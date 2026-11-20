extends SceneTree
## Desktop screenshot tour of every X1 screen with an isolated test profile (needs a window, not headless).
## Usage: Godot --path game --fixed-fps 60 [--resolution 1600x720] --script res://tests/x1_visual.gd -- out=/absolute/folder

const Profile := preload("res://scripts/x1/core/profile.gd")
const Data := preload("res://scripts/x1/core/data.gd")
const Bot := preload("res://tests/x1_bot.gd")

var out := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
		if arg.begins_with("size="):
			var parts := arg.substr(5).split("x")
			root.size = Vector2i(int(parts[0]), int(parts[1]))
	call_deferred("tour")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png(out.path_join(name + ".png"))
	print("saved ", name)


func find_button(node: Node, needle: String) -> Button:
	if node == null: return null
	if node is Button and needle in node.text and not node.disabled: return node
	for child: Node in node.get_children():
		var result := find_button(child, needle)
		if result != null: return result
	return null


func press(scene, needle: String) -> bool:
	var button := find_button(scene.overlay, needle)
	if button == null: return false
	button.pressed.emit()
	return true


func fight(scene, seconds: float) -> void:
	var bot = Bot.new()
	for i in int(seconds * 60.0):
		if scene.screen != "battle" or scene.run.battle == null: return
		if scene.run.needs_level_choice():
			scene.run.choose_card(bot.pick_card(scene.run))
			continue
		var b = scene.run.battle
		b.player.invuln = 1.0
		var input: Dictionary = bot.battle_input(b, 1.0 / 60.0)
		var ended: bool = scene.run.tick(1.0 / 60.0, input)
		b.take_events()   # screenshots show the battle state, not 26 s of piled-up effects
		if ended: return


func tour() -> void:
	var base := "user://x1-visual-%d" % Time.get_ticks_usec()
	var scene = load("res://x1_main.tscn").instantiate()
	var profile = Profile.new(base + ".save", base + ".r1", base + ".old")
	var next: Dictionary = profile.data.duplicate(true)
	next.owned.append_array(["H01", "H03", "U03"])
	next.region_night = {"courtyard": 1, "greenhouse": 0, "belltower": -1}
	next.unlocked = ["CL05", "SH05", "PO04"]
	profile.commit(next)
	scene.profile = profile
	scene.instant = true   # no wipes, walks or card flips in still shots
	root.add_child(scene)
	await shot("01_title")
	press(scene, "出發夜巡")
	await shot("02_setup")
	press(scene, "出發！")
	await shot("03_map")
	press(scene, "狩獵")
	fight(scene, 26.0)
	scene.hud.show_hint("右手拖曳、放開：撲出去！撲擊途中不會受傷，落地會咬一口。", 5.0)
	scene.touch.aim_id = 3
	scene.touch.aim_origin = Vector2(1050, 520)
	scene.touch.aim_point = Vector2(1120, 470)
	await shot("04_battle_courtyard")
	scene.touch.aim_id = -1
	scene.run.gain_xp(scene.run.xp_needed())
	scene.advance_frame(1.0 / 60.0)
	await shot("05_card_choice")
	press(scene, "略過")
	scene.run.phase = "shop"
	scene.run.fish = 30
	scene.run._stock_shop()
	scene._sync()
	await shot("06_shop")
	scene.run.phase = "moon"
	scene.run.event_id = "M04"
	scene._sync()
	await shot("07_moon")
	scene.run.phase = "map"
	scene.run.queue = ["item"]
	scene.run.advance_queue()
	scene._sync()
	await shot("08_item")
	for region: String in ["greenhouse", "belltower"]:
		scene.run.region_id = region
		scene.run.node_kind = "hunt"
		scene.run.node_layer = 4
		scene.run.phase = "map"
		scene.run._start_battle("hunt")
		scene._sync()
		fight(scene, 22.0)
		await shot("09_battle_" + region)
	for region: String in ["courtyard", "greenhouse", "belltower"]:
		scene.run.region_id = region
		scene.run.node_kind = "boss"
		scene.run.node_layer = 8
		scene.run._start_battle("boss")
		scene._sync()
		fight(scene, 14.0)
		await shot("10_boss_" + region)
	scene.run._finish(false)
	scene._sync()
	await shot("11_result")
	press(scene, "收藏與紀錄")
	await shot("12_collection")
	press(scene, "本能卡")
	await shot("13_cards")
	press(scene, "返回")
	press(scene, "設定")
	await shot("14_settings")
	quit()
