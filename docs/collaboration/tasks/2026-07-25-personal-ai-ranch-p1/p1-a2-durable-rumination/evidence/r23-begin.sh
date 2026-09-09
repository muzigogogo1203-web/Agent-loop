#!/bin/bash

# R23 BEGIN-only candidate driver.
# This file does not run tests, build, migration matrix, source gates, bundle
# assembly, signing, or preview. It establishes one fail-once evidence boundary.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R23_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R23_TASK_DIRECTORY="${R23_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R23_DRIVER_PATH="${R23_TASK_DIRECTORY}/evidence/r23-begin.sh"
readonly R23_MANIFEST_PATH="${R23_TASK_DIRECTORY}/evidence/r23-entry.sha256"
readonly R23_FREEZE_PATH="${R23_TASK_DIRECTORY}/evidence/plan-freeze-r23.md"
readonly R23_REVIEW23_PATH="${R23_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/23-p1-plan-review.md"
readonly R23_BOUNDARY_LOG="${R23_TASK_DIRECTORY}/evidence/r23-clean-boundary.log"
readonly R23_HASH_LOG="${R23_TASK_DIRECTORY}/evidence/r23-hash-manifest.log"
readonly R23_RANCH_ART_DIRECTORY="${R23_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R23_EXPECTED_MANIFEST_COUNT="163"
readonly R23_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R23_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R23_EXPECTED_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R23_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R23_R15_STATE_ROOT_BASENAME="agentloop-r15-state.Zq6Jvm"
readonly R23_R15_BUNDLE_PARENT_BASENAME="agentloop-r15-bundle.2xROcy"
readonly R23_R15_STATE_ROOT="/private/tmp/${R23_R15_STATE_ROOT_BASENAME}"
readonly R23_R15_BUNDLE_PARENT="/private/tmp/${R23_R15_BUNDLE_PARENT_BASENAME}"
readonly R23_R15_ABSENCE_PROOF_IDENTITY="private_tmp_parent_enumeration_exact_basename_v1"
readonly R23_R15_PLANNED_APP="${R23_R15_BUNDLE_PARENT}/AgentLoop.app"
readonly R23_R15_SCREENSHOT="${R23_TASK_DIRECTORY}/evidence/r15-preview-smoke.png"
readonly R23_R19_INVOCATION_ID="r19-daef1dab-0fbe-4a03-bab1-422adc18b3d4"
readonly R23_R19_MANIFEST_PATH="${R23_TASK_DIRECTORY}/evidence/r19-entry.sha256"
readonly R23_R19_FREEZE_PATH="${R23_TASK_DIRECTORY}/evidence/plan-freeze-r19.md"
readonly R23_R19_REVIEW_PATH="${R23_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/19-p1-plan-review.md"
readonly R23_R19_STATE_ROOT_BASENAME="agentloop-r19-state.dNgUXh"
readonly R23_R19_BUNDLE_PARENT_BASENAME="agentloop-r19-bundle.49xVDm"
readonly R23_R19_STATE_ROOT="/private/tmp/agentloop-r19-state.dNgUXh"
readonly R23_R19_BUNDLE_PARENT="/private/tmp/agentloop-r19-bundle.49xVDm"
readonly R23_R19_PLANNED_APP="${R23_R19_BUNDLE_PARENT}/AgentLoop.app"
readonly R23_R19_SCREENSHOT="${R23_TASK_DIRECTORY}/evidence/r19-preview-smoke.png"
readonly R23_R19_BOUNDARY_LOG="${R23_TASK_DIRECTORY}/evidence/r19-clean-boundary.log"
readonly R23_R19_HASH_LOG="${R23_TASK_DIRECTORY}/evidence/r19-hash-manifest.log"
readonly R23_R19_TARGETED_LOG="${R23_TASK_DIRECTORY}/r19-targeted-tests.log"
readonly R23_R19_VERIFY_LOG="${R23_TASK_DIRECTORY}/r19-verify.log"
readonly R23_R19_REPORT="${R23_TASK_DIRECTORY}/impl-report-r19.md"
readonly R23_R20_INVOCATION_ID="r20-98452cde-0ff4-4b66-b3f6-8085eb045a6f"
readonly R23_R20_MANIFEST_PATH="${R23_TASK_DIRECTORY}/evidence/r20-entry.sha256"
readonly R23_R20_FREEZE_PATH="${R23_TASK_DIRECTORY}/evidence/plan-freeze-r20.md"
readonly R23_R20_REVIEW_PATH="${R23_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/20-p1-plan-review.md"
readonly R23_R20_STATE_ROOT_BASENAME="agentloop-r20-state.3QwlQa"
readonly R23_R20_BUNDLE_PARENT_BASENAME="agentloop-r20-bundle.30V5RH"
readonly R23_R20_STATE_ROOT="/private/tmp/agentloop-r20-state.3QwlQa"
readonly R23_R20_BUNDLE_PARENT="/private/tmp/agentloop-r20-bundle.30V5RH"
readonly R23_R20_APP="${R23_R20_BUNDLE_PARENT}/AgentLoop.app"
readonly R23_R20_EXECUTABLE="${R23_R20_APP}/Contents/MacOS/AgentLoop"
readonly R23_R20_INFO_PLIST="${R23_R20_APP}/Contents/Info.plist"
readonly R23_R20_SCREENSHOT="${R23_TASK_DIRECTORY}/evidence/r20-preview-smoke.png"
readonly R23_R20_BOUNDARY_LOG="${R23_TASK_DIRECTORY}/evidence/r20-clean-boundary.log"
readonly R23_R20_HASH_LOG="${R23_TASK_DIRECTORY}/evidence/r20-hash-manifest.log"
readonly R23_R20_TARGETED_LOG="${R23_TASK_DIRECTORY}/r20-targeted-tests.log"
readonly R23_R20_VERIFY_LOG="${R23_TASK_DIRECTORY}/r20-verify.log"
readonly R23_R20_BUILD_LOG="${R23_TASK_DIRECTORY}/r20-build.log"
readonly R23_R20_REPORT="${R23_TASK_DIRECTORY}/impl-report-r20.md"
readonly R23_R20_EXECUTABLE_SHA="d55fc10e674b77b480a85de46137eff40d40bd94b27c8e33b0d49f55d40a049c"
readonly R23_R20_INFO_PLIST_SHA="5c67c5737662236bd4703ff1ddf968d54b65faf6e2610eeec95786ad63743b58"
readonly R23_R20_SIGNED_BUNDLE_MANIFEST_SHA="06e063d4fdd541a808c78eacc5b34ddfd64874a3ab1648bbfe6bf74646db8170"
readonly R23_R20_CORE_FINAL_SHA="c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275"
readonly R23_R20_TEST_FINAL_SHA="66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26"
readonly R23_R21_DRIVER_PATH="${R23_TASK_DIRECTORY}/evidence/r21-begin.sh"
readonly R23_R21_MANIFEST_PATH="${R23_TASK_DIRECTORY}/evidence/r21-entry.sha256"
readonly R23_R21_FREEZE_PATH="${R23_TASK_DIRECTORY}/evidence/plan-freeze-r21.md"
readonly R23_R21_REVIEW_PATH="${R23_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/21-p1-plan-review.md"
readonly R23_R22_DRIVER_PATH="${R23_TASK_DIRECTORY}/evidence/r22-begin.sh"
readonly R23_R22_MANIFEST_PATH="${R23_TASK_DIRECTORY}/evidence/r22-entry.sha256"
readonly R23_R22_FREEZE_PATH="${R23_TASK_DIRECTORY}/evidence/plan-freeze-r22.md"
readonly R23_R22_REVIEW_PATH="${R23_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/22-p1-plan-review.md"
readonly R23_R22_DRIVER_SHA="55c87eca611f5d6fad6efdc1d21de79650301f3134e0b3416e638d392e98a713"
readonly R23_R22_MANIFEST_SHA="57100ca88f871e79632e891b69a70b3696cb64d3b67f8b0c9805ff1eb31728e8"
readonly R23_R22_FREEZE_SHA="839a46ad50d8bb943240267679e5878613d7ee42b5664106b4dc5b0a3dc1a8bf"
readonly R23_R22_REVIEW_SHA="bf007443ac2b1932fbde93cf908a99b50cb4878de3e485118092bb24552050b5"
readonly R23_IMPLEMENTATION_CORE_PATH="${R23_REPOSITORY_ROOT}/Sources/AgentLoopCore/Loop/AgentLoop.swift"
readonly R23_IMPLEMENTATION_TEST_PATH="${R23_REPOSITORY_ROOT}/Sources/AgentLoopTestSuite/AgentLoopTests.swift"

R23_BOUNDARY_ACTIVE="false"
R23_BOUNDARY_INITIALIZED="false"
R23_PHASE="pre_begin"
R23_INVOCATION_ID=""
R23_STATE_ROOT=""
R23_BUNDLE_PARENT=""
readonly R23_ZERO_36="000000000000000000000000000000000000"
readonly R23_ZERO_38="00000000000000000000000000000000000000"
readonly R23_ONE_36="111111111111111111111111111111111111"
readonly R23_R20_REVIEW22_BASELINE_MASK="11101011100000000000000000000000000010"
R23_R20_EROSION_FIRST_MASK=""
R23_R20_EROSION_LATEST_MASK=""
R23_R20_EROSION_PRE_BEGIN_MASK=""
R23_R20_EROSION_POST_ACTIVATION_MASK=""
R23_R20_EROSION_FIRST_STATE=""
R23_R20_EROSION_LATEST_STATE=""
R23_R20_EROSION_PRE_BEGIN_STATE=""
R23_R20_EROSION_POST_ACTIVATION_STATE=""
R23_R20_CAPTURED_MASK=""
R23_R20_CAPTURED_STATE=""
R23_R20_CAPTURED_NODE_COUNT="0"
R23_R20_CAPTURED_DIRECTORY_COUNT="0"
R23_R20_CAPTURED_FILE_COUNT="0"
R23_R20_CAPTURE_PARENT_PRESENT="0"
R23_R20_CAPTURE_APP_PRESENT="0"
R23_R20_CURRENT_SIGNED_APP_VERIFIED="false"

readonly -a R23_R20_EXPECTED_NODE_TRIPLES=(
    "D"
    "Contents"
    "-"
    "F"
    "Contents/Info.plist"
    "${R23_R20_INFO_PLIST_SHA}"
    "D"
    "Contents/MacOS"
    "-"
    "F"
    "Contents/MacOS/AgentLoop"
    "${R23_R20_EXECUTABLE_SHA}"
    "D"
    "Contents/Resources"
    "-"
    "D"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle"
    "-"
    "D"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt"
    "-"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnDay.png"
    "8e3fa4eae64bd933b2119e8609fed3a95621207ff3a40fa4d63de68c40e8d93b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnNight.png"
    "13c402ff5225e87bc3e9dd686a022034f52a4b7004563507ebd9e86cc9999b9b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideAmber.png"
    "3166ee2fbf917c2700913fc0b8e989f09efa49c9d26035412be8bdde6e022a98"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideBlue.png"
    "bc59959c81e6957cf6403e79ef48d4f7b543cfb3b6980c1900f6a19de0f1a3a9"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideCoral.png"
    "da471a67b32b32a560ef3234ccaf42a66c3ffb403da7c3a8c8de9f7eab709cb3"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideGreen.png"
    "2b5c2178fa8ca4ba11b5615347f6029450237c1a3cfa97220dee7da34a6cad70"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePink.png"
    "7e424ea3ea38a0d927d9548e53ac7575c18224f24a05fc5163b2aaa505dee409"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePurple.png"
    "5a1b90a96720cbb03572babd2d234f8a6e5945a5ae2e650556108ff6185dd2c8"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideTeal.png"
    "b5577e1bb6bdb448f25f5078ce534167471dac47b02910e48346fdd08a1fcbc1"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepAmber.png"
    "337a18ea9ff0f48d71eb8f799942290d49c17c6e725f614ca93500738fad99d0"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepBlue.png"
    "9ca08f0809cdebee7ff5d340494fc85b3df9d9c16cb9d739419c1c9debb18c4b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepCoral.png"
    "73a4cdad14d69ccf25106aba261b36c792ca004634a88e8a2be24ad04ecd306b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepGreen.png"
    "326be64cd3c4b6ac2ff0b2d991c5eff0a7752616a5cf4d8297a1fed6010d7513"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPink.png"
    "bbc2145cedc821959420c1a27f50ef1c2454c36c0b11d17f8da43e4259d80444"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPurple.png"
    "e9def94b358c6950c5f3168124d7a3563c8f0680e386149d12538ae30a6fcbe3"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepTeal.png"
    "7a68441ea798d211b13f9764928332bb4cf1a1607646c55fb0a1f0bfa4773627"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideAmber.png"
    "3f8bbbb82fb11e4934efc97018e084e2eab541c97ed25ecc1382996392ac7c8c"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideBlue.png"
    "cbf47e2668e19e1ce32b98b6ec1fcc3403f63c358a8dababa3c0da09946f8fb1"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideCoral.png"
    "55726ca797194d1c428567426a6b2fae50dc01bb43795dbb7b1aa1c19b532650"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideGreen.png"
    "08efff075a883dbbdda94eb3388910bfb7c2c0e042a818bb5696dba3baa6cc8b"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePink.png"
    "cd0cf39c9120fbecff1433387ebe4ddcff57a3c468a62b0fb78af29621a15b8e"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePurple.png"
    "d31abde4d4e4b70ddf2bdd547226ff81bc808155308aa40430d78e87f8d81c1a"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideTeal.png"
    "27926a3f3088a4d570c9acfbf1ba599b6387a16f1bdc0df3dd413eb65c2e5540"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaDay.png"
    "35f89d34928e3bba5d68fbc52a55dfa55df6cf586ca867b05b5d1198e1b1d308"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaNight.png"
    "fba4f7457df442a55280fa1af7ad03e1443d63c92e47c7fb1efd99196c2a8e25"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureDay.png"
    "6d831556ccfcc2d173683375b29579bd75926e6e8668e78bfb311823b3d8966f"
    "F"
    "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureNight.png"
    "0a106a90f04569292e150071dc1649c5fc995dd6921b43f2f8874039d89f6909"
    "D"
    "Contents/_CodeSignature"
    "-"
    "F"
    "Contents/_CodeSignature/CodeResources"
    "4e903bc32534480c4fa8a17490e49c496e655f1827eafbed280d09fc0eb90ae4"
)

r23_utc_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r23_pre_begin_fail() {
  local r23_exit_code="$1"
  shift
  /usr/bin/printf 'R23 pre-BEGIN rejected: %s\n' "$*" >&2
  exit "$r23_exit_code"
}

r23_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R23_BOUNDARY_LOG}"
}

