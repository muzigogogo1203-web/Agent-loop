#!/bin/bash

# Reviewed R16 BEGIN-only driver.
# This file does not run tests, build, migration matrix, source gates, bundle
# assembly, signing, or preview. It establishes one fail-once evidence boundary.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R16_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R16_TASK_DIRECTORY="${R16_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R16_DRIVER_PATH="${R16_TASK_DIRECTORY}/evidence/r16-begin.sh"
readonly R16_MANIFEST_PATH="${R16_TASK_DIRECTORY}/evidence/r16-entry.sha256"
readonly R16_FREEZE_PATH="${R16_TASK_DIRECTORY}/evidence/plan-freeze-r16.md"
readonly R16_REVIEW16_PATH="${R16_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/16-p1-plan-review.md"
readonly R16_BOUNDARY_LOG="${R16_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
readonly R16_HASH_LOG="${R16_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
readonly R16_RANCH_ART_DIRECTORY="${R16_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R16_EXPECTED_MANIFEST_COUNT="110"
readonly R16_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R16_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R16_EXPECTED_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R16_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R16_R15_STATE_ROOT="/private/tmp/agentloop-r15-state.Zq6Jvm"
readonly R16_R15_BUNDLE_PARENT="/private/tmp/agentloop-r15-bundle.2xROcy"
readonly R16_R15_PLANNED_APP="${R16_R15_BUNDLE_PARENT}/AgentLoop.app"
readonly R16_R15_SCREENSHOT="${R16_TASK_DIRECTORY}/evidence/r15-preview-smoke.png"

R16_BOUNDARY_ACTIVE="false"
R16_PHASE="pre_begin"
R16_INVOCATION_ID=""
R16_STATE_ROOT=""
R16_BUNDLE_PARENT=""

r16_utc_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r16_pre_begin_fail() {
  local r16_exit_code="$1"
  shift
  /usr/bin/printf 'R16 pre-BEGIN rejected: %s\n' "$*" >&2
  exit "$r16_exit_code"
}

r16_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R16_BOUNDARY_LOG}"
}

r16_authorization_is_consumed() {
  if [[ "${R16_BOUNDARY_ACTIVE}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${R16_INVOCATION_ID}" &&
        -f "${R16_BOUNDARY_LOG}" &&
        ! -L "${R16_BOUNDARY_LOG}" ]] &&
     /usr/bin/grep -Fx "invocation_id=${R16_INVOCATION_ID}" "${R16_BOUNDARY_LOG}" >/dev/null 2>&1 &&
     /usr/bin/grep -Fx 'authorization_consumed=true' "${R16_BOUNDARY_LOG}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

r16_active_fail() {
  local r16_exit_code="$1"
  local r16_reason="$2"
  local r16_command="${3:-explicit_fail_closed}"
  trap - ERR HUP INT TERM
  set +e
  r16_append_boundary "utc=$(r16_utc_now)"
  r16_append_boundary "status=REJECTED_CONTAMINATED"
  r16_append_boundary "phase=${R16_PHASE}"
  r16_append_boundary "reason=${r16_reason}"
  printf 'failed_command=%q\n' "${r16_command}" >> "${R16_BOUNDARY_LOG}"
  r16_append_boundary "exit_code=${r16_exit_code}"
  r16_append_boundary "state_root=${R16_STATE_ROOT:-UNCREATED}"
  r16_append_boundary "bundle_parent=${R16_BUNDLE_PARENT:-UNCREATED}"
  if [[ -n "${R16_PLANNED_APP:-}" ]]; then
    r16_append_boundary "planned_app=${R16_PLANNED_APP}"
  fi
  r16_append_boundary "retry_same_boundary=false"
  /usr/bin/printf 'R16 rejected after authorization consumption: %s\n' "${r16_reason}" >&2
  exit "$r16_exit_code"
}

r16_unexpected_error() {
  local r16_exit_code="$?"
  local r16_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  if r16_authorization_is_consumed; then
    r16_active_fail "${r16_exit_code}" "unexpected_command_failure" "${r16_command}"
  fi
  printf 'R16 pre-BEGIN command failed: phase=%s rc=%s command=%q\n' \
    "${R16_PHASE}" "${r16_exit_code}" "${r16_command}" >&2
  exit "${r16_exit_code}"
}

r16_signal_error() {
  local r16_signal="$1"
  trap - HUP INT TERM
  if r16_authorization_is_consumed; then
    r16_active_fail "74" "signal_${r16_signal}" "signal_${r16_signal}"
  fi
  /usr/bin/printf 'R16 pre-BEGIN interrupted by signal %s\n' "${r16_signal}" >&2
  exit 74
}

trap r16_unexpected_error ERR
trap 'r16_signal_error HUP' HUP
trap 'r16_signal_error INT' INT
trap 'r16_signal_error TERM' TERM

r16_attestation_fail() {
  local r16_exit_code="$1"
  shift
  if r16_authorization_is_consumed; then
    r16_active_fail "${r16_exit_code}" "$*"
  fi
  r16_pre_begin_fail "${r16_exit_code}" "$*"
}

r16_require_lowercase_sha256() {
  local r16_value="$1"
  local r16_label="$2"
  if [[ "${#r16_value}" -ne 64 ]]; then
    r16_pre_begin_fail 64 "${r16_label} must be exactly 64 lowercase hex characters"
  fi
  case "${r16_value}" in
    *[!0-9a-f]*)
      r16_pre_begin_fail 64 "${r16_label} must be exactly 64 lowercase hex characters"
      ;;
  esac
}

