#!/bin/bash

# Bash 3.2-safe micro-probes for the R17 status-capture patterns.
# This script does not invoke the R17 driver or any product command.

set -Eeuo pipefail
set -f
IFS=$' \t\n'

r17_probe_err_stolen() {
  local r17_probe_rc="$?"
  local r17_probe_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  /usr/bin/printf 'FAIL: global ERR trap stole status rc=%s command=%q\n' \
    "${r17_probe_rc}" "${r17_probe_command}" >&2
  exit 97
}

r17_probe_fail() {
  trap - ERR
  /usr/bin/printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

r17_probe_return_two() {
  return 2
}

r17_probe_pipeline_producer_failure() {
  /usr/bin/printf 'x'
  return 7
}

r17_probe_command_substitution_failure() {
  /usr/bin/printf 'c-failure'
  return 9
}

trap r17_probe_err_stolen ERR

if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r17_probe_fail "Bash 3.2 or newer is required"
fi

# S-success: a successful simple command must report zero without invoking ERR.
if /usr/bin/true; then
  r17_s_success_rc=0
else
  r17_s_success_rc="$?"
fi
if [[ "${r17_s_success_rc}" -ne 0 ]]; then
  r17_probe_fail "S-success captured rc=${r17_s_success_rc}, expected 0"
fi

# S-pgrep: rc=1 means the uniquely named process is absent and is a clean path.
r17_absent_process_name="R17NoSuch$$"
if /usr/bin/pgrep -x "${r17_absent_process_name}" >/dev/null 2>&1; then
  r17_pgrep_rc=0
else
  r17_pgrep_rc="$?"
fi
if [[ "${r17_pgrep_rc}" -ne 1 ]]; then
  r17_probe_fail "S-pgrep captured rc=${r17_pgrep_rc}, expected absent rc=1"
fi

# S-indeterminate: preserve an arbitrary nonzero status for fail-closed routing.
if r17_probe_return_two; then
  r17_indeterminate_rc=0
else
  r17_indeterminate_rc="$?"
fi
if [[ "${r17_indeterminate_rc}" -ne 2 ]]; then
  r17_probe_fail "S-indeterminate captured rc=${r17_indeterminate_rc}, expected 2"
fi

# S-diff: rc=1 is a meaningful mismatch, not an unexpected ERR-trap event.
if /usr/bin/diff -u \
  <(/usr/bin/printf '%s\n' "expected") \
  <(/usr/bin/printf '%s\n' "actual") \
  >/dev/null 2>&1; then
  r17_diff_rc=0
else
  r17_diff_rc="$?"
fi
if [[ "${r17_diff_rc}" -ne 1 ]]; then
  r17_probe_fail "S-diff captured rc=${r17_diff_rc}, expected mismatch rc=1"
fi

# P-success: PIPESTATUS must be copied immediately in the selected branch.
if /usr/bin/printf 'ok' | /usr/bin/wc -c >/dev/null; then
  r17_pipeline_success_status=( "${PIPESTATUS[@]}" )
else
  r17_pipeline_success_status=( "${PIPESTATUS[@]}" )
fi
if [[ "${#r17_pipeline_success_status[@]}" -ne 2 ||
      "${r17_pipeline_success_status[0]}" -ne 0 ||
      "${r17_pipeline_success_status[1]}" -ne 0 ]]; then
  r17_probe_fail "P-success did not preserve PIPESTATUS=(0 0)"
fi

# P-failure: preserve the failing producer even though the consumer succeeds.
if r17_probe_pipeline_producer_failure |
  /usr/bin/wc -c >/dev/null; then
  r17_pipeline_failure_status=( "${PIPESTATUS[@]}" )
else
  r17_pipeline_failure_status=( "${PIPESTATUS[@]}" )
fi
if [[ "${#r17_pipeline_failure_status[@]}" -ne 2 ||
      "${r17_pipeline_failure_status[0]}" -ne 7 ||
      "${r17_pipeline_failure_status[1]}" -ne 0 ]]; then
  r17_probe_fail "P-failure did not preserve PIPESTATUS=(7 0)"
fi

# C-success: locally remove inherited ERR before the command substitution.
if r17_command_substitution_output="$(
  trap - ERR
  /usr/bin/printf 'c-success'
)"; then
  r17_command_substitution_success_rc=0
else
  r17_command_substitution_success_rc="$?"
fi
if [[ "${r17_command_substitution_success_rc}" -ne 0 ||
      "${r17_command_substitution_output}" != "c-success" ]]; then
  r17_probe_fail "C-success did not preserve rc=0 and exact output"
fi

# C-failure: preserve the substitution's status and output without firing ERR.
if r17_command_substitution_output="$(
  trap - ERR
  r17_probe_command_substitution_failure
)"; then
  r17_command_substitution_failure_rc=0
else
  r17_command_substitution_failure_rc="$?"
fi
if [[ "${r17_command_substitution_failure_rc}" -ne 9 ||
      "${r17_command_substitution_output}" != "c-failure" ]]; then
  r17_probe_fail "C-failure did not preserve rc=9 and exact output"
fi

# C-pipeline: pipefail must expose a failed component through the substitution.
if r17_command_substitution_output="$(
  trap - ERR
  r17_probe_pipeline_producer_failure |
    /usr/bin/wc -c |
    /usr/bin/tr -d '[:space:]'
)"; then
  r17_command_substitution_pipeline_rc=0
else
  r17_command_substitution_pipeline_rc="$?"
fi
if [[ "${r17_command_substitution_pipeline_rc}" -ne 7 ||
      "${r17_command_substitution_output}" != "1" ]]; then
  r17_probe_fail "C-pipeline did not preserve component failure rc=7 and output=1"
fi

/usr/bin/printf 'PASS: Bash %s S/P/C status capture; pgrep=1 diff=1 indeterminate=2 pipeline=(7 0) command_substitution=9 command_substitution_pipeline=7\n' \
  "${BASH_VERSION}"
