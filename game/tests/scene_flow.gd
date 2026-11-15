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
	check(scene.selected_character == "nana" and scene.selected_scenario == "nana_build_e1", "Title defaults to Nana build experiment")
	var entry: Button = find_button(scene.overlay, "選擇能力與情境")
	check(entry != null, "Title opens the build configuration")
	entry.pressed.emit()
	scene._start_run()
	await process_frame
	check(scene.run.character_id == "nana" and scene.ultimate_button.visible, "Nana starts in the real scene with an ultimate button")
	var nana_move := InputEventScreenTouch.new()
	nana_move.index = 41
	nana_move.position = Vector2(100, 500)
	nana_move.pressed = true
	root.push_input(nana_move, true)
	var ultimate_touch := InputEventScreenTouch.new()
	ultimate_touch.index = 42
	ultimate_touch.position = scene.ultimate_button.get_global_rect().get_center()
	ultimate_touch.pressed = true
	root.push_input(ultimate_touch, true)
	check(scene.run.nana.cooldown == 40.0 and scene.touch.move_id == 41 and scene.touch.aim_id == -1, "Ultimate touch activates on press without stealing movement or aim")
	var ultimate_drag := InputEventScreenDrag.new()
	ultimate_drag.index = 42
	ultimate_drag.position = Vector2(1200, 600)
	root.push_input(ultimate_drag, true)
	check(scene.touch.aim_id == -1 and scene.touch.move_id == 41, "Dragging from the ultimate button cannot become an aim gesture")
	ultimate_touch.pressed = false
	root.push_input(ultimate_touch, true)
	check(scene.touch.aim_id == -1 and scene.touch.move_id == 41 and scene.ultimate_touches.is_empty(), "Ultimate release stays owned by the button")
	scene._pause_run()
	await process_frame
	check(not scene.ultimate_button.visible and scene.screen == "paused", "Nana's ultimate button is hidden in the pause overlay")
	scene._show_title()
	var build_entry: Button = find_button(scene.overlay, "選擇能力與情境")
	check(build_entry != null, "Nana title exposes the build experiment")
	build_entry.pressed.emit()
	var model = scene.run
	var build_a: Button = find_button(scene.overlay, "穿影爪")
	check(build_a != null and find_button(scene.overlay, "混合威脅") != null, "Experiment menu exposes abilities and encounters")
	build_a.pressed.emit()
	scene._toggle_build_ability("c")
	scene._toggle_build_ability("b")
	check(scene.selected_build_abilities == ["a", "c"], "Experiment menu enforces the two ability limit")
	scene._select_build_scenario("nana_build_e2")
	scene._start_run()
	check(model.experiment.active and model.experiment.abilities == ["a", "c"] and model.scenario_id == "nana_build_e2", "Experiment starts selected abilities and scenario through the real scene")
	scene._pause_run()
	var frozen_time: float = model.elapsed
	model.tick(1.0, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.elapsed == frozen_time and scene.screen == "paused", "Experiment pause freezes simulation")
	scene._resume_run()
	model.combat_metrics.damage_taken["charger"] = 16.0
	model.combat_metrics.defeats.append({"kind": "elite", "time": 10.0, "born_at": 2.0})
	model.state = "unfinished"
	scene._sync_screen()
	check(scene.screen == "unfinished" and model.experiment.logged and find_button(scene.overlay, "更換能力或情境") != null, "Unfinished result persists observations and exposes a configuration return")
	check(contains_label(scene.overlay, "衝撞者 16") and contains_label(scene.overlay, "精英 8.0 秒"), "Experiment result shows readable damage sources and elapsed target time")
	if not model.experiment.saved_path.is_empty():
		DirAccess.remove_absolute(model.experiment.saved_path)
	scene._show_build_experiment()
	check(scene.selected_build_abilities == ["a", "c"] and scene.selected_scenario == "nana_build_e2", "Returning to configuration preserves the test choices")
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
