#!/bin/bash

# R26 reviewed clean re-verification driver.
# BEGIN, the unique full test, every later mechanical gate, both interactive
# preview checkpoints, and END execute in this one Bash 3.2 process.  No
# caller-shell status, lifecycle state, or ad-hoc continuation is trusted.

set -Eeuo pipefail
set -f
IFS=$' \t\n'
umask 077

readonly R26_REPOSITORY_ROOT="/Users/muzi/Agent-loop"
readonly R26_TASK_DIRECTORY="${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/p1-a2-durable-rumination"
readonly R26_DRIVER_PATH="${R26_TASK_DIRECTORY}/evidence/r26-begin.sh"
readonly R26_MANIFEST_PATH="${R26_TASK_DIRECTORY}/evidence/r26-entry.sha256"
readonly R26_FREEZE_PATH="${R26_TASK_DIRECTORY}/evidence/plan-freeze-r26.md"
readonly R26_REVIEW26_PATH="${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/26-p1-plan-review.md"
readonly R26_BOUNDARY_LOG="${R26_TASK_DIRECTORY}/evidence/r26-clean-boundary.log"
readonly R26_HASH_LOG="${R26_TASK_DIRECTORY}/evidence/r26-hash-manifest.log"
readonly R26_VERIFY_LOG="${R26_TASK_DIRECTORY}/r26-verify.log"
readonly R26_EXPECTED_MANIFEST_COUNT="206"
readonly R26_EXPECTED_BRANCH="codex/personal-ai-ranch-p0"
readonly R26_EXPECTED_HEAD="02334ec8d21533be81d93d39191bc7d9b9c24f7f"
readonly R26_EXPECTED_CORE_SHA="c25d7d3bfdb30a370f243f21de06750f15284f57346ad11a44f298d489540275"
readonly R26_EXPECTED_TEST_SHA="37fad0b3b123d248f6a52128f5f5d60559587cb8d291b6a6a6da1d615ad87967"
readonly R26_EXPECTED_R20_TEST_SHA="66c3b12ca56b1e42d2d4a591544531f2cf346150004603b5e8cf7b11a70daa26"
readonly R26_EXPECTED_RANCH_ART_MANIFEST_SHA="4f73a80e821faa64d0a29d797cc12e20d5f88248bbb186e74972af49798ddbab"
readonly R26_EXPECTED_MATRIX_ENTRY_SHA="75c12732327ec06a3b3a69d6ff928d7909c0e170fee37067210d16f575d91d5c"
readonly R26_EXPECTED_R23_FREEZE_SHA="9c791a1bab22026ed2930eb120b9c82923390d42fad61a78f53b40080c6cef9a"
readonly R26_EXPECTED_R23_REVIEW_SHA="13bd182b8701df2b83fa63c58e978b440ed55c75c0c4a6c3ac936116d411a8bc"
readonly R26_EXPECTED_R23_DRIVER_SHA="0d82a6cf04d4391117d0095bc3b7439f7402d965b45e4396fce50811f4ed4c6c"
readonly R26_EXPECTED_R23_MANIFEST_SHA="1776c5694ce8799258c5f4b37b623d230f3f37218d54817c25489c8dd63a4006"
readonly R26_EXPECTED_R23_REPORT_SHA="512e123bcd861043c3f57c08a364489f662582528ecd7f745f282ee9ab999c69"
readonly R26_EXPECTED_R23_BOUNDARY_SHA="4b17b1e7e8536fa88b7b41e68efc089f3b300dd801d42729a375fe2284cd5a78"
readonly R26_EXPECTED_R23_HASH_LOG_SHA="cdb9776b645f0db4b059d2c4e44a974da3788c565653741e1ff2635c22e3afeb"
readonly R26_EXPECTED_R23_VERIFY_SHA="c0f5fe79792c60eacfa266a12d53f79abdf3cea53d6e8c9e1f6bc42337100762"
readonly R26_EXPECTED_R24_FREEZE_SHA="f22a7ffd954ddf6d9b2d804a5f3be58807373c388634b9200d260f1a8eb66746"
readonly R26_EXPECTED_R24_REVIEW_SHA="a9ef2cab24afa65290f563b85ac03022b958d39253c025017d1c91b689926c0e"
readonly R26_EXPECTED_R24_DRIVER_SHA="1b224f442d1fdea856433d12141e5ea9f74190a380e554e4ec94872ba0b8655f"
readonly R26_EXPECTED_R24_MANIFEST_SHA="55a6c2e8a657166de8b983cd0edfb2a7b1ae1943dc291819c0c2ea417338a80c"
readonly R26_EXPECTED_R24_BOUNDARY_SHA="c3066bbce88a22a0ac7dfa860a6991a07adc90122a0be551d820681f671880fb"
readonly R26_EXPECTED_R24_HASH_LOG_SHA="7ff8f616c269f0450ca30e22d7fc03f5a527982bf301e111f9254acaf391b088"
readonly R26_EXPECTED_R24_VERIFY_SHA="1f2cfaa1b42d821404ce8f449445f29f1fa3d9cf745967883e89ff185c85f084"
readonly R26_EXPECTED_R24_TARGETED_SHA="b1565785c8eafc04e088503273c33bfad740d7285574aecf98596593559d571e"
readonly R26_EXPECTED_R24_BUILD_SHA="ad11175a810a70ae005aa30e51b441c210c0988abc6437516ae6c9638b251319"
readonly R26_EXPECTED_R24_MATRIX_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
readonly R26_EXPECTED_R24_BUNDLE_LOG_SHA="20a4f2764e97024eaa17da100925af7c870d092bfb5177279ceb05dfcfe80b8a"
readonly R26_EXPECTED_R24_SOURCE_LOG_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
readonly R26_EXPECTED_R24_BOOTSTRAP_LOG_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
readonly R26_EXPECTED_R24_COLD_START_LOG_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
readonly R26_EXPECTED_R24_APP_MANIFEST_SHA="1871d346bed8b7978f7456e2893218a97cad7b8dc643c84bba9cd87cb81c8b5e"
readonly R26_EXPECTED_R24_EXECUTABLE_SHA="0d01c0ee8b658cf68c5463ef70cc68756a69630a5986cf620ad3870097021b05"
readonly R26_EXPECTED_R24_INFO_PLIST_SHA="53bb6470fc12b39a5f48ac6d261415acff96cfbc57ffbf4721d3e351d2123277"
readonly R26_EXPECTED_R24_CODE_RESOURCES_SHA="4e903bc32534480c4fa8a17490e49c496e655f1827eafbed280d09fc0eb90ae4"
readonly R26_EXPECTED_R24_CDHASH="17bd20ada27ef9e69d0de007b49c53d01ddf48a6"
readonly R26_EXPECTED_R25_FREEZE_SHA="8e6d97aca80591f544b40a8b645c01f1c5624f0f120d5ac12cedf37b94ffbeca"
readonly R26_EXPECTED_R25_REVIEW_SHA="65b738e9c977e97ec6acdfbadad938d43ff97213c42e3b56297e67998dec237e"
readonly R26_EXPECTED_R25_DRIVER_SHA="1eee61d199c5bb1c5b0149989f17508e9a75eacfbc2bac3b1a2f0063f0ab68bb"
readonly R26_EXPECTED_R25_MANIFEST_SHA="462be6ff554b3d38bea76ac8351a77f780b575a1a9aeae4a461e42dd303655ba"
readonly R26_EXPECTED_R25_BOUNDARY_SHA="2d1dabc7872b31b7d330700c0979857563af84491ff39391b3bf9279ff50c0d4"
readonly R26_EXPECTED_R25_HASH_LOG_SHA="bba9e1ffd51e2f8fb066d00226fc18f9e4f66b9c32f1917129522b471706564a"
readonly R26_EXPECTED_R25_VERIFY_SHA="9a0d772ac0f36cf56b2340c741d237dfbc2a4a6a9ecd4314bb5b95319f7b8b5f"
readonly R26_EXPECTED_R25_TARGETED_SHA="538cf3ff68d95318ab7da9dc7a685648f4c7651668ca0c6fcf4dc35c8a48e532"
readonly R26_EXPECTED_R25_BUILD_SHA="cc50f7f484bb397052dae2be64307361e99255fd27169648cb4ac36aa75dd703"
readonly R26_EXPECTED_R25_MATRIX_SHA="7c0e55705520fe79281e7a38b409177515f00fedc89eb8c8bf68fc0f4f74dca9"
readonly R26_EXPECTED_R25_BUNDLE_LOG_SHA="5bdfdad577d4f9c0c029463c59cf442b83122939f76e59c435e89371e682e3d5"
readonly R26_EXPECTED_R25_SOURCE_LOG_SHA="8d995eeb44fbccd42d9f83a0b64088d35f326ac8dd0051198327320ca2f0466f"
readonly R26_EXPECTED_R25_BOOTSTRAP_LOG_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
readonly R26_EXPECTED_R25_COLD_START_LOG_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
readonly R26_EXPECTED_EMPTY_SHA="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

readonly R26_R23_FREEZE_PATH="${R26_TASK_DIRECTORY}/evidence/plan-freeze-r23.md"
readonly R26_R23_REVIEW_PATH="${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/23-p1-plan-review.md"
readonly R26_R23_DRIVER_PATH="${R26_TASK_DIRECTORY}/evidence/r23-begin.sh"
readonly R26_R23_MANIFEST_PATH="${R26_TASK_DIRECTORY}/evidence/r23-entry.sha256"
readonly R26_R23_REPORT_PATH="${R26_TASK_DIRECTORY}/impl-report-r23.md"
readonly R26_R23_BOUNDARY_PATH="${R26_TASK_DIRECTORY}/evidence/r23-clean-boundary.log"
readonly R26_R23_HASH_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r23-hash-manifest.log"
readonly R26_R23_VERIFY_PATH="${R26_TASK_DIRECTORY}/r23-verify.log"
readonly R26_R23_SCREENSHOT_PATH="${R26_TASK_DIRECTORY}/evidence/r23-preview-smoke.png"
readonly R26_R23_STATE_ROOT="/private/tmp/agentloop-r23-state.GsQHd1"
readonly R26_R23_BUNDLE_ROOT="/private/tmp/agentloop-r23-bundle.PuKOJy"
readonly R26_R23_PLANNED_APP="${R26_R23_BUNDLE_ROOT}/AgentLoop.app"
readonly R26_R23_PLANNED_EXECUTABLE="${R26_R23_PLANNED_APP}/Contents/MacOS/AgentLoop"
readonly R26_R23_BASELINE_MASK="11"

readonly R26_R24_FREEZE_PATH="${R26_TASK_DIRECTORY}/evidence/plan-freeze-r24.md"
readonly R26_R24_REVIEW_PATH="${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/24-p1-plan-review.md"
readonly R26_R24_DRIVER_PATH="${R26_TASK_DIRECTORY}/evidence/r24-begin.sh"
readonly R26_R24_MANIFEST_PATH="${R26_TASK_DIRECTORY}/evidence/r24-entry.sha256"
readonly R26_R24_BOUNDARY_PATH="${R26_TASK_DIRECTORY}/evidence/r24-clean-boundary.log"
readonly R26_R24_HASH_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r24-hash-manifest.log"
readonly R26_R24_VERIFY_PATH="${R26_TASK_DIRECTORY}/r24-verify.log"
readonly R26_R24_TARGETED_PATH="${R26_TASK_DIRECTORY}/r24-targeted-tests.log"
readonly R26_R24_BUILD_PATH="${R26_TASK_DIRECTORY}/r24-build.log"
readonly R26_R24_MATRIX_PATH="${R26_TASK_DIRECTORY}/r24-migration-matrix.log"
readonly R26_R24_BUNDLE_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r24-bundle-provenance.log"
readonly R26_R24_SOURCE_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r24-source-gates.log"
readonly R26_R24_BOOTSTRAP_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r24-preview-bootstrap.log"
readonly R26_R24_COLD_START_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r24-preview-cold-start.log"
readonly R26_R24_REPORT_PATH="${R26_TASK_DIRECTORY}/impl-report-r24.md"
readonly R26_R24_SCREENSHOT_PATH="${R26_TASK_DIRECTORY}/evidence/r24-preview-smoke.png"
readonly R26_R24_STATE_ROOT="/private/tmp/agentloop-r24-state.Qko2Y3"
readonly R26_R24_BUNDLE_ROOT="/private/tmp/agentloop-r24-bundle.OPfuVv"
readonly R26_R24_APP="${R26_R24_BUNDLE_ROOT}/AgentLoop.app"
readonly R26_R24_EXECUTABLE="${R26_R24_APP}/Contents/MacOS/AgentLoop"
readonly R26_R24_INFO_PLIST="${R26_R24_APP}/Contents/Info.plist"
readonly R26_R24_CODE_RESOURCES="${R26_R24_APP}/Contents/_CodeSignature/CodeResources"
readonly R26_R24_BASELINE_MASK="111111111111111111111111111111111111111"

readonly R26_R25_FREEZE_PATH="${R26_TASK_DIRECTORY}/evidence/plan-freeze-r25.md"
readonly R26_R25_REVIEW_PATH="${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/reviews/25-p1-plan-review.md"
readonly R26_R25_DRIVER_PATH="${R26_TASK_DIRECTORY}/evidence/r25-begin.sh"
readonly R26_R25_MANIFEST_PATH="${R26_TASK_DIRECTORY}/evidence/r25-entry.sha256"
readonly R26_R25_BOUNDARY_PATH="${R26_TASK_DIRECTORY}/evidence/r25-clean-boundary.log"
readonly R26_R25_HASH_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r25-hash-manifest.log"
readonly R26_R25_VERIFY_PATH="${R26_TASK_DIRECTORY}/r25-verify.log"
readonly R26_R25_TARGETED_PATH="${R26_TASK_DIRECTORY}/r25-targeted-tests.log"
readonly R26_R25_BUILD_PATH="${R26_TASK_DIRECTORY}/r25-build.log"
readonly R26_R25_MATRIX_PATH="${R26_TASK_DIRECTORY}/r25-migration-matrix.log"
readonly R26_R25_BUNDLE_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r25-bundle-provenance.log"
readonly R26_R25_SOURCE_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r25-source-gates.log"
readonly R26_R25_BOOTSTRAP_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r25-preview-bootstrap.log"
readonly R26_R25_COLD_START_LOG_PATH="${R26_TASK_DIRECTORY}/evidence/r25-preview-cold-start.log"
readonly R26_R25_REPORT_PATH="${R26_TASK_DIRECTORY}/impl-report-r25.md"
readonly R26_R25_SCREENSHOT_PATH="${R26_TASK_DIRECTORY}/evidence/r25-preview-smoke.png"
readonly R26_R25_STATE_ROOT="/private/tmp/agentloop-r25-state.fs7Cz2"
readonly R26_R25_BUNDLE_ROOT="/private/tmp/agentloop-r25-bundle.Ozi6d3"
readonly R26_R25_BASELINE_MASK="11"

readonly R26_R15_STATE_ROOT="/private/tmp/agentloop-r15-state.Zq6Jvm"
readonly R26_R15_BUNDLE_ROOT="/private/tmp/agentloop-r15-bundle.2xROcy"

readonly R26_R19_STATE_ROOT="/private/tmp/agentloop-r19-state.dNgUXh"
readonly R26_R19_BUNDLE_ROOT="/private/tmp/agentloop-r19-bundle.49xVDm"
readonly R26_R20_STATE_ROOT="/private/tmp/agentloop-r20-state.3QwlQa"
readonly R26_R20_BUNDLE_ROOT="/private/tmp/agentloop-r20-bundle.30V5RH"
readonly R26_R20_APP="${R26_R20_BUNDLE_ROOT}/AgentLoop.app"
readonly R26_R20_BASELINE_MASK="11101011100000000000000000000000000010"
readonly R26_R20_CONTENTS="${R26_R20_APP}/Contents"
readonly R26_R20_MACOS="${R26_R20_CONTENTS}/MacOS"
readonly R26_R20_RESOURCES="${R26_R20_CONTENTS}/Resources"
readonly R26_R20_RESOURCE_BUNDLE="${R26_R20_RESOURCES}/AgentLoop_AgentLoopApp.bundle"
readonly R26_R20_RANCH_ART="${R26_R20_RESOURCE_BUNDLE}/RanchArt"
readonly R26_R20_CODE_SIGNATURE="${R26_R20_CONTENTS}/_CodeSignature"

readonly R26_CORE_PATH="${R26_REPOSITORY_ROOT}/Sources/AgentLoopCore/Loop/AgentLoop.swift"
readonly R26_TEST_PATH="${R26_REPOSITORY_ROOT}/Sources/AgentLoopTestSuite/AgentLoopTests.swift"
readonly R26_MATRIX_SCRIPT="${R26_REPOSITORY_ROOT}/scripts/verify-p1-migrations-sqlite-matrix.sh"
readonly R26_STAGE_PATH="${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"
readonly R26_RANCH_ART_DIRECTORY="${R26_REPOSITORY_ROOT}/Sources/AgentLoopApp/Resources/RanchArt"
readonly R26_BUILD_LOG="${R26_TASK_DIRECTORY}/r26-build.log"
readonly R26_TARGETED_LOG="${R26_TASK_DIRECTORY}/r26-targeted-tests.log"
readonly R26_MATRIX_LOG="${R26_TASK_DIRECTORY}/r26-migration-matrix.log"
readonly R26_BUNDLE_LOG="${R26_TASK_DIRECTORY}/evidence/r26-bundle-provenance.log"
readonly R26_SOURCE_LOG="${R26_TASK_DIRECTORY}/evidence/r26-source-gates.log"
readonly R26_BOOTSTRAP_LOG="${R26_TASK_DIRECTORY}/evidence/r26-preview-bootstrap.log"
readonly R26_COLD_START_LOG="${R26_TASK_DIRECTORY}/evidence/r26-preview-cold-start.log"
readonly R26_SCREENSHOT="${R26_TASK_DIRECTORY}/evidence/r26-preview-smoke.png"
readonly R26_IMPL_REPORT="${R26_TASK_DIRECTORY}/impl-report-r26.md"

R26_BOUNDARY_ACTIVE="false"
R26_PHASE="pre_begin"
R26_INVOCATION_ID=""
R26_STATE_ROOT=""
R26_BUNDLE_ROOT=""
R26_R23_FIRST_MASK=""
R26_R23_LATEST_MASK="${R26_R23_BASELINE_MASK}"
R26_R23_ACCEPTED_MODE_B=""
R26_R24_FIRST_MASK=""
R26_R24_LATEST_MASK="${R26_R24_BASELINE_MASK}"
R26_R24_ACCEPTED_MODE_B=""
R26_R25_FIRST_MASK=""
R26_R25_LATEST_MASK="${R26_R25_BASELINE_MASK}"
R26_R25_ACCEPTED_MODE_B=""
R26_R20_FIRST_MASK=""
R26_R20_LATEST_MASK="${R26_R20_BASELINE_MASK}"
R26_R20_ACCEPTED_MODE_B=""
R26_AUTHORITATIVE_SWIFT_RC="UNKNOWN"
R26_AUTHORITATIVE_TEE_RC="UNKNOWN"
R26_AUTHORITATIVE_STATUS_CAPTURED="false"
R26_VERIFY_LOG_SHA="UNKNOWN"
R26_VERIFY_LOG_BYTES="UNKNOWN"
R26_DEFERRED_SIGNAL=""
R26_DEFERRED_SIGNAL_STATUS=""
R26_MATRIX_MUTATED="false"
R26_MATRIX_ENTRY_BYTES=""
R26_MATRIX_ENTRY_SHA=""
R26_MATRIX_BACKUP_PATH=""
R26_MATRIX_MUTATED_STAGE=""
R26_MATRIX_RESTORE_STAGE=""
R26_MATRIX_BACKUP_OWNED="false"
R26_MATRIX_MUTATED_STAGE_OWNED="false"
R26_MATRIX_RESTORE_STAGE_OWNED="false"
R26_APP=""
R26_APP_EXECUTABLE=""
R26_BUILD_EXECUTABLE=""
R26_BUILD_RESOURCE_BUNDLE=""
R26_BUILD_EXECUTABLE_SHA=""
R26_BUILD_UUID_SET=""
R26_SIGNED_EXECUTABLE_SHA=""
R26_SIGNED_BUNDLE_MANIFEST_SHA=""
R26_SIGNED_UUID_SET=""
R26_INFO_PLIST_SHA=""
R26_SIGNED_CDHASH=""
R26_APP_PID=""
R26_APP_CHILDREN=""
R26_APP_PPID=""
R26_APP_DIRECT_CHILD_OWNED="false"
R26_APP_IDENTITY_COMMITTED="false"
R26_BOOTSTRAP_PID=""
R26_BOOTSTRAP_BIRTH=""
R26_BOOTSTRAP_NONCE=""
R26_COLD_START_NONCE=""
R26_PREVIEW_CAMP_ID=""
R26_CURRENT_ROOT_PHASE="uncreated"
R26_BUNDLE_IDENTIFIER=""
R26_APP_BIRTH=""
R26_SCREENSHOT_SHA=""
R26_SCREENSHOT_BYTES=""
R26_SCREENSHOT_WIDTH=""
R26_SCREENSHOT_HEIGHT=""
R26_SCREENSHOT_STAGE=""
R26_SCREENSHOT_STAGE_OWNED="false"
R26_PREVIEW_CONTAINMENT_RC="0"
R26_PREVIEW_CONTAINMENT_WAIT_RC="NOT_WAITED"
R26_PREVIEW_CONTAINMENT_COMMAND_MATCH="NOT_OBSERVED"
R26_PREVIEW_CONTAINMENT_PPID_MATCH="NOT_OBSERVED"
R26_PREVIEW_CONTAINMENT_BIRTH_MATCH="NOT_OBSERVED"
R26_PREVIEW_CONTAINMENT_AUTH_RC="NOT_ATTEMPTED"
R26_CU_RAW_PATH=""
R26_CU_RAW_ENCODING=""
R26_CU_RAW_BYTES=""
R26_CU_RAW_SHA=""
R26_IMPL_REPORT_STAGE=""
R26_IMPL_REPORT_STAGE_SHA=""
R26_IMPL_REPORT_STAGE_OWNED="false"
R26_IMPL_REPORT_PUBLISHED="false"
R26_END_COMMITTED="false"
R26_CORE_GUARD_SHAPE=""
R26_TEST_GUARD_SHAPE=""

r26_now() {
  /bin/date -u '+%Y-%m-%dT%H:%M:%SZ'
}

r26_capture_now() {
  local r26_captured_now=""
  if r26_captured_now="$(r26_now)"; then
    :
  else
    return "$?"
  fi
  [[ -n "${r26_captured_now}" && "${r26_captured_now}" != *$'\n'* ]] || return 70
  /usr/bin/printf '%s\n' "${r26_captured_now}"
}

r26_sha() {
  local r26_sha_line=""
  if r26_sha_line="$(/usr/bin/shasum -a 256 "$1")"; then
    /usr/bin/printf '%s\n' "${r26_sha_line%% *}"
  else
    return "$?"
  fi
}

r26_canonical_directory() {
  local r26_directory="$1"
  (
    cd -P "${r26_directory}"
    pwd -P
  )
}

r26_canonical_file() {
  local r26_file="$1"
  local r26_parent=""
  local r26_parent_real=""
  local r26_name=""
  r26_parent="${r26_file%/*}"
  r26_name="${r26_file##*/}"
  [[ -n "${r26_parent}" && -n "${r26_name}" ]] || return 70
  if r26_parent_real="$(r26_canonical_directory "${r26_parent}")"; then
    :
  else
    return "$?"
  fi
  /usr/bin/printf '%s/%s\n' "${r26_parent_real}" "${r26_name}"
}

r26_require_sha_literal() {
  local r26_name="$1"
  local r26_value="$2"
  [[ "${#r26_value}" == "64" ]] || r26_fail 70 "sha_literal_length_${r26_name}_${#r26_value}"
  case "${r26_value}" in
    *[!0-9a-f]*) r26_fail 70 "sha_literal_format_${r26_name}" ;;
  esac
}

r26_require_sha_constant_shapes() {
  local r26_pair=""
  local r26_name=""
  local r26_value=""
  for r26_pair in \
    "expected_core=${R26_EXPECTED_CORE_SHA}" \
    "expected_test=${R26_EXPECTED_TEST_SHA}" \
    "expected_r20_test=${R26_EXPECTED_R20_TEST_SHA}" \
    "expected_ranch_art=${R26_EXPECTED_RANCH_ART_MANIFEST_SHA}" \
    "expected_matrix_entry=${R26_EXPECTED_MATRIX_ENTRY_SHA}" \
    "r23_freeze=${R26_EXPECTED_R23_FREEZE_SHA}" \
    "r23_review=${R26_EXPECTED_R23_REVIEW_SHA}" \
    "r23_driver=${R26_EXPECTED_R23_DRIVER_SHA}" \
    "r23_manifest=${R26_EXPECTED_R23_MANIFEST_SHA}" \
    "r23_report=${R26_EXPECTED_R23_REPORT_SHA}" \
    "r23_boundary=${R26_EXPECTED_R23_BOUNDARY_SHA}" \
    "r23_hash_log=${R26_EXPECTED_R23_HASH_LOG_SHA}" \
    "r23_verify=${R26_EXPECTED_R23_VERIFY_SHA}" \
    "r24_freeze=${R26_EXPECTED_R24_FREEZE_SHA}" \
    "r24_review=${R26_EXPECTED_R24_REVIEW_SHA}" \
    "r24_driver=${R26_EXPECTED_R24_DRIVER_SHA}" \
    "r24_manifest=${R26_EXPECTED_R24_MANIFEST_SHA}" \
    "r24_boundary=${R26_EXPECTED_R24_BOUNDARY_SHA}" \
    "r24_hash_log=${R26_EXPECTED_R24_HASH_LOG_SHA}" \
    "r24_verify=${R26_EXPECTED_R24_VERIFY_SHA}" \
    "r24_targeted=${R26_EXPECTED_R24_TARGETED_SHA}" \
    "r24_build=${R26_EXPECTED_R24_BUILD_SHA}" \
    "r24_matrix=${R26_EXPECTED_R24_MATRIX_SHA}" \
    "r24_bundle_log=${R26_EXPECTED_R24_BUNDLE_LOG_SHA}" \
    "r24_source_log=${R26_EXPECTED_R24_SOURCE_LOG_SHA}" \
    "r24_bootstrap_log=${R26_EXPECTED_R24_BOOTSTRAP_LOG_SHA}" \
    "r24_cold_start_log=${R26_EXPECTED_R24_COLD_START_LOG_SHA}" \
    "r24_app_manifest=${R26_EXPECTED_R24_APP_MANIFEST_SHA}" \
    "r24_executable=${R26_EXPECTED_R24_EXECUTABLE_SHA}" \
    "r24_info_plist=${R26_EXPECTED_R24_INFO_PLIST_SHA}" \
    "r24_code_resources=${R26_EXPECTED_R24_CODE_RESOURCES_SHA}" \
    "r25_freeze=${R26_EXPECTED_R25_FREEZE_SHA}" \
    "r25_review=${R26_EXPECTED_R25_REVIEW_SHA}" \
    "r25_driver=${R26_EXPECTED_R25_DRIVER_SHA}" \
    "r25_manifest=${R26_EXPECTED_R25_MANIFEST_SHA}" \
    "r25_boundary=${R26_EXPECTED_R25_BOUNDARY_SHA}" \
    "r25_hash_log=${R26_EXPECTED_R25_HASH_LOG_SHA}" \
    "r25_verify=${R26_EXPECTED_R25_VERIFY_SHA}" \
    "r25_targeted=${R26_EXPECTED_R25_TARGETED_SHA}" \
    "r25_build=${R26_EXPECTED_R25_BUILD_SHA}" \
    "r25_matrix=${R26_EXPECTED_R25_MATRIX_SHA}" \
    "r25_bundle_log=${R26_EXPECTED_R25_BUNDLE_LOG_SHA}" \
    "r25_source_log=${R26_EXPECTED_R25_SOURCE_LOG_SHA}" \
    "r25_bootstrap_log=${R26_EXPECTED_R25_BOOTSTRAP_LOG_SHA}" \
    "r25_cold_start_log=${R26_EXPECTED_R25_COLD_START_LOG_SHA}" \
    "empty=${R26_EXPECTED_EMPTY_SHA}"; do
    r26_name="${r26_pair%%=*}"
    r26_value="${r26_pair#*=}"
    r26_require_sha_literal "${r26_name}" "${r26_value}"
  done
  [[ "${#R26_R24_BASELINE_MASK}" == "39" && "${R26_R24_BASELINE_MASK}" != *[!01]* ]] || r26_fail 70 "r24_baseline_mask_shape"
  [[ "${R26_R25_BASELINE_MASK}" == "11" ]] || r26_fail 70 "r25_baseline_mask_shape"
  [[ "${#R26_EXPECTED_R24_CDHASH}" == "40" && "${R26_EXPECTED_R24_CDHASH}" != *[!0-9a-f]* ]] || r26_fail 70 "r24_cdhash_shape"
}

r26_require_canonical_entry_paths() {
  local r26_initial_cwd=""
  local r26_repo_real=""
  local r26_driver_parent_real=""
  local r26_driver_real=""
  if r26_initial_cwd="$(pwd -P)"; then :; else r26_fail 70 "entry_pwd_failed"; fi
  [[ "${r26_initial_cwd}" == "${R26_REPOSITORY_ROOT}" ]] || r26_fail 70 "entry_cwd_mismatch_${r26_initial_cwd}"
  [[ -d "${R26_REPOSITORY_ROOT}" && ! -L "${R26_REPOSITORY_ROOT}" ]] || r26_fail 70 "repository_root_not_real_directory"
  if r26_repo_real="$(r26_canonical_directory "${R26_REPOSITORY_ROOT}")"; then :; else r26_fail 70 "repository_root_canonicalization_failed"; fi
  [[ "${r26_repo_real}" == "${R26_REPOSITORY_ROOT}" ]] || r26_fail 70 "repository_root_canonical_mismatch_${r26_repo_real}"
  [[ -d "${R26_TASK_DIRECTORY}/evidence" && ! -L "${R26_TASK_DIRECTORY}/evidence" ]] || r26_fail 70 "driver_parent_not_real_directory"
  if r26_driver_parent_real="$(r26_canonical_directory "${R26_TASK_DIRECTORY}/evidence")"; then :; else r26_fail 70 "driver_parent_canonicalization_failed"; fi
  [[ "${r26_driver_parent_real}" == "${R26_TASK_DIRECTORY}/evidence" ]] || r26_fail 70 "driver_parent_canonical_mismatch_${r26_driver_parent_real}"
  r26_require_regular_file "${R26_DRIVER_PATH}"
  if r26_driver_real="$(r26_canonical_file "${R26_DRIVER_PATH}")"; then :; else r26_fail 70 "driver_canonicalization_failed"; fi
  [[ "${r26_driver_real}" == "${R26_DRIVER_PATH}" ]] || r26_fail 70 "driver_canonical_mismatch_${r26_driver_real}"
  [[ "$0" == "${R26_DRIVER_PATH}" ]] || r26_fail 70 "driver_argv0_not_canonical_$0"
  [[ "${BASH_SOURCE[0]}" == "${R26_DRIVER_PATH}" ]] || r26_fail 70 "driver_BASH_SOURCE_not_canonical_${BASH_SOURCE[0]}"
}

r26_require_private_tmp() {
  local r26_private_tmp=""
  [[ -d /private/tmp && ! -L /private/tmp ]] || r26_fail 70 "private_tmp_not_real_directory"
  if r26_private_tmp="$(r26_canonical_directory /private/tmp)"; then :; else r26_fail 70 "private_tmp_canonicalization_failed"; fi
  [[ "${r26_private_tmp}" == "/private/tmp" ]] || r26_fail 70 "private_tmp_canonical_mismatch_${r26_private_tmp}"
}

r26_pre_begin_fail() {
  local r26_status="$1"
  shift
  /usr/bin/printf 'R26 pre-BEGIN failure: %s\n' "$*" >&2
  exit "${r26_status}"
}

r26_append_boundary() {
  /usr/bin/printf '%s\n' "$*" >> "${R26_BOUNDARY_LOG}"
}

r26_restore_matrix_containment() {
  local r26_restored_sha=""
  local r26_restore_mode=""
  [[ "${R26_MATRIX_MUTATED}" == "true" ]] || return 0
  [[ "${R26_MATRIX_BACKUP_OWNED}" == "true" ]] || return 90
  [[ -n "${R26_MATRIX_BACKUP_PATH}" && -f "${R26_MATRIX_BACKUP_PATH}" && ! -L "${R26_MATRIX_BACKUP_PATH}" ]] || return 91
  [[ -n "${R26_MATRIX_RESTORE_STAGE}" ]] || return 92
  if [[ "${R26_MATRIX_RESTORE_STAGE_OWNED}" == "true" ]]; then
    r26_remove_exact_matrix_stage "${R26_MATRIX_RESTORE_STAGE}" || return 93
  fi
  r26_exclusive_create_empty "${R26_MATRIX_RESTORE_STAGE}" || return 93
  R26_MATRIX_RESTORE_STAGE_OWNED="true"
  /bin/cp -p "${R26_MATRIX_BACKUP_PATH}" "${R26_MATRIX_RESTORE_STAGE}" || return 94
  [[ -f "${R26_MATRIX_RESTORE_STAGE}" && ! -L "${R26_MATRIX_RESTORE_STAGE}" ]] || return 95
  r26_restored_sha="$(r26_sha "${R26_MATRIX_RESTORE_STAGE}")" || return 96
  [[ "${r26_restored_sha}" == "${R26_EXPECTED_MATRIX_ENTRY_SHA}" ]] || return 97
  r26_restore_mode="$(/usr/bin/stat -f '%Lp' "${R26_MATRIX_RESTORE_STAGE}")" || return 98
  [[ "${r26_restore_mode}" == "755" ]] || return 99
  /bin/mv -f "${R26_MATRIX_RESTORE_STAGE}" "${R26_MATRIX_SCRIPT}" || return 100
  R26_MATRIX_RESTORE_STAGE_OWNED="false"
  [[ -f "${R26_MATRIX_SCRIPT}" && ! -L "${R26_MATRIX_SCRIPT}" ]] || return 101
  r26_restored_sha="$(r26_sha "${R26_MATRIX_SCRIPT}")" || return 102
  [[ "${r26_restored_sha}" == "${R26_EXPECTED_MATRIX_ENTRY_SHA}" ]] || return 103
  r26_restore_mode="$(/usr/bin/stat -f '%Lp' "${R26_MATRIX_SCRIPT}")" || return 104
  [[ "${r26_restore_mode}" == "755" ]] || return 105
  R26_MATRIX_MUTATED="false"
  [[ "${R26_MATRIX_BACKUP_OWNED}" == "true" ]] || return 106
  /bin/rm -f "${R26_MATRIX_BACKUP_PATH}" || return 106
  [[ ! -e "${R26_MATRIX_BACKUP_PATH}" && ! -L "${R26_MATRIX_BACKUP_PATH}" ]] || return 107
  R26_MATRIX_BACKUP_OWNED="false"
  return 0
}

r26_remove_exact_matrix_stage() {
  local r26_stage="$1"
  local r26_kind=""
  [[ -n "${r26_stage}" ]] || return 0
  case "${r26_stage}" in
    "${R26_REPOSITORY_ROOT}/scripts/.${R26_INVOCATION_ID}.matrix-mutated.stage")
      r26_kind="mutated"
      [[ "${R26_MATRIX_MUTATED_STAGE_OWNED}" == "true" ]] || return 0
      ;;
    "${R26_REPOSITORY_ROOT}/scripts/.${R26_INVOCATION_ID}.matrix-restore.stage")
      r26_kind="restore"
      [[ "${R26_MATRIX_RESTORE_STAGE_OWNED}" == "true" ]] || return 0
      ;;
    *) return 111 ;;
  esac
  if [[ -e "${r26_stage}" || -L "${r26_stage}" ]]; then
    [[ -f "${r26_stage}" && ! -L "${r26_stage}" ]] || return 112
    /bin/rm -f "${r26_stage}" || return 113
  fi
  [[ ! -e "${r26_stage}" && ! -L "${r26_stage}" ]] || return 114
  if [[ "${r26_kind}" == "mutated" ]]; then
    R26_MATRIX_MUTATED_STAGE_OWNED="false"
  else
    R26_MATRIX_RESTORE_STAGE_OWNED="false"
  fi
}

r26_contain_matrix_owned_paths() {
  local r26_live_sha=""
  r26_remove_exact_matrix_stage "${R26_MATRIX_MUTATED_STAGE}" || return "$?"
  r26_remove_exact_matrix_stage "${R26_MATRIX_RESTORE_STAGE}" || return "$?"
  if [[ "${R26_MATRIX_BACKUP_OWNED}" == "true" ]]; then
    [[ "${R26_MATRIX_BACKUP_PATH}" == "${R26_STATE_ROOT}/r26-matrix-entry.backup" ]] || return 115
    if [[ -e "${R26_MATRIX_BACKUP_PATH}" || -L "${R26_MATRIX_BACKUP_PATH}" ]]; then
      [[ -f "${R26_MATRIX_BACKUP_PATH}" && ! -L "${R26_MATRIX_BACKUP_PATH}" ]] || return 116
    fi
    r26_live_sha="$(r26_sha "${R26_MATRIX_SCRIPT}")" || return 117
    if [[ "${r26_live_sha}" == "${R26_EXPECTED_MATRIX_ENTRY_SHA}" ]]; then
      if [[ -e "${R26_MATRIX_BACKUP_PATH}" || -L "${R26_MATRIX_BACKUP_PATH}" ]]; then
        /bin/rm -f "${R26_MATRIX_BACKUP_PATH}" || return 118
      fi
      [[ ! -e "${R26_MATRIX_BACKUP_PATH}" && ! -L "${R26_MATRIX_BACKUP_PATH}" ]] || return 119
      R26_MATRIX_BACKUP_OWNED="false"
    fi
  fi
  return 0
}

r26_contain_screenshot_stage() {
  [[ -n "${R26_SCREENSHOT_STAGE}" ]] || return 0
  [[ "${R26_SCREENSHOT_STAGE_OWNED}" == "true" ]] || return 0
  [[ "${R26_SCREENSHOT_STAGE}" == "${R26_TASK_DIRECTORY}/evidence/.${R26_INVOCATION_ID}.r26-preview-smoke.stage.png" ]] || return 120
  if [[ -e "${R26_SCREENSHOT_STAGE}" || -L "${R26_SCREENSHOT_STAGE}" ]]; then
    [[ -f "${R26_SCREENSHOT_STAGE}" && ! -L "${R26_SCREENSHOT_STAGE}" ]] || return 121
    /bin/rm -f "${R26_SCREENSHOT_STAGE}" || return 122
  fi
  [[ ! -e "${R26_SCREENSHOT_STAGE}" && ! -L "${R26_SCREENSHOT_STAGE}" ]] || return 123
  R26_SCREENSHOT_STAGE_OWNED="false"
  return 0
}

# Reset identity only after the direct child has been reaped.
r26_clear_owned_preview_identity() {
  R26_APP_PID=""
  R26_APP_PPID=""
  R26_APP_BIRTH=""
  R26_APP_DIRECT_CHILD_OWNED="false"
  R26_APP_IDENTITY_COMMITTED="false"
}

