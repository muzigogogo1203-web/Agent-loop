#!/bin/zsh
set -euo pipefail
task_repo=/Users/muzi/Agent-loop
task_evidence="$task_repo/docs/collaboration/tasks/2026-09-05-desktop-coding-closure"
task_fixture=$(mktemp -d /tmp/agentloop-package-literal.XXXXXX)
task_fixture=$(cd "$task_fixture" && pwd -P)
print -r -- "FIXTURE=$task_fixture"
mkdir "$task_fixture/bin"
cp "$task_evidence/package-swift-stub.zsh" "$task_fixture/bin/swift"
chmod 0755 "$task_fixture/bin/swift"
for task_kind in run-app package-app; do
  task_target="$task_fixture/$task_kind-literal\npath"
  task_log="$task_fixture/$task_kind.log"
  task_exit=0
  if env PATH="$task_fixture/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      SIGN_ID=- NOTARY_PROFILE= \
      AGENTLOOP_PACKAGE_TEST_SWIFT_MARKER="$task_fixture/$task_kind.swift" \
      /bin/zsh "$task_repo/scripts/$task_kind.sh" --output-dir "$task_target" \
      > "$task_log" 2>&1; then
    task_exit=0
  else
    task_exit=$?
  fi
  [[ "$task_exit" -eq 99 && -d "$task_target" ]]
  rg --fixed-strings --line-regexp -- "==> 输出目录：$task_target" "$task_log"
  print -r -- "PASS $task_kind literal-path no-real-build"
done
