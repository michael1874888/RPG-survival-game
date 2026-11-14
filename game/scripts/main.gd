extends Control

const Run := preload("res://scripts/run_model.gd")
const Touch := preload("res://scripts/touch_controls.gd")
const CREAM := Color("fff2d4")
const MUTED := Color("a9c9ae")
const GOLD := Color("ffd479")
const INK := Color("17362d")

var run = Run.new()
var touch = Touch.new()
var font: Font
var bold_font: Font
var screen: String = "title"
var selected_character: String = "hedgehog"
var selected_mode: String = "bloom"
var selected_scenario: String = "surround"
var overlay: Control
var pause_button: Button
var mouse_held: bool = false
var mouse_position := Vector2.ZERO
var effects: Array[Dictionary] = []
var decorations: Array[Dictionary] = []
var clock: float = 0.0
var hurt_flash: float = 0.0
var audio_player: AudioStreamPlayer
var audio_buffer: AudioStreamGeneratorPlayback
var audio_phase: float = 0.0
var tone_remaining: float = 0.0
var tone_frequency: float = 600.0
var sound_on: bool = true


func _ready() -> void:
	var base_font: Font = load("res://assets/fonts/NotoSansTC.ttf") as Font
	var regular := FontVariation.new()
	regular.base_font = base_font
	var weight_tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	regular.variation_opentype = {weight_tag: 450.0}
	regular.variation_embolden = 0.45
	font = regular
	var heavier := FontVariation.new()
	heavier.base_font = base_font
	heavier.variation_opentype = {weight_tag: 700.0}
	heavier.variation_embolden = 0.9
	bold_font = heavier
	var decoration_rng := RandomNumberGenerator.new()
	decoration_rng.seed = 8201
	for i in 180:
		decorations.append({"pos": Vector2(decoration_rng.randf_range(0, Run.WORLD.x),
			decoration_rng.randf_range(0, Run.WORLD.y)), "size": decoration_rng.randf_range(2, 8),
			"flower": i % 7 == 0})
	pause_button = Button.new()
	pause_button.text = "暫停 Ⅱ"
	pause_button.add_theme_font_override("font", font)
	pause_button.add_theme_font_size_override("font_size", 17)
	pause_button.add_theme_stylebox_override("normal", panel_style(Color("274a3e"), 14))
	pause_button.add_theme_stylebox_override("hover", panel_style(Color("3d6552"), 14))
	pause_button.pressed.connect(_pause_run)
	add_child(pause_button)
	resized.connect(_layout_hud)
	_layout_hud()
	_setup_audio()
	_show_title()
	get_window().focus_exited.connect(_on_focus_lost)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--preview" in args:
		_start_run()
		# A reproducible presentation mode; actual gameplay still uses the same model.
		run.elapsed = 62.0
		for i in 20:
			run.spawn_enemy()
			if i < run.enemies.size():
				run.enemies[i]["pos"] = run.player + Vector2.RIGHT.rotated(i * 0.55) * (180.0 + (i % 4) * 55.0)
		run.upgrades["scatter"] = 1
		run.upgrades["pierce"] = 1


func _layout_hud() -> void:
	if is_instance_valid(pause_button):
		pause_button.position = Vector2(size.x - 126.0, 27.0)
		pause_button.size = Vector2(96, 44)


func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.06
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = -22.0
	add_child(audio_player)
	audio_player.play()
	audio_buffer = audio_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _audio_tick(delta: float) -> void:
	if audio_buffer == null:
		return
	var frames: int = audio_buffer.get_frames_available()
	for i in frames:
		var sample: float = 0.0
		if sound_on and tone_remaining > 0.0:
			sample = sin(audio_phase) * minf(1.0, tone_remaining * 30.0) * 0.5
			audio_phase += TAU * tone_frequency / 22050.0
			tone_remaining = maxf(0.0, tone_remaining - 1.0 / 22050.0)
		audio_buffer.push_frame(Vector2.ONE * sample)
	if frames == 0:
		tone_remaining = maxf(0.0, tone_remaining - delta)


