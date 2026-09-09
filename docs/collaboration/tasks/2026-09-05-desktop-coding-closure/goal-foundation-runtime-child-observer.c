/* Diagnostic draft only. Root owns compilation, self-check, review and execution.
 * --identity PID
 * --self-check
 * --observe PID START_SEC START_USEC RESOLVED_RUNTESTS_PATH RESOLVED_TEMP_ROOT
 * Exit: 0 bounded observation complete; 2 arguments; 3 capability/IO;
 *       4 identity/ambiguity; 5 deadline/missed target or unreaped self-child.
 * No environment access, process signals, debugger, task_for_pid, or child FD reads.
 */
#include <errno.h>
#include <dirent.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/proc_info.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define NS_PER_SEC UINT64_C(1000000000)
#define INTERVAL_NS UINT64_C(100000000)
#define MAX_THREADS 16
#define MAX_CHILDREN 1024

static mach_timebase_info_data_t timebase;
static int observed_error;
static uint64_t sample_serial;

static uint64_t mono(void) {
    return (uint64_t)(((__uint128_t)mach_absolute_time() * timebase.numer)
                      / timebase.denom);
}

/* Strings reaching this function are validated paths or fixed literals only. */
static void json_string(const char *s) {
    putchar('"');
    for (const unsigned char *p = (const unsigned char *)s; *p; ++p) {
        if (*p == '"' || *p == '\\') { putchar('\\'); putchar(*p); }
        else if (*p < 0x20 || *p >= 0x7f) { printf("\\u%04x", (unsigned)*p); }
        else { putchar(*p); }
    }
    putchar('"');
}

static void api_error(const char *api, pid_t pid, int actual, int expected,
                      int error_number) {
    printf("{\"event\":\"api_error\",\"mono\":%" PRIu64
           ",\"api\":\"%s\",\"pid\":%d,\"actual\":%d,\"expected\":%d,\"errno\":%d}\n",
           mono(), api, pid, actual, expected, error_number);
}

static bool pause_until(uint64_t until) {
    for (;;) {
        uint64_t now = mono();
        if (now >= until) return true;
        uint64_t left = until - now;
        struct timespec delay = { (time_t)(left / NS_PER_SEC),
                                  (long)(left % NS_PER_SEC) };
        if (nanosleep(&delay, NULL) == 0) return true;
        if (errno != EINTR) {
            api_error("nanosleep", 0, -1, 0, errno); return false;
        }
    }
}

static bool close_owned(int *fd) {
    if (*fd < 0) return true;
    int old = *fd; *fd = -1;
    if (close(old) == 0) return true;
    api_error("close_owned", 0, -1, 0, errno);
    return false; /* Do not retry close against a potentially reused descriptor. */
}

static bool bsd(pid_t pid, struct proc_bsdinfo *out, bool report) {
    memset(out, 0, sizeof(*out)); errno = 0;
    int n = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, out, (int)sizeof(*out));
    int e = errno;
    if (n == (int)sizeof(*out)) return true;
    if (report) api_error("PROC_PIDTBSDINFO", pid, n, (int)sizeof(*out), e);
    return false;
}

static bool same_generation(const struct proc_bsdinfo *a,
                            const struct proc_bsdinfo *b) {
    return a->pbi_pid == b->pbi_pid && a->pbi_ppid == b->pbi_ppid
        && a->pbi_uid == b->pbi_uid && a->pbi_ruid == b->pbi_ruid
        && a->pbi_pgid == b->pbi_pgid
        && a->pbi_start_tvsec == b->pbi_start_tvsec
        && a->pbi_start_tvusec == b->pbi_start_tvusec;
}

static bool process_path(pid_t pid, char out[PROC_PIDPATHINFO_MAXSIZE]) {
    memset(out, 0, PROC_PIDPATHINFO_MAXSIZE); errno = 0;
    int n = proc_pidpath(pid, out, PROC_PIDPATHINFO_MAXSIZE);
    int e = errno;
    if (n <= 0 || n >= PROC_PIDPATHINFO_MAXSIZE || out[0] != '/') {
        api_error("proc_pidpath", pid, n, PROC_PIDPATHINFO_MAXSIZE, e); return false;
    }
    return true;
}

static bool canonical_path(const char *input, char output[PATH_MAX]) {
    if (input[0] != '/' || strlen(input) >= PATH_MAX) return false;
    if (realpath(input, output) == NULL) return false;
    return strcmp(input, output) == 0;
}

