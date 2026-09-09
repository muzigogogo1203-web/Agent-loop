#define _DARWIN_C_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <signal.h>
#include <spawn.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define FIXTURE_SWITCH "--agentloop-cli-mechanics-fixture"
#define MODE_EXIT_ZERO "exit-zero"
#define MODE_PRINT_FINAL_LINE "print-final-line"
#define MODE_WAIT_TERM "wait-term"
#define MODE_IGNORE_TERM "ignore-term"
#define MODE_READY_FILE_IGNORE_TERM "ready-file-ignore-term"
#define MODE_READY_FILE "ready-file"
#define MODE_READY_AND_DRAIN_IGNORE_TERM "ready-and-drain-ignore-term"
#define MODE_HELD_STDERR_PARENT "held-stderr-parent"
#define MODE_HELD_STDERR_CHILD "held-stderr-child"
#define MODE_ENVIRONMENT_SENTINEL "environment-sentinel"

#define FIXTURE_ERROR_EXIT 64
#define FIXTURE_REPORT_ERROR_EXIT 74
#define FIXTURE_REPORT_LOST_EXIT 75
#define MAX_CLEANUP_FAILURES 8

typedef struct {
    const char *operation;
    int code;
    bool message_only;
} fixture_failure;

typedef struct {
    fixture_failure primary;
    bool has_primary;
    fixture_failure cleanup[MAX_CLEANUP_FAILURES];
    size_t cleanup_count;
    bool cleanup_overflow;
} fixture_errors;

static void set_system_failure(fixture_errors *errors, const char *operation,
                               int code) {
    if (!errors->has_primary) {
        errors->primary = (fixture_failure){operation, code, false};
        errors->has_primary = true;
    }
}

static void set_message_failure(fixture_errors *errors, const char *message) {
    if (!errors->has_primary) {
        errors->primary = (fixture_failure){message, 0, true};
        errors->has_primary = true;
    }
}

static void add_cleanup_failure(fixture_errors *errors, const char *operation,
                                int code) {
    if (errors->cleanup_count == MAX_CLEANUP_FAILURES) {
        errors->cleanup_overflow = true;
        return;
    }
    errors->cleanup[errors->cleanup_count++] =
        (fixture_failure){operation, code, false};
}

static int write_all_raw(int descriptor, const void *bytes, size_t count,
                         int *failure_code) {
    const unsigned char *cursor = bytes;
    size_t offset = 0;
    while (offset < count) {
        ssize_t written = write(descriptor, cursor + offset, count - offset);
        if (written > 0) {
            offset += (size_t)written;
            continue;
        }
        if (written < 0 && errno == EINTR) {
            continue;
        }
        *failure_code = written == 0 ? EIO : errno;
        return -1;
    }
    return 0;
}

static int write_fixture(int descriptor, const void *bytes, size_t count,
                         fixture_errors *errors) {
    int code = 0;
    if (write_all_raw(descriptor, bytes, count, &code) == 0) {
        return 0;
    }
    set_system_failure(errors, "write", code);
    return -1;
}

static bool append_format(char *buffer, size_t capacity, size_t *length,
                          const char *format, ...) {
    if (*length >= capacity) {
        return false;
    }
    va_list arguments;
    va_start(arguments, format);
    int count = vsnprintf(buffer + *length, capacity - *length, format,
                          arguments);
    va_end(arguments);
    if (count < 0 || (size_t)count >= capacity - *length) {
        return false;
    }
    *length += (size_t)count;
    return true;
}

static bool append_failure(char *buffer, size_t capacity, size_t *length,
                           fixture_failure failure) {
    if (failure.message_only) {
        return append_format(buffer, capacity, length, "%s", failure.operation);
    }
    return append_format(buffer, capacity, length, "fixture %s failed errno=%d",
                         failure.operation, failure.code);
}

