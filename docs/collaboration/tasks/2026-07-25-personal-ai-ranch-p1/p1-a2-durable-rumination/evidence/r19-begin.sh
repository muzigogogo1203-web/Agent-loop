#!/bin/bash

# R19 BEGIN-only candidate driver.
# This file does not run tests, build, migration matrix, source gates, bundle
# assembly, signing, or preview. It establishes one fail-once evidence boundary.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R19_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R19_TASK_DIRECTORY="${R19_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R19_DRIVER_PATH="${R19_TASK_DIRECTORY}/evidence/r19-begin.sh"
readonly R19_MANIFEST_PATH="${R19_TASK_DIRECTORY}/evidence/r19-entry.sha256"
readonly R19_FREEZE_PATH="${R19_TASK_DIRECTORY}/evidence/plan-freeze-r19.md"
readonly R19_REVIEW19_PATH="${R19_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/19-p1-plan-review.md"
readonly R19_BOUNDARY_LOG="${R19_TASK_DIRECTORY}/evidence/r19-clean-boundary.log"
readonly R19_HASH_LOG="${R19_TASK_DIRECTORY}/evidence/r19-hash-manifest.log"
readonly R19_RANCH_ART_DIRECTORY="${R19_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R19_EXPECTED_MANIFEST_COUNT="123"
readonly R19_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R19_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R19_EXPECTED_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R19_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R19_R15_STATE_ROOT_BASENAME="agentloop-r15-state.Zq6Jvm"
readonly R19_R15_BUNDLE_PARENT_BASENAME="agentloop-r15-bundle.2xROcy"
readonly R19_R15_STATE_ROOT="/private/tmp/${R19_R15_STATE_ROOT_BASENAME}"
readonly R19_R15_BUNDLE_PARENT="/private/tmp/${R19_R15_BUNDLE_PARENT_BASENAME}"
readonly R19_R15_ABSENCE_PROOF_IDENTITY="private_tmp_parent_enumeration_exact_basename_v1"
readonly R19_R15_PLANNED_APP="${R19_R15_BUNDLE_PARENT}/AgentLoop.app"
readonly R19_R15_SCREENSHOT="${R19_TASK_DIRECTORY}/evidence/r15-preview-smoke.png"

R19_BOUNDARY_ACTIVE="false"
R19_PHASE="pre_begin"
R19_INVOCATION_ID=""
R19_STATE_ROOT=""
R19_BUNDLE_PARENT=""

r19_utc_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r19_pre_begin_fail() {
  local r19_exit_code="$1"
  shift
  /usr/bin/printf 'R19 pre-BEGIN rejected: %s\n' "$*" >&2
  exit "$r19_exit_code"
}

r19_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R19_BOUNDARY_LOG}"
}

r19_authorization_is_consumed() {
  if [[ "${R19_BOUNDARY_ACTIVE}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${R19_INVOCATION_ID}" &&
        -f "${R19_BOUNDARY_LOG}" &&
        ! -L "${R19_BOUNDARY_LOG}" ]] &&
     /usr/bin/grep -Fx "invocation_id=${R19_INVOCATION_ID}" "${R19_BOUNDARY_LOG}" >/dev/null 2>&1 &&
     /usr/bin/grep -Fx 'authorization_consumed=true' "${R19_BOUNDARY_LOG}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

r19_active_fail() {
  local r19_exit_code="$1"
  local r19_reason="$2"
  local r19_command="${3:-explicit_fail_closed}"
  trap - ERR HUP INT TERM
  set +e
  r19_append_boundary "utc=$(r19_utc_now)"
  r19_append_boundary "status=REJECTED_CONTAMINATED"
  r19_append_boundary "phase=${R19_PHASE}"
  r19_append_boundary "reason=${r19_reason}"
  printf 'failed_command=%q\n' "${r19_command}" >> "${R19_BOUNDARY_LOG}"
  r19_append_boundary "exit_code=${r19_exit_code}"
  r19_append_boundary "state_root=${R19_STATE_ROOT:-UNCREATED}"
  r19_append_boundary "bundle_parent=${R19_BUNDLE_PARENT:-UNCREATED}"
  if [[ -n "${R19_PLANNED_APP:-}" ]]; then
    r19_append_boundary "planned_app=${R19_PLANNED_APP}"
  fi
  r19_append_boundary "retry_same_boundary=false"
  /usr/bin/printf 'R19 rejected after authorization consumption: %s\n' "${r19_reason}" >&2
  exit "$r19_exit_code"
}

r19_unexpected_error() {
  local r19_exit_code="$?"
  local r19_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  if r19_authorization_is_consumed; then
    r19_active_fail "${r19_exit_code}" "unexpected_command_failure" "${r19_command}"
  fi
  printf 'R19 pre-BEGIN command failed: phase=%s rc=%s command=%q\n' \
    "${R19_PHASE}" "${r19_exit_code}" "${r19_command}" >&2
  exit "${r19_exit_code}"
}

r19_signal_error() {
  local r19_signal="$1"
  trap - HUP INT TERM
  if r19_authorization_is_consumed; then
    r19_active_fail "74" "signal_${r19_signal}" "signal_${r19_signal}"
  fi
  /usr/bin/printf 'R19 pre-BEGIN interrupted by signal %s\n' "${r19_signal}" >&2
  exit 74
}

trap r19_unexpected_error ERR
trap 'r19_signal_error HUP' HUP
trap 'r19_signal_error INT' INT
trap 'r19_signal_error TERM' TERM

r19_attestation_fail() {
  local r19_exit_code="$1"
  shift
  if r19_authorization_is_consumed; then
    r19_active_fail "${r19_exit_code}" "$*"
  fi
  r19_pre_begin_fail "${r19_exit_code}" "$*"
}

r19_require_lowercase_sha256() {
  local r19_value="$1"
  local r19_label="$2"
  if [[ "${#r19_value}" -ne 64 ]]; then
    r19_pre_begin_fail 64 "${r19_label} must be exactly 64 lowercase hex characters"
  fi
  case "${r19_value}" in
    *[!0-9a-f]*)
      r19_pre_begin_fail 64 "${r19_label} must be exactly 64 lowercase hex characters"
      ;;
  esac
}