r16_emit_anchor_manifest() {
  /usr/bin/printf '%s  %s\n' "${R16_EXPECTED_FREEZE_SHA}" "${R16_FREEZE_PATH}"
  /usr/bin/printf '%s  %s\n' "${R16_EXPECTED_REVIEW16_SHA}" "${R16_REVIEW16_PATH}"
  /usr/bin/printf '%s  %s\n' "${R16_EXPECTED_DRIVER_SHA}" "${R16_DRIVER_PATH}"
  /usr/bin/printf '%s  %s\n' "${R16_EXPECTED_MANIFEST_SHA}" "${R16_MANIFEST_PATH}"
}

r16_check_anchors_to_stdout() {
  local -a r16_anchor_status
  set +e
  r16_emit_anchor_manifest | /usr/bin/shasum -a 256 --strict -c -
  r16_anchor_status=( "${PIPESTATUS[@]}" )
  set -e
  if [[ "${r16_anchor_status[0]}" -ne 0 || "${r16_anchor_status[1]}" -ne 0 ]]; then
    r16_pre_begin_fail 65 "terminal anchor verification failed with producer_rc=${r16_anchor_status[0]} shasum_rc=${r16_anchor_status[1]}"
  fi
}

r16_check_manifest_shape() {
  local r16_manifest_count
  if [[ ! -f "${R16_MANIFEST_PATH}" || -L "${R16_MANIFEST_PATH}" ]]; then
    r16_attestation_fail 66 "static manifest is missing, non-regular, or a symlink"
  fi
  r16_manifest_count="$(/usr/bin/wc -l < "${R16_MANIFEST_PATH}" | /usr/bin/tr -d '[:space:]')"
  if [[ "${r16_manifest_count}" != "${R16_EXPECTED_MANIFEST_COUNT}" ]]; then
    r16_attestation_fail 66 "static manifest entry count is ${r16_manifest_count}, expected ${R16_EXPECTED_MANIFEST_COUNT}"
  fi
  if /usr/bin/grep -F -- "  ${R16_MANIFEST_PATH}" "${R16_MANIFEST_PATH}" >/dev/null 2>&1; then
    r16_attestation_fail 66 "static manifest must not contain itself"
  fi
  if /usr/bin/grep -F -- "  ${R16_FREEZE_PATH}" "${R16_MANIFEST_PATH}" >/dev/null 2>&1; then
    r16_attestation_fail 66 "static manifest must not contain the R16 freeze"
  fi
  if /usr/bin/grep -F -- "  ${R16_REVIEW16_PATH}" "${R16_MANIFEST_PATH}" >/dev/null 2>&1; then
    r16_attestation_fail 66 "static manifest must not contain Review16"
  fi
  if ! /usr/bin/cut -c 67- "${R16_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r16_attestation_fail 66 "static manifest paths are not bytewise sorted and unique"
  fi
  while IFS= read -r r16_manifest_line; do
    local r16_manifest_entry_path="${r16_manifest_line#*  }"
    case "${r16_manifest_entry_path}" in
      "${R16_REPOSITORY_ROOT}"/*)
        ;;
      *)
        r16_attestation_fail 66 "static manifest entry is outside the repository"
        ;;
    esac
    case "${r16_manifest_entry_path}" in
      *"/../"*|*"/./"*|*/..|*/.)
        r16_attestation_fail 66 "static manifest entry contains a non-canonical path segment"
        ;;
    esac
    if [[ ! -f "${r16_manifest_entry_path}" || -L "${r16_manifest_entry_path}" ]]; then
      r16_attestation_fail 66 "static manifest entry is non-regular or a symlink: ${r16_manifest_entry_path}"
    fi
  done < "${R16_MANIFEST_PATH}"
}