r23_authorization_is_consumed() {
  if [[ "${R23_BOUNDARY_ACTIVE}" == "true" ]]; then
    return 0
  fi
  if [[ -n "${R23_INVOCATION_ID}" &&
        -f "${R23_BOUNDARY_LOG}" &&
        ! -L "${R23_BOUNDARY_LOG}" ]] &&
     /usr/bin/grep -Fx "invocation_id=${R23_INVOCATION_ID}" "${R23_BOUNDARY_LOG}" >/dev/null 2>&1 &&
     /usr/bin/grep -Fx 'authorization_consumed=true' "${R23_BOUNDARY_LOG}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

r23_active_fail() {
  local r23_exit_code="$1"
  local r23_reason="$2"
  local r23_command="${3:-explicit_fail_closed}"
  trap - ERR HUP INT TERM
  set +e
  if [[ "${R23_BOUNDARY_INITIALIZED}" != "true" ]]; then
    /usr/bin/printf '\n' >> "${R23_BOUNDARY_LOG}"
    r23_append_boundary "recovery_invocation_id=${R23_INVOCATION_ID}"
    r23_append_boundary "recovery_authorization_consumed=true"
    r23_append_boundary "recovery_boundary_exclusive_create_succeeded=true"
    r23_append_boundary "boundary_initialization_complete=false"
  fi
  r23_append_boundary "utc=$(r23_utc_now)"
  r23_append_boundary "status=REJECTED_CONTAMINATED"
  r23_append_boundary "phase=${R23_PHASE}"
  r23_append_boundary "reason=${r23_reason}"
  r23_append_boundary "r20_review22_baseline_mask=${R23_R20_REVIEW22_BASELINE_MASK:-UNAVAILABLE}"
  r23_append_boundary "r20_erosion_first_mask=${R23_R20_EROSION_FIRST_MASK:-UNCOMMITTED}"
  r23_append_boundary "r20_erosion_first_state=${R23_R20_EROSION_FIRST_STATE:-UNCOMMITTED}"
  r23_append_boundary "r20_erosion_latest_mask=${R23_R20_EROSION_LATEST_MASK:-UNCOMMITTED}"
  r23_append_boundary "r20_erosion_latest_state=${R23_R20_EROSION_LATEST_STATE:-UNCOMMITTED}"
  r23_append_boundary "r20_capture_mask=${R23_R20_CAPTURED_MASK:-UNCOMMITTED}"
  r23_append_boundary "r20_capture_state=${R23_R20_CAPTURED_STATE:-UNCOMMITTED}"
  r23_append_boundary "r20_capture_node_count=${R23_R20_CAPTURED_NODE_COUNT:-UNCOMMITTED}"
  r23_append_boundary "r20_capture_directory_count=${R23_R20_CAPTURED_DIRECTORY_COUNT:-UNCOMMITTED}"
  r23_append_boundary "r20_capture_file_count=${R23_R20_CAPTURED_FILE_COUNT:-UNCOMMITTED}"
  printf 'failed_command=%q\n' "${r23_command}" >> "${R23_BOUNDARY_LOG}"
  r23_append_boundary "exit_code=${r23_exit_code}"
  r23_append_boundary "state_root=${R23_STATE_ROOT:-UNCREATED}"
  r23_append_boundary "bundle_parent=${R23_BUNDLE_PARENT:-UNCREATED}"
  if [[ -n "${R23_PLANNED_APP:-}" ]]; then
    r23_append_boundary "planned_app=${R23_PLANNED_APP}"
  fi
  r23_append_boundary "retry_same_boundary=false"
  /usr/bin/printf 'R23 rejected after authorization consumption: %s\n' "${r23_reason}" >&2
  exit "$r23_exit_code"
}

r23_unexpected_error() {
  local r23_exit_code="$?"
  local r23_command="${BASH_COMMAND:-unknown}"
  trap - ERR
  if r23_authorization_is_consumed; then
    r23_active_fail "${r23_exit_code}" "unexpected_command_failure" "${r23_command}"
  fi
  printf 'R23 pre-BEGIN command failed: phase=%s rc=%s command=%q\n' \
    "${R23_PHASE}" "${r23_exit_code}" "${r23_command}" >&2
  exit "${r23_exit_code}"
}

r23_signal_error() {
  local r23_signal="$1"
  trap - HUP INT TERM
  if r23_authorization_is_consumed; then
    r23_active_fail "74" "signal_${r23_signal}" "signal_${r23_signal}"
  fi
  /usr/bin/printf 'R23 pre-BEGIN interrupted by signal %s\n' "${r23_signal}" >&2
  exit 74
}

trap r23_unexpected_error ERR
trap 'r23_signal_error HUP' HUP
trap 'r23_signal_error INT' INT
trap 'r23_signal_error TERM' TERM

r23_attestation_fail() {
  local r23_exit_code="$1"
  shift
  if r23_authorization_is_consumed; then
    r23_active_fail "${r23_exit_code}" "$*"
  fi
  r23_pre_begin_fail "${r23_exit_code}" "$*"
}

r23_require_lowercase_sha256() {
  local r23_value="$1"
  local r23_label="$2"
  if [[ "${#r23_value}" -ne 64 ]]; then
    r23_pre_begin_fail 64 "${r23_label} must be exactly 64 lowercase hex characters"
  fi
  case "${r23_value}" in
    *[!0-9a-f]*)
      r23_pre_begin_fail 64 "${r23_label} must be exactly 64 lowercase hex characters"
      ;;
  esac
}

r23_load_review23_machine_block() {
  local r23_review_values
  local r23_review_values_rc
  local r23_review_freeze_sha
  local r23_review_driver_sha
  local r23_review_manifest_sha
  local r23_review_extra
  if [[ ! -f "${R23_REVIEW23_PATH}" || -L "${R23_REVIEW23_PATH}" ]]; then
    r23_pre_begin_fail 65 "Review23 is missing, non-regular, or a symlink"
  fi
  if r23_review_values="$(
    trap - ERR
    /usr/bin/awk '
      BEGIN {
        in_block = 0
        begin_count = 0
        end_count = 0
        block_line_count = 0
        authority_count = 0
        standing_goal_count = 0
        independence_count = 0
        write_scope_count = 0
        echo_count = 0
        verdict_count = 0
        human_verdict_count = 0
        other_human_verdict_count = 0
        freeze_count = 0
        driver_count = 0
        manifest_count = 0
        branch_count = 0
        head_count = 0
        count_count = 0
      }
      $0 == "R23_MACHINE_BLOCK_BEGIN" {
        begin_count++
        if (in_block != 0) exit 2
        in_block = 1
        next
      }
      $0 == "R23_MACHINE_BLOCK_END" {
        end_count++
        if (in_block != 1) exit 2
        in_block = 0
        next
      }
      in_block == 1 {
        block_line_count++
        if ($0 == "authority_mode=standing_goal_automatic_after_review23") authority_count++
        else if ($0 == "standing_goal_authority_verified=true") standing_goal_count++
        else if ($0 == "reviewer_independence_attested=true") independence_count++
        else if ($0 == "reviewer_write_scope=review23_only") write_scope_count++
        else if ($0 == "user_hash_echo_required=false") echo_count++
        else if ($0 == "review_verdict=APPROVED_0_P0_0_P1") verdict_count++
        else if (index($0, "freeze_sha=") == 1) {
          freeze_count++
          freeze_sha = substr($0, 12)
        }
        else if (index($0, "driver_sha=") == 1) {
          driver_count++
          driver_sha = substr($0, 12)
        }
        else if (index($0, "manifest_sha=") == 1) {
          manifest_count++
          manifest_sha = substr($0, 14)
        }
        else if ($0 == "branch=codex/personal-ai-ranch-p0") branch_count++
        else if ($0 == "head=02334ec8d21533be81d93d39191bc7d9b9c24f7f") head_count++
        else if ($0 == "manifest_count=163") count_count++
        else exit 2
        next
      }
      $0 == "Verdict: APPROVED — 0 P0 / 0 P1" {
        human_verdict_count++
        next
      }
      index($0, "Verdict:") == 1 {
        other_human_verdict_count++
        next
      }
      END {
        if (in_block != 0 ||
            begin_count != 1 || end_count != 1 || block_line_count != 12 ||
            authority_count != 1 || standing_goal_count != 1 ||
            independence_count != 1 || write_scope_count != 1 ||
            echo_count != 1 || verdict_count != 1 || human_verdict_count != 1 ||
            other_human_verdict_count != 0 ||
            freeze_count != 1 || driver_count != 1 || manifest_count != 1 ||
            branch_count != 1 || head_count != 1 || count_count != 1 ||
            length(freeze_sha) != 64 || freeze_sha ~ /[^0-9a-f]/ ||
            length(driver_sha) != 64 || driver_sha ~ /[^0-9a-f]/ ||
            length(manifest_sha) != 64 || manifest_sha ~ /[^0-9a-f]/) exit 2
        printf "%s %s %s\n", freeze_sha, driver_sha, manifest_sha
      }
    ' "${R23_REVIEW23_PATH}"
  )"; then
    r23_review_values_rc=0
  else
    r23_review_values_rc="$?"
  fi
  if [[ "${r23_review_values_rc}" -ne 0 ]]; then
    r23_pre_begin_fail 65 "Review23 machine block validation failed with rc=${r23_review_values_rc}"
  fi
  r23_review_extra=""
  IFS=' ' read -r \
    r23_review_freeze_sha \
    r23_review_driver_sha \
    r23_review_manifest_sha \
    r23_review_extra <<< "${r23_review_values}"
  if [[ -n "${r23_review_extra}" ||
        -z "${r23_review_freeze_sha}" ||
        -z "${r23_review_driver_sha}" ||
        -z "${r23_review_manifest_sha}" ]]; then
    r23_pre_begin_fail 65 "Review23 machine block output shape is invalid"
  fi
  R23_EXPECTED_FREEZE_SHA="${r23_review_freeze_sha}"
  R23_EXPECTED_DRIVER_SHA="${r23_review_driver_sha}"
  R23_EXPECTED_MANIFEST_SHA="${r23_review_manifest_sha}"
}

r23_emit_anchor_manifest() {
  /usr/bin/printf '%s  %s\n' "${R23_EXPECTED_FREEZE_SHA}" "${R23_FREEZE_PATH}"
  /usr/bin/printf '%s  %s\n' "${R23_EXPECTED_REVIEW23_SHA}" "${R23_REVIEW23_PATH}"
  /usr/bin/printf '%s  %s\n' "${R23_EXPECTED_DRIVER_SHA}" "${R23_DRIVER_PATH}"
  /usr/bin/printf '%s  %s\n' "${R23_EXPECTED_MANIFEST_SHA}" "${R23_MANIFEST_PATH}"
}

r23_check_anchors_to_stdout() {
  local -a r23_anchor_status
  if r23_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c -; then
    r23_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r23_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${r23_anchor_status[0]}" -ne 0 || "${r23_anchor_status[1]}" -ne 0 ]]; then
    r23_pre_begin_fail 65 "terminal anchor verification failed with producer_rc=${r23_anchor_status[0]} shasum_rc=${r23_anchor_status[1]}"
  fi
}

r23_manifest_contains_path() {
  local r23_manifest_file="$1"
  local r23_expected_path="$2"
  local r23_manifest_line
  local r23_manifest_entry_path
  while IFS= read -r r23_manifest_line || [[ -n "${r23_manifest_line}" ]]; do
    r23_manifest_entry_path="${r23_manifest_line#*  }"
    if [[ "${r23_manifest_entry_path}" == "${r23_expected_path}" ]]; then
      return 0
    fi
  done < "${r23_manifest_file}"
  return 1
}

r23_check_manifest_shape() {
  local r23_manifest_count
  local r23_manifest_count_rc
  local r23_r22_manifest_count
  local r23_r22_manifest_count_rc
  local r23_r22_manifest_line
  local r23_r22_manifest_entry_path
  local r23_required_addition
  local -a r23_required_additions=(
    "${R23_DRIVER_PATH}"
    "${R23_R22_MANIFEST_PATH}"
    "${R23_R22_FREEZE_PATH}"
    "${R23_R22_REVIEW_PATH}"
  )
  if [[ ! -f "${R23_MANIFEST_PATH}" || -L "${R23_MANIFEST_PATH}" ]]; then
    r23_attestation_fail 66 "static manifest is missing, non-regular, or a symlink"
  fi
  if r23_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R23_MANIFEST_PATH}"
  )"; then
    r23_manifest_count_rc=0
  else
    r23_manifest_count_rc="$?"
  fi
  if [[ "${r23_manifest_count_rc}" -ne 0 ]]; then
    r23_attestation_fail 66 "static manifest record count failed with rc=${r23_manifest_count_rc}"
  fi
  if [[ "${r23_manifest_count}" != "${R23_EXPECTED_MANIFEST_COUNT}" ]]; then
    r23_attestation_fail 66 "static manifest entry count is ${r23_manifest_count}, expected ${R23_EXPECTED_MANIFEST_COUNT}"
  fi
  if /usr/bin/grep -F -- "  ${R23_MANIFEST_PATH}" "${R23_MANIFEST_PATH}" >/dev/null 2>&1; then
    r23_attestation_fail 66 "static manifest must not contain itself"
  fi
  if /usr/bin/grep -F -- "  ${R23_FREEZE_PATH}" "${R23_MANIFEST_PATH}" >/dev/null 2>&1; then
    r23_attestation_fail 66 "static manifest must not contain the R23 freeze"
  fi
  if /usr/bin/grep -F -- "  ${R23_REVIEW23_PATH}" "${R23_MANIFEST_PATH}" >/dev/null 2>&1; then
    r23_attestation_fail 66 "static manifest must not contain Review23"
  fi
  if ! /usr/bin/cut -c 67- "${R23_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r23_attestation_fail 66 "static manifest paths are not bytewise sorted and unique"
  fi
  while IFS= read -r r23_manifest_line || [[ -n "${r23_manifest_line}" ]]; do
    local r23_manifest_entry_path="${r23_manifest_line#*  }"
    case "${r23_manifest_entry_path}" in
      "${R23_REPOSITORY_ROOT}"/*)
        ;;
      *)
        r23_attestation_fail 66 "static manifest entry is outside the repository"
        ;;
    esac
    case "${r23_manifest_entry_path}" in
      *"/../"*|*"/./"*|*/..|*/.)
        r23_attestation_fail 66 "static manifest entry contains a non-canonical path segment"
        ;;
    esac
    if [[ ! -f "${r23_manifest_entry_path}" || -L "${r23_manifest_entry_path}" ]]; then
      r23_attestation_fail 66 "static manifest entry is non-regular or a symlink: ${r23_manifest_entry_path}"
    fi
  done < "${R23_MANIFEST_PATH}"

  if ! /usr/bin/grep -Fx -- \
      "${R23_R20_CORE_FINAL_SHA}  ${R23_IMPLEMENTATION_CORE_PATH}" \
      "${R23_MANIFEST_PATH}" >/dev/null 2>&1; then
    r23_attestation_fail 66 "R23 manifest does not pin the immutable R20-final Core source"
  fi
  if ! /usr/bin/grep -Fx -- \
      "${R23_R20_TEST_FINAL_SHA}  ${R23_IMPLEMENTATION_TEST_PATH}" \
      "${R23_MANIFEST_PATH}" >/dev/null 2>&1; then
    r23_attestation_fail 66 "R23 manifest does not pin the R20-final TestSuite entry source"
  fi

  if [[ ! -f "${R23_R22_MANIFEST_PATH}" || -L "${R23_R22_MANIFEST_PATH}" ]]; then
    r23_attestation_fail 66 "immutable R22 manifest is missing, non-regular, or a symlink"
  fi
  if r23_r22_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R23_R22_MANIFEST_PATH}"
  )"; then
    r23_r22_manifest_count_rc=0
  else
    r23_r22_manifest_count_rc="$?"
  fi
  if [[ "${r23_r22_manifest_count_rc}" -ne 0 ]]; then
    r23_attestation_fail 66 "immutable R22 manifest record count failed with rc=${r23_r22_manifest_count_rc}"
  fi
  if [[ "${r23_r22_manifest_count}" != "159" ]]; then
    r23_attestation_fail 66 "immutable R22 manifest no longer has exactly 159 entries"
  fi
  if ! /usr/bin/cut -c 67- "${R23_R22_MANIFEST_PATH}" | LC_ALL=C /usr/bin/sort -cu; then
    r23_attestation_fail 66 "immutable R22 manifest paths are not bytewise sorted and unique"
  fi
  if [[ "${#r23_required_additions[@]}" -ne 4 ]]; then
    r23_attestation_fail 66 "R23 required-addition set no longer has exactly 4 paths"
  fi
  while IFS= read -r r23_r22_manifest_line || [[ -n "${r23_r22_manifest_line}" ]]; do
    r23_r22_manifest_entry_path="${r23_r22_manifest_line#*  }"
    if ! r23_manifest_contains_path "${R23_MANIFEST_PATH}" "${r23_r22_manifest_entry_path}"; then
      r23_attestation_fail 66 "R23 manifest does not inherit the complete R22 path set"
    fi
  done < "${R23_R22_MANIFEST_PATH}"
  for r23_required_addition in "${r23_required_additions[@]}"; do
    if r23_manifest_contains_path "${R23_R22_MANIFEST_PATH}" "${r23_required_addition}"; then
      r23_attestation_fail 66 "R23 required addition unexpectedly overlaps the R22 path set"
    fi
    if ! r23_manifest_contains_path "${R23_MANIFEST_PATH}" "${r23_required_addition}"; then
      r23_attestation_fail 66 "R23 manifest is missing a required addition"
    fi
  done
}

r23_check_manifest_to_stdout() {
  local r23_manifest_rc
  if /usr/bin/shasum -a 256 --strict -c "${R23_MANIFEST_PATH}"; then
    r23_manifest_rc=0
  else
    r23_manifest_rc="$?"
  fi
  if [[ "${r23_manifest_rc}" -ne 0 ]]; then
    r23_pre_begin_fail 66 "static manifest verification failed with rc=${r23_manifest_rc}"
  fi
}

r23_require_process_absent() {
  local r23_process_name="$1"
  local r23_process_rc
  if /usr/bin/pgrep -x "${r23_process_name}" >/dev/null 2>&1; then
    r23_process_rc=0
  else
    r23_process_rc="$?"
  fi
  case "${r23_process_rc}" in
    1)
      ;;
    0)
      r23_attestation_fail 69 "${r23_process_name} process is present"
      ;;
    *)
      r23_attestation_fail 69 "pgrep for ${r23_process_name} was indeterminate with rc=${r23_process_rc}"
      ;;
  esac
}

