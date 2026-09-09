#!/bin/zsh
set -euo pipefail
print -r -- "STUB_ONLY $*" > "${AGENTLOOP_PACKAGE_TEST_SWIFT_MARKER:?}"
exit 99
