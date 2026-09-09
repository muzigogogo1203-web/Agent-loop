#!/bin/bash

# Reviewed R17 BEGIN-only driver.
# This file does not run tests, build, migration matrix, source gates, bundle
# assembly, signing, or preview. It establishes one fail-once evidence boundary.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R17_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R17_TASK_DIRECTORY="${R17_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R17_DRIVER_PATH="${R17_TASK_DIRECTORY}/evidence/r17-begin.sh"
readonly R17_MANIFEST_PATH="${R17_TASK_DIRECTORY}/evidence/r17-entry.sha256"
readonly R17_FREEZE_PATH="${R17_TASK_DIRECTORY}/evidence/plan-freeze-r17.md"
readonly R17_REVIEW17_PATH="${R17_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/17-p1-plan-review.md"
readonly R17_BOUNDARY_LOG="${R17_TASK_DIRECTORY}/evidence/r17-clean-boundary.log"
readonly R17_HASH_LOG="${R17_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
readonly R17_RANCH_ART_DIRECTORY="${R17_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R17_EXPECTED_MANIFEST_COUNT="115"
readonly R17_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R17_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R17_EXPECTED_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R17_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R17_R15_STATE_ROOT="/private/tmp/agentloop-r15-state.Zq6Jvm"
readonly R17_R15_BUNDLE_PARENT="/private/tmp/agentloop-r15-bundle.2xROcy"
readonly R17_R15_PLANNED_APP="${R17_R15_BUNDLE_PARENT}/AgentLoop.app"
readonly R17_R15_SCREENSHOT="${R17_TASK_DIRECTORY}/evidence/r15-preview-smoke.png"

R17_BOUNDARY_ACTIVE="false"
R17_PHASE="pre_begin"
R17_INVOCATION_ID=""
R17_STATE_ROOT=""
R17_BUNDLE_PARENT=""

r17_utc_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r17_pre_begin_fail() {
  local r17_exit_code="$1"
  shift
  /usr/bin/printf 'R17 pre-BEGIN rejected: %s\n' "$*" >&2
  exit "$r17_exit_code"
}

r17_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R17_BOUNDARY_LOG}"
}

r17_authorization_is_consumed() {
  if [[ "${R17_BOUNDARY_ACTIVE}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${R17_INVOCATION_ID}" &&
        -f "${R17_BOUNDARY_LOG}" &&
        ! -L "${R17_BOUNDARY_LOG}" ]] &&
     /usr/bin/grep -Fx "invocation_id=${R17_INVOCATION_ID}" "${R17_BOUNDARY_LOG}" >/dev/null 2>&1 &&
     /usr/bin/grep -Fx 'authorization_consumed=true' "${R17_BOUNDARY_LOG}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

r17_active_fail() {
  local r17_exit_code="$1"
  local r17_reason="$2"
  local r17_command="${3:-explicit_fail_closed}"
  trap - ERR HUP INT TERM
  set +e
  r17_append_boundary "utc=$(r17_utc_now)"
  r17_append_boundary "status=REJECTED_CONTAMINATED"
  r17_append_boundary "phase=${R17_PHASE}"
  r17_append_boundary "reason=${r17_reason}"
  printf 'failed_command=%q\n' "${r17_command}" >> "${R17_BOUNDARY_LOG}"
  r17_append_boundary "exit_code=${r17_exit_code}"
  r17_append_boundary "state_root=${R17_STATE_ROOT:-UNCREATED}"
  r17_append_boundary "bundle_parent=${R17_BUNDLE_PARENT:-UNCREATED}"
  if [[ -n "${R17_PLANNED_APP:-}" ]]; then
    r17_append_boundary "planned_app=${R17_PLANNED_APP}"
  fi
  r17_append_boundary "retry_same_boundary=false"
  /usr/bin/printf 'R17 rejected after authorization consumption: %s\n' "${r17_reason}" >&2
  exit "$r17_exit_code"
}

r17_unexpected_error() {
  local r17_exit_code="$?"
  local r17_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  if r17_authorization_is_consumed; then
    r17_active_fail "${r17_exit_code}" "unexpected_command_failure" "${r17_command}"
  fi
  printf 'R17 pre-BEGIN command failed: phase=%s rc=%s command=%q\n' \
    "${R17_PHASE}" "${r17_exit_code}" "${r17_command}" >&2
  exit "${r17_exit_code}"
}

r17_signal_error() {
  local r17_signal="$1"
  trap - HUP INT TERM
  if r17_authorization_is_consumed; then
    r17_active_fail "74" "signal_${r17_signal}" "signal_${r17_signal}"
  fi
  /usr/bin/printf 'R17 pre-BEGIN interrupted by signal %s\n' "${r17_signal}" >&2
  exit 74
}

trap r17_unexpected_error ERR
trap 'r17_signal_error HUP' HUP
trap 'r17_signal_error INT' INT
trap 'r17_signal_error TERM' TERM

r17_attestation_fail() {
  local r17_exit_code="$1"
  shift
  if r17_authorization_is_consumed; then
    r17_active_fail "${r17_exit_code}" "$*"
  fi
  r17_pre_begin_fail "${r17_exit_code}" "$*"
}

r17_require_lowercase_sha256() {
  local r17_value="$1"
  local r17_label="$2"
  if [[ "${#r17_value}" -ne 64 ]]; then
    r17_pre_begin_fail 64 "${r17_label} must be exactly 64 lowercase hex characters"
  fi
  case "${r17_value}" in
    *[!0-9a-f]*)
      r17_pre_begin_fail 64 "${r17_label} must be exactly 64 lowercase hex characters"
      ;;
  esac
}

