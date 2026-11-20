extends SceneTree
## Records contact sheets (frame sequences) of key feedback moments for review. Needs a window.
## Usage: Godot --path game --fixed-fps 60 --script res://tests/x1_record.gd -- out=/absolute/folder [size=1280x720]
## --fixed-fps 60 matters: without it the presentation runs on the display's real frame time
## (8 ms on a 120 Hz screen) while the battle steps 1/60 s per frame, so effects look twice as long.

const Profile := preload("res://scripts/x1/core/profile.gd")
const Bot := preload("res://tests/x1_bot.gd")

var out := ""
var scene = null
var bot = Bot.new()


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("out="): out = arg.substr(4)
		if arg.begins_with("size="):
			var parts := arg.substr(5).split("x")
			root.size = Vector2i(int(parts[0]), int(parts[1]))
	call_deferred("record")


func resolve_cards() -> void:
	var guard := 0
	while scene.screen == "card" and scene.run != null and not scene.run.build.offers.is_empty() and guard < 10:
		guard += 1
		scene.run.choose_card(scene.run.build.offers[0])
		scene._after_card()


func step(frames: int, use_bot := true) -> void:
	for i in frames:
		resolve_cards()
		var b = scene.run.battle if scene.run != null else null
		if b != null and use_bot and scene.screen == "battle":
			var input: Dictionary = bot.battle_input(b, 1.0 / 60.0)
			scene.touch.move_id = -1
			b.player.invuln = maxf(float(b.player.invuln), 0.0)
		scene.advance_frame(1.0 / 60.0)
		await process_frame


func sheet(name: String, frames: int, every := 2, setup := Callable()) -> void:
	var shots: Array = []
	resolve_cards()
	if setup.is_valid(): setup.call()
	for i in frames:
		if name != "06_level_up": resolve_cards()
		scene.advance_frame(1.0 / 60.0)
		await process_frame
		if i % every == 0:
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			image.resize(int(image.get_width() / 2.0), int(image.get_height() / 2.0), Image.INTERPOLATE_BILINEAR)
			shots.append(image)
	var cols := 4
	var w: int = shots[0].get_width()
	var h: int = shots[0].get_height()
	var rows := int(ceil(shots.size() / float(cols)))
	var canvas := Image.create(w * cols, h * rows, false, shots[0].get_format())
	for i in shots.size():
		canvas.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	canvas.save_png(out.path_join(name + ".png"))
	print("saved ", name, " (", shots.size(), " frames)")


func find_button(node: Node, needle: String) -> Button:
	if node == null: return null
	if node is Button and needle in node.text and not node.disabled: return node
	for child: Node in node.get_children():
		var result := find_button(child, needle)
		if result != null: return result
	return null


func near_enemy(b, kind: String, offset: Vector2, hp: float, opts := {}) -> Dictionary:
	var e: Dictionary = b.spawn_enemy(kind, b.player.pos + offset, opts)
	e.hp = hp
	e.max_hp = maxf(hp, float(e.max_hp))
	e.visible_time = 5.0
	return e


func record() -> void:
	var base := "user://x1-record-%d" % Time.get_ticks_usec()
	scene = load("res://x1_main.tscn").instantiate()
	scene.profile = Profile.new(base + ".save", base + ".r1", base + ".old")
	scene.set_process(false)
	root.add_child(scene)
	await process_frame
	find_button(scene.overlay, "出發夜巡").pressed.emit()
	await process_frame
	find_button(scene.overlay, "出發！").pressed.emit()
	await process_frame
	scene.instant = true
	find_button(scene.overlay, "狩獵").pressed.emit()
	scene.instant = false
	await process_frame
	await step(60 * 14)
	var b = scene.run.battle
	b.spawning = false
	scene.run.tutorial = false
	scene.hud.hint_time = 0.0
	# 1. Pounce through a line of fodder and bite a prey at the landing point.
	await sheet("01_pounce_bite", 24, 2, func():
		for e in b.enemies: e.hp = 0.0
		for i in 4: near_enemy(b, "E01", Vector2(60 + i * 40, 0), 10.0)
		near_enemy(b, "E04", Vector2(250, 0), 200.0, {"prey": true})
		b.pounce.charges = 2
		scene.touch.pending_pounce = Vector2.RIGHT)
	# 2. Prey kill with gold burst and fish flying to the HUD.
	await sheet("02_prey_kill", 24, 2, func():
		var prey := near_enemy(b, "E05", Vector2(110, 0), 1.0, {"prey": true})
		b.claw_timer = 0.0)
	# 3. Night shadow activation in a crowd.
	await sheet("03_night_shadow", 28, 2, func():
		for i in 14: near_enemy(b, "E01", Vector2(120, 0).rotated(TAU * i / 14.0), 40.0)
		b.ult.meter = 100.0
		b.ult.active = 0.0
		scene.ult_request = true)
	# 4. Getting hit from the right.
	await sheet("04_hurt", 20, 2, func():
		b.player.invuln = 0.0
		b.player.hp = 25.0
		b.hurt_player(12.0, "E03", b.player.pos + Vector2(80, 0)))
	# 5. Combo: a ring of fodder cleared quickly.
	await sheet("05_combo", 32, 3, func():
		for i in 24: near_enemy(b, "E01", Vector2(70 + (i % 3) * 25, 0).rotated(TAU * i / 24.0), 5.0)
		b.stats.add_buff("claw_angle", 260.0, 3.0, "record"))
	# 6. Level-up flow into the card reveal.
	await sheet("06_level_up", 40, 3, func():
		scene.run.gain_xp(scene.run.xp_needed()))
	resolve_cards()
	# 7. Enemy warnings: guard swing and charger line.
	await sheet("07_telegraphs", 36, 3, func():
		for e in b.enemies: e.hp = 0.0
		b.player.hp = float(b.player.max_hp)
		near_enemy(b, "E05", Vector2(140, 40), 300.0)
		near_enemy(b, "E03", Vector2(-200, -60), 300.0))
	# 8. Boss phase change and defeat.
	scene.run.node_kind = "boss"
	scene.run.node_layer = 8
	scene.run._start_battle("boss")
	scene._sync()
	var boss_battle = scene.run.battle
	boss_battle.player.invuln = 99.0
	await sheet("08a_boss_intro", 150, 10)
	await sheet("08_boss_phase", 32, 2, func():
		var boss: Dictionary = boss_battle.boss()
		if not boss.is_empty(): boss.hp = float(boss.max_hp) * 0.29)
	await sheet("09_boss_down", 48, 3, func():
		var boss: Dictionary = boss_battle.boss()
		if not boss.is_empty(): boss_battle.damage_enemy(boss, 999999.0, "bite", 0))
	print("done")
	quit()