r23_require_absent_path() {
  local r23_path="$1"
  if [[ -e "${r23_path}" || -L "${r23_path}" ]]; then
    r23_attestation_fail 68 "runtime artifact already exists: ${r23_path}"
  fi
}

r23_probe_empty_directory() {
  local r23_path="$1"
  local r23_probe_output
  local r23_probe_rc
  if r23_probe_output="$(
    trap - ERR
    /usr/bin/find "${r23_path}" -mindepth 1 -maxdepth 1 -print -quit 2>&1
  )"; then
    r23_probe_rc=0
  else
    r23_probe_rc="$?"
  fi
  if [[ "${r23_probe_rc}" -ne 0 ]]; then
    return 2
  fi
  if [[ -n "${r23_probe_output}" ]]; then
    return 1
  fi
  return 0
}

r23_require_r15_tombstones_absent() {
  local r23_r15_tombstone_probe_output
  local r23_r15_tombstone_probe_rc
  if [[ -z "${R23_R15_STATE_ROOT_BASENAME}" ||
        "${R23_R15_STATE_ROOT_BASENAME}" == "." ||
        "${R23_R15_STATE_ROOT_BASENAME}" == ".." ||
        -z "${R23_R15_BUNDLE_PARENT_BASENAME}" ||
        "${R23_R15_BUNDLE_PARENT_BASENAME}" == "." ||
        "${R23_R15_BUNDLE_PARENT_BASENAME}" == ".." ||
        "${R23_R15_STATE_ROOT_BASENAME}" == "${R23_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r23_pre_begin_fail 70 "R15 tombstone basenames are invalid or non-distinct"
  fi
  if [[ "${R23_R15_STATE_ROOT_BASENAME}" != "agentloop-r15-state.Zq6Jvm" ||
        "${R23_R15_BUNDLE_PARENT_BASENAME}" != "agentloop-r15-bundle.2xROcy" ||
        "${R23_R15_STATE_ROOT}" != "/private/tmp/agentloop-r15-state.Zq6Jvm" ||
        "${R23_R15_BUNDLE_PARENT}" != "/private/tmp/agentloop-r15-bundle.2xROcy" ]]; then
    r23_pre_begin_fail 70 "R15 tombstone frozen basename or path identity drifted"
  fi
  if [[ "${R23_R15_STATE_ROOT}" != "/private/tmp/${R23_R15_STATE_ROOT_BASENAME}" ||
        "${R23_R15_BUNDLE_PARENT}" != "/private/tmp/${R23_R15_BUNDLE_PARENT_BASENAME}" ]]; then
    r23_pre_begin_fail 70 "R15 tombstone path reconstruction failed"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r23_pre_begin_fail 70 "R15 tombstone parent is missing, non-directory, or symlink: /private/tmp"
  fi
  if r23_r15_tombstone_probe_output="$(
    trap - ERR
    /usr/bin/find /private/tmp \
      -mindepth 1 -maxdepth 1 \
      \( \
        -name "${R23_R15_STATE_ROOT_BASENAME}" -o \
        -name "${R23_R15_BUNDLE_PARENT_BASENAME}" \
      \) \
      -print -quit 2>&1
  )"; then
    r23_r15_tombstone_probe_rc=0
  else
    r23_r15_tombstone_probe_rc="$?"
  fi
  if [[ "${r23_r15_tombstone_probe_rc}" -ne 0 ]]; then
    r23_pre_begin_fail 70 "R15 tombstone absence parent enumeration was indeterminate with rc=${r23_r15_tombstone_probe_rc}"
  fi
  if [[ -n "${r23_r15_tombstone_probe_output}" ]]; then
    r23_pre_begin_fail 70 "R15 tombstoned volatile root reappeared: ${r23_r15_tombstone_probe_output}"
  fi
  if [[ -e "${R23_R15_STATE_ROOT}" || -L "${R23_R15_STATE_ROOT}" ]]; then
    r23_pre_begin_fail 70 "R15 tombstoned state root reappeared after parent enumeration: ${R23_R15_STATE_ROOT}"
  fi
  if [[ -e "${R23_R15_BUNDLE_PARENT}" || -L "${R23_R15_BUNDLE_PARENT}" ]]; then
    r23_pre_begin_fail 70 "R15 tombstoned bundle parent reappeared after parent enumeration: ${R23_R15_BUNDLE_PARENT}"
  fi
}

r23_require_no_unconsumed_fresh_roots() {
  local r23_verification_mode="$1"
  local -a r23_root_pipeline_status
  case "${r23_verification_mode}" in
    pre_begin|post_activation)
      ;;
    *)
      r23_attestation_fail 64 "invalid historical fresh-root verification mode: ${r23_verification_mode}"
      ;;
  esac
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r23_attestation_fail 70 "historical fresh-root parent is missing, non-directory, or symlink"
  fi
  if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      set -f
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      mode="$1"
      actual_path=""
      read_rc=1
      partial_final_record=0
      matched_root_count=0
      while :; do
        actual_path=""
        if IFS= read -r -d "" actual_path; then
          case "${actual_path}" in
            /private/tmp/agentloop-r16-state.*|/private/tmp/agentloop-r16-bundle.*|\
            /private/tmp/agentloop-r17-state.*|/private/tmp/agentloop-r17-bundle.*|\
            /private/tmp/agentloop-r18-state.*|/private/tmp/agentloop-r18-bundle.*|\
            /private/tmp/agentloop-r21-state.*|/private/tmp/agentloop-r21-bundle.*|\
            /private/tmp/agentloop-r22-state.*|/private/tmp/agentloop-r22-bundle.*)
              matched_root_count=$(( matched_root_count + 1 ))
              ;;
            /private/tmp/agentloop-r23-state.*|/private/tmp/agentloop-r23-bundle.*)
              if [[ "${mode}" == "pre_begin" ]]; then
                matched_root_count=$(( matched_root_count + 1 ))
              fi
              ;;
          esac
        else
          read_rc="$?"
          if [[ -n "${actual_path}" ]]; then
            partial_final_record=1
          fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 ||
            "${partial_final_record}" -ne 0 ||
            "${matched_root_count}" -ne 0 ]]; then
        exit 1
      fi
    ' -- "${r23_verification_mode}"; then
    r23_root_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r23_root_pipeline_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r23_root_pipeline_status[@]}" -ne 2 ||
        "${r23_root_pipeline_status[0]}" -ne 0 ||
        "${r23_root_pipeline_status[1]}" -ne 0 ]]; then
    r23_attestation_fail 70 \
      "historical fresh-root full-parent verification failed in ${r23_verification_mode} with find_rc=${r23_root_pipeline_status[0]:-MISSING} validator_rc=${r23_root_pipeline_status[1]:-MISSING}"
  fi
}

r23_exclusive_create_empty() {
  local r23_path="$1"
  ( set -C; : > "${r23_path}" )
}

r23_require_fresh_root() {
  local r23_path="$1"
  local r23_label="$2"
  local r23_probe_rc
  local r23_realpath
  local r23_realpath_rc
  if [[ ! -d "${r23_path}" || -L "${r23_path}" ]]; then
    r23_active_fail 72 "${r23_label}_invalid_type"
  fi
  if r23_realpath="$(
    trap - ERR
    /bin/realpath "${r23_path}" 2>&1
  )"; then
    r23_realpath_rc=0
  else
    r23_realpath_rc="$?"
  fi
  if [[ "${r23_realpath_rc}" -ne 0 ]]; then
    r23_active_fail 72 "${r23_label}_realpath_probe_failed"
  fi
  if [[ "${r23_realpath}" != "${r23_path}" ]]; then
    r23_active_fail 72 "${r23_label}_realpath_mismatch"
  fi
  if r23_probe_empty_directory "${r23_path}"; then
    return 0
  else
    r23_probe_rc="$?"
  fi
  if [[ "${r23_probe_rc}" -eq 1 ]]; then
    r23_active_fail 72 "${r23_label}_not_empty"
  fi
  r23_active_fail 72 "${r23_label}_emptiness_probe_indeterminate"
}

r23_emit_r19_artifact_manifest() {
  /usr/bin/printf '%s  %s\n' \
    "501957999e7a8103e553cb580d9b70f0825ee79a5c9a89e4b47e13c5db350f45" "${R23_R19_TARGETED_LOG}" \
    "8ef56ce31c3e01c551e4ef65c98ce43e3631ad7554b56640e943cdb0ce5d5c15" "${R23_R19_VERIFY_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R23_TASK_DIRECTORY}/r19-build.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R23_TASK_DIRECTORY}/r19-migration-matrix.log" \
    "cddaffeaf553ff72b8f40ea1748baad649d98f747ff2210722f8fd1c388aceec" "${R23_R19_REPORT}" \
    "a5e1b1b8edda476204f4b0fbcc01f90e3e6bced1dee07daf4d58b9f4e143ca30" "${R23_R19_BOUNDARY_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R23_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R23_TASK_DIRECTORY}/evidence/r19-source-gates.log" \
    "43e9d2eb00c0a63d5071b0c17f2cdc4c5809530788e893b4ffb0381e60e1aff8" "${R23_R19_HASH_LOG}" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R23_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log" \
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" "${R23_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
}

r23_require_r19_tombstones_absent() {
  local -a r23_r19_tombstone_status
  if [[ "${R23_R19_STATE_ROOT}" != "/private/tmp/${R23_R19_STATE_ROOT_BASENAME}" ||
        "${R23_R19_BUNDLE_PARENT}" != "/private/tmp/${R23_R19_BUNDLE_PARENT_BASENAME}" ||
        "${R23_R19_STATE_ROOT_BASENAME}" == "${R23_R19_BUNDLE_PARENT_BASENAME}" ]]; then
    r23_attestation_fail 70 "R19 tombstone frozen identities drifted"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r23_attestation_fail 70 "R19 tombstone parent is missing, non-directory, or symlink"
  fi
  if [[ -e "${R23_R19_STATE_ROOT}" || -L "${R23_R19_STATE_ROOT}" ||
        -e "${R23_R19_BUNDLE_PARENT}" || -L "${R23_R19_BUNDLE_PARENT}" ]]; then
    r23_attestation_fail 70 "R19 absorbing tombstone reappeared before parent enumeration"
  fi
  if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      set -f
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then
        exit 2
      fi
      expected_state="$1"
      expected_bundle="$2"
      actual_path=""
      read_rc=1
      partial_final_record=0
      seen_state=0
      seen_bundle=0
      alternate_root=0
      while :; do
        actual_path=""
        if IFS= read -r -d "" actual_path; then
          case "${actual_path}" in
            "${expected_state}")
              seen_state=$(( seen_state + 1 ))
              ;;
            "${expected_bundle}")
              seen_bundle=$(( seen_bundle + 1 ))
              ;;
            /private/tmp/agentloop-r19-state.*|/private/tmp/agentloop-r19-bundle.*)
              alternate_root=$(( alternate_root + 1 ))
              ;;
          esac
        else
          read_rc="$?"
          if [[ -n "${actual_path}" ]]; then
            partial_final_record=1
          fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 ||
            "${partial_final_record}" -ne 0 ||
            "${seen_state}" -ne 0 ||
            "${seen_bundle}" -ne 0 ||
            "${alternate_root}" -ne 0 ]]; then
        exit 1
      fi
    ' -- "${R23_R19_STATE_ROOT}" "${R23_R19_BUNDLE_PARENT}"; then
    r23_r19_tombstone_status=( "${PIPESTATUS[@]}" )
  else
    r23_r19_tombstone_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r23_r19_tombstone_status[@]}" -ne 2 ||
        "${r23_r19_tombstone_status[0]}" -ne 0 ||
        "${r23_r19_tombstone_status[1]}" -ne 0 ]]; then
    r23_attestation_fail 70 \
      "R19 tombstone full-parent verification failed with find_rc=${r23_r19_tombstone_status[0]:-MISSING} validator_rc=${r23_r19_tombstone_status[1]:-MISSING}"
  fi
  if [[ -e "${R23_R19_STATE_ROOT}" || -L "${R23_R19_STATE_ROOT}" ||
        -e "${R23_R19_BUNDLE_PARENT}" || -L "${R23_R19_BUNDLE_PARENT}" ]]; then
    r23_attestation_fail 70 "R19 absorbing tombstone reappeared after parent enumeration"
  fi
}

r23_require_r19_containment() {
  local r23_verification_mode="$1"
  local -a r23_r19_artifact_status
  local -a r23_r19_artifacts=(
    "${R23_R19_TARGETED_LOG}"
    "${R23_R19_VERIFY_LOG}"
    "${R23_TASK_DIRECTORY}/r19-build.log"
    "${R23_TASK_DIRECTORY}/r19-migration-matrix.log"
    "${R23_R19_REPORT}"
    "${R23_R19_BOUNDARY_LOG}"
    "${R23_TASK_DIRECTORY}/evidence/r19-bundle-provenance.log"
    "${R23_TASK_DIRECTORY}/evidence/r19-source-gates.log"
    "${R23_R19_HASH_LOG}"
    "${R23_TASK_DIRECTORY}/evidence/r19-preview-bootstrap.log"
    "${R23_TASK_DIRECTORY}/evidence/r19-preview-cold-start.log"
  )
  local r23_r19_artifact
  local r23_r19_required_line

  case "${r23_verification_mode}" in
    pre_begin)
      if r23_authorization_is_consumed; then
        r23_attestation_fail 70 "pre_begin_r19_containment_after_authorization_consumption"
      fi
      ;;
    post_activation|post_activation_probe)
      if ! r23_authorization_is_consumed; then
        r23_pre_begin_fail 70 "post_activation_r19_containment_before_authorization_consumption"
      fi
      ;;
    *)
      r23_attestation_fail 64 "invalid R19 containment verification mode: ${r23_verification_mode}"
      ;;
  esac

  for r23_r19_artifact in "${r23_r19_artifacts[@]}"; do
    if [[ ! -f "${r23_r19_artifact}" || -L "${r23_r19_artifact}" ]]; then
      r23_attestation_fail 70 "R19 artifact is missing, non-regular, or a symlink"
    fi
  done

  if r23_emit_r19_artifact_manifest |
    /usr/bin/shasum -a 256 --strict -c - >/dev/null; then
    r23_r19_artifact_status=( "${PIPESTATUS[@]}" )
  else
    r23_r19_artifact_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r23_r19_artifact_status[@]}" -ne 2 ||
        "${r23_r19_artifact_status[0]}" -ne 0 ||
        "${r23_r19_artifact_status[1]}" -ne 0 ]]; then
    r23_attestation_fail 70 "R19 immutable artifact verification failed"
  fi

  r23_require_r19_tombstones_absent

  if [[ -e "${R23_R19_PLANNED_APP}" || -L "${R23_R19_PLANNED_APP}" ]]; then
    r23_attestation_fail 70 "R19 planned App reappeared under an absorbing tombstone"
  fi
  if [[ -e "${R23_R19_SCREENSHOT}" || -L "${R23_R19_SCREENSHOT}" ]]; then
    r23_attestation_fail 70 "R19 screenshot must remain absent"
  fi

  for r23_r19_required_line in \
    "boundary=R19_CLEAN_REVERIFICATION" \
    "invocation_id=${R23_R19_INVOCATION_ID}" \
    "authorization_consumed=true" \
    "status=REJECTED_CONTAMINATED" \
    "phase=full_tests" \
    "reason=swift_run_full_failed" \
    "state_root=${R23_R19_STATE_ROOT}" \
    "bundle_parent=${R23_R19_BUNDLE_PARENT}" \
    "containment_state_root_empty=true" \
    "containment_bundle_parent_empty=true" \
    "containment_app_absent=true" \
    "verdict_remains=REJECTED_CONTAMINATED" \
    "retry_same_boundary=false"; do
    if ! /usr/bin/grep -Fx -- "${r23_r19_required_line}" "${R23_R19_BOUNDARY_LOG}" >/dev/null 2>&1; then
      r23_attestation_fail 70 "R19 immutable boundary fact is missing"
    fi
  done

  if [[ "${r23_verification_mode}" == "post_activation" ]]; then
    /usr/bin/printf '%s\n' \
      "section=r19_containment" \
      "phase=post_activation" \
      "r19_invocation_id=${R23_R19_INVOCATION_ID}" \
      "r19_verdict=REJECTED_CONTAMINATED" \
      "r19_artifact_count=11" \
      "r19_artifacts_immutable=true" \
      "r19_roots_historical_state=CANONICAL_EMPTY" \
      "r19_roots_current_state=ABSENT_TOMBSTONE" \
      "r19_root_glob_exact_count=0" \
      "r19_state_root=${R23_R19_STATE_ROOT}" \
      "r19_bundle_parent=${R23_R19_BUNDLE_PARENT}" \
      "r19_disappearance_cause=UNKNOWN" \
      "r19_tombstone_transition=CANONICAL_EMPTY_TO_ABSENT" \
      "r19_tombstone_absorbing=true" \
      "r19_tombstone_parent_transport=find_print0_bash_read_d_nul_v1" \
      "r19_planned_app_absent=true" \
      "r19_screenshot_absent=true" \
      "r19_retry_same_boundary=false" >> "${R23_HASH_LOG}"
  fi
}