r17_emit_anchor_manifest() {
  /usr/bin/printf '%s  %s\n' "${R17_EXPECTED_FREEZE_SHA}" "${R17_FREEZE_PATH}"
  /usr/bin/printf '%s  %s\n' "${R17_EXPECTED_REVIEW17_SHA}" "${R17_REVIEW17_PATH}"
  /usr/bin/printf '%s  %s\n' "${R17_EXPECTED_DRIVER_SHA}" "${R17_DRIVER_PATH}"
  /usr/bin/printf '%s  %s\n' "${R17_EXPECTED_MANIFEST_SHA}" "${R17_MANIFEST_PATH}"
}

r17_check_anchors_to_stdout() {
  local -a r17_anchor_status
  if r17_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c -; then
    r17_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r17_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${r17_anchor_status[0]}" -ne 0 || "${r17_anchor_status[1]}" -ne 0 ]]; then
    r17_pre_begin_fail 65 "terminal anchor verification failed with producer_rc=${r17_anchor_status[0]} shasum_rc=${r17_anchor_status[1]}"
  fi
}

r17_check_manifest_shape() {
  local r17_manifest_count
  if [[ ! -f "${R17_MANIFEST_PATH}" || -L "${R17_MANIFEST_PATH}" ]]; then
    r17_attestation_fail 66 "static manifest is missing, non-regular, or a symlink"
  fi
  r17_manifest_count="$(/usr/bin/wc -l < "${R17_MANIFEST_PATH}" | /usr/bin/tr -d '[:space:]')"
  if [[ "${r17_manifest_count}" != "${R17_EXPECTED_MANIFEST_COUNT}" ]]; then
    r17_attestation_fail 66 "static manifest entry count is ${r17_manifest_count}, expected ${R17_EXPECTED_MANIFEST_COUNT}"
  fi
  if /usr/bin/grep -F -- "  ${R17_MANIFEST_PATH}" "${R17_MANIFEST_PATH}" >/dev/null 2>&1; then
    r17_attestation_fail 66 "static manifest must not contain itself"
  fi
  if /usr/bin/grep -F -- "  ${R17_FREEZE_PATH}" "${R17_MANIFEST_PATH}" >/dev/null 2>&1; then
    r17_attestation_fail 66 "static manifest must not contain the R17 freeze"
  fi
  if /usr/bin/grep -F -- "  ${R17_REVIEW17_PATH}" "${R17_MANIFEST_PATH}" >/dev/null 2>&1; then
    r17_attestation_fail 66 "static manifest must not contain Review17"
  fi
  if ! /usr/bin/cut -c 67- "${R17_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r17_attestation_fail 66 "static manifest paths are not bytewise sorted and unique"
  fi
  while IFS= read -r r17_manifest_line; do
    local r17_manifest_entry_path="${r17_manifest_line#*  }"
    case "${r17_manifest_entry_path}" in
      "${R17_REPOSITORY_ROOT}"/*)
        ;;
      *)
        r17_attestation_fail 66 "static manifest entry is outside the repository"
        ;;
    esac
    case "${r17_manifest_entry_path}" in
      *"/../"*|*"/./"*|*/..|*/.)
        r17_attestation_fail 66 "static manifest entry contains a non-canonical path segment"
        ;;
    esac
    if [[ ! -f "${r17_manifest_entry_path}" || -L "${r17_manifest_entry_path}" ]]; then
      r17_attestation_fail 66 "static manifest entry is non-regular or a symlink: ${r17_manifest_entry_path}"
    fi
  done < "${R17_MANIFEST_PATH}"
}