static int report_errors(const fixture_errors *errors) {
    char message[4096];
    size_t length = 0;
    bool formatted = append_format(message, sizeof(message), &length,
                                   "AgentLoop CLI mechanics fixture: ");
    fixture_failure primary = errors->has_primary
        ? errors->primary
        : (fixture_failure){"unknown fixture failure", 0, true};
    formatted = formatted
        && append_failure(message, sizeof(message), &length, primary);
    if (errors->cleanup_count > 0 || errors->cleanup_overflow) {
        formatted = formatted
            && append_format(message, sizeof(message), &length, "; cleanup=[");
        for (size_t index = 0; formatted && index < errors->cleanup_count;
             ++index) {
            if (index > 0) {
                formatted = append_format(message, sizeof(message), &length,
                                          "; ");
            }
            formatted = formatted
                && append_failure(message, sizeof(message), &length,
                                  errors->cleanup[index]);
        }
        if (formatted && errors->cleanup_overflow) {
            formatted = append_format(message, sizeof(message), &length,
                                      "%scleanup failure capacity exceeded",
                                      errors->cleanup_count > 0 ? "; " : "");
        }
        formatted = formatted
            && append_format(message, sizeof(message), &length, "]");
    }
    formatted = formatted
        && append_format(message, sizeof(message), &length, "\n");
    if (!formatted) {
        static const char overflow[] =
            "AgentLoop CLI mechanics fixture: error report overflow\n";
        memcpy(message, overflow, sizeof(overflow) - 1);
        length = sizeof(overflow) - 1;
    }

    int stderr_code = 0;
    if (write_all_raw(STDERR_FILENO, message, length, &stderr_code) == 0) {
        return FIXTURE_ERROR_EXIT;
    }

    char fallback[4608];
    int prefix = snprintf(
        fallback, sizeof(fallback),
        "AgentLoop CLI mechanics fixture: stderr error report failed errno=%d; "
        "original report follows:\n",
        stderr_code
    );
    if (prefix < 0 || (size_t)prefix + length > sizeof(fallback)) {
        static const char lost[] =
            "AgentLoop CLI mechanics fixture: stderr error report and fallback "
            "formatting failed\n";
        int stdout_code = 0;
        if (write_all_raw(STDOUT_FILENO, lost, sizeof(lost) - 1,
                          &stdout_code) != 0) {
            return FIXTURE_REPORT_LOST_EXIT;
        }
        return FIXTURE_REPORT_ERROR_EXIT;
    }
    memcpy(fallback + prefix, message, length);
    int stdout_code = 0;
    if (write_all_raw(STDOUT_FILENO, fallback, (size_t)prefix + length,
                      &stdout_code) != 0) {
        return FIXTURE_REPORT_LOST_EXIT;
    }
    return FIXTURE_REPORT_ERROR_EXIT;
}

static bool bounded_equal(const char *value, const char *expected,
                          size_t maximum) {
    if (value == NULL) {
        return false;
    }
    size_t length = strnlen(value, maximum + 1);
    size_t expected_length = strlen(expected);
    return length <= maximum && length == expected_length
        && memcmp(value, expected, length) == 0;
}

static bool bounded_present(const char *value, size_t maximum) {
    return value != NULL && strnlen(value, maximum + 1) <= maximum;
}

static int require_exact_arguments(int argc, int expected,
                                   fixture_errors *errors) {
    if (argc == expected) {
        return 0;
    }
    set_message_failure(errors, "invalid fixture arguments");
    return -1;
}

static int install_ignored_signal(int signal_number, fixture_errors *errors) {
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = SIG_IGN;
    if (sigemptyset(&action.sa_mask) != 0
        || sigaction(signal_number, &action, NULL) != 0) {
        set_system_failure(errors, "signal", errno);
        return -1;
    }
    return 0;
}

static int drain_stdin(fixture_errors *errors) {
    unsigned char bytes[4096];
    for (;;) {
        ssize_t count = read(STDIN_FILENO, bytes, sizeof(bytes));
        if (count > 0) {
            continue;
        }
        if (count == 0) {
            return 0;
        }
        if (errno == EINTR) {
            continue;
        }
        set_system_failure(errors, "stdin read", errno);
        return -1;
    }
}