static bool number(const char *s, uint64_t *out) {
    if (!*s) return false;
    for (const char *p = s; *p; ++p) if (*p < '0' || *p > '9') return false;
    errno = 0; char *end = NULL; unsigned long long n = strtoull(s, &end, 10);
    if (errno || !end || *end) return false;
    *out = (uint64_t)n; return true;
}

static int identity(pid_t pid) {
    struct proc_bsdinfo before, after;
    memset(&before, 0, sizeof(before)); memset(&after, 0, sizeof(after));
    char path[PROC_PIDPATHINFO_MAXSIZE] = {0}, resolved[PATH_MAX] = {0};
    errno = 0;
    int bsd_len = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &before, (int)sizeof(before));
    int bsd_error = errno, path_len = 0, path_error = 0, after_len = 0, after_error = 0;
    int status = 3;
    if (bsd_len == (int)sizeof(before) && before.pbi_uid == getuid()) {
        errno = 0; path_len = proc_pidpath(pid, path, (uint32_t)sizeof(path)); path_error = errno;
        if (path_len > 0 && path_len < (int)sizeof(path) && realpath(path, resolved)) {
            errno = 0; after_len = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &after, (int)sizeof(after)); after_error = errno;
            status = after_len == (int)sizeof(after) && same_generation(&before, &after) ? 0 : 4;
        }
    } else if (bsd_len == (int)sizeof(before)) status = 4;
    if (status != 0) {
        printf("{\"event\":\"identity\",\"mono\":%" PRIu64
               ",\"pid\":%d,\"status\":%d,\"bsd_length\":%d,\"bsd_errno\":%d,\"path_length\":%d,\"path_errno\":%d,\"after_length\":%d,\"after_errno\":%d}\n",
               mono(), pid, status, bsd_len, bsd_error, path_len, path_error, after_len, after_error);
        return status;
    }
    printf("{\"event\":\"identity\",\"mono\":%" PRIu64
           ",\"pid\":%u,\"ppid\":%u,\"uid\":%u,\"pgid\":%u,\"start_sec\":%" PRIu64
           ",\"start_usec\":%" PRIu64 ",\"bsd_length\":%zu,\"bsd_errno\":%d,\"after_length\":%d,\"after_errno\":%d,\"path_length\":%d,\"path_errno\":%d,\"path\":",
           mono(), before.pbi_pid, before.pbi_ppid, before.pbi_uid, before.pbi_pgid,
           before.pbi_start_tvsec, before.pbi_start_tvusec, sizeof(before), bsd_error,
           after_len, after_error, path_len, path_error);
    json_string(resolved); puts(",\"status\":0}"); return 0;
}

struct target {
    bool admitted, ended, name_attempted;
    int fixture;
    struct proc_bsdinfo generation;
    uint64_t wrapper_dev, wrapper_ino;
    char wrapper[PATH_MAX];
    mach_port_t name_port;
    uint64_t previous_begin;
    unsigned valid_samples;
};

static void release_port(struct target *t) {
    if (t->name_port == MACH_PORT_NULL) return;
    kern_return_t kr = mach_port_deallocate(mach_task_self(), t->name_port);
    printf("{\"event\":\"name_port_release\",\"mono\":%" PRIu64
           ",\"pid\":%u,\"kr\":%d}\n", mono(), t->generation.pbi_pid, kr);
    t->name_port = MACH_PORT_NULL;
    if (kr != KERN_SUCCESS) observed_error = 3;
}

static void end_target(struct target *t, const char *reason) {
    if (t->ended) return;
    t->ended = true;
    printf("{\"event\":\"child_end\",\"mono\":%" PRIu64
           ",\"pid\":%u,\"fixture\":%d,\"reason\":\"%s\"}\n",
           mono(), t->generation.pbi_pid, t->fixture, reason);
    release_port(t);
}

static bool check_target(struct target *t, struct proc_bsdinfo *now) {
    if (!bsd((pid_t)t->generation.pbi_pid, now, true)) {
        end_target(t, "identity_unavailable"); return false;
    }
    if (!same_generation(&t->generation, now)) {
        end_target(t, "identity_changed"); observed_error = 4; return false;
    }
    return true;
}

