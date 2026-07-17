#!/bin/zsh
# Coding 牧场分发打包(M10-D6'):release 构建 → .app bundle → 签名 →(可选)公证 → DMG + zip
#
# 用法:
#   scripts/package-app.sh                      # ad-hoc 签名(本机/亲友分发;跨机首启需右键打开过 Gatekeeper)
#   scripts/package-app.sh --version 1.1.0      # 显式版本(默认取当前提交最近的祖先 vX.Y.Z 标签,无语义化版本标签兜底 1.1.0)
#   scripts/package-app.sh --feed-url <url>     # 写入 SUFeedURL(为将来 Sparkle 预留,当前无消费方)
#   SIGN_ID="Developer ID Application: …" scripts/package-app.sh          # 正式签名(硬化运行时 + entitlements)
#   SIGN_ID="…" NOTARY_PROFILE=<profile> scripts/package-app.sh           # 签名 + 公证 + staple
#
# 公证凭据一次性配置(需要 Apple Developer 账号):
#   xcrun notarytool store-credentials <profile> --apple-id <id> --team-id <team> --password <app专用密码>
#
# 产出:dist/Coding 牧场.app、dist/CodingRanch-<ver>.dmg、dist/CodingRanch-<ver>.zip
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=""
FEED_URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --feed-url) FEED_URL="$2"; shift 2 ;;
    *) echo "未知参数:$1" >&2; exit 1 ;;
  esac
done
if [[ -z "$VERSION" ]]; then
  # Milestone tags such as `m3` are not valid application versions.
  VERSION="$(git describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --abbrev=0 2>/dev/null | sed 's/^v//' || true)"
  VERSION="${VERSION:-1.1.0}"
fi
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
SIGN_ID="${SIGN_ID:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

BUILD_FLAGS=(-c release)
if [[ -n "${CLANG_MODULE_CACHE_PATH:-}" ]]; then
  BUILD_FLAGS+=(--disable-sandbox)
fi
echo "==> swift build ${BUILD_FLAGS[*]}"
swift build "${BUILD_FLAGS[@]}"

APP_NAME="Coding 牧场"
APP="dist/${APP_NAME}.app"
rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AgentLoopApp "$APP/Contents/MacOS/AgentLoop"

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

if [[ "$SIGN_ID" != "-" ]]; then
  echo "==> codesign (Developer ID: ${SIGN_ID})"
  codesign --force --options runtime --timestamp \
    --entitlements scripts/agentloop.entitlements \
    -s "$SIGN_ID" "$APP"
else
  echo "==> codesign (ad-hoc;跨机首启需右键打开过 Gatekeeper)"
  codesign --force -s - "$APP"
fi

echo "==> zip"
ZIP="dist/CodingRanch-${VERSION}.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

if [[ -n "$NOTARY_PROFILE" ]]; then
  if [[ "$SIGN_ID" == "-" ]]; then
    echo "!! 公证需要 Developer ID 签名(SIGN_ID),已跳过公证" >&2
  else
    echo "==> notarize (profile: ${NOTARY_PROFILE})"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP"
    # staple 后重打 zip,分发物带票据
    ditto -c -k --keepParent "$APP" "$ZIP"
  fi
else
  echo "==> 未配置 NOTARY_PROFILE,跳过公证(脚本头注释有一次性配置方法)"
fi

echo "==> DMG"
DMG="dist/CodingRanch-${VERSION}.dmg"
STAGING="$(mktemp -d)/CodingRanch"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "Coding 牧场" -srcfolder "$STAGING" -format UDZO -ov "$DMG" >/dev/null
if [[ -n "$NOTARY_PROFILE" && "$SIGN_ID" != "-" ]]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "打包完成:$APP(v${VERSION} build ${BUILD_NUMBER})"
echo "  - $ZIP"
echo "  - $DMG"
codesign -dv "$APP" 2>&1 | head -3
