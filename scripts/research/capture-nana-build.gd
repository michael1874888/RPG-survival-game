extends SceneTree
## Render the actual game scene for local layout review; writes two temporary PNGs.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene._show_build_experiment()
	scene._select_build_preset(["a", "c"])
	scene._select_build_scenario("nana_build_e3")
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/nana-build-menu.png")
	scene._start_run()
	scene.run.encounters.add_enemy(scene.run, "elite", scene.run.player + Vector2(145, 0))
	scene.run.nana.prey_id = int(scene.run.enemies[0].id)
	scene.run.nana.prey_remaining = 3.0
	scene.run.nana.bite_charge = 3
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("/tmp/nana-build-game.png")
	quit()