static bool sample_target(struct target *t, int fd, int64_t *pipe_count) {
    struct proc_bsdinfo pre, post;
    uint64_t begin = mono(), serial = ++sample_serial;
    if (!check_target(t, &pre)) return false;
    printf("{\"event\":\"sample_begin\",\"sample\":%" PRIu64
           ",\"mono\":%" PRIu64 ",\"gap_ns\":%" PRIu64 ",\"pid\":%u,\"fixture\":%d}\n",
           serial, begin, t->previous_begin ? begin - t->previous_begin : 0,
           pre.pbi_pid, t->fixture);
    t->previous_begin = begin;
    bool ok = true;
    struct proc_taskallinfo task; memset(&task, 0, sizeof(task)); errno = 0;
    int n = proc_pidinfo((pid_t)pre.pbi_pid, PROC_PIDTASKALLINFO, 0, &task, (int)sizeof(task));
    int task_errno = errno;
    bool task_valid = n == (int)sizeof(task) && same_generation(&pre, &task.pbsd);
    printf("{\"event\":\"task\",\"sample\":%" PRIu64 ",\"mono\":%" PRIu64
           ",\"pid\":%u,\"length\":%d,\"expected\":%zu,\"errno\":%d,\"valid\":%d",
           serial, mono(), pre.pbi_pid, n, sizeof(task), task_errno, task_valid);
    if (task_valid) {
        printf(",\"bsd_status\":%u,\"bsd_flags\":%u,\"user\":%" PRIu64
               ",\"system\":%" PRIu64 ",\"faults\":%d,\"pageins\":%d,\"syscalls_mach\":%d"
               ",\"syscalls_unix\":%d,\"context_switches\":%d,\"threads\":%d,\"running\":%d",
               task.pbsd.pbi_status, task.pbsd.pbi_flags, task.ptinfo.pti_total_user,
               task.ptinfo.pti_total_system, task.ptinfo.pti_faults, task.ptinfo.pti_pageins,
               task.ptinfo.pti_syscalls_mach, task.ptinfo.pti_syscalls_unix, task.ptinfo.pti_csw,
               task.ptinfo.pti_threadnum, task.ptinfo.pti_numrunning);
    } else ok = false;
    puts("}");
    if (!task_valid) {
        bool identity_valid = check_target(t, &post);
        if (n == (int)sizeof(task) && !same_generation(&pre, &task.pbsd)) {
            end_target(t, "task_identity_changed"); observed_error = 4; identity_valid = false;
        }
        printf("{\"event\":\"sample_end\",\"sample\":%" PRIu64 ",\"mono\":%" PRIu64
               ",\"pid\":%u,\"identity_valid\":%d,\"required_apis_valid\":0}\n",
               serial, mono(), pre.pbi_pid, identity_valid);
        return false;
    }
    uint64_t threads[MAX_THREADS]; memset(threads, 0, sizeof(threads)); errno = 0;
    n = proc_pidinfo((pid_t)pre.pbi_pid, PROC_PIDLISTTHREADS, 0, threads, (int)sizeof(threads));
    int thread_errno = errno;
    bool list_valid = n > 0 && n <= (int)sizeof(threads) && n % (int)sizeof(uint64_t) == 0;
    bool truncated = n >= (int)sizeof(threads)
        || (task_valid && task.ptinfo.pti_threadnum > MAX_THREADS);
    printf("{\"event\":\"thread_list\",\"sample\":%" PRIu64 ",\"mono\":%" PRIu64
           ",\"pid\":%u,\"length\":%d,\"capacity\":%zu,\"errno\":%d,\"valid\":%d,\"possibly_truncated\":%d}\n",
           serial, mono(), pre.pbi_pid, n, sizeof(threads), thread_errno, list_valid, truncated);
    if (!list_valid || truncated) ok = false;
    if (list_valid) for (int i = 0; i < n / (int)sizeof(uint64_t); ++i) {
        struct proc_threadinfo thread; memset(&thread, 0, sizeof(thread)); errno = 0;
        int len = proc_pidinfo((pid_t)pre.pbi_pid, PROC_PIDTHREADINFO, threads[i], &thread, (int)sizeof(thread));
        int e = errno; bool valid = len == (int)sizeof(thread);
        printf("{\"event\":\"thread\",\"sample\":%" PRIu64 ",\"mono\":%" PRIu64
               ",\"pid\":%u,\"thread_handle\":%" PRIu64 ",\"length\":%d,\"expected\":%zu,\"errno\":%d,\"valid\":%d",
               serial, mono(), pre.pbi_pid, threads[i], len, sizeof(thread), e, valid);
        if (valid) printf(",\"run_state\":%d,\"flags\":%d,\"user\":%" PRIu64
                          ",\"system\":%" PRIu64 ",\"cpu_usage\":%d,\"sleep_time\":%d",
                          thread.pth_run_state, thread.pth_flags, thread.pth_user_time,
                          thread.pth_system_time, thread.pth_cpu_usage, thread.pth_sleep_time);
        else ok = false;
        puts("}");
    }
    if (!t->name_attempted) {
        t->name_attempted = true;
        kern_return_t kr = task_name_for_pid(mach_task_self(), (int)pre.pbi_pid, &t->name_port);
        printf("{\"event\":\"task_name\",\"sample\":%" PRIu64
               ",\"mono\":%" PRIu64 ",\"pid\":%u,\"kr\":%d,\"port_valid\":%d}\n",
               serial, mono(), pre.pbi_pid, kr, t->name_port != MACH_PORT_NULL);
        if (kr != KERN_SUCCESS && t->name_port != MACH_PORT_NULL) release_port(t);
    }
    if (t->name_port != MACH_PORT_NULL) {
        mach_task_basic_info_data_t basic; memset(&basic, 0, sizeof(basic));
        mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
        kern_return_t kr = task_info(t->name_port, MACH_TASK_BASIC_INFO, (task_info_t)&basic, &count);
        bool valid = kr == KERN_SUCCESS && count == MACH_TASK_BASIC_INFO_COUNT;
        printf("{\"event\":\"task_basic\",\"sample\":%" PRIu64 ",\"mono\":%" PRIu64
               ",\"pid\":%u,\"kr\":%d,\"count\":%u,\"expected\":%u,\"valid\":%d",
               serial, mono(), pre.pbi_pid, kr, count, (unsigned)MACH_TASK_BASIC_INFO_COUNT, valid);
        if (valid) printf(",\"suspend_count\":%d", basic.suspend_count);
        puts("}"); /* Optional capability failure remains unknown, not zero. */
    }
    struct pipe_fdinfo pipe; memset(&pipe, 0, sizeof(pipe)); errno = 0;
    n = proc_pidfdinfo((pid_t)pre.pbi_pid, fd, PROC_PIDFDPIPEINFO, &pipe, (int)sizeof(pipe));
    int pipe_errno = errno;
    bool pipe_valid = n == (int)sizeof(pipe) && pipe.pipeinfo.pipe_stat.vst_size >= 0;
    printf("{\"event\":\"pipe\",\"sample\":%" PRIu64 ",\"mono\":%" PRIu64
           ",\"pid\":%u,\"fd\":%d,\"length\":%d,\"expected\":%zu,\"errno\":%d,\"valid\":%d",
           serial, mono(), pre.pbi_pid, fd, n, sizeof(pipe), pipe_errno, pipe_valid);
    if (pipe_valid) {
        *pipe_count = pipe.pipeinfo.pipe_stat.vst_size;
        printf(",\"candidate_bytes\":%" PRId64 ",\"handle\":%" PRIu64 ",\"peer_handle\":%" PRIu64
               ",\"status\":%d", *pipe_count, pipe.pipeinfo.pipe_handle,
               pipe.pipeinfo.pipe_peerhandle, pipe.pipeinfo.pipe_status);
    } else ok = false;
    puts("}");
    bool identity_valid = check_target(t, &post);
    printf("{\"event\":\"sample_end\",\"sample\":%" PRIu64 ",\"mono\":%" PRIu64
           ",\"pid\":%u,\"identity_valid\":%d,\"required_apis_valid\":%d}\n",
           serial, mono(), pre.pbi_pid, identity_valid, ok);
    /* Consumers must discard all sample values if this final identity check fails. */
    if (identity_valid && ok) ++t->valid_samples;
    return identity_valid && ok;
}

