# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Bramble" (working title): a mobile-first cute-animal survival-action game prototype. Godot **4.7.2 standard (not .NET)**, GDScript, GL Compatibility renderer, landscape 1280×720. Single playable character: the black cat Nana. Docs, design notes and in-game text are written in Traditional Chinese; keep that convention when editing them.

Current version is v0.31.0: the v0.30 "X1 撲擊狩獵" (pounce hunt; three regions, map runs, cards, night ladder, unlocks) redesign approved on 2026-11-20 and built on branch `feature/nana-x1-pounce-hunt`, plus a feel/feedback rework (hit-stop, shake, haptics, procedural animation, effects, generated audio and adaptive music, HUD and UI animation) on branch `feature/x1-feel`. Phone playtest, haptics, performance and fun are not yet validated. The v0.20 "R1" code still ships for regression tests and a debug-only comparison entry. Read [HANDOFF.md](HANDOFF.md) first in a new session — it holds the latest decisions, user feedback and open work, and [docs/README.md](docs/README.md) indexes all docs. [GLOSSARY.md](GLOSSARY.md) defines the project's design terms (構築, 局內升級, etc.).

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

(run `--editor --import --quit` once first on a fresh checkout so `game/.godot/` exists). Suites live in `game/tests/`: legacy `run_tests`, `nana_build_tests`, `nana_series_tests`, `nana_growth_tests`, `treasure_tests`, `scene_flow`, `r1_tests`, `r1_mechanics`, `r1_scene_flow`, and X1 `x1_data_tests`, `x1_combat_tests`, `x1_enemy_tests`, `x1_build_tests`, `x1_run_tests`, `x1_scene_flow`, `x1_feel_tests`, `x1_time_tests`, `x1_audio_tests`. Tests use `check(cond, msg)` + `push_error` counters; new suites must be added to `test-game.sh` with their marker regex. A script with a parse error never calls `quit()` and hangs headless Godot, so wrap ad-hoc runs in a timeout. `x1_helpers.gd` builds controlled battles (spawning off); `x1_bot.gd` is the scripted player.

Dev tools (not in the suite): `x1_autoplay_probe.gd` (whole runs with the bot; pacing numbers, not human results; `-- seeds=3 night=0 region=all`), `x1_visual.gd` (windowed screenshot tour; `--fixed-fps 60 ... -- out=/abs/dir`, add `--resolution 1600x720` for 20:9), `x1_record.gd` (windowed contact sheets of key feedback moments; needs `--fixed-fps 60` or effects look twice as long on a 120 Hz screen), `x1_perf.gd` (windowed stress: 120 enemies, prints logic/draw/render ms; `-- seconds=10 effects=high`), `python3 -B scripts/x1-content-table.py` (regenerates `docs/design/nana-x1-content.md` from the JSON — run it after data changes), `python3 -B scripts/x1-make-audio.py` (regenerates all WAVs in `game/assets/audio/x1/`, fixed seeds, stdlib only). In a debug build, F5 reloads the JSON and restarts the current battle; F3 toggles the frame-time overlay.