func _physics_process(delta: float) -> void:
	run.view_size = size
	if screen == "title":
		return
	if run.state == "playing":
		var movement: Vector2 = touch.movement()
		var keyboard := Vector2(
			float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
			float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
		if keyboard.length_squared() > 0.0:
			movement = keyboard.normalized()
		var direction: Vector2 = touch.aim_direction()
		var firing: bool = touch.firing()
		if mouse_held:
			direction = (mouse_position - (run.player - run.camera_origin())).normalized()
			firing = true
		run.tick(delta, movement, direction, firing)
		_consume_events()
	_sync_screen()


func _process(delta: float) -> void:
	clock += delta
	hurt_flash = maxf(0.0, hurt_flash - delta)
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["life"] = float(effects[i]["life"]) - delta
		if float(effects[i]["life"]) <= 0.0:
			effects.remove_at(i)
	_audio_tick(delta)
	queue_redraw()


func _consume_events() -> void:
	for event: Dictionary in run.events:
		var kind: String = event["kind"]
		if kind == "hurt":
			hurt_flash = 0.20
			tone_frequency = 170.0
			tone_remaining = 0.12
		elif kind == "pickup":
			tone_frequency = 960.0 + run.xp * 25.0
			tone_remaining = 0.035
		elif kind == "defeat":
			effects.append({"pos": event["pos"], "life": 0.40, "max_life": 0.40, "kind": kind})
			tone_frequency = 420.0
			tone_remaining = 0.04
		elif kind == "hit":
			effects.append({"pos": event["pos"], "life": 0.14, "max_life": 0.14, "kind": kind})
		elif kind == "swipe":
			var swipe: Dictionary = event.duplicate()
			swipe["life"] = 0.24
			swipe["max_life"] = 0.24
			effects.append(swipe)
			tone_frequency = 235.0
			tone_remaining = 0.055
	run.events.clear()


func _unhandled_input(event: InputEvent) -> void:
	# Keep mouse emulation for GUI buttons, but never let the first touch finger
	# masquerade as a desktop attack and override the independent right stick.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			if screen == "paused":
				_resume_run()
			elif screen == "playing":
				_pause_run()
		if event.keycode == KEY_M:
			sound_on = not sound_on
	if screen != "playing":
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch.handle(event, size)
	elif event is InputEventMouseMotion:
		mouse_position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed
		mouse_position = event.position


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_on_focus_lost()


func _on_focus_lost() -> void:
	touch.clear()
	mouse_held = false
	if screen == "playing":
		_pause_run()


func _pause_run() -> void:
	run.pause()
	_sync_screen()


func _resume_run() -> void:
	run.resume()
	_sync_screen()


func _start_run() -> void:
	run.reset(0, selected_character, selected_mode, selected_scenario)
	effects.clear()
	screen = ""
	_sync_screen()


func _select_character(id: String) -> void:
	if Run.CHARACTERS.has(id):
		selected_character = id
		if id == "bear":
			selected_mode = "standard"
			selected_scenario = "normal"
		_show_title()


func _select_mode(id: String) -> void:
	if selected_character == "hedgehog" and Run.RUN_MODES.has(id):
		selected_mode = id
		if id == "standard":
			selected_scenario = "normal"
		_show_title()


func _select_scenario(id: String) -> void:
	if selected_character == "hedgehog" and selected_mode != "standard" and Run.SCENARIOS.has(id):
		selected_scenario = id
		_show_title()


func _choose_upgrade(id: String) -> void:
	if run.choose_upgrade(id):
		tone_frequency = 1200.0
		tone_remaining = 0.12
		# Chained levels may stay in upgrade state, but still need fresh choices.
		screen = ""
		_sync_screen()


func _sync_screen() -> void:
	if screen == run.state:
		return
	screen = run.state
	touch.clear()
	mouse_held = false
	_clear_overlay()
	pause_button.visible = screen == "playing"
	match screen:
		"upgrade": _show_upgrades()
		"paused": _show_pause()
		"won", "lost": _show_result()


func _clear_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
		overlay = null


func panel_style(color: Color, radius: int = 22) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _make_overlay(min_width: float = 640.0) -> VBoxContainer:
	_clear_overlay()
	overlay = ColorRect.new()
	(overlay as ColorRect).color = Color(0.035, 0.10, 0.075, 0.84)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(min_width, 0)
	panel.add_theme_stylebox_override("panel", panel_style(Color("234638"), 28))
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	return column


func _label(text: String, font_size: int = 20, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", bold_font if font_size >= 28 else font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_override("font", bold_font)
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", INK if primary else CREAM)
	button.add_theme_color_override("font_hover_color", INK if primary else CREAM)
	button.add_theme_color_override("font_pressed_color", INK if primary else CREAM)
	button.add_theme_stylebox_override("normal", panel_style(GOLD if primary else Color("345b47"), 15))
	button.add_theme_stylebox_override("hover", panel_style(Color("ffe5a4") if primary else Color("47765b"), 15))
	button.add_theme_stylebox_override("pressed", panel_style(Color("e4af54") if primary else Color("2c4f3e"), 15))
	button.pressed.connect(callback)
	return button


func _show_title() -> void:
	screen = "title"
	run.reset(0, selected_character, selected_mode, selected_scenario)
	touch.clear()
	mouse_held = false
	effects.clear()
	pause_button.hide()
	var column: VBoxContainer = _make_overlay(960)
	column.add_theme_constant_override("separation", 6)
	column.add_child(_label("BRAMBLE", 34))
	column.add_child(_label("換個陣形，試試不同本領", 18, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for id: String in ["hedgehog", "bear"]:
		var info: Dictionary = Run.CHARACTERS[id]
		var mark: String = "✓ " if id == selected_character else ""
		var button: Button = _button(mark + info["name"] + "｜" + info["style"] + "\n" + info["hint"], _select_character.bind(id), id == selected_character)
		button.custom_minimum_size.y = 76
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 18)
		row.add_child(button)
	if selected_character == "hedgehog":
		column.add_child(_label("刺蝟構築比較：A／B 各帶 4 次起始強化", 16, GOLD))
		var modes := HBoxContainer.new()
		modes.add_theme_constant_override("separation", 12)
		column.add_child(modes)
		for id: String in ["standard", "bloom", "focus"]:
			var info: Dictionary = Run.RUN_MODES[id]
			var mark: String = "✓ " if id == selected_mode else ""
			var button: Button = _button(mark + info["name"] + "\n" + info["hint"], _select_mode.bind(id), id == selected_mode)
			button.add_theme_font_size_override("font_size", 16)
			button.custom_minimum_size.y = 76
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			modes.add_child(button)
		column.add_child(_label("A：鋪開扇形，讓尖刺跳向鄰近目標  ·  B：引怪成線，連續穿透", 15, MUTED))
		if selected_mode != "standard":
			var scenarios := HBoxContainer.new()
			scenarios.add_theme_constant_override("separation", 12)
			column.add_child(scenarios)
			for id: String in ["normal", "surround", "queue"]:
				var info: Dictionary = Run.SCENARIOS[id]
				var mark: String = "✓ " if id == selected_scenario else ""
				var button: Button = _button(mark + info["name"] + "\n" + info["hint"], _select_scenario.bind(id), id == selected_scenario)
				button.add_theme_font_size_override("font_size", 16)
				button.custom_minimum_size.y = 70
				button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				scenarios.add_child(button)
			var hint: String = "短情境能力固定、不升級；橘圈預告 1 秒後出怪，可自由移動。" if selected_scenario != "normal" else "原本生存保留隨機升級；短情境可固定能力比較陣形。"
			column.add_child(_label(hint, 14, MUTED))
	else:
		column.add_child(_label("小熊 · 近距揮擊 · 自由遊玩", 18, GOLD))
	column.add_child(_label("手機：左側拖曳移動，右側拖曳瞄準並攻擊\n電腦：WASD／方向鍵移動，按住滑鼠左鍵瞄準攻擊", 15, MUTED))
	column.add_child(_button("開始 45 秒情境比較" if selected_scenario != "normal" else "出發，守住這片小森林", _start_run, true))
	column.add_child(_label("陣形比較 PoC v0.4  ·  M 靜音 / P 暫停", 14, MUTED))


func _show_pause() -> void:
	var column: VBoxContainer = _make_overlay(900)
	column.add_child(_label("喘口氣，森林會等你", 32))
	column.add_child(_label("戰鬥、計時與攻擊都已暫停。", 18, MUTED))
	_add_build_recap(column)
	column.add_child(_button("繼續冒險", _resume_run, true))
	column.add_child(_button("重新挑戰", _start_run))
	column.add_child(_button("回到起點", _show_title))


func _show_upgrades() -> void:
	var column: VBoxContainer = _make_overlay(1040)
	column.add_child(_label("長出一點新本領", 36))
	column.add_child(_label("LEVEL %02d   ·   選一項強化，再回到森林" % run.level, 18, GOLD))
	column.add_child(_label(_build_text(), 15, MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for id: String in run.offers:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(290, 0)
		card.add_theme_constant_override("separation", 15)
		row.add_child(card)
		var symbol: String = {"scatter": "⋮", "pierce": "→", "bounce": "↗", "wide": "⌒", "reach": "→", "push": "»", "damage": "+", "haste": "»", "speed": "≋"}[id]
		card.add_child(_label(symbol, 48, GOLD))
		card.add_child(_label(run.upgrade_info(id)["name"], 25))
		card.add_child(_label("已選 %d 次" % int(run.upgrades[id]), 15, MUTED))
		card.add_child(_label(run.upgrade_info(id)["desc"], 16, MUTED))
		card.add_child(_button("選擇這項", _choose_upgrade.bind(id), true))
	column.add_child(_label("戰鬥已暫停，慢慢選。", 15, MUTED))


func _show_result() -> void:
	var won: bool = screen == "won"
	var column: VBoxContainer = _make_overlay(960)
	var success_text: String = "情境完成！" if run.scenario_id != "normal" else "森林守住了！"
	column.add_child(_label(success_text if won else "先休息，再出發", 40))
	column.add_child(_label("%s · %s" % [Run.CHARACTERS[run.character_id]["name"], Run.CHARACTERS[run.character_id]["style"]], 20, MUTED))
	column.add_child(_label("存活 %s    ·    擊敗 %d    ·    等級 %d" % [_format_time(run.elapsed), run.kills, run.level], 23, GOLD))
	_add_build_recap(column)
	column.add_child(_button("帶著新點子，再玩一次", _start_run, true))
	if run.scenario_id != "normal":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		column.add_child(row)
		var build_button: Button = _button("同情境，換 A／B", _switch_comparison)
		build_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(build_button)
		var scenario_button: Button = _button("同構築，換陣形", _switch_scenario)
		scenario_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(scenario_button)
	elif run.mode_id != "standard":
		column.add_child(_button("換成另一條路線比較", _switch_comparison))
	column.add_child(_button("回到起點", _show_title))


func _switch_comparison() -> void:
	selected_mode = "focus" if run.mode_id == "bloom" else "bloom"
	selected_character = "hedgehog"
	selected_scenario = run.scenario_id
	_show_title()


func _switch_scenario() -> void:
	selected_scenario = "queue" if run.scenario_id == "surround" else "surround"
	selected_mode = run.mode_id
	selected_character = "hedgehog"
	_show_title()


func _build_text(with_source: bool = false) -> String:
	var entries: Array[String] = []
	for id: String in run.upgrade_ids():
		var total: int = int(run.upgrades[id])
		if total == 0:
			continue
		var entry: String = "%s ×%d" % [run.upgrade_info(id)["name"], total]
		if with_source:
			var starter: int = int(run.starting_upgrades.get(id, 0))
			entry += "（起始 %d／新選 %d）" % [starter, total - starter]
		entries.append(entry)
	if entries.is_empty():
		return "尚未取得強化，擊敗敵人並靠近收集星種。"
	var lines: Array[String] = []
	var per_line: int = 2 if with_source else 3
	for i in range(0, entries.size(), per_line):
		lines.append("   ·   ".join(entries.slice(i, mini(i + per_line, entries.size()))))
	return "\n".join(lines)


func _add_build_recap(column: VBoxContainer) -> void:
	if run.scenario_id != "normal":
		column.add_child(_label("%s · 45 秒 · 固定能力，不升級" % Run.SCENARIOS[run.scenario_id]["name"], 18, GOLD))
	column.add_child(_label("%s · 本局新選 %d 次" % [Run.RUN_MODES[run.mode_id]["name"], run.chosen_upgrades.size()], 18, GOLD))
	column.add_child(_label(_build_text(true), 16, MUTED))
	if run.scenario_id != "normal":
		column.add_child(_label("相同普通怪與出怪節奏；只比較陣形，站位仍會影響遭遇。", 14, MUTED))
	elif run.mode_id != "standard":
		column.add_child(_label("A／B 起始各 4 次強化；相同敵人規則，走位與升級仍會影響遭遇。", 14, MUTED))


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _draw() -> void:
	var camera: Vector2 = run.camera_origin()
	draw_rect(Rect2(Vector2.ZERO, size), Color("284b3b"))
	_draw_forest(camera)
	for point: Vector2 in run.warning_positions:
		var pos: Vector2 = point - camera
		var progress: float = 1.0 - run.warning_remaining / Run.WAVE_WARNING
		draw_circle(pos, 24.0, Color(1.0, 0.62, 0.3, 0.12))
		draw_arc(pos, 32.0, -PI * 0.5, -PI * 0.5 + maxf(0.02, progress) * TAU, 24, Color("ffbd76"), 3.0, true)
		draw_string(bold_font, pos + Vector2(-4, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD)
	for pickup: Dictionary in run.pickups:
		var pos: Vector2 = Vector2(pickup["pos"]) - camera
		draw_circle(pos, 10.0 + sin(clock * 4.0) * 1.5, Color(0.95, 0.85, 0.4, 0.13))
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -6), pos + Vector2(5, 0), pos + Vector2(0, 6), pos + Vector2(-5, 0)]), GOLD)
	for enemy: Dictionary in run.enemies:
		_draw_enemy(enemy, camera)
	for projectile: Dictionary in run.projectiles:
		var pos: Vector2 = Vector2(projectile["pos"]) - camera
		var tail: Vector2 = pos - Vector2(projectile["dir"]) * 20.0
		draw_line(tail, pos, Color(1.0, 0.85, 0.4, 0.16), 10, true)
		draw_line(tail, pos, GOLD, 3.2, true)
		draw_circle(pos, 2.5, CREAM)
	if run.character_id == "bear":
		_draw_bear(run.player - camera)
	else:
		_draw_hedgehog(run.player - camera)
	for effect: Dictionary in effects:
		var progress: float = 1.0 - float(effect["life"]) / float(effect["max_life"])
		var pos: Vector2 = Vector2(effect["pos"]) - camera
		if effect["kind"] == "swipe":
			var angle: float = Vector2(effect["dir"]).angle()
			var half_angle: float = effect["half_angle"]
			for fraction: float in [0.66, 0.83, 1.0]:
				draw_arc(pos, float(effect["reach"]) * fraction, angle - half_angle, angle + half_angle, 28,
					Color(1.0, 0.82, 0.57, (1.0 - progress) * 0.7), 5.0 * (1.0 - progress) + 1.0, true)
			continue
		var color := Color(1.0, 0.83, 0.47, 1.0 - progress)
		draw_arc(pos, 8.0 + progress * 27.0, 0, TAU, 18, color, 2.0, true)
		if effect["kind"] == "defeat":
			for i in 5:
				var point: Vector2 = pos + Vector2.RIGHT.rotated(i * TAU / 5.0) * progress * 38.0
				draw_circle(point, 3.5 * (1.0 - progress), color)
	if screen != "title":
		_draw_hud()
	if screen == "playing":
		_draw_sticks()
	if hurt_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.42, 0.29, hurt_flash * 0.8))


