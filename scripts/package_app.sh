#!/bin/zsh
# Builds the click-to-install Mac app:
#   dist/"Aeroplane Simulator Offline.app"  (double-click to run)
#   dist/Aeroplane-Simulator-Offline-<ver>.dmg (drag to Applications to install)
set -euo pipefail
cd "$(dirname "$0")/.."
APP_NAME="Aeroplane Simulator Offline"
VERSION="${1:-1.0.0}"
DIST="dist"
STAGE="$DIST/dmg-stage"

echo "▶ Building release binary…"
swift build -c release --disable-sandbox

echo "▶ Rendering icon…"
rm -rf /tmp/AeroIcon
swift scripts/make_icon.swift /tmp/AeroIcon
iconutil -c icns /tmp/AeroIcon/AppIcon.iconset -o /tmp/AeroIcon/AppIcon.icns

echo "▶ Assembling .app bundle…"
rm -rf "$DIST/$APP_NAME.app" "$STAGE"
mkdir -p "$DIST/$APP_NAME.app/Contents/MacOS" "$DIST/$APP_NAME.app/Contents/Resources"
cp -f ".build/release/AeroplaneSimulatorOffline" "$DIST/$APP_NAME.app/Contents/MacOS/$APP_NAME"
chmod +x "$DIST/$APP_NAME.app/Contents/MacOS/$APP_NAME"
cp -f /tmp/AeroIcon/AppIcon.icns "$DIST/$APP_NAME.app/Contents/Resources/AppIcon.icns"
cat > "$DIST/$APP_NAME.app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Aeroplane Simulator Offline</string>
    <key>CFBundleDisplayName</key><string>Aeroplane Simulator Offline</string>
    <key>CFBundleIdentifier</key><string>com.getwinharris.aeroplane-simulator-offline</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.family-games</string>
</dict>
</plist>
PLIST
echo -n "APPL????" > "$DIST/$APP_NAME.app/Contents/PkgInfo"
plutil -lint "$DIST/$APP_NAME.app/Contents/Info.plist"

echo "▶ Signing…"
# SIGN_IDENTITY: "-" (ad-hoc, default) or your Developer ID, e.g.
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package_app.sh 1.0.0
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "  Ad-hoc signing (Gatekeeper will warn on downloaded copies — see scripts/notarize.sh for the fix)…"
  codesign --force --deep --sign - "$DIST/$APP_NAME.app"
else
  echo "  Developer ID signing with hardened runtime: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    --entitlements AeroplaneSimulatorOffline.entitlements "$DIST/$APP_NAME.app"
fi
codesign --verify --verbose "$DIST/$APP_NAME.app"

echo "▶ Building DMG installer…"
mkdir -p "$STAGE"
cp -R "$DIST/$APP_NAME.app" "$STAGE/"
ln -sfn /Applications "$STAGE/Applications"
DMG="$DIST/Aeroplane-Simulator-Offline-${VERSION}.dmg"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --force --sign "$SIGN_IDENTITY" "$DMG"
echo "✅ APP: $DIST/$APP_NAME.app"
echo "✅ DMG: $DMG"
ls -la "$DIST"
