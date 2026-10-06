#!/bin/zsh
# Notarize + staple the DMG so Gatekeeper opens it with NO malware warning.
#
# One-time Apple setup (paid Developer Program, $99/yr):
#   1. Enrol at https://developer.apple.com/programs/ → get a Team ID.
#   2. Xcode → Settings → Accounts → + → Apple ID → Download "Developer ID
#      Application" certificate (or create it at developer.apple.com → Certificates).
#   3. Apple ID → Sign-In and Security → App-specific password → generate one.
#
# Usage:
#   SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/package_app.sh 1.0.0
#   APPLE_ID="you@example.com" APP_PASSWORD="xxxx-xxxx-xxxx-xxxx" TEAM_ID="TEAMID" ./scripts/notarize.sh 1.0.0
#
# The DMG in dist/ is then Gatekeeper-clean: double-click install, no warning.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-1.0.0}"
DMG="dist/Aeroplane-Simulator-Offline-${VERSION}.dmg"

[[ -f "$DMG" ]] || { echo "missing $DMG — run package_app.sh first"; exit 1; }
for v in APPLE_ID APP_PASSWORD TEAM_ID; do
  [[ -n "${(P)v:-}" ]] || { echo "env $v is not set (see header of this script)"; exit 1; }
done
# The bundle must be Developer-ID signed (not ad-hoc) before notarization.
APP='dist/Aeroplane Simulator Offline.app'
codesign -dv "$APP" 2>&1 | grep -q "Authority=Developer ID Application" \
  || { echo ".app is not Developer-ID signed — rebuild with SIGN_IDENTITY set (see header)"; exit 1; }

echo "▶ Submitting to Apple notary service (takes 1–10 min)…"
xcrun notarytool submit "$DMG" \
  --apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID" \
  --wait

echo "▶ Stapling notarization ticket…"
xcrun stapler staple "$DMG"
spctl -a -t open --context context:primary-signature -v "$DMG" \
  && echo "✅ Gatekeeper-clean: $DMG"
