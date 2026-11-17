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
	scene._show_title()
	var series_entry: Button = find_button(scene.overlay, "三連戰")
	check(series_entry != null, "The title exposes the three-stage mode")
	series_entry.pressed.emit()
	find_button(scene.overlay, "游走蓄勢").pressed.emit()
	check(scene.series.active and model.experiment.abilities == ["b"] and model.scenario_id == "nana_build_e1", "Opening ability starts E1 through the actual menu")
	var series_paths: Array[String] = []
	for stage_index in 2:
		# Terminal fixtures exercise UI transitions; the combat probe plays full encounters.
		model.state = "won"
		model.enemies.clear()
		for event in model.experiment.schedule: event.state = "born"
		model.hp = 50.0
		model.nana.cooldown = 24.0
		scene._sync_screen()
		series_paths.append(model.experiment.saved_path)
		check(scene.screen == "between" and not scene.ultimate_button.visible and scene.series.results.size() == stage_index + 1, "Stage completion opens a single intermission")
		check(contains_label(scene.overlay, "生命 50 → 75") and contains_label(scene.overlay, "冷卻 24.0"), "Intermission shows the actual recovery and carried cooldown")
		var choice := "加裝：穿影爪" if stage_index == 0 else "替換：游走蓄勢 → 獵痕重咬"
		find_button(scene.overlay, choice).pressed.emit()
		check(scene.screen == "playing" and model.hp == 75.0 and model.nana.cooldown == 24.0, "Choosing a build starts the next stage with carried state")
	check(scene.series.stage == 2 and model.experiment.abilities == ["a", "c"], "The second choice can replace one ability for E3")
	model.state = "lost"
	scene._sync_screen()
	series_paths.append(model.experiment.saved_path)
	check(scene.series.finished and contains_label(scene.overlay, "完成 2 / 3 段"), "A loss ends the whole series and shows its earlier stages")
	find_button(scene.overlay, "同開局，再挑戰三連戰").pressed.emit()
	check(scene.series.stage == 0 and model.hp == 100.0 and model.experiment.abilities == ["b"], "Result retry restarts at E1 with the same opening")
	scene._pause_run()
	check(find_button(scene.overlay, "從第一段重新挑戰") != null, "Pause makes series restart scope explicit")
	scene._show_title()
	var short_entry: Button = find_button(scene.overlay, "森林短局")
	check(short_entry != null, "The title exposes the short run")
	short_entry.pressed.emit()
	find_button(scene.overlay, "游走蓄勢").pressed.emit()
	check(scene.series.short_run and model.scenario_id == "nana_build_s1", "Short-run setup starts the first short scenario")
	for stage_index in 4:
		model.state = "won"
		model.enemies.clear()
		for event in model.experiment.schedule: event.state = "born"
		scene._sync_screen()
		series_paths.append(model.experiment.saved_path)
		if stage_index < 3:
			check(scene.screen == "between", "Each short-run stage opens its intermission")
			scene._advance_series(scene.series.choices()[0])
	check(scene.series.finished and contains_label(scene.overlay, "完成 4 / 4 段"), "Fourth short-run victory reaches the final summary")
	find_button(scene.overlay, "同開局，再挑戰").pressed.emit()
	check(scene.series.short_run and model.scenario_id == "nana_build_s1", "Short-run retry preserves its mode")
	for path in series_paths:
		if not path.is_empty(): DirAccess.remove_absolute(path)
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
