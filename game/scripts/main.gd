extends Control

const Run := preload("res://scripts/run_model.gd")
const Touch := preload("res://scripts/touch_controls.gd")
const Series := preload("res://scripts/nana_series.gd")
const CREAM := Color("fff2d4")
const MUTED := Color("a9c9ae")
const GOLD := Color("ffd479")
const INK := Color("17362d")

var run = Run.new()
var series = Series.new()
var touch = Touch.new()
var font: Font
var bold_font: Font
var screen: String = "title"
var selected_character: String = "nana"
var selected_mode: String = "standard"
var selected_scenario: String = "normal"
var selected_build_abilities: Array[String] = []
var build_preview_id: int = -1
var overlay: Control
var pause_button: Button
var ultimate_button: Button
var ultimate_touches: Dictionary = {}
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
	ultimate_button = Button.new()
	ultimate_button.text = "夜影解放\n準備完成"
	ultimate_button.focus_mode = Control.FOCUS_NONE
	ultimate_button.add_theme_font_override("font", bold_font)
	ultimate_button.add_theme_font_size_override("font_size", 18)
	ultimate_button.add_theme_stylebox_override("normal", panel_style(Color("564478"), 18))
	ultimate_button.add_theme_stylebox_override("hover", panel_style(Color("725c9a"), 18))
	ultimate_button.add_theme_stylebox_override("pressed", panel_style(Color("46365e"), 18))
	ultimate_button.button_down.connect(_activate_ultimate)
	add_child(ultimate_button)
	resized.connect(_layout_hud)
	_layout_hud()
	_setup_audio()
	_show_title()
	get_window().focus_exited.connect(_on_focus_lost)


func _layout_hud() -> void:
	if is_instance_valid(pause_button):
		pause_button.position = Vector2(size.x - 126.0, 27.0)
		pause_button.size = Vector2(96, 44)
	if is_instance_valid(ultimate_button):
		ultimate_button.position = Vector2(size.x - 350.0, size.y - 260.0)
		ultimate_button.size = Vector2(150.0, 72.0)


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
	if run.experiment.active:
		run.experiment.clock(delta, run.state)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["life"] = float(effects[i]["life"]) - delta
		if float(effects[i]["life"]) <= 0.0:
			effects.remove_at(i)
	_audio_tick(delta)
	if is_instance_valid(ultimate_button) and ultimate_button.visible:
		if run.nana.ultimate_remaining > 0.0:
			ultimate_button.text = "夜影解放\n影化 %.1f 秒" % run.nana.ultimate_remaining
		elif run.nana.cooldown > 0.0:
			ultimate_button.text = "夜影解放\n冷卻 %d 秒" % int(ceilf(run.nana.cooldown))
		else:
			ultimate_button.text = "夜影解放\n準備完成"
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
		elif kind == "nana_bite" or kind == "nana_bite_windup" or kind == "nana_ultimate" or kind == "nana_shadow":
			var effect: Dictionary = event.duplicate()
			effect["life"] = 0.45 if kind == "nana_ultimate" else (0.1 if kind == "nana_bite_windup" else (0.32 if kind == "nana_shadow" else 0.22))
			effect["max_life"] = effect["life"]
			effects.append(effect)
			tone_frequency = 140.0 if kind == "nana_ultimate" else 330.0
			tone_remaining = 0.11 if kind == "nana_ultimate" else 0.05
		elif kind in ["nana_ready", "nana_charged", "nana_cash", "nana_push", "nana_cash_wave"]:
			effects.append({"pos": event.pos, "life": 0.35, "max_life": 0.35, "kind": kind, "radius": event.get("radius", 0.0)})
			tone_frequency = 920.0 if kind == "nana_ready" else (570.0 if kind == "nana_charged" else 190.0)
			tone_remaining = 0.09
	run.events.clear()


func _input(event: InputEvent) -> void:
	if screen != "playing" or run.character_id != "nana":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_activate_ultimate()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if ultimate_touches.has(event.index):
			if not event.pressed or event.canceled:
				ultimate_touches.erase(event.index)
			get_viewport().set_input_as_handled()
		elif event.pressed and not event.canceled and event.index != touch.move_id and event.index != touch.aim_id and ultimate_button.visible and ultimate_button.get_global_rect().has_point(event.position):
			ultimate_touches[event.index] = true
			_activate_ultimate()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and ultimate_touches.has(event.index):
		get_viewport().set_input_as_handled()