static int wait_forever(fixture_errors *errors) {
    for (;;) {
        if (pause() == -1 && errno == EINTR) {
            continue;
        }
        set_system_failure(errors, "pause", errno);
        return -1;
    }
}

static int close_owned(int *descriptor, const char *operation,
                       fixture_errors *errors, bool cleanup) {
    if (*descriptor < 0) {
        return 0;
    }
    int owned = *descriptor;
    *descriptor = -1;
    if (close(owned) == 0) {
        return 0;
    }
    if (cleanup) {
        add_cleanup_failure(errors, operation, errno);
    } else {
        set_system_failure(errors, operation, errno);
    }
    return -1;
}

static int create_ready_file(const char *root, const char *leaf,
                             fixture_errors *errors) {
    if (!bounded_present(root, PATH_MAX - 1)
        || (!bounded_equal(leaf, "cold-ready", 32)
            && !bounded_equal(leaf, "resume-ready", 32))) {
        set_message_failure(errors, "fixture readiness authority is invalid");
        return -1;
    }

    struct stat supplied_root;
    if (lstat(root, &supplied_root) != 0) {
        set_system_failure(errors, "readiness root lstat", errno);
        return -1;
    }
    if (!S_ISDIR(supplied_root.st_mode)) {
        set_message_failure(errors, "fixture readiness authority is invalid");
        return -1;
    }

    char resolved_root[PATH_MAX];
    char resolved_tmp[PATH_MAX];
    char allowed_prefix[PATH_MAX];
    char workspace[PATH_MAX];
    char resolved_workspace[PATH_MAX];
    char resolved_cwd[PATH_MAX];
    if (realpath(root, resolved_root) == NULL) {
        set_system_failure(errors, "readiness root realpath", errno);
        return -1;
    }
    if (realpath("/tmp", resolved_tmp) == NULL) {
        set_system_failure(errors, "temporary root realpath", errno);
        return -1;
    }
    int prefix_count = snprintf(allowed_prefix, sizeof(allowed_prefix),
                                "%s/al65-", resolved_tmp);
    int workspace_count = snprintf(workspace, sizeof(workspace), "%s/workspace",
                                   root);
    if (prefix_count < 0 || (size_t)prefix_count >= sizeof(allowed_prefix)
        || workspace_count < 0
        || (size_t)workspace_count >= sizeof(workspace)
        || strncmp(resolved_root, allowed_prefix,
                   (size_t)prefix_count) != 0) {
        set_message_failure(errors, "fixture readiness authority is invalid");
        return -1;
    }
    if (realpath(workspace, resolved_workspace) == NULL) {
        set_system_failure(errors, "readiness workspace realpath", errno);
        return -1;
    }
    if (realpath(".", resolved_cwd) == NULL) {
        set_system_failure(errors, "current workspace realpath", errno);
        return -1;
    }
    if (strcmp(resolved_workspace, resolved_cwd) != 0) {
        set_message_failure(errors, "fixture readiness authority is invalid");
        return -1;
    }

    int root_descriptor = open(root, O_RDONLY | O_DIRECTORY | O_CLOEXEC
                                      | O_NOFOLLOW);
    int ready_descriptor = -1;
    if (root_descriptor < 0) {
        set_system_failure(errors, "readiness root open", errno);
        return -1;
    }
    struct stat root_info;
    if (fstat(root_descriptor, &root_info) != 0) {
        set_system_failure(errors, "readiness root fstat", errno);
        goto cleanup;
    }
    if (!S_ISDIR(root_info.st_mode) || root_info.st_uid != getuid()
        || (root_info.st_mode & 0777) != 0700
        || root_info.st_dev != supplied_root.st_dev
        || root_info.st_ino != supplied_root.st_ino) {
        set_message_failure(errors, "fixture readiness authority is invalid");
        goto cleanup;
    }
    ready_descriptor = openat(root_descriptor, leaf,
                              O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC
                                  | O_NOFOLLOW,
                              0600);
    if (ready_descriptor < 0) {
        set_system_failure(errors, "readiness file open", errno);
        goto cleanup;
    }
    if (close_owned(&ready_descriptor, "readiness file close", errors,
                    false) != 0) {
        goto cleanup;
    }
    if (close_owned(&root_descriptor, "readiness root close", errors,
                    false) != 0) {
        return -1;
    }
    return 0;

cleanup:
    close_owned(&ready_descriptor, "readiness file cleanup close", errors,
                true);
    close_owned(&root_descriptor, "readiness root cleanup close", errors,
                true);
    return -1;
}