r19_emit_anchor_manifest() {
  /usr/bin/printf '%s  %s\n' "${R19_EXPECTED_FREEZE_SHA}" "${R19_FREEZE_PATH}"
  /usr/bin/printf '%s  %s\n' "${R19_EXPECTED_REVIEW19_SHA}" "${R19_REVIEW19_PATH}"
  /usr/bin/printf '%s  %s\n' "${R19_EXPECTED_DRIVER_SHA}" "${R19_DRIVER_PATH}"
  /usr/bin/printf '%s  %s\n' "${R19_EXPECTED_MANIFEST_SHA}" "${R19_MANIFEST_PATH}"
}

r19_check_anchors_to_stdout() {
  local -a r19_anchor_status
  if r19_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c -; then
    r19_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r19_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${r19_anchor_status[0]}" -ne 0 || "${r19_anchor_status[1]}" -ne 0 ]]; then
    r19_pre_begin_fail 65 "terminal anchor verification failed with producer_rc=${r19_anchor_status[0]} shasum_rc=${r19_anchor_status[1]}"
  fi
}

r19_check_manifest_shape() {
  local r19_manifest_count
  if [[ ! -f "${R19_MANIFEST_PATH}" || -L "${R19_MANIFEST_PATH}" ]]; then
    r19_attestation_fail 66 "static manifest is missing, non-regular, or a symlink"
  fi
  r19_manifest_count="$(/usr/bin/wc -l < "${R19_MANIFEST_PATH}" | /usr/bin/tr -d '[:space:]')"
  if [[ "${r19_manifest_count}" != "${R19_EXPECTED_MANIFEST_COUNT}" ]]; then
    r19_attestation_fail 66 "static manifest entry count is ${r19_manifest_count}, expected ${R19_EXPECTED_MANIFEST_COUNT}"
  fi
  if /usr/bin/grep -F -- "  ${R19_MANIFEST_PATH}" "${R19_MANIFEST_PATH}" >/dev/null 2>&1; then
    r19_attestation_fail 66 "static manifest must not contain itself"
  fi
  if /usr/bin/grep -F -- "  ${R19_FREEZE_PATH}" "${R19_MANIFEST_PATH}" >/dev/null 2>&1; then
    r19_attestation_fail 66 "static manifest must not contain the R19 freeze"
  fi
  if /usr/bin/grep -F -- "  ${R19_REVIEW19_PATH}" "${R19_MANIFEST_PATH}" >/dev/null 2>&1; then
    r19_attestation_fail 66 "static manifest must not contain Review19"
  fi
  if ! /usr/bin/cut -c 67- "${R19_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r19_attestation_fail 66 "static manifest paths are not bytewise sorted and unique"
  fi
  while IFS= read -r r19_manifest_line; do
    local r19_manifest_entry_path="${r19_manifest_line#*  }"
    case "${r19_manifest_entry_path}" in
      "${R19_REPOSITORY_ROOT}"/*)
        ;;
      *)
        r19_attestation_fail 66 "static manifest entry is outside the repository"
        ;;
    esac
    case "${r19_manifest_entry_path}" in
      *"/../"*|*"/./"*|*/..|*/.)
        r19_attestation_fail 66 "static manifest entry contains a non-canonical path segment"
        ;;
    esac
    if [[ ! -f "${r19_manifest_entry_path}" || -L "${r19_manifest_entry_path}" ]]; then
      r19_attestation_fail 66 "static manifest entry is non-regular or a symlink: ${r19_manifest_entry_path}"
    fi
  done < "${R19_MANIFEST_PATH}"
}

r19_check_manifest_to_stdout() {
  local r19_manifest_rc
  if /usr/bin/shasum -a 256 --strict -c "${R19_MANIFEST_PATH}"; then
    r19_manifest_rc=0
  else
    r19_manifest_rc="$?"
  fi
  if [[ "${r19_manifest_rc}" -ne 0 ]]; then
    r19_pre_begin_fail 66 "static manifest verification failed with rc=${r19_manifest_rc}"
  fi
}

r19_require_process_absent() {
  local r19_process_name="$1"
  local r19_process_rc
  if /usr/bin/pgrep -x "${r19_process_name}" >/dev/null 2>&1; then
    r19_process_rc=0
  else
    r19_process_rc="$?"
  fi
  case "${r19_process_rc}" in
    1)
      ;;
    0)
      r19_attestation_fail 69 "${r19_process_name} process is present"
      ;;
    *)
      r19_attestation_fail 69 "pgrep for ${r19_process_name} was indeterminate with rc=${r19_process_rc}"
      ;;
  esac
}

r19_require_absent_path() {
  local r19_path="$1"
  if [[ -e "${r19_path}" || -L "${r19_path}" ]]; then
    r19_pre_begin_fail 68 "runtime artifact already exists: ${r19_path}"
  fi
}

r19_probe_empty_directory() {
  local r19_path="$1"
  local r19_probe_output
  local r19_probe_rc
  if r19_probe_output="$(
    trap - ERR
    /usr/bin/find "${r19_path}" -mindepth 1 -maxdepth 1 -print -quit 2>&1
  )"; then
    r19_probe_rc=0
  else
    r19_probe_rc="$?"
  fi
  if [[ "${r19_probe_rc}" -ne 0 ]]; then
    return 2
  fi
  if [[ -n "${r19_probe_output}" ]]; then
    return 1
  fi
  return 0
}