r17_check_manifest_to_stdout() {
  local r17_manifest_rc
  if /usr/bin/shasum -a 256 --strict -c "${R17_MANIFEST_PATH}"; then
    r17_manifest_rc=0
  else
    r17_manifest_rc="$?"
  fi
  if [[ "${r17_manifest_rc}" -ne 0 ]]; then
    r17_pre_begin_fail 66 "static manifest verification failed with rc=${r17_manifest_rc}"
  fi
}

r17_require_process_absent() {
  local r17_process_name="$1"
  local r17_process_rc
  if /usr/bin/pgrep -x "${r17_process_name}" >/dev/null 2>&1; then
    r17_process_rc=0
  else
    r17_process_rc="$?"
  fi
  case "${r17_process_rc}" in
    1)
      ;;
    0)
      r17_attestation_fail 69 "${r17_process_name} process is present"
      ;;
    *)
      r17_attestation_fail 69 "pgrep for ${r17_process_name} was indeterminate with rc=${r17_process_rc}"
      ;;
  esac
}

r17_require_absent_path() {
  local r17_path="$1"
  if [[ -e "${r17_path}" || -L "${r17_path}" ]]; then
    r17_pre_begin_fail 68 "runtime artifact already exists: ${r17_path}"
  fi
}

r17_probe_empty_directory() {
  local r17_path="$1"
  local r17_probe_output
  local r17_probe_rc
  if r17_probe_output="$(
    trap - ERR
    /usr/bin/find "${r17_path}" -mindepth 1 -maxdepth 1 -print -quit 2>&1
  )"; then
    r17_probe_rc=0
  else
    r17_probe_rc="$?"
  fi
  if [[ "${r17_probe_rc}" -ne 0 ]]; then
    return 2
  fi
  if [[ -n "${r17_probe_output}" ]]; then
    return 1
  fi
  return 0
}

r17_require_empty_preserved_directory() {
  local r17_path="$1"
  local r17_probe_rc
  local r17_realpath
  local r17_realpath_rc
  if [[ ! -d "${r17_path}" || -L "${r17_path}" ]]; then
    r17_pre_begin_fail 70 "preserved R15 root is missing, non-directory, or symlink: ${r17_path}"
  fi
  if r17_realpath="$(
    trap - ERR
    /bin/realpath "${r17_path}" 2>&1
  )"; then
    r17_realpath_rc=0
  else
    r17_realpath_rc="$?"
  fi
  if [[ "${r17_realpath_rc}" -ne 0 ]]; then
    r17_pre_begin_fail 70 "preserved R15 root realpath probe failed: ${r17_path}"
  fi
  if [[ "${r17_realpath}" != "${r17_path}" ]]; then
    r17_pre_begin_fail 70 "preserved R15 root realpath drifted: ${r17_path}"
  fi
  if r17_probe_empty_directory "${r17_path}"; then
    return 0
  else
    r17_probe_rc="$?"
  fi
  if [[ "${r17_probe_rc}" -eq 1 ]]; then
    r17_pre_begin_fail 70 "preserved R15 root is not empty: ${r17_path}"
  fi
  r17_pre_begin_fail 70 "preserved R15 root emptiness probe was indeterminate: ${r17_path}"
}

r17_require_no_r16_fresh_roots() {
  local r17_r16_root_probe_output
  local r17_r16_root_probe_rc
  if r17_r16_root_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( -name 'agentloop-r16-state.*' -o -name 'agentloop-r16-bundle.*' \) \
      -print -quit 2>&1
  )"; then
    r17_r16_root_probe_rc=0
  else
    r17_r16_root_probe_rc="$?"
  fi
  if [[ "${r17_r16_root_probe_rc}" -ne 0 ]]; then
    r17_pre_begin_fail 70 "R16 fresh-root absence probe was indeterminate with rc=${r17_r16_root_probe_rc}"
  fi
  if [[ -n "${r17_r16_root_probe_output}" ]]; then
    r17_pre_begin_fail 70 "R16 fresh root must remain absent: ${r17_r16_root_probe_output}"
  fi
}

