#!/bin/zsh
# AgentLoop 分发打包（M5-5）：release 构建 → .app bundle（Info.plist/图标）→ 签名 → dist/
#
# 用法：
#   scripts/package-app.sh                # ad-hoc 签名（本机/亲友分发；跨机首启需右键打开过 Gatekeeper）
#   SIGN_ID="Developer ID Application: …" scripts/package-app.sh   # 正式签名（有证书时）
#
# 产出：dist/AgentLoop.app + dist/AgentLoop.zip
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.5.0"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
SIGN_ID="${SIGN_ID:--}"

BUILD_FLAGS=(-c release)
if [[ -n "${CLANG_MODULE_CACHE_PATH:-}" ]]; then
  BUILD_FLAGS+=(--disable-sandbox)
fi
echo "==> swift build ${BUILD_FLAGS[*]}"
swift build "${BUILD_FLAGS[@]}"

APP=dist/AgentLoop.app
rm -rf dist && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AgentLoopApp "$APP/Contents/MacOS/AgentLoop"

# 图标：代码绘制 1024 → iconset → icns
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
codesign --force --options runtime -s "$SIGN_ID" "$APP" 2>/dev/null \
  || codesign --force -s "$SIGN_ID" "$APP"

echo "==> zip"
ditto -c -k --keepParent "$APP" dist/AgentLoop.zip

echo "打包完成：$APP（v${VERSION} build ${BUILD_NUMBER}）"
codesign -dv "$APP" 2>&1 | head -3
