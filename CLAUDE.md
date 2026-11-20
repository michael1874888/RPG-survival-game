# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Bramble" (working title): a mobile-first cute-animal survival-action game prototype. Godot **4.7.2 standard (not .NET)**, GDScript, GL Compatibility renderer, landscape 1280×720. Single playable character: the black cat Nana. Docs, design notes and in-game text are written in Traditional Chinese; keep that convention when editing them.

Current version is v0.20.0 "R1" (first-chapter expedition). R2 (full launch content) and R3 (release candidate) are not done. Read [HANDOFF.md](HANDOFF.md) first in a new session — it holds the latest decisions, user feedback and open work, and [docs/README.md](docs/README.md) indexes all docs. [GLOSSARY.md](GLOSSARY.md) defines the project's design terms (構築, 局內升級, etc.).

Working agreement recorded in HANDOFF: advance the main line in small milestones, log off-direction issues for the relevant later stage, and ask before changing core gameplay/controls/build direction. Automated test results (invincible/auto-aim controllers) must never be reported as human win rates or "fun" validation; only the user's playtests count for that.

## Commands

Godot defaults to `/Applications/Godot.app/Contents/MacOS/Godot`; override with `BRAMBLE_GODOT_BIN`.

```sh
./Play.command                      # run the game (or: godot --path game)
./Edit.command                      # open the editor (or: godot --editor --path game)
bash scripts/test-game.sh           # import project, then run every headless test suite
python3 -B scripts/verify-packaged-nana.py   # verify the packaged (exported) rules
```

There is no single-test flag. `scripts/test-game.sh` runs each suite as a Godot `SceneTree` script and requires its summary line (e.g. `R1 RESULT: N checks, 0 failures`) with no `SCRIPT ERROR`. To run one suite:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/r1_tests.gd
```

(run `--editor --import --quit` once first on a fresh checkout so `game/.godot/` exists). Suites live in `game/tests/`: `run_tests`, `nana_build_tests`, `nana_series_tests`, `nana_growth_tests`, `treasure_tests`, `scene_flow` (legacy, real scene), and `r1_tests`, `r1_mechanics`, `r1_scene_flow` (v0.20). `r1_autoplay_probe.gd` and `r1_visual.gd` are probes, not part of the suite. Tests use `check(cond, msg)` + `push_error` counters; new suites must be added to `test-game.sh` with their marker regex.

Android export is machine-specific (`scripts/export-android.py` depends on the original Mac's SSD/keystore); other environments copy `game/export_presets.cfg.example`. See [docs/development/getting-started.md](docs/development/getting-started.md). APKs/keystores are gitignored; the latest build receipt is `tools/android-build.json`.

## Architecture

The code is layered by version; older layers are kept alive for tests and historical probes, so do not delete them as "dead".

- **Entry scene**: `game/r1_main.tscn` → `scripts/r1_main.gd`, which `extends "res://scripts/main.gd"` and overrides the title/menu flow. `main.gd` (~1000 lines) is the shared base: input (keyboard/mouse and `touch_controls.gd`), HUD, overlays, drawing, pause. `main.tscn` is the older experiment scene still exercised by legacy tests.
- **Run model** (`run_model.gd`): the core headless state — encounter/run state, upgrade pool, XP, win/lose, seeded RNG. `main.gd` drives it each frame; logic is intentionally testable without scenes.
- **Combat** (`nana_combat.gd`): Nana's cone claw, combo → heavy bite, ultimate "夜影解放" (cooldown 40s). `combat_geometry.gd` holds fan/rect-vs-circle hit tests. `nana_encounters.gd`: enemy AI (chaser, charger, thrower, guard, elite, 疾追者) and wave scheduling. `nana_experiment.gd`: fixed-scenario build experiments and behavior logging.
- **Historical modes**: `nana_series.gd` (v0.12–0.13 three-stage series), `nana_growth_run.gd` (v0.14–0.17 four-stage growth short run).
- **v0.20 R1 layer** (`r1_*.gd`): `r1_expedition.gd` (nine-battle chapter state machine, routes/events, save/resume), `r1_growth.gd` (core abilities, formations, talents, XP thresholds, bell treasure interplay), `r1_waves.gd` / `r1_encounters.gd` / `r1_combat.gd` (R1 enemy waves, elites, boss, combat extensions), `r1_profile.gd` (persistent profile/treasure collection save with a backup file and load-failure handling; shares `treasure_collection.gd` from v0.19).
- **Test-only hooks** (invincibility, auto input) live in test code, never in shipped gameplay.

## Repo conventions

- `docs/design/` holds decisions and playtest feedback (`poc-feedback-and-followups.md` is the running log); `docs/development/` holds per-version practice notes (`nana-vX.Y-practice.md`), probe outputs and test receipts. Update the relevant practice note, HANDOFF.md, and README status when shipping a version.
- `scripts/research/` probes are tied to a specific version — read their header comments before interpreting output. Absolute `/Users/...` and `/Volumes/...` paths in reports and receipts are historical and intentional.
- `.gitignore` excludes `game/.godot/`, `game/export_presets.cfg`, `.agents/`, APK/AAB/keystores and builds; never commit those. No license for the project has been chosen — do not add one.