r17_exclusive_create_empty() {
  local r17_path="$1"
  ( set -C; : > "${r17_path}" )
}

r17_require_fresh_root() {
  local r17_path="$1"
  local r17_label="$2"
  local r17_probe_rc
  local r17_realpath
  local r17_realpath_rc
  if [[ ! -d "${r17_path}" || -L "${r17_path}" ]]; then
    r17_active_fail 72 "${r17_label}_invalid_type"
  fi
  if r17_realpath="$(
    trap - ERR
    /bin/realpath "${r17_path}" 2>&1
  )"; then
    r17_realpath_rc=0
  else
    r17_realpath_rc="$?"
  fi
  if [[ "${r17_realpath_rc}" -ne 0 ]]; then
    r17_active_fail 72 "${r17_label}_realpath_probe_failed"
  fi
  if [[ "${r17_realpath}" != "${r17_path}" ]]; then
    r17_active_fail 72 "${r17_label}_realpath_mismatch"
  fi
  if r17_probe_empty_directory "${r17_path}"; then
    return 0
  else
    r17_probe_rc="$?"
  fi
  if [[ "${r17_probe_rc}" -eq 1 ]]; then
    r17_active_fail 72 "${r17_label}_not_empty"
  fi
  r17_active_fail 72 "${r17_label}_emptiness_probe_indeterminate"
}

r17_post_activation_anchor_check() {
  local -a r17_anchor_status
  {
    /usr/bin/printf '%s\n' "section=terminal_anchors"
    r17_emit_anchor_manifest
  } >> "${R17_HASH_LOG}"
  if r17_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c - >> "${R17_HASH_LOG}" 2>&1; then
    r17_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r17_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  /usr/bin/printf 'terminal_anchor_producer_rc=%s\n' "${r17_anchor_status[0]}" >> "${R17_HASH_LOG}"
  /usr/bin/printf 'terminal_anchor_shasum_rc=%s\n' "${r17_anchor_status[1]}" >> "${R17_HASH_LOG}"
  if [[ "${r17_anchor_status[0]}" -ne 0 || "${r17_anchor_status[1]}" -ne 0 ]]; then
    r17_active_fail 65 "post_activation_terminal_anchor_failure_producer_${r17_anchor_status[0]}_shasum_${r17_anchor_status[1]}"
  fi
}

r17_post_activation_manifest_check() {
  local r17_manifest_rc
  local r17_manifest_count
  r17_manifest_count="$(/usr/bin/wc -l < "${R17_MANIFEST_PATH}" | /usr/bin/tr -d '[:space:]')"
  /usr/bin/printf '%s\n' "section=static_manifest" >> "${R17_HASH_LOG}"
  /usr/bin/printf 'static_manifest_expected_count=%s\n' "${R17_EXPECTED_MANIFEST_COUNT}" >> "${R17_HASH_LOG}"
  /usr/bin/printf 'static_manifest_actual_count=%s\n' "${r17_manifest_count}" >> "${R17_HASH_LOG}"
  if /usr/bin/shasum -a 256 --strict -c "${R17_MANIFEST_PATH}" >> "${R17_HASH_LOG}" 2>&1; then
    r17_manifest_rc=0
  else
    r17_manifest_rc="$?"
  fi
  /usr/bin/printf 'static_manifest_rc=%s\n' "${r17_manifest_rc}" >> "${R17_HASH_LOG}"
  if [[ "${r17_manifest_rc}" -ne 0 ]]; then
    r17_active_fail 66 "post_activation_static_manifest_failure_rc_${r17_manifest_rc}"
  fi
  if [[ "${r17_manifest_count}" != "${R17_EXPECTED_MANIFEST_COUNT}" ]]; then
    r17_active_fail 66 "post_activation_static_manifest_count_${r17_manifest_count}"
  fi
}

