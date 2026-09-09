#!/bin/zsh
# Parent-owned argument-only checks. Swift is replaced by an exit-99 recorder.
# No compilation, signing or app launch is permitted by this validation.
set -euo pipefail
task_repo=/Users/muzi/Agent-loop
task_evidence="$task_repo/docs/collaboration/tasks/2026-09-05-desktop-coding-closure"
task_fixture=$(mktemp -d /tmp/agentloop-package-arguments.XXXXXX)
print -r -- "FIXTURE=$task_fixture"
mkdir "$task_fixture/bin" "$task_fixture/existing"
cp "$task_evidence/package-swift-stub.zsh" "$task_fixture/bin/swift"
chmod 0755 "$task_fixture/bin/swift"
cp "$task_evidence/package-plan.md" "$task_fixture/existing/sentinel"
ln -s "$task_fixture/existing" "$task_fixture/existing-link"
ln -s "$task_fixture/absent" "$task_fixture/dangling-link"
task_case_count=0

check_rejected() {
  local task_script="$1" task_name="$2" task_expected="$3"
  shift 3
  local task_log="$task_fixture/$task_name.log"
  local task_marker="$task_fixture/$task_name.swift"
  local task_exit=0
  if env PATH="$task_fixture/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      SIGN_ID=- NOTARY_PROFILE= \
      AGENTLOOP_PACKAGE_TEST_SWIFT_MARKER="$task_marker" \
      /bin/zsh "$task_script" "$@" > "$task_log" 2>&1; then
    task_exit=0
  else
    task_exit=$?
  fi
  [[ "$task_exit" -eq "$task_expected" && ! -e "$task_marker" ]]
  cmp "$task_evidence/package-plan.md" "$task_fixture/existing/sentinel"
  [[ -L "$task_fixture/existing-link" && -L "$task_fixture/dangling-link" ]]
  task_case_count=$((task_case_count + 1))
  print -r -- "PASS $task_name exit=$task_exit no-build"
}

for task_kind in run-app package-app; do
  task_script="$task_repo/scripts/$task_kind.sh"
  /bin/zsh -n "$task_script"
  check_rejected "$task_script" "$task_kind-missing-value" 2 --output-dir
  check_rejected "$task_script" "$task_kind-empty-value" 2 --output-dir ''
  check_rejected "$task_script" "$task_kind-following-flag" 2 --output-dir --preview
  check_rejected "$task_script" "$task_kind-existing-dir" 2 --output-dir "$task_fixture/existing"
  check_rejected "$task_script" "$task_kind-existing-link" 2 --output-dir "$task_fixture/existing-link"
  check_rejected "$task_script" "$task_kind-dangling-link" 2 --output-dir "$task_fixture/dangling-link"
  check_rejected "$task_script" "$task_kind-missing-parent" 2 --output-dir "$task_fixture/missing/child"
  [[ ! -e "$task_fixture/missing" ]]

  # Positive argument acceptance must claim its fresh directory before reaching
  # the stub. This prevents an old "unknown option" parser from passing the suite.
  task_target="$task_fixture/$task_kind-new"
  task_marker="$task_fixture/$task_kind-positive.swift"
  task_exit=0
  if env PATH="$task_fixture/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      SIGN_ID=- NOTARY_PROFILE= \
      AGENTLOOP_PACKAGE_TEST_SWIFT_MARKER="$task_marker" \
      /bin/zsh "$task_script" --output-dir "$task_target" \
      > "$task_fixture/$task_kind-positive.log" 2>&1; then
    task_exit=0
  else
    task_exit=$?
  fi
  [[ "$task_exit" -eq 99 && -d "$task_target" && -f "$task_marker" ]]
  [[ "$(< "$task_marker")" == *'--product AgentLoopApp'* ]]
  task_case_count=$((task_case_count + 1))
  print -r -- "PASS $task_kind-positive exit=99 stub-only fresh-dir-preserved"
done

task_marker="$task_fixture/notary-conflict.swift"
task_exit=0
if env PATH="$task_fixture/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    SIGN_ID=- NOTARY_PROFILE=fixture-no-keychain-use \
    AGENTLOOP_PACKAGE_TEST_SWIFT_MARKER="$task_marker" \
    /bin/zsh "$task_repo/scripts/package-app.sh" \
    --output-dir "$task_fixture/notary-output" \
    > "$task_fixture/notary-conflict.log" 2>&1; then
  task_exit=0
else
  task_exit=$?
fi
[[ "$task_exit" -eq 1 && ! -e "$task_marker" && ! -e "$task_fixture/notary-output" ]]
task_case_count=$((task_case_count + 1))
print -r -- 'PASS notary-conflict exit=1 no-build no-keychain no-output'
cmp "$task_evidence/package-plan.md" "$task_fixture/existing/sentinel"
shasum -a 256 -c "$task_evidence/package-old-app-identities.sha256"
print -r -- "PASS total=$task_case_count (argument/stub checks only, no real build/signature/App evidence)"