# Count the exact PID in one numeric Bash job-list snapshot.
r26_job_list_exact_pid_count() {
  local r26_list="$1"
  local r26_line=""
  local r26_count=0
  while IFS= read -r r26_line; do
    [[ -n "${r26_line}" ]] || continue
    case "${r26_line}" in *[!0-9]*) return 2 ;; esac
    if [[ "${r26_line}" == "${R26_APP_PID}" ]]; then
      r26_count=$((r26_count + 1))
    fi
  done <<< "${r26_list}"
  [[ "${r26_count}" -le 1 ]] || return 2
  /usr/bin/printf '%s\n' "${r26_count}"
}

# Return 0 only after two stable snapshots place the exact PID in precisely
# one Bash running/stopped set, 1 only after two stable snapshots place it in
# neither set, and 2 for transition/indeterminate output.  Done/Exit jobs are
# deliberately excluded by -r/-s before cached wait is consumed.
r26_preview_active_job_exact() {
  local r26_running=""
  local r26_stopped=""
  local r26_running_count=""
  local r26_stopped_count=""
  local r26_state=""
  local r26_previous_state=""
  local r26_index=0
  while (( r26_index < 20 )); do
    if r26_running="$(jobs -pr)" && r26_stopped="$(jobs -ps)"; then :; else return 2; fi
    if r26_running_count="$(r26_job_list_exact_pid_count "${r26_running}")"; then :; else return 2; fi
    if r26_stopped_count="$(r26_job_list_exact_pid_count "${r26_stopped}")"; then :; else return 2; fi
    case "${r26_running_count}:${r26_stopped_count}" in
      1:0) r26_state="RUNNING" ;;
      0:1) r26_state="STOPPED" ;;
      0:0) r26_state="ABSENT" ;;
      *) r26_state="TRANSITION" ;;
    esac
    if [[ "${r26_state}" != "TRANSITION" && "${r26_state}" == "${r26_previous_state}" ]]; then
      [[ "${r26_state}" == "ABSENT" ]] && return 1
      return 0
    fi
    r26_previous_state="${r26_state}"
    /bin/sleep 0.01
    r26_index=$((r26_index + 1))
  done
  return 2
}

# Consume Bash's cached status only after stable running/stopped snapshots
# prove the child is no longer active. No kill -0 probe is used because an OS
# PID may already have been reused after Bash reaps the child.
r26_wait_cached_preview_child() {
  local r26_job_rc=0
  local r26_wait_rc=0
  [[ "${R26_APP_DIRECT_CHILD_OWNED}" == "true" ]] || return 126
  if r26_preview_active_job_exact; then
    return 1
  else
    r26_job_rc="$?"
  fi
  [[ "${r26_job_rc}" == "1" ]] || return 128
  if wait "${R26_APP_PID}" 2>/dev/null; then
    r26_wait_rc=0
  else
    r26_wait_rc="$?"
  fi
  R26_PREVIEW_CONTAINMENT_WAIT_RC="${r26_wait_rc}"
  r26_clear_owned_preview_identity
  [[ "${r26_wait_rc}" != "127" ]] || return 127
  return 0
}

# Refresh the job-table, PPID, and (once committed) birth token immediately
# before each signal.  Command identity remains diagnostic because a direct
# launch may still be in its fork-to-exec window.
r26_authorize_preview_signal() {
  local r26_job_rc=0
  local r26_command=""
  local r26_birth=""
  local r26_ppid=""
  R26_PREVIEW_CONTAINMENT_COMMAND_MATCH="READ_FAILED"
  R26_PREVIEW_CONTAINMENT_PPID_MATCH="READ_FAILED"
  R26_PREVIEW_CONTAINMENT_BIRTH_MATCH="READ_FAILED"
  if r26_preview_active_job_exact; then
    :
  else
    r26_job_rc="$?"
    return $((130 + r26_job_rc))
  fi
  if r26_ppid="$(/bin/ps -p "${R26_APP_PID}" -o ppid= 2>/dev/null)"; then :; else return 133; fi
  r26_ppid="${r26_ppid// /}"
  r26_ppid="${r26_ppid//$'\t'/}"
  if [[ "${r26_ppid}" == "$$" ]]; then
    R26_PREVIEW_CONTAINMENT_PPID_MATCH="true"
  else
    R26_PREVIEW_CONTAINMENT_PPID_MATCH="false_${r26_ppid}"
    return 134
  fi
  if r26_command="$(/bin/ps -ww -p "${R26_APP_PID}" -o command= 2>/dev/null)"; then
    if [[ "${r26_command}" == "${R26_APP_EXECUTABLE}" ]]; then
      R26_PREVIEW_CONTAINMENT_COMMAND_MATCH="true"
    else
      R26_PREVIEW_CONTAINMENT_COMMAND_MATCH="false_preexec_or_drift"
    fi
  fi
  if [[ "${R26_APP_IDENTITY_COMMITTED}" == "true" ]]; then
    [[ -n "${R26_APP_BIRTH}" ]] || return 135
    if r26_birth="$(/bin/ps -p "${R26_APP_PID}" -o lstart= 2>/dev/null)"; then :; else return 136; fi
    if [[ "${r26_birth}" == "${R26_APP_BIRTH}" ]]; then
      R26_PREVIEW_CONTAINMENT_BIRTH_MATCH="true"
    else
      R26_PREVIEW_CONTAINMENT_BIRTH_MATCH="false"
      return 137
    fi
  else
    R26_PREVIEW_CONTAINMENT_BIRTH_MATCH="not_committed"
  fi
  R26_PREVIEW_CONTAINMENT_AUTH_RC="0"
  return 0
}

r26_contain_preview_process() {
  local r26_job_rc=0
  local r26_authorize_rc=0
  local r26_index=0
  [[ -n "${R26_APP_PID}" ]] || {
    [[ "${R26_APP_DIRECT_CHILD_OWNED}" == "false" ]] || return 120
    return 0
  }
  case "${R26_APP_PID}" in ''|*[!0-9]*) return 121 ;; esac
  [[ "${R26_APP_DIRECT_CHILD_OWNED}" == "true" ]] || return 122

  if r26_preview_active_job_exact; then
    :
  else
    r26_job_rc="$?"
    if [[ "${r26_job_rc}" == "1" ]]; then
      r26_wait_cached_preview_child
      return "$?"
    fi
    return 123
  fi
  if r26_authorize_preview_signal; then
    :
  else
    r26_authorize_rc="$?"
    R26_PREVIEW_CONTAINMENT_AUTH_RC="${r26_authorize_rc}"
    if r26_preview_active_job_exact; then
      return 133
    else
      r26_job_rc="$?"
      if [[ "${r26_job_rc}" == "1" ]]; then
        r26_wait_cached_preview_child
        return "$?"
      fi
      return 124
    fi
  fi
  /bin/kill -TERM "${R26_APP_PID}" 2>/dev/null || {
    if r26_preview_active_job_exact; then
      return 125
    fi
    r26_job_rc="$?"
    if [[ "${r26_job_rc}" == "1" ]]; then
      r26_wait_cached_preview_child
      return "$?"
    fi
    return 126
  }

  while (( r26_index < 100 )); do
    if r26_preview_active_job_exact; then
      /bin/sleep 0.1
      r26_index=$((r26_index + 1))
      continue
    fi
    r26_job_rc="$?"
    if [[ "${r26_job_rc}" == "1" ]]; then
      r26_wait_cached_preview_child
      return "$?"
    fi
    return 127
  done

  # Refresh the full proof again immediately before escalation.  If any
  # identity token is absent or mismatched, do not signal the current PID.
  if r26_authorize_preview_signal; then
    :
  else
    r26_authorize_rc="$?"
    R26_PREVIEW_CONTAINMENT_AUTH_RC="${r26_authorize_rc}"
    if r26_preview_active_job_exact; then
      return 134
    else
      r26_job_rc="$?"
      if [[ "${r26_job_rc}" == "1" ]]; then
        r26_wait_cached_preview_child
        return "$?"
      fi
      return 128
    fi
  fi
  /bin/kill -KILL "${R26_APP_PID}" 2>/dev/null || {
    if r26_preview_active_job_exact; then
      return 129
    fi
    r26_job_rc="$?"
    if [[ "${r26_job_rc}" == "1" ]]; then
      r26_wait_cached_preview_child
      return "$?"
    fi
    return 130
  }
  r26_index=0
  while (( r26_index < 100 )); do
    if r26_preview_active_job_exact; then
      /bin/sleep 0.1
      r26_index=$((r26_index + 1))
      continue
    fi
    r26_job_rc="$?"
    if [[ "${r26_job_rc}" == "1" ]]; then
      r26_wait_cached_preview_child
      return "$?"
    fi
    return 131
  done
  return 132
}

r26_contain_uncommitted_impl_report() {
  local r26_live_sha=""
  [[ "${R26_END_COMMITTED}" == "false" ]] || return 0
  if [[ "${R26_IMPL_REPORT_STAGE_OWNED}" == "true" ]]; then
    [[ -n "${R26_INVOCATION_ID}" ]] || return 140
    [[ "${R26_IMPL_REPORT_STAGE}" == "${R26_TASK_DIRECTORY}/.${R26_INVOCATION_ID}.impl-report-r26.stage.md" ]] || return 141
    if [[ -e "${R26_IMPL_REPORT_STAGE}" || -L "${R26_IMPL_REPORT_STAGE}" ]]; then
      [[ -f "${R26_IMPL_REPORT_STAGE}" && ! -L "${R26_IMPL_REPORT_STAGE}" ]] || return 142
      /bin/rm -f "${R26_IMPL_REPORT_STAGE}" || return 143
    fi
    [[ ! -e "${R26_IMPL_REPORT_STAGE}" && ! -L "${R26_IMPL_REPORT_STAGE}" ]] || return 144
    R26_IMPL_REPORT_STAGE_OWNED="false"
  fi
  if [[ "${R26_IMPL_REPORT_PUBLISHED}" == "true" ]]; then
    [[ -n "${R26_IMPL_REPORT_STAGE_SHA}" ]] || return 145
    [[ -f "${R26_IMPL_REPORT}" && ! -L "${R26_IMPL_REPORT}" ]] || return 146
    if r26_live_sha="$(r26_sha "${R26_IMPL_REPORT}")"; then :; else return 147; fi
    [[ "${r26_live_sha}" == "${R26_IMPL_REPORT_STAGE_SHA}" ]] || return 148
    /bin/rm -f "${R26_IMPL_REPORT}" || return 149
    [[ ! -e "${R26_IMPL_REPORT}" && ! -L "${R26_IMPL_REPORT}" ]] || return 150
    R26_IMPL_REPORT_PUBLISHED="false"
  fi
  return 0
}

r26_active_fail() {
  local r26_status="$1"
  local r26_matrix_restore_rc=0
  local r26_matrix_owned_cleanup_rc=0
  local r26_preview_containment_rc=0
  local r26_screenshot_stage_cleanup_rc=0
  local r26_impl_report_cleanup_rc=0
  local r26_matrix_restore_attempts=0
  local r26_rejected_at=""
  shift
  trap - ERR
  trap '' HUP INT TERM
  set +e
  if [[ "${R26_MATRIX_MUTATED}" == "true" ]]; then
    while (( r26_matrix_restore_attempts < 2 )); do
      r26_matrix_restore_attempts=$((r26_matrix_restore_attempts + 1))
      r26_restore_matrix_containment
      r26_matrix_restore_rc="$?"
      [[ "${r26_matrix_restore_rc}" == "0" ]] && break
    done
  fi
  r26_contain_matrix_owned_paths
  r26_matrix_owned_cleanup_rc="$?"
  r26_contain_preview_process
  r26_preview_containment_rc="$?"
  R26_PREVIEW_CONTAINMENT_RC="${r26_preview_containment_rc}"
  r26_contain_screenshot_stage
  r26_screenshot_stage_cleanup_rc="$?"
  r26_contain_uncommitted_impl_report
  r26_impl_report_cleanup_rc="$?"
  if [[ -f "${R26_BOUNDARY_LOG}" && ! -L "${R26_BOUNDARY_LOG}" ]]; then
    {
      /usr/bin/printf '%s\n' 'status=REJECTED_CONTAMINATED'
      /usr/bin/printf 'phase=%s\n' "${R26_PHASE}"
      /usr/bin/printf 'reason=%s\n' "$*"
      /usr/bin/printf 'exit_code=%s\n' "${r26_status}"
      /usr/bin/printf 'r23_first_mask=%s\n' "${R26_R23_FIRST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r23_latest_mask=%s\n' "${R26_R23_LATEST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r24_first_mask=%s\n' "${R26_R24_FIRST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r24_latest_mask=%s\n' "${R26_R24_LATEST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r25_first_mask=%s\n' "${R26_R25_FIRST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r25_latest_mask=%s\n' "${R26_R25_LATEST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r20_first_mask=%s\n' "${R26_R20_FIRST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'r20_latest_mask=%s\n' "${R26_R20_LATEST_MASK:-UNCOMMITTED}"
      /usr/bin/printf 'authoritative_status_captured=%s\n' "${R26_AUTHORITATIVE_STATUS_CAPTURED}"
      /usr/bin/printf 'authoritative_swift_rc=%s\n' "${R26_AUTHORITATIVE_SWIFT_RC}"
      /usr/bin/printf 'authoritative_tee_rc=%s\n' "${R26_AUTHORITATIVE_TEE_RC}"
      /usr/bin/printf 'authoritative_verify_log_sha=%s\n' "${R26_VERIFY_LOG_SHA}"
      /usr/bin/printf 'authoritative_verify_log_bytes=%s\n' "${R26_VERIFY_LOG_BYTES}"
      /usr/bin/printf 'matrix_restore_attempt_rc=%s\n' "${r26_matrix_restore_rc}"
      /usr/bin/printf 'matrix_restore_attempt_count=%s\n' "${r26_matrix_restore_attempts}"
      /usr/bin/printf 'matrix_mutated_after_containment=%s\n' "${R26_MATRIX_MUTATED}"
      /usr/bin/printf 'matrix_owned_path_cleanup_rc=%s\n' "${r26_matrix_owned_cleanup_rc}"
      /usr/bin/printf 'preview_exact_pid_containment_rc=%s\n' "${r26_preview_containment_rc}"
      /usr/bin/printf 'preview_exact_pid_containment_wait_rc=%s\n' "${R26_PREVIEW_CONTAINMENT_WAIT_RC}"
      /usr/bin/printf 'preview_direct_child_owned_after_containment=%s\n' "${R26_APP_DIRECT_CHILD_OWNED}"
      /usr/bin/printf 'preview_identity_committed_after_containment=%s\n' "${R26_APP_IDENTITY_COMMITTED}"
      /usr/bin/printf 'preview_containment_command_match=%s\n' "${R26_PREVIEW_CONTAINMENT_COMMAND_MATCH}"
      /usr/bin/printf 'preview_containment_ppid_match=%s\n' "${R26_PREVIEW_CONTAINMENT_PPID_MATCH}"
      /usr/bin/printf 'preview_containment_birth_match=%s\n' "${R26_PREVIEW_CONTAINMENT_BIRTH_MATCH}"
      /usr/bin/printf 'preview_containment_authorization_rc=%s\n' "${R26_PREVIEW_CONTAINMENT_AUTH_RC}"
      /usr/bin/printf 'preview_screenshot_stage_cleanup_rc=%s\n' "${r26_screenshot_stage_cleanup_rc}"
      /usr/bin/printf 'impl_report_uncommitted_cleanup_rc=%s\n' "${r26_impl_report_cleanup_rc}"
      /usr/bin/printf 'terminal_end_committed=%s\n' "${R26_END_COMMITTED}"
      /usr/bin/printf 'preview_raw_path=%s\n' "${R26_CU_RAW_PATH:-UNSET}"
      /usr/bin/printf '%s\n' 'preview_raw_if_present_retained_as_isolated_contaminated_evidence=true'
      /usr/bin/printf '%s\n' 'authorization_consumed=true'
      /usr/bin/printf '%s\n' 'retry_same_boundary=false'
      if r26_rejected_at="$(r26_capture_now)"; then :; else r26_rejected_at="TIMESTAMP_CAPTURE_FAILED"; fi
      /usr/bin/printf 'utc_rejected=%s\n' "${r26_rejected_at}"
    } >> "${R26_BOUNDARY_LOG}"
  fi
  /usr/bin/printf 'R26 active failure: %s\n' "$*" >&2
  exit "${r26_status}"
}

r26_err_trap() {
  local r26_status="$?"
  local r26_command="${BASH_COMMAND:-UNKNOWN}"
  # ERR is inherited by command-substitution subshells under set -E. A child
  # failure must propagate its real status to the root shell without running
  # root-owned containment or writing a second rejection from the child.
  if (( BASH_SUBSHELL != 0 )); then
    trap - ERR
    exit "${r26_status}"
  fi
  if [[ "${R26_BOUNDARY_ACTIVE}" == "true" ]]; then
    r26_active_fail "${r26_status}" "unexpected_command_failure_${r26_command}"
  fi
  r26_pre_begin_fail "${r26_status}" "unexpected_command_failure_${r26_command}"
}

r26_signal_trap() {
  local r26_name="$1"
  local r26_status="$2"
  if [[ "${R26_BOUNDARY_ACTIVE}" == "true" ]]; then
    r26_active_fail "${r26_status}" "signal_${r26_name}"
  fi
  r26_pre_begin_fail "${r26_status}" "signal_${r26_name}"
}

r26_defer_signal() {
  if [[ -z "${R26_DEFERRED_SIGNAL}" ]]; then
    R26_DEFERRED_SIGNAL="$1"
    R26_DEFERRED_SIGNAL_STATUS="$2"
  fi
}

r26_install_signal_traps() {
  trap 'r26_signal_trap HUP 129' HUP
  trap 'r26_signal_trap INT 130' INT
  trap 'r26_signal_trap TERM 143' TERM
}

r26_begin_preview_launch_identity_window() {
  [[ -z "${R26_APP_PID}" ]] || r26_active_fail 70 "launch_window_pid_already_set"
  [[ "${R26_APP_DIRECT_CHILD_OWNED}" == "false" ]] || r26_active_fail 70 "launch_window_child_already_owned"
  [[ "${R26_APP_IDENTITY_COMMITTED}" == "false" ]] || r26_active_fail 70 "launch_window_identity_already_committed"
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  R26_PREVIEW_CONTAINMENT_WAIT_RC="NOT_WAITED"
  R26_PREVIEW_CONTAINMENT_COMMAND_MATCH="NOT_OBSERVED"
  R26_PREVIEW_CONTAINMENT_PPID_MATCH="NOT_OBSERVED"
  R26_PREVIEW_CONTAINMENT_BIRTH_MATCH="NOT_OBSERVED"
  R26_PREVIEW_CONTAINMENT_AUTH_RC="NOT_ATTEMPTED"
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
}

r26_capture_preview_launch_identity() {
  local r26_job_rc=0
  local r26_index=0
  local r26_birth=""
  local r26_ppid=""
  while (( r26_index < 50 )); do
    if r26_preview_active_job_exact; then
      if r26_ppid="$(/bin/ps -p "${R26_APP_PID}" -o ppid= 2>/dev/null)" && \
         r26_birth="$(/bin/ps -p "${R26_APP_PID}" -o lstart= 2>/dev/null)"; then
        r26_ppid="${r26_ppid// /}"
        r26_ppid="${r26_ppid//$'\t'/}"
        if [[ "${r26_ppid}" == "$$" && -n "${r26_birth}" && "${r26_birth}" != *$'\n'* ]]; then
          R26_APP_PPID="${r26_ppid}"
          R26_APP_BIRTH="${r26_birth}"
          return 0
        fi
      fi
    else
      r26_job_rc="$?"
      if [[ "${r26_job_rc}" == "1" ]]; then
        r26_wait_cached_preview_child || :
        return 71
      fi
      return 72
    fi
    /bin/sleep 0.02
    r26_index=$((r26_index + 1))
  done
  return 73
}

r26_commit_preview_launch_identity_window() {
  local r26_label="$1"
  [[ "${R26_APP_DIRECT_CHILD_OWNED}" == "true" ]] || r26_active_fail 70 "launch_identity_not_owned_${r26_label}"
  case "${R26_APP_PID}" in ''|*[!0-9]*) r26_active_fail 70 "launch_identity_pid_invalid_${r26_label}" ;; esac
  [[ -n "${R26_APP_BIRTH}" && "${R26_APP_BIRTH}" != *$'\n'* ]] || r26_active_fail 70 "launch_identity_birth_invalid_${r26_label}"
  [[ "${R26_APP_PPID}" == "$$" ]] || r26_active_fail 70 "launch_identity_ppid_invalid_${r26_label}_${R26_APP_PPID}"
  R26_APP_IDENTITY_COMMITTED="true"
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then
    r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_launch_identity_${r26_label}"
  fi
}

trap 'r26_err_trap' ERR
r26_install_signal_traps

r26_fail() {
  local r26_status="$1"
  shift
  if [[ "${R26_BOUNDARY_ACTIVE}" == "true" ]]; then
    r26_active_fail "${r26_status}" "$*"
  fi
  r26_pre_begin_fail "${r26_status}" "$*"
}

r26_require_regular_file() {
  local r26_path="$1"
  [[ -f "${r26_path}" && ! -L "${r26_path}" ]] || r26_fail 70 "not_regular_non_symlink_${r26_path}"
}

r26_require_absent_path() {
  local r26_path="$1"
  [[ ! -e "${r26_path}" && ! -L "${r26_path}" ]] || r26_fail 70 "expected_absent_${r26_path}"
}

r26_require_sha() {
  local r26_expected="$1"
  local r26_path="$2"
  local r26_actual=""
  r26_require_regular_file "${r26_path}"
  if r26_actual="$(r26_sha "${r26_path}")"; then
    :
  else
    r26_fail 70 "sha_read_failed_${r26_path}"
  fi
  [[ "${r26_actual}" == "${r26_expected}" ]] || r26_fail 70 "sha_mismatch_${r26_path}"
}

r26_exact_line_count() {
  local r26_path="$1"
  local r26_line="$2"
  /usr/bin/awk -v expected="${r26_line}" '$0 == expected { count += 1 } END { print count + 0 }' "${r26_path}"
}

r26_require_exact_line_once() {
  local r26_path="$1"
  local r26_line="$2"
  local r26_count=""
  if r26_count="$(r26_exact_line_count "${r26_path}" "${r26_line}")"; then
    :
  else
    r26_fail 70 "line_count_failed_${r26_path}"
  fi
  [[ "${r26_count}" == "1" ]] || r26_fail 70 "line_not_unique_${r26_path}_${r26_line}"
}

r26_machine_value() {
  local r26_key="$1"
  /usr/bin/awk -v key="${r26_key}" '
    $0 == "R26_MACHINE_BLOCK_BEGIN" { inside = 1; next }
    $0 == "R26_MACHINE_BLOCK_END" { inside = 0; next }
    inside && index($0, key "=") == 1 { print substr($0, length(key) + 2) }
  ' "${R26_REVIEW26_PATH}"
}

r26_require_review26() {
  local r26_argument_sha="$1"
  local r26_actual_review_sha=""
  local r26_field_count=""
  local r26_key=""
  local r26_expected=""
  local r26_actual=""
  local r26_verdict_count=""
  local r26_freeze_sha=""
  local r26_driver_sha=""
  local r26_manifest_sha=""

  r26_require_regular_file "${R26_REVIEW26_PATH}"
  if r26_actual_review_sha="$(r26_sha "${R26_REVIEW26_PATH}")"; then
    :
  else
    r26_fail 70 "review26_sha_read_failed"
  fi
  [[ "${r26_actual_review_sha}" == "${r26_argument_sha}" ]] || r26_fail 70 "review26_argument_sha_mismatch"
  r26_require_exact_line_once "${R26_REVIEW26_PATH}" 'Verdict: APPROVED — 0 P0 / 0 P1'
  if r26_verdict_count="$(/usr/bin/awk '/^Verdict:/ { count += 1 } END { print count + 0 }' "${R26_REVIEW26_PATH}")"; then :; else r26_fail 70 "review26_verdict_count_read_failed"; fi
  [[ "${r26_verdict_count}" == "1" ]] || r26_fail 70 "review26_verdict_count_${r26_verdict_count}"
  r26_require_exact_line_once "${R26_REVIEW26_PATH}" 'R26_MACHINE_BLOCK_BEGIN'
  r26_require_exact_line_once "${R26_REVIEW26_PATH}" 'R26_MACHINE_BLOCK_END'
  if r26_field_count="$(/usr/bin/awk '
      $0 == "R26_MACHINE_BLOCK_BEGIN" { inside = 1; next }
      $0 == "R26_MACHINE_BLOCK_END" { inside = 0; next }
      inside { count += 1 }
      END { print count + 0 }
    ' "${R26_REVIEW26_PATH}")"; then
    :
  else
    r26_fail 70 "review26_field_count_failed"
  fi
  [[ "${r26_field_count}" == "12" ]] || r26_fail 70 "review26_field_count_${r26_field_count}"
  if r26_freeze_sha="$(r26_sha "${R26_FREEZE_PATH}")"; then :; else r26_fail 70 "review26_freeze_sha_read_failed"; fi
  if r26_driver_sha="$(r26_sha "${R26_DRIVER_PATH}")"; then :; else r26_fail 70 "review26_driver_sha_read_failed"; fi
  if r26_manifest_sha="$(r26_sha "${R26_MANIFEST_PATH}")"; then :; else r26_fail 70 "review26_manifest_sha_read_failed"; fi

  for r26_key in \
    authority_mode standing_goal_authority_verified reviewer_independence_attested \
    reviewer_write_scope user_hash_echo_required review_verdict freeze_sha driver_sha \
    manifest_sha branch head manifest_count; do
    if r26_actual="$(r26_machine_value "${r26_key}")"; then
      :
    else
      r26_fail 70 "review26_field_read_failed_${r26_key}"
    fi
    [[ -n "${r26_actual}" && "${r26_actual}" != *$'\n'* ]] || r26_fail 70 "review26_field_not_unique_${r26_key}"
    case "${r26_key}" in
      authority_mode) r26_expected='standing_goal_automatic_after_review26' ;;
      standing_goal_authority_verified) r26_expected='true' ;;
      reviewer_independence_attested) r26_expected='true' ;;
      reviewer_write_scope) r26_expected='review26_only' ;;
      user_hash_echo_required) r26_expected='false' ;;
      review_verdict) r26_expected='APPROVED_0_P0_0_P1' ;;
      freeze_sha) r26_expected="${r26_freeze_sha}" ;;
      driver_sha) r26_expected="${r26_driver_sha}" ;;
      manifest_sha) r26_expected="${r26_manifest_sha}" ;;
      branch) r26_expected="${R26_EXPECTED_BRANCH}" ;;
      head) r26_expected="${R26_EXPECTED_HEAD}" ;;
      manifest_count) r26_expected="${R26_EXPECTED_MANIFEST_COUNT}" ;;
      *) r26_fail 70 "review26_unknown_field_${r26_key}" ;;
    esac
    [[ "${r26_actual}" == "${r26_expected}" ]] || r26_fail 70 "review26_field_mismatch_${r26_key}"
  done
}

