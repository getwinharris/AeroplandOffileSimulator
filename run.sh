#!/bin/zsh
# Quick dev run — opens via Swift (Xcode not required for logic check).
# For full Mac App Store build: open Package.swift in Xcode → Product → Archive.
set -e
cd "$(dirname "$0")"
swift build --disable-sandbox
echo "✅ Build OK. To play:"
echo "  1. Open this folder in Xcode (File → Open → Package.swift)"
echo "  2. Press ▶ Run (My Mac destination)"
echo "  Or: .build/debug/AeroplaneSimulatorOffline (GUI needs Xcode run)"