func _activate_ultimate() -> void:
	if screen == "playing" and run.nana.activate_ultimate(run):
		_consume_events()


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
	if run.experiment.active:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			run.experiment.input_kind = "touch"
		elif event is InputEventKey or event is InputEventMouse:
			run.experiment.input_kind = "keyboard_mouse"
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
	ultimate_touches.clear()
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
	if run.experiment.active and not run.experiment.logged:
		run.experiment.save(run, "abandoned")
	series.active = false
	run.reset(0, "nana", "standard", selected_scenario)
	run.experiment.configure(run, selected_build_abilities)
	effects.clear()
	screen = ""
	_sync_screen()


func _toggle_build_ability(id: String) -> void:
	if id in selected_build_abilities:
		selected_build_abilities.erase(id)
	elif selected_build_abilities.size() < 2:
		selected_build_abilities.append(id)
	_show_build_experiment()


func _select_build_scenario(id: String) -> void:
	selected_scenario = id
	_show_build_experiment()


func _select_build_preset(ids: Array) -> void:
	selected_build_abilities.clear()
	for id in ids:
		selected_build_abilities.append(str(id))
	_show_build_experiment()


func _show_build_experiment() -> void:
	if run.experiment.active and not run.experiment.logged:
		run.experiment.save(run, "abandoned")
	series.active = false
	screen = "title"
	selected_character = "nana"
	selected_mode = "standard"
	if not selected_scenario.begins_with("nana_build_"):
		selected_scenario = "nana_build_e1"
	touch.clear()
	mouse_held = false
	pause_button.hide()
	ultimate_button.hide()
	var column: VBoxContainer = _make_overlay(990)
	column.add_theme_constant_override("separation", 8)
	column.add_child(_label("奈奈 · 構築實驗", 30))
	column.add_child(_label("任選 0–2 個能力；同情境可重試，比較實際打法。", 16, MUTED))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	column.add_child(choices)
	for entry: Array in [["a", "穿影爪\n第三次命中，窄長爪影"], ["b", "游走蓄勢\n停手移動，命中才消耗"], ["c", "獵痕重咬\n咬中留痕，再咬兌現"]]:
		var id: String = entry[0]
		var button: Button = _button(("✓ " if id in selected_build_abilities else "") + str(entry[1]), _toggle_build_ability.bind(id), id in selected_build_abilities)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 82
		button.add_theme_font_size_override("font_size", 16)
		choices.add_child(button)
	column.add_child(_label("已裝 %d / 2　·　不選能力可作基準" % selected_build_abilities.size(), 15, GOLD))
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	column.add_child(presets)
	for preset: Array in [["基礎", []], ["A＋B", ["a", "b"]], ["A＋C", ["a", "c"]], ["B＋C", ["b", "c"]]]:
		var preset_button: Button = _button(str(preset[0]), _select_build_preset.bind(preset[1]))
		preset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preset_button.custom_minimum_size.y = 40
		preset_button.add_theme_font_size_override("font_size", 15)
		presets.add_child(preset_button)
	var situations := HBoxContainer.new()
	situations.add_theme_constant_override("separation", 8)
	column.add_child(situations)
	for id: String in ["nana_build_e1", "nana_build_e2", "nana_build_e3"]:
		var button: Button = _button(("✓ " if id == selected_scenario else "") + str(Run.SCENARIOS[id].name), _select_build_scenario.bind(id), id == selected_scenario)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 17)
		situations.add_child(button)
	column.add_child(_label("固定事件 · 最多 60 秒 · 各局獨立恢復", 15, MUTED))
	column.add_child(_button("開始實驗", _start_run, true))
	column.add_child(_button("回到起點", _show_title))