r17_check_ranch_art_structure() {
  local r17_expected_paths
  local r17_raw_paths
  local r17_actual_paths
  local r17_find_rc
  local r17_transform_rc
  local r17_diff_rc
  local r17_unexpected_node
  local r17_unexpected_rc
  local r17_regular_count
  local r17_count_rc
  /usr/bin/printf '%s\n' "section=ranch_art_structure" >> "${R17_HASH_LOG}"

  r17_expected_paths="$(
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

  if r17_raw_paths="$(
    trap - ERR
    /usr/bin/find "${R17_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 -type f -print 2>&1
  )"; then
    r17_find_rc=0
  else
    r17_find_rc="$?"
  fi
  /usr/bin/printf 'ranch_art_file_find_rc=%s\n' "${r17_find_rc}" >> "${R17_HASH_LOG}"
  if [[ "${r17_find_rc}" -ne 0 ]]; then
    /usr/bin/printf 'ranch_art_file_find_output=%s\n' "${r17_raw_paths}" >> "${R17_HASH_LOG}"
    r17_active_fail 70 "ranch_art_file_find_indeterminate_rc_${r17_find_rc}"
  fi

  if r17_actual_paths="$(
    trap - ERR
    /usr/bin/printf '%s\n' "${r17_raw_paths}" |
      /usr/bin/sed "s#^${R17_RANCH_ART_DIRECTORY}/##" |
      LC_ALL=C /usr/bin/sort
  )"; then
    r17_transform_rc=0
  else
    r17_transform_rc="$?"
  fi
  /usr/bin/printf 'ranch_art_path_transform_rc=%s\n' "${r17_transform_rc}" >> "${R17_HASH_LOG}"
  if [[ "${r17_transform_rc}" -ne 0 ]]; then
    r17_active_fail 70 "ranch_art_path_transform_indeterminate_rc_${r17_transform_rc}"
  fi

  if /usr/bin/diff -u \
    <(/usr/bin/printf '%s\n' "${r17_expected_paths}") \
    <(/usr/bin/printf '%s\n' "${r17_actual_paths}") \
    >> "${R17_HASH_LOG}" 2>&1; then
    r17_diff_rc=0
  else
    r17_diff_rc="$?"
  fi
  /usr/bin/printf 'ranch_art_path_set_diff_rc=%s\n' "${r17_diff_rc}" >> "${R17_HASH_LOG}"
  if [[ "${r17_diff_rc}" -ne 0 ]]; then
    r17_active_fail 70 "ranch_art_exact_path_set_mismatch_rc_${r17_diff_rc}"
  fi

  if r17_unexpected_node="$(
    trap - ERR
    /usr/bin/find "${R17_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 ! -type f -print -quit 2>&1
  )"; then
    r17_unexpected_rc=0
  else
    r17_unexpected_rc="$?"
  fi
  /usr/bin/printf 'ranch_art_nonregular_find_rc=%s\n' "${r17_unexpected_rc}" >> "${R17_HASH_LOG}"
  if [[ "${r17_unexpected_rc}" -ne 0 ]]; then
    /usr/bin/printf 'ranch_art_nonregular_find_output=%s\n' "${r17_unexpected_node}" >> "${R17_HASH_LOG}"
    r17_active_fail 70 "ranch_art_nonregular_find_indeterminate_rc_${r17_unexpected_rc}"
  fi
  if [[ -n "${r17_unexpected_node}" ]]; then
    /usr/bin/printf 'ranch_art_first_nonregular_node=%s\n' "${r17_unexpected_node}" >> "${R17_HASH_LOG}"
    r17_active_fail 70 "ranch_art_nonregular_node_present"
  fi

  if r17_regular_count="$(
    trap - ERR
    /usr/bin/printf '%s\n' "${r17_actual_paths}" |
      /usr/bin/wc -l |
      /usr/bin/tr -d '[:space:]'
  )"; then
    r17_count_rc=0
  else
    r17_count_rc="$?"
  fi
  if [[ "${r17_count_rc}" -ne 0 ]]; then
    r17_active_fail 70 "ranch_art_count_indeterminate_rc_${r17_count_rc}"
  fi
  /usr/bin/printf 'ranch_art_regular_file_count=%s\n' "${r17_regular_count}" >> "${R17_HASH_LOG}"
  /usr/bin/printf '%s\n' "ranch_art_symlink_count=0" >> "${R17_HASH_LOG}"
  if [[ "${r17_regular_count}" != "27" ]]; then
    r17_active_fail 70 "ranch_art_regular_file_count_${r17_regular_count}"
  fi
}

if [[ "$#" -ne 4 ]]; then
  r17_pre_begin_fail 64 "expected four SHA-256 arguments: freeze Review17 driver manifest"
fi