static bool hex_char(char c) {
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

static int cwd_kind(const char *path, const char *temp) {
    size_t root_len = strlen(temp);
    if (strncmp(path, temp, root_len) != 0 || path[root_len] != '/') return 0;
    const char *p = path + root_len + 1;
    if (strlen(p) != 6 + 4 + 10) return 0;
    int kind = 0;
    if (strncmp(p, "c-346-", 6) == 0) kind = 346;
    if (strncmp(p, "c-347-", 6) == 0) kind = 347;
    if (strncmp(p, "c-372-", 6) == 0) kind = 372;
    if (!kind) return 0;
    p += 6;
    for (int i = 0; i < 4; ++i) if (!hex_char(p[i])) return 0;
    return strcmp(p + 4, "/workspace") == 0 ? kind : 0;
}

static bool staged_name(const char *p) {
    if (strlen(p) != 7 + 36 || strncmp(p, "staged-", 7) != 0) return false;
    p += 7;
    for (int i = 0; i < 36; ++i) {
        bool dash = i == 8 || i == 13 || i == 18 || i == 23;
        if (dash ? p[i] != '-' : !hex_char(p[i])) return false;
    }
    return true;
}

static bool owned_directory(const char *path) {
    char canonical[PATH_MAX];
    if (!canonical_path(path, canonical)) return false;
    struct stat st;
    return lstat(path, &st) == 0 && S_ISDIR(st.st_mode) && st.st_uid == getuid();
}

static int find_cwd(pid_t pid, const char *temp, char cwd[PATH_MAX]) {
    struct proc_vnodepathinfo info; memset(&info, 0, sizeof(info)); errno = 0;
    int n = proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, (int)sizeof(info));
    if (n != (int)sizeof(info)) {
        api_error("PROC_PIDVNODEPATHINFO_discovery", 0, n, (int)sizeof(info), errno); return -1;
    }
    const char *path = info.pvi_cdir.vip_path;
    if (!memchr(path, 0, sizeof(info.pvi_cdir.vip_path))) return -1;
    int kind = cwd_kind(path, temp);
    if (!kind) return 0;
    if (strlen(path) >= PATH_MAX || !owned_directory(path)) return -1;
    char fixture[PATH_MAX]; memcpy(fixture, path, strlen(path) + 1);
    fixture[strlen(path) - strlen("/workspace")] = 0;
    if (!owned_directory(fixture)) return -1;
    memcpy(cwd, path, strlen(path) + 1);
    return kind;
}