func _sync_screen() -> void:
	if series.active and run.state in ["won", "lost", "unfinished"]:
		series.collect(run)
		if series.between:
			if screen != "between":
				_show_series_between()
			return
	if screen == run.state:
		return
	screen = run.state
	touch.clear()
	ultimate_touches.clear()
	mouse_held = false
	_clear_overlay()
	pause_button.visible = screen == "playing"
	ultimate_button.visible = screen == "playing" and run.character_id == "nana"
	match screen:
		"paused": _show_pause()
		"won", "lost", "unfinished":
			if run.experiment.active:
				run.experiment.save(run, screen)
			_show_result()


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
	if run.experiment.active and not run.experiment.logged:
		run.experiment.save(run, "abandoned")
	series.active = false
	selected_character = "nana"
	selected_mode = "standard"
	selected_scenario = "nana_build_e1"
	run.reset(0, "nana", "standard", "normal")
	touch.clear()
	mouse_held = false
	effects.clear()
	pause_button.hide()
	ultimate_button.hide()
	ultimate_touches.clear()
	var column: VBoxContainer = _make_overlay(860)
	column.add_theme_constant_override("separation", 16)
	column.add_child(_label("BRAMBLE", 38))
	column.add_child(_label("奈奈 · 構築實驗", 25, GOLD))
	column.add_child(_label("選擇能力，試試不同的戰鬥方式。", 18, MUTED))
	column.add_child(_button("三連戰 · 段間構築", _show_series_setup, true))
	column.add_child(_button("選擇能力與情境", _show_build_experiment))
	column.add_child(_label("手機：左側移動，右側瞄準並攻擊；點擊按鈕釋放大絕。\n電腦：WASD／方向鍵移動，按住滑鼠攻擊，空白鍵釋放大絕。", 15, MUTED))
	column.add_child(_label("M 靜音 / P 暫停", 14, MUTED))


func _show_pause() -> void:
	var column: VBoxContainer = _make_overlay(900)
	column.add_child(_label("喘口氣，森林會等你", 32))
	column.add_child(_label("戰鬥、計時與攻擊都已暫停。", 18, MUTED))
	_add_build_recap(column)
	column.add_child(_button("繼續冒險", _resume_run, true))
	column.add_child(_button("從第一段重新挑戰" if series.active else "重新挑戰", _restart_current))
	column.add_child(_button("回到起點", _show_title))


func _show_result() -> void:
	if series.active:
		_show_series_result()
		return
	var won: bool = screen == "won"
	var column: VBoxContainer = _make_overlay(960)
	var success_text: String = "情境完成！" if run.scenario_id != "normal" else "森林守住了！"
	column.add_child(_label(success_text if won else ("時間到，尚未完成" if screen == "unfinished" else "先休息，再出發"), 40))
	column.add_child(_label("%s · %s" % [Run.CHARACTERS[run.character_id]["name"], Run.CHARACTERS[run.character_id]["style"]], 20, MUTED))
	var stats: String = "存活 %s    ·    擊敗 %d" % [_format_time(run.elapsed), run.kills]
	if run.character_id != "nana" or run.scenario_id == "nana_growth":
		stats += "    ·    等級 %d" % run.level
	column.add_child(_label(stats, 23, GOLD))
	_add_build_recap(column)
	if run.experiment.active:
		var c: Dictionary = run.experiment.counts
		column.add_child(_label("爪影 %d 次 · 蓄勢命中 %d 次 · 獵痕兌現 %d 次" % [c.shadow, c.charged, c.cash], 17, MUTED))
		if not run.experiment.logged:
			column.add_child(_label("本局觀察紀錄無法儲存", 15, Color("ffb58e")))
		var injuries: Array[String] = []
		var injury_names := {"chaser": "追逐者", "charger": "衝撞者", "guard": "守衛", "elite": "精英", "thrower_projectile": "投擲物", "unknown": "其他"}
		for source in run.combat_metrics.damage_taken:
			injuries.append("%s %d" % [injury_names.get(source, source), int(run.combat_metrics.damage_taken[source])])
		column.add_child(_label("受傷來源：" + ("、".join(injuries) if not injuries.is_empty() else "無"), 15, MUTED))
		var elites: Array = run.combat_metrics.defeats.filter(func(item): return item.kind == "elite" or item.kind == "guard")
		column.add_child(_label("強敵：" + ("、".join(elites.map(func(item): return "%s %.1f 秒" % ["精英" if item.kind == "elite" else "守衛", float(item.time) - float(item.born_at)])) if not elites.is_empty() else "尚未擊敗"), 15, MUTED))
	column.add_child(_button("帶著新點子，再玩一次", _start_run, true))
	if run.experiment.active:
		column.add_child(_button("更換能力或情境", _show_build_experiment))
	column.add_child(_button("回到起點", _show_title))