r19_require_r15_tombstones_absent() {
  local r19_r15_tombstone_probe_output
  local r19_r15_tombstone_probe_rc
  if [[ -z "${R19_R15_STATE_ROOT_BASENAME}" ||
        "${R19_R15_STATE_ROOT_BASENAME}" == "." ||
        "${R19_R15_STATE_ROOT_BASENAME}" == ".." ||
        -z "${R19_R15_BUNDLE_PARENT_BASENAME}" ||
        "${R19_R15_BUNDLE_PARENT_BASENAME}" == "." ||
        "${R19_R15_BUNDLE_PARENT_BASENAME}" == ".." ||
        "${R19_R15_STATE_ROOT_BASENAME}" == "${R19_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r19_pre_begin_fail 70 "R15 tombstone basenames are invalid or non-distinct"
  fi
  if [[ "${R19_R15_STATE_ROOT_BASENAME}" != "agentloop-r15-state.Zq6Jvm" ||
        "${R19_R15_BUNDLE_PARENT_BASENAME}" != "agentloop-r15-bundle.2xROcy" ||
        "${R19_R15_STATE_ROOT}" != "/private/tmp/agentloop-r15-state.Zq6Jvm" ||
        "${R19_R15_BUNDLE_PARENT}" != "/private/tmp/agentloop-r15-bundle.2xROcy" ]]; then
    r19_pre_begin_fail 70 "R15 tombstone frozen basename or path identity drifted"
  fi
  if [[ "${R19_R15_STATE_ROOT}" != "/private/tmp/${R19_R15_STATE_ROOT_BASENAME}" ||
        "${R19_R15_BUNDLE_PARENT}" != "/private/tmp/${R19_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r19_pre_begin_fail 70 "R15 tombstone path reconstruction failed"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r19_pre_begin_fail 70 "R15 tombstone parent is missing, non-directory, or symlink: /private/tmp"
  fi
  if r19_r15_tombstone_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name "${R19_R15_STATE_ROOT_BASENAME}" -o \
        -name "${R19_R15_BUNDLE_PARENT_BASENAME}" \
      \) \
      -print -quit 2>&1
  )"; then
    r19_r15_tombstone_probe_rc=0
  else
    r19_r15_tombstone_probe_rc="$?"
  fi
  if [[ "${r19_r15_tombstone_probe_rc}" -ne 0 ]]; then
    r19_pre_begin_fail 70 "R15 tombstone absence parent enumeration was indeterminate with rc=${r19_r15_tombstone_probe_rc}"
  fi
  if [[ -n "${r19_r15_tombstone_probe_output}" ]]; then
    r19_pre_begin_fail 70 "R15 tombstoned volatile root reappeared: ${r19_r15_tombstone_probe_output}"
  fi
  if [[ -e "${R19_R15_STATE_ROOT}" || -L "${R19_R15_STATE_ROOT}" ]]; then
    r19_pre_begin_fail 70 "R15 tombstoned state root reappeared after parent enumeration: ${R19_R15_STATE_ROOT}"
  fi
  if [[ -e "${R19_R15_BUNDLE_PARENT}" || -L "${R19_R15_BUNDLE_PARENT}" ]]; then
    r19_pre_begin_fail 70 "R15 tombstoned bundle parent reappeared after parent enumeration: ${R19_R15_BUNDLE_PARENT}"
  fi
}

r19_require_no_unconsumed_fresh_roots() {
  local r19_root_probe_output
  local r19_root_probe_rc
  if r19_root_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name 'agentloop-r16-state.*' -o \
        -name 'agentloop-r16-bundle.*' -o \
        -name 'agentloop-r17-state.*' -o \
        -name 'agentloop-r17-bundle.*' -o \
        -name 'agentloop-r18-state.*' -o \
        -name 'agentloop-r18-bundle.*' -o \
        -name 'agentloop-r19-state.*' -o \
        -name 'agentloop-r19-bundle.*' \
      \) \
      -print -quit 2>&1
  )"; then
    r19_root_probe_rc=0
  else
    r19_root_probe_rc="$?"
  fi
  if [[ "${r19_root_probe_rc}" -ne 0 ]]; then
    r19_pre_begin_fail 70 "R16/R17/R18/R19 fresh-root absence probe was indeterminate with rc=${r19_root_probe_rc}"
  fi
  if [[ -n "${r19_root_probe_output}" ]]; then
    r19_pre_begin_fail 70 "R16/R17/R18/R19 fresh root must remain absent: ${r19_root_probe_output}"
  fi
}

r19_exclusive_create_empty() {
  local r19_path="$1"
  ( set -C; : > "${r19_path}" )
}

r19_require_fresh_root() {
  local r19_path="$1"
  local r19_label="$2"
  local r19_probe_rc
  local r19_realpath
  local r19_realpath_rc
  if [[ ! -d "${r19_path}" || -L "${r19_path}" ]]; then
    r19_active_fail 72 "${r19_label}_invalid_type"
  fi
  if r19_realpath="$(
    trap - ERR
    /bin/realpath "${r19_path}" 2>&1
  )"; then
    r19_realpath_rc=0
  else
    r19_realpath_rc="$?"
  fi
  if [[ "${r19_realpath_rc}" -ne 0 ]]; then
    r19_active_fail 72 "${r19_label}_realpath_probe_failed"
  fi
  if [[ "${r19_realpath}" != "${r19_path}" ]]; then
    r19_active_fail 72 "${r19_label}_realpath_mismatch"
  fi
  if r19_probe_empty_directory "${r19_path}"; then
    return 0
  else
    r19_probe_rc="$?"
  fi
  if [[ "${r19_probe_rc}" -eq 1 ]]; then
    r19_active_fail 72 "${r19_label}_not_empty"
  fi
  r19_active_fail 72 "${r19_label}_emptiness_probe_indeterminate"
}

