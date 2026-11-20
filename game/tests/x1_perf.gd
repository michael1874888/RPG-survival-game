extends SceneTree
## Stress measurement for the presentation layer (needs a window, not headless): keeps 120 enemies
## around Nana, kills them steadily with a wide claw, pounces every 40 frames and fires the night
## shadow whenever it fills, then reports frame-time numbers. Desktop numbers only; phones differ.
## Usage: Godot --path game --script res://tests/x1_perf.gd -- [seconds=10] [effects=high|medium|low]

const Profile := preload("res://scripts/x1/core/profile.gd")

var seconds := 10.0
var effects := "high"
var scene = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("seconds="): seconds = float(arg.substr(8))
		if arg.begins_with("effects="): effects = arg.substr(8)
	call_deferred("measure")


func find_button(node: Node, needle: String) -> Button:
	if node == null: return null
	if node is Button and needle in node.text and not node.disabled: return node
	for child: Node in node.get_children():
		var result := find_button(child, needle)
		if result != null: return result
	return null


func stats(values: Array) -> String:
	if values.is_empty(): return "-"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted: total += float(v)
	return "avg %.2f · p95 %.2f · max %.2f ms" % [total / sorted.size(), float(sorted[int(sorted.size() * 0.95)]), float(sorted[-1])]


func measure() -> void:
	var base := "user://x1-perf-%d" % Time.get_ticks_usec()
	var profile = Profile.new(base + ".save", base + ".r1", base + ".old")
	var next: Dictionary = profile.data.duplicate(true)
	next.settings.effects = effects
	profile.commit(next)
	scene = load("res://x1_main.tscn").instantiate()
	scene.profile = profile
	scene.instant = true
	root.add_child(scene)
	await process_frame
	find_button(scene.overlay, "出發夜巡").pressed.emit()
	await process_frame
	find_button(scene.overlay, "出發！").pressed.emit()
	await process_frame
	find_button(scene.overlay, "狩獵").pressed.emit()
	await process_frame
	scene.set_process(false)
	scene.advance_frame(1.0 / 60.0)
	var b = scene.run.battle
	b.spawning = false
	scene.run.tutorial = false
	b.stats.add_buff("claw_angle", 300.0, 9999.0, "perf")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var logic: Array = []
	var render_cpu: Array = []
	var gpu: Array = []
	var process: Array = []
	var frame_real: Array = []
	var peak_particles := 0
	var last := Time.get_ticks_usec()
	var frames := int(seconds * 60.0)
	for i in frames:
		if scene.screen == "card" and not scene.run.build.offers.is_empty():
			scene.run.choose_card(scene.run.build.offers[0])
			scene._after_card()
		if scene.run.battle == null or scene.screen != "battle": break
		b = scene.run.battle
		b.player.invuln = 1.0
		b.player.hp = float(b.player.max_hp)
		while b.enemies.size() < 120:
			var pos: Vector2 = b.player.pos + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(90.0, 520.0)
			var e: Dictionary = b.spawn_enemy("E01" if rng.randf() < 0.8 else "E02", pos, {})
			e.hp = 14.0
			e.visible_time = 5.0
		if i % 40 == 0: scene.touch.pending_pounce = Vector2.RIGHT.rotated(rng.randf() * TAU)
		if b.ult_ready(): scene.ult_request = true
		var t0 := Time.get_ticks_usec()
		scene.advance_frame(1.0 / 60.0)
		logic.append((Time.get_ticks_usec() - t0) / 1000.0)
		await process_frame
		var now := Time.get_ticks_usec()
		if i > 30:
			frame_real.append((now - last) / 1000.0)
			process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		last = now
		peak_particles = maxi(peak_particles, scene.world.fx.particles.size())
	print("X1 PERF (%s effects, %d frames, window %s)" % [effects, frame_real.size(), str(root.size)])
	print("  simulation + feedback (advance_frame): ", stats(logic))
	print("  process (all _process, incl. above):   ", stats(process))
	print("  render CPU:                            ", stats(render_cpu))
	print("  GPU:                                   ", stats(gpu))
	print("  real frame interval:                   ", stats(frame_real))
	var layers := ""
	for key: String in scene.world.draw_ms: layers += "%s %.2f · " % [key, float(scene.world.draw_ms[key])]
	print("  draw-list build (smoothed ms): ", layers, "hud %.2f" % scene.hud.draw_ms)
	print("  peak particles %d (cap %d), enemies %d" % [peak_particles, scene.world.fx.cap(), scene.run.battle.enemies.size() if scene.run.battle != null else 0])
	quit()