func _add_build_recap(column: VBoxContainer) -> void:
	column.add_child(_label("三連戰 · 第 %d / 3 段" % (series.stage + 1) if series.active else "奈奈構築實驗 · 固定能力", 18, GOLD))
	column.add_child(_label("能力：" + (_ability_names(run.experiment.abilities, run.experiment.levels) if not run.experiment.abilities.is_empty() else "基礎"), 16, MUTED))


func _restart_current() -> void:
	if series.active:
		_start_series(series.opening)
	else:
		_start_run()


func _ability_names(ids: Array, levels: Dictionary = {}) -> String:
	var names: Array[String] = []
	for id in ids:
		var name: String = {"a": "穿影爪", "b": "游走蓄勢", "c": "獵痕重咬"}[id]
		names.append(name + (" Lv.%d" % int(levels[id]) if levels.has(id) else ""))
	return "＋".join(names)


func _show_series_setup() -> void:
	if run.experiment.active and not run.experiment.logged:
		run.experiment.save(run, "abandoned")
	series.active = false
	screen = "title"
	touch.clear()
	ultimate_touches.clear()
	mouse_held = false
	pause_button.hide()
	ultimate_button.hide()
	var column: VBoxContainer = _make_overlay(940)
	column.add_child(_label("奈奈 · 三連戰", 32))
	column.add_child(_label("清路 → 混合威脅 → 強敵帶支援", 22, GOLD))
	column.add_child(_label("選一個開局能力；每段之後可升級、加裝或替換。\n最多裝兩個；段間恢復 25 生命，生命與大絕冷卻保留。", 17, MUTED))
	for item in [["a", "穿影爪 · 連續命中，長條穿透"], ["b", "游走蓄勢 · 停手移動，換取爆發"], ["c", "獵痕重咬 · 追擊獵物，再咬兌現"]]:
		column.add_child(_button("以「%s」開始" % item[1], _start_series.bind(str(item[0]))))
	column.add_child(_button("回到起點", _show_title))


func _start_series(ability: String) -> void:
	if run.experiment.active and not run.experiment.logged:
		run.experiment.save(run, "abandoned")
	if not series.begin(run, ability):
		return
	effects.clear()
	hurt_flash = 0.0
	screen = ""
	_sync_screen()


func _show_series_between() -> void:
	screen = "between"
	touch.clear()
	ultimate_touches.clear()
	mouse_held = false
	pause_button.hide()
	ultimate_button.hide()
	var column: VBoxContainer = _make_overlay(960)
	column.add_theme_constant_override("separation", 10)
	column.add_child(_label("第 %d 段完成" % (series.stage + 1), 30))
	var next_id: String = Series.STAGES[series.stage + 1]
	column.add_child(_label("下一段：" + str(Run.SCENARIOS[next_id].name), 22, GOLD))
	column.add_child(_label("追逐者、投擲者、衝撞者與守衛" if series.stage == 0 else "精英與持續追加的追逐者", 16, MUTED))
	column.add_child(_label("目前：" + _ability_names(run.experiment.abilities, series.levels), 16, MUTED))
	column.add_child(_label("生命 %d → %d / 100　·　大絕冷卻 %.1f 秒" % [int(run.hp), int(series.snapshot.hp), run.nana.cooldown], 18))
	column.add_child(_label("選擇期間不計時；進入下一段才恢復戰鬥。", 16, MUTED))
	column.add_child(_label("選一項：發展、加裝或替換", 18, GOLD))
	var descriptions := {"a": "爪影也向身後延伸", "b": "蓄勢推開非獵痕敵人", "c": "兌現波及附近敵人"}
	var cards := GridContainer.new()
	cards.columns = 2
	cards.add_theme_constant_override("h_separation", 8)
	cards.add_theme_constant_override("v_separation", 8)
	column.add_child(cards)
	for choice: Dictionary in series.choices():
		var text: String
		if choice.kind == "upgrade":
			text = "發展：%s Lv.2\n%s" % [_ability_names([choice.id]), descriptions[choice.id]]
		elif choice.kind == "add":
			text = "加裝：%s Lv.1\n保留現有能力" % _ability_names([choice.id])
		else:
			text = "替換：%s → %s Lv.1\n失去原能力與其進度" % [_ability_names([choice.remove]), _ability_names([choice.id])]
		var button: Button = _button(text, _advance_series.bind(choice))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 72
		button.add_theme_font_size_override("font_size", 16)
		cards.add_child(button)
	if series.save_failures > 0:
		column.add_child(_label("有 %d 段觀察紀錄無法儲存" % series.save_failures, 15, Color("ffb58e")))
	column.add_child(_button("結束本輪，回到起點", _show_title))