readonly R17_EXPECTED_FREEZE_SHA="$1"
readonly R17_EXPECTED_REVIEW17_SHA="$2"
readonly R17_EXPECTED_DRIVER_SHA="$3"
readonly R17_EXPECTED_MANIFEST_SHA="$4"

r17_require_lowercase_sha256 "${R17_EXPECTED_FREEZE_SHA}" "freeze hash"
r17_require_lowercase_sha256 "${R17_EXPECTED_REVIEW17_SHA}" "Review17 hash"
r17_require_lowercase_sha256 "${R17_EXPECTED_DRIVER_SHA}" "driver hash"
r17_require_lowercase_sha256 "${R17_EXPECTED_MANIFEST_SHA}" "manifest hash"

if [[ "$0" != "${R17_DRIVER_PATH}" ]]; then
  r17_pre_begin_fail 64 "driver must be invoked by its frozen absolute path"
fi
if [[ "${BASH_SOURCE[0]}" != "${R17_DRIVER_PATH}" ||
      ! -f "${R17_DRIVER_PATH}" ||
      -L "${R17_DRIVER_PATH}" ||
      "$(/bin/realpath "${R17_DRIVER_PATH}")" != "${R17_DRIVER_PATH}" ]]; then
  r17_pre_begin_fail 64 "driver source path or file type is not canonical"
fi
if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r17_pre_begin_fail 64 "Bash 3.2 or newer is required"
fi
if [[ "${LC_ALL:-}" != "C" || "${LANG:-}" != "C" ]]; then
  r17_pre_begin_fail 64 "LC_ALL and LANG must both equal C"
fi
if [[ "${PATH:-}" != "/usr/bin:/bin:/usr/sbin:/sbin" ]]; then
  r17_pre_begin_fail 64 "PATH is not the frozen clean value"
fi
if [[ "${TMPDIR:-}" != "/private/tmp" ]]; then
  r17_pre_begin_fail 64 "TMPDIR is not the frozen clean value"
fi
if [[ "${GIT_CONFIG_NOSYSTEM:-}" != "1" || "${GIT_CONFIG_GLOBAL:-}" != "/dev/null" ]]; then
  r17_pre_begin_fail 64 "Git clean-environment controls are missing"
fi
if [[ -n "${BASH_ENV+x}" || -n "${ENV+x}" || -n "${CDPATH+x}" ]]; then
  r17_pre_begin_fail 64 "shell startup or directory environment was inherited"
fi

R17_PHASE="pre_begin_terminal_anchors"
r17_check_anchors_to_stdout

R17_PHASE="pre_begin_manifest_shape"
r17_check_manifest_shape

R17_PHASE="pre_begin_static_manifest"
r17_check_manifest_to_stdout

R17_PHASE="pre_begin_repository_identity"
R17_ACTUAL_BRANCH="$(/usr/bin/git -C "${R17_REPOSITORY_ROOT}" symbolic-ref --quiet --short HEAD)"
R17_ACTUAL_HEAD="$(/usr/bin/git -C "${R17_REPOSITORY_ROOT}" rev-parse --verify HEAD)"
if [[ "${R17_ACTUAL_BRANCH}" != "${R17_EXPECTED_BRANCH}" ]]; then
  r17_pre_begin_fail 67 "branch is ${R17_ACTUAL_BRANCH}, expected ${R17_EXPECTED_BRANCH}"
fi
if [[ "${R17_ACTUAL_HEAD}" != "${R17_EXPECTED_HEAD}" ]]; then
  r17_pre_begin_fail 67 "HEAD is ${R17_ACTUAL_HEAD}, expected ${R17_EXPECTED_HEAD}"
fi

R17_PHASE="pre_begin_r16_preservation"
R17_R16_RUNTIME_PATHS=(
  "${R17_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R17_TASK_DIRECTORY}/r16-verify.log"
  "${R17_TASK_DIRECTORY}/r16-build.log"
  "${R17_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R17_TASK_DIRECTORY}/impl-report-r16.md"
  "${R17_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
  "${R17_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R17_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R17_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R17_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R17_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
  "${R17_TASK_DIRECTORY}/evidence/r16-preview-smoke.png"
)
for R17_R16_RUNTIME_PATH in "${R17_R16_RUNTIME_PATHS[@]}"; do
  r17_require_absent_path "${R17_R16_RUNTIME_PATH}"
done
r17_require_no_r16_fresh_roots