/* Optional stat-only provenance. No script/argv/environment contents are read. */
static void record_wrapper(struct target *t, const char *cwd) {
    char fixture[PATH_MAX]; memcpy(fixture, cwd, strlen(cwd) + 1);
    fixture[strlen(cwd) - strlen("/workspace")] = 0;
    errno = 0; DIR *dir = opendir(fixture);
    if (!dir) { api_error("optional_wrapper_opendir", (pid_t)t->generation.pbi_pid, -1, 0, errno); return; }
    unsigned entries = 0, matches = 0; int read_error = 0;
    for (;;) {
        errno = 0; struct dirent *entry = readdir(dir);
        if (!entry) { read_error = errno; break; }
        if (++entries > 64) break;
        if (!staged_name(entry->d_name)) continue;
        ++matches;
        int n = snprintf(t->wrapper, sizeof(t->wrapper), "%s/%s/executable", fixture, entry->d_name);
        if (n < 0 || n >= (int)sizeof(t->wrapper)) { read_error = ENAMETOOLONG; break; }
    }
    int close_result = closedir(dir), close_error = close_result == 0 ? 0 : errno;
    struct stat st; char canonical[PATH_MAX];
    bool valid = !read_error && !close_error && entries <= 64 && matches == 1
        && canonical_path(t->wrapper, canonical) && lstat(t->wrapper, &st) == 0
        && S_ISREG(st.st_mode) && st.st_uid == getuid() && st.st_nlink == 1;
    printf("{\"event\":\"optional_wrapper\",\"mono\":%" PRIu64
           ",\"pid\":%u,\"valid\":%d,\"matches\":%u,\"truncated\":%d,\"read_errno\":%d,\"close_errno\":%d",
           mono(), t->generation.pbi_pid, valid, matches, entries > 64, read_error, close_error);
    if (valid) {
        t->wrapper_dev = (uint64_t)st.st_dev; t->wrapper_ino = (uint64_t)st.st_ino;
        printf(",\"dev\":%" PRIu64 ",\"ino\":%" PRIu64 ",\"path\":", t->wrapper_dev, t->wrapper_ino);
        json_string(t->wrapper);
    }
    puts("}");
}

static bool root_identity(pid_t pid, uint64_t sec, uint64_t usec,
                          const struct proc_bsdinfo *pinned,
                          const char *expected, bool *image_ready) {
    struct proc_bsdinfo before, after;
    char path[PROC_PIDPATHINFO_MAXSIZE], resolved[PATH_MAX];
    if (!bsd(pid, &before, true)) return false;
    if (before.pbi_pid != (uint32_t)pid || before.pbi_uid != getuid()
        || before.pbi_start_tvsec != sec || before.pbi_start_tvusec != usec
        || !same_generation(pinned, &before)) return false;
    if (!process_path(pid, path) || !realpath(path, resolved)
        || !bsd(pid, &after, true) || !same_generation(&before, &after)) return false;
    *image_ready = strcmp(resolved, expected) == 0;
    return true;
}