func _advance_series(choice: Dictionary) -> void:
	if not series.advance(run, choice):
		return
	effects.clear()
	hurt_flash = 0.0
	screen = ""
	_sync_screen()


func _show_series_result() -> void:
	var column: VBoxContainer = _make_overlay(970)
	column.add_child(_label("三連戰完成！" if run.state == "won" else ("本段時間到，三連戰結束" if run.state == "unfinished" else "這次先到這裡"), 32))
	column.add_child(_label("累計戰鬥 %.1f 秒　·　完成 %d / 3 段" % [series.total_seconds(), series.results.filter(func(row): return row.result == "won").size()], 21, GOLD))
	for row in series.results:
		var result_name: String = {"won": "完成", "lost": "失敗", "unfinished": "未完成"}[row.result]
		column.add_child(_label("第 %d 段 %s · %s\n%.1f 秒 · 剩餘生命 %d · %s" % [row.stage, result_name, _ability_names(row.abilities, row.levels), row.time, int(row.hp), "獵痕兌現 %d 次" % int(row.counts.cash)], 16, MUTED))
	if series.save_failures > 0:
		column.add_child(_label("有 %d 段觀察紀錄無法儲存" % series.save_failures, 15, Color("ffb58e")))
	column.add_child(_button("同開局，再挑戰三連戰", _start_series.bind(series.opening), true))
	column.add_child(_button("更換開局能力", _show_series_setup))
	column.add_child(_button("回到起點", _show_title))