r16_check_manifest_to_stdout() {
  local r16_manifest_rc
  set +e
  /usr/bin/shasum -a 256 --strict -c "${R16_MANIFEST_PATH}"
  r16_manifest_rc="$?"
  set -e
  if [[ "${r16_manifest_rc}" -ne 0 ]]; then
    r16_pre_begin_fail 66 "static manifest verification failed with rc=${r16_manifest_rc}"
  fi
}

r16_require_process_absent() {
  local r16_process_name="$1"
  local r16_process_rc
  set +e
  /usr/bin/pgrep -x "${r16_process_name}" >/dev/null 2>&1
  r16_process_rc="$?"
  set -e
  case "${r16_process_rc}" in
    1)
      ;;
    0)
      r16_attestation_fail 69 "${r16_process_name} process is present"
      ;;
    *)
      r16_attestation_fail 69 "pgrep for ${r16_process_name} was indeterminate with rc=${r16_process_rc}"
      ;;
  esac
}

r16_require_absent_path() {
  local r16_path="$1"
  if [[ -e "${r16_path}" || -L "${r16_path}" ]]; then
    r16_pre_begin_fail 68 "runtime artifact already exists: ${r16_path}"
  fi
}

r16_probe_empty_directory() {
  local r16_path="$1"
  local r16_probe_output
  local r16_probe_rc
  set +e
  r16_probe_output="$(/usr/bin/find "${r16_path}" -mindepth 1 -maxdepth 1 -print -quit 2>&1)"
  r16_probe_rc="$?"
  set -e
  if [[ "${r16_probe_rc}" -ne 0 ]]; then
    return 2
  fi
  if [[ -n "${r16_probe_output}" ]]; then
    return 1
  fi
  return 0
}

r16_require_empty_preserved_directory() {
  local r16_path="$1"
  local r16_probe_rc
  local r16_realpath
  local r16_realpath_rc
  if [[ ! -d "${r16_path}" || -L "${r16_path}" ]]; then
    r16_pre_begin_fail 70 "preserved R15 root is missing, non-directory, or symlink: ${r16_path}"
  fi
  set +e
  r16_realpath="$(/bin/realpath "${r16_path}" 2>&1)"
  r16_realpath_rc="$?"
  set -e
  if [[ "${r16_realpath_rc}" -ne 0 ]]; then
    r16_pre_begin_fail 70 "preserved R15 root realpath probe failed: ${r16_path}"
  fi
  if [[ "${r16_realpath}" != "${r16_path}" ]]; then
    r16_pre_begin_fail 70 "preserved R15 root realpath drifted: ${r16_path}"
  fi
  if r16_probe_empty_directory "${r16_path}"; then
    return 0
  else
    r16_probe_rc="$?"
  fi
  if [[ "${r16_probe_rc}" -eq 1 ]]; then
    r16_pre_begin_fail 70 "preserved R15 root is not empty: ${r16_path}"
  fi
  r16_pre_begin_fail 70 "preserved R15 root emptiness probe was indeterminate: ${r16_path}"
}

r16_exclusive_create_empty() {
  local r16_path="$1"
  ( set -C; : > "${r16_path}" )
}