func _draw_forest(camera: Vector2) -> void:
	for x in range(0, int(Run.WORLD.x), 120):
		for y in range(0, int(Run.WORLD.y), 120):
			var point := Vector2(x, y) - camera
			if Rect2(Vector2(-130, -130), size + Vector2(260, 260)).has_point(point):
				draw_circle(point, 53.0, Color(0.29, 0.42, 0.29, 0.12))
	for item: Dictionary in decorations:
		var pos: Vector2 = Vector2(item["pos"]) - camera
		if not Rect2(Vector2(-20, -20), size + Vector2(40, 40)).has_point(pos):
			continue
		var radius: float = float(item["size"])
		draw_line(pos, pos + Vector2(-3, -radius * 2), Color("528263"), 2, true)
		draw_line(pos, pos + Vector2(5, -radius), Color("528263"), 2, true)
		if item["flower"]:
			draw_circle(pos + Vector2(-3, -radius * 2), 2.5, Color("c9bc8c"))
	var edge := Rect2(-camera + Vector2(14, 14), Run.WORLD - Vector2(28, 28))
	draw_rect(edge, Color("7a9b66"), false, 12.0)
	draw_rect(edge.grow(-10), Color("365c41"), false, 4.0)


func _draw_hedgehog(pos: Vector2) -> void:
	draw_set_transform(pos)
	draw_circle(Vector2(0, 15), 26.0, Color(0.02, 0.09, 0.055, 0.35))
	var blink: bool = run.invulnerability > 0.0 and int(clock * 16.0) % 2 == 0
	var body: Color = Color("f9cda1") if blink else Color("a76b43")
	for i in 13:
		var angle: float = i * TAU / 13.0
		var direction := Vector2.RIGHT.rotated(angle)
		var side := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([direction * 18.0 + side * 8.0, direction * 34.0,
			direction * 18.0 - side * 8.0]), Color("70472f"))
	draw_circle(Vector2.ZERO, 25.0, body)
	draw_circle(Vector2(-12, 19), 6.0, Color("70472f"))
	draw_circle(Vector2(12, 19), 6.0, Color("70472f"))
	var face_center: Vector2 = run.aim * 10.0 + Vector2(0, 3)
	draw_circle(face_center, 18.0, Color("f4d9a8"))
	var eyes: Vector2 = run.aim.orthogonal() * 7.0
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = face_center + run.aim * 5.0 + eyes * side
		draw_circle(eye, 2.7, Color("352f27"))
		draw_circle(eye + Vector2(-0.7, -0.8), 0.9, Color.WHITE)
		draw_circle(face_center + eyes * side * 1.6, 3.3, Color("e5a884"))
	draw_circle(face_center + run.aim * 17.0, 4.0, Color("48362c"))
	draw_set_transform(Vector2.ZERO)
	if screen == "playing":
		draw_line(pos + run.aim * 40.0, pos + run.aim * 64.0, Color(1.0, 0.9, 0.65, 0.45), 2.0, true)