r23_require_valid_erosion_mask() {
  local r23_mask="$1"
  local r23_label="$2"
  if [[ "${#r23_mask}" -ne 38 ]]; then
    r23_attestation_fail 70 "${r23_label} must contain exactly 38 bits"
  fi
  case "${r23_mask}" in
    *[!01]*)
      r23_attestation_fail 70 "${r23_label} contains a non-binary byte"
      ;;
  esac
}

r23_require_mask_monotonic() {
  local r23_prior_mask="$1"
  local r23_next_mask="$2"
  local r23_label="$3"
  local r23_index=0
  local r23_prior_bit
  local r23_next_bit
  r23_require_valid_erosion_mask "${r23_prior_mask}" "${r23_label}_prior"
  r23_require_valid_erosion_mask "${r23_next_mask}" "${r23_label}_next"
  while [[ "${r23_index}" -lt 38 ]]; do
    r23_prior_bit="${r23_prior_mask:${r23_index}:1}"
    r23_next_bit="${r23_next_mask:${r23_index}:1}"
    if [[ "${r23_prior_bit}" == "0" && "${r23_next_bit}" == "1" ]]; then
      r23_attestation_fail 70 "R20 erosion snapshot attempted 0-to-1 at fixed bit ${r23_index} during ${r23_label}"
    fi
    r23_index=$(( r23_index + 1 ))
  done
}

r23_validate_r20_top_level() {
  local r23_bundle_before=0
  local r23_bundle_after=0
  local r23_bundle_realpath
  local r23_bundle_realpath_rc
  local -a r23_top_status
  if [[ "${R23_R20_STATE_ROOT}" != "/private/tmp/${R23_R20_STATE_ROOT_BASENAME}" ||
        "${R23_R20_BUNDLE_PARENT}" != "/private/tmp/${R23_R20_BUNDLE_PARENT_BASENAME}" ||
        "${R23_R20_STATE_ROOT_BASENAME}" == "${R23_R20_BUNDLE_PARENT_BASENAME}" ]]; then
    r23_attestation_fail 70 "R20 erosion root identities drifted"
  fi
  if [[ ! -d /private/tmp || -L /private/tmp ]]; then
    r23_attestation_fail 70 "R20 erosion parent is missing, non-directory, or symlink"
  fi
  if [[ -e "${R23_R20_STATE_ROOT}" || -L "${R23_R20_STATE_ROOT}" ]]; then
    r23_attestation_fail 70 "R20 state-root absorbing tombstone reappeared before enumeration"
  fi
  if [[ -e "${R23_R20_BUNDLE_PARENT}" || -L "${R23_R20_BUNDLE_PARENT}" ]]; then
    r23_bundle_before=1
  fi
  if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      set -f
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then exit 2; fi
      expected_state="$1"
      expected_bundle="$2"
      expected_bundle_presence="$3"
      path=""
      read_rc=1
      partial=0
      seen_state=0
      seen_bundle=0
      alternate=0
      while :; do
        path=""
        if IFS= read -r -d "" path; then
          case "${path}" in
            "${expected_state}") seen_state=$(( seen_state + 1 )) ;;
            "${expected_bundle}") seen_bundle=$(( seen_bundle + 1 )) ;;
            /private/tmp/agentloop-r20-state.*|/private/tmp/agentloop-r20-bundle.*)
              alternate=$(( alternate + 1 ))
              ;;
          esac
        else
          read_rc="$?"
          if [[ -n "${path}" ]]; then partial=1; fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 || "${partial}" -ne 0 ||
            "${seen_state}" -ne 0 || "${alternate}" -ne 0 ||
            "${seen_bundle}" -ne "${expected_bundle_presence}" ]]; then
        exit 1
      fi
    ' -- "${R23_R20_STATE_ROOT}" "${R23_R20_BUNDLE_PARENT}" "${r23_bundle_before}"; then
    r23_top_status=( "${PIPESTATUS[@]}" )
  else
    r23_top_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r23_top_status[@]}" -ne 2 ||
        "${r23_top_status[0]}" -ne 0 || "${r23_top_status[1]}" -ne 0 ]]; then
    r23_attestation_fail 70 "R20 top-level erosion universe failed find=${r23_top_status[0]:-MISSING} validator=${r23_top_status[1]:-MISSING}"
  fi
  if [[ -e "${R23_R20_STATE_ROOT}" || -L "${R23_R20_STATE_ROOT}" ]]; then
    r23_attestation_fail 70 "R20 state-root absorbing tombstone reappeared after enumeration"
  fi
  if [[ -e "${R23_R20_BUNDLE_PARENT}" || -L "${R23_R20_BUNDLE_PARENT}" ]]; then
    r23_bundle_after=1
  fi
  if [[ "${r23_bundle_before}" -ne "${r23_bundle_after}" ]]; then
    r23_attestation_fail 70 "R20 bundle parent changed presence inside one complete capture"
  fi
  if [[ "${r23_bundle_after}" -eq 1 ]]; then
    if r23_bundle_realpath="$(
      trap - ERR
      /bin/realpath "${R23_R20_BUNDLE_PARENT}" 2>&1
    )"; then
      r23_bundle_realpath_rc=0
    else
      r23_bundle_realpath_rc="$?"
    fi
    if [[ ! -d "${R23_R20_BUNDLE_PARENT}" || -L "${R23_R20_BUNDLE_PARENT}" ||
          "${r23_bundle_realpath_rc}" -ne 0 ||
          "${r23_bundle_realpath}" != "${R23_R20_BUNDLE_PARENT}" ]]; then
      r23_attestation_fail 70 "R20 bundle parent present with wrong type or realpath"
    fi
  fi
  R23_R20_CAPTURE_PARENT_PRESENT="${r23_bundle_after}"
}

r23_validate_r20_parent_children() {
  local r23_app_before=0
  local r23_app_after=0
  local r23_app_realpath
  local r23_app_realpath_rc
  local -a r23_child_status
  if [[ -e "${R23_R20_APP}" || -L "${R23_R20_APP}" ]]; then
    r23_app_before=1
  fi
  if /usr/bin/find -P "${R23_R20_BUNDLE_PARENT}" -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash --noprofile --norc -c '
      set -uo pipefail
      set -f
      IFS=$'"'"' \t\n'"'"'
      set +H
      if ! shopt -u nocasematch; then exit 2; fi
      expected_app="$1"
      expected_presence="$2"
      path=""
      read_rc=1
      partial=0
      seen=0
      extra=0
      while :; do
        path=""
        if IFS= read -r -d "" path; then
          if [[ "${path}" == "${expected_app}" ]]; then
            seen=$(( seen + 1 ))
          else
            extra=$(( extra + 1 ))
          fi
        else
          read_rc="$?"
          if [[ -n "${path}" ]]; then partial=1; fi
          break
        fi
      done
      if [[ "${read_rc}" -ne 1 || "${partial}" -ne 0 ||
            "${extra}" -ne 0 || "${seen}" -ne "${expected_presence}" ]]; then
        exit 1
      fi
    ' -- "${R23_R20_APP}" "${r23_app_before}"; then
    r23_child_status=( "${PIPESTATUS[@]}" )
  else
    r23_child_status=( "${PIPESTATUS[@]}" )
  fi
  if [[ "${#r23_child_status[@]}" -ne 2 ||
        "${r23_child_status[0]}" -ne 0 || "${r23_child_status[1]}" -ne 0 ]]; then
    r23_attestation_fail 70 "R20 parent-child universe failed find=${r23_child_status[0]:-MISSING} validator=${r23_child_status[1]:-MISSING}"
  fi
  if [[ -e "${R23_R20_APP}" || -L "${R23_R20_APP}" ]]; then
    r23_app_after=1
  fi
  if [[ "${r23_app_before}" -ne "${r23_app_after}" ]]; then
    r23_attestation_fail 70 "R20 App changed presence inside one complete capture"
  fi
  if [[ "${r23_app_after}" -eq 1 ]]; then
    if r23_app_realpath="$(
      trap - ERR
      /bin/realpath "${R23_R20_APP}" 2>&1
    )"; then
      r23_app_realpath_rc=0
    else
      r23_app_realpath_rc="$?"
    fi
    if [[ ! -d "${R23_R20_APP}" || -L "${R23_R20_APP}" ||
          "${r23_app_realpath_rc}" -ne 0 ||
          "${r23_app_realpath}" != "${R23_R20_APP}" ]]; then
      r23_attestation_fail 70 "R20 App present with wrong type or realpath"
    fi
  fi
  R23_R20_CAPTURE_APP_PRESENT="${r23_app_after}"
}