r16_require_fresh_root() {
  local r16_path="$1"
  local r16_label="$2"
  local r16_probe_rc
  local r16_realpath
  local r16_realpath_rc
  if [[ ! -d "${r16_path}" || -L "${r16_path}" ]]; then
    r16_active_fail 72 "${r16_label}_invalid_type"
  fi
  set +e
  r16_realpath="$(/bin/realpath "${r16_path}" 2>&1)"
  r16_realpath_rc="$?"
  set -e
  if [[ "${r16_realpath_rc}" -ne 0 ]]; then
    r16_active_fail 72 "${r16_label}_realpath_probe_failed"
  fi
  if [[ "${r16_realpath}" != "${r16_path}" ]]; then
    r16_active_fail 72 "${r16_label}_realpath_mismatch"
  fi
  if r16_probe_empty_directory "${r16_path}"; then
    return 0
  else
    r16_probe_rc="$?"
  fi
  if [[ "${r16_probe_rc}" -eq 1 ]]; then
    r16_active_fail 72 "${r16_label}_not_empty"
  fi
  r16_active_fail 72 "${r16_label}_emptiness_probe_indeterminate"
}

r16_post_activation_anchor_check() {
  local -a r16_anchor_status
  {
    /usr/bin/printf '%s\n' "section=terminal_anchors"
    r16_emit_anchor_manifest
  } >> "${R16_HASH_LOG}"
  set +e
  r16_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c - >> "${R16_HASH_LOG}" 2>&1
  r16_anchor_status=( "${PIPESTATUS[@]}" )
  set -e
  /usr/bin/printf 'terminal_anchor_producer_rc=%s\n' "${r16_anchor_status[0]}" >> "${R16_HASH_LOG}"
  /usr/bin/printf 'terminal_anchor_shasum_rc=%s\n' "${r16_anchor_status[1]}" >> "${R16_HASH_LOG}"
  if [[ "${r16_anchor_status[0]}" -ne 0 || "${r16_anchor_status[1]}" -ne 0 ]]; then
    r16_active_fail 65 "post_activation_terminal_anchor_failure_producer_${r16_anchor_status[0]}_shasum_${r16_anchor_status[1]}"
  fi
}

r16_post_activation_manifest_check() {
  local r16_manifest_rc
  local r16_manifest_count
  r16_manifest_count="$(/usr/bin/wc -l < "${R16_MANIFEST_PATH}" | /usr/bin/tr -d '[:space:]')"
  /usr/bin/printf '%s\n' "section=static_manifest" >> "${R16_HASH_LOG}"
  /usr/bin/printf 'static_manifest_expected_count=%s\n' "${R16_EXPECTED_MANIFEST_COUNT}" >> "${R16_HASH_LOG}"
  /usr/bin/printf 'static_manifest_actual_count=%s\n' "${r16_manifest_count}" >> "${R16_HASH_LOG}"
  set +e
  /usr/bin/shasum -a 256 --strict -c "${R16_MANIFEST_PATH}" >> "${R16_HASH_LOG}" 2>&1
  r16_manifest_rc="$?"
  set -e
  /usr/bin/printf 'static_manifest_rc=%s\n' "${r16_manifest_rc}" >> "${R16_HASH_LOG}"
  if [[ "${r16_manifest_rc}" -ne 0 ]]; then
    r16_active_fail 66 "post_activation_static_manifest_failure_rc_${r16_manifest_rc}"
  fi
  if [[ "${r16_manifest_count}" != "${R16_EXPECTED_MANIFEST_COUNT}" ]]; then
    r16_active_fail 66 "post_activation_static_manifest_count_${r16_manifest_count}"
  fi
}