func _format_time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _draw() -> void:
	var camera: Vector2 = run.camera_origin()
	build_preview_id = -1
	if run.experiment.active:
		var bite_reach: float = run.nana.BITE_REACH * (1.4 if run.nana.ultimate_remaining > 0.0 else 1.0)
		var preview: Dictionary = run.nana.bite_target(run, bite_reach, run.nana.BITE_HALF_ANGLE)
		if not preview.is_empty():
			build_preview_id = int(preview.id)
	draw_rect(Rect2(Vector2.ZERO, size), Color("284b3b"))
	_draw_forest(camera)
	for point: Vector2 in run.warning_positions:
		var pos: Vector2 = point - camera
		var progress: float = 1.0 - run.warning_remaining / Run.WAVE_WARNING
		draw_circle(pos, 24.0, Color(1.0, 0.62, 0.3, 0.12))
		draw_arc(pos, 32.0, -PI * 0.5, -PI * 0.5 + maxf(0.02, progress) * TAU, 24, Color("ffbd76"), 3.0, true)
		draw_string(bold_font, pos + Vector2(-4, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD)
	for spawn: Dictionary in run.encounters.pending_spawns:
		var pos: Vector2 = Vector2(spawn.pos) - camera
		draw_arc(pos, 34.0, 0.0, TAU, 32, GOLD, 3.0, true)
		draw_string(bold_font, pos + Vector2(-5, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD)
	if run.experiment.active:
		for spawn: Dictionary in run.experiment.schedule:
			if spawn.state != "warning":
				continue
			var pos: Vector2 = Vector2(spawn.pos) - camera
			draw_arc(pos, 34.0, 0.0, TAU, 32, GOLD, 3.0, true)
			draw_string(bold_font, pos + Vector2(-5, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, GOLD)
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
	for projectile: Dictionary in run.encounters.enemy_projectiles:
		var pos: Vector2 = Vector2(projectile["pos"]) - camera
		draw_circle(pos, 8.0, Color("f07870"))
		draw_arc(pos, 11.0, 0.0, TAU, 20, CREAM, 2.0, true)
	_draw_nana(run.player - camera)
	if run.experiment.active and run.nana.movement_charge >= 260.0:
		draw_arc(run.player - camera, 32.0, -PI * 0.35, PI * 0.35, 18, GOLD, 4.0, true)
	for effect: Dictionary in effects:
		var progress: float = 1.0 - float(effect["life"]) / float(effect["max_life"])
		var pos: Vector2 = Vector2(effect["pos"]) - camera
		if effect["kind"] == "swipe":
			var angle: float = Vector2(effect["dir"]).angle()
			var half_angle: float = effect["half_angle"]
			var nana_swipe: bool = effect.get("style", "") == "nana"
			for fraction: float in [0.66, 0.83, 1.0]:
				draw_arc(pos, float(effect["reach"]) * fraction, angle - half_angle, angle + half_angle, 28,
					Color(0.83, 0.72, 1.0, (1.0 - progress) * 0.7) if nana_swipe else Color(1.0, 0.82, 0.57, (1.0 - progress) * 0.7), 5.0 * (1.0 - progress) + 1.0, true)
			continue
		if effect["kind"] == "nana_ultimate":
			draw_arc(pos, float(effect["radius"]) * progress, 0, TAU, 48, Color(0.80, 0.68, 1.0, (1.0 - progress) * 0.9), 7.0, true)
			continue
		if effect["kind"] == "nana_cash_wave":
			draw_arc(pos, float(effect.radius) * (0.55 + 0.45 * progress), 0.0, TAU, 36, Color(1.0, 0.60, 0.72, (1.0 - progress) * 0.8), 4.0, true)
			continue
		if effect["kind"] == "nana_shadow":
			var axis: Vector2 = Vector2(effect.dir).normalized()
			var side := axis.orthogonal() * float(effect.width) * 0.5
			var end: Vector2 = pos + axis * float(effect.reach)
			var fade: float = 1.0 - progress
			draw_colored_polygon(PackedVector2Array([pos - side, end - side, end + side, pos + side]), Color(0.40, 0.85, 1.0, fade * 0.18))
			for stripe in [-0.65, 0.0, 0.65]:
				draw_line(pos + side * stripe, end + side * stripe, Color(0.70, 0.96, 1.0, fade * 0.85), 4.0, true)
			continue
		if effect["kind"] == "nana_bite" or effect["kind"] == "nana_bite_windup":
			var angle: float = Vector2(effect["dir"]).angle()
			var opacity: float = 0.45 if effect["kind"] == "nana_bite_windup" else 1.0 - progress
			var bite_half: float = float(effect.get("half_angle", 0.48))
			draw_arc(pos, float(effect["reach"]), angle - bite_half, angle + bite_half, 24, Color(0.95, 0.84, 1.0, opacity), 4.0, true)
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


func _draw_nana(pos: Vector2) -> void:
	draw_set_transform(pos)
	draw_circle(Vector2(0, 17), 27.0, Color(0.02, 0.09, 0.055, 0.4))
	if run.nana.ultimate_remaining > 0.0:
		draw_circle(Vector2.ZERO, 40.0, Color(0.59, 0.42, 0.82, 0.17))
		draw_arc(Vector2.ZERO, 37.0, 0, TAU, 32, Color(0.82, 0.70, 1.0, 0.8), 2.0, true)
	var blink: bool = run.invulnerability > 0.0 and int(clock * 16.0) % 2 == 0
	var fur: Color = Color("807a94") if blink else Color("25232d")
	draw_arc(Vector2(-27, 7), 16.0, -PI * 0.55, PI * 0.6, 20, fur, 8.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-21, -12), Vector2(-20, -34), Vector2(-5, -23)]), fur)
	draw_colored_polygon(PackedVector2Array([Vector2(21, -12), Vector2(20, -34), Vector2(5, -23)]), fur)
	draw_circle(Vector2.ZERO, 26.0, Color("b3a7c2"))
	draw_circle(Vector2.ZERO, 23.5, fur)
	var face: Vector2 = run.aim * 7.0
	var eyes: Vector2 = run.aim.orthogonal() * 8.0
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = face + run.aim * 4.0 + eyes * side
		draw_circle(eye, 3.5, Color("eddb8f"))
		draw_circle(eye + run.aim, 1.5, Color("201d28"))
	draw_circle(face + run.aim * 13.0, 2.5, Color("efb0b4"))
	draw_set_transform(Vector2.ZERO)
	if screen == "playing":
		for i in 3:
			var marker: Vector2 = pos + Vector2(-14.0 + i * 14.0, -44.0)
			draw_circle(marker, 4.5, Color("d9b7ff") if i < run.nana.bite_charge else Color("4a4656"))
		draw_line(pos + run.aim * 36.0, pos + run.aim * 59.0, Color(0.9, 0.8, 1.0, 0.5), 2.0, true)
		if int(run.upgrades.get("sweep", 0)) > 0 or int(run.upgrades.get("hunt", 0)) > 0:
			var hunting: bool = int(run.upgrades.get("hunt", 0)) > 0
			var reach: float = (175.0 if hunting else 145.0) * (1.4 if run.nana.ultimate_remaining > 0.0 else 1.0) * (1.0 + 0.1 * int(run.upgrades["reach"]))
			var half: float = (deg_to_rad(27.5) if hunting else deg_to_rad(70.0)) + deg_to_rad(7.5 * int(run.upgrades["wide"]))
			if not hunting and run.nana.sweep_count == 2:
				half = PI
			var angle: float = run.aim.angle()
			draw_arc(pos, reach, angle - half, angle + half, 48, Color(0.84, 0.72, 1.0, 0.35), 2.0, true)


