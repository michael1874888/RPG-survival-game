extends SceneTree
## Pressure probe: NANA_STAND=1 holds position and fires right; default moves toward nearest.
## No invulnerability or ultimate. One deterministic controller per mode.
const Run := preload("res://scripts/run_model.gd")
const CONFIGS := [[], ["a"], ["b"], ["c"], ["a", "b"], ["a", "c"], ["b", "c"]]

func _initialize() -> void:
	for scenario in ["nana_build_e1", "nana_build_e2", "nana_build_e3"]:
		for config in CONFIGS:
			probe(scenario, config)
	quit()

func probe(scenario: String, config: Array) -> void:
	var run = Run.new(992, "nana", "standard", scenario)
	run.experiment.configure(run, config, {"legacy_c": OS.get_environment("NANA_LEGACY_C") == "1"})
	var steps := 0
	var empty := 0.0
	var mixed := 0.0
	var close_threat := 0.0
	var max_live := 0
	while run.state == "playing" and steps < 3000:
		steps += 1
		var nearest: Dictionary = {}
		var best := INF
		var kinds: Dictionary = {}
		var live := 0
		for enemy: Dictionary in run.enemies:
			if float(enemy.hp) <= 0.0: continue
			live += 1
			kinds[enemy.kind] = true
			var distance: float = Vector2(enemy.pos).distance_to(run.player)
			if distance < best:
				best = distance
				nearest = enemy
		max_live = maxi(max_live, live)
		var movement := Vector2.ZERO
		var direction: Vector2 = run.aim
		var firing := false
		if not nearest.is_empty():
			direction = (Vector2(nearest.pos) - run.player).normalized()
			var charging: bool = "b" in config and fmod(run.elapsed, 7.0) >= 4.8 and run.nana.movement_charge < 260.0
			if charging:
				movement = -direction
			elif best > 115.0:
				movement = direction
			elif best < 85.0:
				movement = -direction
			else:
				movement = direction.rotated(PI * 0.5) * 0.35
			firing = not charging and best <= 170.0
		if OS.get_environment("NANA_STAND") == "1":
			movement = Vector2.ZERO
			direction = Vector2.RIGHT
			firing = true
		if OS.get_environment("NANA_USE_ULT") == "1" and run.hp <= 60.0 and run.nana.cooldown <= 0.0:
			run.nana.activate_ultimate(run)
		var before: float = run.elapsed
		run.tick(1.0 / 30.0, movement, direction, firing)
		var elapsed: float = run.elapsed - before
		if live == 0: empty += elapsed
		if kinds.size() >= 2: mixed += elapsed
		if live > 0 and best <= 390.0: close_threat += elapsed
		if run.events.size() > 0: run.events.clear()
	var born := 0
	var cancelled := 0
	var pending := 0
	for event: Dictionary in run.experiment.schedule:
		if event.state == "born": born += 1
		elif event.state == "cancelled": cancelled += 1
		else: pending += 1
	var names: String = "+".join(config) if not config.is_empty() else "base"
	print("%s %-5s state=%-10s time=%5.1f hp=%5.1f kills=%2d born=%2d cancel=%2d pending=%2d max=%2d empty=%.1f%% mixed=%.1f%% close=%.1f%% A=%d/%d B=%d/%d C=%d/%d" % [
		scenario, names, run.state, run.elapsed, run.hp, run.kills, born, cancelled, pending, max_live,
		100.0 * empty / maxf(run.elapsed, 0.001), 100.0 * mixed / maxf(run.elapsed, 0.001),
		100.0 * close_threat / maxf(run.elapsed, 0.001), run.experiment.counts.shadow,
		run.experiment.counts.shadow_hits, run.experiment.counts.charged,
		run.experiment.counts.charged_hits, run.experiment.counts.mark, run.experiment.counts.cash])