r26_require_manifest() {
  local r26_count=""
  local r26_shape=""
  local r26_status=""
  local r26_expected=""
  local r26_path=""
  local r26_membership_count=""
  local r26_old_path=""
  local r26_addition=""
  local r26_excluded=""
  local r26_old_count=0
  local r26_addition_count=0

  R26_MANIFEST_ADDITIONS=(
    "${R26_DRIVER_PATH}"
    "${R26_R25_MANIFEST_PATH}"
    "${R26_R25_FREEZE_PATH}"
    "${R26_R25_REVIEW_PATH}"
    "${R26_R25_BOUNDARY_PATH}"
    "${R26_R25_HASH_LOG_PATH}"
    "${R26_R25_VERIFY_PATH}"
    "${R26_R25_TARGETED_PATH}"
    "${R26_R25_BUILD_PATH}"
    "${R26_R25_MATRIX_PATH}"
    "${R26_R25_BUNDLE_LOG_PATH}"
    "${R26_R25_SOURCE_LOG_PATH}"
    "${R26_R25_BOOTSTRAP_LOG_PATH}"
    "${R26_R25_COLD_START_LOG_PATH}"
  )
  R26_MANIFEST_EXCLUSIONS=(
    "${R26_MANIFEST_PATH}"
    "${R26_FREEZE_PATH}"
    "${R26_REVIEW26_PATH}"
    "${R26_TARGETED_LOG}"
    "${R26_VERIFY_LOG}"
    "${R26_BUILD_LOG}"
    "${R26_MATRIX_LOG}"
    "${R26_TASK_DIRECTORY}/impl-report-r26.md"
    "${R26_BOUNDARY_LOG}"
    "${R26_BUNDLE_LOG}"
    "${R26_SOURCE_LOG}"
    "${R26_HASH_LOG}"
    "${R26_BOOTSTRAP_LOG}"
    "${R26_COLD_START_LOG}"
    "${R26_SCREENSHOT}"
  )

  r26_require_sha "${R26_EXPECTED_R25_MANIFEST_SHA}" "${R26_R25_MANIFEST_PATH}"
  r26_require_regular_file "${R26_MANIFEST_PATH}"
  if r26_count="$(/usr/bin/awk 'END { print NR + 0 }' "${R26_MANIFEST_PATH}")"; then
    :
  else
    r26_fail 70 "manifest_count_read_failed"
  fi
  [[ "${r26_count}" == "${R26_EXPECTED_MANIFEST_COUNT}" ]] || r26_fail 70 "manifest_count_${r26_count}"
  if r26_shape="$(/usr/bin/awk -v root="${R26_REPOSITORY_ROOT}/" '
      BEGIN { ok = 1; previous = "" }
      {
        if ($0 !~ /^[0-9a-f]{64}  \/Users\/muzi\/Agent-loop\//) ok = 0
        path = substr($0, 67)
        if (path <= previous) ok = 0
        previous = path
      }
      END { print ok }
    ' "${R26_MANIFEST_PATH}")"; then
    :
  else
    r26_fail 70 "manifest_shape_read_failed"
  fi
  [[ "${r26_shape}" == "1" ]] || r26_fail 70 "manifest_shape_invalid"

  while IFS= read -r r26_status; do
    r26_expected="${r26_status%%  *}"
    r26_path="${r26_status#*  }"
    [[ "${r26_expected}" != "${r26_status}" ]] || r26_fail 70 "manifest_record_parse_failed"
    r26_require_regular_file "${r26_path}"
  done < "${R26_MANIFEST_PATH}"

  while IFS= read -r r26_status; do
    r26_old_path="${r26_status#*  }"
    [[ "${r26_old_path}" != "${r26_status}" ]] || r26_fail 70 "r25_manifest_path_parse_failed"
    if r26_membership_count="$(/usr/bin/awk -v expected="${r26_old_path}" 'substr($0, 67) == expected { count += 1 } END { print count + 0 }' "${R26_MANIFEST_PATH}")"; then
      :
    else
      r26_fail 70 "r25_path_membership_read_failed_${r26_old_path}"
    fi
    [[ "${r26_membership_count}" == "1" ]] || r26_fail 70 "r25_path_not_in_r26_manifest_${r26_old_path}"
    r26_old_count=$((r26_old_count + 1))
  done < "${R26_R25_MANIFEST_PATH}"
  [[ "${r26_old_count}" == "192" ]] || r26_fail 70 "r25_path_set_count_${r26_old_count}"

  for r26_addition in "${R26_MANIFEST_ADDITIONS[@]}"; do
    if r26_membership_count="$(/usr/bin/awk -v expected="${r26_addition}" 'substr($0, 67) == expected { count += 1 } END { print count + 0 }' "${R26_R25_MANIFEST_PATH}")"; then :; else r26_fail 70 "addition_old_membership_read_failed_${r26_addition}"; fi
    [[ "${r26_membership_count}" == "0" ]] || r26_fail 70 "addition_overlaps_r25_set_${r26_addition}"
    if r26_membership_count="$(/usr/bin/awk -v expected="${r26_addition}" 'substr($0, 67) == expected { count += 1 } END { print count + 0 }' "${R26_MANIFEST_PATH}")"; then :; else r26_fail 70 "addition_membership_read_failed_${r26_addition}"; fi
    [[ "${r26_membership_count}" == "1" ]] || r26_fail 70 "addition_not_exactly_once_${r26_addition}"
    r26_addition_count=$((r26_addition_count + 1))
  done
  [[ "${r26_addition_count}" == "14" ]] || r26_fail 70 "addition_count_${r26_addition_count}"

  for r26_excluded in "${R26_MANIFEST_EXCLUSIONS[@]}"; do
    if r26_membership_count="$(/usr/bin/awk -v expected="${r26_excluded}" 'substr($0, 67) == expected { count += 1 } END { print count + 0 }' "${R26_MANIFEST_PATH}")"; then :; else r26_fail 70 "exclusion_membership_read_failed_${r26_excluded}"; fi
    [[ "${r26_membership_count}" == "0" ]] || r26_fail 70 "excluded_path_present_${r26_excluded}"
  done

  if /usr/bin/shasum -a 256 --strict -c "${R26_MANIFEST_PATH}" >/dev/null 2>&1; then
    :
  else
    r26_fail 70 "manifest_strict_check_failed"
  fi
}

r26_require_r23_predecessor() {
  local r26_path=""
  local r26_empty_path=""
  local r26_old_expected=""
  local r26_old_path=""
  local r26_old_actual=""
  local r26_old_pass=0
  local r26_old_mismatch=0
  local r26_expected_mismatch="false"

  r26_require_sha "${R26_EXPECTED_R23_FREEZE_SHA}" "${R26_R23_FREEZE_PATH}"
  r26_require_sha "${R26_EXPECTED_R23_REVIEW_SHA}" "${R26_R23_REVIEW_PATH}"
  r26_require_sha "${R26_EXPECTED_R23_DRIVER_SHA}" "${R26_R23_DRIVER_PATH}"
  r26_require_sha "${R26_EXPECTED_R23_MANIFEST_SHA}" "${R26_R23_MANIFEST_PATH}"
  r26_require_sha "${R26_EXPECTED_R23_REPORT_SHA}" "${R26_R23_REPORT_PATH}"
  r26_require_sha "${R26_EXPECTED_R23_BOUNDARY_SHA}" "${R26_R23_BOUNDARY_PATH}"
  r26_require_sha "${R26_EXPECTED_R23_HASH_LOG_SHA}" "${R26_R23_HASH_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R23_VERIFY_SHA}" "${R26_R23_VERIFY_PATH}"

  R26_R23_EMPTY_RUNTIME_PATHS=(
    "${R26_TASK_DIRECTORY}/r23-targeted-tests.log"
    "${R26_TASK_DIRECTORY}/r23-build.log"
    "${R26_TASK_DIRECTORY}/r23-migration-matrix.log"
    "${R26_TASK_DIRECTORY}/evidence/r23-bundle-provenance.log"
    "${R26_TASK_DIRECTORY}/evidence/r23-source-gates.log"
    "${R26_TASK_DIRECTORY}/evidence/r23-preview-bootstrap.log"
    "${R26_TASK_DIRECTORY}/evidence/r23-preview-cold-start.log"
  )
  for r26_empty_path in "${R26_R23_EMPTY_RUNTIME_PATHS[@]}"; do
    r26_require_sha "${R26_EXPECTED_EMPTY_SHA}" "${r26_empty_path}"
  done
  r26_require_absent_path "${R26_R23_SCREENSHOT_PATH}"

  r26_require_exact_line_once "${R26_R23_REVIEW_PATH}" 'Verdict: APPROVED — 0 P0 / 0 P1'
  r26_require_exact_line_once "${R26_R23_BOUNDARY_PATH}" 'status=REJECTED_CONTAMINATED'
  r26_require_exact_line_once "${R26_R23_BOUNDARY_PATH}" 'phase=authoritative_full_test_status_capture'
  r26_require_exact_line_once "${R26_R23_BOUNDARY_PATH}" 'reason=outer_shell_zsh_PIPESTATUS_unset_after_terminal_652_of_652_log'
  r26_require_exact_line_once "${R26_R23_BOUNDARY_PATH}" 'authoritative_pipeline_status=UNKNOWN_NOT_CAPTURED'
  r26_require_exact_line_once "${R26_R23_BOUNDARY_PATH}" 'authoritative_swift_rc=UNKNOWN_NOT_CAPTURED'
  r26_require_exact_line_once "${R26_R23_BOUNDARY_PATH}" 'authoritative_tee_rc=UNKNOWN_NOT_CAPTURED'
  r26_require_exact_line_once "${R26_R23_BOUNDARY_PATH}" 'full_test_rerun_forbidden=true'
  r26_require_exact_line_once "${R26_R23_BOUNDARY_PATH}" 'subsequent_gates_run=false'
  r26_require_exact_line_once "${R26_R23_VERIFY_PATH}" '✔ Test run with 652 tests in 7 suites passed after 41.900 seconds.'
  r26_require_absent_path "${R26_R23_PLANNED_APP}"
  r26_require_absent_path "${R26_R23_PLANNED_EXECUTABLE}"

  while IFS= read -r r26_path; do
    r26_require_regular_file "${r26_path}"
  done <<EOF
${R26_R23_BOUNDARY_PATH}
${R26_R23_HASH_LOG_PATH}
${R26_R23_VERIFY_PATH}
${R26_R23_REPORT_PATH}
EOF

  while IFS= read -r r26_path; do
    r26_old_expected="${r26_path%%  *}"
    r26_old_path="${r26_path#*  }"
    if r26_old_actual="$(r26_sha "${r26_old_path}")"; then
      :
    else
      r26_fail 70 "r23_manifest_actual_sha_failed_${r26_old_path}"
    fi
    r26_expected_mismatch="false"
    case "${r26_old_path}" in
      "${R26_TEST_PATH}"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md"|\
      "${R26_TASK_DIRECTORY}/plan.md"|\
      "${R26_TASK_DIRECTORY}/blocked.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md")
        r26_expected_mismatch="true"
        ;;
    esac
    if [[ "${r26_expected_mismatch}" == "true" ]]; then
      [[ "${r26_old_actual}" != "${r26_old_expected}" ]] || r26_fail 70 "r23_manifest_expected_mismatch_missing_${r26_old_path}"
      r26_old_mismatch=$((r26_old_mismatch + 1))
    else
      [[ "${r26_old_actual}" == "${r26_old_expected}" ]] || r26_fail 70 "r23_manifest_unexpected_mismatch_${r26_old_path}"
      r26_old_pass=$((r26_old_pass + 1))
    fi
  done < "${R26_R23_MANIFEST_PATH}"
  [[ "${r26_old_pass}" == "156" && "${r26_old_mismatch}" == "7" ]] || r26_fail 70 "r23_manifest_partition_${r26_old_pass}_${r26_old_mismatch}"
}

r26_require_r24_predecessor() {
  local r26_record=""
  local r26_old_expected=""
  local r26_old_path=""
  local r26_old_actual=""
  local r26_old_pass=0
  local r26_old_mismatch=0
  local r26_expected_mismatch="false"
  local r26_repeated_line=""
  local r26_repeated_count=""

  r26_require_sha "${R26_EXPECTED_R24_FREEZE_SHA}" "${R26_R24_FREEZE_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_REVIEW_SHA}" "${R26_R24_REVIEW_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_DRIVER_SHA}" "${R26_R24_DRIVER_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_MANIFEST_SHA}" "${R26_R24_MANIFEST_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_BOUNDARY_SHA}" "${R26_R24_BOUNDARY_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_HASH_LOG_SHA}" "${R26_R24_HASH_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_VERIFY_SHA}" "${R26_R24_VERIFY_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_TARGETED_SHA}" "${R26_R24_TARGETED_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_BUILD_SHA}" "${R26_R24_BUILD_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_MATRIX_SHA}" "${R26_R24_MATRIX_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_BUNDLE_LOG_SHA}" "${R26_R24_BUNDLE_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_SOURCE_LOG_SHA}" "${R26_R24_SOURCE_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_BOOTSTRAP_LOG_SHA}" "${R26_R24_BOOTSTRAP_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R24_COLD_START_LOG_SHA}" "${R26_R24_COLD_START_LOG_PATH}"
  r26_require_absent_path "${R26_R24_REPORT_PATH}"
  r26_require_absent_path "${R26_R24_SCREENSHOT_PATH}"

  r26_require_exact_line_once "${R26_R24_REVIEW_PATH}" 'Verdict: APPROVED — 0 P0 / 0 P1'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'boundary_identity=R24_SINGLE_BASH_FULL_CHAIN_AND_ISOLATED_PREVIEW'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'status=REJECTED_CONTAMINATED'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'phase=guard_shape_and_strip'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'reason=core_guard_shape_1:1::0:1:1'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'authoritative_log_terminal_summary=652_of_652_pass'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'same_log_targeted_audit=46_of_46_pass'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'launch_ready=true'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'matrix_restore_attempt_count=0'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'matrix_mutated_after_containment=false'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'preview_direct_child_owned_after_containment=false'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'preview_identity_committed_after_containment=false'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'preview_containment_authorization_rc=NOT_ATTEMPTED'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'terminal_end_committed=false'
  r26_require_exact_line_once "${R26_R24_BOUNDARY_PATH}" 'preview_raw_path=UNSET'
  for r26_repeated_line in \
    'authorization_consumed=true' \
    'authoritative_status_captured=true' \
    'authoritative_swift_rc=0' \
    'authoritative_tee_rc=0' \
    'retry_same_boundary=false'; do
    if r26_repeated_count="$(r26_exact_line_count "${R26_R24_BOUNDARY_PATH}" "${r26_repeated_line}")"; then :; else r26_fail 70 "r24_repeated_line_count_failed_${r26_repeated_line}"; fi
    [[ "${r26_repeated_count}" == "2" ]] || r26_fail 70 "r24_repeated_line_count_${r26_repeated_line}_${r26_repeated_count}"
  done
  r26_require_exact_line_once "${R26_R24_VERIFY_PATH}" '✔ Test run with 652 tests in 7 suites passed after 42.492 seconds.'
  r26_require_exact_line_once "${R26_R24_TARGETED_PATH}" 'status=PASS'
  r26_require_exact_line_once "${R26_R24_TARGETED_PATH}" 'required_discovery_total=46'
  r26_require_exact_line_once "${R26_R24_TARGETED_PATH}" 'required_pass_total=46'
  r26_require_exact_line_once "${R26_R24_BUNDLE_LOG_PATH}" 'signed_bundle_manifest_sha=1871d346bed8b7978f7456e2893218a97cad7b8dc643c84bba9cd87cb81c8b5e'
  r26_require_exact_line_once "${R26_R24_BUNDLE_LOG_PATH}" 'post_sign_executable_sha=0d01c0ee8b658cf68c5463ef70cc68756a69630a5986cf620ad3870097021b05'
  r26_require_exact_line_once "${R26_R24_BUNDLE_LOG_PATH}" 'info_plist_sha=53bb6470fc12b39a5f48ac6d261415acff96cfbc57ffbf4721d3e351d2123277'
  r26_require_exact_line_once "${R26_R24_BUNDLE_LOG_PATH}" 'cdhash=17bd20ada27ef9e69d0de007b49c53d01ddf48a6'
  r26_require_exact_line_once "${R26_R24_BUNDLE_LOG_PATH}" 'process_count=0'

  while IFS= read -r r26_record; do
    r26_old_expected="${r26_record%%  *}"
    r26_old_path="${r26_record#*  }"
    if r26_old_actual="$(r26_sha "${r26_old_path}")"; then
      :
    else
      r26_fail 70 "r24_manifest_actual_sha_failed_${r26_old_path}"
    fi
    r26_expected_mismatch="false"
    case "${r26_old_path}" in
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md"|\
      "${R26_TASK_DIRECTORY}/plan.md"|\
      "${R26_TASK_DIRECTORY}/blocked.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md")
        r26_expected_mismatch="true"
        ;;
    esac
    if [[ "${r26_expected_mismatch}" == "true" ]]; then
      [[ "${r26_old_actual}" != "${r26_old_expected}" ]] || r26_fail 70 "r24_manifest_expected_mismatch_missing_${r26_old_path}"
      r26_old_mismatch=$((r26_old_mismatch + 1))
    else
      [[ "${r26_old_actual}" == "${r26_old_expected}" ]] || r26_fail 70 "r24_manifest_unexpected_mismatch_${r26_old_path}"
      r26_old_pass=$((r26_old_pass + 1))
    fi
  done < "${R26_R24_MANIFEST_PATH}"
  [[ "${r26_old_pass}" == "172" && "${r26_old_mismatch}" == "6" ]] || r26_fail 70 "r24_manifest_partition_${r26_old_pass}_${r26_old_mismatch}"
}

r26_require_r25_predecessor() {
  local r26_record=""
  local r26_old_expected=""
  local r26_old_path=""
  local r26_old_actual=""
  local r26_old_pass=0
  local r26_old_mismatch=0
  local r26_expected_mismatch="false"
  local r26_count=""

  r26_require_sha "${R26_EXPECTED_R25_FREEZE_SHA}" "${R26_R25_FREEZE_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_REVIEW_SHA}" "${R26_R25_REVIEW_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_DRIVER_SHA}" "${R26_R25_DRIVER_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_MANIFEST_SHA}" "${R26_R25_MANIFEST_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_BOUNDARY_SHA}" "${R26_R25_BOUNDARY_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_HASH_LOG_SHA}" "${R26_R25_HASH_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_VERIFY_SHA}" "${R26_R25_VERIFY_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_TARGETED_SHA}" "${R26_R25_TARGETED_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_BUILD_SHA}" "${R26_R25_BUILD_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_MATRIX_SHA}" "${R26_R25_MATRIX_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_BUNDLE_LOG_SHA}" "${R26_R25_BUNDLE_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_SOURCE_LOG_SHA}" "${R26_R25_SOURCE_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_BOOTSTRAP_LOG_SHA}" "${R26_R25_BOOTSTRAP_LOG_PATH}"
  r26_require_sha "${R26_EXPECTED_R25_COLD_START_LOG_SHA}" "${R26_R25_COLD_START_LOG_PATH}"
  r26_require_absent_path "${R26_R25_REPORT_PATH}"
  r26_require_absent_path "${R26_R25_SCREENSHOT_PATH}"

  r26_require_exact_line_once "${R26_R25_REVIEW_PATH}" 'Verdict: APPROVED — 0 P0 / 0 P1'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'boundary_identity=R25_SINGLE_BASH_FULL_CHAIN_AND_ISOLATED_PREVIEW'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'authoritative_log_terminal_summary=652_of_652_pass'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'same_log_targeted_audit=46_of_46_pass'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'launch_ready=true'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'remaining_source_privacy_final_hashes=PASS'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'manifest_final_pre_preview=192_of_192'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'reason=unexpected_command_failure_/usr/bin/pgrep -x "${r25_name}"'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'reason=unexpected_command_failure_return "${r25_rc}"'
  r26_require_exact_line_once "${R26_R25_BOUNDARY_PATH}" 'reason=preview_command_read_failed_bootstrap_ready'
  if r26_count="$(r26_exact_line_count "${R26_R25_BOUNDARY_PATH}" 'status=REJECTED_CONTAMINATED')"; then :; else r26_fail 70 "r25_rejection_count_read_failed"; fi
  [[ "${r26_count}" == "3" ]] || r26_fail 70 "r25_rejection_count_${r26_count}"
  if r26_count="$(r26_exact_line_count "${R26_R25_BOUNDARY_PATH}" 'phase=preview_bootstrap_direct_start')"; then :; else r26_fail 70 "r25_phase_count_read_failed"; fi
  [[ "${r26_count}" == "3" ]] || r26_fail 70 "r25_phase_count_${r26_count}"
  r26_require_exact_line_once "${R26_R25_VERIFY_PATH}" '✔ Test run with 652 tests in 7 suites passed after 42.354 seconds.'
  r26_require_exact_line_once "${R26_R25_TARGETED_PATH}" 'status=PASS'
  r26_require_exact_line_once "${R26_R25_TARGETED_PATH}" 'required_discovery_total=46'
  r26_require_exact_line_once "${R26_R25_TARGETED_PATH}" 'required_pass_total=46'
  r26_require_exact_line_once "${R26_R25_BUNDLE_LOG_PATH}" 'signed_bundle_manifest_sha=57b2022e1128422591145471cfacf36b6b2fe86cf4a04a326e702fba3e27ed43'
  r26_require_exact_line_once "${R26_R25_BUNDLE_LOG_PATH}" 'post_sign_executable_sha=9713a30416cc391e6512b8880da79ac100bbec0325d24e732e0864259a5111df'
  r26_require_exact_line_once "${R26_R25_BUNDLE_LOG_PATH}" 'info_plist_sha=5e426e400cdc47fb2bceb15ca2cf665f83d0078a3337ac0077f373b2e0fb4f0d'
  r26_require_exact_line_once "${R26_R25_BUNDLE_LOG_PATH}" 'cdhash=d9f0a10b24213f54b671f440cbc4c089304cf24d'
  r26_require_exact_line_once "${R26_R25_BUNDLE_LOG_PATH}" 'process_count=0'

  while IFS= read -r r26_record; do
    r26_old_expected="${r26_record%%  *}"
    r26_old_path="${r26_record#*  }"
    if r26_old_actual="$(r26_sha "${r26_old_path}")"; then :; else r26_fail 70 "r25_manifest_actual_sha_failed_${r26_old_path}"; fi
    r26_expected_mismatch="false"
    case "${r26_old_path}" in
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-stage-spec.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p0/p1-plan.md"|\
      "${R26_TASK_DIRECTORY}/plan.md"|\
      "${R26_TASK_DIRECTORY}/blocked.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/stage-spec.md"|\
      "${R26_REPOSITORY_ROOT}/docs/collaboration/tasks/2026-07-25-personal-ai-ranch-p1/plan.md")
        r26_expected_mismatch="true"
        ;;
    esac
    if [[ "${r26_expected_mismatch}" == "true" ]]; then
      [[ "${r26_old_actual}" != "${r26_old_expected}" ]] || r26_fail 70 "r25_manifest_expected_mismatch_missing_${r26_old_path}"
      r26_old_mismatch=$((r26_old_mismatch + 1))
    else
      [[ "${r26_old_actual}" == "${r26_old_expected}" ]] || r26_fail 70 "r25_manifest_unexpected_mismatch_${r26_old_path}"
      r26_old_pass=$((r26_old_pass + 1))
    fi
  done < "${R26_R25_MANIFEST_PATH}"
  [[ "${r26_old_pass}" == "186" && "${r26_old_mismatch}" == "6" ]] || r26_fail 70 "r25_manifest_partition_${r26_old_pass}_${r26_old_mismatch}"
}

r26_require_implementation_baseline() {
  r26_require_sha "${R26_EXPECTED_CORE_SHA}" "${R26_CORE_PATH}"
  r26_require_sha "${R26_EXPECTED_TEST_SHA}" "${R26_TEST_PATH}"
}

r26_require_branch_and_head() {
  local r26_branch=""
  local r26_head=""
  if r26_branch="$(/usr/bin/git -C "${R26_REPOSITORY_ROOT}" branch --show-current)"; then
    :
  else
    r26_fail 70 "branch_read_failed"
  fi
  if r26_head="$(/usr/bin/git -C "${R26_REPOSITORY_ROOT}" rev-parse HEAD)"; then
    :
  else
    r26_fail 70 "head_read_failed"
  fi
  [[ "${r26_branch}" == "${R26_EXPECTED_BRANCH}" ]] || r26_fail 70 "branch_mismatch_${r26_branch}"
  [[ "${r26_head}" == "${R26_EXPECTED_HEAD}" ]] || r26_fail 70 "head_mismatch_${r26_head}"
}

r26_require_invocation_environment() {
  local r26_env_output=""
  local r26_env_status=()
  case "${BASH_VERSION}" in
    3.2.*) ;;
    *) r26_fail 70 "unexpected_bash_version_${BASH_VERSION}" ;;
  esac
  [[ -z "${BASH_ENV+x}" ]] || r26_fail 70 "BASH_ENV_must_be_unset"
  [[ -z "${ENV+x}" ]] || r26_fail 70 "ENV_must_be_unset"
  [[ -z "${CDPATH+x}" ]] || r26_fail 70 "CDPATH_must_be_unset"
  if r26_env_output="$({
      if /usr/bin/env -0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          expected=(
            "GIT_CONFIG_GLOBAL=/dev/null"
            "GIT_CONFIG_NOSYSTEM=1"
            "LANG=C"
            "LC_ALL=C"
            "PATH=/usr/bin:/bin:/usr/sbin:/sbin"
            "PWD=/Users/muzi/Agent-loop"
            "SHLVL=1"
            "TMPDIR=/private/tmp"
            "_=/usr/bin/env"
          )
          index=0
          while :; do
            record=""
            IFS= read -r -d "" record
            read_rc=$?
            if [[ "${read_rc}" == "0" ]]; then
              [[ "${index}" -lt "${#expected[@]}" ]] || exit 71
              [[ "${record}" == "${expected[${index}]}" ]] || exit 72
              index=$((index + 1))
              continue
            fi
            if [[ "${read_rc}" == "1" ]]; then
              [[ -z "${record}" ]] || exit 73
              break
            fi
            exit 74
          done
          [[ "${index}" == "${#expected[@]}" ]] || exit 75
        '; then
        r26_env_status=("${PIPESTATUS[@]}")
      else
        r26_env_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_env_status[@]}" == "3" ]] || exit 76
      [[ "${r26_env_status[0]}" == "0" && "${r26_env_status[1]}" == "0" && "${r26_env_status[2]}" == "0" ]] || exit 77
    })"; then
    :
  else
    r26_fail 70 "clean_environment_exact_universe_failed"
  fi
  [[ -z "${r26_env_output}" ]] || r26_fail 70 "clean_environment_probe_output"
}

r26_require_no_process() {
  local r26_process_rc=""
  if /usr/bin/pgrep -x AgentLoop >/dev/null 2>&1; then
    r26_process_rc="0"
  else
    r26_process_rc="$?"
  fi
  [[ "${r26_process_rc}" == "1" ]] || r26_fail 70 "AgentLoop_process_state_${r26_process_rc}"
  if /usr/bin/pgrep -x AgentLoopApp >/dev/null 2>&1; then
    r26_process_rc="0"
  else
    r26_process_rc="$?"
  fi
  [[ "${r26_process_rc}" == "1" ]] || r26_fail 70 "AgentLoopApp_process_state_${r26_process_rc}"
}

r26_runtime_paths() {
  /usr/bin/printf '%s\n' \
    "${R26_TASK_DIRECTORY}/r26-targeted-tests.log" \
    "${R26_TASK_DIRECTORY}/r26-verify.log" \
    "${R26_TASK_DIRECTORY}/r26-build.log" \
    "${R26_TASK_DIRECTORY}/r26-migration-matrix.log" \
    "${R26_TASK_DIRECTORY}/impl-report-r26.md" \
    "${R26_TASK_DIRECTORY}/evidence/r26-clean-boundary.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-bundle-provenance.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-source-gates.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-hash-manifest.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-preview-bootstrap.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-preview-cold-start.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-preview-smoke.png"
}

r26_require_fresh_runtime_absence() {
  local r26_path=""
  while IFS= read -r r26_path; do
    r26_require_absent_path "${r26_path}"
  done < <(r26_runtime_paths)
}

r26_require_zero_write_predecessors() {
  local r26_round="$1"
  local r26_generation=""
  local r26_path=""
  for r26_generation in r16 r17 r18 r21 r22; do
    for r26_path in \
      "${R26_TASK_DIRECTORY}/${r26_generation}-targeted-tests.log" \
      "${R26_TASK_DIRECTORY}/${r26_generation}-verify.log" \
      "${R26_TASK_DIRECTORY}/${r26_generation}-build.log" \
      "${R26_TASK_DIRECTORY}/${r26_generation}-migration-matrix.log" \
      "${R26_TASK_DIRECTORY}/impl-report-${r26_generation}.md" \
      "${R26_TASK_DIRECTORY}/evidence/${r26_generation}-clean-boundary.log" \
      "${R26_TASK_DIRECTORY}/evidence/${r26_generation}-bundle-provenance.log" \
      "${R26_TASK_DIRECTORY}/evidence/${r26_generation}-source-gates.log" \
      "${R26_TASK_DIRECTORY}/evidence/${r26_generation}-hash-manifest.log" \
      "${R26_TASK_DIRECTORY}/evidence/${r26_generation}-preview-bootstrap.log" \
      "${R26_TASK_DIRECTORY}/evidence/${r26_generation}-preview-cold-start.log" \
      "${R26_TASK_DIRECTORY}/evidence/${r26_generation}-preview-smoke.png"; do
      r26_require_absent_path "${r26_path}"
    done
  done
  if [[ "${R26_BOUNDARY_ACTIVE}" == "true" ]]; then
    r26_append_boundary "r16_r17_r18_r21_r22_zero_write_${r26_round}=true"
  fi
}

r26_validate_empty_exact_root() {
  local r26_path="$1"
  local r26_real=""
  local r26_capture=""
  [[ -d "${r26_path}" && ! -L "${r26_path}" ]] || r26_fail 70 "root_not_real_directory_${r26_path}"
  if r26_real="$(r26_canonical_directory "${r26_path}")"; then
    :
  else
    r26_fail 70 "root_realpath_failed_${r26_path}"
  fi
  [[ "${r26_real}" == "${r26_path}" ]] || r26_fail 70 "root_realpath_mismatch_${r26_path}_${r26_real}"
  if r26_capture="$({
      if /usr/bin/find -P "${r26_path}" -mindepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          unexpected=""
          IFS= read -r -d "" unexpected
          read_rc=$?
          if [[ "${read_rc}" == "0" ]]; then exit 72; fi
          if [[ "${read_rc}" != "1" ]]; then exit 73; fi
          [[ -z "${unexpected}" ]] || exit 74
        '; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 75
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 76
    })"; then
    :
  else
    r26_fail 70 "root_not_proven_empty_${r26_path}"
  fi
  [[ -z "${r26_capture}" ]] || r26_fail 70 "root_empty_probe_output_${r26_path}"
  [[ -d "${r26_path}" && ! -L "${r26_path}" ]] || r26_fail 70 "root_terminal_bookend_failed_${r26_path}"
}

r26_require_r15_tombstone_universe() {
  local r26_capture=""
  r26_require_private_tmp
  if r26_capture="$({
      if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            case "${path}" in
              /private/tmp/agentloop-r15-state.*|/private/tmp/agentloop-r15-bundle.*) exit 73 ;;
            esac
          done
        '; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 74
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 75
    })"; then
    :
  else
    r26_fail 70 "r15_tombstone_universe_failed"
  fi
  [[ -z "${r26_capture}" ]] || r26_fail 70 "r15_tombstone_universe_output"
  r26_require_absent_path "${R26_R15_STATE_ROOT}"
  r26_require_absent_path "${R26_R15_BUNDLE_ROOT}"
}

r26_validate_preview_state_tree() {
  local r26_capture=""
  if r26_capture="$({
      if /usr/bin/find -P "${R26_STATE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          root="$1"
          expected=(
            ".agentloop.lock"
            "agentloop.sqlite"
            "agentloop.sqlite-shm"
            "agentloop.sqlite-wal"
          )
          index=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ "${index}" -lt "${#expected[@]}" ]] || exit 73
            [[ "${path}" == "${root}/${expected[${index}]}" ]] || exit 74
            [[ -f "${path}" && ! -L "${path}" ]] || exit 75
            index=$((index + 1))
          done
          [[ "${index}" == "4" ]] || exit 76
          /usr/bin/printf "%s\n" "${index}"
        ' bash "${R26_STATE_ROOT}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "3" ]] || exit 77
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" && "${r26_status[2]}" == "0" ]] || exit 78
    })"; then
    :
  else
    r26_fail 70 "preview_state_tree_validation_failed"
  fi
  [[ "${r26_capture}" == "4" ]] || r26_fail 70 "preview_state_tree_count_${r26_capture}"
}

r26_validate_quiescent_preview_state_tree() {
  local r26_capture=""
  if r26_capture="$({
      if /usr/bin/find -P "${R26_STATE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          root="$1"
          expected=(
            ".agentloop.lock"
            "agentloop.sqlite"
            "agentloop.sqlite-shm"
            "agentloop.sqlite-wal"
          )
          index=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ "${index}" -lt "${#expected[@]}" ]] || exit 73
            [[ "${path}" == "${root}/${expected[${index}]}" ]] || exit 74
            [[ -f "${path}" && ! -L "${path}" ]] || exit 75
            index=$((index + 1))
          done
          [[ "${index}" == "2" || "${index}" == "4" ]] || exit 76
          /usr/bin/printf "%s\n" "${index}"
        ' bash "${R26_STATE_ROOT}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "3" ]] || exit 77
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" && "${r26_status[2]}" == "0" ]] || exit 78
    })"; then
    :
  else
    r26_fail 70 "quiescent_preview_state_tree_validation_failed"
  fi
  [[ "${r26_capture}" == "2" || "${r26_capture}" == "4" ]] || r26_fail 70 "quiescent_preview_state_tree_count_${r26_capture}"
  [[ -d "${R26_STATE_ROOT}" && ! -L "${R26_STATE_ROOT}" ]] || r26_fail 70 "quiescent_preview_state_root_terminal_bookend"
}

r26_validate_bundle_root_ready() {
  local r26_capture=""
  local r26_current_exec_sha=""
  local r26_current_bundle_sha=""
  local r26_current_uuid=""
  if r26_capture="$({
      if /usr/bin/find -P "${R26_BUNDLE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          expected="$1"
          count=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ "${path}" == "${expected}" && "${count}" == "0" ]] || exit 73
            [[ -d "${path}" && ! -L "${path}" ]] || exit 74
            count=1
          done
          /usr/bin/printf "%s\n" "${count}"
        ' bash "${R26_APP}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 75
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 76
    })"; then
    :
  else
    r26_fail 70 "bundle_root_direct_child_validation_failed"
  fi
  [[ "${r26_capture}" == "1" ]] || r26_fail 70 "bundle_root_direct_child_count_${r26_capture}"
  r26_validate_app_tree "signed"
  if r26_current_exec_sha="$(r26_sha "${R26_APP_EXECUTABLE}")"; then :; else r26_fail 70 "bundle_ready_exec_sha_failed"; fi
  if r26_current_bundle_sha="$(r26_tree_manifest_sha "${R26_APP}")"; then :; else r26_fail 70 "bundle_ready_manifest_failed"; fi
  if r26_current_uuid="$(r26_uuid_set "${R26_APP_EXECUTABLE}")"; then :; else r26_fail 70 "bundle_ready_uuid_failed"; fi
  [[ "${r26_current_exec_sha}" == "${R26_SIGNED_EXECUTABLE_SHA}" ]] || r26_fail 70 "bundle_ready_exec_sha_drift"
  [[ "${r26_current_bundle_sha}" == "${R26_SIGNED_BUNDLE_MANIFEST_SHA}" ]] || r26_fail 70 "bundle_ready_manifest_drift"
  [[ "${r26_current_uuid}" == "${R26_SIGNED_UUID_SET}" ]] || r26_fail 70 "bundle_ready_uuid_drift"
  if /usr/bin/codesign --verify --deep --strict --verbose=4 "${R26_APP}" >/dev/null 2>&1; then :; else r26_fail 70 "bundle_ready_codesign_drift"; fi
}

r26_validate_current_roots_phase() {
  case "${R26_CURRENT_ROOT_PHASE}" in
    empty)
      r26_validate_empty_exact_root "${R26_STATE_ROOT}"
      r26_validate_empty_exact_root "${R26_BUNDLE_ROOT}"
      ;;
    bundle_ready)
      r26_validate_empty_exact_root "${R26_STATE_ROOT}"
      r26_validate_bundle_root_ready
      ;;
    preview_live)
      r26_validate_preview_state_tree
      r26_validate_bundle_root_ready
      ;;
    preview_quiescent)
      r26_validate_quiescent_preview_state_tree
      r26_validate_bundle_root_ready
      ;;
    *)
      r26_fail 70 "r26_root_phase_not_observable_${R26_CURRENT_ROOT_PHASE}"
      ;;
  esac
}

r26_capture_r23_roots() {
  local r26_expect_r26="$1"
  local r26_mask=""
  local r26_status_capture=""

  r26_require_private_tmp
  if r26_status_capture="$({
      if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          r23_state="$1"
          r23_bundle="$2"
          r26_state="$3"
          r26_bundle="$4"
          expect_r26="$5"
          state_bit=0
          bundle_bit=0
          r26_state_seen=0
          r26_bundle_seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then
              [[ -z "${path}" ]] || exit 69
              break
            fi
            [[ "${read_rc}" == "0" ]] || exit 70
            case "${path}" in
              /private/tmp/agentloop-r15-state.*|/private/tmp/agentloop-r15-bundle.*)
                exit 68
                ;;
              /private/tmp/agentloop-r19-state.*|/private/tmp/agentloop-r19-bundle.*)
                exit 71
                ;;
              /private/tmp/agentloop-r20-state.*)
                exit 72
                ;;
              /private/tmp/agentloop-r16-state.*|/private/tmp/agentloop-r16-bundle.*|/private/tmp/agentloop-r17-state.*|/private/tmp/agentloop-r17-bundle.*|/private/tmp/agentloop-r18-state.*|/private/tmp/agentloop-r18-bundle.*|/private/tmp/agentloop-r21-state.*|/private/tmp/agentloop-r21-bundle.*|/private/tmp/agentloop-r22-state.*|/private/tmp/agentloop-r22-bundle.*)
                exit 73
                ;;
              /private/tmp/agentloop-r23-state.*)
                [[ "${path}" == "${r23_state}" && "${state_bit}" == "0" ]] || exit 74
                state_bit=1
                ;;
              /private/tmp/agentloop-r23-bundle.*)
                [[ "${path}" == "${r23_bundle}" && "${bundle_bit}" == "0" ]] || exit 75
                bundle_bit=1
                ;;
              /private/tmp/agentloop-r26-state.*)
                [[ "${expect_r26}" == "true" && "${path}" == "${r26_state}" && "${r26_state_seen}" == "0" ]] || exit 76
                r26_state_seen=1
                ;;
              /private/tmp/agentloop-r26-bundle.*)
                [[ "${expect_r26}" == "true" && "${path}" == "${r26_bundle}" && "${r26_bundle_seen}" == "0" ]] || exit 77
                r26_bundle_seen=1
                ;;
            esac
          done
          if [[ "${expect_r26}" == "true" ]]; then
            [[ "${r26_state_seen}" == "1" && "${r26_bundle_seen}" == "1" ]] || exit 78
          else
            [[ "${r26_state_seen}" == "0" && "${r26_bundle_seen}" == "0" ]] || exit 79
          fi
          /usr/bin/printf "%s%s\n" "${state_bit}" "${bundle_bit}"
        ' bash "${R26_R23_STATE_ROOT}" "${R26_R23_BUNDLE_ROOT}" "${R26_STATE_ROOT}" "${R26_BUNDLE_ROOT}" "${r26_expect_r26}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 80
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 81
    })"; then
    :
  else
    r26_fail 70 "top_level_root_universe_capture_failed"
  fi
  r26_mask="${r26_status_capture}"
  [[ "${#r26_mask}" == "2" && "${r26_mask}" != *[!01]* ]] || r26_fail 70 "r23_root_mask_invalid_${r26_mask}"
  r26_require_absent_path "${R26_R15_STATE_ROOT}"
  r26_require_absent_path "${R26_R15_BUNDLE_ROOT}"
  if [[ "${r26_mask:0:1}" == "1" ]]; then
    r26_validate_empty_exact_root "${R26_R23_STATE_ROOT}"
  else
    r26_require_absent_path "${R26_R23_STATE_ROOT}"
  fi
  if [[ "${r26_mask:1:1}" == "1" ]]; then
    r26_validate_empty_exact_root "${R26_R23_BUNDLE_ROOT}"
  else
    r26_require_absent_path "${R26_R23_BUNDLE_ROOT}"
  fi
  if [[ "${r26_expect_r26}" == "true" ]]; then
    r26_validate_current_roots_phase
  fi
  /usr/bin/printf '%s\n' "${r26_mask}"
}

r26_capture_r24() {
  local r26_top=""
  local r26_state_bit="0"
  local r26_parent_bit="0"
  local r26_child=""
  local r26_app_bit="0"
  local r26_nodes="000000000000000000000000000000000000"
  local r26_mask=""
  local r26_real=""
  local r26_terminal_child=""
  local r26_manifest=""
  local r26_signature=""
  local r26_cdhash=""

  r26_require_private_tmp
  if r26_top="$({
      if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact_state="$1"
          exact_bundle="$2"
          state_seen=0
          bundle_seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            case "${path}" in
              /private/tmp/agentloop-r24-state.*)
                [[ "${path}" == "${exact_state}" && "${state_seen}" == "0" ]] || exit 71
                state_seen=1
                ;;
              /private/tmp/agentloop-r24-bundle.*)
                [[ "${path}" == "${exact_bundle}" && "${bundle_seen}" == "0" ]] || exit 72
                bundle_seen=1
                ;;
            esac
          done
          /usr/bin/printf "%s%s\n" "${state_seen}" "${bundle_seen}"
        ' bash "${R26_R24_STATE_ROOT}" "${R26_R24_BUNDLE_ROOT}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 73
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 74
    })"; then
    :
  else
    r26_fail 70 "r24_top_level_capture_failed"
  fi
  [[ "${#r26_top}" == "2" && "${r26_top}" != *[!01]* ]] || r26_fail 70 "r24_top_level_mask_invalid_${r26_top}"
  r26_state_bit="${r26_top:0:1}"
  r26_parent_bit="${r26_top:1:1}"

  if [[ "${r26_state_bit}" == "1" ]]; then
    r26_validate_empty_exact_root "${R26_R24_STATE_ROOT}"
  else
    r26_require_absent_path "${R26_R24_STATE_ROOT}"
  fi

  if [[ "${r26_parent_bit}" == "0" ]]; then
    r26_require_absent_path "${R26_R24_BUNDLE_ROOT}"
    r26_require_absent_path "${R26_R24_APP}"
    /usr/bin/printf '%s\n' "${r26_state_bit}00000000000000000000000000000000000000"
    return
  fi

  [[ -d "${R26_R24_BUNDLE_ROOT}" && ! -L "${R26_R24_BUNDLE_ROOT}" ]] || r26_fail 70 "r24_bundle_parent_not_real_directory"
  if r26_real="$(r26_canonical_directory "${R26_R24_BUNDLE_ROOT}")"; then :; else r26_fail 70 "r24_bundle_parent_realpath_failed"; fi
  [[ "${r26_real}" == "${R26_R24_BUNDLE_ROOT}" ]] || r26_fail 70 "r24_bundle_parent_realpath_mismatch"

  if r26_child="$({
      if /usr/bin/find -P "${R26_R24_BUNDLE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact="$1"
          seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${exact}" && "${seen}" == "0" ]] || exit 71
            seen=1
          done
          /usr/bin/printf "%s\n" "${seen}"
        ' bash "${R26_R24_APP}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 72
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 73
    })"; then
    :
  else
    r26_fail 70 "r24_bundle_direct_child_capture_failed"
  fi
  r26_app_bit="${r26_child}"
  [[ "${r26_app_bit}" == "0" || "${r26_app_bit}" == "1" ]] || r26_fail 70 "r24_app_bit_invalid"
  if [[ "${r26_app_bit}" == "0" ]]; then
    r26_require_absent_path "${R26_R24_APP}"
    [[ -d "${R26_R24_BUNDLE_ROOT}" && ! -L "${R26_R24_BUNDLE_ROOT}" ]] || r26_fail 70 "r24_bundle_parent_terminal_bookend"
    /usr/bin/printf '%s\n' "${r26_state_bit}10000000000000000000000000000000000000"
    return
  fi

  [[ -d "${R26_R24_APP}" && ! -L "${R26_R24_APP}" ]] || r26_fail 70 "r24_app_not_real_directory"
  if r26_real="$(r26_canonical_directory "${R26_R24_APP}")"; then :; else r26_fail 70 "r24_app_realpath_failed"; fi
  [[ "${r26_real}" == "${R26_R24_APP}" ]] || r26_fail 70 "r24_app_realpath_mismatch"

  if r26_nodes="$({
      if /usr/bin/find -P "${R26_R24_APP}" -mindepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          app="$1"
          expected=(
            "Contents|d|-"
            "Contents/Info.plist|f|53bb6470fc12b39a5f48ac6d261415acff96cfbc57ffbf4721d3e351d2123277"
            "Contents/MacOS|d|-"
            "Contents/MacOS/AgentLoop|f|0d01c0ee8b658cf68c5463ef70cc68756a69630a5986cf620ad3870097021b05"
            "Contents/Resources|d|-"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle|d|-"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt|d|-"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnDay.png|f|8e3fa4eae64bd933b2119e8609fed3a95621207ff3a40fa4d63de68c40e8d93b"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnNight.png|f|13c402ff5225e87bc3e9dd686a022034f52a4b7004563507ebd9e86cc9999b9b"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideAmber.png|f|3166ee2fbf917c2700913fc0b8e989f09efa49c9d26035412be8bdde6e022a98"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideBlue.png|f|bc59959c81e6957cf6403e79ef48d4f7b543cfb3b6980c1900f6a19de0f1a3a9"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideCoral.png|f|da471a67b32b32a560ef3234ccaf42a66c3ffb403da7c3a8c8de9f7eab709cb3"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideGreen.png|f|2b5c2178fa8ca4ba11b5615347f6029450237c1a3cfa97220dee7da34a6cad70"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePink.png|f|7e424ea3ea38a0d927d9548e53ac7575c18224f24a05fc5163b2aaa505dee409"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePurple.png|f|5a1b90a96720cbb03572babd2d234f8a6e5945a5ae2e650556108ff6185dd2c8"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideTeal.png|f|b5577e1bb6bdb448f25f5078ce534167471dac47b02910e48346fdd08a1fcbc1"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepAmber.png|f|337a18ea9ff0f48d71eb8f799942290d49c17c6e725f614ca93500738fad99d0"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepBlue.png|f|9ca08f0809cdebee7ff5d340494fc85b3df9d9c16cb9d739419c1c9debb18c4b"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepCoral.png|f|73a4cdad14d69ccf25106aba261b36c792ca004634a88e8a2be24ad04ecd306b"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepGreen.png|f|326be64cd3c4b6ac2ff0b2d991c5eff0a7752616a5cf4d8297a1fed6010d7513"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPink.png|f|bbc2145cedc821959420c1a27f50ef1c2454c36c0b11d17f8da43e4259d80444"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPurple.png|f|e9def94b358c6950c5f3168124d7a3563c8f0680e386149d12538ae30a6fcbe3"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepTeal.png|f|7a68441ea798d211b13f9764928332bb4cf1a1607646c55fb0a1f0bfa4773627"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideAmber.png|f|3f8bbbb82fb11e4934efc97018e084e2eab541c97ed25ecc1382996392ac7c8c"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideBlue.png|f|cbf47e2668e19e1ce32b98b6ec1fcc3403f63c358a8dababa3c0da09946f8fb1"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideCoral.png|f|55726ca797194d1c428567426a6b2fae50dc01bb43795dbb7b1aa1c19b532650"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideGreen.png|f|08efff075a883dbbdda94eb3388910bfb7c2c0e042a818bb5696dba3baa6cc8b"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePink.png|f|cd0cf39c9120fbecff1433387ebe4ddcff57a3c468a62b0fb78af29621a15b8e"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePurple.png|f|d31abde4d4e4b70ddf2bdd547226ff81bc808155308aa40430d78e87f8d81c1a"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideTeal.png|f|27926a3f3088a4d570c9acfbf1ba599b6387a16f1bdc0df3dd413eb65c2e5540"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaDay.png|f|35f89d34928e3bba5d68fbc52a55dfa55df6cf586ca867b05b5d1198e1b1d308"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaNight.png|f|fba4f7457df442a55280fa1af7ad03e1443d63c92e47c7fb1efd99196c2a8e25"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureDay.png|f|6d831556ccfcc2d173683375b29579bd75926e6e8668e78bfb311823b3d8966f"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureNight.png|f|0a106a90f04569292e150071dc1649c5fc995dd6921b43f2f8874039d89f6909"
            "Contents/_CodeSignature|d|-"
            "Contents/_CodeSignature/CodeResources|f|4e903bc32534480c4fa8a17490e49c496e655f1827eafbed280d09fc0eb90ae4"
          )
          bits=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${app}/"* ]] || exit 71
            rel="${path#${app}/}"
            found=-1
            index=0
            while [[ "${index}" -lt "${#expected[@]}" ]]; do
              candidate="${expected[${index}]%%|*}"
              if [[ "${candidate}" == "${rel}" ]]; then found="${index}"; break; fi
              index=$((index + 1))
            done
            [[ "${found}" -ge "0" ]] || exit 72
            [[ "${bits[${found}]}" == "0" ]] || exit 73
            entry="${expected[${found}]}"
            rest="${entry#*|}"
            kind="${rest%%|*}"
            expected_sha="${rest#*|}"
            if [[ "${kind}" == "d" ]]; then
              [[ -d "${path}" && ! -L "${path}" ]] || exit 74
            else
              [[ "${kind}" == "f" && -f "${path}" && ! -L "${path}" ]] || exit 75
              if sha_line="$(/usr/bin/shasum -a 256 "${path}")"; then :; else exit 76; fi
              actual_sha="${sha_line%% *}"
              [[ "${actual_sha}" == "${expected_sha}" ]] || exit 77
            fi
            bits[${found}]=1
          done
          for bit in "${bits[@]}"; do /usr/bin/printf "%s" "${bit}"; done
          /usr/bin/printf "\n"
        ' bash "${R26_R24_APP}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 78
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 79
    })"; then
    :
  else
    r26_fail 70 "r24_app_subtree_capture_failed"
  fi
  [[ "${#r26_nodes}" == "36" && "${r26_nodes}" != *[!01]* ]] || r26_fail 70 "r24_node_mask_invalid_${r26_nodes}"

  [[ -d "${R26_R24_BUNDLE_ROOT}" && ! -L "${R26_R24_BUNDLE_ROOT}" ]] || r26_fail 70 "r24_bundle_parent_terminal_bookend"
  [[ -d "${R26_R24_APP}" && ! -L "${R26_R24_APP}" ]] || r26_fail 70 "r24_app_terminal_bookend"
  if r26_real="$(r26_canonical_directory "${R26_R24_BUNDLE_ROOT}")"; then :; else r26_fail 70 "r24_bundle_parent_terminal_realpath_failed"; fi
  [[ "${r26_real}" == "${R26_R24_BUNDLE_ROOT}" ]] || r26_fail 70 "r24_bundle_parent_terminal_realpath_mismatch"
  if r26_real="$(r26_canonical_directory "${R26_R24_APP}")"; then :; else r26_fail 70 "r24_app_terminal_realpath_failed"; fi
  [[ "${r26_real}" == "${R26_R24_APP}" ]] || r26_fail 70 "r24_app_terminal_realpath_mismatch"
  if r26_terminal_child="$({
      if /usr/bin/find -P "${R26_R24_BUNDLE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact="$1"
          seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${exact}" && "${seen}" == "0" ]] || exit 71
            seen=1
          done
          /usr/bin/printf "%s\n" "${seen}"
        ' bash "${R26_R24_APP}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 72
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 73
    })"; then
    :
  else
    r26_fail 70 "r24_terminal_direct_child_capture_failed"
  fi
  [[ "${r26_terminal_child}" == "1" ]] || r26_fail 70 "r24_terminal_direct_child_shape_${r26_terminal_child}"

  if [[ "${r26_nodes}" == "111111111111111111111111111111111111" ]]; then
    if r26_manifest="$(r26_tree_manifest_sha "${R26_R24_APP}")"; then :; else r26_fail 70 "r24_full_manifest_read_failed"; fi
    [[ "${r26_manifest}" == "${R26_EXPECTED_R24_APP_MANIFEST_SHA}" ]] || r26_fail 70 "r24_full_manifest_mismatch"
    r26_require_sha "${R26_EXPECTED_R24_EXECUTABLE_SHA}" "${R26_R24_EXECUTABLE}"
    r26_require_sha "${R26_EXPECTED_R24_INFO_PLIST_SHA}" "${R26_R24_INFO_PLIST}"
    r26_require_sha "${R26_EXPECTED_R24_CODE_RESOURCES_SHA}" "${R26_R24_CODE_RESOURCES}"
    if /usr/bin/codesign --verify --deep --strict --verbose=4 "${R26_R24_APP}" >/dev/null 2>&1; then :; else r26_fail 70 "r24_full_codesign_failed"; fi
    if r26_signature="$(/usr/bin/codesign --display --verbose=4 "${R26_R24_APP}" 2>&1)"; then :; else r26_fail 70 "r24_signature_display_failed"; fi
    if r26_cdhash="$(/usr/bin/awk -F= '$1 == "CDHash" { print $2 }' <<< "${r26_signature}")"; then :; else r26_fail 70 "r24_cdhash_parse_failed"; fi
    [[ "${r26_cdhash}" == "${R26_EXPECTED_R24_CDHASH}" ]] || r26_fail 70 "r24_cdhash_mismatch"
  fi

  r26_mask="${r26_state_bit}11${r26_nodes}"
  [[ "${#r26_mask}" == "39" ]] || r26_fail 70 "r24_capture_mask_length"
  /usr/bin/printf '%s\n' "${r26_mask}"
}