func _draw_bear(pos: Vector2) -> void:
	draw_set_transform(pos)
	draw_circle(Vector2(0, 17), 29.0, Color(0.02, 0.09, 0.055, 0.35))
	var blink: bool = run.invulnerability > 0.0 and int(clock * 16.0) % 2 == 0
	var fur: Color = Color("f4d3a5") if blink else Color("c48b54")
	for x: float in [-18.0, 18.0]:
		draw_circle(Vector2(x, -19), 12, fur)
		draw_circle(Vector2(x, -19), 6.5, Color("e7b887"))
	draw_circle(Vector2.ZERO, 27.0, fur)
	for side: float in [-1.0, 1.0]:
		var paw: Vector2 = run.aim.rotated(side * 0.72) * 28.0
		draw_circle(paw, 10.0, Color("9d693f"))
		draw_circle(paw + run.aim * 2.0, 6.0, fur)
	var face: Vector2 = run.aim * 8.0
	draw_circle(face, 18.0, Color("f1d8b0"))
	var eyes: Vector2 = run.aim.orthogonal() * 8.0
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = face + run.aim * 3.0 + eyes * side
		draw_circle(eye, 2.9, INK)
		draw_circle(eye + Vector2(-0.7, -0.8), 0.9, CREAM)
	draw_circle(face + run.aim * 14.0, 5.0, Color("5c402d"))
	draw_set_transform(Vector2.ZERO)
	if screen == "playing":
		var angle: float = run.aim.angle()
		var half_angle: float = run.melee_half_angle()
		draw_arc(pos, run.melee_reach(), angle - half_angle, angle + half_angle, 32,
			Color(1.0, 0.84, 0.57, 0.22), 1.5, true)


