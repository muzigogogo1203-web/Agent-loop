#!/bin/zsh
# AgentLoop 分发打包（M10 长明火）：
# release 构建 → .app bundle → hardened runtime 签名 → zip + DMG → 可选公证/装订。
#
# 用法：
#   scripts/package-app.sh 1.0.0
#   VERSION=1.0.0 SIGN_ID="Developer ID Application: ..." NOTARY_PROFILE=agentloop scripts/package-app.sh
#   APPCAST_URL="https://example.com/appcast.xml" SPARKLE_PUBLIC_KEY="..." scripts/package-app.sh 1.0.0
#
# 产出：
#   dist/AgentLoop.app
#   dist/AgentLoop-<version>.zip
#   dist/AgentLoop-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="AgentLoop"
VERSION="${1:-${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || echo 1.0.0)}}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
SIGN_ID="${SIGN_ID:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ENTITLEMENTS="${ENTITLEMENTS:-scripts/AgentLoop.entitlements}"
APPCAST_URL="${APPCAST_URL:-}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"

DIST_DIR="dist"
APP="$DIST_DIR/${APP_NAME}.app"
ZIP="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
DMG="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"

BUILD_FLAGS=(-c release)
if [[ -n "${CLANG_MODULE_CACHE_PATH:-}" ]]; then
  BUILD_FLAGS+=(--disable-sandbox)
fi

echo "==> swift build ${BUILD_FLAGS[*]}"
swift build "${BUILD_FLAGS[@]}"

xml_escape() {
  printf '%s' "$1" \
    | sed -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g"
}

SPARKLE_PLIST_KEYS=""
if [[ -n "$APPCAST_URL" && -n "$SPARKLE_PUBLIC_KEY" ]]; then
  APPCAST_URL_XML="$(xml_escape "$APPCAST_URL")"
  SPARKLE_PUBLIC_KEY_XML="$(xml_escape "$SPARKLE_PUBLIC_KEY")"
  SPARKLE_PLIST_KEYS=$'  <key>SUFeedURL</key><string>'"${APPCAST_URL_XML}"$'</string>\n  <key>SUPublicEDKey</key><string>'"${SPARKLE_PUBLIC_KEY_XML}"$'</string>'
else
  echo "==> Sparkle feed disabled (set APPCAST_URL and SPARKLE_PUBLIC_KEY to enable runtime updates)"
fi

echo "==> bundle ${APP}"
rm -rf "$DIST_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp .build/release/AgentLoopApp "$APP/Contents/MacOS/AgentLoop"

SPARKLE_FRAMEWORK="$(find .build -path "*/AgentLoop.app/*" -prune -o -path "*/release/Sparkle.framework" -type d -print | head -1)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_FRAMEWORK="$(find .build -path "*/Sparkle.xcframework/*/Sparkle.framework" -type d -print | head -1)"
fi
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
  echo "==> embed Sparkle.framework"
  ditto "$SPARKLE_FRAMEWORK" "$APP/Contents/Frameworks/Sparkle.framework"
  if ! otool -l "$APP/Contents/MacOS/AgentLoop" | grep -q "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/AgentLoop"
  fi
else
  echo "warning: Sparkle.framework not found under .build"
fi

echo "==> icon"
ICON_TMP="$(mktemp -d)"
trap 'rm -rf "$ICON_TMP" "${DMG_ROOT:-}"' EXIT
swift scripts/make-icon.swift "$ICON_TMP" >/dev/null
ICONSET="$ICON_TMP/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON_TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z $d $d "$ICON_TMP/icon_1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AgentLoop</string>
  <key>CFBundleIdentifier</key><string>com.muzi.agentloop</string>
  <key>CFBundleName</key><string>AgentLoop</string>
  <key>CFBundleDisplayName</key><string>AgentLoop</string>
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
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 Muzi</string>
  <key>NSUserNotificationAlertStyle</key><string>alert</string>
${SPARKLE_PLIST_KEYS}
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

echo "==> codesign (${SIGN_ID})"
if [[ -d "$APP/Contents/Frameworks/Sparkle.framework" ]]; then
  if [[ "$SIGN_ID" == "-" ]]; then
    codesign --force --options runtime -s - "$APP/Contents/Frameworks/Sparkle.framework"
  else
    codesign --force --timestamp --options runtime -s "$SIGN_ID" "$APP/Contents/Frameworks/Sparkle.framework"
  fi
fi
if [[ "$SIGN_ID" == "-" ]]; then
  codesign --force --options runtime --entitlements "$ENTITLEMENTS" -s - "$APP"
else
  codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS" -s "$SIGN_ID" "$APP"
fi
codesign --verify --deep --strict "$APP"

echo "==> zip ${ZIP}"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> dmg ${DMG}"
DMG_ROOT="$(mktemp -d)"
cp -R "$APP" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"
hdiutil create \
  -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG" >/dev/null

if [[ -n "$NOTARY_PROFILE" && "$SIGN_ID" != "-" ]]; then
  echo "==> notarize (${NOTARY_PROFILE})"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "==> staple"
  xcrun stapler staple "$DMG"
else
  echo "==> notarize skipped (set NOTARY_PROFILE and SIGN_ID for Developer ID release)"
fi

echo "打包完成："
echo "  $APP"
echo "  $ZIP"
echo "  $DMG"
codesign -dv "$APP" 2>&1 | head -4
