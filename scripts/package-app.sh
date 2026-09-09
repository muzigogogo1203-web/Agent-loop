#!/bin/zsh
# Coding 牧场分发打包(M10-D6'):release 构建 → .app bundle → 签名 →(可选)公证 → DMG + zip
#
# 用法:
#   SIGN_ID=- scripts/package-app.sh            # 显式同次 ad-hoc 预览签名
#   scripts/package-app.sh --version 1.1.0      # 显式版本(默认取当前提交最近的祖先 vX.Y.Z 标签,无语义化版本标签兜底 1.1.0)
#   scripts/package-app.sh --feed-url <url>     # 写入 SUFeedURL(为将来 Sparkle 预留,当前无消费方)
#   scripts/package-app.sh --output-dir <path>  # 使用指定的全新输出目录
#   SIGN_ID="Developer ID Application: …" scripts/package-app.sh          # 正式签名(硬化运行时 + entitlements)
#   SIGN_ID="…" NOTARY_PROFILE=<profile> scripts/package-app.sh           # 签名 + 公证 + staple
#
# 公证凭据一次性配置(需要 Apple Developer 账号):
#   xcrun notarytool store-credentials <profile> --apple-id <id> --team-id <team> --password <app专用密码>
#
# 产出:每次全新的输出目录内生成 Coding 牧场.app、CodingRanch-<ver>.dmg 和 CodingRanch-<ver>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=""
FEED_URL=""
OUTPUT_DIR_REQUEST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version|--feed-url|--output-dir)
      OPTION="$1"
      if (( $# < 2 )); then
        print -u2 -- "${OPTION} 需要一个非空值"
        exit 2
      fi
      if [[ -z "$2" || "$2" == -* ]]; then
        print -u2 -- "${OPTION} 需要一个非空值，不能使用后续选项作为值"
        exit 2
      fi
      case "$OPTION" in
        --version) VERSION="$2" ;;
        --feed-url) FEED_URL="$2" ;;
        --output-dir) OUTPUT_DIR_REQUEST="$2" ;;
      esac
      shift 2
      ;;
    *) echo "未知参数:$1" >&2; exit 1 ;;
  esac
done
if [[ -z "$VERSION" ]]; then
  # Milestone tags such as `m3` are not valid application versions.
  VERSION="$(git describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
  VERSION="${VERSION:-1.1.0}"
fi
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
if [[ -z "${SIGN_ID+x}" || -z "$SIGN_ID" ]]; then
  echo "!! 必须显式设置 SIGN_ID=-（预览）或 Developer ID Application 身份" >&2
  exit 1
fi
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -n "$NOTARY_PROFILE" && "$SIGN_ID" == "-" ]]; then
  echo "!! 公证/发布包必须使用 Developer ID，不能使用 SIGN_ID=-" >&2
  exit 1
fi

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
  local parent="dist"
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
  OUTPUT_DIR="$(mktemp -d "${physical_parent}/CodingRanchCandidate.XXXXXX")"
}

if [[ -n "$OUTPUT_DIR_REQUEST" ]]; then
  claim_requested_output_dir "$OUTPUT_DIR_REQUEST"
else
  claim_default_output_dir
fi
print -r -- "==> 输出目录：${OUTPUT_DIR}"

BUILD_FLAGS=(-c release)
if [[ -n "${CLANG_MODULE_CACHE_PATH:-}" ]]; then
  BUILD_FLAGS+=(--disable-sandbox)
fi
echo "==> swift build ${BUILD_FLAGS[*]}"
swift build "${BUILD_FLAGS[@]}" --product AgentLoopApp
swift build "${BUILD_FLAGS[@]}" --product AgentLoopBoardBridge

APP_NAME="Coding 牧场"
APP="${OUTPUT_DIR}/${APP_NAME}.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp .build/release/AgentLoopApp "$APP/Contents/MacOS/AgentLoop"
HELPER="$APP/Contents/Helpers/AgentLoopBoardBridge"
cp .build/release/AgentLoopBoardBridge "$HELPER"
chmod 0755 "$HELPER"
[[ -x "$HELPER" ]]
cp -R .build/release/AgentLoop_AgentLoopApp.bundle "$APP/Contents/Resources/"

# 图标:代码绘制 1024 → iconset → icns
echo "==> icon"
ICON_TMP="$(mktemp -d)"
swift scripts/make-icon.swift "$ICON_TMP" >/dev/null
ICONSET="$ICON_TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON_TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$ICON_TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