static int observe(pid_t root, uint64_t sec, uint64_t usec, const char *expected, const char *temp) {
    struct target targets[3]; memset(targets, 0, sizeof(targets));
    struct proc_bsdinfo pinned;
    if (!bsd(root, &pinned, true) || pinned.pbi_uid != getuid()
        || pinned.pbi_start_tvsec != sec || pinned.pbi_start_tvusec != usec) {
        printf("{\"event\":\"terminal\",\"mono\":%" PRIu64 ",\"reason\":\"initial_parent_identity_invalid\",\"status\":4}\n", mono());
        return 4;
    }
    uint64_t begin = mono(), deadline = begin + 120 * NS_PER_SEC;
    const char *reason = "deadline";
    bool seen_image = false;
    while (mono() < deadline) {
        uint64_t tick = mono(); bool image_ready = false;
        if (!root_identity(root, sec, usec, &pinned, expected, &image_ready)) {
            struct proc_bsdinfo last;
            if (bsd(root, &last, false)) observed_error = 4;
            reason = "parent_identity_ended"; break;
        }
        if (seen_image && !image_ready) { observed_error = 4; reason = "parent_image_changed"; break; }
        if (!image_ready) {
            uint64_t next = tick + INTERVAL_NS;
            if (!pause_until(next < deadline ? next : deadline)) { observed_error = 3; reason = "sleep_error"; break; }
            continue;
        }
        seen_image = true;
        pid_t children[MAX_CHILDREN]; memset(children, 0, sizeof(children)); errno = 0;
        /* proc_listpids has byte-count semantics; avoid listchildpids count ambiguity. */
        int bytes = proc_listpids(PROC_PPID_ONLY, (uint32_t)root, children, (int)sizeof(children));
        int enumeration_errno = errno;
        bool enumeration_valid = bytes >= 0 && bytes < (int)sizeof(children)
            && bytes % (int)sizeof(pid_t) == 0 && !(bytes == 0 && enumeration_errno != 0);
        printf("{\"event\":\"child_enumeration\",\"mono\":%" PRIu64
               ",\"root_pid\":%d,\"length\":%d,\"capacity\":%zu,\"errno\":%d,\"valid\":%d}\n",
               mono(), root, bytes, sizeof(children), enumeration_errno, enumeration_valid);
        if (!enumeration_valid) {
            api_error("PROC_PPID_ONLY", root, bytes, (int)sizeof(children), enumeration_errno);
            observed_error = 3; reason = "child_list_failure_or_truncation"; break;
        }
        for (int i = 0; i < bytes / (int)sizeof(pid_t); ++i) {
            pid_t pid = children[i]; if (pid <= 0) continue;
            struct proc_bsdinfo pre, post;
            if (!bsd(pid, &pre, false) || pre.pbi_pid != (uint32_t)pid
                || pre.pbi_ppid != (uint32_t)root || pre.pbi_uid != getuid()
                || pre.pbi_ruid != getuid() || pre.pbi_pgid != (uint32_t)pid) continue;
            bool known = false;
            for (int j = 0; j < 3; ++j) if (targets[j].admitted
                && same_generation(&targets[j].generation, &pre)) known = true;
            if (known) continue;
            char cwd[PATH_MAX] = {0}; int kind = find_cwd(pid, temp, cwd);
            if (kind < 0) { observed_error = 3; continue; }
            if (!kind) continue;
            char image[PROC_PIDPATHINFO_MAXSIZE], resolved_image[PATH_MAX];
            if (!process_path(pid, image) || !realpath(image, resolved_image)) { observed_error = 3; continue; }
            if (strcmp(resolved_image, "/bin/sh") != 0
                && !(kind == 372 && strcmp(resolved_image, "/bin/sleep") == 0)) {
                observed_error = 4; reason = "fixture_image_unexpected"; goto done;
            }
            if (!bsd(pid, &post, true) || !same_generation(&pre, &post)) continue;
            bool parent_ready = false;
            if (!root_identity(root, sec, usec, &pinned, expected, &parent_ready) || !parent_ready) {
                observed_error = 4; reason = "parent_changed_during_admission"; goto done;
            }
            int index = kind == 346 ? 0 : kind == 347 ? 1 : 2;
            struct target *t = &targets[index];
            if (t->admitted) { observed_error = 4; reason = "multiple_fixture_generations"; goto done; }
            t->admitted = true; t->fixture = kind; t->generation = pre;
            printf("{\"event\":\"child_admitted\",\"mono\":%" PRIu64
                   ",\"pid\":%u,\"ppid\":%u,\"uid\":%u,\"pgid\":%u,\"fixture\":%d"
                   ",\"start_sec\":%" PRIu64 ",\"start_usec\":%" PRIu64
                   ",\"image\":",
                   mono(), pre.pbi_pid, pre.pbi_ppid, pre.pbi_uid, pre.pbi_pgid, kind,
                   pre.pbi_start_tvsec, pre.pbi_start_tvusec);
            json_string(resolved_image); printf(",\"cwd\":"); json_string(cwd); puts("}");
            record_wrapper(t, cwd);
        }
        for (int i = 0; i < 3; ++i) if (targets[i].admitted && !targets[i].ended) {
            int64_t count = -1;
            if (!sample_target(&targets[i], STDOUT_FILENO, &count) && !targets[i].ended) observed_error = 3;
        }
        uint64_t next = tick + INTERVAL_NS;
        if (!pause_until(next < deadline ? next : deadline)) { observed_error = 3; reason = "sleep_error"; break; }
    }
done:;
    int missing = 0, no_samples = 0;
    for (int i = 0; i < 3; ++i) {
        if (!targets[i].admitted) ++missing;
        else {
            if (!targets[i].valid_samples) ++no_samples;
            printf("{\"event\":\"coverage\",\"mono\":%" PRIu64 ",\"fixture\":%d,\"pid\":%u,\"valid_samples\":%u}\n",
                   mono(), targets[i].fixture, targets[i].generation.pbi_pid, targets[i].valid_samples);
            end_target(&targets[i], "observer_finished");
        }
    }
    int status = observed_error ? observed_error : missing || no_samples || mono() >= deadline ? 5 : 0;
    printf("{\"event\":\"terminal\",\"mono\":%" PRIu64
           ",\"reason\":\"%s\",\"missing_targets\":%d,\"no_valid_samples\":%d,\"image_seen\":%d,\"status\":%d}\n",
           mono(), reason, missing, no_samples, seen_image, status);
    return status;
}

