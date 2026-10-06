#!/usr/bin/env python3
"""Emit root index.yaml — queryable project knowledge for agents (feature debugging).

Points to original sources; never duplicates bodies. Stdlib only.
Usage: generate-index.py [--check]
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "index.yaml"

CONCEPTS = [
    # screens
    ('screen:menu', 'screen', 'Main menu', 'First screen: FLY NOW / Planes / How to Fly.', 'Sources/AeroplaneSimulatorOffline/Views/MainMenuView.swift', ['menu']),
    ('screen:planes', 'screen', 'Plane picker', '6-plane grid; sets GameState.selectedPlane.', 'Sources/AeroplaneSimulatorOffline/Views/PlaneSelectionView.swift', ['menu', 'planes']),
    ('screen:fly', 'screen', 'Flight screen', 'SceneKit view + HUD + mouse/SHIFT input.', 'Sources/AeroplaneSimulatorOffline/Views/FlyView.swift', ['fly', 'input']),
    ('screen:help', 'screen', 'How to Fly', 'Picture instructions for 3-5 yr olds.', 'Sources/AeroplaneSimulatorOffline/Views/MainMenuView.swift', ['help']),
    # views
    ('view:app', 'view', 'App entry + ContentView', '@main app, screen router, BigKidButton.', 'Sources/AeroplaneSimulatorOffline/Views/App.swift', ['entry']),
    ('view:fly-input', 'view', 'Mouse + SHIFT steering', 'FlySCNView: mouse position → steer, SHIFT/mouse-down → boost, ESC → menu.', 'Sources/AeroplaneSimulatorOffline/Views/FlyView.swift', ['input', 'controls']),
    # models
    ('model:planes', 'model', 'KidPlane catalogue', '6 planes: id, colours, speed, handling, style.', 'Sources/AeroplaneSimulatorOffline/Models/Plane.swift', ['planes']),
    ('model:gamestate', 'model', 'GameState', 'Single ObservableObject: screen, stars, rings, sound, sensitivity.', 'Sources/AeroplaneSimulatorOffline/Models/GameState.swift', ['state']),
    # game systems
    ('game:world', 'game', 'FlightScene world+loop', 'Island/ocean/clouds/stars/rings/balloons + 60fps renderer update.', 'Sources/AeroplaneSimulatorOffline/Game/FlightScene.swift', ['world', 'flight']),
    ('game:planes', 'game', 'PlaneFactory', 'Procedural cartoon planes (sellable, no 3rd-party IP) + boost trail.', 'Sources/AeroplaneSimulatorOffline/Game/PlaneFactory.swift', ['planes', '3d']),
    ('game:sound', 'game', 'SoundManager', 'Synthesised offline tones + speech cheers; no audio files.', 'Sources/AeroplaneSimulatorOffline/Game/SoundManager.swift', ['audio']),
    # planes (debugging aid: which style builds which wings)
    ('plane:red-jet', 'plane', 'Ruby Jet', 'Jet style, topSpeed 38, single wing + exhaust flame.', 'Sources/AeroplaneSimulatorOffline/Models/Plane.swift', ['jet']),
    ('plane:blue-prop', 'plane', 'Blue Buddy', 'Prop style, topSpeed 26, highest turn rate (beginner plane).', 'Sources/AeroplaneSimulatorOffline/Models/Plane.swift', ['prop']),
    ('plane:yellow-biplane', 'plane', 'Sunny Biplane', 'Biplane style: two wings + struts.', 'Sources/AeroplaneSimulatorOffline/Models/Plane.swift', ['biplane']),
    ('plane:green-glider', 'plane', 'Gerry Glider', 'Glider style: extra-wide wings, slowest.', 'Sources/AeroplaneSimulatorOffline/Models/Plane.swift', ['glider']),
    ('plane:pink-jumbo', 'plane', 'Pinky Jumbo', 'Jumbo style with upper hump.', 'Sources/AeroplaneSimulatorOffline/Models/Plane.swift', ['jumbo']),
    ('plane:orange-rocket', 'plane', 'Rocket Rory', 'Rocket style, fastest (46), exhaust flame.', 'Sources/AeroplaneSimulatorOffline/Models/Plane.swift', ['rocket']),
    # distribution
    ('dist:app', 'dist', 'Click-to-install .app', 'Assembled + ad-hoc signed by scripts/package_app.sh.', 'dist/Aeroplane Simulator Offline.app', ['install']),
    ('dist:dmg', 'dist', 'Drag-to-install .dmg', 'DMG with Applications symlink; checksum-verified by ./aero verify.', 'dist/Aeroplane-Simulator-Offline-1.0.0.dmg', ['install']),
    # docs & process
    ('doc:contract', 'doc', 'Agent contract', 'Binding rules, Verification Gate, testing, release.', 'CLAUDE.md', ['process']),
    ('doc:observability', 'doc', 'Observability', 'Logs, crash reports, launch-smoke evidence steps.', 'docs/observability.md', ['process', 'logs']),
    ('doc:free-assets', 'doc', 'Free 3D assets guide', 'Which CC0 packs are resale-safe + .usdz wiring.', 'docs/FreeAssets.md', ['assets', 'legal']),
    ('doc:store-listing', 'doc', 'App Store listing', 'Name, subtitle, keywords, privacy answers, review notes.', 'AppStore/Listing.md', ['release']),
    # skills
    ('skill:swiftui', 'skill', 'macos-swiftui', 'When to use: editing SwiftUI screens, HUD, menu, navigation.', '.claude/skills/macos-swiftui/SKILL.md', ['skill']),
    ('skill:scenekit', 'skill', 'scenekit-world', 'When to use: flight loop, steering, clouds/stars/rings, camera.', '.claude/skills/scenekit-world/SKILL.md', ['skill']),
    ('skill:planes', 'skill', 'planes-content', 'When to use: catalogue, PlaneFactory looks, balancing speeds.', '.claude/skills/planes-content/SKILL.md', ['skill']),
    ('skill:release', 'skill', 'release', 'When to use: packaging, signing, DMG, App Store submission.', '.claude/skills/release/SKILL.md', ['skill']),
]

def yaml_str(s: str) -> str:
    return '"' + s.replace('"', "'") + '"'

def main():
    check = "--check" in sys.argv
    out = []
    out.append('format: "aero-project-knowledge-index"')
    out.append('version: "1.0"')
    out.append('generated_by: "cli/generate-index.py"')
    out.append('authoritative_sources:')
    out.append('  inventory: "docs/project-index.json"')
    out.append('  code_map: "map.mmd"')
    out.append('  wiring: "docs/systematic-map.mmd"')
    out.append('rules:')
    for r in [
        "Concepts point to original sources; this index never duplicates source bodies.",
        "Read discovery first; query only the relevant section. Do not load this entire index into agent context.",
        "Use at most three discovery hops: entry instructions, exact index match, original source.",
    ]:
        out.append(f'  - {yaml_str(r)}')
    out.append('discovery:')
    for q, u in [
        ("Does a screen, view, model or game system exist?", "docs/project-index.json"),
        ("How are screens, views, models and game systems connected?", "docs/systematic-map.mmd"),
        ("Where is the mouse/SHIFT steering code?", 'concepts filtered by type=view, then read its resource'),
        ("Which plane style builds which wings / speed?", 'concepts filtered by type=plane, then read its resource'),
        ("What repo instructions or skill apply?", "CLAUDE.md, AGENTS.md, then .claude/skills"),
        ("How do I build the installer or debug a crash?", "docs/observability.md + ./aero logs"),
    ]:
        out.append(f'  - question: {yaml_str(q)}')
        out.append(f'    use: {yaml_str(u)}')
    out.append('query_examples:')
    for q in [
        "sed -n '1,40p' index.yaml",
        "rg -n -B2 -A8 'id: \"screen:fly\"' index.yaml",
        "rg -n -A6 'type: \"plane\"' index.yaml",
        "rg -n '<term>' docs/project-index.json map.mmd index.yaml",
    ]:
        out.append(f'  - {yaml_str(q)}')
    by_type = {}
    for c in CONCEPTS:
        by_type[c[1]] = by_type.get(c[1], 0) + 1
    out.append('summary:')
    out.append(f'  concepts: {len(CONCEPTS)}')
    out.append('  by_type:')
    for t in sorted(by_type):
        out.append(f'    {t}: {by_type[t]}')
    out.append('concepts:')
    for cid, ctype, title, desc, res, tags in CONCEPTS:
        out.append(f'  - id: {yaml_str(cid)}')
        out.append(f'    type: {yaml_str(ctype)}')
        out.append(f'    title: {yaml_str(title)}')
        out.append(f'    description: {yaml_str(desc)}')
        out.append(f'    resource: {yaml_str(res)}')
        out.append('    tags:')
        for t in tags:
            out.append(f'      - {yaml_str(t)}')
    text = "\n".join(out) + "\n"
    if check:
        cur = OUT.read_text() if OUT.exists() else ""
        if cur != text:
            print("DRIFT: index.yaml is stale — run ./aero index", file=sys.stderr)
            return 1
        print("index.yaml: in sync")
        return 0
    OUT.write_text(text)
    print(f"wrote {OUT} ({len(CONCEPTS)} concepts)")
    return 0

if __name__ == "__main__":
    sys.exit(main())