r26_capture_r20() {
  local r26_top=""
  local r26_parent_bit=""
  local r26_child=""
  local r26_app_bit="0"
  local r26_nodes="000000000000000000000000000000000000"
  local r26_real=""
  local r26_mask=""
  local r26_terminal_child=""

  r26_require_private_tmp
  if r26_top="$({
      if /usr/bin/find -P /private/tmp -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact="$1"
          seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            case "${path}" in
              /private/tmp/agentloop-r20-bundle.*)
                [[ "${path}" == "${exact}" && "${seen}" == "0" ]] || exit 71
                seen=1
                ;;
            esac
          done
          /usr/bin/printf "%s\n" "${seen}"
        ' bash "${R26_R20_BUNDLE_ROOT}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 72
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 73
    })"; then
    :
  else
    r26_fail 70 "r20_top_level_capture_failed"
  fi
  r26_parent_bit="${r26_top}"
  [[ "${r26_parent_bit}" == "0" || "${r26_parent_bit}" == "1" ]] || r26_fail 70 "r20_parent_bit_invalid"
  if [[ "${r26_parent_bit}" == "0" ]]; then
    r26_require_absent_path "${R26_R20_BUNDLE_ROOT}"
    r26_require_absent_path "${R26_R20_APP}"
    /usr/bin/printf '%s\n' '00000000000000000000000000000000000000'
    return
  fi

  [[ -d "${R26_R20_BUNDLE_ROOT}" && ! -L "${R26_R20_BUNDLE_ROOT}" ]] || r26_fail 70 "r20_parent_not_directory"
  if r26_real="$(r26_canonical_directory "${R26_R20_BUNDLE_ROOT}")"; then :; else r26_fail 70 "r20_parent_realpath_failed"; fi
  [[ "${r26_real}" == "${R26_R20_BUNDLE_ROOT}" ]] || r26_fail 70 "r20_parent_realpath_mismatch"

  if r26_child="$({
      if /usr/bin/find -P "${R26_R20_BUNDLE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact="$1"
          seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${exact}" && "${seen}" == "0" ]] || exit 71
            seen=1
          done
          /usr/bin/printf "%s\n" "${seen}"
        ' bash "${R26_R20_APP}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 72
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 73
    })"; then
    :
  else
    r26_fail 70 "r20_direct_child_capture_failed"
  fi
  r26_app_bit="${r26_child}"
  [[ "${r26_app_bit}" == "0" || "${r26_app_bit}" == "1" ]] || r26_fail 70 "r20_app_bit_invalid"
  if [[ "${r26_app_bit}" == "0" ]]; then
    r26_require_absent_path "${R26_R20_APP}"
    [[ -d "${R26_R20_BUNDLE_ROOT}" && ! -L "${R26_R20_BUNDLE_ROOT}" ]] || r26_fail 70 "r20_parent_terminal_bookend"
    /usr/bin/printf '%s\n' '10000000000000000000000000000000000000'
    return
  fi

  [[ -d "${R26_R20_APP}" && ! -L "${R26_R20_APP}" ]] || r26_fail 70 "r20_app_not_directory"
  if r26_real="$(r26_canonical_directory "${R26_R20_APP}")"; then :; else r26_fail 70 "r20_app_realpath_failed"; fi
  [[ "${r26_real}" == "${R26_R20_APP}" ]] || r26_fail 70 "r20_app_realpath_mismatch"

  if r26_nodes="$({
      if /usr/bin/find -P "${R26_R20_APP}" -mindepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          app="$1"
          bits=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${app}/"* ]] || exit 71
            rel="${path#${app}/}"
            case "${rel}" in
              Contents) index=0 ;;
              Contents/MacOS) index=2 ;;
              Contents/Resources) index=4 ;;
              Contents/Resources/AgentLoop_AgentLoopApp.bundle) index=5 ;;
              Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt) index=6 ;;
              Contents/_CodeSignature) index=34 ;;
              *) exit 72 ;;
            esac
            [[ "${bits[${index}]}" == "0" ]] || exit 73
            [[ -d "${path}" && ! -L "${path}" ]] || exit 74
            bits[${index}]=1
          done
          for bit in "${bits[@]}"; do /usr/bin/printf "%s" "${bit}"; done
          /usr/bin/printf "\n"
        ' bash "${R26_R20_APP}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 75
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 76
    })"; then
    :
  else
    r26_fail 70 "r20_subtree_capture_failed"
  fi
  [[ "${#r26_nodes}" == "36" && "${r26_nodes}" != *[!01]* ]] || r26_fail 70 "r20_node_mask_invalid_${r26_nodes}"

  [[ -d "${R26_R20_BUNDLE_ROOT}" && ! -L "${R26_R20_BUNDLE_ROOT}" ]] || r26_fail 70 "r20_parent_terminal_bookend"
  [[ -d "${R26_R20_APP}" && ! -L "${R26_R20_APP}" ]] || r26_fail 70 "r20_app_terminal_bookend"
  if r26_real="$(r26_canonical_directory "${R26_R20_BUNDLE_ROOT}")"; then :; else r26_fail 70 "r20_parent_terminal_realpath_failed"; fi
  [[ "${r26_real}" == "${R26_R20_BUNDLE_ROOT}" ]] || r26_fail 70 "r20_parent_terminal_realpath_mismatch"
  if r26_real="$(r26_canonical_directory "${R26_R20_APP}")"; then :; else r26_fail 70 "r20_app_terminal_realpath_failed"; fi
  [[ "${r26_real}" == "${R26_R20_APP}" ]] || r26_fail 70 "r20_app_terminal_realpath_mismatch"
  if r26_terminal_child="$({
      if /usr/bin/find -P "${R26_R20_BUNDLE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          exact="$1"
          seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 69; break; fi
            [[ "${read_rc}" == "0" ]] || exit 70
            [[ "${path}" == "${exact}" && "${seen}" == "0" ]] || exit 71
            seen=1
          done
          /usr/bin/printf "%s\n" "${seen}"
        ' bash "${R26_R20_APP}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 72
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 73
    })"; then
    :
  else
    r26_fail 70 "r20_terminal_direct_child_capture_failed"
  fi
  [[ "${r26_terminal_child}" == "1" ]] || r26_fail 70 "r20_terminal_direct_child_shape_${r26_terminal_child}"

  r26_mask="11${r26_nodes}"
  /usr/bin/printf '%s\n' "${r26_mask}"
}

# R25 roots are historical contaminated evidence. Observe only the two root
# path entries themselves. Never enter, enumerate, hash, open, or clean either
# root or any descendant; in particular, never open the WAL-mode database.
r26_capture_r25_roots_coarse() {
  /usr/bin/python3 - "${R26_R25_STATE_ROOT}" "${R26_R25_BUNDLE_ROOT}" <<'R26_R25_COARSE_LSTAT'
import os
import stat
import sys

mask = []
for path in sys.argv[1:]:
    try:
        metadata = os.lstat(path)
    except FileNotFoundError:
        mask.append("0")
        continue
    except OSError:
        raise SystemExit(71)
    if stat.S_ISLNK(metadata.st_mode):
        raise SystemExit(72)
    if not stat.S_ISDIR(metadata.st_mode):
        raise SystemExit(73)
    mask.append("1")
if len(mask) != 2:
    raise SystemExit(74)
print("".join(mask))
R26_R25_COARSE_LSTAT
}

r26_compare_erosion() {
  local r26_from="$1"
  local r26_to="$2"
  local r26_label="$3"
  local r26_index=0
  local r26_from_bit=""
  local r26_to_bit=""
  [[ "${#r26_from}" == "${#r26_to}" ]] || r26_fail 70 "erosion_length_${r26_label}"
  while (( r26_index < ${#r26_from} )); do
    r26_from_bit="${r26_from:r26_index:1}"
    r26_to_bit="${r26_to:r26_index:1}"
    [[ "${r26_from_bit}" == "0" || "${r26_from_bit}" == "1" ]] || r26_fail 70 "erosion_from_bit_${r26_label}_${r26_index}"
    [[ "${r26_to_bit}" == "0" || "${r26_to_bit}" == "1" ]] || r26_fail 70 "erosion_to_bit_${r26_label}_${r26_index}"
    [[ "${r26_from_bit}${r26_to_bit}" != "01" ]] || r26_fail 70 "erosion_reappearance_${r26_label}_bit_${r26_index}"
    r26_index=$((r26_index + 1))
  done
}

r26_observe_lifecycles() {
  local r26_label="$1"
  local r26_expect_r26="$2"
  local r26_r23_a=""
  local r26_r23_b=""
  local r26_r24_a=""
  local r26_r24_b=""
  local r26_r25_a=""
  local r26_r25_b=""
  local r26_r20_a=""
  local r26_r20_b=""
  local r26_pair_r23_from="${R26_R23_LATEST_MASK}"
  local r26_pair_r24_from="${R26_R24_LATEST_MASK}"
  local r26_pair_r25_from="${R26_R25_LATEST_MASK}"
  local r26_pair_r20_from="${R26_R20_LATEST_MASK}"
  local r26_r23_transition="UNCHANGED"
  local r26_r24_transition="UNCHANGED"
  local r26_r25_transition="UNCHANGED"
  local r26_r20_transition="UNCHANGED"
  local r26_r23_disappearance_cause="NOT_OBSERVED"
  local r26_r24_disappearance_cause="NOT_OBSERVED"
  local r26_r25_disappearance_cause="NOT_OBSERVED"
  local r26_r20_disappearance_cause="NOT_OBSERVED"

  r26_require_r15_tombstone_universe
  if r26_r23_a="$(r26_capture_r23_roots "${r26_expect_r26}")"; then :; else r26_fail 70 "r23_capture_a_${r26_label}"; fi
  if r26_r24_a="$(r26_capture_r24)"; then :; else r26_fail 70 "r24_capture_a_${r26_label}"; fi
  if r26_r25_a="$(r26_capture_r25_roots_coarse)"; then :; else r26_fail 70 "r25_coarse_capture_a_${r26_label}"; fi
  if r26_r20_a="$(r26_capture_r20)"; then :; else r26_fail 70 "r20_capture_a_${r26_label}"; fi
  if r26_r23_b="$(r26_capture_r23_roots "${r26_expect_r26}")"; then :; else r26_fail 70 "r23_capture_b_${r26_label}"; fi
  if r26_r24_b="$(r26_capture_r24)"; then :; else r26_fail 70 "r24_capture_b_${r26_label}"; fi
  if r26_r25_b="$(r26_capture_r25_roots_coarse)"; then :; else r26_fail 70 "r25_coarse_capture_b_${r26_label}"; fi
  if r26_r20_b="$(r26_capture_r20)"; then :; else r26_fail 70 "r20_capture_b_${r26_label}"; fi
  r26_require_r15_tombstone_universe

  r26_compare_erosion "${r26_pair_r23_from}" "${r26_r23_a}" "r23_${r26_label}_LATEST_to_A"
  r26_compare_erosion "${r26_r23_a}" "${r26_r23_b}" "r23_${r26_label}_A_to_B"
  r26_compare_erosion "${r26_pair_r24_from}" "${r26_r24_a}" "r24_${r26_label}_LATEST_to_A"
  r26_compare_erosion "${r26_r24_a}" "${r26_r24_b}" "r24_${r26_label}_A_to_B"
  r26_compare_erosion "${r26_pair_r25_from}" "${r26_r25_a}" "r25_${r26_label}_LATEST_to_A"
  r26_compare_erosion "${r26_r25_a}" "${r26_r25_b}" "r25_${r26_label}_A_to_B"
  r26_compare_erosion "${r26_pair_r20_from}" "${r26_r20_a}" "r20_${r26_label}_LATEST_to_A"
  r26_compare_erosion "${r26_r20_a}" "${r26_r20_b}" "r20_${r26_label}_A_to_B"
  if [[ "${r26_pair_r23_from}" != "${r26_r23_b}" ]]; then
    r26_r23_transition="ERODED"
    r26_r23_disappearance_cause="UNKNOWN"
  fi
  if [[ "${r26_pair_r24_from}" != "${r26_r24_b}" ]]; then
    r26_r24_transition="ERODED"
    r26_r24_disappearance_cause="UNKNOWN"
  fi
  if [[ "${r26_pair_r25_from}" != "${r26_r25_b}" ]]; then
    r26_r25_transition="ERODED"
    r26_r25_disappearance_cause="UNKNOWN"
  fi
  if [[ "${r26_pair_r20_from}" != "${r26_r20_b}" ]]; then
    r26_r20_transition="ERODED"
    r26_r20_disappearance_cause="UNKNOWN"
  fi

  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  if [[ -z "${R26_R23_FIRST_MASK}" ]]; then R26_R23_FIRST_MASK="${r26_r23_a}"; fi
  R26_R23_LATEST_MASK="${r26_r23_b}"
  R26_R23_ACCEPTED_MODE_B="${r26_r23_b}"
  if [[ -z "${R26_R24_FIRST_MASK}" ]]; then R26_R24_FIRST_MASK="${r26_r24_a}"; fi
  R26_R24_LATEST_MASK="${r26_r24_b}"
  R26_R24_ACCEPTED_MODE_B="${r26_r24_b}"
  if [[ -z "${R26_R25_FIRST_MASK}" ]]; then R26_R25_FIRST_MASK="${r26_r25_a}"; fi
  R26_R25_LATEST_MASK="${r26_r25_b}"
  R26_R25_ACCEPTED_MODE_B="${r26_r25_b}"
  if [[ -z "${R26_R20_FIRST_MASK}" ]]; then R26_R20_FIRST_MASK="${r26_r20_a}"; fi
  R26_R20_LATEST_MASK="${r26_r20_b}"
  R26_R20_ACCEPTED_MODE_B="${r26_r20_b}"
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then
    r26_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_${r26_label}"
  fi

  if [[ "${R26_BOUNDARY_ACTIVE}" == "true" ]]; then
    {
      /usr/bin/printf 'lifecycle_label=%s\n' "${r26_label}"
      /usr/bin/printf 'r23_capture_a=%s\n' "${r26_r23_a}"
      /usr/bin/printf 'r23_capture_b=%s\n' "${r26_r23_b}"
      /usr/bin/printf 'r23_first_mask=%s\n' "${R26_R23_FIRST_MASK}"
      /usr/bin/printf 'r23_latest_mask=%s\n' "${R26_R23_LATEST_MASK}"
      /usr/bin/printf 'r23_accepted_mode_b=%s\n' "${R26_R23_ACCEPTED_MODE_B}"
      /usr/bin/printf 'r23_transition=%s\n' "${r26_r23_transition}"
      /usr/bin/printf 'r23_disappearance_cause=%s\n' "${r26_r23_disappearance_cause}"
      /usr/bin/printf 'r24_capture_a=%s\n' "${r26_r24_a}"
      /usr/bin/printf 'r24_capture_b=%s\n' "${r26_r24_b}"
      /usr/bin/printf 'r24_first_mask=%s\n' "${R26_R24_FIRST_MASK}"
      /usr/bin/printf 'r24_latest_mask=%s\n' "${R26_R24_LATEST_MASK}"
      /usr/bin/printf 'r24_accepted_mode_b=%s\n' "${R26_R24_ACCEPTED_MODE_B}"
      /usr/bin/printf 'r24_transition=%s\n' "${r26_r24_transition}"
      /usr/bin/printf 'r24_disappearance_cause=%s\n' "${r26_r24_disappearance_cause}"
      /usr/bin/printf 'r25_capture_mode=coarse_root_entries_only_no_descendant_access\n'
      /usr/bin/printf 'r25_state_class=POST_REJECTION_READ_PROBE_CONTAMINATED\n'
      /usr/bin/printf 'r25_capture_a=%s\n' "${r26_r25_a}"
      /usr/bin/printf 'r25_capture_b=%s\n' "${r26_r25_b}"
      /usr/bin/printf 'r25_first_mask=%s\n' "${R26_R25_FIRST_MASK}"
      /usr/bin/printf 'r25_latest_mask=%s\n' "${R26_R25_LATEST_MASK}"
      /usr/bin/printf 'r25_accepted_mode_b=%s\n' "${R26_R25_ACCEPTED_MODE_B}"
      /usr/bin/printf 'r25_transition=%s\n' "${r26_r25_transition}"
      /usr/bin/printf 'r25_disappearance_cause=%s\n' "${r26_r25_disappearance_cause}"
      /usr/bin/printf 'r20_capture_a=%s\n' "${r26_r20_a}"
      /usr/bin/printf 'r20_capture_b=%s\n' "${r26_r20_b}"
      /usr/bin/printf 'r20_first_mask=%s\n' "${R26_R20_FIRST_MASK}"
      /usr/bin/printf 'r20_latest_mask=%s\n' "${R26_R20_LATEST_MASK}"
      /usr/bin/printf 'r20_accepted_mode_b=%s\n' "${R26_R20_ACCEPTED_MODE_B}"
      /usr/bin/printf 'r20_transition=%s\n' "${r26_r20_transition}"
      /usr/bin/printf 'r20_disappearance_cause=%s\n' "${r26_r20_disappearance_cause}"
    } >> "${R26_BOUNDARY_LOG}"
  fi
}

r26_exclusive_create_empty() {
  local r26_path="$1"
  local r26_old_noclobber="false"
  case "$-" in *C*) r26_old_noclobber="true" ;; esac
  set -C
  if : > "${r26_path}"; then
    if [[ "${r26_old_noclobber}" != "true" ]]; then set +C; fi
    return 0
  fi
  if [[ "${r26_old_noclobber}" != "true" ]]; then set +C; fi
  return 1
}

r26_create_runtime_evidence() {
  local r26_path=""
  R26_PHASE="activation_hash_log"
  r26_exclusive_create_empty "${R26_HASH_LOG}" || r26_active_fail 71 "exclusive_create_failed_${R26_HASH_LOG}"
  for r26_path in \
    "${R26_TASK_DIRECTORY}/r26-targeted-tests.log" \
    "${R26_VERIFY_LOG}" \
    "${R26_TASK_DIRECTORY}/r26-build.log" \
    "${R26_TASK_DIRECTORY}/r26-migration-matrix.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-bundle-provenance.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-source-gates.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-preview-bootstrap.log" \
    "${R26_TASK_DIRECTORY}/evidence/r26-preview-cold-start.log"; do
    r26_exclusive_create_empty "${r26_path}" || r26_active_fail 71 "exclusive_create_failed_${r26_path}"
  done
}

r26_require_verify_log_identity() {
  local r26_label="$1"
  local r26_sha_before=""
  local r26_sha_after=""
  local r26_bytes_before=""
  local r26_bytes_after=""
  [[ "${R26_VERIFY_LOG_SHA}" != "UNKNOWN" && "${R26_VERIFY_LOG_BYTES}" != "UNKNOWN" ]] || r26_active_fail 70 "verify_identity_not_committed_${r26_label}"
  r26_require_regular_file "${R26_VERIFY_LOG}"
  if r26_sha_before="$(r26_sha "${R26_VERIFY_LOG}")"; then :; else r26_active_fail 70 "verify_sha_before_failed_${r26_label}"; fi
  if r26_bytes_before="$(/usr/bin/stat -f '%z' "${R26_VERIFY_LOG}")"; then :; else r26_active_fail 70 "verify_bytes_before_failed_${r26_label}"; fi
  r26_require_regular_file "${R26_VERIFY_LOG}"
  if r26_sha_after="$(r26_sha "${R26_VERIFY_LOG}")"; then :; else r26_active_fail 70 "verify_sha_after_failed_${r26_label}"; fi
  if r26_bytes_after="$(/usr/bin/stat -f '%z' "${R26_VERIFY_LOG}")"; then :; else r26_active_fail 70 "verify_bytes_after_failed_${r26_label}"; fi
  [[ "${r26_sha_before}" == "${R26_VERIFY_LOG_SHA}" && "${r26_sha_after}" == "${R26_VERIFY_LOG_SHA}" ]] || r26_active_fail 70 "verify_sha_drift_${r26_label}"
  [[ "${r26_bytes_before}" == "${R26_VERIFY_LOG_BYTES}" && "${r26_bytes_after}" == "${R26_VERIFY_LOG_BYTES}" ]] || r26_active_fail 70 "verify_bytes_drift_${r26_label}"
}

r26_run_authoritative_full_test() {
  local r26_pipeline_status=()
  local r26_terminal_count=""
  local r26_working_directory=""
  local r26_verify_sha=""
  local r26_verify_bytes=""

  R26_PHASE="authoritative_full_test"
  [[ -f "${R26_VERIFY_LOG}" && ! -L "${R26_VERIFY_LOG}" && ! -s "${R26_VERIFY_LOG}" ]] || r26_active_fail 70 "authoritative_verify_log_not_fresh_empty_regular"
  cd -P "${R26_REPOSITORY_ROOT}"
  if r26_working_directory="$(pwd -P)"; then :; else r26_active_fail 70 "authoritative_pwd_failed"; fi
  [[ "${r26_working_directory}" == "${R26_REPOSITORY_ROOT}" ]] || r26_active_fail 70 "authoritative_cwd_mismatch_${r26_working_directory}"
  R26_AUTHORITATIVE_SWIFT_RC="UNKNOWN"
  R26_AUTHORITATIVE_TEE_RC="UNKNOWN"
  R26_AUTHORITATIVE_STATUS_CAPTURED="false"
  if /usr/bin/swift run RunTests 2>&1 | /usr/bin/tee "${R26_VERIFY_LOG}"; then
    r26_pipeline_status=("${PIPESTATUS[@]}")
  else
    r26_pipeline_status=("${PIPESTATUS[@]}")
  fi
  [[ "${#r26_pipeline_status[@]}" == "2" ]] || r26_active_fail 70 "authoritative_PIPESTATUS_cardinality_${#r26_pipeline_status[@]}"
  case "${r26_pipeline_status[0]}" in ''|*[!0-9]*) r26_active_fail 70 "authoritative_swift_status_not_numeric" ;; esac
  case "${r26_pipeline_status[1]}" in ''|*[!0-9]*) r26_active_fail 70 "authoritative_tee_status_not_numeric" ;; esac
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  R26_AUTHORITATIVE_SWIFT_RC="${r26_pipeline_status[0]}"
  R26_AUTHORITATIVE_TEE_RC="${r26_pipeline_status[1]}"
  R26_AUTHORITATIVE_STATUS_CAPTURED="true"
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then
    r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_authoritative_status_commit"
  fi
  [[ -f "${R26_VERIFY_LOG}" && ! -L "${R26_VERIFY_LOG}" ]] || r26_active_fail 70 "authoritative_verify_log_terminal_type"
  {
    /usr/bin/printf '%s\n' 'authoritative_test_invocation_count=1'
    /usr/bin/printf '%s\n' 'authoritative_test_filter=none'
    /usr/bin/printf '%s\n' 'authoritative_host_shell_dependency=false'
    /usr/bin/printf '%s\n' 'authoritative_capture_shell=/bin/bash_3.2'
    /usr/bin/printf 'authoritative_status_captured=%s\n' "${R26_AUTHORITATIVE_STATUS_CAPTURED}"
    /usr/bin/printf 'authoritative_swift_rc=%s\n' "${R26_AUTHORITATIVE_SWIFT_RC}"
    /usr/bin/printf 'authoritative_tee_rc=%s\n' "${R26_AUTHORITATIVE_TEE_RC}"
  } >> "${R26_BOUNDARY_LOG}"
  [[ "${R26_AUTHORITATIVE_SWIFT_RC}" == "0" ]] || r26_active_fail "${R26_AUTHORITATIVE_SWIFT_RC}" "authoritative_swift_failed"
  [[ "${R26_AUTHORITATIVE_TEE_RC}" == "0" ]] || r26_active_fail "${R26_AUTHORITATIVE_TEE_RC}" "authoritative_tee_failed"
  if r26_terminal_count="$(/usr/bin/awk '$0 ~ /^.*Test run with 652 tests in 7 suites passed after [0-9.]+ seconds\.$/ { count += 1 } END { print count + 0 }' "${R26_VERIFY_LOG}")"; then
    :
  else
    r26_active_fail 70 "authoritative_terminal_summary_scan_failed"
  fi
  [[ "${r26_terminal_count}" == "1" ]] || r26_active_fail 70 "authoritative_terminal_summary_count_${r26_terminal_count}"
  if r26_verify_sha="$(r26_sha "${R26_VERIFY_LOG}")"; then :; else r26_active_fail 70 "authoritative_verify_sha_failed"; fi
  if r26_verify_bytes="$(/usr/bin/stat -f '%z' "${R26_VERIFY_LOG}")"; then :; else r26_active_fail 70 "authoritative_verify_size_failed"; fi
  case "${r26_verify_bytes}" in ''|*[!0-9]*) r26_active_fail 70 "authoritative_verify_size_not_numeric" ;; esac
  [[ "${r26_verify_bytes}" != "0" ]] || r26_active_fail 70 "authoritative_verify_log_empty"
  R26_VERIFY_LOG_SHA="${r26_verify_sha}"
  R26_VERIFY_LOG_BYTES="${r26_verify_bytes}"
  r26_append_boundary 'authoritative_log_terminal_summary=652_of_652_pass'
  r26_append_boundary 'authoritative_pipeline_status=CAPTURED_BOTH_ZERO'
  r26_append_boundary "authoritative_verify_log_sha=${R26_VERIFY_LOG_SHA}"
  r26_append_boundary "authoritative_verify_log_bytes=${R26_VERIFY_LOG_BYTES}"
  r26_append_boundary 'status=AUTHORITATIVE_FULL_TEST_ATTESTED'
  r26_require_verify_log_identity "authoritative_terminal_adjacent"
}

r26_run_same_log_targeted_audit() {
  local r26_name=""
  local r26_joined_names=""
  local r26_audit_output=""
  local r26_audit_status=""
  local r26_now_value=""
  local r26_name_index=0
  R26_REQUIRED_TEST_NAMES=(
    ruminationStartAndWorkAreAtomic
    ruminationCrashIsAdoptedAndCompletesOnce
    ruminationFailurePersistenceFailureRemainsRecoverable
    ruminationCancelRejectsStaleResponse
    legacyRuminatingRowGetsOneRepairWork
    repeatedRuminationCommandReturnsExistingWork
    ruminationCancelAndQueuedProjectionRollbackTogether
    ruminationAttemptClosesExactlyOnce
    ruminationWorkInputUsesCanonicalCapturedIdentityAndFirstTrace
    ruminationSameKeyDifferentCapturedIdentityConflictsWithoutResolution
    ruminationTerminalRetryCreatesReplacementWhileActiveReplayReusesWork
    ruminationCapturedProfileAndModelIgnoreDefaultDrift
    ruminationClaimResolutionFailureMatrixIsStableSafeAndFailClosed
    ruminationResolverNeverFallsBackToCurrentDefaultOrCompanion
    ruminationTransientFailureRetriesAtFiveThirtyOneTwentyThenTerminates
    ruminationDeterministicFailureDoesNotRetry
    ruminationTerminalFailureAndProjectionCommitOrRollbackTogether
    ruminationSuccessResultProjectionAndWorkCommitOrRollbackTogether
    ruminationLeaseRenewalAllowsOnlyLatestClaimToCommit
    ruminationTerminalCommitFailureRetainsProposalAndDoesNotRecallProvider
    ruminationProcessRestartMayRecallProviderButCommitsOneResultAndTerminal
    ruminationEmergencyHaltCancelsWorkAndQueuesProjectionAtomically
    ruminationEmergencyHaltRejectsClaimResolveAndProviderDispatch
    ruminationLateProviderResponseCannotOverrideEmergencyHalt
    ruminationResumeDoesNotReviveCanceledWork
    ruminationWaitUntilIdleIncludesDueRuminationAndIgnoresFutureRetry
    ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal
    legacyRuminationWithoutResolvableRuntimeFailsSafelyExactlyOnce
    ruminationSanitizesPersistedAndVisibleDiagnostics
    ruminationInvalidOutputIsDeterministicAndPreservesSource
    ruminationProviderUsesNoToolsAndProducesOneCanonicalResult
    singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle
    ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask
    ruminationUnknownRestartRendersRecoveringWithoutInventingReading
    ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents
    genericDurableWorkAPIsSealRuminationWithExactPriority
    supervisedWorkPumpIsGlobalFIFOWithoutPlanningRegression
    ruminationStartupRemainsSuppressedUntilOrchestratorActivation
    legacyRuminationRepairCoversValidHaltedAndEveryTerminalReason
    ruminationUsageIsExactOrFailsBeforeAccounting
    activeRuminationFencesDiscardDeleteAndArchiveRaces
    slowActiveStreamDoesNotIdleTimeout
    turnTimeoutRetriesOnceThenBlocks
    timeoutThenSuccessDoesNotAccumulate
    cancelWinsOverIdleTimeout
    turnCompletesUnderTimeout
  )
  [[ "${#R26_REQUIRED_TEST_NAMES[@]}" == "46" ]] || r26_active_fail 70 "targeted_name_array_count"
  for r26_name in "${R26_REQUIRED_TEST_NAMES[@]}"; do
    if [[ "${r26_name_index}" == "0" ]]; then
      r26_joined_names="${r26_name}"
    else
      r26_joined_names="${r26_joined_names}|${r26_name}"
    fi
    r26_name_index=$((r26_name_index + 1))
  done
  r26_require_verify_log_identity "targeted_reader_pre"
  if r26_audit_output="$(/usr/bin/awk -v joined="${r26_joined_names}" '
      BEGIN { n = split(joined, names, "|"); ok = 1 }
      {
        if ($0 != "") last = $0
        if ($0 == "◇ Test run started.") run_started += 1
        if ($0 ~ /^◇ Test .*\(\) started\.$/) test_started += 1
        if ($0 ~ /^✔ Test .*\(\) passed after [0-9.]+ seconds\.$/) test_passed += 1
        if ($0 ~ /^◇ Suite .* started\.$/) suite_started += 1
        if ($0 ~ /^✔ Suite .* passed after [0-9.]+ seconds\.$/) suite_passed += 1
        if ($0 ~ /^✘ /) failure_markers += 1
        if ($0 ~ /^✔ Test run with 652 tests in 7 suites passed after [0-9.]+ seconds\.$/) summary += 1
        for (i = 1; i <= n; i += 1) {
          if ($0 == "◇ Test " names[i] "() started.") discovery[i] += 1
          if ($0 ~ ("^✔ Test " names[i] "\\(\\) passed after [0-9.]+ seconds\\.$")) passed[i] += 1
          if ($0 ~ ("^✘ Test " names[i] "\\(\\)")) failed[i] += 1
        }
      }
      END {
        if (n != 46 || run_started != 1 || test_started != 652 || test_passed != 652 ||
            suite_started != 7 || suite_passed != 7 || failure_markers != 0 || summary != 1 ||
            last !~ /^✔ Test run with 652 tests in 7 suites passed after [0-9.]+ seconds\.$/) ok = 0
        print "captured_run_started_count=" (run_started + 0)
        print "full_test_discovery_count=" (test_started + 0)
        print "full_test_pass_count=" (test_passed + 0)
        print "full_suite_start_count=" (suite_started + 0)
        print "full_suite_pass_count=" (suite_passed + 0)
        print "full_failure_marker_count=" (failure_markers + 0)
        print "full_summary_count=" (summary + 0)
        print "full_summary_is_last_nonempty_line=" (last ~ /^✔ Test run with 652 tests in 7 suites passed after [0-9.]+ seconds\.$/ ? "true" : "false")
        print "required_name_count=" n
        discovery_total = 0; pass_total = 0
        for (i = 1; i <= n; i += 1) {
          discovery_total += discovery[i]; pass_total += passed[i]
          if (discovery[i] != 1 || passed[i] != 1 || failed[i] != 0) ok = 0
          print "name=" names[i] " discovery=" (discovery[i] + 0) " pass=" (passed[i] + 0) " failure=" (failed[i] + 0)
        }
        print "required_discovery_total=" discovery_total
        print "required_pass_total=" pass_total
        print "status=" (ok ? "PASS" : "FAIL")
      }
    ' "${R26_VERIFY_LOG}")"; then
    :
  else
    r26_active_fail 70 "targeted_audit_awk_failed"
  fi
  r26_require_verify_log_identity "targeted_reader_post"
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "targeted_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'format=r26-targeted-tests-v1'
    /usr/bin/printf 'utc=%s\n' "${r26_now_value}"
    /usr/bin/printf 'source_log=%s\n' "${R26_VERIFY_LOG}"
    /usr/bin/printf 'source_sha256=%s\n' "${R26_VERIFY_LOG_SHA}"
    /usr/bin/printf 'source_bytes=%s\n' "${R26_VERIFY_LOG_BYTES}"
    /usr/bin/printf '%s\n' 'authoritative_command=swift run RunTests'
    /usr/bin/printf '%s\n' 'authoritative_unfiltered=true'
    /usr/bin/printf '%s\n' 'authoritative_single_invocation=true'
    /usr/bin/printf '%s\n' "${r26_audit_output}"
  } >> "${R26_TARGETED_LOG}"
  if r26_audit_status="$(r26_exact_line_count "${R26_TARGETED_LOG}" 'status=PASS')"; then :; else r26_active_fail 70 "targeted_status_read_failed"; fi
  [[ "${r26_audit_status}" == "1" ]] || r26_active_fail 70 "targeted_audit_not_pass"
  r26_require_verify_log_identity "targeted_transition_adjacent"
  r26_append_boundary 'same_log_targeted_audit=46_of_46_pass'
}

r26_tree_manifest_sha() {
  local r26_tree="$1"
  local r26_manifest_output=""
  [[ -d "${r26_tree}" && ! -L "${r26_tree}" ]] || return 70
  if r26_manifest_output="$({
      cd -P "${r26_tree}" || exit 71
      if /usr/bin/find -P . -type f -print0 |
        /usr/bin/sort -z |
        /usr/bin/xargs -0 /usr/bin/shasum -a 256 |
        /usr/bin/sed 's#  \./#  #' |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "6" ]] || exit 72
      for r26_rc in "${r26_status[@]}"; do [[ "${r26_rc}" == "0" ]] || exit 73; done
    })"; then
    :
  else
    return "$?"
  fi
  [[ "${#r26_manifest_output}" == "64" && "${r26_manifest_output}" != *[!0-9a-f]* ]] || return 74
  /usr/bin/printf '%s\n' "${r26_manifest_output}"
}

r26_uuid_set() {
  local r26_binary="$1"
  local r26_uuid_output=""
  r26_require_regular_file "${r26_binary}"
  if r26_uuid_output="$({
      if /usr/bin/dwarfdump --uuid "${r26_binary}" |
        /usr/bin/awk '/^UUID: / { gsub(/[()]/, "", $3); print $2 "|" $3 }' |
        /usr/bin/sort; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "3" ]] || exit 71
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" && "${r26_status[2]}" == "0" ]] || exit 72
    })"; then
    :
  else
    return "$?"
  fi
  [[ -n "${r26_uuid_output}" ]] || return 73
  /usr/bin/printf '%s\n' "${r26_uuid_output}"
}

r26_validate_ranch_art_tree() {
  local r26_tree="$1"
  local r26_capture=""
  local r26_manifest=""
  [[ -d "${r26_tree}" && ! -L "${r26_tree}" ]] || r26_active_fail 70 "ranch_art_not_real_directory_${r26_tree}"
  if r26_capture="$({
      if /usr/bin/find -P "${r26_tree}" -mindepth 1 -maxdepth 1 -print0 |
        /bin/bash --noprofile --norc -c '
          set -u
          count=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ -f "${path}" && ! -L "${path}" ]] || exit 73
            count=$((count + 1))
          done
          /usr/bin/printf "%s\n" "${count}"
        '; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 74
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 75
    })"; then
    :
  else
    r26_active_fail 70 "ranch_art_tree_drain_failed_${r26_tree}"
  fi
  [[ "${r26_capture}" == "27" ]] || r26_active_fail 70 "ranch_art_count_${r26_tree}_${r26_capture}"
  if r26_manifest="$(r26_tree_manifest_sha "${r26_tree}")"; then :; else r26_active_fail 70 "ranch_art_manifest_failed_${r26_tree}"; fi
  [[ "${r26_manifest}" == "${R26_EXPECTED_RANCH_ART_MANIFEST_SHA}" ]] || r26_active_fail 70 "ranch_art_manifest_mismatch_${r26_tree}"
}