R17_PHASE="pre_begin_runtime_paths"
R17_RUNTIME_PATHS=(
  "${R17_TASK_DIRECTORY}/r17-targeted-tests.log"
  "${R17_TASK_DIRECTORY}/r17-verify.log"
  "${R17_TASK_DIRECTORY}/r17-build.log"
  "${R17_TASK_DIRECTORY}/r17-migration-matrix.log"
  "${R17_TASK_DIRECTORY}/impl-report-r17.md"
  "${R17_TASK_DIRECTORY}/evidence/r17-clean-boundary.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-bundle-provenance.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-source-gates.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-preview-bootstrap.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-preview-cold-start.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-preview-smoke.png"
)
for R17_RUNTIME_PATH in "${R17_RUNTIME_PATHS[@]}"; do
  r17_require_absent_path "${R17_RUNTIME_PATH}"
done

R17_PHASE="pre_begin_processes"
r17_require_process_absent "AgentLoop"
r17_require_process_absent "AgentLoopApp"

R17_PHASE="pre_begin_r15_preservation"
r17_require_empty_preserved_directory "${R17_R15_STATE_ROOT}"
r17_require_empty_preserved_directory "${R17_R15_BUNDLE_PARENT}"
if [[ -e "${R17_R15_PLANNED_APP}" || -L "${R17_R15_PLANNED_APP}" ]]; then
  r17_pre_begin_fail 70 "R15 planned App must remain absent"
fi
if [[ -e "${R17_R15_SCREENSHOT}" || -L "${R17_R15_SCREENSHOT}" ]]; then
  r17_pre_begin_fail 70 "R15 screenshot must remain absent"
fi

R17_PHASE="activation_boundary"
R17_INVOCATION_ID="r17-$(
  /usr/bin/uuidgen |
    /usr/bin/tr '[:upper:]' '[:lower:]'
)"
R17_BEGIN_UTC="$(r17_utc_now)"
if ! (
  set -C
  /usr/bin/printf '%s\n' \
    "boundary=R17_CLEAN_REVERIFICATION" \
    "invocation_id=${R17_INVOCATION_ID}" \
    "utc_begin=${R17_BEGIN_UTC}" \
    "authorization_consumed=true" \
    "status=BEGIN_STARTED" \
    "branch=${R17_ACTUAL_BRANCH}" \
    "head=${R17_ACTUAL_HEAD}" \
    "recipe=r17-dev-bundle-v1" \
    "normal_root=/Users/muzi/Library/Application Support/AgentLoop" \
    "normal_root_access_policy=lsof_path_comparison_only" \
    "freeze_sha=${R17_EXPECTED_FREEZE_SHA}" \
    "review17_sha=${R17_EXPECTED_REVIEW17_SHA}" \
    "driver_sha=${R17_EXPECTED_DRIVER_SHA}" \
    "manifest_sha=${R17_EXPECTED_MANIFEST_SHA}" \
    > "${R17_BOUNDARY_LOG}"
); then
  r17_attestation_fail 71 "could not exclusive-create and initialize R17 boundary log"
fi
R17_BOUNDARY_ACTIVE="true"

R17_PHASE="activation_logs"
R17_TEXT_LOGS=(
  "${R17_TASK_DIRECTORY}/r17-targeted-tests.log"
  "${R17_TASK_DIRECTORY}/r17-verify.log"
  "${R17_TASK_DIRECTORY}/r17-build.log"
  "${R17_TASK_DIRECTORY}/r17-migration-matrix.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-bundle-provenance.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-source-gates.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-preview-bootstrap.log"
  "${R17_TASK_DIRECTORY}/evidence/r17-preview-cold-start.log"
)
for R17_TEXT_LOG in "${R17_TEXT_LOGS[@]}"; do
  if ! r17_exclusive_create_empty "${R17_TEXT_LOG}"; then
    r17_active_fail 71 "exclusive_create_failed_${R17_TEXT_LOG}" "exclusive_create"
  fi
done

R17_PHASE="activation_fresh_roots"
R17_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r17-state.XXXXXX')"
R17_BUNDLE_PARENT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r17-bundle.XXXXXX')"
R17_PLANNED_APP="${R17_BUNDLE_PARENT}/AgentLoop.app"
R17_PLANNED_EXECUTABLE="${R17_PLANNED_APP}/Contents/MacOS/AgentLoop"