r16_check_ranch_art_structure() {
  local r16_expected_paths
  local r16_raw_paths
  local r16_actual_paths
  local r16_find_rc
  local r16_transform_rc
  local r16_diff_rc
  local r16_unexpected_node
  local r16_unexpected_rc
  local r16_regular_count
  local r16_count_rc
  /usr/bin/printf '%s\n' "section=ranch_art_structure" >> "${R16_HASH_LOG}"

  r16_expected_paths="$(
    /usr/bin/printf '%s\n' \
      "PixelBarnDay.png" \
      "PixelBarnNight.png" \
      "PixelCowSideAmber.png" \
      "PixelCowSideBlue.png" \
      "PixelCowSideCoral.png" \
      "PixelCowSideGreen.png" \
      "PixelCowSidePink.png" \
      "PixelCowSidePurple.png" \
      "PixelCowSideTeal.png" \
      "PixelCowSleepAmber.png" \
      "PixelCowSleepBlue.png" \
      "PixelCowSleepCoral.png" \
      "PixelCowSleepGreen.png" \
      "PixelCowSleepPink.png" \
      "PixelCowSleepPurple.png" \
      "PixelCowSleepTeal.png" \
      "PixelCowStrideAmber.png" \
      "PixelCowStrideBlue.png" \
      "PixelCowStrideCoral.png" \
      "PixelCowStrideGreen.png" \
      "PixelCowStridePink.png" \
      "PixelCowStridePurple.png" \
      "PixelCowStrideTeal.png" \
      "PixelPanoramaDay.png" \
      "PixelPanoramaNight.png" \
      "PixelPastureDay.png" \
      "PixelPastureNight.png"
  )"

  set +e
  r16_raw_paths="$(
    /usr/bin/find "${R16_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 -type f -print 2>&1
  )"
  r16_find_rc="$?"
  set -e
  /usr/bin/printf 'ranch_art_file_find_rc=%s\n' "${r16_find_rc}" >> "${R16_HASH_LOG}"
  if [[ "${r16_find_rc}" -ne 0 ]]; then
    /usr/bin/printf 'ranch_art_file_find_output=%s\n' "${r16_raw_paths}" >> "${R16_HASH_LOG}"
    r16_active_fail 70 "ranch_art_file_find_indeterminate_rc_${r16_find_rc}"
  fi

  set +e
  r16_actual_paths="$(
    /usr/bin/printf '%s\n' "${r16_raw_paths}" |
      /usr/bin/sed "s#^${R16_RANCH_ART_DIRECTORY}/##" |
      LC_ALL=C /usr/bin/sort
  )"
  r16_transform_rc="$?"
  set -e
  /usr/bin/printf 'ranch_art_path_transform_rc=%s\n' "${r16_transform_rc}" >> "${R16_HASH_LOG}"
  if [[ "${r16_transform_rc}" -ne 0 ]]; then
    r16_active_fail 70 "ranch_art_path_transform_indeterminate_rc_${r16_transform_rc}"
  fi

  set +e
  /usr/bin/diff -u \
    <(/usr/bin/printf '%s\n' "${r16_expected_paths}") \
    <(/usr/bin/printf '%s\n' "${r16_actual_paths}") \
    >> "${R16_HASH_LOG}" 2>&1
  r16_diff_rc="$?"
  set -e
  /usr/bin/printf 'ranch_art_path_set_diff_rc=%s\n' "${r16_diff_rc}" >> "${R16_HASH_LOG}"
  if [[ "${r16_diff_rc}" -ne 0 ]]; then
    r16_active_fail 70 "ranch_art_exact_path_set_mismatch_rc_${r16_diff_rc}"
  fi

  set +e
  r16_unexpected_node="$(
    /usr/bin/find "${R16_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 ! -type f -print -quit 2>&1
  )"
  r16_unexpected_rc="$?"
  set -e
  /usr/bin/printf 'ranch_art_nonregular_find_rc=%s\n' "${r16_unexpected_rc}" >> "${R16_HASH_LOG}"
  if [[ "${r16_unexpected_rc}" -ne 0 ]]; then
    /usr/bin/printf 'ranch_art_nonregular_find_output=%s\n' "${r16_unexpected_node}" >> "${R16_HASH_LOG}"
    r16_active_fail 70 "ranch_art_nonregular_find_indeterminate_rc_${r16_unexpected_rc}"
  fi
  if [[ -n "${r16_unexpected_node}" ]]; then
    /usr/bin/printf 'ranch_art_first_nonregular_node=%s\n' "${r16_unexpected_node}" >> "${R16_HASH_LOG}"
    r16_active_fail 70 "ranch_art_nonregular_node_present"
  fi

  set +e
  r16_regular_count="$(
    /usr/bin/printf '%s\n' "${r16_actual_paths}" |
      /usr/bin/wc -l |
      /usr/bin/tr -d '[:space:]'
  )"
  r16_count_rc="$?"
  set -e
  if [[ "${r16_count_rc}" -ne 0 ]]; then
    r16_active_fail 70 "ranch_art_count_indeterminate_rc_${r16_count_rc}"
  fi
  /usr/bin/printf 'ranch_art_regular_file_count=%s\n' "${r16_regular_count}" >> "${R16_HASH_LOG}"
  /usr/bin/printf '%s\n' "ranch_art_symlink_count=0" >> "${R16_HASH_LOG}"
  if [[ "${r16_regular_count}" != "27" ]]; then
    r16_active_fail 70 "ranch_art_regular_file_count_${r16_regular_count}"
  fi
}

