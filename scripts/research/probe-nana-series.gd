extends SceneTree
## Historical v0.12 probe: run with the v0.12 packaged scripts, not the v0.13 rules/API.
const Run := preload("res://scripts/run_model.gd")
const Series := preload("res://scripts/nana_series.gd")
var failures := 0

func _initialize() -> void:
	for opening in ["a", "b", "c"]:
		for second in [["a", "b"], ["a", "c"], ["b", "c"]]:
			if opening not in second: continue
			for third in [["a", "b"], ["a", "c"], ["b", "c"]]:
				probe(opening, second, third)
	print("SERIES PROBE: 18 paths, %d integrity failures" % failures)
	quit(1 if failures else 0)

func probe(opening: String, second: Array, third: Array) -> void:
	var run = Run.new()
	var series = Series.new()
	series.begin(run, opening)
	var rows: Array[String] = []
	while not series.finished:
		var start_hp: float = run.hp
		var steps := 0
		while run.state == "playing" and steps < 3000:
			steps += 1
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
			run.tick(1.0 / 30.0, movement, direction, firing)
			run.events.clear()
		var pending: int = run.experiment.schedule.filter(func(event): return event.state not in ["born", "cancelled"]).size()
		if run.state == "playing" or (run.state == "won" and pending > 0):
			failures += 1
			return
		series.collect(run)
		var data = JSON.parse_string(FileAccess.get_file_as_string(run.experiment.saved_path))
		if data == null or data.context.results.size() != series.stage + 1: failures += 1
		DirAccess.remove_absolute(run.experiment.saved_path)
		rows.append("E%d:%s %.1fs hp%.0f->%.0f C%d" % [series.stage + 1, run.state, run.elapsed, start_hp, run.hp, run.experiment.counts.cash])
		if series.between and not series.advance(run, second if series.stage == 0 else third):
			failures += 1
			return
	print("%s -> %s -> %s | %s | total %.1fs" % [opening, "+".join(second), "+".join(third), " / ".join(rows), series.total_seconds()])