r19_post_activation_anchor_check() {
  local -a r19_anchor_status
  {
    /usr/bin/printf '%s\n' "section=terminal_anchors"
    r19_emit_anchor_manifest
  } >> "${R19_HASH_LOG}"
  if r19_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c - >> "${R19_HASH_LOG}" 2>&1; then
    r19_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r19_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  /usr/bin/printf 'terminal_anchor_producer_rc=%s\n' "${r19_anchor_status[0]}" >> "${R19_HASH_LOG}"
  /usr/bin/printf 'terminal_anchor_shasum_rc=%s\n' "${r19_anchor_status[1]}" >> "${R19_HASH_LOG}"
  if [[ "${r19_anchor_status[0]}" -ne 0 || "${r19_anchor_status[1]}" -ne 0 ]]; then
    r19_active_fail 65 "post_activation_terminal_anchor_failure_producer_${r19_anchor_status[0]}_shasum_${r19_anchor_status[1]}"
  fi
}

r19_post_activation_manifest_check() {
  local r19_manifest_rc
  local r19_manifest_count
  r19_manifest_count="$(/usr/bin/wc -l < "${R19_MANIFEST_PATH}" | /usr/bin/tr -d '[:space:]')"
  /usr/bin/printf '%s\n' "section=static_manifest" >> "${R19_HASH_LOG}"
  /usr/bin/printf 'static_manifest_expected_count=%s\n' "${R19_EXPECTED_MANIFEST_COUNT}" >> "${R19_HASH_LOG}"
  /usr/bin/printf 'static_manifest_actual_count=%s\n' "${r19_manifest_count}" >> "${R19_HASH_LOG}"
  if /usr/bin/shasum -a 256 --strict -c "${R19_MANIFEST_PATH}" >> "${R19_HASH_LOG}" 2>&1; then
    r19_manifest_rc=0
  else
    r19_manifest_rc="$?"
  fi
  /usr/bin/printf 'static_manifest_rc=%s\n' "${r19_manifest_rc}" >> "${R19_HASH_LOG}"
  if [[ "${r19_manifest_rc}" -ne 0 ]]; then
    r19_active_fail 66 "post_activation_static_manifest_failure_rc_${r19_manifest_rc}"
  fi
  if [[ "${r19_manifest_count}" != "${R19_EXPECTED_MANIFEST_COUNT}" ]]; then
    r19_active_fail 66 "post_activation_static_manifest_count_${r19_manifest_count}"
  fi
}

