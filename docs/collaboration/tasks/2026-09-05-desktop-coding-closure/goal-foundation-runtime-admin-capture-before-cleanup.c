/* Single-purpose diagnostic. No installation, environment/argv reads, or target
 * control. Root controller compiles/reviews this file before any execution.
 * stdout: selector ticket OR capture JSONL transport. Diagnostics: stderr.
 * Exit 2: refused; 3: diagnostic IO/API; 5: no capture; capture exits with the
 * actual spindump status (also transported explicitly, including signals).
 */
#include <stdio.h>
static int observer_puts(const char *s) {
    return fputs(s, stderr) < 0 || fputc('\n', stderr) == EOF ? EOF : 0;
}
#define printf(...) fprintf(stderr, __VA_ARGS__)
#define puts(s) observer_puts(s)
#define putchar(c) fputc((c), stderr)
#define main reviewed_observer_main
#include "goal-foundation-runtime-child-observer.c"
#undef main
#undef putchar
#undef puts
#undef printf
#include <sys/time.h>
#include <signal.h>

struct request {
    uid_t owner;
    struct proc_bsdinfo launcher, tests, child;
    uint64_t launcher_sec, launcher_usec, ticket[6];
    pid_t launcher_pid;
    const char *binary, *temp, *run;
};

static int refuse(const char *reason) {
    fprintf(stderr, "{\"event\":\"refused\",\"reason\":\"%s\",\"mono\":%" PRIu64 "}\n", reason, mono());
    return 2;
}

static bool owner_dir(const char *path, uid_t owner, bool private) {
    char resolved[PATH_MAX]; struct stat st;
    return canonical_path(path, resolved) && lstat(path, &st) == 0
        && S_ISDIR(st.st_mode) && st.st_uid == owner
        && (!private || (st.st_mode & 07777) == 0700);
}

static bool owned(const struct proc_bsdinfo *p, uid_t owner) {
    return p->pbi_uid == owner && p->pbi_ruid == owner;
}

static bool image(pid_t pid, const char *expected) {
    char path[PROC_PIDPATHINFO_MAXSIZE], resolved[PATH_MAX];
    return process_path(pid, path) && realpath(path, resolved)
        && strcmp(resolved, expected) == 0;
}

static bool ticket_parse(const char *s, uint64_t out[6]) {
    /* Exactly six digit tokens, with exactly one ASCII space separator. */
    for (int i = 0; i < 6; ++i) {
        const char *start = s;
        while (*s >= '0' && *s <= '9') ++s;
        size_t n = (size_t)(s - start); char field[21];
        if (!n || n > 20) return false;
        memcpy(field, start, n); field[n] = 0;
        if (!number(field, &out[i])) return false;
        if (i == 5 ? *s != 0 : *s != ' ') return false;
        if (i != 5) ++s;
    }
    return out[0] > 1 && out[0] <= INT_MAX && out[3] > 1 && out[3] <= INT_MAX
        && out[1] > 0 && out[1] <= INT64_MAX && out[4] > 0 && out[4] <= INT64_MAX
        && out[2] < 1000000 && out[5] < 1000000;
}

static bool born(const struct proc_bsdinfo *p, uint64_t sec, uint64_t usec) {
    return p->pbi_start_tvsec == sec && p->pbi_start_tvusec == usec;
}

static bool launcher_valid(struct request *r, bool pinned) {
    struct proc_bsdinfo p;
    if (!bsd(r->launcher_pid, &p, true) || !owned(&p, r->owner)
        || !born(&p, r->launcher_sec, r->launcher_usec)
        || (pinned && !same_generation(&p, &r->launcher))) return false;
    r->launcher = p; return true;
}

static bool tests_valid(struct request *r, pid_t pid, bool pinned) {
    struct proc_bsdinfo p, after;
    if (!bsd(pid, &p, true) || !owned(&p, r->owner)
        || p.pbi_ppid != r->launcher.pbi_pid || p.pbi_pgid != r->launcher.pbi_pgid
        || p.pbi_start_tvsec < r->launcher.pbi_start_tvsec
        || (pinned && !same_generation(&p, &r->tests))
        || !image(pid, r->binary) || !bsd(pid, &after, true)
        || !same_generation(&p, &after)) return false;
    r->tests = p; return true;
}