Android export is machine-specific (`scripts/export-android.py` depends on the original Mac's SSD/keystore); other environments copy `game/export_presets.cfg.example` (it must keep `data/x1/*.json` in `include_filter` and the vibrate permission). `scripts/verify-packaged-nana.py` copies the compiled scripts and data out of the APK and runs legacy and X1 rule checks on them. See [docs/development/getting-started.md](docs/development/getting-started.md). APKs/keystores are gitignored; the latest build receipt is `tools/android-build.json`.

## Architecture

The code is layered by version; older layers are kept alive for tests and historical probes, so do not delete them as "dead".

### X1 (current, `game/x1_main.tscn` is the main scene)

- **Data-driven**: every number and all content live in `game/data/x1/*.json` (tuning, enemies, spawns, regions, cards, habits, items, events, shop, night_levels, unlocks, and `feel` for all feedback: cues per event, particles, haptic patterns, sounds, music). `scripts/x1/core/data.gd` loads them once (`Data.shared()`) and `validate()` cross-checks references; the allowed stat names, hooks, actions, AIs and counters are the constant lists at its top. Do not hard-code tuning values in scripts. [docs/development/x1-tuning-guide.md](docs/development/x1-tuning-guide.md) maps feel → file/key.
- **Rules (`scripts/x1/core/`, no rendering)**: `battle.gd` is one fight stepped at a fixed tick with `step(dt, {move, pounce, ult})` — auto claw, pounce dash + landing bite, kill-charged night shadow, damage multipliers, hurt queue (largest hit per step), net (收網) and win/lose. `spawner.gd` streams off-screen fodder and warned specials/prey/elites/boss. `effects.gd` + `effect_actions.gd` run card/habit/item triggers ("on hook, do action") with a depth cap; `stats.gd` sums stat effects and timed buffs. `build.gd` holds cards (6 slots, Lv.1–3, evolutions), offers and rerolls. `map_gen.gd` builds the 7-layer map. `run.gd` is the whole patrol (map, nodes, level-ups, rewards, shop, events, result). `profile.gd` + `save_store.gd` persist everything with a hashed, verified write and a backup; `progress.gd` applies counters and unlocks.
- **Determinism**: separate RNG streams (`rng_streams.gd`: map, spawn, combat, cards, loot, events). Every state object has `to_dict`/`from_dict`; a restored `Run` must continue byte-identically (tested). Restoring must not consume random numbers. Hit-stop and slow motion are presentation only (`present/time_controller.gd` decides how many fixed 1/60 s steps run per frame); never put them back in the rules.
- **Enemies**: `scripts/x1/ai/*.gd` are static `update(b, e, dt)` behaviours registered in `battle.gd`'s `AI` table; `common.gd` provides warned phases (`start()` sets `e.tele`, which the renderer draws), dashes and boss phases. Fairness rules (visible before attacking, special-attack concurrency, safe spawn distance, night levels never shorten warnings) are enforced in `battle.gd`/`spawner.gd`.
- **Presentation**: `scripts/x1_main.gd` is the screen state machine (title, setup, map, battle, card, bed, shop, moon, item, result, collection, settings) and owns input and save points; `advance_frame(delta)` runs the time controller's steps, feeds each step's battle events to the feedback director, then presents. `scripts/x1/present/`: `feedback_director.gd` maps events to `feel.json` cues and dispatches them to `time_controller`, `camera_rig`, `world_view` (layered Node2D: ground, entities, effects, additive glow, top layer for warnings/markers/words), `fx.gd` (particles, rings, words, damage numbers), `looks.gd`/`nana_rig.gd` (procedural characters), `hud.gd`, `audio_director`/`music_director` and `haptics`; it also keeps the combo count. Battle events carry the extra fields the presentation needs (enemy id/role, `shown` damage, hurt source position); the enemy kind is `enemy`, because `kind` is the event name. In the Compatibility renderer every polygon/circle/arc/anti-aliased line allocates a vertex buffer per call, so shapes drawn many times per frame use `Looks.ellipse`/`disc` (tinted disc texture) and `Looks.poly` (`draw_primitive`). `ui/theme.gd` (imported as `UI`, since `Theme` is a native class name) builds widgets, with a static button press hook that `x1_main` clears in `_exit_tree` (a static lambda left alive crashed headless runs at exit); `ui/touch_input.gd` maps two thumbs (right thumb: drag then release to pounce, release inside the deadzone cancels); `ui/wipe.gd`, `ui/map_view.gd`, `ui/chest_icon.gd` are the transition, map and chest widgets.

### Earlier versions (kept for regression tests)

- `r1_main.tscn` → `r1_main.gd` extends `main.gd` (v0.20 R1 expedition); `run_model.gd`, `nana_combat.gd`, `nana_encounters.gd`, `nana_experiment.gd`, `nana_series.gd`, `nana_growth_run.gd` are v0.5–v0.17 layers. `combat_geometry.gd` is shared with X1. X1's profile reads (never writes) the v0.20 save to migrate owned items.
- **Test-only hooks** (invincibility, auto input) live in test code, never in shipped gameplay.

## Repo conventions

- `docs/design/` holds decisions and playtest feedback (`poc-feedback-and-followups.md` is the running log); `docs/development/` holds per-version practice notes (`nana-vX.Y-practice.md`), probe outputs and test receipts. Update the relevant practice note, HANDOFF.md, and README status when shipping a version.
- `scripts/research/` probes are tied to a specific version — read their header comments before interpreting output. Absolute `/Users/...` and `/Volumes/...` paths in reports and receipts are historical and intentional.
- `.gitignore` excludes `game/.godot/`, `game/export_presets.cfg`, `.agents/`, APK/AAB/keystores and builds; never commit those. No license for the project has been chosen — do not add one.