r19_check_ranch_art_structure() {
  local r19_verification_mode="$1"
  local r19_evidence_sink
  local r19_evidence_phase
  local -a r19_expected_basenames=(
    "PixelBarnDay.png"
    "PixelBarnNight.png"
    "PixelCowSideAmber.png"
    "PixelCowSideBlue.png"
    "PixelCowSideCoral.png"
    "PixelCowSideGreen.png"
    "PixelCowSidePink.png"
    "PixelCowSidePurple.png"
    "PixelCowSideTeal.png"
    "PixelCowSleepAmber.png"
    "PixelCowSleepBlue.png"
    "PixelCowSleepCoral.png"
    "PixelCowSleepGreen.png"
    "PixelCowSleepPink.png"
    "PixelCowSleepPurple.png"
    "PixelCowSleepTeal.png"
    "PixelCowStrideAmber.png"
    "PixelCowStrideBlue.png"
    "PixelCowStrideCoral.png"
    "PixelCowStrideGreen.png"
    "PixelCowStridePink.png"
    "PixelCowStridePurple.png"
    "PixelCowStrideTeal.png"
    "PixelPanoramaDay.png"
    "PixelPanoramaNight.png"
    "PixelPastureDay.png"
    "PixelPastureNight.png"
  )
  local -a r19_ranch_pipeline_status

  case "${r19_verification_mode}" in
    pre_begin)
      if r19_authorization_is_consumed; then
        r19_attestation_fail 70 "pre_begin_ranch_art_check_after_authorization_consumption"
      fi
      r19_evidence_sink="/dev/stderr"
      r19_evidence_phase="pre_consumption"
      ;;
    post_activation)
      if ! r19_authorization_is_consumed; then
        r19_pre_begin_fail 70 "post_activation_ranch_art_check_before_authorization_consumption"
      fi
      if [[ ! -f "${R19_HASH_LOG}" || -L "${R19_HASH_LOG}" ]]; then
        r19_active_fail 70 "post_activation_ranch_art_hash_log_invalid"
      fi
      r19_evidence_sink="${R19_HASH_LOG}"
      r19_evidence_phase="post_activation"
      ;;
    *)
      r19_attestation_fail 64 "invalid RanchArt verification mode: ${r19_verification_mode}"
      ;;
  esac

  # Hide raw pathname diagnostics while retaining both numeric pipeline statuses
  # in the fixed fail-closed reason below.
  if /usr/bin/find -P "${R19_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash -c '
      set +x
      set +v
      set -u
      set -f
      LC_ALL=C
      export LC_ALL
      shopt -u nocasematch

      r19_directory="$1"
      shift
      r19_expected_count="$#"
      r19_invalid=0
      r19_partial_final_record=0
      r19_read_rc=1
      r19_total_count=0
      r19_regular_count=0
      r19_nonregular_count=0
      r19_symlink_count=0
      r19_index=0
      r19_other_index=0
      r19_path=""
      r19_basename=""
      r19_prefix="${r19_directory}/"
      r19_expected_value=""
      r19_other_expected_value=""
      r19_seen=()

      if [[ "${r19_expected_count}" -ne 27 ]]; then
        r19_invalid=1
      fi
      if [[ ! -d "${r19_directory}" || -L "${r19_directory}" ]]; then
        r19_invalid=1
      fi

      r19_index=0
      for r19_expected_value in "$@"; do
        r19_seen[r19_index]=0
        if [[ -z "${r19_expected_value}" || "${r19_expected_value}" == */* ]]; then
          r19_invalid=1
        fi
        case "${r19_expected_value}" in
          *[!A-Za-z0-9.]* )
            r19_invalid=1
            ;;
        esac
        r19_other_index=0
        for r19_other_expected_value in "$@"; do
          if [[ "${r19_index}" -ne "${r19_other_index}" &&
                "${r19_expected_value}" == "${r19_other_expected_value}" ]]; then
            r19_invalid=1
          fi
          r19_other_index=$(( r19_other_index + 1 ))
        done
        r19_index=$(( r19_index + 1 ))
      done

      while :; do
        r19_path=""
        if IFS= read -r -d "" r19_path; then
          if [[ "${r19_total_count}" -lt 28 ]]; then
            r19_total_count=$(( r19_total_count + 1 ))
          else
            r19_invalid=1
          fi

          r19_record_regular=0
          if [[ -f "${r19_path}" && ! -L "${r19_path}" ]]; then
            r19_record_regular=1
            if [[ "${r19_regular_count}" -lt 28 ]]; then
              r19_regular_count=$(( r19_regular_count + 1 ))
            else
              r19_invalid=1
            fi
          else
            if [[ "${r19_nonregular_count}" -lt 28 ]]; then
              r19_nonregular_count=$(( r19_nonregular_count + 1 ))
            else
              r19_invalid=1
            fi
          fi
          if [[ -L "${r19_path}" ]]; then
            if [[ "${r19_symlink_count}" -lt 28 ]]; then
              r19_symlink_count=$(( r19_symlink_count + 1 ))
            else
              r19_invalid=1
            fi
          fi

          r19_record_matched=0
          if [[ "${r19_path}" == "${r19_prefix}"* ]]; then
            r19_basename="${r19_path#"${r19_prefix}"}"
            if [[ -n "${r19_basename}" && "${r19_basename}" != */* ]]; then
              r19_index=0
              for r19_expected_value in "$@"; do
                if [[ "${r19_basename}" == "${r19_expected_value}" ]]; then
                  r19_record_matched=1
                  if [[ "${r19_seen[r19_index]}" -eq 0 ]]; then
                    r19_seen[r19_index]=1
                  else
                    r19_invalid=1
                  fi
                  break
                fi
                r19_index=$(( r19_index + 1 ))
              done
            fi
          fi
          if [[ "${r19_record_regular}" -ne 1 || "${r19_record_matched}" -ne 1 ]]; then
            r19_invalid=1
          fi
        else
          r19_read_rc="$?"
          if [[ -n "${r19_path}" ]]; then
            r19_partial_final_record=1
            r19_invalid=1
          fi
          break
        fi
      done

      if [[ "${r19_read_rc}" -ne 1 ||
            "${r19_partial_final_record}" -ne 0 ||
            "${r19_total_count}" -ne 27 ||
            "${r19_regular_count}" -ne 27 ||
            "${r19_nonregular_count}" -ne 0 ||
            "${r19_symlink_count}" -ne 0 ||
            ! -d "${r19_directory}" || -L "${r19_directory}" ]]; then
        r19_invalid=1
      fi
      r19_index=0
      for r19_expected_value in "$@"; do
        if [[ "${r19_seen[r19_index]}" -ne 1 ]]; then
          r19_invalid=1
        fi
        r19_index=$(( r19_index + 1 ))
      done

      if [[ "${r19_invalid}" -ne 0 ]]; then
        exit 1
      fi
      exit 0
    ' "r19-ranch-art-nul-validator-v1" \
      "${R19_RANCH_ART_DIRECTORY}" "${r19_expected_basenames[@]}"; then
    r19_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r19_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  fi

  if [[ "${#r19_ranch_pipeline_status[@]}" -ne 2 ]]; then
    r19_attestation_fail 70 "ranch_art_pipeline_status_shape_invalid"
  fi
  if [[ "${r19_ranch_pipeline_status[0]}" -ne 0 ||
        "${r19_ranch_pipeline_status[1]}" -ne 0 ]]; then
    r19_attestation_fail 70 \
      "ranch_art_nul_validation_failed_find_${r19_ranch_pipeline_status[0]}_validator_${r19_ranch_pipeline_status[1]}"
  fi

  /usr/bin/printf '%s\n' "section=ranch_art_structure" >> "${r19_evidence_sink}"
  /usr/bin/printf 'phase=%s\n' "${r19_evidence_phase}" >> "${r19_evidence_sink}"
  /usr/bin/printf 'ranch_art_verification_mode=%s\n' \
    "${r19_verification_mode}" >> "${r19_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "pathname_transport=find_print0_bash_read_d_nul_v1" \
    "ranch_art_find_rc=${r19_ranch_pipeline_status[0]}" \
    "ranch_art_validator_rc=${r19_ranch_pipeline_status[1]}" \
    "ranch_art_expected_count=27" \
    "ranch_art_parent_type=directory_non_symlink" \
    "ranch_art_node_type=regular_non_symlink" \
    "ranch_art_actual_count=27" \
    "ranch_art_exact_relative_path_set_begin" >> "${r19_evidence_sink}"
  /usr/bin/printf '%s\n' "${r19_expected_basenames[@]}" >> "${r19_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "ranch_art_exact_relative_path_set_end" \
    "nonregular_count=0" \
    "symlink_count=0" \
    "regular_count=27" >> "${r19_evidence_sink}"
}

