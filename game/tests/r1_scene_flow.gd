extends SceneTree

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("exercise")


func find_button(node: Node, needle: String) -> Button:
	if node is Button and needle in node.text: return node
	for child: Node in node.get_children():
		var result := find_button(child, needle)
		if result != null: return result
	return null


func exercise() -> void:
	var test_base := "user://r1-scene-%d" % Time.get_ticks_usec()
	var scene = load("res://r1_main.tscn").instantiate()
	scene.profile = load("res://scripts/r1_profile.gd").new(test_base + ".save", test_base + ".old")
	scene.treasure = load("res://scripts/treasure_collection.gd").new(test_base + ".old")
	root.add_child(scene)
	await process_frame
	check(scene.screen == "title" and find_button(scene.overlay, "準備出發") != null, "R1 scene starts at the expedition title")
	find_button(scene.overlay, "準備出發").pressed.emit()
	check(find_button(scene.overlay, "游走蓄勢") != null and find_button(scene.overlay, "開始冒險") != null, "Setup shows opening and start")
	find_button(scene.overlay, "開始冒險").pressed.emit()
	check(scene.screen == "playing" and scene.run.r1 != null and scene.adventure.node == 1, "Setup starts the first actual R1 node")
	scene.run.xp = 12
	scene.run.maybe_level_up()
	scene._sync_screen()
	check(scene.screen == "upgrade" and scene.run.offers.size() == 3, "Level-up opens three R1 choices")
	var first: String = scene.run.offers[0]
	find_button(scene.overlay, scene.run.growth.label(first).split("\n")[0]).pressed.emit()
	check(scene.screen == "playing" and scene.run.level == 2, "Choosing an upgrade resumes combat")
	for node in [1, 2, 3]:
		scene.run.state = "won"
		scene.run.enemies.clear()
		scene._sync_screen()
		if node < 3:
			check(scene.screen == "between", "Completed normal node opens intermission")
			find_button(scene.overlay, "進入下一戰").pressed.emit()
	check(scene.screen == "chest" and find_button(scene.overlay, "回身鈴鐺") != null, "First elite awards the guaranteed bell")
	find_button(scene.overlay, "回身鈴鐺").pressed.emit()
	check("H03" in scene.profile.data.owned and scene.screen == "camp", "Bell is saved before the camp")
	var option: String = scene.adventure.route_choices[0]
	find_button(scene.overlay, scene.adventure.EVENTS[option][0]).pressed.emit()
	check(scene.screen == "between", "Choosing a route leads to the next node")
	find_button(scene.overlay, "進入下一戰").pressed.emit()
	check(scene.adventure.node == 4 and scene.run.state == "playing", "Next battle uses the chosen route")
	scene._pause_run()
	find_button(scene.overlay, "保存並回到起點").pressed.emit()
	check(scene.screen == "title" and find_button(scene.overlay, "繼續上次") != null, "Pause can save and leave")
	find_button(scene.overlay, "繼續上次").pressed.emit()
	check(scene.adventure.node == 4 and scene.run.state == "paused" and "H03" in scene.profile.data.owned, "Continue restores the node paused and keeps collection")
	find_button(scene.overlay, "繼續冒險").pressed.emit()
	for node in range(4, 10):
		check(scene.adventure.node == node and scene.run.state == "playing", "Real scene starts node %d" % node)
		scene.run.experiment.event_success = true
		scene.run.state = "won" # Controlled UI transition; fighting was tested separately.
		scene.run.enemies.clear()
		scene._sync_screen()
		if node == 9: break
		var transitions := 0
		while scene.adventure.phase != "between" and transitions < 8:
			match scene.adventure.phase:
				"chest", "chest_event":
					var choices: Array = scene.adventure.chest_choices
					if not choices.is_empty():
						var item_name = scene.ProfileR1.ITEMS[choices[0]].name
						find_button(scene.overlay, item_name).pressed.emit()
					else:
						var options: Array = scene.adventure.available_supply(scene.run)
						if options.is_empty(): find_button(scene.overlay, "繼續").pressed.emit()
						else: scene._choose_supply(options[0], false)
				"camp":
					var route: String = scene.adventure.route_choices[0]
					find_button(scene.overlay, scene.adventure.EVENTS[route][0]).pressed.emit()
				"event_common":
					var common: String = scene.run.offers[0]
					find_button(scene.overlay, scene.run.growth.label(common).split("\n")[0]).pressed.emit()
				"event_supply":
					var supplies: Array = scene.adventure.available_supply(scene.run, true)
					if supplies.is_empty(): find_button(scene.overlay, "繼續").pressed.emit()
					else: scene._choose_supply(supplies[0], true)
				_:
					check(false, "Unexpected real scene phase " + scene.adventure.phase)
					break
			transitions += 1
		check(scene.adventure.phase == "between", "Scene rewards and camp lead to the next battle")
		find_button(scene.overlay, "進入下一戰").pressed.emit()
	check(scene.screen == "result" and scene.adventure.won, "Ninth node opens the victory result")
	check(scene.profile.data.active.is_empty() and scene.profile.data.history.size() == 1, "Victory records one result and clears the resumable run")
	find_button(scene.overlay, "再出發").pressed.emit()
	check(find_button(scene.overlay, "回身鈴鐺") != null, "A collected bell remains available for the next setup")
	scene.queue_free()
	await process_frame
	for suffix in [".save", ".save.bak", ".save.tmp", ".save.bak.tmp", ".old"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_base + suffix))
	print("R1 SCENE RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