/* The only fork/read/dup/wait operations below target this self-check's own FDs/child. */
static int self_check(void) {
    const uint64_t deadline = mono() + 5 * NS_PER_SEC;
    int output[2] = {-1, -1}, control[2] = {-1, -1};
    pid_t child = -1; int status = 3; bool reaped = false;
    struct target target; memset(&target, 0, sizeof(target));
    for (int fd = 0; fd <= 2; ++fd) if (fcntl(fd, F_GETFD) < 0) {
        api_error("self_stdio_precondition", 0, -1, fd, errno); goto cleanup;
    }
    if (pipe(output) != 0 || pipe(control) != 0) { api_error("self_pipe", 0, -1, 0, errno); goto cleanup; }
    int flags = fcntl(output[0], F_GETFL);
    if (flags < 0 || fcntl(output[0], F_SETFL, flags | O_NONBLOCK) != 0) {
        api_error("self_nonblocking_read", 0, -1, 0, errno); goto cleanup;
    }
    child = fork();
    if (child < 0) { api_error("self_fork", 0, -1, 0, errno); goto cleanup; }
    if (child == 0) {
        if (close(output[0]) != 0 || close(control[1]) != 0) _exit(20);
        if (dup2(output[1], STDOUT_FILENO) < 0) _exit(21);
        if (output[1] != STDOUT_FILENO && close(output[1]) != 0) _exit(22);
        static const char sentinel[] = "123456789";
        if (write(STDOUT_FILENO, sentinel, 9) != 9) _exit(23);
        uint64_t child_deadline = mono() + 4 * NS_PER_SEC;
        while (mono() < child_deadline) {
            struct pollfd p = {control[0], POLLIN | POLLHUP, 0};
            int result = poll(&p, 1, 100);
            if (result < 0 && errno != EINTR) _exit(24);
            if (result > 0 && p.revents) {
                int code = (p.revents & (POLLIN | POLLHUP)) ? 0 : 25;
                if (close(control[0]) != 0 || close(STDOUT_FILENO) != 0) _exit(26);
                _exit(code);
            }
        }
        if (close(control[0]) != 0 || close(STDOUT_FILENO) != 0) _exit(27);
        _exit(28);
    }
    if (!close_owned(&output[1]) || !close_owned(&control[0])) goto cleanup;
    if (!bsd(child, &target.generation, true) || target.generation.pbi_ppid != (uint32_t)getpid()
        || target.generation.pbi_uid != getuid()) goto cleanup;
    target.admitted = true;
    struct pollfd ready = {output[0], POLLIN, 0};
    bool available = false;
    while (mono() < deadline) {
        int n = poll(&ready, 1, 100);
        if (n > 0) { available = (ready.revents & POLLIN) != 0; break; }
        if (n < 0 && errno != EINTR) { api_error("self_poll", child, n, 1, errno); goto cleanup; }
    }
    if (!available) {
        printf("{\"event\":\"self_assert\",\"check\":\"sentinel_available\",\"valid\":0}\n");
        goto cleanup;
    }
    int64_t count = -1;
    bool sample_ok = sample_target(&target, STDOUT_FILENO, &count);
    printf("{\"event\":\"self_assert\",\"check\":\"pipe_before_read\",\"expected\":9,\"actual\":%" PRId64 ",\"apis_valid\":%d}\n", count, sample_ok);
    if (!sample_ok || count != 9) goto cleanup;
    char bytes[9]; ssize_t n = read(output[0], bytes, sizeof(bytes));
    if (n != 9 || memcmp(bytes, "123456789", 9) != 0) {
        api_error("self_read_sentinel", child, (int)n, 9, errno); goto cleanup;
    }
    count = -1;
    sample_ok = sample_target(&target, STDOUT_FILENO, &count);
    printf("{\"event\":\"self_assert\",\"check\":\"pipe_after_read\",\"expected\":0,\"actual\":%" PRId64 ",\"apis_valid\":%d}\n", count, sample_ok);
    if (!sample_ok || count != 0) goto cleanup;
    status = 0;
cleanup:
    /* Closing the parent's control writer releases its own child without signals. */
    if (!close_owned(&control[1])) status = 3;
    if (!close_owned(&control[0])) status = 3;
    if (!close_owned(&output[0])) status = 3;
    if (!close_owned(&output[1])) status = 3;
    release_port(&target);
    if (child > 0) while (mono() < deadline) {
        int wait_status = 0; errno = 0; pid_t result = waitpid(child, &wait_status, WNOHANG);
        if (result == child) {
            reaped = true;
            printf("{\"event\":\"self_child_reaped\",\"mono\":%" PRIu64
                   ",\"pid\":%d,\"raw_status\":%d}\n", mono(), child, wait_status);
            if (!WIFEXITED(wait_status) || WEXITSTATUS(wait_status) != 0) status = 3;
            break;
        }
        if (result < 0 && errno != EINTR) { api_error("self_waitpid", child, result, child, errno); status = 3; break; }
        if (!pause_until(mono() + UINT64_C(10000000))) { status = 3; break; }
    }
    if (child > 0 && !reaped) status = 5;
    if (observed_error) status = observed_error;
    printf("{\"event\":\"self_check_terminal\",\"mono\":%" PRIu64
           ",\"status\":%d,\"child_reaped\":%d}\n", mono(), status, reaped);
    return status;
}

