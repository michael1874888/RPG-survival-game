extends SceneTree
## Real scene rendering with synthetic terminal fixtures; not a player playthrough.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_window().focus_exited.disconnect(scene._on_focus_lost)
	scene._show_series_setup()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/nana-series-setup.png")
	scene._start_series("b")
	scene.set_physics_process(false)
	var paths: Array[String] = []
	for index in 3:
		scene.run.state = "won"
		scene.run.hp = 50.0
		scene.run.elapsed = 20.0
		scene.run.nana.cooldown = 24.0
		scene.run.enemies.clear()
		for entry in scene.run.experiment.schedule: entry.state = "born"
		scene._sync_screen()
		paths.append(scene.run.experiment.saved_path)
		await process_frame
		await process_frame
		if index == 0: root.get_texture().get_image().save_png("/tmp/nana-series-between.png")
		if index == 1: root.get_texture().get_image().save_png("/tmp/nana-series-between2.png")
		if index == 2: root.get_texture().get_image().save_png("/tmp/nana-series-result.png")
		if index < 2: scene._advance_series({"kind": "add", "id": "a"} if index == 0 else {"kind": "replace", "id": "c", "remove": "b"})
	for path in paths:
		if not path.is_empty(): DirAccess.remove_absolute(path)
	scene.queue_free()
	await process_frame
	quit()