static int current_executable(const char *argument, char output[PATH_MAX],
                              fixture_errors *errors) {
    if (!bounded_present(argument, PATH_MAX - 1)) {
        set_system_failure(errors, "current runner identity", EINVAL);
        return -1;
    }
    if (realpath(argument, output) == NULL) {
        set_system_failure(errors, "current runner identity", errno);
        return -1;
    }
    struct stat information;
    if (lstat(output, &information) != 0) {
        set_system_failure(errors, "current runner identity", errno);
        return -1;
    }
    if (!S_ISREG(information.st_mode) || information.st_uid != getuid()
        || information.st_nlink != 1 || (information.st_mode & S_IXUSR) == 0) {
        set_system_failure(errors, "current runner identity", EINVAL);
        return -1;
    }
    return 0;
}

static int normalize_owned_descriptor(int *descriptor, int minimum,
                                      fixture_errors *errors) {
    if (*descriptor < 0) {
        set_system_failure(errors, "ack descriptor", EBADF);
        return -1;
    }
    if (*descriptor >= minimum) {
        if (fcntl(*descriptor, F_SETFD, FD_CLOEXEC) == 0) {
            return 0;
        }
        set_system_failure(errors, "ack cloexec", errno);
        return -1;
    }
    int original = *descriptor;
    int duplicate = fcntl(original, F_DUPFD_CLOEXEC, minimum);
    if (duplicate < 0) {
        set_system_failure(errors, "ack duplicate", errno);
        return -1;
    }
    if (duplicate < minimum) {
        set_system_failure(errors, "ack duplicate", EINVAL);
        if (close(duplicate) != 0) {
            add_cleanup_failure(errors, "ack unexpected duplicate close",
                                errno);
        }
        return -1;
    }
    *descriptor = duplicate;
    if (close(original) != 0) {
        set_system_failure(errors, "ack original close", errno);
        return -1;
    }
    return 0;
}

static void record_release_failure(fixture_errors *errors,
                                   const char *operation, int code,
                                   bool cleanup_only) {
    if (cleanup_only || errors->has_primary) {
        add_cleanup_failure(errors, operation, code);
    } else {
        set_system_failure(errors, operation, code);
    }
}

static void release_spawn_structures(posix_spawn_file_actions_t *actions,
                                     bool *actions_initialized,
                                     posix_spawnattr_t *attributes,
                                     bool *attributes_initialized,
                                     fixture_errors *errors,
                                     bool cleanup_only) {
    if (*attributes_initialized) {
        *attributes_initialized = false;
        int code = posix_spawnattr_destroy(attributes);
        if (code != 0) {
            record_release_failure(errors, "spawn attributes destroy", code,
                                   cleanup_only);
        }
    }
    if (*actions_initialized) {
        *actions_initialized = false;
        int code = posix_spawn_file_actions_destroy(actions);
        if (code != 0) {
            record_release_failure(errors, "spawn actions destroy", code,
                                   cleanup_only);
        }
    }
}

static int terminate_owned_child(pid_t child, fixture_errors *errors) {
    if (kill(child, SIGKILL) != 0 && errno != ESRCH) {
        add_cleanup_failure(errors, "child kill", errno);
        return -1;
    }
    int status = 0;
    for (;;) {
        pid_t result = waitpid(child, &status, 0);
        if (result == child || (result < 0 && errno == ECHILD)) {
            return 0;
        }
        if (result < 0 && errno == EINTR) {
            continue;
        }
        add_cleanup_failure(errors, "child reap",
                            result < 0 ? errno : ECHILD);
        return -1;
    }
}