if [[ "$#" -ne 4 ]]; then
  r16_pre_begin_fail 64 "expected four SHA-256 arguments: freeze Review16 driver manifest"
fi

readonly R16_EXPECTED_FREEZE_SHA="$1"
readonly R16_EXPECTED_REVIEW16_SHA="$2"
readonly R16_EXPECTED_DRIVER_SHA="$3"
readonly R16_EXPECTED_MANIFEST_SHA="$4"

r16_require_lowercase_sha256 "${R16_EXPECTED_FREEZE_SHA}" "freeze hash"
r16_require_lowercase_sha256 "${R16_EXPECTED_REVIEW16_SHA}" "Review16 hash"
r16_require_lowercase_sha256 "${R16_EXPECTED_DRIVER_SHA}" "driver hash"
r16_require_lowercase_sha256 "${R16_EXPECTED_MANIFEST_SHA}" "manifest hash"

if [[ "$0" != "${R16_DRIVER_PATH}" ]]; then
  r16_pre_begin_fail 64 "driver must be invoked by its frozen absolute path"
fi
if [[ "${BASH_SOURCE[0]}" != "${R16_DRIVER_PATH}" ||
      ! -f "${R16_DRIVER_PATH}" ||
      -L "${R16_DRIVER_PATH}" ||
      "$(/bin/realpath "${R16_DRIVER_PATH}")" != "${R16_DRIVER_PATH}" ]]; then
  r16_pre_begin_fail 64 "driver source path or file type is not canonical"
fi
if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r16_pre_begin_fail 64 "Bash 3.2 or newer is required"
fi
if [[ "${LC_ALL:-}" != "C" || "${LANG:-}" != "C" ]]; then
  r16_pre_begin_fail 64 "LC_ALL and LANG must both equal C"
fi
if [[ "${PATH:-}" != "/usr/bin:/bin:/usr/sbin:/sbin" ]]; then
  r16_pre_begin_fail 64 "PATH is not the frozen clean value"
fi
if [[ "${TMPDIR:-}" != "/private/tmp" ]]; then
  r16_pre_begin_fail 64 "TMPDIR is not the frozen clean value"
fi
if [[ "${GIT_CONFIG_NOSYSTEM:-}" != "1" || "${GIT_CONFIG_GLOBAL:-}" != "/dev/null" ]]; then
  r16_pre_begin_fail 64 "Git clean-environment controls are missing"
fi
if [[ -n "${BASH_ENV+x}" || -n "${ENV+x}" || -n "${CDPATH+x}" ]]; then
  r16_pre_begin_fail 64 "shell startup or directory environment was inherited"
fi

R16_PHASE="pre_begin_terminal_anchors"
r16_check_anchors_to_stdout

R16_PHASE="pre_begin_manifest_shape"
r16_check_manifest_shape

R16_PHASE="pre_begin_static_manifest"
r16_check_manifest_to_stdout

R16_PHASE="pre_begin_repository_identity"
R16_ACTUAL_BRANCH="$(/usr/bin/git -C "${R16_REPOSITORY_ROOT}" symbolic-ref --quiet --short HEAD)"
R16_ACTUAL_HEAD="$(/usr/bin/git -C "${R16_REPOSITORY_ROOT}" rev-parse --verify HEAD)"
if [[ "${R16_ACTUAL_BRANCH}" != "${R16_EXPECTED_BRANCH}" ]]; then
  r16_pre_begin_fail 67 "branch is ${R16_ACTUAL_BRANCH}, expected ${R16_EXPECTED_BRANCH}"
