#!/bin/zsh
# AgentLoop 标准启动方式（本机 macOS 26.x 从 CLI 直跑裸二进制不渲染文字，
# 必须打成 .app bundle + ad-hoc 签名后经 LaunchServices 启动；背景见
# docs/collaboration/tasks/2026-07-05-m4-knowledge-dialogue/impl-report.md）。
#
# 用法：
#   scripts/run-app.sh            # 构建并启动（真实数据库）
#   scripts/run-app.sh --preview  # UI 预览模式（不读钥匙串、不调度；配合 AGENTLOOP_STATE_DIR）
#   scripts/run-app.sh --dark     # 追加强制暗色
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_FLAGS=()
# CLT-only 机器沙箱内构建需要重定向 Clang module cache（沿用测试跑法约定）
if [[ -n "${CLANG_MODULE_CACHE_PATH:-}" ]]; then
  BUILD_FLAGS+=(--disable-sandbox)
fi
swift build "${BUILD_FLAGS[@]}"

APP=.build/AgentLoop.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
cp .build/debug/AgentLoopApp "$APP/Contents/MacOS/AgentLoop"

SPARKLE_FRAMEWORK="$(find .build -path "*/AgentLoop.app/*" -prune -o -path "*/debug/Sparkle.framework" -type d -print | head -1)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_FRAMEWORK="$(find .build -path "*/Sparkle.xcframework/*/Sparkle.framework" -type d -print | head -1)"
fi
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
  ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
  if ! otool -l "$APP/Contents/MacOS/AgentLoop" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/AgentLoop"
  fi
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AgentLoop</string>
  <key>CFBundleIdentifier</key><string>com.muzi.agentloop.dev</string>
  <key>CFBundleName</key><string>AgentLoop</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>com.muzi.agentloop.oauth</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>agentloop</string>
      </array>
    </dict>
  </array>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSExceptionDomains</key>
    <dict>
      <key>ai-api.jdcloud.com</key>
      <dict>
        <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
      </dict>
    </dict>
  </dict>
</dict>
</plist>
PLIST
if [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
  codesign --force -s - "$APP/Contents/Frameworks/Sparkle.framework"
fi
codesign --force -s - "$APP"
codesign --verify --deep --strict "$APP"

OPEN_ARGS=(-n "$APP")
for arg in "$@"; do
  case "$arg" in
    --preview) OPEN_ARGS+=(--env AGENTLOOP_UI_PREVIEW=1) ;;
    --dark)    OPEN_ARGS+=(--env AGENTLOOP_FORCE_DARK=1) ;;
  esac
done
if [[ -n "${AGENTLOOP_STATE_DIR:-}" ]]; then
  OPEN_ARGS+=(--env "AGENTLOOP_STATE_DIR=${AGENTLOOP_STATE_DIR}")
fi
exec open "${OPEN_ARGS[@]}"