static int read_acknowledgement(int descriptor, fixture_errors *errors) {
    unsigned char acknowledgement = 0;
    for (;;) {
        ssize_t count = read(descriptor, &acknowledgement, 1);
        if (count == 1) {
            if (acknowledgement == 0x41) {
                return 0;
            }
            set_message_failure(errors,
                                "fixture child acknowledgement was invalid");
            return -1;
        }
        if (count < 0 && errno == EINTR) {
            continue;
        }
        if (count == 0) {
            set_message_failure(errors,
                                "fixture child acknowledgement was invalid");
        } else {
            set_system_failure(errors, "ack read", errno);
        }
        return -1;
    }
}

static int check_spawn_setup(int code, fixture_errors *errors) {
    if (code == 0) {
        return 0;
    }
    set_system_failure(errors, "spawn setup", code);
    return -1;
}

static int run_held_stderr_parent(const char *self_argument,
                                  fixture_errors *errors) {
    int pipe_descriptors[2] = {-1, -1};
    if (pipe(pipe_descriptors) != 0) {
        set_system_failure(errors, "ack pipe", errno);
        return -1;
    }
    int read_descriptor = pipe_descriptors[0];
    int write_descriptor = pipe_descriptors[1];
    posix_spawn_file_actions_t actions;
    posix_spawnattr_t attributes;
    bool actions_initialized = false;
    bool attributes_initialized = false;
    pid_t child = 0;
    bool owns_child = false;
    char executable[PATH_MAX];

    if (normalize_owned_descriptor(&read_descriptor, 4, errors) != 0
        || normalize_owned_descriptor(&write_descriptor, 4, errors) != 0) {
        goto cleanup;
    }
    int code = posix_spawn_file_actions_init(&actions);
    if (code != 0) {
        set_system_failure(errors, "spawn actions init", code);
        goto cleanup;
    }
    actions_initialized = true;
    if (check_spawn_setup(
            posix_spawn_file_actions_addclose(&actions, read_descriptor),
            errors) != 0
        || check_spawn_setup(posix_spawn_file_actions_addopen(
               &actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0), errors) != 0
        || check_spawn_setup(posix_spawn_file_actions_addopen(
               &actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0), errors) != 0
        || check_spawn_setup(posix_spawn_file_actions_adddup2(
               &actions, STDERR_FILENO, STDERR_FILENO), errors) != 0
        || check_spawn_setup(posix_spawn_file_actions_adddup2(
               &actions, write_descriptor, 3), errors) != 0
        || check_spawn_setup(posix_spawn_file_actions_addclose(
               &actions, write_descriptor), errors) != 0) {
        goto cleanup;
    }

    code = posix_spawnattr_init(&attributes);
    if (code != 0) {
        set_system_failure(errors, "spawn attributes init", code);
        goto cleanup;
    }
    attributes_initialized = true;
    sigset_t default_signals;
    sigset_t signal_mask;
    if (sigemptyset(&default_signals) != 0
        || sigaddset(&default_signals, SIGTERM) != 0
        || sigemptyset(&signal_mask) != 0) {
        set_system_failure(errors, "spawn signals", errno);
        goto cleanup;
    }
    if (check_spawn_setup(posix_spawnattr_setsigdefault(
                              &attributes, &default_signals), errors) != 0
        || check_spawn_setup(posix_spawnattr_setsigmask(
               &attributes, &signal_mask), errors) != 0
        || check_spawn_setup(posix_spawnattr_setflags(
               &attributes,
               (short)(POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF
                       | POSIX_SPAWN_SETSIGMASK)), errors) != 0) {
        goto cleanup;
    }
    if (current_executable(self_argument, executable, errors) != 0) {
        goto cleanup;
    }

    char *child_arguments[] = {
        executable,
        FIXTURE_SWITCH,
        MODE_HELD_STDERR_CHILD,
        "3",
        NULL,
    };
    char *child_environment[] = {
        "LC_ALL=C",
        "PATH=/usr/bin:/bin",
        NULL,
    };
    code = posix_spawn(&child, executable, &actions, &attributes,
                       child_arguments, child_environment);
    if (code != 0) {
        set_system_failure(errors, "spawn held child", code);
        goto cleanup;
    }
    owns_child = true;
    release_spawn_structures(&actions, &actions_initialized, &attributes,
                             &attributes_initialized, errors, false);
    if (errors->has_primary) {
        goto cleanup;
    }
    if (close_owned(&write_descriptor, "parent ack write close", errors,
                    false) != 0
        || read_acknowledgement(read_descriptor, errors) != 0) {
        goto cleanup;
    }
    if (getpgid(child) != getpgrp()) {
        set_message_failure(errors,
                            "fixture child did not inherit the parent process group");
        goto cleanup;
    }
    if (close_owned(&read_descriptor, "parent ack read close", errors,
                    false) != 0
        || write_fixture(STDOUT_FILENO, "parent-exited\n",
                         sizeof("parent-exited\n") - 1, errors) != 0) {
        goto cleanup;
    }
    owns_child = false;
    return 0;

cleanup:
    release_spawn_structures(&actions, &actions_initialized, &attributes,
                             &attributes_initialized, errors, true);
    if (owns_child) {
        terminate_owned_child(child, errors);
    }
    close_owned(&read_descriptor, "parent ack read cleanup close", errors,
                true);
    close_owned(&write_descriptor, "parent ack write cleanup close", errors,
                true);
    return -1;
}

