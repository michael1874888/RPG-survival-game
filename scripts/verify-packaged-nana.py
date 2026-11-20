#!/usr/bin/env python3
"""Exercise Nana's compiled rules extracted from the verified local APK."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile


PROJECT = Path(__file__).resolve().parent.parent
GODOT = Path('/Applications/Godot.app/Contents/MacOS/Godot')
CONTROLLER = Path('/Users/junming/AI-Setup/storage/storagectl.py')
CHECK = '''extends SceneTree
const Run = preload("res://scripts/run_model.gd")
const Series = preload("res://scripts/nana_series.gd")
const Treasure = preload("res://scripts/treasure_collection.gd")
const ExpeditionR1 = preload("res://scripts/r1_expedition.gd")
const ProfileR1 = preload("res://scripts/r1_profile.gd")

func _initialize():
 var run = Run.new(99, "nana")
 run.player = Vector2(500, 500)
 var enemy = {"id": 1, "pos": Vector2(600, 500), "hp": 1000.0, "max_hp": 1000.0,
   "kind": "chaser", "radius": 10.0, "speed": 0.0, "phase": "chase",
   "timer": 0.0, "dir": Vector2.ZERO, "flash": 0.0}
 run.enemies.assign([enemy])
 for i in 3: run.nana.attack(run)
 if run.nana.bite_charge != 3: quit(1); return
 run.nana.attack(run)
 run.nana.advance(run, 0.11)
 if enemy["hp"] != 946.0 or not run.nana.activate_ultimate(run): quit(1); return
 if enemy["hp"] != 931.0 or run.nana.cooldown != 40.0 or run.nana.ultimate_remaining != 6.0: quit(1); return
 run.pause()
 run.tick(2.0, Vector2.ZERO, Vector2.ZERO, false)
 if run.nana.cooldown != 40.0 or run.nana.ultimate_remaining != 6.0: quit(1); return
 run.reset(99, "nana", "standard", "nana_mixed")
 if run.enemies.size() != 6: quit(1); return
 var kinds = []
 for item in run.enemies:
  if item.kind not in kinds: kinds.append(item.kind)
 if kinds.size() != 4: quit(1); return
 run.reset(99, "nana", "standard", "nana_growth")
 if run.fixed_abilities or not run.drop_xp: quit(1); return
 run.level = 4
 run.make_offers()
 if "sweep" not in run.offers or "hunt" not in run.offers: quit(1); return
 run.state = "upgrade"
 if not run.choose_upgrade("sweep"): quit(1); return
 run.encounters.add_enemy(run, "elite", run.player + Vector2(150, 0))
 var elite = run.enemies[0]
 elite.phase = "windup"
 elite.timer = 0.01
 run.encounters.update(run, 0.02)
 if elite.phase != "second_wait": quit(1); return
 run.reset(99, "nana", "standard", "nana_compare_guard")
 if run.enemies.size() != 3: quit(1); return
 run.enemies.clear()
 run.upgrades.sweep = 1
 run.encounters.add_enemy(run, "guard", run.player + Vector2(-100, 0))
 var rear = run.enemies[0]
 for i in 3: run.nana.attack(run)
 if rear.hp != 80.0: quit(1); return
 run.reset(99, "nana", "standard", "nana_compare_guard")
 run.enemies.clear()
 run.upgrades.hunt = 1
 run.encounters.add_enemy(run, "guard", run.player + Vector2(100, 0))
 run.encounters.add_enemy(run, "guard", run.player + Vector2(110, 0))
 run.nana.attack(run)
 if run.enemies[0].hp != 76.0 or run.enemies[1].hp != 90.0: quit(1); return
 run.reset(99, "nana", "standard", "nana_pressure_dense")
 if not run.fixed_abilities or run.drop_xp: quit(1); return
 run.tick(1.1, Vector2.ZERO, Vector2.RIGHT, false)
 if run.encounters.pending_spawns.size() != 3: quit(1); return
 run.upgrades.hunt = 1
 run.hunt_variant = "fast"
 if not is_equal_approx(run.nana.attack(run), 0.28): quit(1); return
 run.hunt_variant = "heavy"
 if not is_equal_approx(run.nana.attack(run), 0.42): quit(1); return
 run.reset(99, "nana", "standard", "nana_pressure_standard")
 run.tick(1.1, Vector2.ZERO, Vector2.RIGHT, false)
 if run.encounters.pending_spawns.size() != 1: quit(1); return
 run.reset(99, "nana", "standard", "nana_build_e3")
 run.experiment.configure(run, ["a", "c"])
 if run.experiment.schedule.size() != 34 or run.experiment.abilities.size() != 2: quit(1); return
 run.encounters.add_enemy(run, "guard", run.player + Vector2(100, 0))
 var target = run.enemies[0]
 target.hp = 1000.0
 for i in 7:
  run.nana.attack(run)
  run.nana.advance(run, 0.13)
  run.elapsed += 0.42
 if run.experiment.counts.shadow != 2 or run.experiment.counts.cash != 1: quit(1); return
 run.reset(99, "nana", "standard", "nana_build_e1")
 run.experiment.configure(run, ["b"])
 run.nana.movement_charge = 260.0
 run.nana.attack(run)
 if run.nana.movement_charge != 260.0: quit(1); return
 run.encounters.add_enemy(run, "chaser", run.player + Vector2(100, 0))
 run.nana.attack(run)
 if run.nana.movement_charge != 0.0 or run.enemies[0].hp > 0.0: quit(1); return
 run.reset(99, "nana", "standard", "nana_build_e1")
 run.experiment.configure(run, ["a"])
 run.encounters.add_enemy(run, "guard", run.player + Vector2(80, 60))
 var side = run.enemies[0]
 side.hp = 1000.0
 run.nana.pending_shadows.append({"remaining": 0.01, "pos": run.player, "dir": Vector2.RIGHT})
 run.nana.advance(run, 0.02)
 if side.hp != 992.0: quit(1); return
 run.nana.bite_charge = 3
 run.nana.attack(run)
 run.aim = Vector2.DOWN
 var preview = run.nana.bite_target(run, 175.0, deg_to_rad(27.5))
 if preview.is_empty() or int(preview.id) != int(side.id): quit(1); return
 var series = Series.new()
 if not series.begin(run, "b") or run.experiment.abilities != ["b"]: quit(1); return
 run.hp = 50.0
 run.nana.cooldown = 20.0
 run.state = "won"
 if not series.collect(run): quit(1); return
 var record_path = run.experiment.saved_path
 if not series.advance(run, {"kind": "add", "id": "a"}) or run.hp != 75.0 or run.nana.cooldown != 20.0: quit(1); return
 if run.scenario_id != "nana_build_e2": quit(1); return
 run.state = "won"
 if not series.collect(run): quit(1); return
 var record_path2 = run.experiment.saved_path
 if not series.advance(run, {"kind": "upgrade", "id": "b"}) or int(run.experiment.levels.b) != 2: quit(1); return
 if not record_path.is_empty(): DirAccess.remove_absolute(record_path)
 if not record_path2.is_empty(): DirAccess.remove_absolute(record_path2)
 if not series.begin(run, "b", true) or run.scenario_id != "nana_build_s1" or series.stages().size() != 4: quit(1); return
 for stage in 4:
  if run.scenario_id != series.stages()[stage]: quit(1); return
  if stage == 2:
   for step in 60: run.tick(1.0 / 30.0, Vector2.ZERO, Vector2.RIGHT, false)
   if not run.enemies.any(func(e): return e.kind == "chaser" and e.max_hp == 32.0): quit(1); return
  if stage == 1 and not run.experiment.schedule.any(func(e): return e.kind == "thrower" and e.at == 4.0): quit(1); return
  if stage == 3 and not run.experiment.schedule.any(func(e): return e.kind == "elite" and e.at == 10.0): quit(1); return
  run.state = "won"
  if not series.collect(run): quit(1); return
  if not run.experiment.saved_path.is_empty(): DirAccess.remove_absolute(run.experiment.saved_path)
  if stage < 3 and not series.advance(run, series.choices()[0]): quit(1); return
 if not series.finished or series.results.size() != 4: quit(1); return
 run.reset(0, "nana", "standard", "nana_chasers")
 run.enemies.clear()
 run.player = Vector2(1600, 900)
 run.encounters.add_enemy(run, "pursuer", run.player + Vector2(150, 0))
 var pursuer = run.enemies[0]
 var start_distance = Vector2(pursuer.pos).distance_to(run.player)
 for step in 60: run.tick(1.0 / 30.0, Vector2.LEFT, Vector2.RIGHT, false)
 if Vector2(pursuer.pos).distance_to(run.player) >= start_distance - 30.0 or run.player.x <= 30.0: quit(1); return
 run.reset(0, "nana", "standard", "nana_build_s1")
 run.experiment.configure(run, ["b"], {"levels": {"b": 2}})
 run.encounters.add_enemy(run, "pursuer", run.player + Vector2(150, 0))
 pursuer = run.enemies[0]
 var initial_x = pursuer.pos.x
 run.nana.movement_charge = 260.0
 run.nana.attack(run)
 if not is_equal_approx(pursuer.hp, 26.0) or pursuer.pos.x <= initial_x + 60.0: quit(1); return
 var pushed_x = pursuer.pos.x
 if not run.nana.activate_ultimate(run) or pursuer.pos.x <= pushed_x + 70.0: quit(1); return
 run.reset(99, "nana", "standard", "nana_build_e3")
 run.experiment.configure(run, ["b", "c"])
 run.encounters.add_enemy(run, "guard", run.player + Vector2(100, 0))
 var marked = run.enemies[0]
 marked.hp = 1000.0
 run.nana.prey_id = int(marked.id)
 run.nana.prey_remaining = -1.0
 run.nana.advance(run, 6.0)
 if not run.nana.has_prey(): quit(1); return
 run.nana.movement_charge = 260.0
 run.nana.attack(run)
 if run.nana.bite_charge != 3: quit(1); return
 run.nana.attack(run)
 run.nana.advance(run, 0.11)
 if run.experiment.counts.cash != 1: quit(1); return
 if not series.begin(run, "a", true, true) or run.growth == null or not run.drop_xp: quit(1); return
 run.xp = 32
 run.maybe_level_up()
 if run.state != "upgrade" or "a" not in run.offers or not run.choose_upgrade("a"): quit(1); return
 if run.level != 3 or run.state != "upgrade" or not run.choose_upgrade(run.offers[0]): quit(1); return
 if run.state != "playing" or run.growth.decisions.size() != 2: quit(1); return
 run.state = "won"
 if not series.collect(run) or not series.advance_growth(run) or run.level != 3: quit(1); return
 if not run.experiment.saved_path.is_empty(): DirAccess.remove_absolute(run.experiment.saved_path)
 if not series.begin(run, "b", true, true): quit(1); return
 run.growth.levels = {"b": 2}
 run.experiment.levels = {"b": 2}
 run.state = "upgrade"
 run.growth.offers.assign(["b", "power", "reach"])
 if not run.choose_upgrade("b_follow") or run.growth.b_branch != "follow": quit(1); return
 run.enemies.clear()
 run.encounters.add_enemy(run, "pursuer", run.player + Vector2(100, 0))
 var follow_target = run.enemies[0]
 follow_target.hp = 200.0
 run.aim = Vector2.RIGHT
 run.nana.movement_charge = 260.0
 run.nana.attack(run)
 if run.nana.follow_target_id != follow_target.id: quit(1); return
 run.player = Vector2(follow_target.pos) - Vector2(100, 0)
 var before_follow = follow_target.hp
 run.nana.attack(run)
 if not is_equal_approx(before_follow - follow_target.hp, 20.0) or run.nana.follow_target_id != -1: quit(1); return
 run.state = "won"
 if not series.collect(run) or not series.advance_growth(run) or run.growth.b_branch != "follow": quit(1); return
 if not run.experiment.saved_path.is_empty(): DirAccess.remove_absolute(run.experiment.saved_path)
 var treasure_path = "user://packaged-bell-test-%d.json" % Time.get_ticks_usec()
 var treasure = Treasure.new(treasure_path)
 if treasure.owned or not treasure.acquire() or not treasure.set_equipped(true) or not Treasure.new(treasure_path).equipped: quit(1); return
 DirAccess.remove_absolute(ProjectSettings.globalize_path(treasure_path))
 if not series.begin(run, "b", true, true, 99, true) or not run.growth.bell_equipped: quit(1); return
 run.state = "upgrade"
 run.growth.offers.assign(["b", "power", "reach"])
 if not run.choose_upgrade("b") or run.growth.levels.b != 2: quit(1); return
 run.enemies.clear()
 run.encounters.add_enemy(run, "pursuer", run.player + Vector2(100, 0))
 follow_target = run.enemies[0]
 follow_target.hp = 200.0
 run.aim = Vector2.RIGHT
 run.nana.movement_charge = 260.0
 run.nana.attack(run)
 if run.nana.follow_target_id != follow_target.id: quit(1); return
 var r1 = ExpeditionR1.new()
 var current = Run.new()
 r1.begin(current, "b", 99, "H03", "U01", false)
 if current.experiment.schedule.size() != 18 or current.growth.formed("b"): quit(1); return
 current.state = "upgrade"
 current.growth.offers.assign(["b", "power", "reach"])
 current.offers.assign(current.growth.offers)
 if not current.choose_upgrade("b") or not current.growth.formed("b"): quit(1); return
 current.encounters.add_enemy(current, "guard", current.player + Vector2(70, 0))
 var r1_target = current.enemies[0]
 r1_target.hp = 200.0
 current.aim = Vector2.RIGHT
 current.nana.movement_charge = 260.0
 current.nana.attack(current)
 if current.nana.follow_target_id != r1_target.id: quit(1); return
 var saved = r1.snapshot(current)
 var resumed = ExpeditionR1.new()
 var resumed_run = Run.new()
 if not resumed.restore(resumed_run, saved) or resumed_run.state != "paused" or not resumed_run.growth.formed("b"): quit(1); return
 var profile_path = "user://packaged-r1-test-%d" % Time.get_ticks_usec()
 var profile = ProfileR1.new(profile_path, profile_path + ".legacy")
 if not profile.acquire("H03", saved) or not ProfileR1.new(profile_path, profile_path + ".legacy").data.owned.has("H03"): quit(1); return
 for suffix in ["", ".bak", ".tmp", ".bak.tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path + suffix))
 print("PACKAGED NANA RULES: legacy combat and R1 expedition, early bell, snapshot and collection passed")
 quit(0)
'''


CHECK_X1 = '''extends SceneTree
const Data = preload("res://scripts/x1/core/data.gd")
const Rng = preload("res://scripts/x1/core/rng_streams.gd")
const Battle = preload("res://scripts/x1/core/battle.gd")
const Run = preload("res://scripts/x1/core/run.gd")
const Profile = preload("res://scripts/x1/core/profile.gd")

func _initialize():
 var data = Data.shared()
 if not data.errors.is_empty() or data.card_list.size() != 48 or data.evolutions.size() != 8 or data.regions.size() != 3: quit(1); return
 var rngs = Rng.new()
 rngs.setup(5)
 var b = Battle.new()
 b.setup({"region": "courtyard", "kind": "hunt", "entries": [{"id": "habit", "effects": data.habits.roam.effects, "level": 1}]}, rngs, null)
 b.spawning = false
 var start = b.player.pos
 var target = b.spawn_enemy("E05", start + Vector2(270, 0), {})
 target.hp = 900.0
 b.claw_timer = 99.0
 b.step(1.0 / 60.0, {"pounce": Vector2.RIGHT})
 for i in 20: b.step(1.0 / 60.0, {})
 if absf(b.player.pos.x - start.x - 230.0) > 2.0 or target.hp > 870.0: quit(1); return
 b.add_meter(100.0)
 b.step(1.0 / 60.0, {"ult": true})
 if not b.ult_active(): quit(1); return
 var run = Run.new()
 run.begin({"seed": 11, "region": "belltower", "habit": "hunt"})
 if run.map.rows.size() != 7 or not run.enter(run.available_nodes()[0]) or run.battle == null: quit(1); return
 for i in 600: run.tick(1.0 / 60.0, {"move": Vector2.RIGHT.rotated(i * 0.02)})
 var copy = Run.new()
 if not copy.from_dict(bytes_to_var(var_to_bytes(run.to_dict()))) or copy.battle == null: quit(1); return
 var path = "user://packaged-x1-test-%d" % Time.get_ticks_usec()
 var profile = Profile.new(path + ".save", path + ".r1", path + ".old")
 if not profile.save_active(run.to_dict()) or Profile.new(path + ".save").data.active.is_empty(): quit(1); return
 for suffix in [".save", ".save.bak", ".save.tmp", ".save.bak.tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
 print("PACKAGED X1 RULES: data, pounce, night shadow, map, battle, snapshot and profile passed")
 quit(0)
'''


def main():
    receipt = json.loads((PROJECT / 'tools/android-build.json').read_text())
    root = Path(subprocess.check_output([
        'python3', '-B', CONTROLLER, 'path', 'artifacts', '--project',
        'codex/RPG_Game_Dev'], text=True).strip())
    apk = Path(receipt['path'])
    apk.resolve().relative_to(root.resolve())
    digest = hashlib.sha256()
    with apk.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    actual_hash = digest.hexdigest()
    if actual_hash != receipt['sha256']:
        raise SystemExit('APK does not match the recorded SHA-256')
    with tempfile.TemporaryDirectory(prefix='nana-apk-check-') as temp_dir:
        temp = Path(temp_dir)
        (temp / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="APK check"\n')
        (temp / 'check.gd').write_text(CHECK)
        with zipfile.ZipFile(apk) as archive:
            remap = re.search(r'^path="res://([^"]+)"$', archive.read('assets/x1_main.tscn.remap').decode(), re.M)
            if (not remap or 'assets/' + remap.group(1) not in archive.namelist()
                    or b'res://x1_main.tscn' not in archive.read('assets/project.binary')):
                raise RuntimeError('The X1 startup scene or its remap is missing from the APK')
            names = archive.namelist()
            # v0.31 feel layer: presentation scripts, feel data, and the baked sound effects and music.
            present = [n for n in names if n.startswith('assets/scripts/x1/present/')]
            music = [n for n in names if n.startswith('assets/assets/audio/x1/music/') and n.endswith('.import')]
            sfx = [n for n in names if n.startswith('assets/assets/audio/x1/sfx/') and n.endswith('.import')]
            samples = [n for n in names if n.startswith('assets/.godot/imported/') and n.endswith('.sample')]
            if 'assets/data/x1/feel.json' not in names or len(present) < 10:
                raise RuntimeError('The feel data or presentation scripts are missing from the APK')
            if len(music) < 12 or len(sfx) < 49 or len(samples) < len(music) + len(sfx):
                raise RuntimeError('Audio is missing from the APK: %d music, %d sfx, %d samples' % (len(music), len(sfx), len(samples)))
            print('PACKAGED FEEL: %d presentation scripts, %d music files, %d sound files' % (len(present), len(music), len(sfx)))
            copied = 0
            for entry in archive.namelist():
                if not (entry.startswith('assets/scripts/') or entry.startswith('assets/data/')):
                    continue
                if entry.endswith('/'):
                    continue
                target = temp / entry[len('assets/'):]
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(archive.read(entry))
                copied += 1
            if copied < 60 or not (temp / 'data/x1/cards.json').exists():
                raise RuntimeError('Too few compiled scripts or data files in the APK: %d' % copied)
        (temp / 'check_x1.gd').write_text(CHECK_X1)
        for script, marker in (('res://check.gd', 'PACKAGED NANA RULES:'), ('res://check_x1.gd', 'PACKAGED X1 RULES:')):
            result = subprocess.run([GODOT, '--headless', '--path', temp, '--script', script],
                                    check=True, text=True, capture_output=True, timeout=300)
            output = result.stdout + result.stderr
            if 'SCRIPT ERROR' in output or marker not in output or ' passed' not in output:
                raise RuntimeError('Packaged rule check did not complete successfully:\n' + output)
            print([line for line in output.splitlines() if marker in line][0])

if __name__ == '__main__':
    main()