/* Read cwd only after immediate ancestry and generation admission. No argv. */
static int child_cwd(pid_t pid, struct request *r) {
    struct proc_vnodepathinfo info; memset(&info, 0, sizeof(info)); errno = 0;
    int n = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, (int)sizeof(info));
    if (n != (int)sizeof(info)) {
        api_error("PROC_PIDVNODEPATHINFO", pid, n, (int)sizeof(info), errno); return -1;
    }
    const char *path = info.pvi_cdir.vip_path;
    if (!memchr(path, 0, sizeof(info.pvi_cdir.vip_path))) return -1;
    if (cwd_kind(path, r->temp) != 347) return 0;
    if (!owner_dir(path, r->owner, false)) return -1;
    char fixture[PATH_MAX]; memcpy(fixture, path, strlen(path) + 1);
    fixture[strlen(path) - strlen("/workspace")] = 0;
    return owner_dir(fixture, r->owner, false) ? 347 : -1;
}

static bool child_valid(struct request *r, bool pinned) {
    struct proc_bsdinfo p, after;
    pid_t pid = (pid_t)(pinned ? r->child.pbi_pid : r->ticket[3]);
    if (!bsd(pid, &p, true) || !owned(&p, r->owner)
        || p.pbi_ppid != r->tests.pbi_pid || p.pbi_pgid != p.pbi_pid
        || (pinned && !same_generation(&p, &r->child))
        || !born(&p, r->ticket[4], r->ticket[5])
        || child_cwd(pid, r) != 347 || !image(pid, "/bin/sh")
        || !bsd(pid, &after, true) || !same_generation(&p, &after)) return false;
    r->child = p; return true;
}

static bool age_us(const struct proc_bsdinfo *p, uint64_t *age) {
    struct timeval now;
    if (gettimeofday(&now, NULL) != 0 || now.tv_sec < 0) return false;
    __uint128_t birth = (__uint128_t)p->pbi_start_tvsec * 1000000 + p->pbi_start_tvusec;
    __uint128_t current = (__uint128_t)(uint64_t)now.tv_sec * 1000000 + (uint64_t)now.tv_usec;
    if (current < birth || current - birth > UINT64_MAX) return false;
    *age = (uint64_t)(current - birth); return true;
}

static bool chain(struct request *r) {
    return owner_dir(r->run, r->owner, true) && launcher_valid(r, true)
        && tests_valid(r, (pid_t)r->tests.pbi_pid, true) && child_valid(r, true);
}

static bool quiet_sample(struct request *r, uint64_t *stamp) {
    struct proc_taskallinfo task; struct pipe_fdinfo pipe;
    memset(&task, 0, sizeof(task)); memset(&pipe, 0, sizeof(pipe));
    uint64_t begin = mono();
    if (!chain(r)) return false;
    errno = 0;
    int tn = proc_pidinfo((pid_t)r->child.pbi_pid, PROC_PIDTASKALLINFO, 0, &task, (int)sizeof(task));
    int te = errno; errno = 0;
    int pn = proc_pidfdinfo((pid_t)r->child.pbi_pid, STDOUT_FILENO, PROC_PIDFDPIPEINFO, &pipe, (int)sizeof(pipe));
    int pe = errno;
    bool valid = tn == (int)sizeof(task) && pn == (int)sizeof(pipe)
        && same_generation(&task.pbsd, &r->child) && chain(r);
    bool quiet = valid && task.ptinfo.pti_total_user == 0 && task.ptinfo.pti_faults == 0
        && task.ptinfo.pti_syscalls_mach == 0 && task.ptinfo.pti_syscalls_unix == 0
        && pipe.pipeinfo.pipe_stat.vst_size == 0;
    fprintf(stderr, "{\"event\":\"selection_sample\",\"begin\":%" PRIu64 ",\"end\":%" PRIu64
            ",\"pid\":%u,\"task_length\":%d,\"task_errno\":%d,\"pipe_length\":%d,\"pipe_errno\":%d"
            ",\"valid\":%d,\"quiet\":%d,\"user\":%" PRIu64 ",\"system\":%" PRIu64
            ",\"faults\":%d,\"mach\":%d,\"unix\":%d,\"pipe_bytes\":%" PRId64 "}\n",
            begin, mono(), r->child.pbi_pid, tn, te, pn, pe, valid, quiet,
            task.ptinfo.pti_total_user, task.ptinfo.pti_total_system, task.ptinfo.pti_faults,
            task.ptinfo.pti_syscalls_mach, task.ptinfo.pti_syscalls_unix, pipe.pipeinfo.pipe_stat.vst_size);
    *stamp = begin; return quiet;
}

