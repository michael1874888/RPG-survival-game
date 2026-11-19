extends SceneTree
const Treasure = preload("res://scripts/treasure_collection.gd")
const Run = preload("res://scripts/run_model.gd")
const Series = preload("res://scripts/nana_series.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var path := "user://treasure-test-%d.json" % Time.get_ticks_usec()
	var store = Treasure.new(path)
	check(not store.owned and not store.equipped, "Fresh install has no bell")
	check(store.acquire() and store.owned and not store.equipped, "Acquisition is persisted without automatic equip")
	var reload = Treasure.new(path)
	check(reload.owned and not reload.equipped, "Collection survives reload")
	check(reload.set_equipped(true) and Treasure.new(path).equipped, "Equipment survives reload")
	var old := FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	check(not reload.set_equipped(false) and FileAccess.get_file_as_string(path) == old and reload.equipped, "Failed write preserves disk and active selection")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	check(reload.set_equipped(false) and not Treasure.new(path).equipped, "Unequip survives reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var run = Run.new()
	var series = Series.new()
	check(series.begin(run, "b", true, true, 123, true) and run.growth.bell_equipped, "Bell equipped on B opening")
	check(run.growth.b_branch == "follow" and run.growth.levels.b == 1, "Bell does not grant B2 at start")
	run.state = "upgrade"
	run.growth.offers.assign(["b", "power", "reach"])
	check(run.choose_upgrade("b") and run.growth.levels.b == 2, "Normal upgrade activates bell at B2")
	run.enemies.clear()
	run.encounters.add_enemy(run, "pursuer", run.player + Vector2(100, 0))
	var enemy: Dictionary = run.enemies[0]
	enemy.hp = 200.0
	run.aim = Vector2.RIGHT
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	check(run.nana.follow_target_id == enemy.id, "Bell B2 charged hit marks target")
	var hp: float = enemy.hp
	run.player = Vector2(enemy.pos) - Vector2(100, 0)
	run.nana.attack(run)
	check(is_equal_approx(hp - float(enemy.hp), 20.0), "Bell B2 following claw deals same follow damage")
	run.state = "won"
	check(series.collect(run) and series.advance_growth(run) and run.growth.bell_equipped and run.growth.levels.b == 2, "Bell and growth survive stage transition")
	var valid := true
	for b in [1, 2]:
		for c in [0, 1, 2]:
			for power in 4:
				for reach in 4:
					for vitality in 4:
						var spent: int = b - 1 + c + power + reach + vitality
						if spent > 5: continue
						run.growth.levels = {"b": b}
						if c > 0: run.growth.levels["c"] = c
						run.growth.common = {"power": power, "reach": reach, "vitality": vitality}
						var offered: Array[String] = run.growth.make_offers(spent + 2)
						if offered.size() != 3 or offered[0] == offered[1] or offered[1] == offered[2] or offered[0] == offered[2] or (b == 2 and "b" in offered) or (c == 2 and "c" in offered): valid = false
	check(valid, "All reachable bell configurations offer three different legal cards")
	check(series.begin(run, "a", true, true, 123, true) and not run.growth.bell_equipped, "A opening cannot equip bell")
	check(series.begin(run, "b", true, true, 123, false) and not run.growth.bell_equipped, "Unequipped retry restores standard B growth")
	if not run.experiment.saved_path.is_empty(): DirAccess.remove_absolute(run.experiment.saved_path)
	print("TREASURE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
