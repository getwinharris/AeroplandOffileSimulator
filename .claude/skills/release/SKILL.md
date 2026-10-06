---
name: release
description: Use when packaging the .app/.dmg, signing, versioning, or submitting to the Mac App Store.
---
# Release (click-to-install + App Store)

- Follow the root `AGENTS.md` repository contract. The Verification Gate
  (`./aero ci`) must be green before any release.
- Build: `./scripts/package_app.sh <version>` → `dist/` gets the signed
  `.app` (double-click to run) + `.dmg` (drag to Applications to install).
  Then `./aero verify` (plist lint, signature, DMG checksum).
- Versioning: bump `CFBundleVersion` via the script arg, tag `v<version>`,
  `gh release create` with the `.dmg` attached.
- Signing ladder: ad-hoc (`codesign -s -`, local installs, Gatekeeper asks
  once) → Developer ID + notarization (silent install) → App Store
  distribution (Archive from full Xcode, see `AppStore/Listing.md`).
- This machine has CLT only: `swift build` + `.app`/`.dmg` assembly works here;
  Run/Archive/notarization needs full Xcode.
- Never commit `dist/` to git (gitignored) — releases carry the binaries.
