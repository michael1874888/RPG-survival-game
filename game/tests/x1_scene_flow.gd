extends SceneTree
## The real X1 scene with an isolated test profile: menus, a battle with level-ups, pause,
## save-and-quit, resume, focus loss, collection, settings, practice and the result screen.

const Profile := preload("res://scripts/x1/core/profile.gd")
const Data := preload("res://scripts/x1/core/data.gd")
const Bot := preload("res://tests/x1_bot.gd")

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
	if node == null: return null
	if node is Button and needle in node.text and not node.disabled: return node
	for child: Node in node.get_children():
		var result := find_button(child, needle)
		if result != null: return result
	return null


func has_text(node: Node, needle: String) -> bool:
	if node == null: return false
	if (node is Label or node is Button) and needle in node.text: return true
	for child: Node in node.get_children():
		if has_text(child, needle): return true
	return false


func press(scene, needle: String) -> bool:
	var button := find_button(scene.overlay, needle)
	if button == null: return false
	button.pressed.emit()
	return true


func play_until_not_battle(scene, bot, limit_seconds: float) -> void:
	for i in int(limit_seconds * 60.0):
		if scene.screen == "card":
			press(scene, "Lv.") or press(scene, "進化") or press(scene, "略過")
			continue
		if scene.screen != "battle": return
		var b = scene.run.battle
		if b == null: return
		b.player.invuln = 1.0
		var input: Dictionary = bot.battle_input(b, 1.0 / 60.0)
		scene.touch.pending_pounce = input.pounce
		scene.ult_request = input.ult
		scene.advance_frame(1.0 / 60.0)


func exercise() -> void:
	var base := "user://x1-scene-%d" % Time.get_ticks_usec()
	var scene = load("res://x1_main.tscn").instantiate()
	scene.profile = Profile.new(base + ".save", base + ".r1", base + ".old")
	scene.instant = true
	root.add_child(scene)
	await process_frame
	check(scene.screen == "title" and find_button(scene.overlay, "出發夜巡") != null and find_button(scene.overlay, "練習場") != null, "title offers patrol and practice")
	check(find_button(scene.overlay, "繼續夜巡") == null, "no continue button without a saved run")
	press(scene, "出發夜巡")
	await process_frame
	check(scene.screen == "setup" and has_text(scene.overlay, "月下庭院") and has_text(scene.overlay, "夜深 0"), "setup shows region and night")
	check(find_button(scene.overlay, "失序溫室") == null, "the greenhouse is locked at first")
	press(scene, "游走習性")
	await process_frame
	check(scene.setup.habit == "roam", "habit choice applies")
	press(scene, "柔布領巾")
	await process_frame
	check(scene.profile.data.equip.charm == "U01", "equipping a charm is saved")
	press(scene, "出發！")
	await process_frame
	check(scene.run != null and scene.screen == "map" and scene.run.tutorial, "starting shows the map and enables the tutorial")
	check(not scene.profile.data.active.is_empty(), "the new run is saved at once")
	check(press(scene, "狩獵"), "a hunt can be chosen on the map")
	await process_frame
	check(scene.screen == "battle" and scene.world.visible and scene.run.battle != null, "the battle starts")
	var bot = Bot.new()
	play_until_not_battle(scene, bot, 4.0)
	check(scene.hud.hint_time > 0.0 or scene.tutorial_flags.has("pounce"), "tutorial hints appear")
	scene._on_focus_lost()
	await process_frame
	check(scene.screen == "pause" and find_button(scene.overlay, "繼續") != null, "losing focus pauses the battle")
	check(scene.profile.data.active.get("phase", "") == "battle", "pausing saves the battle")
	press(scene, "保存並回到首頁")
	await process_frame
	check(scene.screen == "title" and find_button(scene.overlay, "繼續夜巡") != null, "title offers to continue")
	press(scene, "繼續夜巡")
	await process_frame
	check(scene.screen == "pause" and scene.run != null and scene.run.battle != null, "continuing restores the battle paused")
	press(scene, "繼續")
	await process_frame
	check(scene.screen == "battle", "resume returns to the battle")
	var levels_before: int = scene.run.level
	play_until_not_battle(scene, bot, 150.0)
	check(scene.run.level > levels_before, "level-ups were chosen through the card screen")
	check(scene.screen == "map" and scene.run.battles_won >= 1, "winning the hunt returns to the map")
	check(scene.profile.data.active.get("phase", "") == "map", "the map position is saved")
	# Force a loss to see the result screen.
	press(scene, "狩獵") or press(scene, "獵物巢") or press(scene, "月光") or press(scene, "貓窩") or press(scene, "房間")
	await process_frame
	if scene.screen == "battle":
		scene.run.battle.player.hp = 1.0
		scene.run.battle.player.invuln = 0.0
		scene.run.battle.hurt_player(99.0, "E01")
		scene.advance_frame(1.0 / 60.0)
	else:
		scene.run._finish(false)
		scene._sync()
	await process_frame
	check(scene.screen == "result" and find_button(scene.overlay, "再出發") != null, "the run ends on the result screen")
	check(scene.profile.data.active.is_empty() and int(scene.profile.data.progress.runs) == 1, "the finished run is recorded")
	check(has_text(scene.overlay, "差一點就解鎖"), "the result shows the nearest goals")
	check(scene.profile.data.tutorial_done, "the tutorial is finished after the first run")
	press(scene, "首頁")
	await process_frame
	press(scene, "收藏與紀錄")
	await process_frame
	check(scene.screen == "collection" and has_text(scene.overlay, "已收藏"), "collection shows items")
	press(scene, "本能卡")
	await process_frame
	check(has_text(scene.overlay, "可用本能卡") and has_text(scene.overlay, "進化"), "collection shows cards and evolutions")
	press(scene, "紀錄")
	await process_frame
	check(has_text(scene.overlay, "夜巡 1 次"), "records count runs")
	press(scene, "寶物")
	await process_frame
	check(press(scene, "設為尋寶目標"), "a chest item can be targeted")
	await process_frame
	check(not str(scene.profile.data.target).is_empty(), "the target is saved")
	press(scene, "返回")
	await process_frame
	press(scene, "設定")
	await process_frame
	press(scene, "低閃光")
	await process_frame
	check(scene.profile.data.settings.low_flash, "settings toggle and save")
	press(scene, "大")
	await process_frame
	check(scene.touch.radius == 90.0, "stick size applies")
	press(scene, "返回")
	await process_frame
	press(scene, "練習場")
	await process_frame
	press(scene, "穿影習性")
	await process_frame
	check(scene.screen == "battle" and scene.run.practice and scene.run.battle.kind == "practice", "practice starts")
	var runs_before: int = int(scene.profile.data.progress.runs)
	scene._pause()
	await process_frame
	check(find_button(scene.overlay, "保存並回到首頁") == null, "practice has no save-and-quit")
	press(scene, "放棄這一局")
	await process_frame
	press(scene, "放棄")
	await process_frame
	check(scene.screen == "title" and int(scene.profile.data.progress.runs) == runs_before, "leaving practice changes nothing")
	scene.queue_free()
	await process_frame
	print("X1 SCENE: %d checks, %d failures" % [checks, failures])
	Data.release()
	quit(1 if failures > 0 else 0)