fi
if [[ "${R16_ACTUAL_HEAD}" != "${R16_EXPECTED_HEAD}" ]]; then
  r16_pre_begin_fail 67 "HEAD is ${R16_ACTUAL_HEAD}, expected ${R16_EXPECTED_HEAD}"
fi

R16_PHASE="pre_begin_runtime_paths"
R16_RUNTIME_PATHS=(
  "${R16_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R16_TASK_DIRECTORY}/r16-verify.log"
  "${R16_TASK_DIRECTORY}/r16-build.log"
  "${R16_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R16_TASK_DIRECTORY}/impl-report-r16.md"
  "${R16_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-preview-smoke.png"
)
for R16_RUNTIME_PATH in "${R16_RUNTIME_PATHS[@]}"; do
  r16_require_absent_path "${R16_RUNTIME_PATH}"
done

R16_PHASE="pre_begin_processes"
r16_require_process_absent "AgentLoop"
r16_require_process_absent "AgentLoopApp"

R16_PHASE="pre_begin_r15_preservation"
r16_require_empty_preserved_directory "${R16_R15_STATE_ROOT}"
r16_require_empty_preserved_directory "${R16_R15_BUNDLE_PARENT}"
if [[ -e "${R16_R15_PLANNED_APP}" || -L "${R16_R15_PLANNED_APP}" ]]; then
  r16_pre_begin_fail 70 "R15 planned App must remain absent"
fi
if [[ -e "${R16_R15_SCREENSHOT}" || -L "${R16_R15_SCREENSHOT}" ]]; then
  r16_pre_begin_fail 70 "R15 screenshot must remain absent"
fi

R16_PHASE="activation_boundary"
R16_INVOCATION_ID="r16-$(
  /usr/bin/uuidgen |
    /usr/bin/tr '[:upper:]' '[:lower:]'
)"
R16_BEGIN_UTC="$(r16_utc_now)"
if ! (
  set -C
  /usr/bin/printf '%s\n' \
    "boundary=R16_CLEAN_REVERIFICATION" \
    "invocation_id=${R16_INVOCATION_ID}" \
    "utc_begin=${R16_BEGIN_UTC}" \
    "authorization_consumed=true" \
    "status=BEGIN_STARTED" \
    "branch=${R16_ACTUAL_BRANCH}" \
    "head=${R16_ACTUAL_HEAD}" \
    "recipe=r16-dev-bundle-v1" \
    "normal_root=/Users/muzi/Library/Application Support/AgentLoop" \
    "normal_root_access_policy=lsof_path_comparison_only" \
    "freeze_sha=${R16_EXPECTED_FREEZE_SHA}" \
    "review16_sha=${R16_EXPECTED_REVIEW16_SHA}" \
    "driver_sha=${R16_EXPECTED_DRIVER_SHA}" \
    "manifest_sha=${R16_EXPECTED_MANIFEST_SHA}" \
    > "${R16_BOUNDARY_LOG}"
); then
  r16_attestation_fail 71 "could not exclusive-create and initialize R16 boundary log"
fi
R16_BOUNDARY_ACTIVE="true"

R16_PHASE="activation_logs"
R16_TEXT_LOGS=(
  "${R16_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R16_TASK_DIRECTORY}/r16-verify.log"
  "${R16_TASK_DIRECTORY}/r16-build.log"
  "${R16_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R16_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
)
for R16_TEXT_LOG in "${R16_TEXT_LOGS[@]}"; do
  if ! r16_exclusive_create_empty "${R16_TEXT_LOG}"; then
    r16_active_fail 71 "exclusive_create_failed_${R16_TEXT_LOG}" "exclusive_create"
  fi
done

R16_PHASE="activation_fresh_roots"
R16_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r16-state.XXXXXX')"
R16_BUNDLE_PARENT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r16-bundle.XXXXXX')"
R16_PLANNED_APP="${R16_BUNDLE_PARENT}/AgentLoop.app"
R16_PLANNED_EXECUTABLE="${R16_PLANNED_APP}/Contents/MacOS/AgentLoop"