static int run_held_stderr_child(int argc, char *argv[],
                                 fixture_errors *errors) {
    if (require_exact_arguments(argc, 4, errors) != 0
        || !bounded_equal(argv[3], "3", 8)
        || fcntl(3, F_GETFD) < 0) {
        if (!errors->has_primary) {
            set_message_failure(errors, "invalid fixture arguments");
        }
        return -1;
    }
    unsigned char acknowledgement = 0x41;
    if (write_fixture(3, &acknowledgement, 1, errors) != 0) {
        return -1;
    }
    int descriptor = 3;
    if (close_owned(&descriptor, "child ack close", errors, false) != 0) {
        return -1;
    }
    return wait_forever(errors);
}

static int report_environment(fixture_errors *errors) {
    const char *sentinel = getenv("AGENTLOOP_FIXTURE_SENTINEL");
    const char *path = getenv("PATH");
    const char *locale = getenv("LC_ALL");
    const char *home = getenv("HOME");
    const char *temporary = getenv("TMPDIR");
    if (!bounded_equal(sentinel, "present", 64)) {
        set_message_failure(errors, "fixture environment sentinel is invalid");
        return -1;
    }
    char report[128];
    int count = snprintf(
        report, sizeof(report),
        "environment-sentinel=present;path=%d;locale=%d;home=%d;tmpdir=%d\n",
        bounded_equal(path, "/usr/bin:/bin", 256) ? 1 : 0,
        bounded_equal(locale, "C", 64) ? 1 : 0,
        bounded_present(home, PATH_MAX - 1) ? 1 : 0,
        bounded_present(temporary, PATH_MAX - 1) ? 1 : 0
    );
    if (count < 0 || (size_t)count >= sizeof(report)) {
        set_message_failure(errors, "fixture environment report is invalid");
        return -1;
    }
    return write_fixture(STDOUT_FILENO, report, (size_t)count, errors);
}