r23_validate_r20_app_subset() {
  local r23_capture_line
  local r23_capture_rc
  local r23_node_mask
  local r23_node_count
  local r23_directory_count
  local r23_file_count
  local r23_extra
  local r23_app_realpath
  local r23_app_realpath_rc

  if [[ "${#R23_R20_EXPECTED_NODE_TRIPLES[@]}" -ne 108 ]]; then
    r23_attestation_fail 70 "R20 historical node universe no longer contains exactly 36 triples"
  fi
  if r23_capture_line="$(
    trap - ERR
    set +e
    /usr/bin/find -P "${R23_R20_APP}" -mindepth 1 -print0 2>/dev/null |
      /bin/bash --noprofile --norc -c '
        set -uo pipefail
        set -f
        IFS=$'"'"' \t\n'"'"'
        set +H
        if ! shopt -u nocasematch; then exit 2; fi
        app="$1"
        shift
        definitions_valid=true
        if [[ "$#" -ne 108 ]]; then definitions_valid=false; fi
        expected_count=0
        expected_file_count=0
        expected_type=()
        expected_path=()
        expected_hash=()
        seen=()
        while [[ "$#" -ge 3 ]]; do
          type="$1"
          relative_path="$2"
          file_hash="$3"
          shift 3
          if [[ -z "${relative_path}" || "${relative_path}" == /* ]]; then
            definitions_valid=false
          fi
          case "${relative_path}" in
            *[!A-Za-z0-9._/-]*|*"//"*|../*|*"/../"*|*"/.."|./*|*"/./"*|*"/.")
              definitions_valid=false
              ;;
          esac
          case "${type}" in
            D)
              if [[ "${file_hash}" != "-" ]]; then definitions_valid=false; fi
              ;;
            F)
              if [[ "${#file_hash}" -ne 64 ]]; then definitions_valid=false; fi
              case "${file_hash}" in
                *[!0-9a-f]*) definitions_valid=false ;;
              esac
              expected_file_count=$(( expected_file_count + 1 ))
              ;;
            *)
              definitions_valid=false
              ;;
          esac
          other_index=0
          while [[ "${other_index}" -lt "${expected_count}" ]]; do
            if [[ "${expected_path[other_index]}" == "${relative_path}" ]]; then
              definitions_valid=false
            fi
            other_index=$(( other_index + 1 ))
          done
          expected_type[expected_count]="${type}"
          expected_path[expected_count]="${relative_path}"
          expected_hash[expected_count]="${file_hash}"
          seen[expected_count]=0
          expected_count=$(( expected_count + 1 ))
        done
        if [[ "$#" -ne 0 || "${expected_count}" -ne 36 ||
              "${expected_file_count}" -ne 30 ]]; then
          definitions_valid=false
        fi

        path=""
        read_rc=1
        partial_final_record=0
        actual_count=0
        valid="${definitions_valid}"
        while :; do
          path=""
          if IFS= read -r -d "" path; then
            actual_count=$(( actual_count + 1 ))
            if [[ "${actual_count}" -gt 36 ]]; then valid=false; fi
            case "${path}" in
              "${app}"/*)
                relative_path="${path#"${app}"/}"
                ;;
              *)
                relative_path=""
                valid=false
                ;;
            esac
            matched_index=-1
            index=0
            while [[ "${index}" -lt "${expected_count}" ]]; do
              if [[ "${relative_path}" == "${expected_path[index]}" ]]; then
                matched_index="${index}"
                break
              fi
              index=$(( index + 1 ))
            done
            if [[ "${matched_index}" -lt 0 ]]; then
              valid=false
              continue
            fi
            if [[ "${seen[matched_index]}" -ne 0 ]]; then
              valid=false
              continue
            fi
            seen[matched_index]=1
            if [[ -L "${path}" ]]; then
              valid=false
              continue
            fi
            case "${expected_type[matched_index]}" in
              D)
                if [[ ! -d "${path}" ]]; then valid=false; fi
                ;;
              F)
                if [[ ! -f "${path}" ]]; then
                  valid=false
                  continue
                fi
                if file_sha="$(/usr/bin/shasum -a 256 "${path}" 2>/dev/null)"; then
                  file_sha="${file_sha%% *}"
                  if [[ "${file_sha}" != "${expected_hash[matched_index]}" ]]; then
                    valid=false
                  fi
                else
                  valid=false
                fi
                ;;
              *)
                valid=false
                ;;
            esac
          else
            read_rc="$?"
            if [[ -n "${path}" ]]; then partial_final_record=1; fi
            break
          fi
        done
        if [[ "${read_rc}" -ne 1 || "${partial_final_record}" -ne 0 ||
              "${valid}" != "true" ]]; then
          exit 1
        fi
        node_mask=""
        node_count=0
        directory_count=0
        file_count=0
        index=0
        while [[ "${index}" -lt "${expected_count}" ]]; do
          if [[ "${seen[index]}" -eq 1 ]]; then
            node_mask="${node_mask}1"
            node_count=$(( node_count + 1 ))
            if [[ "${expected_type[index]}" == "D" ]]; then
              directory_count=$(( directory_count + 1 ))
            else
              file_count=$(( file_count + 1 ))
            fi
          else
            node_mask="${node_mask}0"
          fi
          index=$(( index + 1 ))
        done
        /usr/bin/printf "%s %s %s %s\n" \
          "${node_mask}" "${node_count}" "${directory_count}" "${file_count}"
      ' -- "${R23_R20_APP}" "${R23_R20_EXPECTED_NODE_TRIPLES[@]}"
    r23_subset_status=( "${PIPESTATUS[@]}" )
    if [[ "${#r23_subset_status[@]}" -ne 2 ||
          "${r23_subset_status[0]}" -ne 0 ||
          "${r23_subset_status[1]}" -ne 0 ]]; then
      exit 1
    fi
  )"; then
    r23_capture_rc=0
  else
    r23_capture_rc="$?"
  fi
  if [[ "${r23_capture_rc}" -ne 0 ]]; then
    r23_attestation_fail 70 "R20 App subset full-drain capture failed with rc=${r23_capture_rc}"
  fi
  case "${r23_capture_line}" in
    *$'\n'*)
      r23_attestation_fail 70 "R20 App subset capture emitted multiple records"
      ;;
  esac
  r23_extra=""
  IFS=' ' read -r \
    r23_node_mask r23_node_count r23_directory_count r23_file_count r23_extra \
    <<< "${r23_capture_line}"
  if [[ -n "${r23_extra}" ||
        ! "${r23_node_mask}" =~ ^[01]{36}$ ||
        ! "${r23_node_count}" =~ ^[0-9]+$ ||
        ! "${r23_directory_count}" =~ ^[0-9]+$ ||
        ! "${r23_file_count}" =~ ^[0-9]+$ ||
        "${r23_node_count}" -gt 36 ||
        "${r23_directory_count}" -gt 6 ||
        "${r23_file_count}" -gt 30 ||
        $(( r23_directory_count + r23_file_count )) -ne "${r23_node_count}" ]]; then
    r23_attestation_fail 70 "R20 App subset capture record is invalid"
  fi

  if r23_app_realpath="$(
    trap - ERR
    /bin/realpath "${R23_R20_APP}" 2>&1
  )"; then
    r23_app_realpath_rc=0
  else
    r23_app_realpath_rc="$?"
  fi
  if [[ ! -d "${R23_R20_APP}" || -L "${R23_R20_APP}" ||
        "${r23_app_realpath_rc}" -ne 0 ||
        "${r23_app_realpath}" != "${R23_R20_APP}" ]]; then
    r23_attestation_fail 70 "R20 App changed type or identity after subset full drain"
  fi

  R23_R20_CAPTURED_MASK="11${r23_node_mask}"
  if [[ "${r23_node_mask}" == "${R23_ONE_36}" ]]; then
    if [[ "${r23_node_count}" -ne 36 ||
          "${r23_directory_count}" -ne 6 ||
          "${r23_file_count}" -ne 30 ]]; then
      r23_attestation_fail 70 "R20 complete historical node mask has inconsistent counts"
    fi
    R23_R20_CAPTURED_STATE="COMPLETE_HISTORICAL_SET"
  else
    R23_R20_CAPTURED_STATE="APP_SUBSET"
  fi
  R23_R20_CAPTURED_NODE_COUNT="${r23_node_count}"
  R23_R20_CAPTURED_DIRECTORY_COUNT="${r23_directory_count}"
  R23_R20_CAPTURED_FILE_COUNT="${r23_file_count}"
}

r23_bookend_r20_capture() {
  local r23_expected_parent_bit="${R23_R20_CAPTURED_MASK:0:1}"
  local r23_expected_app_bit="${R23_R20_CAPTURED_MASK:1:1}"
  r23_validate_r20_top_level
  if [[ "${R23_R20_CAPTURE_PARENT_PRESENT}" != "${r23_expected_parent_bit}" ]]; then
    r23_attestation_fail 70 "R20 bundle-parent presence changed before the capture bookend"
  fi
  if [[ "${r23_expected_parent_bit}" == "1" ]]; then
    r23_validate_r20_parent_children
    if [[ "${R23_R20_CAPTURE_APP_PRESENT}" != "${r23_expected_app_bit}" ]]; then
      r23_attestation_fail 70 "R20 App presence changed before the capture bookend"
    fi
  else
    if [[ "${r23_expected_app_bit}" != "0" ||
          -e "${R23_R20_APP}" || -L "${R23_R20_APP}" ]]; then
      r23_attestation_fail 70 "R20 absent-parent capture has a non-absent App at its bookend"
    fi
  fi
}

r23_capture_r20_erosion_once() {
  local r23_topology
  local r23_descendant_mask
  R23_R20_CAPTURED_MASK=""
  R23_R20_CAPTURED_STATE=""
  R23_R20_CAPTURED_NODE_COUNT="0"
  R23_R20_CAPTURED_DIRECTORY_COUNT="0"
  R23_R20_CAPTURED_FILE_COUNT="0"
  R23_R20_CAPTURE_PARENT_PRESENT="0"
  R23_R20_CAPTURE_APP_PRESENT="0"

  r23_validate_r20_top_level
  if [[ "${R23_R20_CAPTURE_PARENT_PRESENT}" -eq 0 ]]; then
    if [[ -e "${R23_R20_APP}" || -L "${R23_R20_APP}" ]]; then
      r23_attestation_fail 70 "R20 App exists while the exact bundle parent is absent"
    fi
    R23_R20_CAPTURED_MASK="${R23_ZERO_38}"
    R23_R20_CAPTURED_STATE="BUNDLE_ABSENT"
  else
    r23_validate_r20_parent_children
    if [[ "${R23_R20_CAPTURE_APP_PRESENT}" -eq 0 ]]; then
      R23_R20_CAPTURED_MASK="10${R23_ZERO_36}"
      R23_R20_CAPTURED_STATE="PARENT_ONLY"
    else
      r23_validate_r20_app_subset
    fi
  fi

  r23_require_valid_erosion_mask "${R23_R20_CAPTURED_MASK}" "r20_complete_capture"
  r23_topology="${R23_R20_CAPTURED_MASK:0:2}"
  r23_descendant_mask="${R23_R20_CAPTURED_MASK:2:36}"
  case "${r23_topology}" in
    00)
      if [[ "${R23_R20_CAPTURED_MASK}" != "${R23_ZERO_38}" ||
            "${R23_R20_CAPTURED_STATE}" != "BUNDLE_ABSENT" ]]; then
        r23_attestation_fail 70 "R20 absent topology is internally inconsistent"
      fi
      ;;
    10)
      if [[ "${r23_descendant_mask}" != "${R23_ZERO_36}" ||
            "${R23_R20_CAPTURED_STATE}" != "PARENT_ONLY" ]]; then
        r23_attestation_fail 70 "R20 parent-only topology is internally inconsistent"
      fi
      ;;
    11)
      case "${R23_R20_CAPTURED_STATE}" in
        APP_SUBSET|COMPLETE_HISTORICAL_SET)
          ;;
        *)
          r23_attestation_fail 70 "R20 App topology has an invalid state label"
          ;;
      esac
      ;;
    01)
      r23_attestation_fail 70 "R20 fixed mask encodes an App without its parent"
      ;;
    *)
      r23_attestation_fail 70 "R20 fixed mask has an invalid topology prefix"
      ;;
  esac
  r23_bookend_r20_capture
}

r23_observe_r20_erosion() {
  local r23_verification_mode="$1"
  local r23_a_mask
  local r23_a_state
  local r23_b_mask
  local r23_b_state
  local r23_b_node_count
  local r23_b_directory_count
  local r23_b_file_count
  local r23_commit_deferred_signal=""

  case "${r23_verification_mode}" in
    pre_begin)
      if r23_authorization_is_consumed; then
        r23_attestation_fail 70 "pre_begin_r20_erosion_after_authorization_consumption"
      fi
      ;;
    post_activation|post_activation_probe)
      if ! r23_authorization_is_consumed; then
        r23_pre_begin_fail 70 "post_activation_r20_erosion_before_authorization_consumption"
      fi
      ;;
    *)
      r23_attestation_fail 64 "invalid R20 erosion observation mode: ${r23_verification_mode}"
      ;;
  esac

  r23_capture_r20_erosion_once
  r23_a_mask="${R23_R20_CAPTURED_MASK}"
  r23_a_state="${R23_R20_CAPTURED_STATE}"

  r23_capture_r20_erosion_once
  r23_b_mask="${R23_R20_CAPTURED_MASK}"
  r23_b_state="${R23_R20_CAPTURED_STATE}"
  r23_b_node_count="${R23_R20_CAPTURED_NODE_COUNT}"
  r23_b_directory_count="${R23_R20_CAPTURED_DIRECTORY_COUNT}"
  r23_b_file_count="${R23_R20_CAPTURED_FILE_COUNT}"

  if [[ -n "${R23_R20_EROSION_LATEST_MASK}" ]]; then
    r23_require_mask_monotonic \
      "${R23_R20_EROSION_LATEST_MASK}" "${r23_a_mask}" "latest_to_capture_a"
  else
    r23_require_valid_erosion_mask \
      "${R23_R20_REVIEW22_BASELINE_MASK}" "review22_frozen_planning_baseline"
    r23_require_mask_monotonic \
      "${R23_R20_REVIEW22_BASELINE_MASK}" "${r23_a_mask}" \
      "review22_baseline_to_first_capture_a"
  fi
  r23_require_mask_monotonic "${r23_a_mask}" "${r23_b_mask}" "capture_a_to_capture_b"

  # This is only an in-process state-commit critical section, not a filesystem
  # transaction or atomic snapshot. Signals are deferred, never discarded.
  trap 'r23_commit_deferred_signal=HUP' HUP
  trap 'r23_commit_deferred_signal=INT' INT
  trap 'r23_commit_deferred_signal=TERM' TERM
  if [[ -z "${R23_R20_EROSION_FIRST_MASK}" ]]; then
    R23_R20_EROSION_FIRST_MASK="${r23_a_mask}"
    R23_R20_EROSION_FIRST_STATE="${r23_a_state}"
  fi
  R23_R20_EROSION_LATEST_MASK="${r23_b_mask}"
  R23_R20_EROSION_LATEST_STATE="${r23_b_state}"
  R23_R20_CAPTURED_MASK="${r23_b_mask}"
  R23_R20_CAPTURED_STATE="${r23_b_state}"
  R23_R20_CAPTURED_NODE_COUNT="${r23_b_node_count}"
  R23_R20_CAPTURED_DIRECTORY_COUNT="${r23_b_directory_count}"
  R23_R20_CAPTURED_FILE_COUNT="${r23_b_file_count}"

  case "${r23_verification_mode}" in
    pre_begin)
      R23_R20_EROSION_PRE_BEGIN_MASK="${r23_b_mask}"
      R23_R20_EROSION_PRE_BEGIN_STATE="${r23_b_state}"
      ;;
    post_activation|post_activation_probe)
      R23_R20_EROSION_POST_ACTIVATION_MASK="${r23_b_mask}"
      R23_R20_EROSION_POST_ACTIVATION_STATE="${r23_b_state}"
      ;;
  esac
  trap 'r23_signal_error HUP' HUP
  trap 'r23_signal_error INT' INT
  trap 'r23_signal_error TERM' TERM
  if [[ -n "${r23_commit_deferred_signal}" ]]; then
    r23_signal_error "${r23_commit_deferred_signal}"
  fi
}

r23_verify_complete_r20_signed_app() {
  local r23_manifest_payload
  local r23_manifest_payload_rc
  local r23_manifest_sha
  local r23_manifest_sha_rc
  local r23_codesign_rc
  if [[ "${R23_R20_CAPTURED_MASK}" != "11${R23_ONE_36}" ||
        "${R23_R20_CAPTURED_STATE}" != "COMPLETE_HISTORICAL_SET" ||
        "${R23_R20_CAPTURED_NODE_COUNT}" -ne 36 ||
        "${R23_R20_CAPTURED_DIRECTORY_COUNT}" -ne 6 ||
        "${R23_R20_CAPTURED_FILE_COUNT}" -ne 30 ]]; then
    r23_attestation_fail 70 "R20 complete signed-App verification received a non-complete snapshot"
  fi
  if r23_manifest_payload="$(
    trap - ERR
    set -Eeuo pipefail
    r23_index=0
    while [[ "${r23_index}" -lt "${#R23_R20_EXPECTED_NODE_TRIPLES[@]}" ]]; do
      r23_type="${R23_R20_EXPECTED_NODE_TRIPLES[r23_index]}"
      r23_relative_path="${R23_R20_EXPECTED_NODE_TRIPLES[r23_index + 1]}"
      r23_expected_sha="${R23_R20_EXPECTED_NODE_TRIPLES[r23_index + 2]}"
      if [[ "${r23_type}" == "F" ]]; then
        r23_actual_sha="$(/usr/bin/shasum -a 256 "${R23_R20_APP}/${r23_relative_path}")"
        r23_actual_sha="${r23_actual_sha%% *}"
        if [[ "${r23_actual_sha}" != "${r23_expected_sha}" ]]; then
          exit 1
        fi
        /usr/bin/printf "%s  %s\n" "${r23_actual_sha}" "${r23_relative_path}"
      fi
      r23_index=$(( r23_index + 3 ))
    done
  )"; then
    r23_manifest_payload_rc=0
  else
    r23_manifest_payload_rc="$?"
  fi
  if [[ "${r23_manifest_payload_rc}" -ne 0 ]]; then
    r23_attestation_fail 70 "R20 complete signed-App manifest payload could not be recomputed"
  fi
  if r23_manifest_sha="$(
    trap - ERR
    /usr/bin/printf '%s\n' "${r23_manifest_payload}" |
      /usr/bin/shasum -a 256
  )"; then
    r23_manifest_sha_rc=0
  else
    r23_manifest_sha_rc="$?"
  fi
  r23_manifest_sha="${r23_manifest_sha%% *}"
  if [[ "${r23_manifest_sha_rc}" -ne 0 ||
        "${r23_manifest_sha}" != "${R23_R20_SIGNED_BUNDLE_MANIFEST_SHA}" ]]; then
    r23_attestation_fail 70 "R20 complete signed-App aggregate manifest drifted"
  fi
  if /usr/bin/codesign --verify --deep --strict "${R23_R20_APP}" >/dev/null 2>&1; then
    r23_codesign_rc=0
  else
    r23_codesign_rc="$?"
  fi
  if [[ "${r23_codesign_rc}" -ne 0 ]]; then
    r23_attestation_fail 70 "R20 complete signed-App verification failed with rc=${r23_codesign_rc}"
  fi
  r23_capture_r20_erosion_once
  if [[ "${R23_R20_CAPTURED_MASK}" != "11${R23_ONE_36}" ||
        "${R23_R20_CAPTURED_STATE}" != "COMPLETE_HISTORICAL_SET" ]]; then
    r23_attestation_fail 70 "R20 complete signed App eroded before its terminal verification bookend"
  fi
  R23_R20_CURRENT_SIGNED_APP_VERIFIED="true"
}

r23_require_r20_containment() {
  local r23_verification_mode="$1"
  local -a r23_r20_artifacts=(
    "${R23_R20_TARGETED_LOG}"
    "${R23_R20_VERIFY_LOG}"
    "${R23_R20_BUILD_LOG}"
    "${R23_TASK_DIRECTORY}/r20-migration-matrix.log"
    "${R23_R20_REPORT}"
    "${R23_R20_BOUNDARY_LOG}"
    "${R23_TASK_DIRECTORY}/evidence/r20-bundle-provenance.log"
    "${R23_TASK_DIRECTORY}/evidence/r20-source-gates.log"
    "${R23_R20_HASH_LOG}"
    "${R23_TASK_DIRECTORY}/evidence/r20-preview-bootstrap.log"
    "${R23_TASK_DIRECTORY}/evidence/r20-preview-cold-start.log"
  )
  local r23_r20_artifact
  local r23_r20_required_line
  local r23_r20_parent_count
  local r23_r20_app_present

  case "${r23_verification_mode}" in
    pre_begin)
      if r23_authorization_is_consumed; then
        r23_attestation_fail 70 "pre_begin_r20_containment_after_authorization_consumption"
      fi
      ;;
    post_activation|post_activation_probe)
      if ! r23_authorization_is_consumed; then
        r23_pre_begin_fail 70 "post_activation_r20_containment_before_authorization_consumption"
      fi
      ;;
    *)
      r23_attestation_fail 64 "invalid R20 containment verification mode: ${r23_verification_mode}"
      ;;
  esac

  for r23_r20_artifact in "${r23_r20_artifacts[@]}"; do
    if [[ ! -f "${r23_r20_artifact}" || -L "${r23_r20_artifact}" ]]; then
      r23_attestation_fail 70 "R20 artifact is missing, non-regular, or a symlink"
    fi
  done
  R23_R20_CURRENT_SIGNED_APP_VERIFIED="false"
  r23_observe_r20_erosion "${r23_verification_mode}"
  if [[ "${R23_R20_CAPTURED_MASK}" == "11${R23_ONE_36}" ]]; then
    r23_verify_complete_r20_signed_app
  fi

  if [[ -e "${R23_R20_SCREENSHOT}" || -L "${R23_R20_SCREENSHOT}" ]]; then
    r23_attestation_fail 70 "R20 screenshot must remain absent"
  fi
  for r23_r20_required_line in \
    "boundary=R20_DETERMINISTIC_CLOCK_REPAIR" \
    "invocation_id=${R23_R20_INVOCATION_ID}" \
    "authorization_consumed=true" \
    "authoritative_test_invocation_count=1" \
    "authoritative_test_filter=none" \
    "authoritative_swift_rc=0" \
    "authoritative_tee_rc=0" \
    "targeted_required_name_count=46" \
    "launch_ready=true" \
    "executable_sha=${R23_R20_EXECUTABLE_SHA}" \
    "signed_bundle_manifest_sha=${R23_R20_SIGNED_BUNDLE_MANIFEST_SHA}" \
    "status=REJECTED_CONTAMINATED" \
    "phase=release_core_build" \
    "reason=release_AgentLoopCore_build_failed_rc_1" \
    "exit_code=1" \
    "state_root=${R23_R20_STATE_ROOT}" \
    "bundle_parent=${R23_R20_BUNDLE_PARENT}" \
    "retry_same_boundary=false"; do
    if ! /usr/bin/grep -Fx -- "${r23_r20_required_line}" "${R23_R20_BOUNDARY_LOG}" >/dev/null 2>&1; then
      r23_attestation_fail 70 "R20 immutable boundary fact is missing"
    fi
  done

  if [[ "${R23_R20_CAPTURED_MASK:0:1}" == "1" ]]; then
    r23_r20_parent_count=1
  else
    r23_r20_parent_count=0
  fi
  if [[ "${R23_R20_CAPTURED_MASK:1:1}" == "1" ]]; then
    r23_r20_app_present=true
  else
    r23_r20_app_present=false
  fi

  if [[ "${r23_verification_mode}" == "post_activation" ]]; then
    /usr/bin/printf '%s\n' \
      "section=r20_erosion_containment" \
      "phase=post_activation" \
      "r20_invocation_id=${R23_R20_INVOCATION_ID}" \
      "r20_verdict=REJECTED_CONTAMINATED" \
      "r20_failure_phase=release_core_build" \
      "r20_historical_authoritative_full_tests=652_of_652_pass" \
      "r20_historical_targeted_audit=46_of_46_pass" \
      "r20_historical_launch_ready=true" \
      "r20_artifact_count=11" \
      "r20_artifacts_immutable_by_static_manifest=true" \
      "r20_state_root=${R23_R20_STATE_ROOT}" \
      "r20_state_root_historical_state=CANONICAL_EMPTY" \
      "r20_state_root_current_state=ABSENT_TOMBSTONE" \
      "r20_state_root_disappearance_cause=UNKNOWN" \
      "r20_bundle_parent=${R23_R20_BUNDLE_PARENT}" \
      "r20_erosion_mask_identity=r23_r20_fixed_38_bit_v1" \
      "r20_erosion_mask_order=parent_app_then_36_historical_nodes" \
      "r20_erosion_transition=one_to_zero_only" \
      "r20_erosion_pair_protocol=double_complete_capture_a_b" \
      "r20_erosion_first_mask=${R23_R20_EROSION_FIRST_MASK}" \
      "r20_erosion_first_state=${R23_R20_EROSION_FIRST_STATE}" \
      "r20_erosion_pre_begin_mask=${R23_R20_EROSION_PRE_BEGIN_MASK}" \
      "r20_erosion_pre_begin_state=${R23_R20_EROSION_PRE_BEGIN_STATE}" \
      "r20_erosion_post_activation_mask=${R23_R20_EROSION_POST_ACTIVATION_MASK}" \
      "r20_erosion_post_activation_state=${R23_R20_EROSION_POST_ACTIVATION_STATE}" \
      "r20_erosion_latest_mask=${R23_R20_EROSION_LATEST_MASK}" \
      "r20_erosion_latest_state=${R23_R20_EROSION_LATEST_STATE}" \
      "r20_root_glob_exact_count=${r23_r20_parent_count}" \
      "r20_app_present=${r23_r20_app_present}" \
      "r20_current_node_count=${R23_R20_CAPTURED_NODE_COUNT}" \
      "r20_current_directory_count=${R23_R20_CAPTURED_DIRECTORY_COUNT}" \
      "r20_current_regular_file_count=${R23_R20_CAPTURED_FILE_COUNT}" \
      "r20_current_signed_app_verified=${R23_R20_CURRENT_SIGNED_APP_VERIFIED}" \
      "r20_current_signed_app_claim_permitted=${R23_R20_CURRENT_SIGNED_APP_VERIFIED}" \
      "r20_volatile_root_parent_transport=find_print0_bash_read_d_nul_v1" \
      "r20_app_node_transport=find_print0_bash_read_d_nul_v1" \
      "r20_screenshot_absent=true" \
      "r20_retry_same_boundary=false" >> "${R23_HASH_LOG}"
    if [[ "${R23_R20_CURRENT_SIGNED_APP_VERIFIED}" == "true" ]]; then
      /usr/bin/printf '%s\n' \
        "r20_current_complete_historical_set=true" \
        "r20_current_signed_bundle_manifest_recomputed=true" \
        "r20_current_executable_sha=${R23_R20_EXECUTABLE_SHA}" \
        "r20_current_info_plist_sha=${R23_R20_INFO_PLIST_SHA}" \
        "r20_current_signed_bundle_manifest_sha=${R23_R20_SIGNED_BUNDLE_MANIFEST_SHA}" >> "${R23_HASH_LOG}"
    else
      /usr/bin/printf '%s\n' \
        "r20_current_complete_historical_set=false" \
        "r20_current_signed_bundle_manifest_recomputed=false" \
        "r20_historical_executable_sha=${R23_R20_EXECUTABLE_SHA}" \
        "r20_historical_info_plist_sha=${R23_R20_INFO_PLIST_SHA}" \
        "r20_historical_signed_bundle_manifest_sha=${R23_R20_SIGNED_BUNDLE_MANIFEST_SHA}" >> "${R23_HASH_LOG}"
    fi
  fi
}

r23_post_activation_anchor_check() {
  local -a r23_anchor_status
  {
    /usr/bin/printf '%s\n' "section=terminal_anchors"
    r23_emit_anchor_manifest
  } >> "${R23_HASH_LOG}"
  if r23_emit_anchor_manifest |
    /usr/bin/shasum -a 256 --strict -c - >> "${R23_HASH_LOG}" 2>&1; then
    r23_anchor_status=( "${PIPESTATUS[@]}" )
  else
    r23_anchor_status=( "${PIPESTATUS[@]}" )
  fi
  /usr/bin/printf 'terminal_anchor_producer_rc=%s\n' "${r23_anchor_status[0]}" >> "${R23_HASH_LOG}"
  /usr/bin/printf 'terminal_anchor_shasum_rc=%s\n' "${r23_anchor_status[1]}" >> "${R23_HASH_LOG}"
  if [[ "${r23_anchor_status[0]}" -ne 0 || "${r23_anchor_status[1]}" -ne 0 ]]; then
    r23_active_fail 65 "post_activation_terminal_anchor_failure_producer_${r23_anchor_status[0]}_shasum_${r23_anchor_status[1]}"
  fi
}

r23_post_activation_manifest_check() {
  local r23_manifest_rc
  local r23_manifest_count
  local r23_manifest_count_rc
  if r23_manifest_count="$(
    trap - ERR
    /usr/bin/awk 'END { print NR }' "${R23_MANIFEST_PATH}"
  )"; then
    r23_manifest_count_rc=0
  else
    r23_manifest_count_rc="$?"
  fi
  if [[ "${r23_manifest_count_rc}" -ne 0 ]]; then
    r23_active_fail 66 "post_activation_static_manifest_count_failed_rc_${r23_manifest_count_rc}"
  fi
  /usr/bin/printf '%s\n' "section=static_manifest" >> "${R23_HASH_LOG}"
  /usr/bin/printf 'static_manifest_expected_count=%s\n' "${R23_EXPECTED_MANIFEST_COUNT}" >> "${R23_HASH_LOG}"
  /usr/bin/printf 'static_manifest_actual_count=%s\n' "${r23_manifest_count}" >> "${R23_HASH_LOG}"
  if /usr/bin/shasum -a 256 --strict -c "${R23_MANIFEST_PATH}" >> "${R23_HASH_LOG}" 2>&1; then
    r23_manifest_rc=0
  else
    r23_manifest_rc="$?"
  fi
  /usr/bin/printf 'static_manifest_rc=%s\n' "${r23_manifest_rc}" >> "${R23_HASH_LOG}"
  if [[ "${r23_manifest_rc}" -ne 0 ]]; then
    r23_active_fail 66 "post_activation_static_manifest_failure_rc_${r23_manifest_rc}"
  fi
  if [[ "${r23_manifest_count}" != "${R23_EXPECTED_MANIFEST_COUNT}" ]]; then
    r23_active_fail 66 "post_activation_static_manifest_count_${r23_manifest_count}"
  fi
}

r23_check_ranch_art_structure() {
  local r23_verification_mode="$1"
  local r23_evidence_sink
  local r23_evidence_phase
  local -a r23_expected_basenames=(
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
  local -a r23_ranch_pipeline_status

  case "${r23_verification_mode}" in
    pre_begin)
      if r23_authorization_is_consumed; then
        r23_attestation_fail 70 "pre_begin_ranch_art_check_after_authorization_consumption"
      fi
      r23_evidence_sink="/dev/stderr"
      r23_evidence_phase="pre_consumption"
      ;;
    post_activation)
      if ! r23_authorization_is_consumed; then
        r23_pre_begin_fail 70 "post_activation_ranch_art_check_before_authorization_consumption"
      fi
      if [[ ! -f "${R23_HASH_LOG}" || -L "${R23_HASH_LOG}" ]]; then
        r23_active_fail 70 "post_activation_ranch_art_hash_log_invalid"
      fi
      r23_evidence_sink="${R23_HASH_LOG}"
      r23_evidence_phase="post_activation"
      ;;
    *)
      r23_attestation_fail 64 "invalid RanchArt verification mode: ${r23_verification_mode}"
      ;;
  esac

  # Hide raw pathname diagnostics while retaining both numeric pipeline statuses
  # in the fixed fail-closed reason below.
  if /usr/bin/find -P "${R23_RANCH_ART_DIRECTORY}" \
      -mindepth 1 -maxdepth 1 -print0 2>/dev/null |
    /bin/bash -c '
      set +x
      set +v
      set -u
      set -f
      LC_ALL=C
      export LC_ALL
      shopt -u nocasematch

      r23_directory="$1"
      shift
      r23_expected_count="$#"
      r23_invalid=0
      r23_partial_final_record=0
      r23_read_rc=1
      r23_total_count=0
      r23_regular_count=0
      r23_nonregular_count=0
      r23_symlink_count=0
      r23_index=0
      r23_other_index=0
      r23_path=""
      r23_basename=""
      r23_prefix="${r23_directory}/"
      r23_expected_value=""
      r23_other_expected_value=""
      r23_seen=()

      if [[ "${r23_expected_count}" -ne 27 ]]; then
        r23_invalid=1
      fi
      if [[ ! -d "${r23_directory}" || -L "${r23_directory}" ]]; then
        r23_invalid=1
      fi

      r23_index=0
      for r23_expected_value in "$@"; do
        r23_seen[r23_index]=0
        if [[ -z "${r23_expected_value}" || "${r23_expected_value}" == */* ]]; then
          r23_invalid=1
        fi
        case "${r23_expected_value}" in
          *[!A-Za-z0-9.]* )
            r23_invalid=1
            ;;
        esac
        r23_other_index=0
        for r23_other_expected_value in "$@"; do
          if [[ "${r23_index}" -ne "${r23_other_index}" &&
                "${r23_expected_value}" == "${r23_other_expected_value}" ]]; then
            r23_invalid=1
          fi
          r23_other_index=$(( r23_other_index + 1 ))
        done
        r23_index=$(( r23_index + 1 ))
      done

      while :; do
        r23_path=""
        if IFS= read -r -d "" r23_path; then
          if [[ "${r23_total_count}" -lt 28 ]]; then
            r23_total_count=$(( r23_total_count + 1 ))
          else
            r23_invalid=1
          fi

          r23_record_regular=0
          if [[ -f "${r23_path}" && ! -L "${r23_path}" ]]; then
            r23_record_regular=1
            if [[ "${r23_regular_count}" -lt 28 ]]; then
              r23_regular_count=$(( r23_regular_count + 1 ))
            else
              r23_invalid=1
            fi
          else
            if [[ "${r23_nonregular_count}" -lt 28 ]]; then
              r23_nonregular_count=$(( r23_nonregular_count + 1 ))
            else
              r23_invalid=1
            fi
          fi
          if [[ -L "${r23_path}" ]]; then
            if [[ "${r23_symlink_count}" -lt 28 ]]; then
              r23_symlink_count=$(( r23_symlink_count + 1 ))
            else
              r23_invalid=1
            fi
          fi

          r23_record_matched=0
          if [[ "${r23_path}" == "${r23_prefix}"* ]]; then
            r23_basename="${r23_path#"${r23_prefix}"}"
            if [[ -n "${r23_basename}" && "${r23_basename}" != */* ]]; then
              r23_index=0
              for r23_expected_value in "$@"; do
                if [[ "${r23_basename}" == "${r23_expected_value}" ]]; then
                  r23_record_matched=1
                  if [[ "${r23_seen[r23_index]}" -eq 0 ]]; then
                    r23_seen[r23_index]=1
                  else
                    r23_invalid=1
                  fi
                  break
                fi
                r23_index=$(( r23_index + 1 ))
              done
            fi
          fi
          if [[ "${r23_record_regular}" -ne 1 || "${r23_record_matched}" -ne 1 ]]; then
            r23_invalid=1
          fi
        else
          r23_read_rc="$?"
          if [[ -n "${r23_path}" ]]; then
            r23_partial_final_record=1
            r23_invalid=1
          fi
          break
        fi
      done

      if [[ "${r23_read_rc}" -ne 1 ||
            "${r23_partial_final_record}" -ne 0 ||
            "${r23_total_count}" -ne 27 ||
            "${r23_regular_count}" -ne 27 ||
            "${r23_nonregular_count}" -ne 0 ||
            "${r23_symlink_count}" -ne 0 ||
            ! -d "${r23_directory}" || -L "${r23_directory}" ]]; then
        r23_invalid=1
      fi
      r23_index=0
      for r23_expected_value in "$@"; do
        if [[ "${r23_seen[r23_index]}" -ne 1 ]]; then
          r23_invalid=1
        fi
        r23_index=$(( r23_index + 1 ))
      done

      if [[ "${r23_invalid}" -ne 0 ]]; then
        exit 1
      fi
      exit 0
    ' "r23-ranch-art-nul-validator-v1" \
      "${R23_RANCH_ART_DIRECTORY}" "${r23_expected_basenames[@]}"; then
    r23_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  else
    r23_ranch_pipeline_status=( "${PIPESTATUS[@]}" )
  fi

  if [[ "${#r23_ranch_pipeline_status[@]}" -ne 2 ]]; then
    r23_attestation_fail 70 "ranch_art_pipeline_status_shape_invalid"
  fi
  if [[ "${r23_ranch_pipeline_status[0]}" -ne 0 ||
        "${r23_ranch_pipeline_status[1]}" -ne 0 ]]; then
    r23_attestation_fail 70 \
      "ranch_art_nul_validation_failed_find_${r23_ranch_pipeline_status[0]}_validator_${r23_ranch_pipeline_status[1]}"
  fi

  /usr/bin/printf '%s\n' "section=ranch_art_structure" >> "${r23_evidence_sink}"
  /usr/bin/printf 'phase=%s\n' "${r23_evidence_phase}" >> "${r23_evidence_sink}"
  /usr/bin/printf 'ranch_art_verification_mode=%s\n' \
    "${r23_verification_mode}" >> "${r23_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "pathname_transport=find_print0_bash_read_d_nul_v1" \
    "ranch_art_find_rc=${r23_ranch_pipeline_status[0]}" \
    "ranch_art_validator_rc=${r23_ranch_pipeline_status[1]}" \
    "ranch_art_expected_count=27" \
    "ranch_art_parent_type=directory_non_symlink" \
    "ranch_art_node_type=regular_non_symlink" \
    "ranch_art_actual_count=27" \
    "ranch_art_exact_relative_path_set_begin" >> "${r23_evidence_sink}"
  /usr/bin/printf '%s\n' "${r23_expected_basenames[@]}" >> "${r23_evidence_sink}"
  /usr/bin/printf '%s\n' \
    "ranch_art_exact_relative_path_set_end" \
    "nonregular_count=0" \
    "symlink_count=0" \
    "regular_count=27" >> "${r23_evidence_sink}"
}

if [[ "$#" -ne 1 ]]; then
  r23_pre_begin_fail 64 "expected one automatically computed Review23 SHA-256 argument"
fi

readonly R23_EXPECTED_REVIEW23_SHA="$1"
r23_require_lowercase_sha256 "${R23_EXPECTED_REVIEW23_SHA}" "Review23 hash"

if [[ "$0" != "${R23_DRIVER_PATH}" ]]; then
  r23_pre_begin_fail 64 "driver must be invoked by its frozen absolute path"
fi
if [[ "${BASH_SOURCE[0]}" != "${R23_DRIVER_PATH}" ||
      ! -f "${R23_DRIVER_PATH}" ||
      -L "${R23_DRIVER_PATH}" ||
      "$(/bin/realpath "${R23_DRIVER_PATH}")" != "${R23_DRIVER_PATH}" ]]; then
  r23_pre_begin_fail 64 "driver source path or file type is not canonical"
fi
if (( BASH_VERSINFO[0] < 3 ||
      (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2) )); then
  r23_pre_begin_fail 64 "Bash 3.2 or newer is required"
fi
if [[ "${LC_ALL:-}" != "C" || "${LANG:-}" != "C" ]]; then
  r23_pre_begin_fail 64 "LC_ALL and LANG must both equal C"
fi
if [[ "${PATH:-}" != "/usr/bin:/bin:/usr/sbin:/sbin" ]]; then
  r23_pre_begin_fail 64 "PATH is not the frozen clean value"
fi
if [[ "${TMPDIR:-}" != "/private/tmp" ]]; then
  r23_pre_begin_fail 64 "TMPDIR is not the frozen clean value"
fi
if [[ "${GIT_CONFIG_NOSYSTEM:-}" != "1" || "${GIT_CONFIG_GLOBAL:-}" != "/dev/null" ]]; then
  r23_pre_begin_fail 64 "Git clean-environment controls are missing"
fi
if [[ -n "${BASH_ENV+x}" || -n "${ENV+x}" || -n "${CDPATH+x}" ]]; then
  r23_pre_begin_fail 64 "shell startup or directory environment was inherited"
fi

R23_PHASE="pre_begin_review23_authority"
r23_load_review23_machine_block
r23_require_lowercase_sha256 "${R23_EXPECTED_FREEZE_SHA}" "freeze hash"
r23_require_lowercase_sha256 "${R23_EXPECTED_DRIVER_SHA}" "driver hash"
r23_require_lowercase_sha256 "${R23_EXPECTED_MANIFEST_SHA}" "manifest hash"
readonly R23_EXPECTED_FREEZE_SHA
readonly R23_EXPECTED_DRIVER_SHA
readonly R23_EXPECTED_MANIFEST_SHA

R23_PHASE="pre_begin_terminal_anchors"
r23_check_anchors_to_stdout

R23_PHASE="pre_begin_manifest_shape"
r23_check_manifest_shape

R23_PHASE="pre_begin_static_manifest"
r23_check_manifest_to_stdout

R23_PHASE="pre_begin_repository_identity"
R23_ACTUAL_BRANCH="$(/usr/bin/git -C "${R23_REPOSITORY_ROOT}" symbolic-ref --quiet --short HEAD)"
R23_ACTUAL_HEAD="$(/usr/bin/git -C "${R23_REPOSITORY_ROOT}" rev-parse --verify HEAD)"
if [[ "${R23_ACTUAL_BRANCH}" != "${R23_EXPECTED_BRANCH}" ]]; then
  r23_pre_begin_fail 67 "branch is ${R23_ACTUAL_BRANCH}, expected ${R23_EXPECTED_BRANCH}"
fi
if [[ "${R23_ACTUAL_HEAD}" != "${R23_EXPECTED_HEAD}" ]]; then
  r23_pre_begin_fail 67 "HEAD is ${R23_ACTUAL_HEAD}, expected ${R23_EXPECTED_HEAD}"
fi

R23_PHASE="pre_begin_r16_preservation"
R23_R16_RUNTIME_PATHS=(
  "${R23_TASK_DIRECTORY}/r16-targeted-tests.log"
  "${R23_TASK_DIRECTORY}/r16-verify.log"
  "${R23_TASK_DIRECTORY}/r16-build.log"
  "${R23_TASK_DIRECTORY}/r16-migration-matrix.log"
  "${R23_TASK_DIRECTORY}/impl-report-r16.md"
  "${R23_TASK_DIRECTORY}/evidence/r16-clean-boundary.log"
  "${R23_TASK_DIRECTORY}/evidence/r16-bundle-provenance.log"
  "${R23_TASK_DIRECTORY}/evidence/r16-source-gates.log"
  "${R23_TASK_DIRECTORY}/evidence/r16-hash-manifest.log"
  "${R23_TASK_DIRECTORY}/evidence/r16-preview-bootstrap.log"
  "${R23_TASK_DIRECTORY}/evidence/r16-preview-cold-start.log"
  "${R23_TASK_DIRECTORY}/evidence/r16-preview-smoke.png"
)
for R23_R16_RUNTIME_PATH in "${R23_R16_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R16_RUNTIME_PATH}"
done

R23_PHASE="pre_begin_r17_preservation"
R23_R17_RUNTIME_PATHS=(
  "${R23_TASK_DIRECTORY}/r17-targeted-tests.log"
  "${R23_TASK_DIRECTORY}/r17-verify.log"
  "${R23_TASK_DIRECTORY}/r17-build.log"
  "${R23_TASK_DIRECTORY}/r17-migration-matrix.log"
  "${R23_TASK_DIRECTORY}/impl-report-r17.md"
  "${R23_TASK_DIRECTORY}/evidence/r17-clean-boundary.log"
  "${R23_TASK_DIRECTORY}/evidence/r17-bundle-provenance.log"
  "${R23_TASK_DIRECTORY}/evidence/r17-source-gates.log"
  "${R23_TASK_DIRECTORY}/evidence/r17-hash-manifest.log"
  "${R23_TASK_DIRECTORY}/evidence/r17-preview-bootstrap.log"
  "${R23_TASK_DIRECTORY}/evidence/r17-preview-cold-start.log"
  "${R23_TASK_DIRECTORY}/evidence/r17-preview-smoke.png"
)
for R23_R17_RUNTIME_PATH in "${R23_R17_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R17_RUNTIME_PATH}"
done

R23_PHASE="pre_begin_r18_preservation"
R23_R18_RUNTIME_PATHS=(
  "${R23_TASK_DIRECTORY}/r18-targeted-tests.log"
  "${R23_TASK_DIRECTORY}/r18-verify.log"
  "${R23_TASK_DIRECTORY}/r18-build.log"
  "${R23_TASK_DIRECTORY}/r18-migration-matrix.log"
  "${R23_TASK_DIRECTORY}/impl-report-r18.md"
  "${R23_TASK_DIRECTORY}/evidence/r18-clean-boundary.log"
  "${R23_TASK_DIRECTORY}/evidence/r18-bundle-provenance.log"
  "${R23_TASK_DIRECTORY}/evidence/r18-source-gates.log"
  "${R23_TASK_DIRECTORY}/evidence/r18-hash-manifest.log"
  "${R23_TASK_DIRECTORY}/evidence/r18-preview-bootstrap.log"
  "${R23_TASK_DIRECTORY}/evidence/r18-preview-cold-start.log"
  "${R23_TASK_DIRECTORY}/evidence/r18-preview-smoke.png"
)
for R23_R18_RUNTIME_PATH in "${R23_R18_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R18_RUNTIME_PATH}"
done

R23_PHASE="pre_begin_r21_preservation"
R23_R21_RUNTIME_PATHS=(
  "${R23_TASK_DIRECTORY}/r21-targeted-tests.log"
  "${R23_TASK_DIRECTORY}/r21-verify.log"
  "${R23_TASK_DIRECTORY}/r21-build.log"
  "${R23_TASK_DIRECTORY}/r21-migration-matrix.log"
  "${R23_TASK_DIRECTORY}/impl-report-r21.md"
  "${R23_TASK_DIRECTORY}/evidence/r21-clean-boundary.log"
  "${R23_TASK_DIRECTORY}/evidence/r21-bundle-provenance.log"
  "${R23_TASK_DIRECTORY}/evidence/r21-source-gates.log"
  "${R23_TASK_DIRECTORY}/evidence/r21-hash-manifest.log"
  "${R23_TASK_DIRECTORY}/evidence/r21-preview-bootstrap.log"
  "${R23_TASK_DIRECTORY}/evidence/r21-preview-cold-start.log"
  "${R23_TASK_DIRECTORY}/evidence/r21-preview-smoke.png"
)
for R23_R21_RUNTIME_PATH in "${R23_R21_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R21_RUNTIME_PATH}"
done

R23_PHASE="pre_begin_r22_preservation"
R23_R22_RUNTIME_PATHS=(
  "${R23_TASK_DIRECTORY}/r22-targeted-tests.log"
  "${R23_TASK_DIRECTORY}/r22-verify.log"
  "${R23_TASK_DIRECTORY}/r22-build.log"
  "${R23_TASK_DIRECTORY}/r22-migration-matrix.log"
  "${R23_TASK_DIRECTORY}/impl-report-r22.md"
  "${R23_TASK_DIRECTORY}/evidence/r22-clean-boundary.log"
  "${R23_TASK_DIRECTORY}/evidence/r22-bundle-provenance.log"
  "${R23_TASK_DIRECTORY}/evidence/r22-source-gates.log"
  "${R23_TASK_DIRECTORY}/evidence/r22-hash-manifest.log"
  "${R23_TASK_DIRECTORY}/evidence/r22-preview-bootstrap.log"
  "${R23_TASK_DIRECTORY}/evidence/r22-preview-cold-start.log"
  "${R23_TASK_DIRECTORY}/evidence/r22-preview-smoke.png"
)
for R23_R22_RUNTIME_PATH in "${R23_R22_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R22_RUNTIME_PATH}"
done

R23_PHASE="pre_begin_r19_containment"
r23_require_r19_containment "pre_begin"

R23_PHASE="pre_begin_r20_containment"
r23_require_r20_containment "pre_begin"

r23_require_no_unconsumed_fresh_roots "pre_begin"

R23_PHASE="pre_begin_runtime_paths"
R23_RUNTIME_PATHS=(
  "${R23_TASK_DIRECTORY}/r23-targeted-tests.log"
  "${R23_TASK_DIRECTORY}/r23-verify.log"
  "${R23_TASK_DIRECTORY}/r23-build.log"
  "${R23_TASK_DIRECTORY}/r23-migration-matrix.log"
  "${R23_TASK_DIRECTORY}/impl-report-r23.md"
  "${R23_TASK_DIRECTORY}/evidence/r23-clean-boundary.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-bundle-provenance.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-source-gates.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-hash-manifest.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-preview-bootstrap.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-preview-cold-start.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-preview-smoke.png"
)
for R23_RUNTIME_PATH in "${R23_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_RUNTIME_PATH}"
done

R23_PHASE="pre_begin_processes"
r23_require_process_absent "AgentLoop"
r23_require_process_absent "AgentLoopApp"

R23_PHASE="pre_begin_r15_tombstone_absence"
r23_require_r15_tombstones_absent
if [[ -e "${R23_R15_PLANNED_APP}" || -L "${R23_R15_PLANNED_APP}" ]]; then
  r23_pre_begin_fail 70 "R15 planned App must remain absent"
fi
if [[ -e "${R23_R15_SCREENSHOT}" || -L "${R23_R15_SCREENSHOT}" ]]; then
  r23_pre_begin_fail 70 "R15 screenshot must remain absent"
fi

R23_PHASE="pre_begin_activation_metadata"
R23_INVOCATION_ID="r23-$(
  /usr/bin/uuidgen |
    /usr/bin/tr '[:upper:]' '[:lower:]'
)"
if [[ ! "${R23_INVOCATION_ID}" =~ ^r23-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
  r23_pre_begin_fail 71 "generated R23 invocation ID has invalid format"
fi
R23_BEGIN_UTC="$(r23_utc_now)"
if [[ ! "${R23_BEGIN_UTC}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  r23_pre_begin_fail 71 "generated R23 begin UTC has invalid format"
fi

R23_PHASE="pre_begin_ranch_art_structure"
r23_check_ranch_art_structure "pre_begin"

R23_PHASE="pre_begin_final_r21_preservation"
for R23_R21_RUNTIME_PATH in "${R23_R21_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R21_RUNTIME_PATH}"
done
R23_PHASE="pre_begin_final_r22_preservation"
for R23_R22_RUNTIME_PATH in "${R23_R22_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R22_RUNTIME_PATH}"
done
r23_require_no_unconsumed_fresh_roots "pre_begin"

R23_PHASE="pre_begin_final_r19_containment"
r23_require_r19_containment "pre_begin"

R23_PHASE="pre_begin_final_r20_containment"
r23_require_r20_containment "pre_begin"

R23_PHASE="activation_boundary"
trap '' HUP INT TERM
if r23_exclusive_create_empty "${R23_BOUNDARY_LOG}"; then
  R23_BOUNDARY_ACTIVE="true"
  trap 'r23_signal_error HUP' HUP
  trap 'r23_signal_error INT' INT
  trap 'r23_signal_error TERM' TERM
else
  trap 'r23_signal_error HUP' HUP
  trap 'r23_signal_error INT' INT
  trap 'r23_signal_error TERM' TERM
  r23_pre_begin_fail 71 "could not exclusive-create R23 boundary log"
fi
if ! /usr/bin/printf '%s\n' \
    "boundary=R23_EROSION_SNAPSHOT_AND_RELEASE_CONFIGURATION_REPAIR" \
    "invocation_id=${R23_INVOCATION_ID}" \
    "utc_begin=${R23_BEGIN_UTC}" \
    "authorization_consumed=true" \
    "boundary_exclusive_create_succeeded=true" \
    "authority_mode=standing_goal_automatic_after_review23" \
    "standing_goal_authority_verified=true" \
    "reviewer_independence_attested=true" \
    "reviewer_write_scope=review23_only" \
    "user_hash_echo_required=false" \
    "local_consistency_is_not_human_anti_rewrite=true" \
    "status=BEGIN_STARTED" \
    "branch=${R23_ACTUAL_BRANCH}" \
    "head=${R23_ACTUAL_HEAD}" \
    "r15_state_root_pre_begin_observed_state=ABSENT" \
    "r15_bundle_parent_pre_begin_observed_state=ABSENT" \
    "r15_state_root_current_absent=true" \
    "r15_bundle_parent_current_absent=true" \
    "r15_absence_proof_identity=${R23_R15_ABSENCE_PROOF_IDENTITY}" \
    "disappearance_cause=UNKNOWN" \
    "pre_begin_ranch_art_structure=true" \
    "recipe=r23-dev-bundle-v1" \
    "normal_root=/Users/muzi/Library/Application Support/AgentLoop" \
    "normal_root_access_policy=lsof_path_comparison_only" \
    "r19_invocation_id=${R23_R19_INVOCATION_ID}" \
    "r19_verdict=REJECTED_CONTAMINATED" \
    "r19_artifact_count=11" \
    "r19_state_root=${R23_R19_STATE_ROOT}" \
    "r19_bundle_parent=${R23_R19_BUNDLE_PARENT}" \
    "r19_roots_historical_state=CANONICAL_EMPTY" \
    "r19_roots_current_state=ABSENT_TOMBSTONE" \
    "r19_roots_disappearance_cause=UNKNOWN" \
    "r19_retry_same_boundary=false" \
    "r20_invocation_id=${R23_R20_INVOCATION_ID}" \
    "r20_verdict=REJECTED_CONTAMINATED" \
    "r20_failure_phase=release_core_build" \
    "r20_historical_authoritative_full_tests=652_of_652_pass" \
    "r20_historical_targeted_audit=46_of_46_pass" \
    "r20_historical_launch_ready=true" \
    "r20_artifact_count=11" \
    "r20_state_root=${R23_R20_STATE_ROOT}" \
    "r20_state_root_historical_state=CANONICAL_EMPTY" \
    "r20_state_root_current_state=ABSENT_TOMBSTONE" \
    "r20_state_root_disappearance_cause=UNKNOWN" \
    "r20_bundle_parent=${R23_R20_BUNDLE_PARENT}" \
    "r20_erosion_mask_identity=r23_r20_fixed_38_bit_v1" \
    "r20_erosion_mask_order=parent_app_then_36_historical_nodes" \
    "r20_review22_baseline_mask=${R23_R20_REVIEW22_BASELINE_MASK}" \
    "r20_review22_observed_zero_absorbed=true" \
    "r20_erosion_first_mask=${R23_R20_EROSION_FIRST_MASK}" \
    "r20_erosion_first_state=${R23_R20_EROSION_FIRST_STATE}" \
    "r20_erosion_pre_begin_mask=${R23_R20_EROSION_PRE_BEGIN_MASK}" \
    "r20_erosion_pre_begin_state=${R23_R20_EROSION_PRE_BEGIN_STATE}" \
    "r20_erosion_latest_mask=${R23_R20_EROSION_LATEST_MASK}" \
    "r20_erosion_latest_state=${R23_R20_EROSION_LATEST_STATE}" \
    "r20_erosion_transition=one_to_zero_only" \
    "r20_retry_same_boundary=false" \
    "r21_review_approved=true" \
    "r21_external_caller_anchors_passed=true" \
    "r21_static_manifest_155_of_155_passed=true" \
    "r21_pre_begin_exit_code=70" \
    "r21_pre_begin_failure_phase=r19_containment" \
    "r21_authorization_consumed=false" \
    "r21_runtime_write_count=0" \
    "r22_freeze_sha=${R23_R22_FREEZE_SHA}" \
    "r22_review22_sha=${R23_R22_REVIEW_SHA}" \
    "r22_driver_sha=${R23_R22_DRIVER_SHA}" \
    "r22_manifest_sha=${R23_R22_MANIFEST_SHA}" \
    "r22_review_verdict=CHANGES_REQUIRED_0_P0_1_P1" \
    "r22_authorization_consumed=false" \
    "r22_runtime_write_count=0" \
    "r22_not_executed=true" \
    "implementation_entry_baseline_count=2" \
    "implementation_allowed_final_delta_count=1" \
    "implementation_final_delta_policy=exact_test_path_only_relative_to_entry_manifest" \
    "implementation_core_path=${R23_IMPLEMENTATION_CORE_PATH}" \
    "implementation_test_path=${R23_IMPLEMENTATION_TEST_PATH}" \
    "implementation_core_required_sha=${R23_R20_CORE_FINAL_SHA}" \
    "implementation_test_entry_sha=${R23_R20_TEST_FINAL_SHA}" \
    "implementation_test_delta=three_matching_debug_guard_pairs_only" \
    "authoritative_test_command=swift_run_RunTests_unfiltered_once" \
    "test_filter_forbidden=true" \
    "targeted_evidence_source=mechanical_46_name_extraction_from_authoritative_log" \
    "freeze_sha=${R23_EXPECTED_FREEZE_SHA}" \
    "review23_sha=${R23_EXPECTED_REVIEW23_SHA}" \
    "driver_sha=${R23_EXPECTED_DRIVER_SHA}" \
    "manifest_sha=${R23_EXPECTED_MANIFEST_SHA}" \
    >> "${R23_BOUNDARY_LOG}"; then
  r23_active_fail 71 "could_not_initialize_R23_boundary_log" "boundary_initialization"
fi
R23_BOUNDARY_INITIALIZED="true"

R23_PHASE="post_activation_immediate_r21_preservation"
for R23_R21_RUNTIME_PATH in "${R23_R21_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R21_RUNTIME_PATH}"
done
R23_PHASE="post_activation_immediate_r22_preservation"
for R23_R22_RUNTIME_PATH in "${R23_R22_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R22_RUNTIME_PATH}"
done
r23_require_no_unconsumed_fresh_roots "post_activation"

R23_PHASE="post_activation_immediate_r19_containment"
r23_require_r19_containment "post_activation_probe"

R23_PHASE="post_activation_immediate_r20_containment"
r23_require_r20_containment "post_activation_probe"

R23_PHASE="activation_hash_log"
if ! r23_exclusive_create_empty "${R23_HASH_LOG}"; then
  r23_active_fail 71 "exclusive_create_failed_${R23_HASH_LOG}" "exclusive_create"
fi

R23_PHASE="post_activation_ranch_art_structure"
r23_check_ranch_art_structure "post_activation"

R23_PHASE="post_activation_terminal_anchors"
r23_post_activation_anchor_check

R23_PHASE="post_activation_static_manifest"
r23_check_manifest_shape
r23_post_activation_manifest_check

R23_PHASE="post_activation_r19_containment"
r23_require_r19_containment "post_activation"

R23_PHASE="post_activation_r20_containment"
r23_require_r20_containment "post_activation"

/usr/bin/printf 'frozen_info_plist_sha=%s\n' "${R23_EXPECTED_INFO_PLIST_SHA}" >> "${R23_HASH_LOG}"
/usr/bin/printf 'frozen_ranch_art_manifest_sha=%s\n' "${R23_EXPECTED_RANCH_ART_MANIFEST_SHA}" >> "${R23_HASH_LOG}"
/usr/bin/printf '%s\n' "section=worktree_status" >> "${R23_HASH_LOG}"
/usr/bin/git --no-optional-locks -C "${R23_REPOSITORY_ROOT}" status --short --branch >> "${R23_HASH_LOG}"

R23_PHASE="activation_remaining_logs"
R23_REMAINING_TEXT_LOGS=(
  "${R23_TASK_DIRECTORY}/r23-targeted-tests.log"
  "${R23_TASK_DIRECTORY}/r23-verify.log"
  "${R23_TASK_DIRECTORY}/r23-build.log"
  "${R23_TASK_DIRECTORY}/r23-migration-matrix.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-bundle-provenance.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-source-gates.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-preview-bootstrap.log"
  "${R23_TASK_DIRECTORY}/evidence/r23-preview-cold-start.log"
)
for R23_REMAINING_TEXT_LOG in "${R23_REMAINING_TEXT_LOGS[@]}"; do
  if ! r23_exclusive_create_empty "${R23_REMAINING_TEXT_LOG}"; then
    r23_active_fail 71 "exclusive_create_failed_${R23_REMAINING_TEXT_LOG}" "exclusive_create"
  fi
done

R23_PHASE="activation_fresh_roots"
R23_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r23-state.XXXXXX')"
R23_BUNDLE_PARENT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r23-bundle.XXXXXX')"
R23_PLANNED_APP="${R23_BUNDLE_PARENT}/AgentLoop.app"
R23_PLANNED_EXECUTABLE="${R23_PLANNED_APP}/Contents/MacOS/AgentLoop"

r23_require_fresh_root "${R23_STATE_ROOT}" "fresh_state_root"
r23_require_fresh_root "${R23_BUNDLE_PARENT}" "fresh_bundle_parent"
if [[ "${R23_STATE_ROOT}" == "${R23_BUNDLE_PARENT}" ]]; then
  r23_active_fail 72 "fresh_roots_equal"
fi
case "${R23_STATE_ROOT}/" in
  "${R23_BUNDLE_PARENT}/"* )
    r23_active_fail 72 "state_root_nested_in_bundle_parent"
    ;;
esac
case "${R23_BUNDLE_PARENT}/" in
  "${R23_STATE_ROOT}/"* )
    r23_active_fail 72 "bundle_parent_nested_in_state_root"
    ;;
esac
if [[ "${R23_STATE_ROOT}" == "${R23_R15_STATE_ROOT}" ||
      "${R23_STATE_ROOT}" == "${R23_R15_BUNDLE_PARENT}" ||
      "${R23_BUNDLE_PARENT}" == "${R23_R15_STATE_ROOT}" ||
      "${R23_BUNDLE_PARENT}" == "${R23_R15_BUNDLE_PARENT}" ||
      "${R23_STATE_ROOT}" == "${R23_R19_STATE_ROOT}" ||
      "${R23_STATE_ROOT}" == "${R23_R19_BUNDLE_PARENT}" ||
      "${R23_BUNDLE_PARENT}" == "${R23_R19_STATE_ROOT}" ||
      "${R23_BUNDLE_PARENT}" == "${R23_R19_BUNDLE_PARENT}" ||
      "${R23_STATE_ROOT}" == "${R23_R20_STATE_ROOT}" ||
      "${R23_STATE_ROOT}" == "${R23_R20_BUNDLE_PARENT}" ||
      "${R23_BUNDLE_PARENT}" == "${R23_R20_STATE_ROOT}" ||
      "${R23_BUNDLE_PARENT}" == "${R23_R20_BUNDLE_PARENT}" ]]; then
  r23_active_fail 72 "fresh_root_reuses_historical_root"
fi
if [[ -e "${R23_PLANNED_APP}" || -L "${R23_PLANNED_APP}" ]]; then
  r23_active_fail 72 "planned_app_preexists"
fi

R23_PHASE="post_root_r21_preservation"
for R23_R21_RUNTIME_PATH in "${R23_R21_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R21_RUNTIME_PATH}"
done
R23_PHASE="post_root_r22_preservation"
for R23_R22_RUNTIME_PATH in "${R23_R22_RUNTIME_PATHS[@]}"; do
  r23_require_absent_path "${R23_R22_RUNTIME_PATH}"
done
r23_require_no_unconsumed_fresh_roots "post_activation"

R23_PHASE="post_root_final_r19_containment"
r23_require_r19_containment "post_activation_probe"

R23_PHASE="post_root_final_r20_containment"
r23_require_r20_containment "post_activation_probe"

/usr/bin/printf '%s\n' \
  "section=final_historical_root_lifecycle" \
  "r19_roots_current_state=ABSENT_TOMBSTONE" \
  "r20_state_root_current_state=ABSENT_TOMBSTONE" \
  "r20_review22_baseline_mask=${R23_R20_REVIEW22_BASELINE_MASK}" \
  "r20_erosion_first_mask=${R23_R20_EROSION_FIRST_MASK}" \
  "r20_erosion_first_state=${R23_R20_EROSION_FIRST_STATE}" \
  "r20_erosion_pre_begin_mask=${R23_R20_EROSION_PRE_BEGIN_MASK}" \
  "r20_erosion_pre_begin_state=${R23_R20_EROSION_PRE_BEGIN_STATE}" \
  "r20_erosion_post_activation_mask=${R23_R20_EROSION_POST_ACTIVATION_MASK}" \
  "r20_erosion_post_activation_state=${R23_R20_EROSION_POST_ACTIVATION_STATE}" \
  "r20_erosion_latest_mask=${R23_R20_EROSION_LATEST_MASK}" \
  "r20_erosion_latest_state=${R23_R20_EROSION_LATEST_STATE}" \
  >> "${R23_HASH_LOG}"

r23_append_boundary "state_root=${R23_STATE_ROOT}"
r23_append_boundary "bundle_parent=${R23_BUNDLE_PARENT}"
r23_append_boundary "planned_app=${R23_PLANNED_APP}"
r23_append_boundary "planned_executable=${R23_PLANNED_EXECUTABLE}"
r23_append_boundary "final_executable_hash=DEFERRED_TO_LAUNCH_READY"
r23_append_boundary "process_count=0"
r23_append_boundary "r15_planned_app_absent=true"
r23_append_boundary "r15_screenshot_absent=true"
r23_append_boundary "r16_runtime_artifacts_absent=true"
r23_append_boundary "r16_fresh_roots_absent=true"
r23_append_boundary "r16_pre_begin_zero_write_preserved=true"
r23_append_boundary "r17_runtime_artifacts_absent=true"
r23_append_boundary "r17_fresh_roots_absent=true"
r23_append_boundary "r17_not_executed_preserved=true"
r23_append_boundary "r18_runtime_artifacts_absent=true"
r23_append_boundary "r18_fresh_roots_absent=true"
r23_append_boundary "r18_not_executed_preserved=true"
r23_append_boundary "r21_runtime_artifacts_absent=true"
r23_append_boundary "r21_fresh_roots_absent=true"
r23_append_boundary "r21_pre_begin_zero_write_preserved=true"
r23_append_boundary "r21_authorization_consumed=false"
r23_append_boundary "r22_runtime_artifacts_absent=true"
r23_append_boundary "r22_fresh_roots_absent=true"
r23_append_boundary "r22_review_verdict=CHANGES_REQUIRED_0_P0_1_P1"
r23_append_boundary "r22_authorization_consumed=false"
r23_append_boundary "r22_runtime_write_count=0"
r23_append_boundary "r22_not_executed=true"
r23_append_boundary "r19_runtime_artifacts_immutable=true"
r23_append_boundary "r19_runtime_artifact_count=11"
  r23_append_boundary "r19_boundary_rejected_contaminated=true"
  r23_append_boundary "r19_state_root=${R23_R19_STATE_ROOT}"
  r23_append_boundary "r19_bundle_parent=${R23_R19_BUNDLE_PARENT}"
  r23_append_boundary "r19_roots_historical_state=CANONICAL_EMPTY"
  r23_append_boundary "r19_roots_current_state=ABSENT_TOMBSTONE"
  r23_append_boundary "r19_roots_disappearance_cause=UNKNOWN"
  r23_append_boundary "r19_tombstone_absorbing=true"
r23_append_boundary "r19_planned_app_absent=true"
r23_append_boundary "r19_screenshot_absent=true"
r23_append_boundary "r19_retry_same_boundary=false"
r23_append_boundary "r20_runtime_artifacts_immutable=true"
r23_append_boundary "r20_runtime_artifact_count=11"
r23_append_boundary "r20_boundary_rejected_contaminated=true"
r23_append_boundary "r20_failure_phase=release_core_build"
r23_append_boundary "r20_historical_authoritative_full_tests=652_of_652_pass"
r23_append_boundary "r20_historical_targeted_audit=46_of_46_pass"
r23_append_boundary "r20_historical_launch_ready=true"
r23_append_boundary "r20_state_root=${R23_R20_STATE_ROOT}"
r23_append_boundary "r20_bundle_parent=${R23_R20_BUNDLE_PARENT}"
r23_append_boundary "r20_state_root_historical_state=CANONICAL_EMPTY"
r23_append_boundary "r20_state_root_current_state=ABSENT_TOMBSTONE"
r23_append_boundary "r20_state_root_disappearance_cause=UNKNOWN"
r23_append_boundary "r20_erosion_mask_identity=r23_r20_fixed_38_bit_v1"
r23_append_boundary "r20_erosion_mask_order=parent_app_then_36_historical_nodes"
r23_append_boundary "r20_review22_baseline_mask=${R23_R20_REVIEW22_BASELINE_MASK}"
r23_append_boundary "r20_review22_observed_zero_absorbed=true"
r23_append_boundary "r20_erosion_first_mask=${R23_R20_EROSION_FIRST_MASK}"
r23_append_boundary "r20_erosion_first_state=${R23_R20_EROSION_FIRST_STATE}"
r23_append_boundary "r20_erosion_pre_begin_mask=${R23_R20_EROSION_PRE_BEGIN_MASK}"
r23_append_boundary "r20_erosion_pre_begin_state=${R23_R20_EROSION_PRE_BEGIN_STATE}"
r23_append_boundary "r20_erosion_post_activation_mask=${R23_R20_EROSION_POST_ACTIVATION_MASK}"
r23_append_boundary "r20_erosion_post_activation_state=${R23_R20_EROSION_POST_ACTIVATION_STATE}"
r23_append_boundary "r20_erosion_latest_mask=${R23_R20_EROSION_LATEST_MASK}"
r23_append_boundary "r20_erosion_latest_state=${R23_R20_EROSION_LATEST_STATE}"
r23_append_boundary "r20_erosion_transition=one_to_zero_only"
r23_append_boundary "r20_current_node_count=${R23_R20_CAPTURED_NODE_COUNT}"
r23_append_boundary "r20_current_directory_count=${R23_R20_CAPTURED_DIRECTORY_COUNT}"
r23_append_boundary "r20_current_regular_file_count=${R23_R20_CAPTURED_FILE_COUNT}"
r23_append_boundary "r20_current_signed_app_verified=${R23_R20_CURRENT_SIGNED_APP_VERIFIED}"
if [[ "${R23_R20_CAPTURED_MASK:0:1}" == "0" ]]; then
  r23_append_boundary "r20_bundle_parent_current_absent=true"
else
  r23_append_boundary "r20_bundle_parent_current_present=true"
fi
if [[ "${R23_R20_CAPTURED_MASK:1:1}" == "0" ]]; then
  r23_append_boundary "r20_app_current_absent=true"
else
  r23_append_boundary "r20_app_current_present=true"
fi
if [[ "${R23_R20_CURRENT_SIGNED_APP_VERIFIED}" == "true" ]]; then
  r23_append_boundary "r20_current_complete_historical_set=true"
  r23_append_boundary "r20_current_signed_bundle_manifest_recomputed=true"
  r23_append_boundary "r20_current_executable_sha=${R23_R20_EXECUTABLE_SHA}"
  r23_append_boundary "r20_current_info_plist_sha=${R23_R20_INFO_PLIST_SHA}"
  r23_append_boundary "r20_current_signed_bundle_manifest_sha=${R23_R20_SIGNED_BUNDLE_MANIFEST_SHA}"
else
  r23_append_boundary "r20_current_complete_historical_set=false"
  r23_append_boundary "r20_current_signed_bundle_manifest_recomputed=false"
  r23_append_boundary "r20_historical_executable_sha=${R23_R20_EXECUTABLE_SHA}"
  r23_append_boundary "r20_historical_info_plist_sha=${R23_R20_INFO_PLIST_SHA}"
  r23_append_boundary "r20_historical_signed_bundle_manifest_sha=${R23_R20_SIGNED_BUNDLE_MANIFEST_SHA}"
fi
r23_append_boundary "r20_screenshot_absent=true"
r23_append_boundary "r20_retry_same_boundary=false"
r23_append_boundary "r23_pre_activation_fresh_roots_absent=true"
r23_append_boundary "frozen_info_plist_sha=${R23_EXPECTED_INFO_PLIST_SHA}"
r23_append_boundary "frozen_ranch_art_manifest_sha=${R23_EXPECTED_RANCH_ART_MANIFEST_SHA}"

R23_PHASE="begin_finalization"
r23_require_process_absent "AgentLoop"
r23_require_process_absent "AgentLoopApp"
r23_append_boundary "utc_begin_attested=$(r23_utc_now)"
r23_append_boundary "begin_attestation_complete=true"
r23_append_boundary "status=BEGIN_ATTESTED"
r23_append_boundary "retry_same_boundary=false"

/usr/bin/printf '%s\n' \
  "status=BEGIN_ATTESTED" \
  "invocation_id=${R23_INVOCATION_ID}" \
  "boundary_log=${R23_BOUNDARY_LOG}" \
  "hash_log=${R23_HASH_LOG}" \
  "state_root=${R23_STATE_ROOT}" \
  "bundle_parent=${R23_BUNDLE_PARENT}" \
  "planned_app=${R23_PLANNED_APP}" \
  "planned_executable=${R23_PLANNED_EXECUTABLE}"
