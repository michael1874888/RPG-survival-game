#!/usr/bin/env python3
"""Exercise Nana's compiled rules extracted from the verified local APK."""

import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile


PROJECT = Path(__file__).resolve().parent.parent
GODOT = Path('/Applications/Godot.app/Contents/MacOS/Godot')
CONTROLLER = Path('/Users/junming/AI-Setup/storage/storagectl.py')
CHECK = '''extends SceneTree
const Run = preload("res://scripts/run_model.gd")
const Series = preload("res://scripts/nana_series.gd")

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
 print("PACKAGED NANA RULES: combat, four-stage short run and pursuer chase/push passed")
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
        (temp / 'scripts').mkdir()
        (temp / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="APK check"\n')
        (temp / 'check.gd').write_text(CHECK)
        with zipfile.ZipFile(apk) as archive:
            for name in ('run_model.gdc', 'run_model.gd.remap',
                         'nana_experiment.gdc', 'nana_experiment.gd.remap',
                         'nana_series.gdc', 'nana_series.gd.remap',
                         'nana_combat.gdc', 'nana_combat.gd.remap',
                         'nana_encounters.gdc', 'nana_encounters.gd.remap',
                         'combat_geometry.gdc', 'combat_geometry.gd.remap'):
                (temp / 'scripts' / name).write_bytes(archive.read('assets/scripts/' + name))
        result = subprocess.run([GODOT, '--headless', '--path', temp, '--script', 'res://check.gd'],
                                check=True, text=True, capture_output=True)
        output = result.stdout + result.stderr
        if 'SCRIPT ERROR' in output or 'PACKAGED NANA RULES:' not in output or ' passed' not in output:
            raise RuntimeError('Packaged rule check did not complete successfully:\n' + output)
        print(output.strip())


if __name__ == '__main__':
    main()