static int run_mode(int argc, char *argv[], fixture_errors *errors) {
    const char *mode = argv[2];
    if (bounded_equal(mode, MODE_EXIT_ZERO, 64)) {
        return require_exact_arguments(argc, 3, errors) == 0
            ? drain_stdin(errors) : -1;
    }
    if (bounded_equal(mode, MODE_PRINT_FINAL_LINE, 64)) {
        if (require_exact_arguments(argc, 3, errors) != 0
            || drain_stdin(errors) != 0) {
            return -1;
        }
        return write_fixture(STDOUT_FILENO, "final-line",
                             sizeof("final-line") - 1, errors);
    }
    if (bounded_equal(mode, MODE_WAIT_TERM, 64)) {
        if (require_exact_arguments(argc, 3, errors) != 0
            || drain_stdin(errors) != 0
            || write_fixture(STDOUT_FILENO, "ready\n",
                             sizeof("ready\n") - 1, errors) != 0) {
            return -1;
        }
        return wait_forever(errors);
    }
    if (bounded_equal(mode, MODE_IGNORE_TERM, 64)) {
        if (require_exact_arguments(argc, 3, errors) != 0
            || install_ignored_signal(SIGTERM, errors) != 0
            || drain_stdin(errors) != 0
            || write_fixture(STDOUT_FILENO, "ready\n",
                             sizeof("ready\n") - 1, errors) != 0) {
            return -1;
        }
        return wait_forever(errors);
    }
    if (bounded_equal(mode, MODE_READY_FILE_IGNORE_TERM, 64)) {
        if (require_exact_arguments(argc, 5, errors) != 0
            || install_ignored_signal(SIGTERM, errors) != 0
            || drain_stdin(errors) != 0
            || create_ready_file(argv[3], argv[4], errors) != 0) {
            return -1;
        }
        return wait_forever(errors);
    }
    if (bounded_equal(mode, MODE_READY_FILE, 64)) {
        if (require_exact_arguments(argc, 5, errors) != 0
            || create_ready_file(argv[3], argv[4], errors) != 0) {
            return -1;
        }
        /* The pre-registration inspector must observe this before stdin exists. */
        return wait_forever(errors);
    }
    if (bounded_equal(mode, MODE_READY_AND_DRAIN_IGNORE_TERM, 64)) {
        if (require_exact_arguments(argc, 3, errors) != 0
            || install_ignored_signal(SIGTERM, errors) != 0
            || drain_stdin(errors) != 0
            || write_fixture(STDOUT_FILENO, "p1f1d-ready\n",
                             sizeof("p1f1d-ready\n") - 1, errors) != 0
            || write_fixture(STDERR_FILENO, "p1f1d-drain\n",
                             sizeof("p1f1d-drain\n") - 1, errors) != 0) {
            return -1;
        }
        return wait_forever(errors);
    }
    if (bounded_equal(mode, MODE_HELD_STDERR_PARENT, 64)) {
        if (require_exact_arguments(argc, 3, errors) != 0
            || drain_stdin(errors) != 0) {
            return -1;
        }
        return run_held_stderr_parent(argv[0], errors);
    }
    if (bounded_equal(mode, MODE_HELD_STDERR_CHILD, 64)) {
        return run_held_stderr_child(argc, argv, errors);
    }
    if (bounded_equal(mode, MODE_ENVIRONMENT_SENTINEL, 64)) {
        if (require_exact_arguments(argc, 3, errors) != 0
            || drain_stdin(errors) != 0) {
            return -1;
        }
        return report_environment(errors);
    }
    set_message_failure(errors, "invalid fixture arguments");
    return -1;
}

int main(int argc, char *argv[]) {
    fixture_errors errors = {0};
    if (install_ignored_signal(SIGPIPE, &errors) != 0) {
        return report_errors(&errors);
    }
    if (argc < 3 || argc > 5 || argv[0] == NULL || argv[1] == NULL
        || argv[2] == NULL || !bounded_present(argv[0], PATH_MAX - 1)
        || !bounded_equal(argv[1], FIXTURE_SWITCH, 64)
        || !bounded_present(argv[2], 64)) {
        set_message_failure(&errors, "invalid fixture arguments");
        return report_errors(&errors);
    }
    if (run_mode(argc, argv, &errors) == 0) {
        return EXIT_SUCCESS;
    }
    return report_errors(&errors);
}
