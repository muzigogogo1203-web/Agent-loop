#!/bin/zsh
# AgentLoop 标准启动方式（本机 macOS 26.x 从 CLI 直跑裸二进制不渲染文字，
# 必须打成 .app bundle + ad-hoc 签名后经 LaunchServices 启动；背景见
# docs/collaboration/tasks/2026-07-05-m4-knowledge-dialogue/impl-report.md）。
#
# 用法：
#   scripts/run-app.sh            # 构建并启动（真实数据库）
#   scripts/run-app.sh --preview  # UI 预览模式（不读钥匙串、不调度；默认使用隔离状态目录）
#   scripts/run-app.sh --dark     # 追加强制暗色
set -euo pipefail
cd "$(dirname "$0")/.."

PREVIEW=false
FORCE_DARK=false
for arg in "$@"; do
  case "$arg" in
    --preview) PREVIEW=true ;;
    --dark)    FORCE_DARK=true ;;
    *)
      print -u2 -- "未知参数：${arg}"
      exit 2
      ;;
  esac
done

# LaunchServices 复用现有实例时会忽略本次 `open --env`，而脚本无法可靠判断现有
# 进程究竟是 production、preview 还是自定义状态目录。所有脚本启动都要求冷启动，
# 避免两个方向的模式混淆（例如 preview→默认启动仍继续复用 preview 进程）。
ensure_cold_launch() {
  if pgrep -x 'AgentLoop|AgentLoopApp' >/dev/null; then
    print -u2 -- "AgentLoop 已在运行；脚本无法安全切换或确认现有进程的运行模式。请先退出现有实例，再重新启动。"
    exit 1
  fi
}

ensure_cold_launch

BUILD_FLAGS=()
# CLT-only 机器沙箱内构建需要重定向 Clang module cache（沿用测试跑法约定）
if [[ -n "${CLANG_MODULE_CACHE_PATH:-}" ]]; then
  BUILD_FLAGS+=(--disable-sandbox)
fi
swift build "${BUILD_FLAGS[@]}"

APP=.build/AgentLoop.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/AgentLoopApp "$APP/Contents/MacOS/AgentLoop"
mkdir -p "$APP/Contents/Resources"
cp -R .build/debug/AgentLoop_AgentLoopApp.bundle "$APP/Contents/Resources/"
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
  <key>LSMultipleInstancesProhibited</key><true/>
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
codesign --force -s - "$APP"

OPEN_ARGS=("$APP")
if [[ "$PREVIEW" == true ]]; then
  OPEN_ARGS+=(--env AGENTLOOP_UI_PREVIEW=1)
fi
if [[ "$FORCE_DARK" == true ]]; then
  OPEN_ARGS+=(--env AGENTLOOP_FORCE_DARK=1)
fi
if [[ -n "${AGENTLOOP_STATE_DIR:-}" ]]; then
  OPEN_ARGS+=(--env "AGENTLOOP_STATE_DIR=${AGENTLOOP_STATE_DIR}")
elif [[ "$PREVIEW" == true ]]; then
  OPEN_ARGS+=(--env "AGENTLOOP_STATE_DIR=${PWD}/.build/AgentLoopPreviewState")
fi
# 构建与签名期间可能有另一个实例启动；交给 LaunchServices 前再次验证，缩小
# 现有进程静默吞掉本次模式/状态目录参数的竞态窗口。
ensure_cold_launch
exec open "${OPEN_ARGS[@]}"
