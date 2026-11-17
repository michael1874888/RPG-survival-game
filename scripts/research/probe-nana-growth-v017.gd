extends SceneTree
## Fixed nearest-enemy controller; protected mode measures progression, not player difficulty.
const Run := preload("res://scripts/run_model.gd")
const Series := preload("res://scripts/nana_series.gd")
func _initialize() -> void:
	print("v0.17 fixed controller, 30 Hz; protected=1 is test-only invulnerability")
	for protected in [false, true]:
		for opening in ["a", "b", "c"]: probe(opening, protected)
	for opening in ["a", "b"]: probe(opening, true, false)
	quit(0)
func probe(opening: String, protected: bool, allow_c: bool = true) -> void:
	var run = Run.new()
	var series = Series.new()
	series.begin(run, opening, true, true, 1701)
	var rows: Array[String] = []
	var max_steps := 25000
	var steps := 0
	while not series.finished and steps < max_steps:
		if run.state == "upgrade":
			var choice: String = opening if opening in run.offers else ""
			if choice.is_empty():
				for option: String in run.offers:
					if allow_c or option != "c":
						choice = option
						break
			if choice.is_empty(): choice = str(run.offers[0])
			if not run.choose_upgrade(choice):
				print("ERROR could not choose ", choice)
				quit(1)
				return
			continue
		if run.state in ["won", "lost", "unfinished"]:
			var guardian_rows: Array = run.experiment.timeline.filter(func(e): return e.kind == "guardian_wave")
			var guardian_times: Array = guardian_rows.map(func(e): return {"threshold": e.threshold, "time": e.time, "scheduled": e.at})
			var row := "S%d %s %.1fs hp%.0f lv%d xp%d build=%s guardian=%s" % [series.stage + 1, run.state, run.elapsed, run.hp, run.level, run.growth.total_xp, JSON.stringify(run.growth.levels), JSON.stringify(guardian_times)]
			series.collect(run)
			rows.append(row)
			if not run.experiment.saved_path.is_empty(): DirAccess.remove_absolute(run.experiment.saved_path)
			if series.between: series.advance_growth(run)
			continue
		steps += 1
		if protected: run.invulnerability = 2.0
		var nearest: Dictionary = {}
		var best := INF
		for enemy: Dictionary in run.enemies:
			if float(enemy.hp) <= 0.0: continue
			var distance: float = Vector2(enemy.pos).distance_to(run.player)
			if distance < best:
				best = distance
				nearest = enemy
		var movement := Vector2.ZERO
		var direction: Vector2 = run.aim
		var firing := false
		if not nearest.is_empty():
			direction = (Vector2(nearest.pos) - run.player).normalized()
			var charging: bool = "b" in run.experiment.abilities and fmod(run.elapsed, 7.0) >= 4.8 and run.nana.movement_charge < 260.0
			if charging: movement = -direction
			elif best > 115.0: movement = direction
			elif best < 85.0: movement = -direction
			else: movement = direction.rotated(PI * 0.5) * 0.35
			firing = not charging and best <= 170.0
		if run.hp <= 60.0 and run.nana.cooldown <= 0.0: run.nana.activate_ultimate(run)
		run.tick(1.0 / 30.0, movement, direction, firing)
		run.events.clear()
	if steps >= max_steps:
		print("ERROR probe step limit")
		quit(1)
		return
	var choices: Array = run.growth.decisions.map(func(x): return "%s@%s:%.1f" % [x.id, x.stage, x.time])
	print("opening=%s protected=%s allow_c=%s | %s | choices=%s" % [opening, protected, allow_c, " / ".join(rows), JSON.stringify(choices)])