r16_require_fresh_root "${R16_STATE_ROOT}" "fresh_state_root"
r16_require_fresh_root "${R16_BUNDLE_PARENT}" "fresh_bundle_parent"
if [[ "${R16_STATE_ROOT}" == "${R16_BUNDLE_PARENT}" ]]; then
  r16_active_fail 72 "fresh_roots_equal"
fi
case "${R16_STATE_ROOT}/" in
  "${R16_BUNDLE_PARENT}/"* )
    r16_active_fail 72 "state_root_nested_in_bundle_parent"
    ;;
esac
case "${R16_BUNDLE_PARENT}/" in
  "${R16_STATE_ROOT}/"* )
    r16_active_fail 72 "bundle_parent_nested_in_state_root"
    ;;
esac
if [[ "${R16_STATE_ROOT}" == "${R16_R15_STATE_ROOT}" ||
      "${R16_STATE_ROOT}" == "${R16_R15_BUNDLE_PARENT}" ||
      "${R16_BUNDLE_PARENT}" == "${R16_R15_STATE_ROOT}" ||
      "${R16_BUNDLE_PARENT}" == "${R16_R15_BUNDLE_PARENT}" ]]; then
  r16_active_fail 72 "fresh_root_reuses_r15_root"
fi
if [[ -e "${R16_PLANNED_APP}" || -L "${R16_PLANNED_APP}" ]]; then
  r16_active_fail 72 "planned_app_preexists"
fi

r16_append_boundary "state_root=${R16_STATE_ROOT}"
r16_append_boundary "bundle_parent=${R16_BUNDLE_PARENT}"
r16_append_boundary "planned_app=${R16_PLANNED_APP}"
r16_append_boundary "planned_executable=${R16_PLANNED_EXECUTABLE}"
r16_append_boundary "final_executable_hash=DEFERRED_TO_LAUNCH_READY"
r16_append_boundary "process_count=0"
r16_append_boundary "r15_state_root_preserved_empty=true"
r16_append_boundary "r15_bundle_parent_preserved_empty=true"
r16_append_boundary "r15_planned_app_absent=true"
r16_append_boundary "r15_screenshot_absent=true"
r16_append_boundary "frozen_info_plist_sha=${R16_EXPECTED_INFO_PLIST_SHA}"
r16_append_boundary "frozen_ranch_art_manifest_sha=${R16_EXPECTED_RANCH_ART_MANIFEST_SHA}"

R16_PHASE="post_activation_terminal_anchors"
r16_post_activation_anchor_check

R16_PHASE="post_activation_static_manifest"
r16_check_manifest_shape
r16_post_activation_manifest_check
/usr/bin/printf 'frozen_info_plist_sha=%s\n' "${R16_EXPECTED_INFO_PLIST_SHA}" >> "${R16_HASH_LOG}"
/usr/bin/printf 'frozen_ranch_art_manifest_sha=%s\n' "${R16_EXPECTED_RANCH_ART_MANIFEST_SHA}" >> "${R16_HASH_LOG}"
/usr/bin/printf '%s\n' "section=worktree_status" >> "${R16_HASH_LOG}"
/usr/bin/git --no-optional-locks -C "${R16_REPOSITORY_ROOT}" status --short --branch >> "${R16_HASH_LOG}"

R16_PHASE="post_activation_ranch_art_structure"
r16_check_ranch_art_structure

R16_PHASE="begin_finalization"
r16_require_process_absent "AgentLoop"
r16_require_process_absent "AgentLoopApp"
r16_append_boundary "utc_begin_attested=$(r16_utc_now)"
r16_append_boundary "begin_attestation_complete=true"
r16_append_boundary "status=BEGIN_ATTESTED"
r16_append_boundary "retry_same_boundary=false"

/usr/bin/printf '%s\n' \
  "status=BEGIN_ATTESTED" \
  "invocation_id=${R16_INVOCATION_ID}" \
  "boundary_log=${R16_BOUNDARY_LOG}" \
  "hash_log=${R16_HASH_LOG}" \
  "state_root=${R16_STATE_ROOT}" \
  "bundle_parent=${R16_BUNDLE_PARENT}" \
  "planned_app=${R16_PLANNED_APP}" \
  "planned_executable=${R16_PLANNED_EXECUTABLE}"