func _draw_enemy(enemy: Dictionary, camera: Vector2) -> void:
	var pos: Vector2 = Vector2(enemy["pos"]) - camera
	if not Rect2(Vector2(-500, -500), size + Vector2(1000, 1000)).has_point(pos):
		return
	var radius: float = enemy["radius"]
	var charger: bool = enemy["kind"] == "charger"
	var body := Color("edac64") if charger else (Color("70b6bc") if enemy["kind"] == "thrower" else (Color("bc827c") if enemy["kind"] in ["guard", "elite"] else Color("ac9acc")))
	if float(enemy["flash"]) > 0.0:
		body = CREAM
	if enemy["phase"] == "windup":
		var end: Vector2 = pos + Vector2(enemy["dir"]) * (650.0 if enemy["kind"] == "thrower" else 236.5)
		if enemy["kind"] in ["guard", "elite"]:
			var a: float = Vector2(enemy["dir"]).angle()
			draw_arc(pos, 170.0, a - deg_to_rad(55.0), a + deg_to_rad(55.0), 32, GOLD, 3.0, true)
			draw_line(pos, pos + Vector2.RIGHT.rotated(a - deg_to_rad(55.0)) * 170.0, GOLD, 2.0, true)
			draw_line(pos, pos + Vector2.RIGHT.rotated(a + deg_to_rad(55.0)) * 170.0, GOLD, 2.0, true)
		else:
			draw_line(pos, end, Color(1.0, 0.63, 0.29, 0.18), 24.0, true)
			draw_line(pos, end, Color(1.0, 0.77, 0.46, 0.8), 2.0, true)
		draw_arc(pos, radius + 8.0, 0, TAU, 24, GOLD, 2.5, true)
	draw_circle(pos + Vector2(0, 10), radius, Color(0.05, 0.1, 0.07, 0.25))
	draw_circle(pos, radius + sin(clock * 4.0 + int(enemy["id"])) * 1.2, body)
	if int(enemy["id"]) == run.nana.marked_target_id:
		draw_arc(pos, radius + 10.0, 0.0, TAU, 24, Color("bdefff"), 2.0, true)
	if run.experiment.active:
		if int(enemy.id) == run.nana.prey_id and run.nana.has_prey():
			draw_arc(pos, radius + 15.0, 0.0, TAU, 28, Color("ff9eac"), 3.0, true)
			draw_string(bold_font, pos + Vector2(-7, -radius - 20), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ff9eac"))
		if build_preview_id == int(enemy.id):
			var opacity: float = 1.0 if run.nana.bite_charge == 3 or not run.nana.pending_bite.is_empty() else 0.7
			draw_arc(pos, radius + 21.0, -PI * 0.8, PI * 0.8, 24, Color(0.65, 0.95, 1.0, opacity), 4.0, true)
			draw_string(bold_font, pos + Vector2(-7, -radius - 45), "▼", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.65, 0.95, 1.0, opacity))
	if float(enemy.get("vulnerable", 0.0)) > 0.0:
		draw_arc(pos, radius + 14.0, -PI * 0.5, -PI * 0.5 + TAU * minf(1.0, float(enemy["vulnerable"]) / 2.0), 28, Color("ffb58e"), 3.0, true)
	if enemy["kind"] == "elite":
		draw_arc(pos, radius + 6.0, 0.0, TAU, 32, GOLD, 3.0, true)
		if enemy["phase"] == "second_wait":
			draw_string(bold_font, pos + Vector2(-12, -radius - 15), "Ⅱ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)
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
	draw_string(font, Vector2(205, 48), "%d / %d" % [int(run.hp), int(run.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
	draw_style_box(panel_style(Color("18382c"), 5), Rect2(40, 63, 254, 10))
	if run.hp > 0.0:
		draw_style_box(panel_style(Color("e9a47c"), 5), Rect2(40, 63, 254 * run.hp / run.max_hp, 10))
	draw_string(font, Vector2(40, 89), Run.CHARACTERS[run.character_id]["style"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	var trial: bool = run.scenario_id != "normal"
	var timer: float = ceilf(maxf(0.0, run.duration() - run.elapsed)) if trial else run.elapsed
	draw_string(bold_font, Vector2(size.x * 0.5 - 42, 49), _format_time(timer), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CREAM)
	draw_string(font, Vector2(size.x * 0.5 - 65, 72), "存活並擊敗精英" if run.scenario_id == "nana_growth" else (("生存挑戰 · 剩餘時間" if run.scenario_id.begins_with("nana_pressure_") else "清除敵人 · 剩餘時間") if trial and run.character_id == "nana" else ("情境剩餘時間" if trial else "存活目標 03:00")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	var score: String = "擊敗 %d" % run.kills if run.character_id == "nana" else "擊敗 %d  ·  Lv.%d" % [run.kills, run.level]
	draw_string(font, Vector2(size.x - 302, 53), score, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CREAM)
	if run.character_id == "nana":
		draw_string(font, Vector2(40, 118), "重咬準備 %d / 3" % run.nana.bite_charge, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
		draw_string(font, Vector2(40, 142), "Lv.%d  經驗 %d / %d" % [run.level, run.xp, run.required_xp()] if run.scenario_id == "nana_growth" else "連抓命中累積 · 朝目標重咬", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM)
		if run.experiment.active:
			if "a" in run.experiment.abilities:
				draw_string(font, Vector2(40, 166), "穿影 Lv.%d ◇ %d / 3" % [run.experiment.levels.get("a", 1), run.nana.shadow_count], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9deaff"))
			if "b" in run.experiment.abilities:
				draw_string(font, Vector2(40, 190), "蓄勢 Lv.%d %d%%" % [run.experiment.levels.get("b", 1), int(100.0 * run.nana.movement_charge / 260.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
			if "c" in run.experiment.abilities:
				draw_string(font, Vector2(40, 214), "獵痕 Lv.%d：%s" % [run.experiment.levels.get("c", 1), "追蹤中" if run.nana.has_prey() else "等待重咬"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ff9eac"))
			if "b" in run.experiment.abilities and "c" in run.experiment.abilities:
				draw_string(font, Vector2(40, 238), "蓄勢命中獵痕可蓄滿重咬", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
			draw_string(font, Vector2(size.x * 0.5 - 105, size.y - 35), "三連戰 · 第 %d / 3 段" % (series.stage + 1) if series.active else "構築實驗 · 固定能力", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
			return
		if int(run.upgrades.get("sweep", 0)) > 0:
			draw_string(font, Vector2(40, 165), "環掃：下一擊！" if run.nana.sweep_count == 2 else "環掃準備 %d / 3" % run.nana.sweep_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
		elif int(run.upgrades.get("hunt", 0)) > 0:
			draw_string(font, Vector2(40, 165), "點殺：每次只攻擊一隻", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
		var hint: String = "奈奈手感練習 · 固定能力"
		if run.scenario_id == "nana_growth":
			hint = "精英已擊敗 · 堅持到時間結束" if run.encounters.elite_defeated else ("精英已登場" if run.encounters.elite_scheduled else "精英將在後段登場")
		draw_string(font, Vector2(size.x * 0.5 - 105, size.y - 35), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, MUTED)
		return


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