r17_require_fresh_root "${R17_STATE_ROOT}" "fresh_state_root"
r17_require_fresh_root "${R17_BUNDLE_PARENT}" "fresh_bundle_parent"
if [[ "${R17_STATE_ROOT}" == "${R17_BUNDLE_PARENT}" ]]; then
  r17_active_fail 72 "fresh_roots_equal"
fi
case "${R17_STATE_ROOT}/" in
  "${R17_BUNDLE_PARENT}/"* )
    r17_active_fail 72 "state_root_nested_in_bundle_parent"
    ;;
esac
case "${R17_BUNDLE_PARENT}/" in
  "${R17_STATE_ROOT}/"* )
    r17_active_fail 72 "bundle_parent_nested_in_state_root"
    ;;
esac
if [[ "${R17_STATE_ROOT}" == "${R17_R15_STATE_ROOT}" ||
      "${R17_STATE_ROOT}" == "${R17_R15_BUNDLE_PARENT}" ||
      "${R17_BUNDLE_PARENT}" == "${R17_R15_STATE_ROOT}" ||
      "${R17_BUNDLE_PARENT}" == "${R17_R15_BUNDLE_PARENT}" ]]; then
  r17_active_fail 72 "fresh_root_reuses_r15_root"
fi
if [[ -e "${R17_PLANNED_APP}" || -L "${R17_PLANNED_APP}" ]]; then
  r17_active_fail 72 "planned_app_preexists"
fi

r17_append_boundary "state_root=${R17_STATE_ROOT}"
r17_append_boundary "bundle_parent=${R17_BUNDLE_PARENT}"
r17_append_boundary "planned_app=${R17_PLANNED_APP}"
r17_append_boundary "planned_executable=${R17_PLANNED_EXECUTABLE}"
r17_append_boundary "final_executable_hash=DEFERRED_TO_LAUNCH_READY"
r17_append_boundary "process_count=0"
r17_append_boundary "r15_state_root_preserved_empty=true"
r17_append_boundary "r15_bundle_parent_preserved_empty=true"
r17_append_boundary "r15_planned_app_absent=true"
r17_append_boundary "r15_screenshot_absent=true"
r17_append_boundary "r16_runtime_artifacts_absent=true"
r17_append_boundary "r16_fresh_roots_absent=true"
r17_append_boundary "r16_pre_begin_zero_write_preserved=true"
r17_append_boundary "frozen_info_plist_sha=${R17_EXPECTED_INFO_PLIST_SHA}"
r17_append_boundary "frozen_ranch_art_manifest_sha=${R17_EXPECTED_RANCH_ART_MANIFEST_SHA}"

R17_PHASE="post_activation_terminal_anchors"
r17_post_activation_anchor_check

R17_PHASE="post_activation_static_manifest"
r17_check_manifest_shape
r17_post_activation_manifest_check
/usr/bin/printf 'frozen_info_plist_sha=%s\n' "${R17_EXPECTED_INFO_PLIST_SHA}" >> "${R17_HASH_LOG}"
/usr/bin/printf 'frozen_ranch_art_manifest_sha=%s\n' "${R17_EXPECTED_RANCH_ART_MANIFEST_SHA}" >> "${R17_HASH_LOG}"
/usr/bin/printf '%s\n' "section=worktree_status" >> "${R17_HASH_LOG}"
/usr/bin/git --no-optional-locks -C "${R17_REPOSITORY_ROOT}" status --short --branch >> "${R17_HASH_LOG}"

R17_PHASE="post_activation_ranch_art_structure"
r17_check_ranch_art_structure

R17_PHASE="begin_finalization"
r17_require_process_absent "AgentLoop"
r17_require_process_absent "AgentLoopApp"
r17_append_boundary "utc_begin_attested=$(r17_utc_now)"
r17_append_boundary "begin_attestation_complete=true"
r17_append_boundary "status=BEGIN_ATTESTED"
r17_append_boundary "retry_same_boundary=false"

/usr/bin/printf '%s\n' \
  "status=BEGIN_ATTESTED" \
  "invocation_id=${R17_INVOCATION_ID}" \
  "boundary_log=${R17_BOUNDARY_LOG}" \
  "hash_log=${R17_HASH_LOG}" \
  "state_root=${R17_STATE_ROOT}" \
  "bundle_parent=${R17_BUNDLE_PARENT}" \
  "planned_app=${R17_PLANNED_APP}" \
  "planned_executable=${R17_PLANNED_EXECUTABLE}"