int main(int argc, char **argv) {
    kern_return_t time_result = mach_timebase_info(&timebase);
    if (time_result != KERN_SUCCESS || !timebase.denom) {
        printf("{\"event\":\"exit\",\"reason\":\"timebase_failure\",\"kr\":%d,\"status\":3}\n", time_result); return 3;
    }
    if (setvbuf(stdout, NULL, _IOLBF, 0) != 0) return 3;
    uint64_t pid_number = 0, sec = 0, usec = 0;
    /* Machine-readable runner handshake is exactly one JSON object. */
    if (argc >= 2 && strcmp(argv[1], "--identity") == 0) {
        if (argc != 3 || !number(argv[2], &pid_number) || pid_number == 0 || pid_number > INT_MAX) {
            puts("{\"event\":\"identity\",\"status\":2,\"reason\":\"invalid_arguments\"}"); return 2;
        }
        int status = identity((pid_t)pid_number);
        if (fflush(stdout) != 0 || ferror(stdout)) return 3;
        return status;
    }
    printf("{\"event\":\"observer_start\",\"mono\":%" PRIu64
           ",\"pid\":%d,\"uid\":%u,\"timebase_numer\":%u,\"timebase_denom\":%u}\n",
           mono(), getpid(), getuid(), timebase.numer, timebase.denom);
    int result = 2;
    if (argc == 2 && strcmp(argv[1], "--self-check") == 0) result = self_check();
    else if (argc == 7 && strcmp(argv[1], "--observe") == 0
             && number(argv[2], &pid_number) && pid_number > 0 && pid_number <= INT_MAX
             && number(argv[3], &sec) && sec > 0 && number(argv[4], &usec) && usec < 1000000) {
        char expected[PATH_MAX], temp[PATH_MAX]; struct stat st;
        if (canonical_path(argv[5], expected) && canonical_path(argv[6], temp)
            && strcmp(temp, "/") != 0 && stat(temp, &st) == 0 && S_ISDIR(st.st_mode))
            result = observe((pid_t)pid_number, sec, usec, expected, temp);
    }
    printf("{\"event\":\"exit\",\"mono\":%" PRIu64 ",\"status\":%d}\n", mono(), result);
    if (fflush(stdout) != 0 || ferror(stdout)) return 3;
    return result;
}
