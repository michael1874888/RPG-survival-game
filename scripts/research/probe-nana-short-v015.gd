extends SceneTree
## Historical v0.15 probe; current schedules changed in v0.16.
## Fixed nearest-enemy controller. Optional NANA_USE_ULT=1 at HP <= 60; no invulnerability.
const Run := preload("res://scripts/run_model.gd")
const Series := preload("res://scripts/nana_series.gd")
var failures := 0
var completed := 0
var stopped := 0

func _initialize() -> void:
	for opening in ["a", "b", "c"]:
		probe(opening, {"kind": "upgrade", "id": opening}, 0)
	print("SHORT V015: completed=%d stopped=%d integrity_failures=%d" % [completed, stopped, failures])
	quit(1 if failures else 0)

func probe(opening: String, first: Dictionary, last_index: int) -> void:
	var run = Run.new()
	var series = Series.new()
	series.begin(run, opening, true)
	var rows: Array[String] = []
	var chosen: Array = []
	while not series.finished:
		var start_hp: float = run.hp
		var steps := 0
		while run.state == "playing" and steps < 4000:
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
			if OS.get_environment("NANA_USE_ULT") == "1" and run.hp <= 60.0 and run.nana.cooldown <= 0.0:
				run.nana.activate_ultimate(run)
			run.tick(1.0 / 30.0, movement, direction, firing)
			run.events.clear()
		var pending: int = run.experiment.schedule.filter(func(event): return event.state not in ["born", "cancelled"]).size()
		if run.state == "playing" or (run.state == "won" and pending > 0):
			failures += 1
			return
		var ult_count: int = run.experiment.timeline.filter(func(event): return event.kind == "ultimate").size()
		series.collect(run)
		var data = JSON.parse_string(FileAccess.get_file_as_string(run.experiment.saved_path))
		if data == null or data.context.results.size() != series.stage + 1: failures += 1
		DirAccess.remove_absolute(run.experiment.saved_path)
		rows.append("E%d:%s %.1fs hp%.0f->%.0f levels=%s cash=%d ult=%d" % [series.stage + 1, run.state, run.elapsed, start_hp, run.hp, JSON.stringify(run.experiment.levels), run.experiment.counts.cash, ult_count])
		if series.between:
			var choice: Dictionary = first if series.stage == 0 else series.choices()[last_index]
			chosen.append(choice)
			if not series.advance(run, choice):
				failures += 1
				return
	if run.state == "won": completed += 1
	else: stopped += 1
	print("open=%s choices=%s | %s | total %.1fs" % [opening, JSON.stringify(chosen), " / ".join(rows), series.total_seconds()])
