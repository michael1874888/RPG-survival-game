extends SceneTree

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("exercise_scene")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func exercise_scene() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(scene.screen == "title" and scene.overlay != null, "Real scene opens at title")
	check(scene.selected_mode == "bloom" and scene.selected_scenario == "surround", "Title defaults to the new short comparison")
	scene._select_mode("standard")
	scene._start_run()
	await process_frame
	check(scene.screen == "playing" and scene.overlay == null and scene.pause_button.visible, "Start button enters real gameplay scene")
	var model = scene.run
	var before: Vector2 = model.player
	Input.action_release("ui_accept")
	var movement := InputEventScreenTouch.new()
	movement.index = 1
	movement.position = Vector2(100, 500)
	movement.pressed = true
	scene._unhandled_input(movement)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(172, 500)
	scene._unhandled_input(drag)
	scene._physics_process(0.1)
	check(model.player.x > before.x and model.projectiles.is_empty(), "Left touch moves without shooting")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	scene._unhandled_input(emulated)
	check(not scene.mouse_held, "Emulated touch mouse must not hijack aim")
	scene._on_focus_lost()
	await process_frame
	check(scene.screen == "paused" and scene.touch.move_id == -1 and not scene.mouse_held, "Losing focus pauses and clears held input")
	var frozen: float = model.elapsed
	scene._physics_process(1.0)
	check(model.elapsed == frozen, "Pause overlay actually freezes simulation")
	scene._resume_run()
	model.xp = model.required_xp()
	model.maybe_level_up()
	scene._sync_screen()
	await process_frame
	check(scene.screen == "upgrade" and scene.overlay != null and not scene.pause_button.visible, "Real upgrade overlay replaces play UI")
	var id: String = model.offers[0]
	scene._choose_upgrade(id)
	await process_frame
	check(scene.screen == "playing" and model.upgrades[id] == 1, "Choosing a real card applies upgrade and returns to play")
	model.elapsed = 179.999
	model.spawn_timer = 1000.0
	model.enemies.clear()
	scene._physics_process(0.01)
	await process_frame
	check(scene.screen == "won" and scene.overlay != null, "Success result UI is reachable")
	scene._start_run()
	model.hp = 0.0
	scene._physics_process(0.01)
	await process_frame
	check(scene.screen == "lost" and scene.overlay != null, "Failure result UI is reachable")
	scene._start_run()
	await process_frame
	check(scene.screen == "playing" and model.hp == 100.0 and model.level == 1 and model.enemies.is_empty(), "Result restart resets the actual scene")
	scene._show_title()
	scene._select_character("bear")
	scene._start_run()
	await process_frame
	check(model.character_id == "bear" and scene.selected_character == "bear", "Character card starts the selected animal")
	model.fire()
	scene._consume_events()
	check(model.projectiles.is_empty() and not scene.effects.is_empty(), "Bear scene renders swipe feedback without spawning projectiles")
	model.xp = model.required_xp()
	model.maybe_level_up()
	scene._sync_screen()
	await process_frame
	check(scene.screen == "upgrade" and "pierce" not in model.offers, "Bear upgrade UI uses its own candidate pool")
	scene._choose_upgrade(model.offers[0])
	scene._start_run()
	check(model.character_id == "bear" and model.level == 1, "Restart keeps chosen animal and clears growth")
	scene._show_title()
	scene._select_character("hedgehog")
	scene._start_run()
	check(model.character_id == "hedgehog", "Returning to title allows switching back to hedgehog")
	scene._show_title()
	var comparison_button: Button = find_button(scene.overlay, "A 廣域清群")
	check(comparison_button != null, "Real title exposes a broad-build comparison button")
	comparison_button.pressed.emit()
	scene._start_run()
	check(model.mode_id == "bloom" and model.upgrades["bounce"] == 2, "Real mode button starts the advertised comparison abilities")
	scene._pause_run()
	await process_frame
	check(contains_label(scene.overlay, "起始 2／新選 0"), "Pause recap identifies starter ability counts")
	scene._resume_run()
	model.xp = model.required_xp()
	model.maybe_level_up()
	scene._sync_screen()
	scene._choose_upgrade(model.offers[0])
	model.hp = 0.0
	scene._physics_process(0.01)
	await process_frame
	check(scene.screen == "lost" and contains_label(scene.overlay, "本局新選 1 次"), "Real result displays earned choices separately from the starter build")
	var switch_button: Button = find_button(scene.overlay, "換成另一條路線比較")
	check(switch_button != null, "Comparison results provide a direct route switch")
	switch_button.pressed.emit()
	await process_frame
	check(scene.screen == "title" and scene.selected_mode == "focus", "Route switch selects the other build before starting")
	scene._start_run()
	check(model.mode_id == "focus" and model.upgrades["pierce"] == 2 and model.chosen_upgrades.is_empty(), "Other build starts cleanly with its own abilities")
	scene._show_title()
	scene._select_character("bear")
	scene._start_run()
	check(model.mode_id == "standard" and model.starting_upgrades.is_empty() and scene.selected_mode == "standard", "Changing to bear clears comparison mode in real UI")
	scene._show_title()
	scene._select_character("hedgehog")
	scene._select_mode("bloom")
	var scenario_button: Button = find_button(scene.overlay, "單向隊列")
	check(scenario_button != null, "Title exposes short scenario selection")
	scenario_button.pressed.emit()
	scene._start_run()
	check(model.scenario_id == "queue" and model.mode_id == "bloom", "Scenario button starts selected formation with selected build")
	scene._physics_process(0.8)
	scene._pause_run()
	var warning: float = model.warning_remaining
	scene._physics_process(1.0)
	check(model.warning_remaining == warning and contains_label(scene.overlay, "固定能力，不升級"), "Real pause freezes arrival warning and explains fixed build")
	scene._resume_run()
	model.xp = 1000
	model.maybe_level_up()
	scene._sync_screen()
	check(scene.screen == "playing" and model.level == 1, "Short scene cannot unexpectedly open random upgrade choices")
	model.enemies.clear()
	model.warning_positions.clear()
	model.spawn_timer = 1000.0
	model.elapsed = 44.99
	scene._physics_process(0.02)
	await process_frame
	check(scene.screen == "won" and contains_label(scene.overlay, "情境完成！"), "Short encounter has its own visible completion result")
	var change_build: Button = find_button(scene.overlay, "同情境，換 A／B")
	check(change_build != null, "Short result exposes a build-only comparison switch")
	change_build.pressed.emit()
	scene._start_run()
	check(model.scenario_id == "queue" and model.mode_id == "focus" and model.elapsed == 0.0, "Build switch preserves formation and resets run")
	model.state = "lost"
	scene._sync_screen()
	var change_scenario: Button = find_button(scene.overlay, "同構築，換陣形")
	check(change_scenario != null, "Failure result also exposes formation-only switch")
	change_scenario.pressed.emit()
	scene._start_run()
	check(model.scenario_id == "surround" and model.mode_id == "focus", "Formation switch preserves build")
	scene._start_run()
	check(model.wave_count == 0 and model.warning_positions.is_empty(), "Real short restart clears arrival state")
	scene._show_title()
	scene._select_mode("standard")
	scene._start_run()
	check(model.scenario_id == "normal" and model.duration() == 180.0 and scene.selected_scenario == "normal", "Returning to ordinary play clears fixed encounter selection")
	print("SCENE RESULT: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)


func find_button(node: Node, text: String) -> Button:
	if node is Button and text in node.text:
		return node
	for child: Node in node.get_children():
		var found: Button = find_button(child, text)
		if found != null:
			return found
	return null


func contains_label(node: Node, text: String) -> bool:
	if node is Label and text in node.text:
		return true
	for child: Node in node.get_children():
		if contains_label(child, text):
			return true
	return false
