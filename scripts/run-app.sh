#!/bin/zsh
# AgentLoop 标准启动方式（本机 macOS 26.x 从 CLI 直跑裸二进制不渲染文字，
# 必须打成 .app bundle + ad-hoc 签名后经 LaunchServices 启动；背景见
# docs/collaboration/tasks/2026-07-05-m4-knowledge-dialogue/impl-report.md）。
#
# 用法：
#   scripts/run-app.sh                                      # 构建并启动（真实数据库）
#   scripts/run-app.sh --preview                            # UI 预览模式（不读钥匙串、不调度）
#   scripts/run-app.sh --dark                               # 追加强制暗色
#   scripts/run-app.sh --output-dir /path/to/absent-output  # 使用指定的全新输出目录
set -euo pipefail
cd "$(dirname "$0")/.."

PREVIEW=false
FORCE_DARK=false
OUTPUT_DIR_REQUEST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preview)
      PREVIEW=true
      shift
      ;;
    --dark)
      FORCE_DARK=true
      shift
      ;;
    --output-dir)
      if (( $# < 2 )); then
        print -u2 -- "--output-dir 需要一个非空路径"
        exit 2
      fi
      if [[ -z "$2" || "$2" == -* ]]; then
        print -u2 -- "--output-dir 需要一个非空路径，不能使用后续选项作为路径"
        exit 2
      fi
      OUTPUT_DIR_REQUEST="$2"
      shift 2
      ;;
    *)
      print -u2 -- "未知参数：$1"
      exit 2
      ;;
  esac
done

claim_requested_output_dir() {
  local requested="$1"
  local requested_parent="${requested:h}"
  local requested_leaf="${requested:t}"
  local physical_parent

  if [[ -e "$requested" || -L "$requested" ]]; then
    print -r -u2 -- "输出路径已存在，不会覆盖或复用：${requested}"
    exit 2
  fi
  if [[ ! -d "$requested_parent" ]]; then
    print -r -u2 -- "输出路径的父目录不存在或不是目录：${requested_parent}"
    exit 2
  fi

  physical_parent="$(cd "$requested_parent" && pwd -P)"
  OUTPUT_DIR="${physical_parent}/${requested_leaf}"
  if [[ -e "$OUTPUT_DIR" || -L "$OUTPUT_DIR" ]]; then
    print -r -u2 -- "规范化后的输出路径已存在，不会覆盖或复用：${OUTPUT_DIR}"
    exit 2
  fi
  if ! mkdir "$OUTPUT_DIR"; then
    print -r -u2 -- "无法独占全新输出目录（可能已被并发创建）：${OUTPUT_DIR}"
    exit 2
  fi
}

claim_default_output_dir() {
  local parent=".build"
  local physical_parent

  if [[ -L "$parent" || ( -e "$parent" && ! -d "$parent" ) ]]; then
    print -r -u2 -- "默认输出父路径必须是非符号链接目录：${parent}"
    exit 2
  fi
  mkdir -p "$parent"
  if [[ -L "$parent" || ! -d "$parent" ]]; then
    print -r -u2 -- "默认输出父路径必须是非符号链接目录：${parent}"
    exit 2
  fi
  physical_parent="$(cd "$parent" && pwd -P)"
  OUTPUT_DIR="$(mktemp -d "${physical_parent}/AgentLoopDev.XXXXXX")"
}

if [[ -n "$OUTPUT_DIR_REQUEST" ]]; then
  claim_requested_output_dir "$OUTPUT_DIR_REQUEST"
else
  claim_default_output_dir
fi
print -r -- "==> 输出目录：${OUTPUT_DIR}"

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
swift build "${BUILD_FLAGS[@]}" --product AgentLoopApp
swift build "${BUILD_FLAGS[@]}" --product AgentLoopBoardBridge

APP="${OUTPUT_DIR}/AgentLoop.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp .build/debug/AgentLoopApp "$APP/Contents/MacOS/AgentLoop"
HELPER="$APP/Contents/Helpers/AgentLoopBoardBridge"
cp .build/debug/AgentLoopBoardBridge "$HELPER"
chmod 0755 "$HELPER"
[[ -x "$HELPER" ]]
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

HELPER_IDENTIFIER="com.muzi.agentloop.board-bridge"
APP_IDENTIFIER="com.muzi.agentloop.dev"
codesign --force --identifier "$HELPER_IDENTIFIER" -s - "$HELPER"
codesign --force --identifier "$APP_IDENTIFIER" -s - "$APP"
codesign --verify --strict --verbose=4 "$HELPER"
codesign --verify --deep --strict --verbose=4 "$APP"

HELPER_SIGNATURE="$(codesign -dvvv "$HELPER" 2>&1)"
APP_SIGNATURE="$(codesign -dvvv "$APP" 2>&1)"
[[ "$HELPER_SIGNATURE" == *"Identifier=${HELPER_IDENTIFIER}"* ]]
[[ "$APP_SIGNATURE" == *"Identifier=${APP_IDENTIFIER}"* ]]
[[ "$HELPER_SIGNATURE" == *"Signature=adhoc"* ]]
[[ "$APP_SIGNATURE" == *"Signature=adhoc"* ]]
[[ "$HELPER_SIGNATURE" != *"Runtime Version="* ]]
[[ "$APP_SIGNATURE" != *"Runtime Version="* ]]
[[ "$HELPER_SIGNATURE" != *"Timestamp="* ]]
[[ "$APP_SIGNATURE" != *"Timestamp="* ]]

HELPER_CDHASH="$(print -r -- "$HELPER_SIGNATURE" | sed -n 's/^CDHash=//p')"
APP_CDHASH="$(print -r -- "$APP_SIGNATURE" | sed -n 's/^CDHash=//p')"
[[ -n "$HELPER_CDHASH" && -n "$APP_CDHASH" ]]
codesign --verify --deep --strict --verbose=4 "$APP"
codesign --verify --strict --verbose=4 "$HELPER"

CODE_RESOURCES="$APP/Contents/_CodeSignature/CodeResources"
[[ -f "$CODE_RESOURCES" ]]
SEALED_HELPER_CDHASH="$(plutil -extract \
  'files2.Helpers/AgentLoopBoardBridge.cdhash' raw -o - \
  "$CODE_RESOURCES" | base64 -D | xxd -p | tr -d '\n')"
SEALED_HELPER_REQUIREMENT="$(plutil -extract \
  'files2.Helpers/AgentLoopBoardBridge.requirement' raw -o - \
  "$CODE_RESOURCES")"
[[ "$SEALED_HELPER_CDHASH" == "${HELPER_CDHASH:l}" ]]
[[ "$SEALED_HELPER_REQUIREMENT" == \
  "cdhash H\"${HELPER_CDHASH:l}\"" ]]

print -r -- "==> 开发 App：${APP}"

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