if [[ "$#" -ne 4 ]]; then
  r19_pre_begin_fail 64 "expected four SHA-256 arguments: freeze Review19 driver manifest"
fi

readonly R19_EXPECTED_FREEZE_SHA="$1"
readonly R19_EXPECTED_REVIEW19_SHA="$2"
readonly R19_EXPECTED_DRIVER_SHA="$3"
readonly R19_EXPECTED_MANIFEST_SHA="$4"

r19_require_lowercase_sha256 "${R19_EXPECTED_FREEZE_SHA}" "freeze hash"
r19_require_lowercase_sha256 "${R19_EXPECTED_REVIEW19_SHA}" "Review19 hash"
r19_require_lowercase_sha256 "${R19_EXPECTED_DRIVER_SHA}" "driver hash"
r19_require_lowercase_sha256 "${R19_EXPECTED_MANIFEST_SHA}" "manifest hash"

if [[ "$0" != "${R19_DRIVER_PATH}" ]]; then
  r19_pre_begin_fail 64 "driver must be invoked by its frozen absolute path"
fi
if [[ "${BASH_SOURCE[0]}" != "${R19_DRIVER_PATH}" ||
      ! -f "${R19_DRIVER_PATH}" ||
      -L "${R19_DRIVER_PATH}" ||
      "$(/bin/realpath "${R19_DRIVER_PATH}")" != "${R19_DRIVER_PATH}" ]]; then
  r19_pre_begin_fail 64 "driver source path or file type is not canonical"
fi
if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r19_pre_begin_fail 64 "Bash 3.2 or newer is required"
fi
if [[ "${LC_ALL:-}" != "C" || "${LANG:-}" != "C" ]]; then
  r19_pre_begin_fail 64 "LC_ALL and LANG must both equal C"
fi
if [[ "${PATH:-}" != "/usr/bin:/bin:/usr/sbin:/sbin" ]]; then
  r19_pre_begin_fail 64 "PATH is not the frozen clean value"
fi
if [[ "${TMPDIR:-}" != "/private/tmp" ]]; then
  r19_pre_begin_fail 64 "TMPDIR is not the frozen clean value"
fi
if [[ "${GIT_CONFIG_NOSYSTEM:-}" != "1" || "${GIT_CONFIG_GLOBAL:-}" != "/dev/null" ]]; then
  r19_pre_begin_fail 64 "Git clean-environment controls are missing"
fi
if [[ -n "${BASH_ENV+x}" || -n "${ENV+x}" || -n "${CDPATH+x}" ]]; then
  r19_pre_begin_fail 64 "shell startup or directory environment was inherited"
fi

R19_PHASE="pre_begin_terminal_anchors"
r19_check_anchors_to_stdout

R19_PHASE="pre_begin_manifest_shape"
r19_check_manifest_shape

R19_PHASE="pre_begin_static_manifest"
r19_check_manifest_to_stdout

R19_PHASE="pre_begin_repository_identity"
R19_ACTUAL_BRANCH="$(/usr/bin/git -C "${R19_REPOSITORY_ROOT}" symbolic-ref --quiet --short HEAD)"
R19_ACTUAL_HEAD="$(/usr/bin/git -C "${R19_REPOSITORY_ROOT}" rev-parse --verify HEAD)"
if [[ "${R19_ACTUAL_BRANCH}" != "${R19_EXPECTED_BRANCH}" ]]; then
  r19_pre_begin_fail 67 "branch is ${R19_ACTUAL_BRANCH}, expected ${R19_EXPECTED_BRANCH}"
fi
if [[ "${R19_ACTUAL_HEAD}" != "${R19_EXPECTED_HEAD}" ]]; then
  r19_pre_begin_fail 67 "HEAD is ${R19_ACTUAL_HEAD}, expected ${R19_EXPECTED_HEAD}"
fi

R19_PHASE="pre_begin_r16_preservation"
R19_R16_RUNTIME_PATHS=(
  "${R19_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R19_TASK_DIRECTORY}/r16-verify.log"
  "${R19_TASK_DIRECTORY}/r16-build.log"
  "${R19_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R19_TASK_DIRECTORY}/impl-report-r16.md"
  "${R19_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
  "${R19_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R19_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R19_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R19_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R19_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
  "${R19_TASK_DIRECTORY}/evidence/r16-preview-smoke.png"
)
for R19_R16_RUNTIME_PATH in "${R19_R16_RUNTIME_PATHS[@]}"; do
  r19_require_absent_path "${R19_R16_RUNTIME_PATH}"
done

R19_PHASE="pre_begin_r17_preservation"
R19_R17_RUNTIME_PATHS=(
  "${R19_TASK_DIRECTORY}/r17-targeted-tests.log"
  "${R19_TASK_DIRECTORY}/r17-verify.log"
  "${R19_TASK_DIRECTORY}/r17-build.log"
  "${R19_TASK_DIRECTORY}/r17-migration-matrix.log"
  "${R19_TASK_DIRECTORY}/impl-report-r17.md"
  "${R19_TASK_DIRECTORY}/evidence/r17-clean-boundary.log"
  "${R19_TASK_DIRECTORY}/evidence/r17-bundle-provenance.log"
  "${R19_TASK_DIRECTORY}/evidence/r17-source-gates.log"
  "${R19_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
  "${R19_TASK_DIRECTORY}/evidence/r17-preview-bootstrap.log"
  "${R19_TASK_DIRECTORY}/evidence/r17-preview-cold-start.log"
  "${R19_TASK_DIRECTORY}/evidence/r17-preview-smoke.png"
)
for R19_R17_RUNTIME_PATH in "${R19_R17_RUNTIME_PATHS[@]}"; do
  r19_require_absent_path "${R19_R17_RUNTIME_PATH}"
done

