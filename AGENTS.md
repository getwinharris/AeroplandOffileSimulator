---
description: Pointer to the binding agent contract for this Swift/SceneKit macOS game repo.
globs: *
alwaysApply: true
---

# Agent Operating Guide

**`CLAUDE.md` is the binding contract. Read it and follow it in full.**

This file exists so non-Claude tooling that looks for `AGENTS.md` still finds the
contract. It deliberately does not restate the rules — there is exactly one copy of
each, and it lives in `CLAUDE.md`.

Quick orientation:
- Skills: canonical project skills live in `.claude/skills/<name>/SKILL.md`
- Wiring: `docs/systematic-map.mmd`
- Click-to-install build: `dist/Aeroplane Simulator Offline.app` + `.dmg` (built by `./aero build-app`)
- Local observability: `./aero logs` (unified log for the bundle id), `docs/observability.md`

Before any change: `./aero map`.
Before pushing to `main`: `./aero ci`, and confirm it is green.

The product has exactly one agent surface: none at runtime. This is a fully
offline kids' game — no chat, no network, no accounts.
Inventory of what actually exists (check before claiming a feature):
`docs/project-index.json` — generated, committed, drift-checked by `./aero ci`.

Queryable project knowledge: `index.yaml`. It points to the original screens,
views, game systems, docs, maps and skills; it does not duplicate source bodies.
Read `discovery` first and query narrowly; do not load the complete generated
index into agent context. Use a three-hop budget:
entry instructions → exact index match → original source. Avoid broad `ls`, recursive
globs and Git history unless the indexed target is absent.