r26_validate_app_tree() {
  local r26_mode="$1"
  local r26_capture=""
  local r26_expected_count=""
  case "${r26_mode}" in
    unsigned) r26_expected_count="34" ;;
    signed) r26_expected_count="36" ;;
    *) r26_active_fail 70 "invalid_app_tree_mode_${r26_mode}" ;;
  esac
  if r26_capture="$({
      if /usr/bin/find -P "${R26_APP}" -mindepth 1 -print0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          app="$1"
          mode="$2"
          expected=(
            "Contents"
            "Contents/Info.plist"
            "Contents/MacOS"
            "Contents/MacOS/AgentLoop"
            "Contents/Resources"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnDay.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelBarnNight.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideAmber.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideBlue.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideCoral.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideGreen.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePink.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSidePurple.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSideTeal.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepAmber.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepBlue.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepCoral.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepGreen.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPink.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepPurple.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowSleepTeal.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideAmber.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideBlue.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideCoral.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideGreen.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePink.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStridePurple.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelCowStrideTeal.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaDay.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPanoramaNight.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureDay.png"
            "Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt/PixelPastureNight.png"
          )
          if [[ "${mode}" == "signed" ]]; then
            expected+=("Contents/_CodeSignature" "Contents/_CodeSignature/CodeResources")
          fi
          index=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 71; break; fi
            [[ "${read_rc}" == "0" ]] || exit 72
            [[ "${index}" -lt "${#expected[@]}" ]] || exit 73
            rel="${path#${app}/}"
            [[ "${rel}" == "${expected[${index}]}" ]] || exit 74
            case "${rel}" in
              Contents|Contents/MacOS|Contents/Resources|Contents/Resources/AgentLoop_AgentLoopApp.bundle|Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt|Contents/_CodeSignature)
                [[ -d "${path}" && ! -L "${path}" ]] || exit 75 ;;
              *) [[ -f "${path}" && ! -L "${path}" ]] || exit 76 ;;
            esac
            index=$((index + 1))
          done
          [[ "${index}" == "${#expected[@]}" ]] || exit 77
          /usr/bin/printf "%s\n" "${index}"
        ' bash "${R26_APP}" "${r26_mode}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "3" ]] || exit 78
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" && "${r26_status[2]}" == "0" ]] || exit 79
    })"; then
    :
  else
    r26_active_fail 70 "app_tree_validation_failed_${r26_mode}"
  fi
  [[ "${r26_capture}" == "${r26_expected_count}" ]] || r26_active_fail 70 "app_tree_count_${r26_mode}_${r26_capture}"
}