static int children(pid_t parent, pid_t ids[MAX_CHILDREN]) {
    errno = 0;
    int n = proc_listpids(PROC_PPID_ONLY, (uint32_t)parent, ids, MAX_CHILDREN * (int)sizeof(pid_t));
    int enumeration_errno = errno;
    /* Match the reviewed observer's byte-count API, not listchildpids. */
    if (n < 0 || (n == 0 && enumeration_errno != 0)
        || n >= MAX_CHILDREN * (int)sizeof(pid_t) || n % (int)sizeof(pid_t)) {
        api_error("PROC_PPID_ONLY", parent, n, MAX_CHILDREN * (int)sizeof(pid_t), enumeration_errno); return -1;
    }
    return n / (int)sizeof(pid_t);
}

static int select_target(struct request *r) {
    if (getuid() != r->owner || geteuid() != r->owner) return refuse("privilege");
    struct proc_bsdinfo self;
    if (!bsd(getpid(), &self, true)) return 3;
    int directory = open(r->run, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    if (directory < 0) return refuse("directory");
    struct stat st;
    if (fstat(directory, &st) != 0 || st.st_uid != r->owner || (st.st_mode & 07777) != 0700) {
        close_owned(&directory); return refuse("directory");
    }
    int ready = openat(directory, "auth-ready", O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (ready < 0) { close_owned(&directory); return refuse("ready"); }
    int written = dprintf(ready, "{\"selector_pid\":%u,\"start_sec\":%" PRIu64 ",\"start_usec\":%" PRIu64 "}\n",
                          self.pbi_pid, self.pbi_start_tvsec, self.pbi_start_tvusec);
    bool closed = close_owned(&ready); closed = close_owned(&directory) && closed;
    if (written < 0 || !closed) return 3;
    uint64_t deadline = mono() + 120 * NS_PER_SEC;
    bool have_tests = false, have_child = false;
    while (mono() < deadline) {
        if (!launcher_valid(r, true)) return refuse("launcher");
        pid_t ids[MAX_CHILDREN]; int n;
        if (!have_tests) {
            n = children(r->launcher_pid, ids); if (n < 0) return 3;
            int matches = 0; struct proc_bsdinfo candidate;
            for (int i = 0; i < n; ++i) {
                if (!bsd(ids[i], &candidate, false) || !owned(&candidate, r->owner)
                    || candidate.pbi_ppid != (uint32_t)r->launcher_pid) continue;
                if (image(ids[i], r->binary)) {
                    if (!tests_valid(r, ids[i], false)) return refuse("runtests");
                    ++matches;
                }
            }
            if (matches > 1) return refuse("ambiguous_runtests");
            have_tests = matches == 1;
        }
        if (have_tests) {
            if (!tests_valid(r, (pid_t)r->tests.pbi_pid, true)) return refuse("runtests");
            n = children((pid_t)r->tests.pbi_pid, ids); if (n < 0) return 3;
            int matches = 0;
            for (int i = 0; i < n; ++i) {
                struct proc_bsdinfo p;
                if (!bsd(ids[i], &p, false) || !owned(&p, r->owner)
                    || p.pbi_ppid != r->tests.pbi_pid) continue;
                int kind = child_cwd(ids[i], r);
                if (kind < 0) return refuse("child_cwd");
                if (kind != 347) continue;
                if (++matches > 1) return refuse("ambiguous_child");
                r->ticket[3] = p.pbi_pid; r->ticket[4] = p.pbi_start_tvsec; r->ticket[5] = p.pbi_start_tvusec;
                if (!child_valid(r, false)) return refuse("child");
                have_child = true;
            }
        }
        if (have_child) break;
        if (!pause_until(mono() + INTERVAL_NS)) return 3;
    }
    if (!have_child) return refuse("missing_target");
    /* The first observed generation is final: no replacement or progress retry. */
    uint64_t age, first, second;
    if (!age_us(&r->child, &age) || age > 1500000 || !quiet_sample(r, &first)) return refuse("progress_or_age");
    uint64_t wait_ns = age < 400000 ? (400000 - age) * 1000 : 0;
    if (wait_ns < INTERVAL_NS) wait_ns = INTERVAL_NS;
    if (!pause_until(first + wait_ns) || !quiet_sample(r, &second)
        || second - first < INTERVAL_NS || !age_us(&r->child, &age)
        || age < 400000 || age > 1500000) return refuse("progress_or_age");
    fprintf(stderr, "{\"event\":\"selected\",\"mono\":%" PRIu64 ",\"tests_pid\":%u,\"tests_sec\":%" PRIu64
            ",\"tests_usec\":%" PRIu64 ",\"pid\":%u,\"start_sec\":%" PRIu64 ",\"start_usec\":%" PRIu64 "}\n",
            mono(), r->tests.pbi_pid, r->tests.pbi_start_tvsec, r->tests.pbi_start_tvusec,
            r->child.pbi_pid, r->child.pbi_start_tvsec, r->child.pbi_start_tvusec);
    fprintf(stdout, "%u %" PRIu64 " %" PRIu64 " %u %" PRIu64 " %" PRIu64 "\n",
            r->tests.pbi_pid, r->tests.pbi_start_tvsec, r->tests.pbi_start_tvusec,
            r->child.pbi_pid, r->child.pbi_start_tvsec, r->child.pbi_start_tvusec);
    return fflush(stdout) == 0 ? 0 : 3;
}

static bool frame(const char *role, const unsigned char *bytes, size_t count) {
    static const char alphabet[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    if (fprintf(stdout, "{\"event\":\"stream\",\"role\":\"%s\",\"base64\":\"", role) < 0) return false;
    for (size_t i = 0; i < count; i += 3) {
        uint32_t v = (uint32_t)bytes[i] << 16;
        if (i + 1 < count) v |= (uint32_t)bytes[i + 1] << 8;
        if (i + 2 < count) v |= bytes[i + 2];
        char out[4] = { alphabet[(v >> 18) & 63], alphabet[(v >> 12) & 63],
                        i + 1 < count ? alphabet[(v >> 6) & 63] : '=',
                        i + 2 < count ? alphabet[v & 63] : '=' };
        if (fwrite(out, 1, 4, stdout) != 4) return false;
    }
    return fputs("\"}\n", stdout) >= 0 && fflush(stdout) == 0;
}

static int capture(struct request *r) {
    if (geteuid() != 0) return refuse("privilege");
    uint64_t age;
    if (!chain(r) || !age_us(&r->child, &age) || age > 2000000) return refuse("final_guard");
    int pipes[2][2] = {{-1, -1}, {-1, -1}};
    for (int i = 0; i < 2; ++i) {
        if (pipe(pipes[i]) != 0) goto pipe_failure;
        for (int j = 0; j < 2; ++j) if (fcntl(pipes[i][j], F_SETFD, FD_CLOEXEC) < 0) goto pipe_failure;
    }
    /* Second complete guard immediately before fork; no name-based discovery. */
    if (!chain(r) || !age_us(&r->child, &age) || age > 2000000) {
        for (int i = 0; i < 2; ++i) for (int j = 0; j < 2; ++j) close_owned(&pipes[i][j]);
        return refuse("final_guard");
    }
    fprintf(stderr, "{\"event\":\"capture_started\",\"mono\":%" PRIu64 ",\"pid\":%u,\"start_sec\":%" PRIu64
            ",\"start_usec\":%" PRIu64 ",\"ppid\":%u,\"uid\":%u,\"ruid\":%u,\"pgid\":%u,\"age_us\":%" PRIu64 "}\n",
            mono(), r->child.pbi_pid, r->child.pbi_start_tvsec, r->child.pbi_start_tvusec,
            r->child.pbi_ppid, r->child.pbi_uid, r->child.pbi_ruid, r->child.pbi_pgid, age);
    fflush(stderr);
    pid_t pid = fork();
    if (pid < 0) goto pipe_failure;
    if (pid == 0) {
        if (dup2(pipes[0][1], STDOUT_FILENO) < 0 || dup2(pipes[1][1], STDERR_FILENO) < 0) _exit(126);
        for (int i = 0; i < 2; ++i) for (int j = 0; j < 2; ++j) close(pipes[i][j]);
        char target_pid[24]; snprintf(target_pid, sizeof(target_pid), "%u", r->child.pbi_pid);
        char *const args[] = {"/usr/sbin/spindump", target_pid, "1", "100", "-onlyTarget", "-timeline",
                              "-timelimit", "10", "-noFile", "-noBinary", NULL};
        char *const environment[] = {"PATH=/usr/bin:/bin:/usr/sbin:/sbin", "LANG=C", NULL};
        execve(args[0], args, environment);
        dprintf(STDERR_FILENO, "spindump execve errno=%d\n", errno); _exit(127);
    }
    bool io_ok = true;
    for (int i = 0; i < 2; ++i) if (!close_owned(&pipes[i][1])) io_ok = false;
    fprintf(stderr, "{\"event\":\"spindump_started\",\"mono\":%" PRIu64 ",\"pid\":%d,\"target\":%u}\n", mono(), pid, r->child.pbi_pid);
    while (pipes[0][0] >= 0 || pipes[1][0] >= 0) {
        struct pollfd fds[2] = {{pipes[0][0], POLLIN, 0}, {pipes[1][0], POLLIN, 0}};
        int n = poll(fds, 2, 1000);
        if (n < 0 && errno == EINTR) continue;
        if (n < 0) { api_error("capture_poll", pid, n, 0, errno); io_ok = false; break; }
        for (int i = 0; i < 2; ++i) if (fds[i].revents) {
            unsigned char buffer[4096]; ssize_t got = read(pipes[i][0], buffer, sizeof(buffer));
            if (got > 0) { if (!frame(i == 0 ? "stdout" : "stderr", buffer, (size_t)got)) io_ok = false; }
            else if (got == 0) { if (!close_owned(&pipes[i][0])) io_ok = false; }
            else if (errno != EINTR) { api_error("capture_pipe_read", pid, -1, 0, errno); io_ok = false; close_owned(&pipes[i][0]); }
        }
    }
    for (int i = 0; i < 2; ++i) if (!close_owned(&pipes[i][0])) io_ok = false;
    int status = 0; pid_t waited;
    do { waited = waitpid(pid, &status, 0); } while (waited < 0 && errno == EINTR);
    struct proc_bsdinfo after; errno = 0;
    bool available = bsd((pid_t)r->child.pbi_pid, &after, true);
    bool same = available && same_generation(&r->child, &after);
    int exit_code = waited == pid && WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    int signal_number = waited == pid && WIFSIGNALED(status) ? WTERMSIG(status) : 0;
    fprintf(stdout, "{\"event\":\"spindump_result\",\"mono\":%" PRIu64 ",\"pid\":%d,\"target\":%u,\"waited\":%d,\"exit\":%d,\"signal\":%d,\"io_ok\":%d,\"post_available\":%d,\"post_same\":%d}\n",
            mono(), pid, r->child.pbi_pid, waited, exit_code, signal_number, io_ok, available, same);
    if (fflush(stdout) != 0 || !io_ok || waited != pid || (available && !same)) return 3;
    return signal_number ? 128 + signal_number : exit_code;
pipe_failure:
    api_error("capture_pipe_or_fork", 0, -1, 0, errno);
    for (int i = 0; i < 2; ++i) for (int j = 0; j < 2; ++j) close_owned(&pipes[i][j]);
    return 3;
}

int main(int argc, char **argv) {
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || !timebase.denom) return 3;
    /* Transport failure must not kill this parent before it reaps spindump. */
    if (signal(SIGPIPE, SIG_IGN) == SIG_ERR) return 3;
    setvbuf(stderr, NULL, _IOLBF, 0);
    if (argc < 2 || (strcmp(argv[1], "--select") && strcmp(argv[1], "--capture"))) return refuse("mode");
    bool selecting = strcmp(argv[1], "--select") == 0;
    if (argc != (selecting ? 9 : 10)) return refuse("arguments");
    struct request r; memset(&r, 0, sizeof(r));
    if (!selecting && !ticket_parse(argv[9], r.ticket)) return refuse("ticket");
    uint64_t owner, launcher;
    if (!number(argv[2], &owner) || !owner || owner >= UINT32_MAX) return refuse("owner");
    r.owner = (uid_t)owner;
    if (!number(argv[3], &launcher) || launcher <= 1 || launcher > INT_MAX
        || !number(argv[4], &r.launcher_sec) || !r.launcher_sec || r.launcher_sec > INT64_MAX
        || !number(argv[5], &r.launcher_usec) || r.launcher_usec >= 1000000) return refuse("arguments");
    r.launcher_pid = (pid_t)launcher; r.binary = argv[6]; r.temp = argv[7]; r.run = argv[8];
    if (!owner_dir(r.run, r.owner, true)) return refuse("directory");
    char binary[PATH_MAX], expected[PATH_MAX], temp[PATH_MAX];
    if (!canonical_path(r.binary, binary) || !realpath("/Users/muzi/Agent-loop/.build/debug/RunTests", expected)
        || strcmp(binary, expected) || !canonical_path(r.temp, temp) || !owner_dir(temp, r.owner, false)
        || strncmp(r.run, temp, strlen(temp)) || r.run[strlen(temp)] != '/') return refuse("paths");
    if (!launcher_valid(&r, false)) return refuse("launcher");
    if (selecting) return select_target(&r);
    if (!tests_valid(&r, (pid_t)r.ticket[0], false) || !born(&r.tests, r.ticket[1], r.ticket[2])) return refuse("runtests");
    if (!child_valid(&r, false)) return refuse("child");
    return capture(&r);
}