FEED_URL_PLIST=""
if [[ -n "$FEED_URL" ]]; then
  FEED_URL_PLIST="  <key>SUFeedURL</key><string>${FEED_URL}</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AgentLoop</string>
  <key>CFBundleIdentifier</key><string>com.muzi.agentloop</string>
  <key>CFBundleName</key><string>AgentLoop</string>
  <key>CFBundleDisplayName</key><string>Coding 牧场</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
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
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Muzi</string>
${FEED_URL_PLIST}
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
APP_IDENTIFIER="com.muzi.agentloop"
if [[ "$SIGN_ID" != "-" ]]; then
  echo "==> codesign (Developer ID: ${SIGN_ID})"
  codesign --force --options runtime --timestamp \
    --identifier "$HELPER_IDENTIFIER" \
    -s "$SIGN_ID" "$HELPER"
  codesign --verify --strict --verbose=4 "$HELPER"
  codesign --force --options runtime --timestamp \
    --identifier "$APP_IDENTIFIER" \
    --entitlements scripts/agentloop.entitlements \
    -s "$SIGN_ID" "$APP"
  codesign --verify --deep --strict --verbose=4 "$APP"

  HELPER_SIGNATURE="$(codesign -dvvv "$HELPER" 2>&1)"
  APP_SIGNATURE="$(codesign -dvvv "$APP" 2>&1)"
  HELPER_TEAM="$(print -r -- "$HELPER_SIGNATURE" | sed -n 's/^TeamIdentifier=//p')"
  APP_TEAM="$(print -r -- "$APP_SIGNATURE" | sed -n 's/^TeamIdentifier=//p')"
  HELPER_ANCHOR="$(print -r -- "$HELPER_SIGNATURE" | sed -n 's/^Authority=//p' | tail -1)"
  APP_ANCHOR="$(print -r -- "$APP_SIGNATURE" | sed -n 's/^Authority=//p' | tail -1)"
  [[ -n "$HELPER_TEAM" && "$HELPER_TEAM" == "$APP_TEAM" ]]
  [[ -n "$HELPER_ANCHOR" && "$HELPER_ANCHOR" == "$APP_ANCHOR" ]]
  [[ "$HELPER_SIGNATURE" == *"Identifier=${HELPER_IDENTIFIER}"* ]]
  [[ "$HELPER_SIGNATURE" == *"Runtime Version="* ]]
  [[ "$APP_SIGNATURE" == *"Runtime Version="* ]]
  [[ "$HELPER_SIGNATURE" == *"Timestamp="* ]]
  [[ "$APP_SIGNATURE" == *"Timestamp="* ]]
else
  echo "==> codesign (explicit same-invocation ad-hoc preview)"
  codesign --force --identifier "$HELPER_IDENTIFIER" \
    -s - "$HELPER"
  codesign --force --identifier "$APP_IDENTIFIER" \
    -s - "$APP"
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
fi

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

if [[ "$SIGN_ID" != "-" ]]; then
  [[ "$SEALED_HELPER_REQUIREMENT" == *"identifier \"${HELPER_IDENTIFIER}\""* ]]
  DEVELOPER_ID_REQUIREMENT='=anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.13] exists'
  codesign --verify --strict --test-requirement "$DEVELOPER_ID_REQUIREMENT" "$HELPER"
  codesign --verify --deep --strict --test-requirement "$DEVELOPER_ID_REQUIREMENT" "$APP"
  HELPER_REQUIREMENT="$(codesign -dr - "$HELPER" 2>&1)"
  APP_REQUIREMENT="$(codesign -dr - "$APP" 2>&1)"
  [[ "$HELPER_REQUIREMENT" == *"anchor apple generic"* ]]
  [[ "$APP_REQUIREMENT" == *"anchor apple generic"* ]]
else
  # An ad-hoc nested-code seal is a byte-exact CDHash requirement rather than
  # a Developer ID designated requirement. Verify that exact sealed identity.
  [[ "$SEALED_HELPER_REQUIREMENT" == \
    "cdhash H\"${HELPER_CDHASH:l}\"" ]]
fi

echo "==> zip"
ZIP="${OUTPUT_DIR}/CodingRanch-${VERSION}.zip"
[[ ! -e "$ZIP" && ! -L "$ZIP" ]]
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "$NOTARY_PROFILE" ]]; then
  echo "==> notarize (profile: ${NOTARY_PROFILE})"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  # staple 后重打 zip,分发物带票据
  ditto -c -k --keepParent "$APP" "$ZIP"
else
  echo "==> 未配置 NOTARY_PROFILE,跳过公证(脚本头注释有一次性配置方法)"
fi

echo "==> DMG"
DMG="${OUTPUT_DIR}/CodingRanch-${VERSION}.dmg"
[[ ! -e "$DMG" && ! -L "$DMG" ]]
STAGING="$(mktemp -d)/CodingRanch"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Coding 牧场" -srcfolder "$STAGING" -format UDZO "$DMG" >/dev/null
if [[ -n "$NOTARY_PROFILE" && "$SIGN_ID" != "-" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

print -r -- "打包完成:${APP}(v${VERSION} build ${BUILD_NUMBER})"
print -r -- "  - ${ZIP}"
print -r -- "  - ${DMG}"
print -r -- "$APP_SIGNATURE"