r26_run_debug_build_and_bundle() {
  local r26_build_status=()
  local r26_bin_dir=""
  local r26_bin_real=""
  local r26_bin_component=""
  local r26_resource_manifest=""
  local r26_copied_resource_manifest=""
  local r26_info_sha=""
  local r26_plist_exec=""
  local r26_plist_identifier=""
  local r26_ls_state=""
  local r26_ls_preview=""
  local r26_unsigned_sha=""
  local r26_unsigned_uuid=""
  local r26_signature_detail=""
  local r26_entitlements=""
  local r26_cdhash=""
  local r26_now_value=""
  local r26_app_real=""
  local r26_exec_real=""

  R26_PHASE="debug_app_build"
  r26_require_verify_log_identity "pre_debug_build"
  if /usr/bin/swift build --product AgentLoopApp 2>&1 | /usr/bin/tee -a "${R26_BUILD_LOG}"; then
    r26_build_status=("${PIPESTATUS[@]}")
  else
    r26_build_status=("${PIPESTATUS[@]}")
  fi
  [[ "${#r26_build_status[@]}" == "2" ]] || r26_active_fail 70 "debug_build_status_shape"
  [[ "${r26_build_status[0]}" == "0" && "${r26_build_status[1]}" == "0" ]] || r26_active_fail 70 "debug_build_failed_${r26_build_status[0]}_${r26_build_status[1]}"

  if r26_bin_dir="$(/usr/bin/swift build -c debug --show-bin-path)"; then :; else r26_active_fail 70 "debug_bin_path_query_failed"; fi
  [[ -d "${r26_bin_dir}" && ! -L "${r26_bin_dir}" ]] || r26_active_fail 70 "debug_bin_not_real_directory"
  if r26_bin_real="$(r26_canonical_directory "${r26_bin_dir}")"; then :; else r26_active_fail 70 "debug_bin_canonicalization_failed"; fi
  [[ "${r26_bin_real}" == "${r26_bin_dir}" ]] || r26_active_fail 70 "debug_bin_canonical_mismatch"
  case "${r26_bin_dir}" in
    "${R26_REPOSITORY_ROOT}/.build/"*/debug) ;;
    *) r26_active_fail 70 "debug_bin_layout_${r26_bin_dir}" ;;
  esac
  r26_bin_component="${r26_bin_dir#${R26_REPOSITORY_ROOT}/.build/}"
  r26_bin_component="${r26_bin_component%/debug}"
  [[ -n "${r26_bin_component}" && "${r26_bin_component}" != */* ]] || r26_active_fail 70 "debug_bin_component_${r26_bin_component}"

  R26_BUILD_EXECUTABLE="${r26_bin_dir}/AgentLoopApp"
  R26_BUILD_RESOURCE_BUNDLE="${r26_bin_dir}/AgentLoop_AgentLoopApp.bundle"
  r26_require_regular_file "${R26_BUILD_EXECUTABLE}"
  [[ -x "${R26_BUILD_EXECUTABLE}" ]] || r26_active_fail 70 "debug_build_executable_not_executable"
  [[ -d "${R26_BUILD_RESOURCE_BUNDLE}" && ! -L "${R26_BUILD_RESOURCE_BUNDLE}" ]] || r26_active_fail 70 "debug_resource_not_real_directory"
  if R26_BUILD_EXECUTABLE_SHA="$(r26_sha "${R26_BUILD_EXECUTABLE}")"; then :; else r26_active_fail 70 "debug_build_executable_sha_failed"; fi
  if R26_BUILD_UUID_SET="$(r26_uuid_set "${R26_BUILD_EXECUTABLE}")"; then :; else r26_active_fail 70 "debug_build_uuid_failed"; fi
  r26_validate_ranch_art_tree "${R26_RANCH_ART_DIRECTORY}"
  r26_validate_ranch_art_tree "${R26_BUILD_RESOURCE_BUNDLE}/RanchArt"
  if r26_resource_manifest="$(r26_tree_manifest_sha "${R26_BUILD_RESOURCE_BUNDLE}")"; then :; else r26_active_fail 70 "generated_resource_manifest_failed"; fi
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "post_build_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=POST_BUILD'
    /usr/bin/printf 'utc=%s\n' "${r26_now_value}"
    /usr/bin/printf '%s\n' 'recipe=r26-dev-bundle-v1'
    /usr/bin/printf '%s\n' 'debug_build_command=swift build --product AgentLoopApp'
    /usr/bin/printf '%s\n' 'debug_build_rc=0'
    /usr/bin/printf 'bin_dir=%s\n' "${r26_bin_dir}"
    /usr/bin/printf 'build_executable=%s\n' "${R26_BUILD_EXECUTABLE}"
    /usr/bin/printf 'build_resource_bundle=%s\n' "${R26_BUILD_RESOURCE_BUNDLE}"
    /usr/bin/printf 'build_executable_sha=%s\n' "${R26_BUILD_EXECUTABLE_SHA}"
    /usr/bin/printf '%s\n' 'build_uuid_set_begin'
    /usr/bin/printf '%s\n' "${R26_BUILD_UUID_SET}"
    /usr/bin/printf '%s\n' 'build_uuid_set_end'
    /usr/bin/printf '%s\n' 'source_ranch_art_regular_count=27'
    /usr/bin/printf 'source_ranch_art_manifest_sha=%s\n' "${R26_EXPECTED_RANCH_ART_MANIFEST_SHA}"
    /usr/bin/printf '%s\n' 'generated_ranch_art_regular_count=27'
    /usr/bin/printf 'generated_ranch_art_manifest_sha=%s\n' "${R26_EXPECTED_RANCH_ART_MANIFEST_SHA}"
    /usr/bin/printf 'generated_resource_manifest_sha=%s\n' "${r26_resource_manifest}"
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R26_BUNDLE_LOG}"

  R26_PHASE="bundle_assembly_pre_sign"
  R26_APP="${R26_BUNDLE_ROOT}/AgentLoop.app"
  R26_APP_EXECUTABLE="${R26_APP}/Contents/MacOS/AgentLoop"
  r26_require_absent_path "${R26_APP}"
  umask 022
  /bin/mkdir -p "${R26_APP}/Contents/MacOS" "${R26_APP}/Contents/Resources"
  /bin/cp "${R26_BUILD_EXECUTABLE}" "${R26_APP_EXECUTABLE}"
  /bin/cp -R "${R26_BUILD_RESOURCE_BUNDLE}" "${R26_APP}/Contents/Resources/"
  /bin/cat > "${R26_APP}/Contents/Info.plist" <<R26_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AgentLoop</string>
  <key>CFBundleIdentifier</key><string>${R26_BUNDLE_IDENTIFIER}</string>
  <key>CFBundleName</key><string>AgentLoop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSEnvironment</key>
  <dict>
    <key>AGENTLOOP_STATE_DIR</key><string>${R26_STATE_ROOT}</string>
    <key>AGENTLOOP_UI_PREVIEW</key><string>1</string>
  </dict>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSMultipleInstancesProhibited</key><true/>
</dict>
</plist>
R26_PLIST
  umask 077
  r26_validate_app_tree "unsigned"
  if /usr/bin/cmp -s "${R26_BUILD_EXECUTABLE}" "${R26_APP_EXECUTABLE}"; then :; else r26_active_fail 70 "unsigned_executable_cmp_failed"; fi
  if /usr/bin/diff -qr "${R26_BUILD_RESOURCE_BUNDLE}" "${R26_APP}/Contents/Resources/AgentLoop_AgentLoopApp.bundle" >/dev/null; then :; else r26_active_fail 70 "unsigned_resource_diff_failed"; fi
  r26_validate_ranch_art_tree "${R26_APP}/Contents/Resources/AgentLoop_AgentLoopApp.bundle/RanchArt"
  if r26_copied_resource_manifest="$(r26_tree_manifest_sha "${R26_APP}/Contents/Resources/AgentLoop_AgentLoopApp.bundle")"; then :; else r26_active_fail 70 "copied_resource_manifest_failed"; fi
  [[ "${r26_copied_resource_manifest}" == "${r26_resource_manifest}" ]] || r26_active_fail 70 "copied_resource_manifest_mismatch"
  if /usr/bin/plutil -lint "${R26_APP}/Contents/Info.plist" >> "${R26_BUILD_LOG}" 2>&1; then :; else r26_active_fail 70 "info_plist_lint_failed"; fi
  if r26_info_sha="$(r26_sha "${R26_APP}/Contents/Info.plist")"; then :; else r26_active_fail 70 "info_plist_sha_failed"; fi
  R26_INFO_PLIST_SHA="${r26_info_sha}"
  if r26_plist_exec="$(/usr/bin/plutil -extract CFBundleExecutable raw -o - "${R26_APP}/Contents/Info.plist")"; then :; else r26_active_fail 70 "plist_executable_read_failed"; fi
  if r26_plist_identifier="$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - "${R26_APP}/Contents/Info.plist")"; then :; else r26_active_fail 70 "plist_identifier_read_failed"; fi
  [[ "${r26_plist_exec}" == "AgentLoop" && "${r26_plist_identifier}" == "${R26_BUNDLE_IDENTIFIER}" ]] || r26_active_fail 70 "plist_identity_mismatch"
  if r26_ls_state="$(/usr/bin/plutil -extract LSEnvironment.AGENTLOOP_STATE_DIR raw -o - "${R26_APP}/Contents/Info.plist")"; then :; else r26_active_fail 70 "plist_ls_environment_state_read_failed"; fi
  if r26_ls_preview="$(/usr/bin/plutil -extract LSEnvironment.AGENTLOOP_UI_PREVIEW raw -o - "${R26_APP}/Contents/Info.plist")"; then :; else r26_active_fail 70 "plist_ls_environment_preview_read_failed"; fi
  [[ "${r26_ls_state}" == "${R26_STATE_ROOT}" ]] || r26_active_fail 70 "plist_ls_environment_state_mismatch"
  [[ "${r26_ls_preview}" == "1" ]] || r26_active_fail 70 "plist_ls_environment_preview_mismatch"
  if /usr/bin/python3 - "${R26_APP}/Contents/Info.plist" "${R26_BUNDLE_IDENTIFIER}" "${R26_STATE_ROOT}" <<'R26_PLIST_CHECK'
import plistlib
import sys

path, identifier, state_root = sys.argv[1:]
with open(path, "rb") as handle:
    value = plistlib.load(handle)
expected = {
    "CFBundleExecutable": "AgentLoop",
    "CFBundleIdentifier": identifier,
    "CFBundleName": "AgentLoop",
    "CFBundlePackageType": "APPL",
    "LSEnvironment": {
        "AGENTLOOP_STATE_DIR": state_root,
        "AGENTLOOP_UI_PREVIEW": "1",
    },
    "LSMinimumSystemVersion": "14.0",
    "LSMultipleInstancesProhibited": True,
    "NSHighResolutionCapable": True,
}
if value != expected:
    raise SystemExit(71)
if any(key.startswith("AGENTLOOP_BOARD_") for key in value["LSEnvironment"]):
    raise SystemExit(72)
R26_PLIST_CHECK
  then :; else r26_active_fail 70 "plist_exact_schema_failed"; fi
  if r26_unsigned_sha="$(r26_sha "${R26_APP_EXECUTABLE}")"; then :; else r26_active_fail 70 "unsigned_executable_sha_failed"; fi
  [[ "${r26_unsigned_sha}" == "${R26_BUILD_EXECUTABLE_SHA}" ]] || r26_active_fail 70 "unsigned_executable_sha_mismatch"
  if r26_unsigned_uuid="$(r26_uuid_set "${R26_APP_EXECUTABLE}")"; then :; else r26_active_fail 70 "unsigned_uuid_failed"; fi
  [[ "${r26_unsigned_uuid}" == "${R26_BUILD_UUID_SET}" ]] || r26_active_fail 70 "unsigned_uuid_mismatch"
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "pre_sign_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=PRE_SIGN'
    /usr/bin/printf 'utc=%s\n' "${r26_now_value}"
    /usr/bin/printf 'bundle_parent=%s\n' "${R26_BUNDLE_ROOT}"
    /usr/bin/printf 'app=%s\n' "${R26_APP}"
    /usr/bin/printf 'app_executable=%s\n' "${R26_APP_EXECUTABLE}"
    /usr/bin/printf '%s\n' 'fresh_bundle_structure_exact=true'
    /usr/bin/printf '%s\n' 'unsigned_executable_cmp_build=true'
    /usr/bin/printf 'unsigned_executable_sha=%s\n' "${r26_unsigned_sha}"
    /usr/bin/printf '%s\n' 'unsigned_uuid_set_begin'
    /usr/bin/printf '%s\n' "${r26_unsigned_uuid}"
    /usr/bin/printf '%s\n' 'unsigned_uuid_set_end'
    /usr/bin/printf '%s\n' 'copied_resource_diff_equal=true'
    /usr/bin/printf 'copied_resource_manifest_sha=%s\n' "${r26_copied_resource_manifest}"
    /usr/bin/printf 'info_plist_sha=%s\n' "${r26_info_sha}"
    /usr/bin/printf 'CFBundleExecutable=%s\n' "${r26_plist_exec}"
    /usr/bin/printf 'CFBundleIdentifier=%s\n' "${r26_plist_identifier}"
    /usr/bin/printf 'LSEnvironment.AGENTLOOP_STATE_DIR=%s\n' "${R26_STATE_ROOT}"
    /usr/bin/printf '%s\n' 'LSEnvironment.AGENTLOOP_UI_PREVIEW=1'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R26_BUNDLE_LOG}"

  R26_PHASE="bundle_sign_launch_ready"
  if /usr/bin/codesign --force --sign - "${R26_APP}" >> "${R26_BUILD_LOG}" 2>&1; then :; else r26_active_fail 70 "codesign_sign_failed"; fi
  if /usr/bin/codesign --verify --deep --strict --verbose=4 "${R26_APP}" >> "${R26_BUILD_LOG}" 2>&1; then :; else r26_active_fail 70 "codesign_verify_failed"; fi
  if r26_signature_detail="$(/usr/bin/codesign --display --verbose=4 "${R26_APP}" 2>&1)"; then :; else r26_active_fail 70 "codesign_display_failed"; fi
  [[ "${r26_signature_detail}" == *$'Signature=adhoc'* ]] || r26_active_fail 70 "signature_not_adhoc"
  [[ "${r26_signature_detail}" == *"Identifier=${R26_BUNDLE_IDENTIFIER}"* ]] || r26_active_fail 70 "signature_identifier_mismatch"
  [[ "${r26_signature_detail}" == *$'TeamIdentifier=not set'* ]] || r26_active_fail 70 "signature_team_identifier_present_or_unknown"
  [[ "${r26_signature_detail}" != *'Developer ID'* ]] || r26_active_fail 70 "developer_id_present"
  if r26_entitlements="$(/usr/bin/codesign --display --entitlements :- "${R26_APP}" 2>&1)"; then :; else r26_active_fail 70 "codesign_entitlements_read_failed"; fi
  [[ "${r26_entitlements}" != *'com.apple.security.app-sandbox'* ]] || r26_active_fail 70 "app_sandbox_entitlement_present"
  r26_require_absent_path "${R26_APP}/Contents/embedded.provisionprofile"
  r26_validate_app_tree "signed"
  if r26_app_real="$(r26_canonical_directory "${R26_APP}")"; then :; else r26_active_fail 70 "signed_app_canonicalization_failed"; fi
  if r26_exec_real="$(r26_canonical_file "${R26_APP_EXECUTABLE}")"; then :; else r26_active_fail 70 "signed_exec_canonicalization_failed"; fi
  [[ "${r26_app_real}" == "${R26_APP}" && "${r26_exec_real}" == "${R26_APP_EXECUTABLE}" ]] || r26_active_fail 70 "signed_path_canonical_mismatch"
  if R26_SIGNED_EXECUTABLE_SHA="$(r26_sha "${R26_APP_EXECUTABLE}")"; then :; else r26_active_fail 70 "signed_executable_sha_failed"; fi
  if R26_SIGNED_UUID_SET="$(r26_uuid_set "${R26_APP_EXECUTABLE}")"; then :; else r26_active_fail 70 "signed_uuid_failed"; fi
  [[ "${R26_SIGNED_UUID_SET}" == "${R26_BUILD_UUID_SET}" ]] || r26_active_fail 70 "signed_uuid_mismatch"
  if R26_SIGNED_BUNDLE_MANIFEST_SHA="$(r26_tree_manifest_sha "${R26_APP}")"; then :; else r26_active_fail 70 "signed_bundle_manifest_failed"; fi
  if /usr/bin/diff -qr "${R26_BUILD_RESOURCE_BUNDLE}" "${R26_APP}/Contents/Resources/AgentLoop_AgentLoopApp.bundle" >/dev/null; then :; else r26_active_fail 70 "signed_resource_diff_failed"; fi
  if r26_cdhash="$(/usr/bin/awk -F= '$1 == "CDHash" { print $2 }' <<< "${r26_signature_detail}")"; then :; else r26_active_fail 70 "cdhash_parse_failed"; fi
  [[ -n "${r26_cdhash}" && "${r26_cdhash}" != *$'\n'* ]] || r26_active_fail 70 "cdhash_not_unique"
  R26_SIGNED_CDHASH="${r26_cdhash}"
  r26_require_no_process
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "launch_ready_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=LAUNCH_READY'
    /usr/bin/printf 'utc=%s\n' "${r26_now_value}"
    /usr/bin/printf 'app=%s\n' "${R26_APP}"
    /usr/bin/printf 'executable=%s\n' "${R26_APP_EXECUTABLE}"
    /usr/bin/printf '%s\n' 'signature=adhoc'
    /usr/bin/printf 'identifier=%s\n' "${R26_BUNDLE_IDENTIFIER}"
    /usr/bin/printf '%s\n' 'team_identifier=not_set'
    /usr/bin/printf '%s\n' 'developer_id_present=false'
    /usr/bin/printf '%s\n' 'entitlement_plist_present=false'
    /usr/bin/printf '%s\n' 'app_sandbox_entitlement_present=false'
    /usr/bin/printf 'post_sign_executable_sha=%s\n' "${R26_SIGNED_EXECUTABLE_SHA}"
    /usr/bin/printf '%s\n' 'post_sign_uuid_set_begin'
    /usr/bin/printf '%s\n' "${R26_SIGNED_UUID_SET}"
    /usr/bin/printf '%s\n' 'post_sign_uuid_set_end'
    /usr/bin/printf 'cdhash=%s\n' "${r26_cdhash}"
    /usr/bin/printf 'signed_bundle_manifest_sha=%s\n' "${R26_SIGNED_BUNDLE_MANIFEST_SHA}"
    /usr/bin/printf '%s\n' 'resources_equal_build=true'
    /usr/bin/printf '%s\n' 'process_count=0'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R26_BUNDLE_LOG}"
  r26_require_verify_log_identity "post_launch_ready"
  R26_CURRENT_ROOT_PHASE="bundle_ready"
  r26_append_boundary 'launch_ready=true'
}

r26_core_guard_shape() {
  /usr/bin/awk '
    /^#(if|elseif|else|endif)/ {
      if ($0 == "#if DEBUG" && depth == 0) { depth = 1; opens += 1; next }
      if ($0 == "#endif" && depth == 1) { depth = 0; closes += 1; next }
      bad += 1
    }
    index($0, "idleClockForTesting") { token += 1; if (depth == 1) guarded += 1 }
    END {
      print (opens + 0) ":" (closes + 0) ":" (bad + 0) ":" (depth + 0) ":" (token + 0) ":" (guarded + 0)
    }
  ' "${R26_CORE_PATH}"
}

r26_test_guard_shape() {
  /usr/bin/awk '
    BEGIN {
      split("ManualAgentLoopClock|ControlledIdleProviderError|ControlledIdleProvider|AgentEventProbe|OneShotGate|startControlledLoop|turnTimeoutRetriesOnceThenBlocks|cancelWinsOverIdleTimeout|timeoutThenSuccessDoesNotAccumulate|slowActiveStreamDoesNotIdleTimeout|turnCompletesUnderTimeout", tokens, "|")
    }
    /^#(if|elseif|else|endif)/ {
      directives += 1
      if ($0 == "#if DEBUG" && depth == 0) { depth = 1; opens += 1; next }
      if ($0 == "#endif" && depth == 1) { depth = 0; closes += 1; next }
      bad += 1
    }
    {
      for (i = 1; i <= 11; i += 1) {
        if (index($0, tokens[i])) { total[i] += 1; if (depth == 1) guarded[i] += 1 }
      }
    }
    END {
      ok = (opens == 3 && closes == 3 && directives == 6 && bad == 0 && depth == 0)
      for (i = 1; i <= 11; i += 1) if (total[i] < 1 || total[i] != guarded[i]) ok = 0
      print (opens + 0) ":" (closes + 0) ":" (directives + 0) ":" (bad + 0) ":" (depth + 0) ":" (ok + 0)
    }
  ' "${R26_TEST_PATH}"
}

r26_require_guard_shape_static() {
  if R26_CORE_GUARD_SHAPE="$(r26_core_guard_shape)"; then
    :
  else
    r26_fail 70 "core_guard_parser_failed"
  fi
  [[ "${R26_CORE_GUARD_SHAPE}" == "1:1:0:0:1:1" ]] || r26_fail 70 "core_guard_shape_${R26_CORE_GUARD_SHAPE}"
  if R26_TEST_GUARD_SHAPE="$(r26_test_guard_shape)"; then
    :
  else
    r26_fail 70 "test_guard_parser_failed"
  fi
  [[ "${R26_TEST_GUARD_SHAPE}" == "3:3:6:0:0:1" ]] || r26_fail 70 "test_guard_shape_${R26_TEST_GUARD_SHAPE}"
}

r26_require_err_subshell_guard_static() {
  if /usr/bin/python3 - "${R26_DRIVER_PATH}" <<'R26_ERR_GUARD_STATIC'
import re
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")
start = source.index("r26_err_trap() {")
end = source.index("\nr26_signal_trap() {", start)
body = source[start:end]
ordered = [
    'local r26_status="$?"',
    'local r26_command="${BASH_COMMAND:-UNKNOWN}"',
    'if (( BASH_SUBSHELL != 0 )); then',
    'trap - ERR',
    'exit "${r26_status}"',
    'if [[ "${R26_BOUNDARY_ACTIVE}" == "true" ]]; then',
    'r26_active_fail "${r26_status}"',
    'r26_pre_begin_fail "${r26_status}"',
]
positions = [body.index(item) for item in ordered]
if positions != sorted(positions):
    raise SystemExit(71)
if body.count('if (( BASH_SUBSHELL != 0 )); then') != 1:
    raise SystemExit(72)
if re.search(r'(?m)^\s*trap\b[^\n]*\bEXIT\b', source):
    raise SystemExit(73)
inventory = {
    r'\$\(/bin/ps': 15,
    r'\$\(/usr/bin/pgrep': 2,
    r'\$\(/usr/sbin/lsof': 3,
}
for pattern, expected in inventory.items():
    if len(re.findall(pattern, source)) != expected:
        raise SystemExit(74)
if len(re.findall(r'(?m)^r26_run_bash32_err_subshell_microprobes$', source)) != 2:
    raise SystemExit(75)
R26_ERR_GUARD_STATIC
  then
    :
  else
    r26_fail 70 "err_subshell_guard_static_inventory_failed"
  fi
}

r26_run_bash32_err_subshell_microprobes() {
  local r26_probe_output=""
  if r26_probe_output="$(/bin/bash --noprofile --norc -c '
set -E
exec 3>&1

legacy_output=""
legacy_rc=0
if legacy_output="$(/bin/bash --noprofile --norc -c '\''
  set -Ee
  legacy_err() { local status="$?"; /usr/bin/printf "LEGACY_CHILD_CLEANUP\\n" >&2; return "${status}"; }
  trap legacy_err ERR
  legacy_probe() {
    local inner=""
    local rc=0
    if inner="$(false)"; then rc=0; else rc=$?; fi
    return "${rc}"
  }
  value=""
  if value="$(legacy_probe)"; then exit 90; else exit "$?"; fi
'\'' 2>&1)"; then
  legacy_rc=0
else
  legacy_rc=$?
fi
legacy_count="$(/usr/bin/awk '\''$0 == "LEGACY_CHILD_CLEANUP" { n += 1 } END { print n + 0 }'\'' <<< "${legacy_output}")"
[[ "${legacy_rc}" == "1" && "${legacy_count}" == "2" ]] || exit 71
/usr/bin/printf "%s\\n" "P1_legacy_double_child_cleanup=PASS"

root_cleanup_count=0
guarded_err() {
  local status="$?"
  local command="${BASH_COMMAND:-UNKNOWN}"
  if (( BASH_SUBSHELL != 0 )); then
    trap - ERR
    exit "${status}"
  fi
  /usr/bin/printf "%s\\n" "ROOT_FAIL_FAST sub=${BASH_SUBSHELL}" >&3
  root_cleanup_count=$((root_cleanup_count + 1))
  return "${status}"
}
trap guarded_err ERR

expected_absent() { return 1; }
expected_present() { /usr/bin/printf "%s\\n" 4242; return 0; }
transient_ps() { /usr/bin/printf "%s\\n" ps-partial; return 1; }
transient_lsof() { /usr/bin/printf "%s\\n" lsof-partial; return 1; }
indeterminate() { return 2; }
exact_wrapper() {
  local output=""
  local rc=0
  if output="$(expected_absent)"; then rc=0; else rc=$?; fi
  [[ "${rc}" == "1" && -z "${output}" ]] || return 72
  /usr/bin/printf "%s" "${output}"
  return "${rc}"
}
classify_ps_retry() {
  local output=""
  local rc=0
  if output="$(transient_ps)"; then rc=0; else rc=$?; fi
  [[ "${rc}" == "1" && "${output}" == "ps-partial" ]] || return 72
  /usr/bin/printf "%s" retry_while_live
}
classify_lsof_subset() {
  local output=""
  local rc=0
  if output="$(transient_lsof)"; then rc=0; else rc=$?; fi
  [[ "${rc}" == "1" && "${output}" == "lsof-partial" ]] || return 72
  /usr/bin/printf "%s" safe_startup_subset
}
classify_indeterminate() {
  local output=""
  local rc=0
  if output="$(indeterminate)"; then rc=0; else rc=$?; fi
  [[ "${rc}" == "2" && -z "${output}" ]] || return 72
  /usr/bin/printf "%s" indeterminate_fail_closed
}

payload="sentinel"; rc=0
if payload="$(exact_wrapper)"; then rc=0; else rc=$?; fi
[[ "${rc}" == "1" && -z "${payload}" && "${root_cleanup_count}" == "0" ]] || exit 73
/usr/bin/printf "%s\\n" "P2_exact_name_absent_no_cleanup=PASS"

payload=""; rc=0
if payload="$(expected_present)"; then rc=0; else rc=$?; fi
[[ "${rc}" == "0" && "${payload}" == "4242" && "${root_cleanup_count}" == "0" ]] || exit 74
/usr/bin/printf "%s\\n" "P3_exact_name_present=PASS"

payload="sentinel"; rc=0
if payload="$(expected_absent)"; then rc=0; else rc=$?; fi
[[ "${rc}" == "1" && -z "${payload}" && "${root_cleanup_count}" == "0" ]] || exit 75
/usr/bin/printf "%s\\n" "P4_no_child_absent_no_cleanup=PASS"

classification=""
if classification="$(classify_ps_retry)"; then :; else exit 76; fi
[[ "${classification}" == "retry_while_live" && "${root_cleanup_count}" == "0" ]] || exit 76
/usr/bin/printf "%s\\n" "P5_transient_ps_retry_no_cleanup=PASS"

classification=""
if classification="$(classify_lsof_subset)"; then :; else exit 77; fi
[[ "${classification}" == "safe_startup_subset" && "${root_cleanup_count}" == "0" ]] || exit 77
/usr/bin/printf "%s\\n" "P6_transient_lsof_subset_no_cleanup=PASS"

classification=""
if classification="$(classify_indeterminate)"; then :; else exit 78; fi
[[ "${classification}" == "indeterminate_fail_closed" && "${root_cleanup_count}" == "0" ]] || exit 78
/usr/bin/printf "%s\\n" "P7_indeterminate_rc2_fail_closed=PASS"

raw=""
raw="$(false)"
raw_rc=$?
[[ "${raw_rc}" == "1" && -z "${raw}" && "${root_cleanup_count}" == "1" ]] || exit 79
/usr/bin/printf "%s\\n" "P8_root_uncaught_substitution_single_cleanup=PASS"
' )"; then
    :
  else
    r26_fail 70 "bash32_err_subshell_microprobes_failed"
  fi
  [[ "${r26_probe_output}" == $'P1_legacy_double_child_cleanup=PASS\nP2_exact_name_absent_no_cleanup=PASS\nP3_exact_name_present=PASS\nP4_no_child_absent_no_cleanup=PASS\nP5_transient_ps_retry_no_cleanup=PASS\nP6_transient_lsof_subset_no_cleanup=PASS\nP7_indeterminate_rc2_fail_closed=PASS\nROOT_FAIL_FAST sub=0\nP8_root_uncaught_substitution_single_cleanup=PASS' ]] || r26_fail 70 "bash32_err_subshell_microprobes_output_mismatch"
}

r26_run_guard_shape_and_strip() {
  local r26_strip_sha=""
  local r26_strip_output=""
  local r26_now_value=""
  R26_PHASE="guard_shape_and_strip"
  r26_require_guard_shape_static
  if r26_strip_output="$(/usr/bin/awk '
      (NR == 90 || NR == 643 || NR == 1007) { if ($0 != "#if DEBUG") exit 71; next }
      (NR == 603 || NR == 695 || NR == 1253) { if ($0 != "#endif") exit 72; next }
      { print }
    ' "${R26_TEST_PATH}")"; then :; else r26_active_fail 70 "test_guard_strip_failed"; fi
  if r26_strip_sha="$(/usr/bin/python3 -c 'import hashlib, sys; print(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())' <<< "${r26_strip_output}")"; then :; else r26_active_fail 70 "test_guard_strip_sha_failed"; fi
  [[ "${r26_strip_sha}" == "${R26_EXPECTED_R20_TEST_SHA}" ]] || r26_active_fail 70 "test_guard_strip_hash_${r26_strip_sha}"
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "guard_shape_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=R21_GUARD_SHAPE_AND_STRIP'
    /usr/bin/printf 'utc=%s\n' "${r26_now_value}"
    /usr/bin/printf 'core_guard_shape=%s\n' "${R26_CORE_GUARD_SHAPE}"
    /usr/bin/printf 'test_guard_shape=%s\n' "${R26_TEST_GUARD_SHAPE}"
    /usr/bin/printf 'test_stripped_sha=%s\n' "${r26_strip_sha}"
    /usr/bin/printf '%s\n' 'test_stripped_matches_r20=true'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R26_SOURCE_LOG}"
}

r26_require_exact_object() {
  local r26_object="$1"
  local r26_expected_parent="$2"
  local r26_parent="${r26_object%/*}"
  local r26_parent_real=""
  local r26_object_real=""
  [[ -d "${r26_parent}" && ! -L "${r26_parent}" ]] || r26_active_fail 70 "object_parent_not_real_${r26_object}"
  if r26_parent_real="$(r26_canonical_directory "${r26_parent}")"; then :; else r26_active_fail 70 "object_parent_canonical_failed_${r26_object}"; fi
  [[ "${r26_parent_real}" == "${r26_expected_parent}" ]] || r26_active_fail 70 "object_parent_mismatch_${r26_object}"
  r26_require_regular_file "${r26_object}"
  if r26_object_real="$(r26_canonical_file "${r26_object}")"; then :; else r26_active_fail 70 "object_canonical_failed_${r26_object}"; fi
  [[ "${r26_object_real}" == "${r26_object}" ]] || r26_active_fail 70 "object_canonical_mismatch_${r26_object}"
}

r26_demangle_object() {
  local r26_object="$1"
  local r26_output=""
  if r26_output="$({
      if /usr/bin/nm -j "${r26_object}" | /usr/bin/xcrun swift-demangle; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "2" ]] || exit 71
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" ]] || exit 72
    })"; then
    :
  else
    return "$?"
  fi
  [[ -n "${r26_output}" ]] || return 73
  /usr/bin/printf '%s\n' "${r26_output}"
}

r26_run_release_and_object_gates() {
  local r26_release_status=()
  local r26_release_bin=""
  local r26_release_real=""
  local r26_debug_bin=""
  local r26_debug_real=""
  local r26_release_component=""
  local r26_debug_component=""
  local r26_release_core_object=""
  local r26_release_test_object=""
  local r26_debug_core_object=""
  local r26_debug_test_object=""
  local r26_core_object_sha_before=""
  local r26_core_object_sha_after=""
  local r26_release_core_symbols=""
  local r26_release_test_symbols=""
  local r26_debug_core_symbols=""
  local r26_debug_test_symbols=""
  local r26_count=""
  local r26_token=""
  local r26_now_value=""

  R26_PHASE="release_core_target"
  if /usr/bin/swift build -c release --target AgentLoopCore 2>&1 | /usr/bin/tee -a "${R26_BUILD_LOG}"; then
    r26_release_status=("${PIPESTATUS[@]}")
  else
    r26_release_status=("${PIPESTATUS[@]}")
  fi
  [[ "${#r26_release_status[@]}" == "2" && "${r26_release_status[0]}" == "0" && "${r26_release_status[1]}" == "0" ]] || r26_active_fail 70 "release_core_target_failed"
  if r26_release_bin="$(/usr/bin/swift build -c release --show-bin-path)"; then :; else r26_active_fail 70 "release_bin_path_query_failed"; fi
  if r26_debug_bin="$(/usr/bin/swift build -c debug --show-bin-path)"; then :; else r26_active_fail 70 "debug_bin_path_requery_failed"; fi
  [[ -d "${r26_release_bin}" && ! -L "${r26_release_bin}" && -d "${r26_debug_bin}" && ! -L "${r26_debug_bin}" ]] || r26_active_fail 70 "bin_path_not_real_directory"
  if r26_release_real="$(r26_canonical_directory "${r26_release_bin}")"; then :; else r26_active_fail 70 "release_bin_canonical_failed"; fi
  if r26_debug_real="$(r26_canonical_directory "${r26_debug_bin}")"; then :; else r26_active_fail 70 "debug_bin_canonical_failed"; fi
  [[ "${r26_release_real}" == "${r26_release_bin}" && "${r26_debug_real}" == "${r26_debug_bin}" ]] || r26_active_fail 70 "bin_path_canonical_mismatch"
  case "${r26_release_bin}" in "${R26_REPOSITORY_ROOT}/.build/"*/release) ;; *) r26_active_fail 70 "release_bin_layout" ;; esac
  case "${r26_debug_bin}" in "${R26_REPOSITORY_ROOT}/.build/"*/debug) ;; *) r26_active_fail 70 "debug_bin_layout_requery" ;; esac
  r26_release_component="${r26_release_bin#${R26_REPOSITORY_ROOT}/.build/}"; r26_release_component="${r26_release_component%/release}"
  r26_debug_component="${r26_debug_bin#${R26_REPOSITORY_ROOT}/.build/}"; r26_debug_component="${r26_debug_component%/debug}"
  [[ -n "${r26_release_component}" && "${r26_release_component}" != */* && "${r26_release_component}" == "${r26_debug_component}" ]] || r26_active_fail 70 "bin_component_mismatch"
  r26_release_core_object="${r26_release_bin}/AgentLoopCore.build/AgentLoop.swift.o"
  r26_release_test_object="${r26_release_bin}/AgentLoopTestSuite.build/AgentLoopTests.swift.o"
  r26_debug_core_object="${r26_debug_bin}/AgentLoopCore.build/AgentLoop.swift.o"
  r26_debug_test_object="${r26_debug_bin}/AgentLoopTestSuite.build/AgentLoopTests.swift.o"
  r26_require_exact_object "${r26_release_core_object}" "${r26_release_bin}/AgentLoopCore.build"
  if r26_core_object_sha_before="$(r26_sha "${r26_release_core_object}")"; then :; else r26_active_fail 70 "release_core_object_sha_before_failed"; fi

  R26_PHASE="release_test_target"
  if /usr/bin/swift build -c release --target AgentLoopTestSuite 2>&1 | /usr/bin/tee -a "${R26_BUILD_LOG}"; then
    r26_release_status=("${PIPESTATUS[@]}")
  else
    r26_release_status=("${PIPESTATUS[@]}")
  fi
  [[ "${#r26_release_status[@]}" == "2" && "${r26_release_status[0]}" == "0" && "${r26_release_status[1]}" == "0" ]] || r26_active_fail 70 "release_test_target_failed"
  r26_require_exact_object "${r26_release_core_object}" "${r26_release_bin}/AgentLoopCore.build"
  r26_require_exact_object "${r26_release_test_object}" "${r26_release_bin}/AgentLoopTestSuite.build"
  r26_require_exact_object "${r26_debug_core_object}" "${r26_debug_bin}/AgentLoopCore.build"
  r26_require_exact_object "${r26_debug_test_object}" "${r26_debug_bin}/AgentLoopTestSuite.build"
  if r26_core_object_sha_after="$(r26_sha "${r26_release_core_object}")"; then :; else r26_active_fail 70 "release_core_object_sha_after_failed"; fi
  [[ "${r26_core_object_sha_after}" == "${r26_core_object_sha_before}" ]] || r26_active_fail 70 "release_core_object_replaced_by_test_target"
  if r26_release_core_symbols="$(r26_demangle_object "${r26_release_core_object}")"; then :; else r26_active_fail 70 "release_core_nm_failed"; fi
  if r26_release_test_symbols="$(r26_demangle_object "${r26_release_test_object}")"; then :; else r26_active_fail 70 "release_test_nm_failed"; fi
  if r26_debug_core_symbols="$(r26_demangle_object "${r26_debug_core_object}")"; then :; else r26_active_fail 70 "debug_core_nm_failed"; fi
  if r26_debug_test_symbols="$(r26_demangle_object "${r26_debug_test_object}")"; then :; else r26_active_fail 70 "debug_test_nm_failed"; fi
  if r26_count="$(/usr/bin/awk -v token='idleClockForTesting' 'index($0, token) { count += 1 } END { print count + 0 }' <<< "${r26_release_core_symbols}")"; then :; else r26_active_fail 70 "release_core_token_count_failed"; fi
  [[ "${r26_count}" == "0" ]] || r26_active_fail 70 "release_core_idle_clock_symbol_count_${r26_count}"
  if r26_count="$(/usr/bin/awk -v token='idleClockForTesting' 'index($0, token) { count += 1 } END { print count + 0 }' <<< "${r26_debug_core_symbols}")"; then :; else r26_active_fail 70 "debug_core_token_count_failed"; fi
  [[ "${r26_count}" -gt "0" ]] || r26_active_fail 70 "debug_core_idle_clock_symbol_absent"
  R26_OBJECT_TEST_TOKENS=(ManualAgentLoopClock ControlledIdleProviderError ControlledIdleProvider AgentEventProbe OneShotGate startControlledLoop turnTimeoutRetriesOnceThenBlocks cancelWinsOverIdleTimeout timeoutThenSuccessDoesNotAccumulate slowActiveStreamDoesNotIdleTimeout turnCompletesUnderTimeout)
  for r26_token in "${R26_OBJECT_TEST_TOKENS[@]}"; do
    if r26_count="$(/usr/bin/awk -v token="${r26_token}" 'index($0, token) { count += 1 } END { print count + 0 }' <<< "${r26_release_test_symbols}")"; then :; else r26_active_fail 70 "release_test_token_count_failed_${r26_token}"; fi
    [[ "${r26_count}" == "0" ]] || r26_active_fail 70 "release_test_token_present_${r26_token}_${r26_count}"
    if r26_count="$(/usr/bin/awk -v token="${r26_token}" 'index($0, token) { count += 1 } END { print count + 0 }' <<< "${r26_debug_test_symbols}")"; then :; else r26_active_fail 70 "debug_test_token_count_failed_${r26_token}"; fi
    [[ "${r26_count}" -gt "0" ]] || r26_active_fail 70 "debug_test_token_absent_${r26_token}"
  done
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "object_gate_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=RELEASE_DEBUG_OBJECT_GATES'
    /usr/bin/printf 'utc=%s\n' "${r26_now_value}"
    /usr/bin/printf 'release_bin=%s\n' "${r26_release_bin}"
    /usr/bin/printf 'debug_bin=%s\n' "${r26_debug_bin}"
    /usr/bin/printf 'release_core_object=%s\n' "${r26_release_core_object}"
    /usr/bin/printf 'release_test_object=%s\n' "${r26_release_test_object}"
    /usr/bin/printf 'debug_core_object=%s\n' "${r26_debug_core_object}"
    /usr/bin/printf 'debug_test_object=%s\n' "${r26_debug_test_object}"
    /usr/bin/printf 'release_core_object_sha=%s\n' "${r26_core_object_sha_after}"
    /usr/bin/printf '%s\n' 'release_core_idleClockForTesting_count=0'
    /usr/bin/printf '%s\n' 'debug_core_idleClockForTesting_count_gt_zero=true'
    /usr/bin/printf '%s\n' 'release_test_11_token_counts_zero=true'
    /usr/bin/printf '%s\n' 'debug_test_11_token_counts_gt_zero=true'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R26_SOURCE_LOG}"
}

r26_require_matrix_window_manifest() {
  local r26_record=""
  local r26_expected=""
  local r26_path=""
  local r26_actual=""
  local r26_pass=0
  local r26_mismatch=0
  while IFS= read -r r26_record; do
    r26_expected="${r26_record%%  *}"
    r26_path="${r26_record#*  }"
    [[ "${r26_expected}" != "${r26_record}" ]] || r26_active_fail 70 "matrix_window_manifest_parse_failed"
    if r26_actual="$(r26_sha "${r26_path}")"; then :; else r26_active_fail 70 "matrix_window_sha_failed_${r26_path}"; fi
    if [[ "${r26_actual}" == "${r26_expected}" ]]; then
      r26_pass=$((r26_pass + 1))
    else
      [[ "${r26_path}" == "${R26_MATRIX_SCRIPT}" ]] || r26_active_fail 70 "matrix_window_unexpected_mismatch_${r26_path}"
      r26_mismatch=$((r26_mismatch + 1))
    fi
  done < "${R26_MANIFEST_PATH}"
  [[ "${r26_pass}" == "205" && "${r26_mismatch}" == "1" ]] || r26_active_fail 70 "matrix_window_partition_${r26_pass}_${r26_mismatch}"
}

r26_run_matrix_with_mandatory_restore() {
  local r26_stage_sha=""
  local r26_stage_line_count=""
  local r26_matrix_mode=""
  local r26_mutated_sha=""
  local r26_matrix_status=()
  local r26_restore_rc=0
  local r26_now_value=""
  local r26_mutated_mode=""
  R26_PHASE="matrix_pre_mutation"
  r26_require_manifest
  r26_require_sha "${R26_EXPECTED_MATRIX_ENTRY_SHA}" "${R26_MATRIX_SCRIPT}"
  if r26_matrix_mode="$(/usr/bin/stat -f '%Lp' "${R26_MATRIX_SCRIPT}")"; then :; else r26_active_fail 70 "matrix_mode_read_failed"; fi
  [[ "${r26_matrix_mode}" == "755" ]] || r26_active_fail 70 "matrix_entry_mode_${r26_matrix_mode}"
  if r26_stage_sha="$(/usr/bin/awk -v expected="${R26_STAGE_PATH}" 'substr($0, 67) == expected { print substr($0, 1, 64) }' "${R26_MANIFEST_PATH}")"; then :; else r26_active_fail 70 "matrix_stage_manifest_sha_read_failed"; fi
  r26_require_sha_literal "matrix_stage_manifest" "${r26_stage_sha}"
  r26_require_sha "${r26_stage_sha}" "${R26_STAGE_PATH}"
  if r26_stage_line_count="$(/usr/bin/awk '$0 == "expected_stage_hash=\"a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f\"" { count += 1; line = NR } END { print (count + 0) ":" (line + 0) }' "${R26_MATRIX_SCRIPT}")"; then :; else r26_active_fail 70 "matrix_stage_line_scan_failed"; fi
  [[ "${r26_stage_line_count}" == "1:115" ]] || r26_active_fail 70 "matrix_stage_line_shape_${r26_stage_line_count}"
  R26_MATRIX_BACKUP_PATH="${R26_STATE_ROOT}/r26-matrix-entry.backup"
  R26_MATRIX_MUTATED_STAGE="${R26_REPOSITORY_ROOT}/scripts/.${R26_INVOCATION_ID}.matrix-mutated.stage"
  R26_MATRIX_RESTORE_STAGE="${R26_REPOSITORY_ROOT}/scripts/.${R26_INVOCATION_ID}.matrix-restore.stage"
  r26_require_absent_path "${R26_MATRIX_BACKUP_PATH}"
  r26_require_absent_path "${R26_MATRIX_MUTATED_STAGE}"
  r26_require_absent_path "${R26_MATRIX_RESTORE_STAGE}"
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  if r26_exclusive_create_empty "${R26_MATRIX_BACKUP_PATH}"; then
    R26_MATRIX_BACKUP_OWNED="true"
  else
    r26_install_signal_traps
    r26_active_fail 70 "matrix_backup_exclusive_create_failed"
  fi
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_matrix_backup_create"; fi
  /bin/cp -p "${R26_MATRIX_SCRIPT}" "${R26_MATRIX_BACKUP_PATH}"
  r26_require_sha "${R26_EXPECTED_MATRIX_ENTRY_SHA}" "${R26_MATRIX_BACKUP_PATH}"
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  if r26_exclusive_create_empty "${R26_MATRIX_MUTATED_STAGE}"; then
    R26_MATRIX_MUTATED_STAGE_OWNED="true"
  else
    r26_install_signal_traps
    r26_active_fail 70 "matrix_mutated_stage_exclusive_create_failed"
  fi
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_matrix_mutated_stage_create"; fi
  if /usr/bin/awk -v new_sha="${r26_stage_sha}" '
      NR == 115 {
        if ($0 != "expected_stage_hash=\"a8ca6e7a56a32e945bae185724a51d4e0015d61676bf02d9637fedc2c27d9b6f\"") exit 71
        print "expected_stage_hash=\"" new_sha "\""
        changed += 1
        next
      }
      { print }
      END { if (changed != 1) exit 72 }
    ' "${R26_MATRIX_SCRIPT}" > "${R26_MATRIX_MUTATED_STAGE}"; then :; else r26_active_fail 70 "matrix_single_line_rewrite_failed"; fi
  /bin/chmod 755 "${R26_MATRIX_MUTATED_STAGE}"
  r26_require_regular_file "${R26_MATRIX_MUTATED_STAGE}"
  if r26_mutated_sha="$(r26_sha "${R26_MATRIX_MUTATED_STAGE}")"; then :; else r26_active_fail 70 "matrix_mutated_stage_sha_failed"; fi
  [[ "${r26_mutated_sha}" != "${R26_EXPECTED_MATRIX_ENTRY_SHA}" ]] || r26_active_fail 70 "matrix_mutated_stage_unchanged"
  if r26_mutated_mode="$(/usr/bin/stat -f '%Lp' "${R26_MATRIX_MUTATED_STAGE}")"; then :; else r26_active_fail 70 "matrix_mutated_stage_mode_failed"; fi
  [[ "${r26_mutated_mode}" == "755" ]] || r26_active_fail 70 "matrix_mutated_stage_mode_${r26_mutated_mode}"
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  R26_MATRIX_MUTATED="true"
  if /bin/mv -f "${R26_MATRIX_MUTATED_STAGE}" "${R26_MATRIX_SCRIPT}"; then :; else r26_install_signal_traps; r26_active_fail 70 "matrix_mutated_publish_failed"; fi
  R26_MATRIX_MUTATED_STAGE_OWNED="false"
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_matrix_publish"; fi
  if [[ -e "${R26_MATRIX_MUTATED_STAGE}" || -L "${R26_MATRIX_MUTATED_STAGE}" ]]; then r26_active_fail 70 "matrix_mutated_stage_survived_publish"; fi
  if r26_mutated_sha="$(r26_sha "${R26_MATRIX_SCRIPT}")"; then :; else r26_active_fail 70 "matrix_mutated_sha_failed"; fi
  if r26_stage_line_count="$(/usr/bin/awk -v expected="expected_stage_hash=\"${r26_stage_sha}\"" '$0 == expected { count += 1; line = NR } END { print (count + 0) ":" (line + 0) }' "${R26_MATRIX_SCRIPT}")"; then :; else r26_active_fail 70 "matrix_mutated_line_scan_failed"; fi
  [[ "${r26_stage_line_count}" == "1:115" ]] || r26_active_fail 70 "matrix_mutated_line_shape_${r26_stage_line_count}"
  r26_require_matrix_window_manifest
  R26_PHASE="migration_matrix"
  if "${R26_MATRIX_SCRIPT}" --sqlite 3.51 --sqlite 3.52 2>&1 | /usr/bin/tee -a "${R26_MATRIX_LOG}"; then
    r26_matrix_status=("${PIPESTATUS[@]}")
  else
    r26_matrix_status=("${PIPESTATUS[@]}")
  fi
  R26_PHASE="matrix_mandatory_restore"
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  if r26_restore_matrix_containment; then
    r26_restore_rc=0
  else
    r26_restore_rc="$?"
  fi
  r26_install_signal_traps
  [[ "${r26_restore_rc}" == "0" ]] || r26_active_fail 70 "matrix_restore_failed_${r26_restore_rc}"
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_matrix_restore"; fi
  [[ "${#r26_matrix_status[@]}" == "2" ]] || r26_active_fail 70 "matrix_status_shape"
  [[ "${r26_matrix_status[0]}" == "0" && "${r26_matrix_status[1]}" == "0" ]] || r26_active_fail 70 "matrix_failed_${r26_matrix_status[0]}_${r26_matrix_status[1]}"
  r26_require_sha "${R26_EXPECTED_MATRIX_ENTRY_SHA}" "${R26_MATRIX_SCRIPT}"
  [[ "${R26_MATRIX_MUTATED}" == "false" ]] || r26_active_fail 70 "matrix_mutated_flag_after_restore"
  [[ "${R26_MATRIX_BACKUP_OWNED}" == "false" && "${R26_MATRIX_MUTATED_STAGE_OWNED}" == "false" && "${R26_MATRIX_RESTORE_STAGE_OWNED}" == "false" ]] || r26_active_fail 70 "matrix_owned_flags_after_restore"
  r26_require_absent_path "${R26_MATRIX_BACKUP_PATH}"
  r26_require_absent_path "${R26_MATRIX_MUTATED_STAGE}"
  r26_require_absent_path "${R26_MATRIX_RESTORE_STAGE}"
  r26_require_manifest
  r26_require_exact_line_once "${R26_MATRIX_LOG}" 'p1_migration_matrix.result=pass'
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "matrix_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=R26_MATRIX_WINDOW'
    /usr/bin/printf 'utc=%s\n' "${r26_now_value}"
    /usr/bin/printf 'stage_sha=%s\n' "${r26_stage_sha}"
    /usr/bin/printf 'temporary_matrix_sha=%s\n' "${r26_mutated_sha}"
    /usr/bin/printf '%s\n' 'window_manifest_partition=205_PASS_1_MATRIX_SCRIPT_MISMATCH'
    /usr/bin/printf 'restored_matrix_sha=%s\n' "${R26_EXPECTED_MATRIX_ENTRY_SHA}"
    /usr/bin/printf '%s\n' 'matrix_mutated_after_restore=false'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R26_SOURCE_LOG}"
  r26_append_boundary 'migration_matrix=PASS'
  r26_append_boundary 'matrix_restored=true'
}

r26_require_launch_ready_identity() {
  local r26_label="$1"
  local r26_info_sha=""
  local r26_signature_detail=""
  local r26_cdhash=""
  local r26_post_build_count=""
  local r26_pre_sign_count=""
  local r26_launch_ready_count=""
  [[ "${R26_CURRENT_ROOT_PHASE}" == "bundle_ready" || "${R26_CURRENT_ROOT_PHASE}" == "preview_live" || "${R26_CURRENT_ROOT_PHASE}" == "preview_quiescent" ]] || r26_active_fail 70 "launch_ready_wrong_root_phase_${r26_label}_${R26_CURRENT_ROOT_PHASE}"
  [[ "${R26_APP}" == "${R26_BUNDLE_ROOT}/AgentLoop.app" ]] || r26_active_fail 70 "launch_ready_app_identity_${r26_label}"
  [[ "${R26_APP_EXECUTABLE}" == "${R26_APP}/Contents/MacOS/AgentLoop" ]] || r26_active_fail 70 "launch_ready_exec_identity_${r26_label}"
  r26_validate_bundle_root_ready
  if r26_info_sha="$(r26_sha "${R26_APP}/Contents/Info.plist")"; then :; else r26_active_fail 70 "launch_ready_info_sha_failed_${r26_label}"; fi
  [[ "${r26_info_sha}" == "${R26_INFO_PLIST_SHA}" ]] || r26_active_fail 70 "launch_ready_info_sha_drift_${r26_label}"
  if /usr/bin/python3 - "${R26_APP}/Contents/Info.plist" "${R26_BUNDLE_IDENTIFIER}" "${R26_STATE_ROOT}" <<'R26_LAUNCH_PLIST_CHECK'
import plistlib
import sys

path, identifier, state_root = sys.argv[1:]
with open(path, "rb") as handle:
    value = plistlib.load(handle)
expected = {
    "CFBundleExecutable": "AgentLoop",
    "CFBundleIdentifier": identifier,
    "CFBundleName": "AgentLoop",
    "CFBundlePackageType": "APPL",
    "LSEnvironment": {"AGENTLOOP_STATE_DIR": state_root, "AGENTLOOP_UI_PREVIEW": "1"},
    "LSMinimumSystemVersion": "14.0",
    "LSMultipleInstancesProhibited": True,
    "NSHighResolutionCapable": True,
}
raise SystemExit(0 if value == expected else 71)
R26_LAUNCH_PLIST_CHECK
  then :; else r26_active_fail 70 "launch_ready_plist_schema_drift_${r26_label}"; fi
  if r26_signature_detail="$(/usr/bin/codesign --display --verbose=4 "${R26_APP}" 2>&1)"; then :; else r26_active_fail 70 "launch_ready_codesign_display_failed_${r26_label}"; fi
  [[ "${r26_signature_detail}" == *$'Signature=adhoc'* && "${r26_signature_detail}" == *"Identifier=${R26_BUNDLE_IDENTIFIER}"* && "${r26_signature_detail}" == *$'TeamIdentifier=not set'* ]] || r26_active_fail 70 "launch_ready_signature_drift_${r26_label}"
  if r26_cdhash="$(/usr/bin/awk -F= '$1 == "CDHash" { print $2 }' <<< "${r26_signature_detail}")"; then :; else r26_active_fail 70 "launch_ready_cdhash_parse_failed_${r26_label}"; fi
  [[ "${r26_cdhash}" == "${R26_SIGNED_CDHASH}" ]] || r26_active_fail 70 "launch_ready_cdhash_drift_${r26_label}"
  if r26_post_build_count="$(r26_exact_line_count "${R26_BUNDLE_LOG}" 'section=POST_BUILD')"; then :; else r26_active_fail 70 "post_build_section_read_failed_${r26_label}"; fi
  if r26_pre_sign_count="$(r26_exact_line_count "${R26_BUNDLE_LOG}" 'section=PRE_SIGN')"; then :; else r26_active_fail 70 "pre_sign_section_read_failed_${r26_label}"; fi
  if r26_launch_ready_count="$(r26_exact_line_count "${R26_BUNDLE_LOG}" 'section=LAUNCH_READY')"; then :; else r26_active_fail 70 "launch_ready_section_read_failed_${r26_label}"; fi
  [[ "${r26_post_build_count}:${r26_pre_sign_count}:${r26_launch_ready_count}" == "1:1:1" ]] || r26_active_fail 70 "bundle_provenance_section_counts_${r26_label}"
  r26_require_no_process
}

r26_require_literal_hashes() {
  local r26_record=""
  local r26_expected=""
  local r26_path=""
  while IFS= read -r r26_record; do
    r26_expected="${r26_record%%  *}"
    r26_path="${r26_record#*  }"
    [[ "${r26_expected}" != "${r26_record}" ]] || r26_active_fail 70 "literal_hash_record_parse_failed"
    r26_require_sha_literal "literal_${r26_path}" "${r26_expected}"
    r26_require_sha "${r26_expected}" "${r26_path}"
  done <<'R26_LITERAL_HASHES'
80fdb08592d0e48b09b64f4bd17db5f54019e35ef9b738907915d6c429aa61d6  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Work/DurableWork.swift
e7cde04d577cc53b5b4ad0f8ad18bb4ca4ce604de18c660020fbc4096cd48f45  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift
f8842cbdde0bdb93c4139e59372cd897e8c091f79925a1cb9e18e8570ee954b5  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Database/DurableWorkStore.swift
147fac786fb877aae96423caa406af4f2d79c33f8298a164e9969cc518d558de  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Database/AppDatabase.swift
af5854b2545cf59f32ea8e216b7dc9d1e91b0387d2a8dda5e10030f3056f0d33  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Ingestion/IngestionRecords.swift
2d5907a5cbeb23934025e3fad248de7c719e61935f34ca7a776c8a525fb0fdae  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Ingestion/FeedService.swift
e1adf999b7b4d4b69ca5530601d3363fc691074d3dc5b4342b9ba36a95faeb6e  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Rumination/RuminationService.swift
80420d32709974fafcada2e6cb8cc71444792a2440c70c7901c514465ab1e8e3  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Rumination/RuminationParser.swift
b2f49eb3350aed0c1f03b574df5eadc09d5401b7c0a467ddc81e9af4819e87c2  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Kernel/Orchestrator.swift
1bf853e7bcd2addf679cf55588c0ae45f2b0d6955dda1e966e8629f11818dcd2  /Users/muzi/Agent-loop/Sources/AgentLoopApp/CodingRanchStoreAdapter.swift
0b3a918ac539c5975e9aa9a6583e2c6f723039b0f243bba497368f4d9d1f6e33  /Users/muzi/Agent-loop/Sources/AgentLoopApp/AppStore.swift
d0d769d025d5927485e833d327abb2c6b36fb5444a56a3c250dc11cea1448a6d  /Users/muzi/Agent-loop/Sources/AgentLoopApp/CodingRanchContracts.swift
54950383569ee7b0965364eda8a6402277e2c7f251aeab7de4f68340a4f97e34  /Users/muzi/Agent-loop/Sources/AgentLoopApp/Views/CodingRanch/RuminationViews.swift
5e311070fc5299fd4f576b4af6fb2286e4a515bf5b23a72d1ccc464c88c2c2bb  /Users/muzi/Agent-loop/Sources/AgentLoopTestSuite/CodingRanchTests.swift
818dfc5f897a0258b3113902f175d65bdf917732652ca44c08bd86fd0a2f0dd7  /Users/muzi/Agent-loop/Sources/AgentLoopTestSuite/DurableWorkTests.swift
863819791bbbead28c7fb0ba80540703fa275977682c846fbb8b415ce512c363  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Support/StateDirectoryLock.swift
eb5f8392870a8cca3a0e9729cc17082d259346b8187ff68cde9ee71ff1497386  /Users/muzi/Agent-loop/Sources/AgentLoopTestSuite/SupportTests.swift
094319b38c287a9265311fa60eb3c0e289555c6676dd0e3cfc0345cf289907c5  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Work/PlanningProviderResolver.swift
7ec1e5a45bc99d6af0270e84c535e59aa04cd57ae02e9f60537ec94c699b8be7  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Rumination/RuminationResult.swift
f0cd523ddf43789a9b0485bbcd0ee7b860b43a129795e06b1483c077d522623f  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Rumination/RuminationMaterializer.swift
1a3184711a261c15fa915571088ecbd9187c53a314139e41c8f336ffd51f7da4  /Users/muzi/Agent-loop/Sources/AgentLoopCore/Database/EventKind.swift
db9d0ef56158321bcfe5048778cc1b63bd592a7cbddb355fac42ec9169f0c267  /Users/muzi/Agent-loop/Sources/P1MigrationMatrixRunner/main.swift
577184382639ebe84f0c972b1aa1f43d67837683b74ab088d12198f72a16fe9d  /Users/muzi/Agent-loop/Package.swift
d2786c9b64c245c62f5793e697bb406d4960753e5f33c622250e804cd865fb3a  /Users/muzi/Agent-loop/Package.resolved
70417b226a6a3b83f2ef876628028a87618392cbb0688de903ce9d10305dbfd3  /Users/muzi/Agent-loop/Sources/RunTests/main.swift
5b34e5e98a0e91b4087e20525c3aba81e7955475865d2af70e6ae65736e7997b  /Users/muzi/Agent-loop/scripts/run-app.sh
7891aef62cfe26caef766572b5258f0fe206b7ccd8b6f039700834276e6a1705  /Users/muzi/Agent-loop/scripts/package-app.sh
3ebed0ed43157459a0d137bc296f875fdebc4f2eba6397007ccc86ac35e70754  /Users/muzi/Agent-loop/Sources/AgentLoopApp/Views/CodingRanch/RanchArtView.swift
R26_LITERAL_HASHES
}

r26_require_slice_sha() {
  local r26_path="$1"
  local r26_start="$2"
  local r26_end="$3"
  local r26_expected_lines="$4"
  local r26_expected_sha="$5"
  local r26_actual_sha=""
  local r26_actual_lines=""
  if r26_actual_sha="$({
      if /usr/bin/sed -n "${r26_start},${r26_end}p" "${r26_path}" |
        /usr/bin/shasum -a 256 |
        /usr/bin/awk '{print $1}'; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "3" ]] || exit 71
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" && "${r26_status[2]}" == "0" ]] || exit 72
    })"; then :; else r26_active_fail 70 "slice_sha_pipeline_failed_${r26_path}_${r26_start}_${r26_end}"; fi
  if r26_actual_lines="$(/usr/bin/awk -v first="${r26_start}" -v last="${r26_end}" 'NR >= first && NR <= last { count += 1 } END { print count + 0 }' "${r26_path}")"; then :; else r26_active_fail 70 "slice_line_count_failed_${r26_path}"; fi
  [[ "${r26_actual_lines}" == "${r26_expected_lines}" ]] || r26_active_fail 70 "slice_line_count_${r26_path}_${r26_actual_lines}"
  [[ "${r26_actual_sha}" == "${r26_expected_sha}" ]] || r26_active_fail 70 "slice_sha_mismatch_${r26_path}_${r26_actual_sha}"
}

r26_run_remaining_source_privacy_final_hashes() {
  local r26_source_test_output=""
  local r26_source_log_sha=""
  local r26_source_log_bytes=""
  local r26_diff_output=""
  local r26_git_status=""
  local r26_now_value=""
  local r26_stage_header=""
  R26_PHASE="remaining_source_privacy_final_hashes"
  [[ "${R26_MATRIX_MUTATED}" == "false" ]] || r26_active_fail 70 "source_gate_matrix_still_mutated"
  r26_require_sha "${R26_EXPECTED_MATRIX_ENTRY_SHA}" "${R26_MATRIX_SCRIPT}"
  r26_require_launch_ready_identity "source_pre"
  r26_require_verify_log_identity "source_contract_reader_pre"
  r26_require_literal_hashes
  r26_require_slice_sha "${R26_REPOSITORY_ROOT}/scripts/run-app.sh" 45 86 42 "6d6daeccd905540f9b59ecdb426da33c11b22029a5d37c91dd8a987421821c83"
  r26_require_slice_sha "${R26_REPOSITORY_ROOT}/scripts/run-app.sh" 88 103 16 "8d3f091cdc2916ec42fcaacf980b285c6fa3acc586c82fe9d24598b70b4fc9fa"
  r26_require_slice_sha "${R26_REPOSITORY_ROOT}/Sources/AgentLoopCore/Database/AppDatabase.swift" 21 612 592 "5bbb555016a64801c25be3634b0fcfcca0da8fe3b4d3cda493b0df3851a8ccff"
  r26_require_slice_sha "${R26_STAGE_PATH}" 3850 4036 187 "fb77180d6edd44413e41179e4b220666438e2660de11fbde1dafee78b6fde5c2"
  if r26_stage_header="$(/usr/bin/sed -n '3847p' "${R26_STAGE_PATH}")"; then :; else r26_active_fail 70 "stage_18_1_header_read_failed"; fi
  [[ "${r26_stage_header}" == '### 18.1 `v12-p1-durable-work`（P1-A1a）' ]] || r26_active_fail 70 "stage_18_1_header_line_drift"
  r26_require_sha "f52b1a98a81e39fed0d3c619ecca81dfa34f22eaf1fd507d79dbf2ed56c5e7d2" "${R26_TASK_DIRECTORY}/evidence/source-gates.log"
  r26_require_sha "12617d5dd3bb43eb9d10074a0aa5fe50328b88c22dac40232fc90f7e10a2765f" "${R26_TASK_DIRECTORY}/evidence/hash-manifest.log"
  r26_require_sha "5b6a171515404a644abcd05e3afc3840cb1dd4d84d7993f74af48de0692b4dd5" "${R26_TASK_DIRECTORY}/reviews/01-p1-a2-review.md"

  if /usr/bin/python3 - "${R26_REPOSITORY_ROOT}" <<'R26_SOURCE_ASSERTIONS'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
def text(relative):
    return (root / relative).read_text(encoding="utf-8")
def count(pattern, relative, flags=0):
    return len(re.findall(pattern, text(relative), flags))
def require(condition, code):
    if not condition:
        raise SystemExit(code)

core_tree = "\n".join(p.read_text(encoding="utf-8") for p in (root / "Sources/AgentLoopCore").rglob("*.swift"))
require(core_tree.count("suppressForOrchestratorRecoveryFailure") == 0, 71)
require(count(r"\bplanningTasks\b", "Sources/AgentLoopCore/Kernel/Orchestrator.swift") == 0, 72)
combined = "\n".join(text(p) for p in [
    "Sources/AgentLoopCore/Kernel/Orchestrator.swift",
    "Sources/AgentLoopApp/AppStore.swift",
    "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift",
])
require(len(re.findall(r"\b(createMissionShell|recordPlanningTokens|recordPlanFallback|planMission)\s*\(", combined)) == 0, 73)
app_calls = "\n".join(text(p) for p in [
    "Sources/AgentLoopApp/AppStore.swift",
    "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift",
    "Sources/AgentLoopApp/MissionScheduler.swift",
])
require(len(re.findall(r"\borchestrator\.(startMission|confirmSquadProposal)\s*\(", app_calls)) == 0, 74)
require(count(r"\bdb\.claimScheduleFire\s*\(", "Sources/AgentLoopApp/MissionScheduler.swift") == 0, 75)
require(count(r"\b(?:factory\.)?linkConverted\s*\(", "Sources/AgentLoopApp/CodingRanchStoreAdapter.swift") == 0, 76)
legacy_public = r"public func (claimNextPlanning|renewPlanningLease|nextClaimablePlanningDate|adoptInterruptedPlanning|commitPlanningSuccess|recordPlanningAttemptFailure|recordPlanningUsageOverflow|cancelPlanning|cancelAllPlanningForEmergencyHalt|repairLegacyPlanningMissions)\b"
require(count(legacy_public, "Sources/AgentLoopCore/Database/AppDatabase.swift") == 0, 77)
require(count(legacy_public, "Sources/AgentLoopCore/Database/DurableWorkStore.swift") == 0, 78)
require(count(r"kind: DurableWorkKind = \.planning|kinds: \[DurableWorkKind\] = \[\.planning\]", "Sources/AgentLoopTestSuite/DurableWorkTests.swift") == 0, 79)
require(count(r"^fileprivate enum PlanningDurableWorkLedgerOwner\b", "Sources/AgentLoopCore/Database/DurableWorkStore.swift", re.M) == 1, 80)

seam = re.compile(r"A2RuminationAuthorization(?:Checkpoint|Loss|Scenario)ForTesting|a2RuminationAuthorizationScenarioForTesting|armA2RuminationAuthorizationScenarioForTesting|consumeA2RuminationAuthorizationScenarioForTesting")
for relative, expected in [
    ("Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift", 17),
    ("Sources/AgentLoopTestSuite/CodingRanchTests.swift", 13),
    ("Sources/AgentLoopTestSuite/DurableWorkTests.swift", 7),
]:
    source = text(relative)
    depth = 0
    guarded = []
    for line in source.splitlines(True):
        if line.strip() == "#if DEBUG":
            require(depth == 0, 81)
            depth = 1
        if depth:
            guarded.append(line)
        if line.strip() == "#endif":
            require(depth == 1, 82)
            depth = 0
    require(depth == 0, 83)
    require(len(seam.findall(source)) == expected, 84)
    require(len(seam.findall("".join(guarded))) == expected, 85)
supervisor = text("Sources/AgentLoopCore/Work/DurableWorkSupervisor.swift")
depth = 0
guarded = []
for line in supervisor.splitlines(True):
    if line.strip() == "#if DEBUG": depth = 1
    if depth: guarded.append(line)
    if line.strip() == "#endif": depth = 0
guarded = "".join(guarded)
for forbidden in ["Mirror(", "unsafeBitCast(", "withUnsafe", "DurableWorkStore(", "database.execute(", ".pool.write", "handleValidatedRuminationTurn(", "validateRuminationPhaseOwnership(", "invalidateRuminationPhaseIfNeeded(", "latchFatalAndInvalidateRumination(", "deliverRuminationCommand(", "onRuminationPhase(", "RuminationParser.parse(", "parseValidatedTurn(", "produceValidatedTurn(", "Fake"]:
    require(forbidden not in guarded, 86)

coding = text("Sources/AgentLoopTestSuite/CodingRanchTests.swift")
durable = text("Sources/AgentLoopTestSuite/DurableWorkTests.swift")
require(coding.count("PlanningTestFixtures.uniqueFunction") == 19, 87)
require(durable.count("PlanningTestFixtures.uniqueFunction") == 1, 88)
definitions = {
    "ruminationSanitizesPersistedAndVisibleDiagnostics": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationProviderUsesNoToolsAndProducesOneCanonicalResult": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationUnknownRestartRendersRecoveringWithoutInventingReading": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents": "Sources/AgentLoopTestSuite/CodingRanchTests.swift",
    "ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal": "Sources/AgentLoopTestSuite/DurableWorkTests.swift",
    "ruminationUsageIsExactOrFailsBeforeAccounting": "Sources/AgentLoopTestSuite/DurableWorkTests.swift",
    "activeRuminationFencesDiscardDeleteAndArchiveRaces": "Sources/AgentLoopTestSuite/DurableWorkTests.swift",
    "stateDirectoryLockRejectsSecondFileDescriptionAndReleases": "Sources/AgentLoopTestSuite/SupportTests.swift",
}
for name, relative in definitions.items():
    require(count(r"@Test func " + re.escape(name) + r"\(", relative) == 1, 89)
R26_SOURCE_ASSERTIONS
  then :; else r26_active_fail 70 "source_contract_static_assertions_failed"; fi

  if r26_source_test_output="$(/usr/bin/awk -v joined='ruminationSanitizesPersistedAndVisibleDiagnostics|ruminationProviderUsesNoToolsAndProducesOneCanonicalResult|singleOrchestratorSupervisorOwnsPlanningAndRuminationLifecycle|ruminationAdapterDelegatesStartRetryCancelWithoutUnownedTask|ruminationUnknownRestartRendersRecoveringWithoutInventingReading|ruminationPhaseProjectionUsesOnlyMatchingSupervisorEvents|ruminationLivePhaseEventsAreOwnedOrderedAndProcessLocal|ruminationUsageIsExactOrFailsBeforeAccounting|activeRuminationFencesDiscardDeleteAndArchiveRaces|stateDirectoryLockRejectsSecondFileDescriptionAndReleases' '
      BEGIN { n = split(joined, names, "|") }
      {
        for (i = 1; i <= n; i += 1) {
          if ($0 == "◇ Test " names[i] "() started.") started[i] += 1
          if ($0 ~ ("^✔ Test " names[i] "\\(\\) passed after [0-9.]+ seconds\\.$")) passed[i] += 1
          if ($0 ~ ("^✘ Test " names[i] "\\(\\)")) failed[i] += 1
        }
      }
      END {
        ok = (n == 10)
        for (i = 1; i <= n; i += 1) {
          if (started[i] != 1 || passed[i] != 1 || failed[i] != 0) ok = 0
          print "source_contract_test=" names[i] " discovery=" (started[i] + 0) " pass=" (passed[i] + 0) " failure=" (failed[i] + 0)
        }
        print "source_contract_test_count=" n
        print "source_contract_tests_status=" (ok ? "PASS" : "FAIL")
      }
    ' "${R26_VERIFY_LOG}")"; then :; else r26_active_fail 70 "source_contract_same_log_scan_failed"; fi
  r26_require_verify_log_identity "source_contract_reader_post"
  [[ "${r26_source_test_output}" == *$'source_contract_tests_status=PASS' ]] || r26_active_fail 70 "source_contract_same_log_not_pass"

  if /usr/bin/python3 - "${R26_VERIFY_LOG}" "${R26_TARGETED_LOG}" "${R26_BUILD_LOG}" "${R26_MATRIX_LOG}" "${R26_BUNDLE_LOG}" "${R26_BOUNDARY_LOG}" "${R26_HASH_LOG}" <<'R26_PRIVACY_SCAN'
import re
import sys
from pathlib import Path

pattern = re.compile(rb"sk-[A-Za-z0-9_-]{20,}|Bearer\s+[A-Za-z0-9._-]{20,}|(?:access|refresh|id)_token[\"=:\s]+[A-Za-z0-9._-]{20,}", re.I)
for item in sys.argv[1:]:
    if pattern.search(Path(item).read_bytes()):
        raise SystemExit(71)
R26_PRIVACY_SCAN
  then :; else r26_active_fail 70 "pre_preview_runtime_privacy_scan_failed"; fi

  r26_validate_ranch_art_tree "${R26_RANCH_ART_DIRECTORY}"
  r26_require_branch_and_head
  r26_require_manifest
  r26_require_r23_predecessor
  r26_require_r24_predecessor
  r26_require_r25_predecessor
  r26_require_implementation_baseline
  if r26_diff_output="$(/usr/bin/git --no-optional-locks -C "${R26_REPOSITORY_ROOT}" diff --check)"; then :; else r26_active_fail 70 "git_diff_check_failed"; fi
  [[ -z "${r26_diff_output}" ]] || r26_active_fail 70 "git_diff_check_output"
  if r26_git_status="$(/usr/bin/git --no-optional-locks -C "${R26_REPOSITORY_ROOT}" status --short --branch)"; then :; else r26_active_fail 70 "git_status_failed"; fi
  r26_require_launch_ready_identity "source_post"
  r26_require_verify_log_identity "source_transition_adjacent"
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "source_gate_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=REMAINING_SOURCE_PRIVACY_FINAL_HASHES'
    /usr/bin/printf 'utc=%s\n' "${r26_now_value}"
    /usr/bin/printf '%s\n' "${r26_source_test_output}"
    /usr/bin/printf '%s\n' 'a1b_sentinels=PASS'
    /usr/bin/printf '%s\n' 'a2_seam_source_guards=PASS'
    /usr/bin/printf '%s\n' 'planning_unique_function_a2_callers=20'
    /usr/bin/printf '%s\n' 'same_log_source_contract_tests=10_of_10_PASS'
    /usr/bin/printf '%s\n' 'literal_hashes=PASS'
    /usr/bin/printf '%s\n' 'pre_preview_privacy_scan=PASS'
    /usr/bin/printf '%s\n' 'git_diff_check=PASS'
    /usr/bin/printf '%s\n' 'status=PASS'
  } >> "${R26_SOURCE_LOG}"
  if r26_source_log_sha="$(r26_sha "${R26_SOURCE_LOG}")"; then :; else r26_active_fail 70 "source_log_sha_failed"; fi
  if r26_source_log_bytes="$(/usr/bin/stat -f '%z' "${R26_SOURCE_LOG}")"; then :; else r26_active_fail 70 "source_log_bytes_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=pre_preview_final_hashes'
    /usr/bin/printf 'source_log_sha=%s\n' "${r26_source_log_sha}"
    /usr/bin/printf 'source_log_bytes=%s\n' "${r26_source_log_bytes}"
    /usr/bin/printf 'matrix_script_sha=%s\n' "${R26_EXPECTED_MATRIX_ENTRY_SHA}"
    /usr/bin/printf 'core_sha=%s\n' "${R26_EXPECTED_CORE_SHA}"
    /usr/bin/printf 'test_sha=%s\n' "${R26_EXPECTED_TEST_SHA}"
    /usr/bin/printf 'verify_sha=%s\n' "${R26_VERIFY_LOG_SHA}"
    /usr/bin/printf 'bundle_manifest_sha=%s\n' "${R26_SIGNED_BUNDLE_MANIFEST_SHA}"
    /usr/bin/printf 'git_status_begin\n%s\ngit_status_end\n' "${r26_git_status}"
  } >> "${R26_HASH_LOG}"
  r26_append_boundary 'remaining_source_privacy_final_hashes=PASS'
  r26_append_boundary 'manifest_final_pre_preview=206_of_206'
  r26_append_boundary 'next_in_process_gate=same_bundle_preview'
}

r26_pgrep_exact_name() {
  local r26_name="$1"
  local r26_output=""
  local r26_rc=0
  if r26_output="$(/usr/bin/pgrep -x "${r26_name}")"; then
    r26_rc=0
  else
    r26_rc="$?"
  fi
  case "${r26_rc}" in
    0) [[ -n "${r26_output}" ]] || return 71 ;;
    1) [[ -z "${r26_output}" ]] || return 72 ;;
    *) return 73 ;;
  esac
  /usr/bin/printf '%s\n' "${r26_output}"
  return "${r26_rc}"
}

r26_preview_state_ready_probe() {
  local r26_output=""
  if r26_output="$({
      if /usr/bin/find -P "${R26_STATE_ROOT}" -mindepth 1 -maxdepth 1 -print0 |
        /usr/bin/sort -z |
        /bin/bash --noprofile --norc -c '
          set -u
          root="$1"
          lock_seen=0
          db_seen=0
          shm_seen=0
          wal_seen=0
          while :; do
            path=""
            IFS= read -r -d "" path
            read_rc=$?
            if [[ "${read_rc}" == "1" ]]; then [[ -z "${path}" ]] || exit 72; break; fi
            [[ "${read_rc}" == "0" ]] || exit 73
            [[ -f "${path}" && ! -L "${path}" ]] || exit 76
            case "${path}" in
              "${root}/.agentloop.lock") [[ "${lock_seen}" == "0" ]] || exit 74; lock_seen=1 ;;
              "${root}/agentloop.sqlite") [[ "${db_seen}" == "0" ]] || exit 74; db_seen=1 ;;
              "${root}/agentloop.sqlite-shm") [[ "${shm_seen}" == "0" ]] || exit 74; shm_seen=1 ;;
              "${root}/agentloop.sqlite-wal") [[ "${wal_seen}" == "0" ]] || exit 74; wal_seen=1 ;;
              *) exit 75 ;;
            esac
          done
          /usr/bin/printf "%s\n" "$((lock_seen + db_seen + shm_seen + wal_seen))"
        ' bash "${R26_STATE_ROOT}"; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "3" ]] || exit 77
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" && "${r26_status[2]}" == "0" ]] || exit 78
    })"; then
    :
  else
    return 2
  fi
  [[ "${r26_output}" == "4" ]] || return 1
  return 0
}

# 0 means the exact isolated open-file set is ready, 1 is a safe startup
# subset, and 2 is an identity/isolation violation or indeterminate failure.
r26_preview_process_ready_probe() {
  local r26_command=""
  local r26_birth=""
  local r26_ppid=""
  local r26_env_line=""
  local r26_env_shape=""
  local r26_lsof_output=""
  local r26_lsof_shape=""
  case "${R26_APP_PID}" in ''|*[!0-9]*) return 2 ;; esac
  /bin/kill -0 "${R26_APP_PID}" 2>/dev/null || return 2
  if r26_birth="$(/bin/ps -p "${R26_APP_PID}" -o lstart= 2>/dev/null)"; then :; else return 2; fi
  [[ -n "${R26_APP_BIRTH}" && "${r26_birth}" == "${R26_APP_BIRTH}" ]] || return 2
  if r26_ppid="$(/bin/ps -p "${R26_APP_PID}" -o ppid= 2>/dev/null)"; then :; else return 2; fi
  r26_ppid="${r26_ppid// /}"
  r26_ppid="${r26_ppid//$'\t'/}"
  [[ "${r26_ppid}" == "$$" ]] || return 2
  if r26_command="$(/bin/ps -ww -p "${R26_APP_PID}" -o command= 2>/dev/null)"; then
    :
  else
    /bin/kill -0 "${R26_APP_PID}" 2>/dev/null || return 2
    return 1
  fi
  [[ "${r26_command}" == "${R26_APP_EXECUTABLE}" ]] || return 1
  if r26_env_line="$(/bin/ps eww -p "${R26_APP_PID}" -o command= 2>/dev/null)"; then :; else return 2; fi
  if r26_env_shape="$(/usr/bin/awk -v state="AGENTLOOP_STATE_DIR=${R26_STATE_ROOT}" '
      { for (i = 1; i <= NF; i += 1) { if ($i == state) state_count += 1; if ($i == "AGENTLOOP_UI_PREVIEW=1") preview_count += 1; if ($i ~ /^AGENTLOOP_BOARD_/) board_count += 1 } }
      END { print state_count + 0 ":" preview_count + 0 ":" board_count + 0 }
    ' <<< "${r26_env_line}")"; then :; else return 2; fi
  [[ "${r26_env_shape}" == "1:1:0" ]] || return 2
  if r26_lsof_output="$(/usr/sbin/lsof -p "${R26_APP_PID}" -Fn 2>/dev/null)"; then :; else
    /bin/kill -0 "${R26_APP_PID}" 2>/dev/null || return 2
    return 1
  fi
  if r26_lsof_shape="$(/usr/bin/python3 -c '
import sys
root = sys.argv[1]
exact_exec = sys.argv[2]
normal = "/Users/muzi/Library/Application Support/AgentLoop"
expected = {root + "/.agentloop.lock", root + "/agentloop.sqlite", root + "/agentloop.sqlite-shm", root + "/agentloop.sqlite-wal"}
paths = [line[1:] for line in sys.stdin.read().splitlines() if line.startswith("n")]
normal_count = sum(path == normal or path.startswith(normal + "/") for path in paths)
isolated = {path for path in paths if path.startswith(root + "/")}
unexpected = len(isolated - expected)
exact_exec_count = sum(path == exact_exec for path in paths)
print(f"{normal_count}:{unexpected}:{exact_exec_count}:{1 if isolated == expected else 0}")
' "${R26_STATE_ROOT}" "${R26_APP_EXECUTABLE}" <<< "${r26_lsof_output}")"; then :; else return 2; fi
  case "${r26_lsof_shape}" in
    0:0:1:1) return 0 ;;
    0:0:1:0) return 1 ;;
    *) return 2 ;;
  esac
}

r26_require_live_preview_process() {
  local r26_label="$1"
  local r26_pids=""
  local r26_app_pids=""
  local r26_command=""
  local r26_birth=""
  local r26_ppid=""
  local r26_txt=""
  local r26_env_line=""
  local r26_env_shape=""
  local r26_lsof_output=""
  local r26_lsof_shape=""
  local r26_children=""
  local r26_child_rc=0
  local r26_current_exec_sha=""
  local r26_current_bundle_sha=""
  case "${R26_APP_PID}" in ''|*[!0-9]*) r26_active_fail 70 "preview_pid_not_numeric_${r26_label}" ;; esac
  if /bin/kill -0 "${R26_APP_PID}" 2>/dev/null; then :; else r26_active_fail 70 "preview_pid_not_live_${r26_label}"; fi
  if r26_pids="$(r26_pgrep_exact_name AgentLoop)"; then :; else r26_active_fail 70 "preview_global_AgentLoop_probe_${r26_label}"; fi
  [[ "${r26_pids}" == "${R26_APP_PID}" ]] || r26_active_fail 70 "preview_global_pid_mismatch_${r26_label}_${r26_pids}"
  if r26_app_pids="$(r26_pgrep_exact_name AgentLoopApp)"; then
    r26_active_fail 70 "preview_AgentLoopApp_present_${r26_label}_${r26_app_pids}"
  else
    [[ "$?" == "1" ]] || r26_active_fail 70 "preview_AgentLoopApp_probe_indeterminate_${r26_label}"
  fi
  if r26_command="$(/bin/ps -ww -p "${R26_APP_PID}" -o command=)"; then :; else r26_active_fail 70 "preview_command_read_failed_${r26_label}"; fi
  [[ "${r26_command}" == "${R26_APP_EXECUTABLE}" ]] || r26_active_fail 70 "preview_command_mismatch_${r26_label}_${r26_command}"
  if r26_ppid="$(/bin/ps -p "${R26_APP_PID}" -o ppid=)"; then :; else r26_active_fail 70 "preview_ppid_read_failed_${r26_label}"; fi
  r26_ppid="${r26_ppid// /}"
  r26_ppid="${r26_ppid//$'\t'/}"
  [[ "${r26_ppid}" == "$$" ]] || r26_active_fail 70 "preview_ppid_mismatch_${r26_label}_${r26_ppid}_expected_$$"
  R26_APP_PPID="${r26_ppid}"
  if r26_birth="$(/bin/ps -p "${R26_APP_PID}" -o lstart=)"; then :; else r26_active_fail 70 "preview_birth_read_failed_${r26_label}"; fi
  [[ -n "${r26_birth}" && "${r26_birth}" != *$'\n'* ]] || r26_active_fail 70 "preview_birth_invalid_${r26_label}"
  if [[ -z "${R26_APP_BIRTH}" ]]; then R26_APP_BIRTH="${r26_birth}"; else [[ "${r26_birth}" == "${R26_APP_BIRTH}" ]] || r26_active_fail 70 "preview_pid_birth_replacement_${r26_label}"; fi
  if r26_txt="$(/usr/sbin/lsof -a -p "${R26_APP_PID}" -d txt -Fn)"; then :; else r26_active_fail 70 "preview_txt_lsof_failed_${r26_label}"; fi
  if r26_txt="$(/usr/bin/awk -v expected="n${R26_APP_EXECUTABLE}" '
      /^n/ { total += 1; if ($0 == expected) exact += 1 }
      END { print total + 0 ":" exact + 0 }
    ' <<< "${r26_txt}")"; then :; else r26_active_fail 70 "preview_txt_parse_failed_${r26_label}"; fi
  [[ "${r26_txt##*:}" == "1" && "${r26_txt%%:*}" -ge 1 ]] || r26_active_fail 70 "preview_txt_identity_mismatch_${r26_label}_${r26_txt}"
  if r26_env_line="$(/bin/ps eww -p "${R26_APP_PID}" -o command=)"; then :; else r26_active_fail 70 "preview_env_read_failed_${r26_label}"; fi
  if r26_env_shape="$(/usr/bin/awk -v state="AGENTLOOP_STATE_DIR=${R26_STATE_ROOT}" '
      { for (i = 1; i <= NF; i += 1) { if ($i == state) state_count += 1; if ($i == "AGENTLOOP_UI_PREVIEW=1") preview_count += 1; if ($i ~ /^AGENTLOOP_BOARD_/) board_count += 1 } }
      END { print state_count + 0 ":" preview_count + 0 ":" board_count + 0 }
    ' <<< "${r26_env_line}")"; then :; else r26_active_fail 70 "preview_env_parse_failed_${r26_label}"; fi
  [[ "${r26_env_shape}" == "1:1:0" ]] || r26_active_fail 70 "preview_safe_env_shape_${r26_label}_${r26_env_shape}"
  if r26_lsof_output="$(/usr/sbin/lsof -p "${R26_APP_PID}" -Fn)"; then :; else r26_active_fail 70 "preview_lsof_failed_${r26_label}"; fi
  if r26_lsof_shape="$(/usr/bin/python3 -c '
import sys
root = sys.argv[1]
normal = "/Users/muzi/Library/Application Support/AgentLoop"
expected = {root + "/.agentloop.lock", root + "/agentloop.sqlite", root + "/agentloop.sqlite-shm", root + "/agentloop.sqlite-wal"}
paths = [line[1:] for line in sys.stdin.read().splitlines() if line.startswith("n")]
normal_count = sum(path == normal or path.startswith(normal + "/") for path in paths)
isolated = {path for path in paths if path.startswith(root + "/")}
print(f"{normal_count}:{1 if isolated == expected else 0}")
' "${R26_STATE_ROOT}" <<< "${r26_lsof_output}")"; then :; else r26_active_fail 70 "preview_lsof_parse_failed_${r26_label}"; fi
  [[ "${r26_lsof_shape}" == "0:1" ]] || r26_active_fail 70 "preview_lsof_shape_${r26_label}_${r26_lsof_shape}"
  if r26_children="$(/usr/bin/pgrep -P "${R26_APP_PID}")"; then
    r26_child_rc=0
  else
    r26_child_rc="$?"
  fi
  [[ "${r26_child_rc}" == "1" && -z "${r26_children}" ]] || r26_active_fail 70 "preview_children_present_or_unknown_${r26_label}_${r26_child_rc}_${r26_children}"
  if r26_current_exec_sha="$(r26_sha "${R26_APP_EXECUTABLE}")"; then :; else r26_active_fail 70 "preview_exec_sha_failed_${r26_label}"; fi
  if r26_current_bundle_sha="$(r26_tree_manifest_sha "${R26_APP}")"; then :; else r26_active_fail 70 "preview_bundle_sha_failed_${r26_label}"; fi
  [[ "${r26_current_exec_sha}" == "${R26_SIGNED_EXECUTABLE_SHA}" && "${r26_current_bundle_sha}" == "${R26_SIGNED_BUNDLE_MANIFEST_SHA}" ]] || r26_active_fail 70 "preview_bundle_identity_drift_${r26_label}"
}

r26_new_nonce() {
  local r26_nonce=""
  if r26_nonce="$({
      if /usr/bin/uuidgen | /usr/bin/tr -d '-' | /usr/bin/tr '[:upper:]' '[:lower:]'; then
        r26_status=("${PIPESTATUS[@]}")
      else
        r26_status=("${PIPESTATUS[@]}")
      fi
      [[ "${#r26_status[@]}" == "3" ]] || exit 71
      [[ "${r26_status[0]}" == "0" && "${r26_status[1]}" == "0" && "${r26_status[2]}" == "0" ]] || exit 72
    })"; then :; else return "$?"; fi
  [[ "${#r26_nonce}" == "32" && "${r26_nonce}" != *[!0-9a-f]* ]] || return 73
  /usr/bin/printf '%s\n' "${r26_nonce}"
}

r26_start_direct_bootstrap() {
  local r26_index=0
  local r26_probe_rc=0
  local r26_process_probe_rc=0
  local r26_now_value=""
  R26_PHASE="preview_bootstrap_direct_start"
  r26_require_launch_ready_identity "bootstrap_pre_launch"
  r26_validate_empty_exact_root "${R26_STATE_ROOT}"
  R26_APP_BIRTH=""
  R26_APP_PPID=""
  r26_begin_preview_launch_identity_window
  AGENTLOOP_STATE_DIR="${R26_STATE_ROOT}" AGENTLOOP_UI_PREVIEW=1 \
    "${R26_APP_EXECUTABLE}" >> "${R26_BOOTSTRAP_LOG}" 2>&1 < /dev/null &
  R26_APP_PID="$!" R26_APP_DIRECT_CHILD_OWNED="true"
  case "${R26_APP_PID}" in ''|*[!0-9]*) r26_active_fail 70 "bootstrap_pid_not_numeric" ;; esac
  r26_capture_preview_launch_identity || r26_active_fail 70 "bootstrap_identity_capture_failed"
  r26_commit_preview_launch_identity_window "bootstrap"
  R26_BOOTSTRAP_PID="${R26_APP_PID}"
  R26_BOOTSTRAP_BIRTH="${R26_APP_BIRTH}"
  while (( r26_index < 150 )); do
    if r26_preview_state_ready_probe; then
      r26_probe_rc=0
    else
      r26_probe_rc="$?"
    fi
    [[ "${r26_probe_rc}" == "0" || "${r26_probe_rc}" == "1" ]] || r26_active_fail 70 "bootstrap_state_ready_probe_error_${r26_probe_rc}"
    if r26_preview_process_ready_probe; then
      r26_process_probe_rc=0
    else
      r26_process_probe_rc="$?"
    fi
    [[ "${r26_process_probe_rc}" == "0" || "${r26_process_probe_rc}" == "1" ]] || r26_active_fail 70 "bootstrap_process_ready_probe_error_${r26_process_probe_rc}"
    if [[ "${r26_probe_rc}" == "0" && "${r26_process_probe_rc}" == "0" ]]; then break; fi
    if /bin/kill -0 "${R26_APP_PID}" 2>/dev/null; then :; else r26_active_fail 70 "bootstrap_process_exited_before_ready"; fi
    /bin/sleep 0.1
    r26_index=$((r26_index + 1))
  done
  [[ "${r26_probe_rc}" == "0" && "${r26_process_probe_rc}" == "0" ]] || r26_active_fail 70 "bootstrap_ready_timeout"
  R26_CURRENT_ROOT_PHASE="preview_live"
  r26_require_live_preview_process "bootstrap_ready"
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "bootstrap_start_timestamp_failed"; fi
  {
    /usr/bin/printf 'preview.bootstrap.started_at=%s\n' "${r26_now_value}"
    /usr/bin/printf '%s\n' 'preview.bootstrap.launch_transport=direct_exact_executable_with_explicit_env'
    /usr/bin/printf 'preview.bootstrap.app=%s\n' "${R26_APP}"
    /usr/bin/printf 'preview.bootstrap.executable=%s\n' "${R26_APP_EXECUTABLE}"
    /usr/bin/printf 'preview.bootstrap.pid=%s\n' "${R26_APP_PID}"
    /usr/bin/printf 'preview.bootstrap.ppid=%s\n' "${R26_APP_PPID}"
    /usr/bin/printf '%s\n' 'preview.bootstrap.direct_child=true'
    /usr/bin/printf 'preview.bootstrap.bundle_identifier=%s\n' "${R26_BUNDLE_IDENTIFIER}"
    /usr/bin/printf 'preview.environment.AGENTLOOP_STATE_DIR=%s\n' "${R26_STATE_ROOT}"
    /usr/bin/printf '%s\n' 'preview.environment.AGENTLOOP_UI_PREVIEW=1'
    /usr/bin/printf '%s\n' 'preview.bootstrap.pid_source=direct_child_dollar_bang'
    /usr/bin/printf '%s\n' 'preview.bootstrap.launchservices_fallback_configured_and_signed=true'
    /usr/bin/printf '%s\n' 'preview.bootstrap.normal_root_open_observed_count=0'
  } >> "${R26_BOOTSTRAP_LOG}"
}

r26_start_direct_cold_preview() {
  local r26_index=0
  local r26_probe_rc=0
  local r26_process_probe_rc=0
  local r26_now_value=""
  R26_PHASE="preview_cold_direct_start"
  r26_require_launch_ready_identity "cold_pre_launch"
  R26_APP_BIRTH=""
  R26_APP_PPID=""
  r26_begin_preview_launch_identity_window
  AGENTLOOP_STATE_DIR="${R26_STATE_ROOT}" AGENTLOOP_UI_PREVIEW=1 \
    "${R26_APP_EXECUTABLE}" >> "${R26_COLD_START_LOG}" 2>&1 < /dev/null &
  R26_APP_PID="$!" R26_APP_DIRECT_CHILD_OWNED="true"
  case "${R26_APP_PID}" in ''|*[!0-9]*) r26_active_fail 70 "cold_pid_not_numeric" ;; esac
  r26_capture_preview_launch_identity || r26_active_fail 70 "cold_identity_capture_failed"
  r26_commit_preview_launch_identity_window "cold"
  [[ -n "${R26_BOOTSTRAP_PID}" && -n "${R26_BOOTSTRAP_BIRTH}" ]] || r26_active_fail 70 "cold_bootstrap_identity_missing"
  [[ "${R26_APP_PID}" != "${R26_BOOTSTRAP_PID}" ]] || r26_active_fail 70 "cold_reused_bootstrap_pid"
  [[ "${R26_APP_BIRTH}" != "${R26_BOOTSTRAP_BIRTH}" ]] || r26_active_fail 70 "cold_reused_bootstrap_birth"
  while (( r26_index < 150 )); do
    if r26_preview_state_ready_probe; then
      r26_probe_rc=0
    else
      r26_probe_rc="$?"
    fi
    [[ "${r26_probe_rc}" == "0" || "${r26_probe_rc}" == "1" ]] || r26_active_fail 70 "cold_state_ready_probe_error_${r26_probe_rc}"
    if r26_preview_process_ready_probe; then
      r26_process_probe_rc=0
    else
      r26_process_probe_rc="$?"
    fi
    [[ "${r26_process_probe_rc}" == "0" || "${r26_process_probe_rc}" == "1" ]] || r26_active_fail 70 "cold_process_ready_probe_error_${r26_process_probe_rc}"
    if [[ "${r26_probe_rc}" == "0" && "${r26_process_probe_rc}" == "0" ]]; then break; fi
    if /bin/kill -0 "${R26_APP_PID}" 2>/dev/null; then :; else r26_active_fail 70 "cold_process_exited_before_ready"; fi
    /bin/sleep 0.1
    r26_index=$((r26_index + 1))
  done
  [[ "${r26_probe_rc}" == "0" && "${r26_process_probe_rc}" == "0" ]] || r26_active_fail 70 "cold_ready_timeout"
  R26_CURRENT_ROOT_PHASE="preview_live"
  r26_require_live_preview_process "cold_ready"
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "cold_start_timestamp_failed"; fi
  {
    /usr/bin/printf 'preview.cold_start.started_at=%s\n' "${r26_now_value}"
    /usr/bin/printf '%s\n' 'preview.cold_start.launch_transport=direct_exact_executable_with_explicit_env'
    /usr/bin/printf 'preview.cold_start.pid=%s\n' "${R26_APP_PID}"
    /usr/bin/printf 'preview.cold_start.ppid=%s\n' "${R26_APP_PPID}"
    /usr/bin/printf '%s\n' 'preview.cold_start.direct_child=true'
    /usr/bin/printf '%s\n' 'preview.cold_start.lifecycle_distinct_from_bootstrap=true'
    /usr/bin/printf 'preview.cold_start.bundle_identifier=%s\n' "${R26_BUNDLE_IDENTIFIER}"
    /usr/bin/printf '%s\n' 'preview.cold_start.normal_root_open_observed_count=0'
  } >> "${R26_COLD_START_LOG}"
}

r26_cu_log_path() {
  case "$1" in
    bootstrap) /usr/bin/printf '%s\n' "${R26_BOOTSTRAP_LOG}" ;;
    cold) /usr/bin/printf '%s\n' "${R26_COLD_START_LOG}" ;;
    *) return 71 ;;
  esac
}

r26_cu_exchange_exact() {
  local r26_phase="$1"
  local r26_step="$2"
  local r26_allowed_scope="$3"
  local r26_expected_metrics="$4"
  local r26_quit_step="$5"
  local r26_nonce=""
  local r26_log=""
  local r26_challenge=""
  local r26_expected=""
  local r26_reply=""
  [[ "${r26_quit_step}" == "true" || "${r26_quit_step}" == "false" ]] || r26_active_fail 70 "cu_quit_flag_invalid_${r26_phase}_${r26_step}"
  [[ -n "${r26_allowed_scope}" && "${r26_allowed_scope}" != *'|'* && "${r26_allowed_scope}" != *$'\n'* ]] || r26_active_fail 70 "cu_allowed_scope_invalid_${r26_phase}_${r26_step}"
  if r26_nonce="$(r26_new_nonce)"; then :; else r26_active_fail 70 "cu_nonce_failed_${r26_phase}_${r26_step}"; fi
  if r26_log="$(r26_cu_log_path "${r26_phase}")"; then :; else r26_active_fail 70 "cu_log_path_failed_${r26_phase}"; fi
  r26_require_live_preview_process "cu_${r26_phase}_${r26_step}_pre"
  r26_challenge="R26_CU_CHALLENGE_V1|invocation_id=${R26_INVOCATION_ID}|phase=${r26_phase}|step=${r26_step}|nonce=${r26_nonce}|pid=${R26_APP_PID}|app=${R26_APP}|exec=${R26_APP_EXECUTABLE}|exec_sha=${R26_SIGNED_EXECUTABLE_SHA}|bundle_sha=${R26_SIGNED_BUNDLE_MANIFEST_SHA}|bundle_id=${R26_BUNDLE_IDENTIFIER}|state_root=${R26_STATE_ROOT}|raw_path=NONE|allowed_scope=${r26_allowed_scope}|full_state_disableDiff=true|coordinates_forbidden=true|fallback_lookup_forbidden=true|timeout_s=180"
  /usr/bin/printf 'control.challenge=%s\n' "${r26_challenge}" >> "${r26_log}"
  /usr/bin/printf '%s\n' "${r26_challenge}"
  if IFS= read -r -t 180 r26_reply; then :; else r26_active_fail 70 "cu_reply_timeout_or_eof_${r26_phase}_${r26_step}"; fi
  [[ "${#r26_reply}" -le 4096 && "${r26_reply}" != *$'\r'* && "${r26_reply}" != *$'\n'* ]] || r26_active_fail 70 "cu_reply_shape_${r26_phase}_${r26_step}"
  r26_expected="R26_CU_RESULT_V1|invocation_id=${R26_INVOCATION_ID}|phase=${r26_phase}|step=${r26_step}|nonce=${r26_nonce}|status=PASS|${r26_expected_metrics}"
  [[ "${r26_reply}" == "${r26_expected}" ]] || r26_active_fail 70 "cu_reply_mismatch_${r26_phase}_${r26_step}"
  /usr/bin/printf 'control.result=%s\n' "${r26_reply}" >> "${r26_log}"
  if [[ "${r26_quit_step}" == "false" ]]; then
    r26_require_live_preview_process "cu_${r26_phase}_${r26_step}_post"
  fi
}

r26_wait_owned_preview_exit() {
  local r26_phase="$1"
  local r26_pid="${R26_APP_PID}"
  local r26_birth="${R26_APP_BIRTH}"
  local r26_job_rc=0
  local r26_current_birth=""
  local r26_ppid=""
  local r26_wait_rc=0
  local r26_index=0
  local r26_log=""
  local r26_now_value=""
  case "${r26_pid}" in ''|*[!0-9]*) r26_active_fail 70 "quit_wait_pid_not_numeric_${r26_phase}" ;; esac
  [[ -n "${r26_birth}" ]] || r26_active_fail 70 "quit_wait_birth_missing_${r26_phase}"
  [[ "${R26_APP_DIRECT_CHILD_OWNED}" == "true" && "${R26_APP_IDENTITY_COMMITTED}" == "true" ]] || r26_active_fail 70 "quit_wait_child_ownership_missing_${r26_phase}"
  while (( r26_index < 150 )); do
    if r26_preview_active_job_exact; then
      if r26_current_birth="$(/bin/ps -p "${r26_pid}" -o lstart= 2>/dev/null)"; then
        [[ "${r26_current_birth}" == "${r26_birth}" ]] || r26_active_fail 70 "quit_wait_pid_birth_replaced_${r26_phase}"
      else
        if r26_preview_active_job_exact; then :; else
          r26_job_rc="$?"
          if [[ "${r26_job_rc}" == "1" ]]; then break; fi
        fi
        r26_active_fail 70 "quit_wait_birth_read_failed_while_live_${r26_phase}"
      fi
      if r26_ppid="$(/bin/ps -p "${r26_pid}" -o ppid= 2>/dev/null)"; then
        :
      else
        if r26_preview_active_job_exact; then :; else
          r26_job_rc="$?"
          if [[ "${r26_job_rc}" == "1" ]]; then break; fi
        fi
        r26_active_fail 70 "quit_wait_ppid_read_failed_while_live_${r26_phase}"
      fi
      r26_ppid="${r26_ppid// /}"
      r26_ppid="${r26_ppid//$'\t'/}"
      [[ "${r26_ppid}" == "$$" ]] || r26_active_fail 70 "quit_wait_ppid_mismatch_${r26_phase}_${r26_ppid}_expected_$$"
      /bin/sleep 0.1
      r26_index=$((r26_index + 1))
      continue
    fi
    r26_job_rc="$?"
    [[ "${r26_job_rc}" == "1" ]] || r26_active_fail 70 "quit_wait_job_table_indeterminate_${r26_phase}_${r26_job_rc}"
    break
  done
  (( r26_index < 150 )) || r26_active_fail 70 "quit_wait_timeout_${r26_phase}"
  if wait "${r26_pid}"; then
    r26_wait_rc="$?"
  else
    r26_wait_rc="$?"
  fi
  [[ "${r26_wait_rc}" == "0" ]] || r26_active_fail 70 "quit_wait_child_status_${r26_phase}_${r26_wait_rc}"
  r26_clear_owned_preview_identity
  r26_require_no_process
  R26_CURRENT_ROOT_PHASE="preview_quiescent"
  r26_validate_current_roots_phase
  if r26_log="$(r26_cu_log_path "${r26_phase}")"; then :; else r26_active_fail 70 "quit_wait_log_path_failed_${r26_phase}"; fi
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "quit_wait_timestamp_failed_${r26_phase}"; fi
  {
    /usr/bin/printf 'preview.%s.quit_child_status=%s\n' "${r26_phase}" "${r26_wait_rc}"
    /usr/bin/printf 'preview.%s.quit_pid_identity_preserved=true\n' "${r26_phase}"
    /usr/bin/printf 'preview.%s.global_process_count_after_quit=0\n' "${r26_phase}"
    /usr/bin/printf 'preview.%s.quiescent_state_shape=PASS\n' "${r26_phase}"
    /usr/bin/printf 'preview.%s.quit_completed_at=%s\n' "${r26_phase}" "${r26_now_value}"
  } >> "${r26_log}"
}

r26_install_preview_fixture() {
  local r26_database="${R26_STATE_ROOT}/agentloop.sqlite"
  local r26_output=""
  local r26_fixture_sha=""
  local r26_now_value=""
  R26_PHASE="preview_fixture_install"
  r26_require_no_process
  [[ "${R26_CURRENT_ROOT_PHASE}" == "preview_quiescent" ]] || r26_active_fail 70 "fixture_wrong_root_phase_${R26_CURRENT_ROOT_PHASE}"
  r26_validate_current_roots_phase
  if r26_output="$(/usr/bin/python3 - "${r26_database}" <<'R26_FIXTURE_PY'
import sqlite3
import sys

path = sys.argv[1]
ingestion_id = "a2-preview-ingestion-recovering"
work_id = "a2-preview-work-recovering"
trace_id = "a2-preview-synthetic-trace"
idempotency_key = "rumination-start:a2-preview-ingestion-recovering:1:v1"
raw_text = "A2 isolated synthetic rumination fixture"
raw_hash = "5bfb45aa64ed74731df07ba237682cd525de94b341b8355945f75bb19fd8c5b3"
input_json = '{"model":"preview-model","pipelineVersion":"coding-ranch-v1","runtimeProfileId":"preview-profile"}'
input_hash = "b3c41c894ab7add26938126da5be12bd71cecb51960dcd3e512d657052e8c721"
when = "2026-08-10 00:00:00.000"

connection = sqlite3.connect(path, timeout=5.0)
try:
    connection.execute("PRAGMA foreign_keys = ON")
    if connection.execute("PRAGMA foreign_keys").fetchone() != (1,):
        raise SystemExit(71)
    camps = connection.execute("SELECT id FROM camp ORDER BY createdAt, rowid").fetchall()
    if len(camps) != 1 or not isinstance(camps[0][0], str):
        raise SystemExit(72)
    camp_id = camps[0][0]
    if connection.execute("SELECT COUNT(*) FROM ingestion_item").fetchone() != (0,):
        raise SystemExit(73)
    if connection.execute("SELECT COUNT(*) FROM durable_work").fetchone() != (0,):
        raise SystemExit(74)
    connection.execute("BEGIN IMMEDIATE")
    connection.execute(
        """
        INSERT INTO ingestion_item (
          id, campId, sourceType, title, rawText, sourceURL, author, userIntent,
          contentHash, status, attempt, errorText, createdAt, updatedAt
        ) VALUES (?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, ?, NULL, ?, ?)
        """,
        (
            ingestion_id, camp_id, "manual", "隔离恢复验证", raw_text,
            raw_hash, "ruminating", 1, when, when,
        ),
    )
    connection.execute(
        """
        INSERT INTO durable_work (
          id, campId, kind, aggregateType, aggregateId, idempotencyKey, state,
          attempt, maxAttempts, notBefore, leaseOwner, leaseExpiresAt,
          inputJson, inputHash, outputJson, errorCode, errorMessage, traceId,
          version, createdAt, updatedAt, finishedAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, ?, ?, NULL,
                  NULL, NULL, ?, ?, ?, ?, NULL)
        """,
        (
            work_id, camp_id, "rumination", "ingestion", ingestion_id,
            idempotency_key, "queued", 0, 4, input_json, input_hash,
            trace_id, 1, when, when,
        ),
    )
    if connection.execute("PRAGMA foreign_key_check").fetchall() != []:
        raise SystemExit(75)
    if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
        raise SystemExit(76)
    ingestion = connection.execute(
        """
        SELECT id, campId, sourceType, title, rawText, sourceURL, author,
               userIntent, contentHash, status, attempt, errorText
        FROM ingestion_item
        """
    ).fetchall()
    expected_ingestion = [(
        ingestion_id, camp_id, "manual", "隔离恢复验证", raw_text, None,
        None, None, raw_hash, "ruminating", 1, None,
    )]
    if ingestion != expected_ingestion:
        raise SystemExit(77)
    work = connection.execute(
        """
        SELECT id, campId, kind, aggregateType, aggregateId, idempotencyKey,
               state, attempt, maxAttempts, notBefore, leaseOwner,
               leaseExpiresAt, inputJson, inputHash, outputJson, errorCode,
               errorMessage, traceId, version, finishedAt
        FROM durable_work
        """
    ).fetchall()
    expected_work = [(
        work_id, camp_id, "rumination", "ingestion", ingestion_id,
        idempotency_key, "queued", 0, 4, None, None, None, input_json,
        input_hash, None, None, None, trace_id, 1, None,
    )]
    if work != expected_work:
        raise SystemExit(78)
    connection.commit()
    if connection.execute("PRAGMA foreign_key_check").fetchall() != []:
        raise SystemExit(79)
    if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
        raise SystemExit(80)
    print("camp_id=" + camp_id)
    print("fixture_counts=1:1")
finally:
    connection.close()
R26_FIXTURE_PY
  )"; then :; else r26_active_fail 70 "preview_fixture_transaction_failed"; fi
  [[ "${r26_output}" == camp_id=*$'\n'fixture_counts=1:1 ]] || r26_active_fail 70 "preview_fixture_output_shape"
  R26_PREVIEW_CAMP_ID="${r26_output%%$'\n'*}"
  R26_PREVIEW_CAMP_ID="${R26_PREVIEW_CAMP_ID#camp_id=}"
  [[ "${#R26_PREVIEW_CAMP_ID}" == "36" ]] || r26_active_fail 70 "preview_fixture_camp_id_length"
  case "${R26_PREVIEW_CAMP_ID}" in *[!0-9A-Fa-f-]*) r26_active_fail 70 "preview_fixture_camp_id_format" ;; esac
  [[ "${R26_PREVIEW_CAMP_ID:8:1}${R26_PREVIEW_CAMP_ID:13:1}${R26_PREVIEW_CAMP_ID:18:1}${R26_PREVIEW_CAMP_ID:23:1}" == "----" ]] || r26_active_fail 70 "preview_fixture_camp_id_hyphens"
  R26_CURRENT_ROOT_PHASE="preview_quiescent"
  r26_validate_current_roots_phase
  if r26_fixture_sha="$(r26_sha "${r26_database}")"; then :; else r26_active_fail 70 "preview_fixture_database_sha_failed"; fi
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "preview_fixture_timestamp_failed"; fi
  {
    /usr/bin/printf 'preview.fixture.installed_at=%s\n' "${r26_now_value}"
    /usr/bin/printf 'preview.fixture.camp_id=%s\n' "${R26_PREVIEW_CAMP_ID}"
    /usr/bin/printf '%s\n' 'preview.fixture.ingestion_id=a2-preview-ingestion-recovering'
    /usr/bin/printf '%s\n' 'preview.fixture.work_id=a2-preview-work-recovering'
    /usr/bin/printf '%s\n' 'preview.fixture.ingestion_status=ruminating'
    /usr/bin/printf '%s\n' 'preview.fixture.work_state=queued'
    /usr/bin/printf '%s\n' 'preview.fixture.foreign_key_check=PASS'
    /usr/bin/printf '%s\n' 'preview.fixture.integrity_check=PASS'
    /usr/bin/printf 'preview.fixture.database_sha_before_cold_start=%s\n' "${r26_fixture_sha}"
  } >> "${R26_COLD_START_LOG}"
}

r26_cu_capture_screenshot() {
  local r26_nonce=""
  local r26_challenge=""
  local r26_reply=""
  local r26_prefix=""
  local r26_rest=""
  local r26_encoding_field=""
  local r26_bytes_field=""
  local r26_sha_field=""
  local r26_extra_field=""
  local r26_actual_bytes=""
  local r26_actual_sha=""
  local r26_actual_encoding=""
  local r26_dimensions=""
  local r26_sips_dimensions=""
  local r26_mime=""
  local r26_stage_sha=""
  local r26_published_sha=""
  local r26_publish_rc=0
  local r26_sips_output=""
  local r26_now_value=""
  R26_PHASE="preview_cold_C06_screenshot_export"
  R26_CU_RAW_PATH="${R26_STATE_ROOT}/.${R26_INVOCATION_ID}.cu-raw"
  R26_SCREENSHOT_STAGE="${R26_TASK_DIRECTORY}/evidence/.${R26_INVOCATION_ID}.r26-preview-smoke.stage.png"
  r26_require_absent_path "${R26_CU_RAW_PATH}"
  r26_require_absent_path "${R26_SCREENSHOT_STAGE}"
  r26_require_absent_path "${R26_SCREENSHOT}"
  if r26_nonce="$(r26_new_nonce)"; then :; else r26_active_fail 70 "cu_nonce_failed_cold_C06"; fi
  r26_require_live_preview_process "cu_cold_C06_pre"
  r26_challenge="R26_CU_SCREENSHOT_CHALLENGE_V1|invocation_id=${R26_INVOCATION_ID}|phase=cold|step=C06|nonce=${r26_nonce}|pid=${R26_APP_PID}|app=${R26_APP}|exec=${R26_APP_EXECUTABLE}|exec_sha=${R26_SIGNED_EXECUTABLE_SHA}|bundle_sha=${R26_SIGNED_BUNDLE_MANIFEST_SHA}|bundle_id=${R26_BUNDLE_IDENTIFIER}|state_root=${R26_STATE_ROOT}|raw_path=${R26_CU_RAW_PATH}|allowed_scope=node_copy_current_C05_screenshot_once_with_fs_open_wx_to_exact_raw_path|other_fs_writes_forbidden=true|ui_action_forbidden=true|timeout_s=180"
  /usr/bin/printf 'control.challenge=%s\n' "${r26_challenge}" >> "${R26_COLD_START_LOG}"
  /usr/bin/printf '%s\n' "${r26_challenge}"
  if IFS= read -r -t 180 r26_reply; then :; else r26_active_fail 70 "cu_reply_timeout_or_eof_cold_C06"; fi
  [[ "${#r26_reply}" -le 4096 && "${r26_reply}" != *$'\r'* && "${r26_reply}" != *$'\n'* ]] || r26_active_fail 70 "cu_reply_shape_cold_C06"
  r26_prefix="R26_CU_SCREENSHOT_RESULT_V1|invocation_id=${R26_INVOCATION_ID}|phase=cold|step=C06|nonce=${r26_nonce}|status=PASS|raw_path=${R26_CU_RAW_PATH}|"
  [[ "${r26_reply}" == "${r26_prefix}"* ]] || r26_active_fail 70 "cu_reply_prefix_cold_C06"
  r26_rest="${r26_reply#"${r26_prefix}"}"
  IFS='|' read -r r26_encoding_field r26_bytes_field r26_sha_field r26_extra_field <<< "${r26_rest}"
  [[ -z "${r26_extra_field}" ]] || r26_active_fail 70 "cu_reply_extra_field_cold_C06"
  [[ "${r26_encoding_field}" == encoding=* && "${r26_bytes_field}" == bytes=* && "${r26_sha_field}" == sha=* ]] || r26_active_fail 70 "cu_reply_fields_cold_C06"
  R26_CU_RAW_ENCODING="${r26_encoding_field#encoding=}"
  R26_CU_RAW_BYTES="${r26_bytes_field#bytes=}"
  R26_CU_RAW_SHA="${r26_sha_field#sha=}"
  [[ "${R26_CU_RAW_ENCODING}" == "PNG" || "${R26_CU_RAW_ENCODING}" == "JPEG" ]] || r26_active_fail 70 "cu_raw_encoding_cold_C06"
  case "${R26_CU_RAW_BYTES}" in ''|*[!0-9]*) r26_active_fail 70 "cu_raw_bytes_cold_C06" ;; esac
  [[ "${R26_CU_RAW_BYTES}" -gt 0 ]] || r26_active_fail 70 "cu_raw_empty_cold_C06"
  r26_require_sha_literal "cu_raw_C06" "${R26_CU_RAW_SHA}"
  [[ -f "${R26_CU_RAW_PATH}" && ! -L "${R26_CU_RAW_PATH}" ]] || r26_active_fail 70 "cu_raw_path_type_cold_C06"
  if r26_actual_bytes="$(/usr/bin/stat -f '%z' "${R26_CU_RAW_PATH}")"; then :; else r26_active_fail 70 "cu_raw_stat_cold_C06"; fi
  if r26_actual_sha="$(r26_sha "${R26_CU_RAW_PATH}")"; then :; else r26_active_fail 70 "cu_raw_sha_cold_C06"; fi
  [[ "${r26_actual_bytes}" == "${R26_CU_RAW_BYTES}" && "${r26_actual_sha}" == "${R26_CU_RAW_SHA}" ]] || r26_active_fail 70 "cu_raw_metadata_mismatch_cold_C06"
  if r26_actual_encoding="$(/usr/bin/python3 - "${R26_CU_RAW_PATH}" <<'R26_IMAGE_KIND'
import sys
data = open(sys.argv[1], "rb").read(12)
if data.startswith(b"\x89PNG\r\n\x1a\n"):
    print("PNG")
elif data.startswith(b"\xff\xd8\xff"):
    print("JPEG")
else:
    raise SystemExit(71)
R26_IMAGE_KIND
  )"; then :; else r26_active_fail 70 "cu_raw_magic_cold_C06"; fi
  [[ "${r26_actual_encoding}" == "${R26_CU_RAW_ENCODING}" ]] || r26_active_fail 70 "cu_raw_encoding_mismatch_cold_C06"
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  if r26_exclusive_create_empty "${R26_SCREENSHOT_STAGE}"; then
    R26_SCREENSHOT_STAGE_OWNED="true"
  else
    r26_install_signal_traps
    r26_active_fail 70 "cu_stage_exclusive_create_failed_C06"
  fi
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then
    r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_screenshot_stage_create"
  fi
  if r26_sips_output="$(/usr/bin/sips -s format png "${R26_CU_RAW_PATH}" --out "${R26_SCREENSHOT_STAGE}" 2>&1)"; then :; else r26_active_fail 70 "cu_full_decode_normalization_failed_C06"; fi
  [[ -n "${r26_sips_output}" ]] || r26_active_fail 70 "cu_full_decode_normalization_output_empty_C06"
  [[ -f "${R26_SCREENSHOT_STAGE}" && ! -L "${R26_SCREENSHOT_STAGE}" ]] || r26_active_fail 70 "cu_stage_type_C06"
  if r26_dimensions="$(/usr/bin/python3 - "${R26_SCREENSHOT_STAGE}" <<'R26_PNG_DIMENSIONS'
import struct
import sys
with open(sys.argv[1], "rb") as handle:
    header = handle.read(24)
if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
    raise SystemExit(71)
width, height = struct.unpack(">II", header[16:24])
if width < 1 or height < 1:
    raise SystemExit(72)
print(f"{width}:{height}")
R26_PNG_DIMENSIONS
  )"; then :; else r26_active_fail 70 "cu_png_dimensions_failed_C06"; fi
  R26_SCREENSHOT_WIDTH="${r26_dimensions%%:*}"
  R26_SCREENSHOT_HEIGHT="${r26_dimensions##*:}"
  if r26_sips_dimensions="$(/usr/bin/sips -g pixelWidth -g pixelHeight "${R26_SCREENSHOT_STAGE}" 2>/dev/null)"; then :; else r26_active_fail 70 "cu_sips_decode_metadata_failed_C06"; fi
  if r26_sips_dimensions="$(/usr/bin/awk '
      $1 == "pixelWidth:" { width = $2; width_count += 1 }
      $1 == "pixelHeight:" { height = $2; height_count += 1 }
      END {
        if (width_count != 1 || height_count != 1 || width !~ /^[0-9]+$/ || height !~ /^[0-9]+$/) exit 71
        print width ":" height
      }
    ' <<< "${r26_sips_dimensions}")"; then :; else r26_active_fail 70 "cu_sips_decode_metadata_parse_failed_C06"; fi
  [[ "${r26_sips_dimensions}" == "${r26_dimensions}" ]] || r26_active_fail 70 "cu_sips_vs_png_dimension_mismatch_C06"
  if r26_stage_sha="$(r26_sha "${R26_SCREENSHOT_STAGE}")"; then :; else r26_active_fail 70 "cu_stage_sha_failed_C06"; fi
  r26_require_absent_path "${R26_SCREENSHOT}"
  if /bin/mv -n "${R26_SCREENSHOT_STAGE}" "${R26_SCREENSHOT}"; then
    r26_publish_rc=0
  else
    r26_publish_rc="$?"
    r26_active_fail 70 "cu_screenshot_same_directory_publish_failed_C06_${r26_publish_rc}"
  fi
  if [[ ! -e "${R26_SCREENSHOT_STAGE}" && ! -L "${R26_SCREENSHOT_STAGE}" && -f "${R26_SCREENSHOT}" && ! -L "${R26_SCREENSHOT}" ]]; then
    R26_SCREENSHOT_STAGE_OWNED="false"
  else
    r26_active_fail 70 "cu_screenshot_publish_postcondition_failed_C06"
  fi
  if r26_published_sha="$(r26_sha "${R26_SCREENSHOT}")"; then :; else r26_active_fail 70 "cu_screenshot_published_sha_failed_C06"; fi
  [[ "${r26_published_sha}" == "${r26_stage_sha}" ]] || r26_active_fail 70 "cu_screenshot_published_sha_mismatch_C06"
  /bin/rm -f "${R26_CU_RAW_PATH}" || r26_active_fail 70 "cu_raw_cleanup_failed_C06"
  r26_require_absent_path "${R26_CU_RAW_PATH}"
  r26_require_absent_path "${R26_SCREENSHOT_STAGE}"
  [[ -f "${R26_SCREENSHOT}" && ! -L "${R26_SCREENSHOT}" ]] || r26_active_fail 70 "cu_screenshot_type_C06"
  if r26_mime="$(/usr/bin/file -b --mime-type "${R26_SCREENSHOT}")"; then :; else r26_active_fail 70 "cu_screenshot_mime_failed_C06"; fi
  [[ "${r26_mime}" == "image/png" ]] || r26_active_fail 70 "cu_screenshot_mime_C06_${r26_mime}"
  R26_SCREENSHOT_SHA="${r26_published_sha}"
  if R26_SCREENSHOT_BYTES="$(/usr/bin/stat -f '%z' "${R26_SCREENSHOT}")"; then :; else r26_active_fail 70 "cu_screenshot_bytes_failed_C06"; fi
  [[ "${R26_SCREENSHOT_BYTES}" -gt 0 ]] || r26_active_fail 70 "cu_screenshot_empty_C06"
  r26_preview_state_ready_probe || r26_active_fail 70 "cu_state_not_exact_four_after_capture_C06"
  r26_require_live_preview_process "cu_cold_C06_post"
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "cu_screenshot_timestamp_failed_C06"; fi
  /usr/bin/printf 'control.result=%s\n' "${r26_reply}" >> "${R26_COLD_START_LOG}"
  {
    /usr/bin/printf 'preview.screenshot.published_at=%s\n' "${r26_now_value}"
    /usr/bin/printf 'preview.screenshot.path=%s\n' "${R26_SCREENSHOT}"
    /usr/bin/printf 'preview.screenshot.sha=%s\n' "${R26_SCREENSHOT_SHA}"
    /usr/bin/printf 'preview.screenshot.bytes=%s\n' "${R26_SCREENSHOT_BYTES}"
    /usr/bin/printf 'preview.screenshot.width=%s\n' "${R26_SCREENSHOT_WIDTH}"
    /usr/bin/printf 'preview.screenshot.height=%s\n' "${R26_SCREENSHOT_HEIGHT}"
    /usr/bin/printf '%s\n' 'preview.screenshot.encoding=PNG'
    /usr/bin/printf '%s\n' 'preview.screenshot.full_sips_decode_and_dimension_recheck=PASS'
    /usr/bin/printf '%s\n' 'preview.screenshot.same_directory_publish=PASS'
    /usr/bin/printf '%s\n' 'preview.screenshot.raw_and_stage_cleanup=PASS'
  } >> "${R26_COLD_START_LOG}"
}

r26_run_same_bundle_preview() {
  R26_PHASE="same_bundle_preview_bootstrap"
  r26_require_manifest
  r26_require_r23_predecessor
  r26_require_r24_predecessor
  r26_require_r25_predecessor
  r26_require_implementation_baseline
  r26_require_zero_write_predecessors "pre_preview"
  r26_observe_lifecycles "pre_preview" "true"
  r26_start_direct_bootstrap
  r26_cu_exchange_exact bootstrap B01 observe_full_onboarding_state "window_count=1|enter_my_camp_count=1|onboarding_visible=true" false
  r26_cu_exchange_exact bootstrap B02 click_exact_enter_my_camp_from_current_state "clicked_enter_my_camp_count=1" false
  r26_cu_exchange_exact bootstrap B03 observe_full_dashboard_state "window_count=1|feed_hero_exact_count=1|enter_my_camp_count=0|view_all_count=0|dashboard_visible=true" false
  r26_cu_exchange_exact bootstrap B04 click_exact_AgentLoop_application_menu_from_current_state "agentloop_menu_clicked_count=1" false
  r26_cu_exchange_exact bootstrap B05 observe_full_application_menu_state "quit_agentloop_count=1|menu_visible=true" false
  r26_cu_exchange_exact bootstrap B06 click_exact_Quit_AgentLoop_from_current_state "quit_agentloop_clicked_count=1" true
  r26_wait_owned_preview_exit bootstrap

  r26_install_preview_fixture

  R26_PHASE="same_bundle_preview_cold"
  r26_start_direct_cold_preview
  r26_cu_exchange_exact cold C01 observe_full_dashboard_state "window_count=1|feed_hero_exact_count=1|enter_my_camp_count=0|view_all_1_exact_count=1|dashboard_visible=true" false
  r26_cu_exchange_exact cold C02 click_exact_view_all_1_from_current_state "clicked_view_all_1_count=1" false
  r26_cu_exchange_exact cold C03 observe_full_rumination_inbox_state "fixture_title_count=1|view_progress_count=1|inbox_visible=true" false
  r26_cu_exchange_exact cold C04 click_exact_fixture_view_progress_from_current_state "clicked_fixture_view_progress_count=1" false
  r26_cu_exchange_exact cold C05 observe_full_recovering_detail_and_capture_current_screenshot "window_count=1|fixture_title_count=1|source_saved_complete_count=2|recovering_in_progress_count=3|extracting_count=0|organizing_count=0|confirm_count=0|screenshot_nonnull_file_url=true" false
  r26_cu_capture_screenshot
  r26_cu_exchange_exact cold C07 click_exact_AgentLoop_application_menu_from_current_C05_state "agentloop_menu_clicked_count=1" false
  r26_cu_exchange_exact cold C08 observe_full_application_menu_state "quit_agentloop_count=1|menu_visible=true" false
  r26_cu_exchange_exact cold C09 click_exact_Quit_AgentLoop_from_current_state "quit_agentloop_clicked_count=1" true
  r26_wait_owned_preview_exit cold
  r26_append_boundary 'same_bundle_preview=PASS'
  r26_append_boundary 'preview_normal_root_open_observed_count=0'
  r26_append_boundary 'preview_all_observed_processes_exact_isolated_child=true'
  r26_append_boundary 'preview_process_replacement_observed=false'
  r26_append_boundary 'preview_screenshot_true_png=PASS'
}

r26_prepare_impl_report_stage() {
  local r26_now_value=""
  [[ -n "${R26_IMPL_REPORT_STAGE}" ]] || r26_active_fail 70 "impl_report_stage_path_missing"
  [[ "${R26_IMPL_REPORT_STAGE}" == "${R26_TASK_DIRECTORY}/.${R26_INVOCATION_ID}.impl-report-r26.stage.md" ]] || r26_active_fail 70 "impl_report_stage_path_mismatch"
  [[ "${R26_IMPL_REPORT_STAGE_OWNED}" == "false" && "${R26_IMPL_REPORT_PUBLISHED}" == "false" ]] || r26_active_fail 70 "impl_report_stage_state_not_fresh"
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  if r26_exclusive_create_empty "${R26_IMPL_REPORT_STAGE}"; then
    R26_IMPL_REPORT_STAGE_OWNED="true"
  else
    r26_install_signal_traps
    r26_active_fail 71 "exclusive_create_failed_${R26_IMPL_REPORT_STAGE}"
  fi
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then
    r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_impl_report_stage_create"
  fi
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "impl_report_timestamp_failed"; fi
  {
    /usr/bin/printf '%s\n' '# R26 implementation report'
    /usr/bin/printf '\n- Status: `PASS`\n'
    /usr/bin/printf -- '- Completed at: `%s`\n' "${r26_now_value}"
    /usr/bin/printf -- '- Product/test/App/permanent-script delta in R26: `0`\n'
    /usr/bin/printf -- '- Authoritative full run: `652/652`, Swift rc `%s`, tee rc `%s`, same-log audit `46/46`\n' "${R26_AUTHORITATIVE_SWIFT_RC}" "${R26_AUTHORITATIVE_TEE_RC}"
    /usr/bin/printf -- '- Core/Test hashes: `%s` / `%s`\n' "${R26_EXPECTED_CORE_SHA}" "${R26_EXPECTED_TEST_SHA}"
    /usr/bin/printf -- '- Matrix entry restored: `%s`; manifest: `206/206`\n' "${R26_EXPECTED_MATRIX_ENTRY_SHA}"
    /usr/bin/printf -- '- Preview app: `%s`\n' "${R26_APP}"
    /usr/bin/printf -- '- Preview state root: `%s`\n' "${R26_STATE_ROOT}"
    /usr/bin/printf -- '- Screenshot: `%s` (`%s`, %sx%s, %s bytes)\n' "${R26_SCREENSHOT}" "${R26_SCREENSHOT_SHA}" "${R26_SCREENSHOT_WIDTH}" "${R26_SCREENSHOT_HEIGHT}" "${R26_SCREENSHOT_BYTES}"
    /usr/bin/printf -- '- Preview isolation claim: every observed owned process used the exact signed executable and isolated state root; observed normal-root open count was zero. This does not claim an atomic proof about unobserved intervals.\n'
    /usr/bin/printf -- '- The invocation-unique bundle domain may contain the isolated onboarding UserDefaults write; R26 does not claim zero preference writes.\n'
    /usr/bin/printf -- '- R23, R24, and R25 remain immutable `REJECTED_CONTAMINATED`; no predecessor full-test output substituted for the R26 run.\n'
    /usr/bin/printf -- '- No commit, push, merge, release, normal-data mutation, external communication, or real-user action was performed.\n'
  } >> "${R26_IMPL_REPORT_STAGE}"
  [[ -s "${R26_IMPL_REPORT_STAGE}" && ! -L "${R26_IMPL_REPORT_STAGE}" ]] || r26_active_fail 70 "impl_report_stage_shape_failed"
  if R26_IMPL_REPORT_STAGE_SHA="$(r26_sha "${R26_IMPL_REPORT_STAGE}")"; then :; else r26_active_fail 70 "impl_report_stage_sha_failed"; fi
  if /usr/bin/python3 - "${R26_IMPL_REPORT_STAGE}" <<'R26_REPORT_PRIVACY'
import re
import sys
from pathlib import Path
pattern = re.compile(rb"sk-[A-Za-z0-9_-]{20,}|Bearer\s+[A-Za-z0-9._-]{20,}|(?:access|refresh|id)_token[\"=:\s]+[A-Za-z0-9._-]{20,}", re.I)
raise SystemExit(71 if pattern.search(Path(sys.argv[1]).read_bytes()) else 0)
R26_REPORT_PRIVACY
  then :; else r26_active_fail 70 "impl_report_stage_privacy_scan_failed"; fi
  r26_require_sha "${R26_IMPL_REPORT_STAGE_SHA}" "${R26_IMPL_REPORT_STAGE}"
}

r26_commit_terminal_success() {
  local r26_end_timestamp="$1"
  local r26_end_block=""
  local r26_published_sha=""
  local r26_publish_rc=0
  local r26_append_rc=0
  [[ "${R26_END_COMMITTED}" == "false" ]] || r26_active_fail 70 "terminal_commit_already_complete"
  [[ "${R26_IMPL_REPORT_STAGE_OWNED}" == "true" && "${R26_IMPL_REPORT_PUBLISHED}" == "false" ]] || r26_active_fail 70 "terminal_commit_report_state_invalid"
  r26_require_sha "${R26_IMPL_REPORT_STAGE_SHA}" "${R26_IMPL_REPORT_STAGE}"
  if printf -v r26_end_block \
    'authorization_consumed=true\nretry_same_boundary=false\nmanifest_final=206_of_206\nproduct_test_app_permanent_script_delta=0\nimpl_report_sha=%s\nscreenshot_sha=%s\nr23_first_mask=%s\nr23_latest_mask=%s\nr24_first_mask=%s\nr24_latest_mask=%s\nr25_first_mask=%s\nr25_latest_mask=%s\nr20_first_mask=%s\nr20_latest_mask=%s\nutc_end=%s\nstatus=END\nresult=PASS\n' \
    "${R26_IMPL_REPORT_STAGE_SHA}" "${R26_SCREENSHOT_SHA}" \
    "${R26_R23_FIRST_MASK}" "${R26_R23_LATEST_MASK}" \
    "${R26_R24_FIRST_MASK}" "${R26_R24_LATEST_MASK}" \
    "${R26_R25_FIRST_MASK}" "${R26_R25_LATEST_MASK}" \
    "${R26_R20_FIRST_MASK}" "${R26_R20_LATEST_MASK}" "${r26_end_timestamp}"; then
    :
  else
    r26_active_fail 70 "terminal_end_block_render_failed"
  fi
  [[ "${r26_end_block}" == *$'\nstatus=END\nresult=PASS\n' ]] || r26_active_fail 70 "terminal_end_block_shape_invalid"
  R26_PHASE="end_commit"
  r26_require_absent_path "${R26_IMPL_REPORT}"
  r26_require_sha "${R26_IMPL_REPORT_STAGE_SHA}" "${R26_IMPL_REPORT_STAGE}"
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  if /bin/mv -n "${R26_IMPL_REPORT_STAGE}" "${R26_IMPL_REPORT}"; then
    r26_publish_rc=0
  else
    r26_publish_rc="$?"
    r26_install_signal_traps
    r26_active_fail 70 "terminal_report_publish_failed_${r26_publish_rc}"
  fi
  if [[ ! -e "${R26_IMPL_REPORT_STAGE}" && ! -L "${R26_IMPL_REPORT_STAGE}" && -f "${R26_IMPL_REPORT}" && ! -L "${R26_IMPL_REPORT}" ]]; then
    R26_IMPL_REPORT_STAGE_OWNED="false"
    R26_IMPL_REPORT_PUBLISHED="true"
  else
    r26_install_signal_traps
    r26_active_fail 70 "terminal_report_publish_postcondition_failed"
  fi
  if r26_published_sha="$(r26_sha "${R26_IMPL_REPORT}")"; then :; else
    r26_install_signal_traps
    r26_active_fail 70 "terminal_report_published_sha_read_failed"
  fi
  if [[ "${r26_published_sha}" != "${R26_IMPL_REPORT_STAGE_SHA}" ]]; then
    r26_install_signal_traps
    r26_active_fail 70 "terminal_report_published_sha_mismatch"
  fi
  r26_install_signal_traps
  if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then
    r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_report_publish"
  fi
  r26_require_sha "${R26_IMPL_REPORT_STAGE_SHA}" "${R26_IMPL_REPORT}"

  # This is the sole commit-wins signal window: the report is already
  # published and verified, and the next external mutation is one END append.
  R26_DEFERRED_SIGNAL=""
  R26_DEFERRED_SIGNAL_STATUS=""
  trap 'r26_defer_signal HUP 129' HUP
  trap 'r26_defer_signal INT 130' INT
  trap 'r26_defer_signal TERM 143' TERM
  if /usr/bin/printf '%s' "${r26_end_block}" >> "${R26_BOUNDARY_LOG}"; then
    r26_append_rc=0
  else
    r26_append_rc="$?"
    r26_install_signal_traps
    r26_active_fail 70 "terminal_boundary_append_failed_${r26_append_rc}"
  fi
  R26_END_COMMITTED="true" R26_BOUNDARY_ACTIVE="false"
  trap '' HUP INT TERM
  trap - ERR
  return 0
}

r26_run_post_preview_final_gates() {
  local r26_diff_output=""
  local r26_git_status=""
  local r26_runtime_hashes=""
  local r26_path=""
  local r26_now_value=""
  R26_PHASE="post_preview_final_gates"
  r26_require_no_process
  [[ "${R26_CURRENT_ROOT_PHASE}" == "preview_quiescent" ]] || r26_active_fail 70 "final_wrong_root_phase_${R26_CURRENT_ROOT_PHASE}"
  r26_validate_current_roots_phase
  [[ -f "${R26_SCREENSHOT}" && ! -L "${R26_SCREENSHOT}" ]] || r26_active_fail 70 "final_screenshot_type"
  r26_require_sha "${R26_SCREENSHOT_SHA}" "${R26_SCREENSHOT}"
  r26_require_absent_path "${R26_CU_RAW_PATH}"
  r26_require_absent_path "${R26_SCREENSHOT_STAGE}"
  if /usr/bin/python3 - "${R26_VERIFY_LOG}" "${R26_TARGETED_LOG}" "${R26_BUILD_LOG}" "${R26_MATRIX_LOG}" "${R26_BUNDLE_LOG}" "${R26_SOURCE_LOG}" "${R26_BOOTSTRAP_LOG}" "${R26_COLD_START_LOG}" "${R26_BOUNDARY_LOG}" "${R26_HASH_LOG}" <<'R26_FINAL_PRIVACY'
import re
import sys
from pathlib import Path
pattern = re.compile(rb"sk-[A-Za-z0-9_-]{20,}|Bearer\s+[A-Za-z0-9._-]{20,}|(?:access|refresh|id)_token[\"=:\s]+[A-Za-z0-9._-]{20,}", re.I)
for item in sys.argv[1:]:
    if pattern.search(Path(item).read_bytes()):
        raise SystemExit(71)
R26_FINAL_PRIVACY
  then :; else r26_active_fail 70 "final_runtime_privacy_scan_failed"; fi
  r26_require_verify_log_identity "final"
  r26_require_manifest
  r26_require_r23_predecessor
  r26_require_r24_predecessor
  r26_require_r25_predecessor
  r26_require_implementation_baseline
  r26_require_branch_and_head
  r26_require_sha "${R26_EXPECTED_MATRIX_ENTRY_SHA}" "${R26_MATRIX_SCRIPT}"
  [[ "${R26_MATRIX_MUTATED}" == "false" ]] || r26_active_fail 70 "final_matrix_mutated"
  r26_require_absent_path "${R26_MATRIX_BACKUP_PATH}"
  r26_require_absent_path "${R26_MATRIX_MUTATED_STAGE}"
  r26_require_absent_path "${R26_MATRIX_RESTORE_STAGE}"
  r26_require_launch_ready_identity "final"
  r26_require_zero_write_predecessors "final_pre_end"
  r26_observe_lifecycles "final_pre_end" "true"
  if r26_diff_output="$(/usr/bin/git --no-optional-locks -C "${R26_REPOSITORY_ROOT}" diff --check)"; then :; else r26_active_fail 70 "final_git_diff_check_failed"; fi
  [[ -z "${r26_diff_output}" ]] || r26_active_fail 70 "final_git_diff_check_output"
  if r26_git_status="$(/usr/bin/git --no-optional-locks -C "${R26_REPOSITORY_ROOT}" status --short --branch)"; then :; else r26_active_fail 70 "final_git_status_failed"; fi
  if r26_runtime_hashes="$({
      for r26_path in \
        "${R26_VERIFY_LOG}" "${R26_TARGETED_LOG}" "${R26_BUILD_LOG}" \
        "${R26_MATRIX_LOG}" "${R26_BUNDLE_LOG}" "${R26_SOURCE_LOG}" \
        "${R26_BOOTSTRAP_LOG}" "${R26_COLD_START_LOG}" "${R26_SCREENSHOT}"; do
        /usr/bin/shasum -a 256 "${r26_path}" || exit "$?"
      done
    })"; then :; else r26_active_fail 70 "final_runtime_hash_capture_failed"; fi
  {
    /usr/bin/printf '%s\n' 'section=post_preview_final'
    /usr/bin/printf '%s\n' 'manifest=206_of_206_PASS'
    /usr/bin/printf '%s\n' 'matrix_restored=true'
    /usr/bin/printf '%s\n' 'privacy_scan=PASS'
    /usr/bin/printf '%s\n' 'normal_root_open_observed_count=0'
    /usr/bin/printf '%s\n' 'all_observed_preview_processes_exact_isolated_child=true'
    /usr/bin/printf '%s\n' 'process_replacement_observed=false'
    /usr/bin/printf '%s\n' 'runtime_hashes_begin'
    /usr/bin/printf '%s\n' "${r26_runtime_hashes}"
    /usr/bin/printf '%s\n' 'runtime_hashes_end'
    /usr/bin/printf 'git_status_begin\n%s\ngit_status_end\n' "${r26_git_status}"
  } >> "${R26_HASH_LOG}"
  r26_prepare_impl_report_stage
  if r26_now_value="$(r26_capture_now)"; then :; else r26_active_fail 70 "end_timestamp_failed"; fi
  r26_commit_terminal_success "${r26_now_value}"
}

if [[ "$#" != "1" ]]; then
  r26_pre_begin_fail 64 "expected_one_review26_sha_argument"
fi
R26_REVIEW26_SHA_ARGUMENT="$1"
[[ "${#R26_REVIEW26_SHA_ARGUMENT}" == "64" ]] || r26_pre_begin_fail 64 "review26_sha_length"
case "${R26_REVIEW26_SHA_ARGUMENT}" in
  *[!0-9a-f]*) r26_pre_begin_fail 64 "review26_sha_format" ;;
esac

R26_PHASE="preflight_static"
r26_require_canonical_entry_paths
r26_require_sha_constant_shapes
r26_require_invocation_environment
r26_require_branch_and_head
r26_require_regular_file "${R26_DRIVER_PATH}"
r26_require_regular_file "${R26_FREEZE_PATH}"
r26_require_review26 "${R26_REVIEW26_SHA_ARGUMENT}"
r26_require_manifest
r26_require_r23_predecessor
r26_require_r24_predecessor
r26_require_r25_predecessor
r26_require_implementation_baseline
r26_require_guard_shape_static
r26_require_err_subshell_guard_static
r26_run_bash32_err_subshell_microprobes
r26_require_no_process
r26_require_fresh_runtime_absence
r26_require_zero_write_predecessors "preflight"

R26_PHASE="preflight_lifecycles"
r26_observe_lifecycles "preflight" "false"

R26_PHASE="final_pre_begin"
r26_require_canonical_entry_paths
r26_require_sha_constant_shapes
r26_require_invocation_environment
r26_require_branch_and_head
r26_require_review26 "${R26_REVIEW26_SHA_ARGUMENT}"
r26_require_manifest
r26_require_r23_predecessor
r26_require_r24_predecessor
r26_require_r25_predecessor
r26_require_implementation_baseline
r26_require_guard_shape_static
r26_require_err_subshell_guard_static
r26_run_bash32_err_subshell_microprobes
r26_require_no_process
r26_require_fresh_runtime_absence
r26_require_zero_write_predecessors "final_pre_begin"
r26_observe_lifecycles "final_pre_begin" "false"

R26_PHASE="exclusive_boundary_create"
R26_DEFERRED_SIGNAL=""
R26_DEFERRED_SIGNAL_STATUS=""
trap 'r26_defer_signal HUP 129' HUP
trap 'r26_defer_signal INT 130' INT
trap 'r26_defer_signal TERM 143' TERM
if r26_exclusive_create_empty "${R26_BOUNDARY_LOG}"; then
  R26_BOUNDARY_ACTIVE="true"
else
  r26_install_signal_traps
  r26_pre_begin_fail 73 "boundary_EEXIST_no_append"
fi
r26_install_signal_traps
if [[ -n "${R26_DEFERRED_SIGNAL}" ]]; then
  r26_active_fail "${R26_DEFERRED_SIGNAL_STATUS}" "deferred_signal_${R26_DEFERRED_SIGNAL}_boundary_activation"
fi

r26_invocation_nonce=""
r26_begin_at=""
r26_begin_attested_at=""
r26_freeze_sha=""
r26_driver_sha=""
r26_manifest_sha=""
r26_git_status=""
r26_verify_size=""
if r26_invocation_nonce="$(r26_new_nonce)"; then :; else r26_active_fail 70 "invocation_nonce_failed"; fi
R26_INVOCATION_ID="r26-${r26_invocation_nonce}"
R26_BUNDLE_IDENTIFIER="com.muzi.agentloop.r26.preview.${r26_invocation_nonce}"
R26_IMPL_REPORT_STAGE="${R26_TASK_DIRECTORY}/.${R26_INVOCATION_ID}.impl-report-r26.stage.md"
[[ "${R26_INVOCATION_ID}" != *[!a-z0-9-]* ]] || r26_active_fail 70 "invocation_id_shape"
[[ "${R26_BUNDLE_IDENTIFIER}" != *[!a-z0-9.]* ]] || r26_active_fail 70 "bundle_identifier_shape"
r26_require_absent_path "${R26_IMPL_REPORT_STAGE}"
r26_require_absent_path "${R26_IMPL_REPORT}"
if r26_begin_at="$(r26_capture_now)"; then :; else r26_active_fail 70 "begin_timestamp_failed"; fi
if r26_freeze_sha="$(r26_sha "${R26_FREEZE_PATH}")"; then :; else r26_active_fail 70 "begin_freeze_sha_failed"; fi
if r26_driver_sha="$(r26_sha "${R26_DRIVER_PATH}")"; then :; else r26_active_fail 70 "begin_driver_sha_failed"; fi
if r26_manifest_sha="$(r26_sha "${R26_MANIFEST_PATH}")"; then :; else r26_active_fail 70 "begin_manifest_sha_failed"; fi
{
  /usr/bin/printf '%s\n' 'boundary_identity=R26_SINGLE_BASH_FULL_CHAIN_AND_ISOLATED_PREVIEW'
  /usr/bin/printf 'invocation_id=%s\n' "${R26_INVOCATION_ID}"
  /usr/bin/printf 'bundle_identifier=%s\n' "${R26_BUNDLE_IDENTIFIER}"
  /usr/bin/printf '%s\n' 'authorization_consumed=true'
  /usr/bin/printf '%s\n' 'status=BEGIN_STARTED'
  /usr/bin/printf 'utc_begin_started=%s\n' "${r26_begin_at}"
  /usr/bin/printf 'freeze_sha=%s\n' "${r26_freeze_sha}"
  /usr/bin/printf 'review26_sha=%s\n' "${R26_REVIEW26_SHA_ARGUMENT}"
  /usr/bin/printf 'driver_sha=%s\n' "${r26_driver_sha}"
  /usr/bin/printf 'manifest_sha=%s\n' "${r26_manifest_sha}"
  /usr/bin/printf 'implementation_core_sha=%s\n' "${R26_EXPECTED_CORE_SHA}"
  /usr/bin/printf 'implementation_test_sha=%s\n' "${R26_EXPECTED_TEST_SHA}"
  /usr/bin/printf '%s\n' 'implementation_entry_source_delta=0'
  /usr/bin/printf '%s\n' 'product_test_app_permanent_script_delta=0'
} >> "${R26_BOUNDARY_LOG}"

R26_PHASE="immediate_post_activation"
r26_require_zero_write_predecessors "immediate_post_activation"
r26_observe_lifecycles "immediate_post_activation" "false"
r26_require_r23_predecessor
r26_require_r24_predecessor
r26_require_r25_predecessor
r26_require_implementation_baseline
r26_create_runtime_evidence

R26_PHASE="fresh_roots"
if R26_STATE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r26-state.XXXXXX')"; then :; else r26_active_fail 71 "state_mktemp_failed"; fi
if R26_BUNDLE_ROOT="$(/usr/bin/mktemp -d '/private/tmp/agentloop-r26-bundle.XXXXXX')"; then :; else r26_active_fail 71 "bundle_mktemp_failed"; fi
[[ "${R26_STATE_ROOT}" != "${R26_BUNDLE_ROOT}" ]] || r26_active_fail 71 "fresh_roots_equal"
R26_CURRENT_ROOT_PHASE="empty"
r26_validate_current_roots_phase
r26_require_zero_write_predecessors "post_root"
r26_observe_lifecycles "post_root" "true"
if r26_begin_attested_at="$(r26_capture_now)"; then :; else r26_active_fail 70 "begin_attested_timestamp_failed"; fi
{
  /usr/bin/printf 'state_root=%s\n' "${R26_STATE_ROOT}"
  /usr/bin/printf 'bundle_root=%s\n' "${R26_BUNDLE_ROOT}"
  /usr/bin/printf 'r23_lifecycle_baseline=%s\n' "${R26_R23_BASELINE_MASK}"
  /usr/bin/printf 'r23_lifecycle_first=%s\n' "${R26_R23_FIRST_MASK}"
  /usr/bin/printf 'r23_lifecycle_latest=%s\n' "${R26_R23_LATEST_MASK}"
  /usr/bin/printf 'r24_lifecycle_baseline=%s\n' "${R26_R24_BASELINE_MASK}"
  /usr/bin/printf 'r24_lifecycle_first=%s\n' "${R26_R24_FIRST_MASK}"
  /usr/bin/printf 'r24_lifecycle_latest=%s\n' "${R26_R24_LATEST_MASK}"
  /usr/bin/printf 'r25_lifecycle_baseline=%s\n' "${R26_R25_BASELINE_MASK}"
  /usr/bin/printf 'r25_lifecycle_first=%s\n' "${R26_R25_FIRST_MASK}"
  /usr/bin/printf 'r25_lifecycle_latest=%s\n' "${R26_R25_LATEST_MASK}"
  /usr/bin/printf '%s\n' 'r25_lifecycle_capture_mode=coarse_root_entries_only_no_descendant_access'
  /usr/bin/printf '%s\n' 'r25_state_class=POST_REJECTION_READ_PROBE_CONTAMINATED'
  /usr/bin/printf 'r20_lifecycle_baseline=%s\n' "${R26_R20_BASELINE_MASK}"
  /usr/bin/printf 'r20_lifecycle_first=%s\n' "${R26_R20_FIRST_MASK}"
  /usr/bin/printf 'r20_lifecycle_latest=%s\n' "${R26_R20_LATEST_MASK}"
  /usr/bin/printf 'utc_begin_attested=%s\n' "${r26_begin_attested_at}"
  /usr/bin/printf '%s\n' 'begin_attestation_complete=true'
  /usr/bin/printf '%s\n' 'status=BEGIN_ATTESTED'
  /usr/bin/printf '%s\n' 'retry_same_boundary=false'
} >> "${R26_BOUNDARY_LOG}"
if r26_git_status="$(/usr/bin/git --no-optional-locks -C "${R26_REPOSITORY_ROOT}" status --short --branch)"; then :; else r26_active_fail 70 "entry_git_status_failed"; fi
{
  /usr/bin/printf '%s\n' 'section=static_manifest'
  /usr/bin/printf 'manifest_count=%s\n' "${R26_EXPECTED_MANIFEST_COUNT}"
  /usr/bin/printf 'manifest_sha=%s\n' "${r26_manifest_sha}"
  /usr/bin/printf '%s\n' 'r23_manifest_partition=156_PASS_7_EXPECTED_MISMATCHES'
  /usr/bin/printf '%s\n' 'r24_manifest_partition=172_PASS_6_EXPECTED_MISMATCHES'
  /usr/bin/printf '%s\n' 'r25_manifest_partition=186_PASS_6_EXPECTED_MISMATCHES'
  /usr/bin/printf '%s\n' 'r25_runtime_artifact_count=10'
  /usr/bin/printf '%s\n' 'r25_impl_report_absent=true'
  /usr/bin/printf '%s\n' 'r25_screenshot_absent=true'
  /usr/bin/printf 'git_status_begin\n%s\ngit_status_end\n' "${r26_git_status}"
} >> "${R26_HASH_LOG}"

R26_PHASE="post_manifest_pre_full_test_reproof"
r26_require_branch_and_head
r26_require_manifest
r26_require_r23_predecessor
r26_require_r24_predecessor
r26_require_r25_predecessor
r26_require_implementation_baseline
r26_require_no_process
r26_require_zero_write_predecessors "post_manifest_pre_full_test"
r26_observe_lifecycles "post_manifest_pre_full_test" "true"

r26_run_authoritative_full_test

R26_PHASE="post_full_test_adjacent_reproof"
r26_require_verify_log_identity "post_full_test_adjacent"
if r26_verify_size="$(/usr/bin/stat -f '%z' "${R26_VERIFY_LOG}")"; then :; else r26_active_fail 70 "authoritative_verify_log_size_read_failed"; fi
[[ "${r26_verify_size}" == "${R26_VERIFY_LOG_BYTES}" ]] || r26_active_fail 70 "authoritative_verify_log_size_drift"
r26_require_manifest
r26_require_r23_predecessor
r26_require_r24_predecessor
r26_require_r25_predecessor
r26_require_implementation_baseline
r26_require_no_process
r26_require_zero_write_predecessors "post_full_test"
r26_observe_lifecycles "post_full_test" "true"

r26_run_same_log_targeted_audit

R26_PHASE="pre_debug_build_bundle_reproof"
r26_require_manifest
r26_require_implementation_baseline
r26_require_verify_log_identity "pre_debug_build"
r26_observe_lifecycles "pre_debug_build" "true"
r26_run_debug_build_and_bundle

R26_PHASE="post_bundle_pre_release_reproof"
r26_require_manifest
r26_require_implementation_baseline
r26_require_verify_log_identity "post_bundle"
r26_require_launch_ready_identity "post_bundle"
r26_observe_lifecycles "post_bundle" "true"
r26_run_guard_shape_and_strip
r26_run_release_and_object_gates

R26_PHASE="pre_matrix_reproof"
r26_require_manifest
r26_require_implementation_baseline
r26_require_verify_log_identity "pre_matrix"
r26_require_launch_ready_identity "pre_matrix"
r26_observe_lifecycles "pre_matrix" "true"
r26_run_matrix_with_mandatory_restore

R26_PHASE="post_matrix_reproof"
r26_require_manifest
r26_require_sha "${R26_EXPECTED_MATRIX_ENTRY_SHA}" "${R26_MATRIX_SCRIPT}"
[[ "${R26_MATRIX_MUTATED}" == "false" ]] || r26_active_fail 70 "post_matrix_mutation_flag"
r26_require_verify_log_identity "post_matrix"
r26_observe_lifecycles "post_matrix" "true"
r26_run_remaining_source_privacy_final_hashes

r26_run_same_bundle_preview
r26_run_post_preview_final_gates

[[ "${R26_END_COMMITTED}" == "true" && "${R26_BOUNDARY_ACTIVE}" == "false" ]] || exit 70
exit 0
