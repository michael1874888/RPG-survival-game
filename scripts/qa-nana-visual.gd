extends SceneTree

var destination: String = OS.get_environment("NANA_QA_DIR")

func _initialize() -> void:
	call_deferred("exercise")

func snap(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result: int = root.get_texture().get_image().save_png(destination.path_join(name))
	if result != OK:
		push_error("Unable to save " + name)
		quit(1)

func click_at(pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.global_position = pos
	event.pressed = true
	root.push_input(event, true)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release, true)

func find_button(node: Node, label: String) -> Button:
	if node is Button and label in node.text:
		return node
	for child: Node in node.get_children():
		var found := find_button(child, label)
		if found != null:
			return found
	return null

func exercise() -> void:
	if destination.is_empty() or not DirAccess.dir_exists_absolute(destination):
		push_error("Set NANA_QA_DIR to an existing, approved output directory")
		quit(1)
		return
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await snap("01-title.png")
	var start: Button = find_button(scene.overlay, "開始奈奈手感練習")
	if start == null:
		push_error("Nana start button is missing")
		quit(1)
		return
	click_at(start.get_global_rect().get_center())
	await process_frame
	if scene.screen == "paused":
		var resume: Button = find_button(scene.overlay, "繼續冒險")
		if resume != null:
			click_at(resume.get_global_rect().get_center())
			await process_frame
	if scene.screen != "playing" or scene.run.character_id != "nana":
		push_error("Native title button state: " + str(scene.screen) + " / " + str(scene.run.character_id))
		quit(1)
		return
	scene.run.spawn_timer = 1000.0
	scene.run.nana.bite_charge = 3
	scene.run._add_enemy(scene.run.player + Vector2(170, 0), false, 100.0, 0.0)
	scene.run._add_enemy(scene.run.player + Vector2(100, 80), false, 100.0, 0.0)
	await snap("02-playing.png")
	click_at(scene.ultimate_button.get_global_rect().get_center())
	await process_frame
	if scene.run.nana.cooldown <= 0.0 or scene.run.nana.ultimate_remaining <= 0.0:
		push_error("Native ultimate button did not activate")
		quit(1)
		return
	await snap("03-ultimate.png")
	print("Native render and UI: title, start, active ultimate, screenshots saved")
	scene.queue_free()
	await create_timer(0.3).timeout
	quit()