R19_PHASE="pre_begin_r18_preservation"
R19_R18_RUNTIME_PATHS=(
  "${R19_TASK_DIRECTORY}/r18-targeted-tests.log"
  "${R19_TASK_DIRECTORY}/r18-verify.log"
  "${R19_TASK_DIRECTORY}/r18-build.log"
  "${R19_TASK_DIRECTORY}/r18-migration-matrix.log"
  "${R19_TASK_DIRECTORY}/impl-report-r18.md"
  "${R19_TASK_DIRECTORY}/evidence/r18-clean-boundary.log"
  "${R19_TASK_DIRECTORY}/evidence/r18-bundle-provenance.log"
  "${R19_TASK_DIRECTORY}/evidence/r18-source-gates.log"
  "${R19_TASK_DIRECTORY}/evidence/r18-hash-manifest.log"
  "${R19_TASK_DIRECTORY}/evidence/r18-preview-bootstrap.log"
  "${R19_TASK_DIRECTORY}/evidence/r18-preview-cold-start.log"
  "${R19_TASK_DIRECTORY}/evidence/r18-preview-smoke.png"
)
for R19_R18_RUNTIME_PATH in "${R19_R18_RUNTIME_PATHS[@]}"; do
  r19_require_absent_path "${R19_R18_RUNTIME_PATH}"
done
r19_require_no_unconsumed_fresh_roots

R19_PHASE="pre_begin_runtime_paths"
R19_RUNTIME_PATHS=(
  "${R19_TASK_DIRECTORY}/r19-targeted-tests.log"
  "${R19_TASK_DIRECTORY}/r19-verify.log"
  "${R19_TASK_DIRECTORY}/r19-build.log"
  "${R19_TASK_DIRECTORY}/r19-migration-matrix.log"
  "${R19_TASK_DIRECTORY}/impl-report-r19.md"
  "${R19_TASK_DIRECTORY}/evidence/r19-clean-boundary.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-source-gates.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-hash-manifest.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-preview-smoke.png"
)
for R19_RUNTIME_PATH in "${R19_RUNTIME_PATHS[@]}"; do
  r19_require_absent_path "${R19_RUNTIME_PATH}"
done

R19_PHASE="pre_begin_processes"
r19_require_process_absent "AgentLoop"
r19_require_process_absent "AgentLoopApp"

R19_PHASE="pre_begin_r15_tombstone_absence"
r19_require_r15_tombstones_absent
if [[ -e "${R19_R15_PLANNED_APP}" || -L "${R19_R15_PLANNED_APP}" ]]; then
  r19_pre_begin_fail 70 "R15 planned App must remain absent"
fi
if [[ -e "${R19_R15_SCREENSHOT}" || -L "${R19_R15_SCREENSHOT}" ]]; then
  r19_pre_begin_fail 70 "R15 screenshot must remain absent"
fi