func _draw_enemy(enemy: Dictionary, camera: Vector2) -> void:
	var pos: Vector2 = Vector2(enemy["pos"]) - camera
	if not Rect2(Vector2(-500, -500), size + Vector2(1000, 1000)).has_point(pos):
		return
	var radius: float = enemy["radius"]
	var charger: bool = enemy["kind"] == "charger"
	var body := Color("edac64") if charger else Color("ac9acc")
	if float(enemy["flash"]) > 0.0:
		body = CREAM
	if enemy["phase"] == "windup":
		var end: Vector2 = pos + Vector2(enemy["dir"]) * 285.0
		draw_line(pos, end, Color(1.0, 0.63, 0.29, 0.18), 24.0, true)
		draw_line(pos, end, Color(1.0, 0.77, 0.46, 0.8), 2.0, true)
		draw_arc(pos, radius + 8.0, 0, TAU, 24, GOLD, 2.5, true)
	draw_circle(pos + Vector2(0, 10), radius, Color(0.05, 0.1, 0.07, 0.25))
	draw_circle(pos, radius + sin(clock * 4.0 + int(enemy["id"])) * 1.2, body)
	draw_circle(pos + Vector2(-6, -2), 2.2, INK)
	draw_circle(pos + Vector2(6, -2), 2.2, INK)
	if charger:
		draw_colored_polygon(PackedVector2Array([pos + Vector2(-9, -15), pos + Vector2(0, -31), pos + Vector2(9, -15)]), Color("bd7045"))
	else:
		draw_arc(pos + Vector2(0, 4), 4, 0, PI, 8, INK, 1.3, true)
	if float(enemy["hp"]) < float(enemy["max_hp"]):
		draw_line(pos + Vector2(-radius, -radius - 8), pos + Vector2(radius, -radius - 8), Color("17362d"), 4.0)
		draw_line(pos + Vector2(-radius, -radius - 8), pos + Vector2(-radius + radius * 2.0 * float(enemy["hp"]) / float(enemy["max_hp"]), -radius - 8), GOLD, 3.0)