R19_PHASE="pre_begin_activation_metadata"
R19_INVOCATION_ID="r19-$(
  /usr/bin/uuidgen |
    /usr/bin/tr '[:upper:]' '[:lower:]'
)"
if [[ ! "${R19_INVOCATION_ID}" =~ ^r19-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  r19_pre_begin_fail 71 "generated R19 invocation ID has invalid format"
fi
R19_BEGIN_UTC="$(r19_utc_now)"
if [[ ! "${R19_BEGIN_UTC}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  r19_pre_begin_fail 71 "generated R19 begin UTC has invalid format"
fi

R19_PHASE="pre_begin_ranch_art_structure"
r19_check_ranch_art_structure "pre_begin"

if ! (
  set -C
  /usr/bin/printf '%s\n' \
    "boundary=R19_CLEAN_REVERIFICATION" \
    "invocation_id=${R19_INVOCATION_ID}" \
    "utc_begin=${R19_BEGIN_UTC}" \
    "authorization_consumed=true" \
    "status=BEGIN_STARTED" \
    "branch=${R19_ACTUAL_BRANCH}" \
    "head=${R19_ACTUAL_HEAD}" \
    "r15_state_root_pre_begin_observed_state=ABSENT" \
    "r15_bundle_parent_pre_begin_observed_state=ABSENT" \
    "r15_state_root_current_absent=true" \
    "r15_bundle_parent_current_absent=true" \
    "r15_absence_proof_identity=${R19_R15_ABSENCE_PROOF_IDENTITY}" \
    "disappearance_cause=UNKNOWN" \
    "pre_begin_ranch_art_structure=true" \
    "recipe=r19-dev-bundle-v1" \
    "normal_root=/Users/muzi/Library/Application Support/AgentLoop" \
    "normal_root_access_policy=lsof_path_comparison_only" \
    "freeze_sha=${R19_EXPECTED_FREEZE_SHA}" \
    "review19_sha=${R19_EXPECTED_REVIEW19_SHA}" \
    "driver_sha=${R19_EXPECTED_DRIVER_SHA}" \
    "manifest_sha=${R19_EXPECTED_MANIFEST_SHA}" \
    > "${R19_BOUNDARY_LOG}"
); then
  R19_PHASE="activation_boundary"
  r19_attestation_fail 71 "could not exclusive-create and initialize R19 boundary log"
fi
R19_PHASE="activation_boundary"
R19_BOUNDARY_ACTIVE="true"

R19_PHASE="activation_hash_log"
if ! r19_exclusive_create_empty "${R19_HASH_LOG}"; then
  r19_active_fail 71 "exclusive_create_failed_${R19_HASH_LOG}" "exclusive_create"
fi

R19_PHASE="post_activation_ranch_art_structure"
r19_check_ranch_art_structure "post_activation"

R19_PHASE="post_activation_terminal_anchors"
r19_post_activation_anchor_check

R19_PHASE="post_activation_static_manifest"
r19_check_manifest_shape
r19_post_activation_manifest_check
/usr/bin/printf 'frozen_info_plist_sha=%s\n' "${R19_EXPECTED_INFO_PLIST_SHA}" >> "${R19_HASH_LOG}"
/usr/bin/printf 'frozen_ranch_art_manifest_sha=%s\n' "${R19_EXPECTED_RANCH_ART_MANIFEST_SHA}" >> "${R19_HASH_LOG}"
/usr/bin/printf '%s\n' "section=worktree_status" >> "${R19_HASH_LOG}"
/usr/bin/git --no-optional-locks -C "${R19_REPOSITORY_ROOT}" status --short --branch >> "${R19_HASH_LOG}"

R19_PHASE="activation_remaining_logs"
R19_REMAINING_TEXT_LOGS=(
  "${R19_TASK_DIRECTORY}/r19-targeted-tests.log"
  "${R19_TASK_DIRECTORY}/r19-verify.log"
  "${R19_TASK_DIRECTORY}/r19-build.log"
  "${R19_TASK_DIRECTORY}/r19-migration-matrix.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-source-gates.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log"
  "${R19_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
)
for R19_REMAINING_TEXT_LOG in "${R19_REMAINING_TEXT_LOGS[@]}"; do
  if ! r19_exclusive_create_empty "${R19_REMAINING_TEXT_LOG}"; then
    r19_active_fail 71 "exclusive_create_failed_${R19_REMAINING_TEXT_LOG}" "exclusive_create"
  fi
done

R19_PHASE="activation_fresh_roots"
R19_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r19-state.XXXXXX')"
R19_BUNDLE_PARENT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r19-bundle.XXXXXX')"
R19_PLANNED_APP="${R19_BUNDLE_PARENT}/AgentLoop.app"
R19_PLANNED_EXECUTABLE="${R19_PLANNED_APP}/Contents/MacOS/AgentLoop"

r19_require_fresh_root "${R19_STATE_ROOT}" "fresh_state_root"
r19_require_fresh_root "${R19_BUNDLE_PARENT}" "fresh_bundle_parent"
if [[ "${R19_STATE_ROOT}" == "${R19_BUNDLE_PARENT}" ]]; then
  r19_active_fail 72 "fresh_roots_equal"
fi
case "${R19_STATE_ROOT}/" in
  "${R19_BUNDLE_PARENT}/"* )
    r19_active_fail 72 "state_root_nested_in_bundle_parent"
    ;;
esac
case "${R19_BUNDLE_PARENT}/" in
  "${R19_STATE_ROOT}/"* )
    r19_active_fail 72 "bundle_parent_nested_in_state_root"
    ;;
esac
if [[ "${R19_STATE_ROOT}" == "${R19_R15_STATE_ROOT}" ||
      "${R19_STATE_ROOT}" == "${R19_R15_BUNDLE_PARENT}" ||
      "${R19_BUNDLE_PARENT}" == "${R19_R15_STATE_ROOT}" ||
      "${R19_BUNDLE_PARENT}" == "${R19_R15_BUNDLE_PARENT}" ]]; then
  r19_active_fail 72 "fresh_root_reuses_r15_root"
fi
if [[ -e "${R19_PLANNED_APP}" || -L "${R19_PLANNED_APP}" ]]; then
  r19_active_fail 72 "planned_app_preexists"
fi

r19_append_boundary "state_root=${R19_STATE_ROOT}"
r19_append_boundary "bundle_parent=${R19_BUNDLE_PARENT}"
r19_append_boundary "planned_app=${R19_PLANNED_APP}"
r19_append_boundary "planned_executable=${R19_PLANNED_EXECUTABLE}"
r19_append_boundary "final_executable_hash=DEFERRED_TO_LAUNCH_READY"
r19_append_boundary "process_count=0"
r19_append_boundary "r15_planned_app_absent=true"
r19_append_boundary "r15_screenshot_absent=true"
r19_append_boundary "r16_runtime_artifacts_absent=true"
r19_append_boundary "r16_fresh_roots_absent=true"
r19_append_boundary "r16_pre_begin_zero_write_preserved=true"
r19_append_boundary "r17_runtime_artifacts_absent=true"
r19_append_boundary "r17_fresh_roots_absent=true"
r19_append_boundary "r17_not_executed_preserved=true"
r19_append_boundary "r18_runtime_artifacts_absent=true"
r19_append_boundary "r18_fresh_roots_absent=true"
r19_append_boundary "r18_not_executed_preserved=true"
r19_append_boundary "r19_pre_activation_fresh_roots_absent=true"
r19_append_boundary "frozen_info_plist_sha=${R19_EXPECTED_INFO_PLIST_SHA}"
r19_append_boundary "frozen_ranch_art_manifest_sha=${R19_EXPECTED_RANCH_ART_MANIFEST_SHA}"

R19_PHASE="begin_finalization"
r19_require_process_absent "AgentLoop"
r19_require_process_absent "AgentLoopApp"
r19_append_boundary "utc_begin_attested=$(r19_utc_now)"
r19_append_boundary "begin_attestation_complete=true"
r19_append_boundary "status=BEGIN_ATTESTED"
r19_append_boundary "retry_same_boundary=false"

/usr/bin/printf '%s\n' \
  "status=BEGIN_ATTESTED" \
  "invocation_id=${R19_INVOCATION_ID}" \
  "boundary_log=${R19_BOUNDARY_LOG}" \
  "hash_log=${R19_HASH_LOG}" \
  "state_root=${R19_STATE_ROOT}" \
  "bundle_parent=${R19_BUNDLE_PARENT}" \
  "planned_app=${R19_PLANNED_APP}" \
  "planned_executable=${R19_PLANNED_EXECUTABLE}"