func _draw_hud() -> void:
	draw_style_box(panel_style(Color(0.06, 0.16, 0.12, 0.9), 18), Rect2(22, 20, 295, 76))
	draw_string(bold_font, Vector2(40, 48), Run.CHARACTERS[run.character_id]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CREAM)
	draw_string(font, Vector2(205, 48), "%d / 100" % int(run.hp), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
	draw_style_box(panel_style(Color("18382c"), 5), Rect2(40, 63, 254, 10))
	if run.hp > 0.0:
		draw_style_box(panel_style(Color("e9a47c"), 5), Rect2(40, 63, 254 * run.hp / 100.0, 10))
	draw_string(font, Vector2(40, 89), Run.CHARACTERS[run.character_id]["style"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	var trial: bool = run.scenario_id != "normal"
	var timer: float = ceilf(maxf(0.0, run.duration() - run.elapsed)) if trial else run.elapsed
	draw_string(bold_font, Vector2(size.x * 0.5 - 42, 49), _format_time(timer), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CREAM)
	draw_string(font, Vector2(size.x * 0.5 - 47, 72), "情境剩餘時間" if trial else "存活目標 03:00", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	draw_string(font, Vector2(size.x - 302, 53), "擊敗 %d  ·  Lv.%d" % [run.kills, run.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CREAM)
	var mode_name: String = Run.RUN_MODES[run.mode_id]["name"]
	var build_heading: String = "%s · %s · 能力固定" % [Run.SCENARIOS[run.scenario_id]["name"], mode_name] if trial else "%s · 本局能力（暫停可看起始／新選）" % mode_name
	draw_string(font, Vector2(40, 118), build_heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
	var lines: PackedStringArray = _build_text().split("\n")
	for i in lines.size():
		draw_string(font, Vector2(40, 142 + i * 21), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM)
	var width: float = size.x - 44.0
	if trial:
		draw_string(font, Vector2(size.x * 0.5 - 116, size.y - 35), "固定構築 · 本情境不升級", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
		return
	draw_rect(Rect2(22, size.y - 22, width, 5), Color("17382b"))
	draw_rect(Rect2(22, size.y - 22, width * clampf(float(run.xp) / run.required_xp(), 0, 1), 5), GOLD)
	draw_string(font, Vector2(size.x * 0.5 - 74, size.y - 35), "星種 %d / %d" % [run.xp, run.required_xp()], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)


func _draw_sticks() -> void:
	var left: Vector2 = touch.move_origin if touch.move_id != -1 else Vector2(120, size.y - 130)
	var right: Vector2 = touch.aim_origin if touch.aim_id != -1 else Vector2(size.x - 120, size.y - 130)
	for center: Vector2 in [left, right]:
		draw_circle(center, 65, Color(0.91, 0.95, 0.78, 0.04))
		draw_arc(center, 65, 0, TAU, 48, Color(0.91, 0.95, 0.78, 0.22), 1.5, true)
	var move_delta: Vector2 = (touch.move_point - left).limit_length(48) if touch.move_id != -1 else Vector2.ZERO
	var aim_delta: Vector2 = (touch.aim_point - right).limit_length(48) if touch.aim_id != -1 else Vector2.ZERO
	draw_circle(left + move_delta, 23, Color(0.94, 0.88, 0.68, 0.19))
	draw_circle(right + aim_delta, 23, Color(1.0, 0.8, 0.4, 0.22))
	draw_string(font, left + Vector2(-17, 93), "移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
	draw_string(font, right + Vector2(-32, 93), "瞄準攻擊", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
