extends Control
## X1 「奈奈夜巡」 entry: title, setup, map, battle, rewards, results, collection and settings.
## Rules live in scripts/x1/core; presentation (world, HUD, sound, music, haptics, camera, time)
## lives in scripts/x1/present. This script owns the screen flow, input and save points.

const UI := preload("res://scripts/x1/ui/theme.gd")
const Data := preload("res://scripts/x1/core/data.gd")
const Run := preload("res://scripts/x1/core/run.gd")
const Profile := preload("res://scripts/x1/core/profile.gd")
const Progress := preload("res://scripts/x1/core/progress.gd")
const Touch := preload("res://scripts/x1/ui/touch_input.gd")
const MapView := preload("res://scripts/x1/ui/map_view.gd")
const Wipe := preload("res://scripts/x1/ui/wipe.gd")
const ChestIcon := preload("res://scripts/x1/ui/chest_icon.gd")
const WorldView := preload("res://scripts/x1/present/world_view.gd")
const Hud := preload("res://scripts/x1/present/hud.gd")
const AudioDirector := preload("res://scripts/x1/present/audio_director.gd")
const MusicDirector := preload("res://scripts/x1/present/music_director.gd")
const TimeController := preload("res://scripts/x1/present/time_controller.gd")
const CameraRig := preload("res://scripts/x1/present/camera_rig.gd")
const Haptics := preload("res://scripts/x1/present/haptics.gd")
const Director := preload("res://scripts/x1/present/feedback_director.gd")

const HABIT_ORDER := ["shadow", "roam", "hunt"]
const STICK_SIZES := {"small": 60.0, "medium": 72.0, "large": 90.0}
const KIND_NAMES := {"hunt": "狩獵", "den": "獵物巢", "boss": "守關", "practice": "練習場"}
const QUALITY := ["low", "medium", "high"]

var data
var profile = null
var run = null
var world
var hud
var audio
var music
var wipe
var time = TimeController.new()
var camera = CameraRig.new()
var haptics = Haptics.new()
var director = Director.new()
var touch = Touch.new()
var overlay: Control = null
var screen := "title"
var pause_button: Button
var ult_button: Button
var ult_touches: Dictionary = {}
var ult_request := false
var mouse_pos := Vector2.ZERO
var mouse_aiming := false
var mouse_pounce := false
var keyboard_pounce := false
var setup: Dictionary = {}
var snapshot_clock := 0.0
var report: Dictionary = {}
var save_notice := ""
var shop_pick_index := -1
var collection_tab := "items"
var tutorial_flags: Dictionary = {}
var autosave_enabled := true
var instant := false             # tests: skip walk animations and card delays
var level_delay := 0.0
var current_battle = null
var perf_window: Array = []
var perf_lowered := false
var last_aim := false


func _ready() -> void:
	data = Data.shared()
	if profile == null: profile = Profile.new()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world = WorldView.new()
	world.visible = false
	add_child(world)
	hud = Hud.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.touch = touch
	hud.visible = false
	add_child(hud)
	audio = AudioDirector.new()
	add_child(audio)
	audio.setup(data.feel)
	music = MusicDirector.new()
	add_child(music)
	music.setup(data.feel, audio)
	camera.setup(data.feel.get("camera", {}))
	haptics.setup(data.feel, "medium")
	time.hitstop_cap = float(data.feel.get("limits", {}).get("hitstop_cap", 0.15))
	time.min_scale = float(data.feel.get("limits", {}).get("slowmo_min_scale", 0.2))
	director.setup(data.feel, {"time": time, "camera": camera, "world": world, "hud": hud, "audio": audio, "music": music, "haptics": haptics})
	pause_button = UI.button("暫停 Ⅱ", _pause, false, 17, 44)
	add_child(pause_button)
	ult_button = UI.button("", func(): ult_request = true, false, 18, 96)
	var clear := StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]: ult_button.add_theme_stylebox_override(state, clear)
	add_child(ult_button)
	wipe = Wipe.new()
	add_child(wipe)
	UI.press_hook = func():
		audio.play("click")
		haptics.play("tick")
	resized.connect(_layout)
	_layout()
	_apply_settings()
	get_window().focus_exited.connect(_on_focus_lost)
	_show_title()


func _layout() -> void:
	pause_button.position = Vector2(size.x - 124.0, 22.0)
	pause_button.size = Vector2(100, 44)
	ult_button.position = Vector2(size.x - 340.0, size.y - 320.0)
	ult_button.size = Vector2(110.0, 110.0)


func _settings() -> Dictionary:
	return profile.data.settings


func _apply_settings() -> void:
	var settings: Dictionary = _settings()
	touch.radius = float(STICK_SIZES.get(str(settings.get("controls", "medium")), 72.0))
	touch.deadzone = float(data.tuning.pounce.deadzone)
	audio.set_volumes(float(settings.get("music_volume", 0.6)), float(settings.get("sfx_volume", 0.8)))
	var applied: Dictionary = settings.duplicate()
	if perf_lowered: applied.effects = QUALITY[maxi(0, QUALITY.find(str(settings.get("effects", "high"))) - 1)]
	director.apply_settings(applied)


func _move_to_top(node: Node) -> void:
	move_child(node, get_child_count() - 1)


# ---- frame loop -------------------------------------------------------------------------------

func _process(delta: float) -> void:
	advance_frame(delta)


## One rendered frame: fixed simulation steps through the time controller, then presentation.
func advance_frame(delta: float) -> void:
	haptics.process(delta)
	var in_battle: bool = screen == "battle" and run != null and run.phase == "battle" and run.battle != null
	pause_button.visible = in_battle
	ult_button.visible = in_battle
	if not in_battle: return
	var b = run.battle
	if b != current_battle: _begin_battle_view(b)
	b.view_size = size
	if run.needs_level_choice():
		level_delay -= delta
		time.advance(delta)   # let slow motion and hit-stop run out; no simulation while choosing
		_present(delta, b)
		if level_delay <= 0.0 or instant: _show_cards()
		return
	var steps: int = time.advance(delta)
	var input := _gather_input(b)
	var ended := false
	for i in steps:
		if i == steps - 1: world.capture()
		ended = run.tick(TimeController.STEP, input) or ended
		input.pounce = Vector2.ZERO
		input.ult = false
		director.process(b.take_events(), b, run)
		if run.phase != "battle" or run.needs_level_choice(): break
	director.frame(delta, b, run)
	_tutorial(b)
	_present(delta, b)
	_watch_performance(delta)
	if run.needs_level_choice():
		level_delay = 0.0 if instant else 0.35
		return
	snapshot_clock += delta
	if snapshot_clock >= float(data.tuning.save.battle_snapshot_every) and not ended:
		snapshot_clock = 0.0
		_save_active()
	if ended or run.phase != "battle":
		if run.phase == "result" and not run.won: director.cue("lost", b.player.pos)
		_sync()


func _present(delta: float, b) -> void:
	var lead: Vector2 = Vector2(b.pounce.dash.dir) if b.dashing() else (b.player.move_dir if touch.movement().length_squared() > 0.01 or _keys().length_squared() > 0.0 else Vector2.ZERO)
	var near := 0
	for e: Dictionary in b.enemies:
		if e.pos.distance_squared_to(b.player.pos) < 300.0 * 300.0: near += 1
	camera.update(delta, b.player.pos, lead, b.dashing(), clampf(near / 40.0, 0.0, 1.0))
	world.transform = camera.world_transform(size, b.world)
	world.alpha = time.alpha()
	world.time_scale = time.current_scale()
	director.view_size = size
	hud.world_xf = world.transform
	hud.ult_rect = Rect2(ult_button.position, ult_button.size)
	var aim := Vector2.ZERO
	if touch.aiming(): aim = touch.aim_direction()
	elif mouse_aiming:
		var offset: Vector2 = mouse_pos - camera.world_to_screen(size, b.world, b.player.pos)
		if offset.length() > 24.0: aim = offset.normalized()
	if touch.aiming() and not last_aim: haptics.play("tick")
	last_aim = touch.aiming()
	world.aim_dir = aim


func _begin_battle_view(b) -> void:
	current_battle = b
	world.set_battle(b)
	hud.reset_battle(b, run)
	director.reset_battle(run)
	camera.snap(b.player.pos)
	world.visible = true
	hud.visible = true
	music.play_region(run.region_id, "battle")
	var region_name: String = data.regions[run.region_id].name
	if not instant: wipe.play(KIND_NAMES.get(b.kind, ""), region_name if b.kind != "practice" else "三分鐘自由練習")
	_move_to_top(wipe)


func _keys() -> Vector2:
	return Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))


func _gather_input(b) -> Dictionary:
	var move: Vector2 = touch.movement()
	var keys := _keys()
	if keys.length_squared() > 0.0: move = keys.normalized()
	var pounce: Vector2 = touch.take_pounce()
	if mouse_pounce:
		mouse_pounce = false
		var offset: Vector2 = mouse_pos - camera.world_to_screen(size, b.world, b.player.pos)
		if offset.length() > 8.0: pounce = offset.normalized()
	if keyboard_pounce:
		keyboard_pounce = false
		pounce = move.normalized() if move.length_squared() > 0.01 else Vector2(b.player.facing)
	var ult := ult_request
	ult_request = false
	return {"move": move, "pounce": pounce, "ult": ult}


## Auto quality: if frames stay slow for a while, lower the effect tier once and say so.
func _watch_performance(delta: float) -> void:
	var cfg: Dictionary = data.feel.get("performance", {})
	perf_window.append(delta)
	var window_frames := int(float(cfg.get("window", 2.0)) * 60.0)
	if perf_window.size() > window_frames: perf_window.pop_front()
	var total := 0.0
	for v in perf_window: total += float(v)
	var average_ms: float = total / maxf(1.0, perf_window.size()) * 1000.0
	if _settings().get("perf_overlay", false):
		var draw_total: float = hud.draw_ms
		for key in world.draw_ms: draw_total += float(world.draw_ms[key])
		hud.perf_text = "%.1f ms · %d fps · 繪製 %.1f ms · 敵 %d · 粒子 %d · %s" % [average_ms, Engine.get_frames_per_second(), draw_total, run.battle.enemies.size() if run.battle != null else 0, world.fx.particles.size(), world.fx.quality]
	else:
		hud.perf_text = ""
	if perf_lowered or perf_window.size() < window_frames or OS.is_debug_build() and not OS.has_feature("mobile"): return
	if average_ms > float(cfg.get("frame_budget_ms", 20.0)) and str(_settings().get("effects", "high")) != "low":
		perf_lowered = true
		_apply_settings()
		hud.show_hint("畫面有點吃力，已自動降低一級特效（可在設定調整）", 3.0)


func _tutorial(b) -> void:
	if not run.tutorial or b.kind == "practice": return
	var steps := [
		["move", 0.6, "左手拖曳移動。爪子會自動抓身邊的敵人。"],
		["pounce", 4.5, "右手拖曳、放開：撲出去！撲擊途中不會受傷，落地會咬一口。"],
	]
	for entry: Array in steps:
		if not tutorial_flags.has(entry[0]) and b.elapsed >= float(entry[1]):
			tutorial_flags[entry[0]] = true
			hud.show_hint(str(entry[2]), 5.0)
	if not tutorial_flags.has("prey"):
		for e: Dictionary in b.enemies:
			if e.get("target", false):
				tutorial_flags["prey"] = true
				hud.show_hint("頭上有 ◆ 的是目標獵物。全部打倒就能收網、結束這場。", 5.0)
				break
	if not tutorial_flags.has("ult") and b.ult_ready():
		tutorial_flags["ult"] = true
		hud.show_hint("夜影解放充滿了！按右下的圓形按鈕（或空白鍵）突破包圍。", 5.0)


# ---- input ------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if screen != "battle": return
	if event is InputEventScreenTouch:
		if ult_touches.has(event.index):
			if not event.pressed or event.canceled: ult_touches.erase(event.index)
			get_viewport().set_input_as_handled()
		elif event.pressed and ult_button.visible and event.index != touch.move_id and event.index != touch.aim_id \
				and ult_button.get_global_rect().has_point(event.position):
			ult_touches[event.index] = true
			ult_request = true
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and ult_touches.has(event.index):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_P:
				if screen == "battle": _pause()
				elif screen == "pause": _resume()
			KEY_SPACE:
				if screen == "battle": ult_request = true
			KEY_J, KEY_K, KEY_SHIFT:
				if screen == "battle": keyboard_pounce = true
			KEY_M:
				var muted: bool = float(_settings().get("sfx_volume", 0.8)) <= 0.0 and float(_settings().get("music_volume", 0.6)) <= 0.0
				profile.set_setting("sfx_volume", 0.8 if muted else 0.0)
				profile.set_setting("music_volume", 0.6 if muted else 0.0)
				_apply_settings()
			KEY_F3:
				profile.set_setting("perf_overlay", not _settings().get("perf_overlay", false))
			KEY_F5:
				if OS.is_debug_build(): _debug_reload()
	if screen != "battle": return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch.handle(event, size)
	elif event is InputEventMouseMotion:
		mouse_pos = event.position
		mouse_aiming = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_pos = event.position
		mouse_pounce = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: _on_focus_lost()


## The button hook is static; drop it with the scene so nothing calls into a freed scene and the
## lambda is not left for engine shutdown to free (that crashed headless runs at exit).
func _exit_tree() -> void:
	UI.press_hook = Callable()


func _on_focus_lost() -> void:
	touch.clear()
	ult_touches.clear()
	if screen == "battle": _pause()


func _debug_reload() -> void:
	data = Data.reload_data()
	if run != null:
		run.data = data
		run.build.data = data
		if run.phase == "battle": run._start_battle(run.node_kind)
	audio.setup(data.feel)
	director.setup(data.feel, {"time": time, "camera": camera, "world": world, "hud": hud, "audio": audio, "music": music, "haptics": haptics})
	camera.setup(data.feel.get("camera", {}))
	world.fx.setup(data.feel)
	_apply_settings()
	hud.show_hint("已重新載入資料檔（F5）", 2.0)


# ---- screens --------------------------------------------------------------------------------------

func _clear() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _open(width := 760.0, dim := 0.84) -> VBoxContainer:
	_clear()
	var column: VBoxContainer = UI.overlay(self, width, dim)
	overlay = column.get_parent().get_parent().get_parent().get_parent()
	move_child(overlay, get_child_count() - 1)
	_move_to_top(wipe)
	if not save_notice.is_empty(): column.add_child(UI.label(save_notice, 15, UI.DANGER))
	var box: Control = column.get_parent().get_parent()
	box.pivot_offset = box.custom_minimum_size * 0.5
	if not instant:
		box.scale = Vector2(0.94, 0.94)
		box.modulate.a = 0.0
		var tween := box.create_tween().set_parallel()
		tween.tween_property(box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(box, "modulate:a", 1.0, 0.12)
	return column


func _sync() -> void:
	if run == null:
		_show_title()
		return
	var battling: bool = run.phase == "battle"
	world.visible = battling or (run.phase == "card" and current_battle != null and run.battle != null)
	hud.visible = world.visible
	if not battling and run.battle == null and current_battle != null:
		current_battle = null
		if not instant: wipe.play()
		music.play_region(run.region_id, "menu")
	match run.phase:
		"battle":
			screen = "battle"
			_clear()
		"map":
			_save_active()
			_show_map()
		"card":
			_save_active()
			_show_cards()
		"bed":
			_save_active()
			_show_bed()
		"upgrade_pick": _show_upgrade_pick()
		"shop":
			_save_active()
			_show_shop()
		"moon":
			_save_active()
			_show_moon()
		"item":
			_save_active()
			_show_items()
		"supply": _show_supply()
		"result": _finish_run()


func _save_active() -> bool:
	if run == null or run.practice or run.phase == "result" or not autosave_enabled: return true
	if profile.save_active(run.to_dict()):
		save_notice = ""
		return true
	save_notice = "尚未保存：%s（下一步會再試）" % profile.last_error
	return false


func _show_title() -> void:
	screen = "title"
	run = null
	current_battle = null
	world.visible = false
	hud.visible = false
	music.play_region("courtyard", "menu")
	var column := _open(720)
	column.add_child(UI.label("BRAMBLE · 奈奈夜巡", 40))
	column.add_child(UI.label("撲向今晚的獵物，把家裡的東西找回來", 19, UI.GOLD))
	if profile.load_failed:
		column.add_child(UI.label(profile.last_error + "。可以先玩練習場；原本的存檔不會被覆蓋。", 17, UI.DANGER))
		column.add_child(UI.button("重新讀取存檔", func():
			profile.load_profile()
			_show_title()))
	if not profile.notice.is_empty(): column.add_child(UI.label(profile.notice, 15, UI.MUTED))
	if not profile.load_failed and not profile.data.active.is_empty():
		column.add_child(UI.button("繼續夜巡", _continue_run, true))
	if not profile.load_failed:
		column.add_child(UI.button("出發夜巡", _show_setup, profile.data.active.is_empty()))
	column.add_child(UI.button("練習場", _show_practice))
	if not profile.load_failed:
		column.add_child(UI.button("收藏與紀錄", _show_collection))
		column.add_child(UI.button("設定", _show_settings))
	if OS.is_debug_build():
		column.add_child(UI.button("（開發）舊版 v0.20", func(): get_tree().change_scene_to_file("res://r1_main.tscn"), false, 16, 40))
	column.add_child(UI.label("左手移動；爪子自動攻擊。右手拖曳後放開撲擊；夜影充滿時按右下按鈕。\n電腦：WASD 移動、滑鼠左鍵朝游標撲擊、空白鍵夜影、P 暫停。", 14, UI.MUTED))


func _continue_run() -> void:
	var restored = Run.new()
	if not restored.from_dict(profile.data.active):
		var column := _open(640)
		column.add_child(UI.label("這份進行中的夜巡無法讀取（可能來自不同版本）。", 18, UI.DANGER))
		column.add_child(UI.button("放棄這局並回到首頁", func():
			profile.clear_active()
			_show_title()))
		column.add_child(UI.button("回到首頁", _show_title))
		return
	run = restored
	tutorial_flags.clear()
	if run.phase == "battle":
		_pause()
		return
	_sync()


# ---- setup ----------------------------------------------------------------------------------------

func _default_setup() -> Dictionary:
	var last: Dictionary = profile.data.last_setup
	var region: String = str(last.get("region", "courtyard"))
	if not data.regions.has(region) or not profile.region_unlocked(region): region = "courtyard"
	return {"region": region, "habit": str(last.get("habit", "shadow")), "night": mini(int(last.get("night", 0)), profile.max_night(region))}


func _show_setup() -> void:
	if not profile.data.active.is_empty():
		var column := _open(640)
		column.add_child(UI.label("還有一局夜巡沒完成。開始新的一局會放棄它（收藏不受影響）。", 19))
		column.add_child(UI.button("繼續原本那局", _continue_run, true))
		column.add_child(UI.button("放棄並重新出發", func():
			if profile.clear_active(): _show_setup()))
		column.add_child(UI.button("返回", _show_title))
		return
	if setup.is_empty(): setup = _default_setup()
	screen = "setup"
	var column := _open(980)
	column.add_child(UI.label("準備出發", 32))
	column.add_child(UI.label("夜巡地點", 17, UI.MUTED))
	var regions := UI.row(column)
	for id: String in data.region_order():
		var region: Dictionary = data.regions[id]
		var open: bool = profile.region_unlocked(id)
		var text: String = region.name if open else "%s（打倒%s守關後開放）" % [region.name, data.regions[region.requires].name]
		var button: Button = UI.expand(UI.button(text, func():
			setup.region = id
			setup.night = mini(int(setup.night), profile.max_night(id))
			_show_setup(), setup.region == id, 17, 46))
		button.disabled = not open
		regions.add_child(button)
	column.add_child(UI.label(str(data.regions[setup.region].intro), 15, UI.MUTED))
	column.add_child(UI.label("習性", 17, UI.MUTED))
	var habits := UI.row(column)
	for id: String in HABIT_ORDER:
		habits.add_child(UI.expand(UI.button(str(data.habits[id].title), func():
			setup.habit = id
			_show_setup(), setup.habit == id, 18, 46)))
	column.add_child(UI.label(str(data.habits[setup.habit].desc), 15, UI.CREAM))
	var equip: Dictionary = profile.data.equip
	for slot: String in ["habit", "charm"]:
		column.add_child(UI.label("習慣寶物（只對對應習性有效）" if slot == "habit" else "隨身小物", 17, UI.MUTED))
		var slot_row := UI.row(column, 8)
		slot_row.add_child(UI.expand(UI.button("空", func(): _equip(slot, ""), str(equip.get(slot, "")).is_empty(), 15, 42)))
		for id: String in profile.data.owned:
			var item: Dictionary = data.items[id]
			if item.slot != slot: continue
			var text: String = item.name
			if slot == "habit": text += "（%s）" % data.habits[item.habit].name
			slot_row.add_child(UI.expand(UI.button(text, func(): _equip(slot, id), equip.get(slot, "") == id, 15, 42)))
		var chosen: String = str(equip.get(slot, ""))
		if not chosen.is_empty():
			var note: String = str(data.items[chosen].desc)
			if slot == "habit" and data.items[chosen].habit != setup.habit: note = "這局選的不是對應習性，%s本局不生效。" % data.items[chosen].name
			column.add_child(UI.label(note, 14, UI.GOLD))
	var max_night: int = profile.max_night(setup.region)
	var night_row := UI.row(column)
	night_row.add_child(UI.button("－", func():
		setup.night = maxi(0, int(setup.night) - 1)
		_show_setup(), false, 20, 44))
	night_row.add_child(UI.label("夜深 %d%s" % [int(setup.night), "（標準）" if int(setup.night) == 0 else ""], 20, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, false))
	night_row.add_child(UI.button("＋", func():
		setup.night = mini(max_night, int(setup.night) + 1)
		_show_setup(), false, 20, 44))
	for line: String in data.night_desc(int(setup.night)):
		column.add_child(UI.label("・" + line, 14, UI.MUTED))
	if max_night == 0: column.add_child(UI.label("打倒這裡的守關後可以挑戰更深的夜。", 14, UI.MUTED))
	var target: String = str(profile.data.target)
	column.add_child(UI.label("尋寶目標：%s" % (data.items[target].name if not target.is_empty() else "沒有指定（寶箱隨機）"), 15, UI.MUTED))
	var assist: bool = profile.data.settings.get("assist", false)
	column.add_child(UI.label("輔助模式：%s（可在設定切換）" % ("開，敵方傷害 ×0.75" if assist else "關"), 14, UI.MUTED))
	var bottom := UI.row(column)
	bottom.add_child(UI.expand(UI.button("返回", _show_title)))
	bottom.add_child(UI.expand(UI.button("出發！", _start_run, true)))


func _equip(slot: String, id: String) -> void:
	if not profile.set_equip(slot, id): save_notice = "裝備沒有保存：%s" % profile.last_error
	_show_setup()


func _start_run() -> void:
	profile.remember_setup(setup)
	run = Run.new()
	var equip: Dictionary = profile.data.equip
	run.begin({"seed": randi(), "region": setup.region, "habit": setup.habit, "equip": equip, "night": int(setup.night),
		"assist": profile.data.settings.get("assist", false), "unlocked": profile.unlocked_cards(), "owned": profile.data.owned,
		"target": profile.data.target, "tutorial": not profile.data.tutorial_done,
		"bell_guarantee": not profile.data.bell_given and not profile.owned("H03"),
		"view_size": size})
	tutorial_flags.clear()
	snapshot_clock = 0.0
	_sync()


func _show_practice() -> void:
	screen = "practice"
	var column := _open(760)
	column.add_child(UI.label("練習場", 32))
	column.add_child(UI.label("三分鐘不停湧出的敵人，可以升級；不影響收藏與紀錄。", 16, UI.MUTED))
	for id: String in HABIT_ORDER:
		column.add_child(UI.button("%s：%s" % [data.habits[id].title, data.habits[id].desc], func(): _start_practice(id), false, 15, 64))
	column.add_child(UI.button("返回", _show_title))


func _start_practice(habit: String) -> void:
	run = Run.new()
	var unlocked: Array = profile.unlocked_cards() if not profile.load_failed else []
	run.begin({"seed": randi(), "region": "courtyard", "habit": habit, "practice": true, "unlocked": unlocked,
		"assist": profile.data.settings.get("assist", false), "view_size": size})
	tutorial_flags.clear()
	_sync()


# ---- map and nodes ---------------------------------------------------------------------------------

func _show_map() -> void:
	screen = "map"
	_clear()
	var back := ColorRect.new()
	back.color = Color(str(data.regions[run.region_id].palette.ground)).darkened(0.35)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	overlay = back
	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 10)
	back.add_child(layout)
	var map_box := VBoxContainer.new()
	map_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(map_box)
	map_box.add_child(UI.label("%s · 夜深 %d" % [data.regions[run.region_id].name, run.night], 24))
	map_box.add_child(UI.label("選一個亮著的地點前進。狩獵與獵物巢是戰鬥；貓窩休息，主人房間買東西，月光是事件。", 14, UI.MUTED))
	if not run.notice.is_empty(): map_box.add_child(UI.label(run.notice, 15, UI.GOLD))
	if not save_notice.is_empty(): map_box.add_child(UI.label(save_notice, 14, UI.DANGER))
	var map_view = MapView.new()
	map_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map_box.add_child(map_view)
	map_view.audio = audio
	map_view.build(run, func(id: String):
		var go := func():
			run.enter(id)
			snapshot_clock = 0.0
			_sync()
		if instant: go.call()
		else: map_view.walk(id, go))
	var side := PanelContainer.new()
	side.custom_minimum_size = Vector2(330, 0)
	side.add_theme_stylebox_override("panel", UI.panel(UI.PANEL, 0, 16))
	layout.add_child(side)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	side.add_child(info)
	info.add_child(UI.label("奈奈 · %s" % data.habits[run.habit].title, 20))
	info.add_child(UI.label("生命 %d / %d" % [ceili(run.hp), int(run.max_hp())], 16, Color("e9a47c"), HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(UI.label("Lv.%d · 小魚乾 %d · 刷新 %d" % [run.level, run.fish, run.build.rerolls], 15, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(UI.label("本能卡 %d / %d" % [run.build.order.size(), int(data.tuning.build.slots)], 16, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	for id: String in run.build.order:
		var card: Dictionary = data.cards[id]
		var level_text: String = "進化" if id.begins_with("EV") else "Lv.%d" % int(run.build.cards[id])
		info.add_child(UI.label("%s %s · %s" % ["【%s】" % data.categories[card.category].name, card.name, level_text], 15, Color(str(data.categories[card.category].color)), HORIZONTAL_ALIGNMENT_LEFT))
	for id: String in run.build.eligible_evolutions():
		info.add_child(UI.label("可進化：%s（下次升級出現）" % data.cards[id].name, 14, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	var items: Array = run.build.items.map(func(i): return data.items[i].name)
	if not items.is_empty(): info.add_child(UI.label("寶物：" + "、".join(items), 14, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	if not run.new_items.is_empty(): info.add_child(UI.label("新收藏：" + "、".join(run.new_items.map(func(i): return data.items[i].name)), 14, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	info.add_child(UI.button("保存並回到首頁", func():
		_save_active()
		_show_title(), false, 16, 44))


func _card_button(id: String, callback: Callable) -> Button:
	var card: Dictionary = data.cards[id]
	var category: Dictionary = data.categories[card.category]
	var lines: Array = []
	if id.begins_with("EV"):
		lines.append("✦ 進化 · %s" % card.name)
		lines.append(str(card.desc[0]))
	else:
		var level: int = int(run.build.cards.get(id, 0))
		lines.append("【%s】%s%s" % [category.name, card.name, "（稀有）" if card.rarity == "rare" else ""])
		lines.append("新卡 Lv.1" if level == 0 else "Lv.%d → Lv.%d" % [level, level + 1])
		lines.append(str(card.desc[mini(level, card.desc.size() - 1)]))
	var button: Button = UI.button("\n".join(lines), callback, id.begins_with("EV"), 16, 170)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(250, 170)
	var tint := Color(str(category.color))
	var normal := UI.panel(tint.darkened(0.55) if not id.begins_with("EV") else UI.GOLD, 16, 12)
	normal.border_color = tint if card.get("rarity", "") != "rare" else UI.GOLD
	normal.set_border_width_all(2 if card.get("rarity", "") != "rare" else 4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", UI.panel(tint.darkened(0.4) if not id.begins_with("EV") else Color("ffe5a4"), 16, 12))
	if card.get("rarity", "") == "rare" or id.begins_with("EV"):
		var pulse := button.create_tween().set_loops()
		pulse.tween_property(button, "self_modulate", Color(1.15, 1.1, 0.95), 0.6)
		pulse.tween_property(button, "self_modulate", Color.WHITE, 0.6)
	return button


func _show_cards() -> void:
	screen = "card"
	var titles := {"level": "升級！選一張本能卡", "reward": "獵物巢的獎勵", "event": "月光下的收穫"}
	var column := _open(900, 0.7)
	column.add_child(UI.label(titles.get(run.choice_context, "選一張卡"), 28))
	column.add_child(UI.label("卡片格 %d / %d" % [run.build.order.size(), int(data.tuning.build.slots)], 15, UI.MUTED))
	var cards := UI.row(column, 14)
	var index := 0
	for id: String in run.build.offers:
		var button := _card_button(id, func():
			var evolution := id.begins_with("EV")
			run.choose_card(id)
			if evolution: _evolution_moment(id)
			_after_card())
		cards.add_child(UI.expand(button))
		if not instant:
			button.modulate.a = 0.0
			button.scale = Vector2(0.1, 1.0)
			var tween := button.create_tween()
			tween.tween_interval(0.06 + index * 0.09)
			tween.tween_callback(func(): audio.play("card", float(index) * 2.0))
			tween.set_parallel()
			tween.tween_property(button, "modulate:a", 1.0, 0.12)
			tween.tween_property(button, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		index += 1
	var actions := UI.row(column)
	var reroll: Button = UI.expand(UI.button("刷新（剩 %d）" % run.build.rerolls, func():
		if run.reroll_cards(): _show_cards(), false, 17, 46))
	reroll.disabled = run.build.rerolls <= 0
	actions.add_child(reroll)
	actions.add_child(UI.expand(UI.button("略過（回復 %d）" % int(data.tuning.build.skip_heal), func():
		run.skip_card()
		_after_card(), false, 17, 46)))


## Evolution: a short celebration that does not block play.
func _evolution_moment(id: String) -> void:
	var evo: Dictionary = data.cards[id]
	hud.banner("✦ 進化 ✦  %s" % evo.name, "%s ＋ %s" % [data.cards[evo.requires[0]].name, data.cards[evo.requires[1]].name], "prey", 1.8)
	audio.play("evolve")
	haptics.play("ult")
	if current_battle != null:
		world.fx.ring("level", current_battle.player.pos, 180.0)
		world.fx.burst("gold", current_battle.player.pos, 40)


func _after_card() -> void:
	if run.phase == "battle" and run.needs_level_choice():
		_show_cards()
		return
	_sync()


func _show_bed() -> void:
	screen = "bed"
	var column := _open(700)
	column.add_child(UI.label("貓窩", 32))
	column.add_child(UI.label("溫暖的窩。要好好睡一覺，還是磨一磨爪子？", 17, UI.MUTED))
	column.add_child(UI.label("生命 %d / %d" % [ceili(run.hp), int(run.max_hp())], 17, Color("e9a47c")))
	column.add_child(UI.button("休息：回復 %d%% 生命" % int(run.bed_heal_pct()), func():
		run.bed_rest()
		_sync(), true))
	var train: Button = UI.button("磨爪：選一張卡升一級", func():
		run.bed_train()
		_sync())
	train.disabled = run.build.upgradable().is_empty()
	column.add_child(train)


func _show_upgrade_pick() -> void:
	screen = "upgrade_pick"
	var column := _open(760)
	column.add_child(UI.label("選一張卡升一級", 28))
	for id: String in run.build.upgradable():
		var card: Dictionary = data.cards[id]
		var level: int = int(run.build.cards[id])
		column.add_child(UI.button("%s Lv.%d → %d：%s" % [card.name, level, level + 1, card.desc[level]], func():
			run.pick_upgrade(id)
			_sync(), false, 16, 52))
	if run.choice_context == "bed":
		column.add_child(UI.button("返回", func():
			run.phase = "bed"
			_sync()))


func _shop_text(entry: Dictionary) -> String:
	match str(entry.type):
		"card":
			var card: Dictionary = data.cards[entry.id]
			return "【%s】%s：%s" % [data.categories[card.category].name, card.name, card.desc[0]]
		"heal": return "罐頭：回復 %d%% 生命" % int(data.shop.heal.pct)
		"upgrade": return "貓抓板：選一張卡升一級"
		"remove": return "整理玩具箱：移除一張卡（空出卡片格）"
		"reroll": return "逗貓棒：刷新次數 +%d" % int(data.shop.reroll.amount)
	return str(entry.type)


func _show_shop() -> void:
	screen = "shop"
	var column := _open(900)
	column.add_child(UI.label("主人的房間", 32))
	column.add_child(UI.label("小魚乾 %d · 生命 %d / %d" % [run.fish, ceili(run.hp), int(run.max_hp())], 17, UI.GOLD))
	for i in run.shop_stock.size():
		var entry: Dictionary = run.shop_stock[i]
		var line := UI.row(column)
		line.add_child(UI.expand(UI.label(_shop_text(entry), 16, UI.CREAM if not entry.sold else UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT)))
		var buy: Button = UI.button("已買" if entry.sold else "%d 小魚乾" % int(entry.price), func(): _shop_buy(i), false, 16, 44)
		buy.custom_minimum_size.x = 150
		buy.disabled = not run.shop_can_buy(i)
		line.add_child(buy)
	column.add_child(UI.button("離開", func():
		run.leave_node()
		_sync(), true))


func _shop_buy(index: int) -> void:
	var entry: Dictionary = run.shop_stock[index]
	if entry.type in ["upgrade", "remove"]:
		shop_pick_index = index
		var column := _open(760)
		column.add_child(UI.label("選哪一張？", 26))
		var options: Array = run.build.upgradable() if entry.type == "upgrade" else run.build.order
		for id: String in options:
			var card: Dictionary = data.cards[id]
			column.add_child(UI.button("%s（%s）" % [card.name, "進化" if id.begins_with("EV") else "Lv.%d" % int(run.build.cards[id])], func():
				run.shop_buy(shop_pick_index, id)
				_show_shop(), false, 16, 48))
		column.add_child(UI.button("返回", _show_shop))
		return
	if run.shop_buy(index): audio.play("pickup", 7.0)
	_show_shop()


func _show_moon() -> void:
	screen = "moon"
	var entry: Dictionary = data.event(run.event_id)
	var column := _open(800)
	column.add_child(UI.label("月光 · %s" % entry.title, 30))
	column.add_child(UI.label(str(entry.text), 18))
	column.add_child(UI.label("生命 %d / %d · 小魚乾 %d" % [ceili(run.hp), int(run.max_hp()), run.fish], 15, UI.MUTED))
	var options: Array = entry.options
	for i in options.size():
		var button: Button = UI.button(str(options[i].label), func():
			run.choose_event(i)
			_sync(), false, 17, 56)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = not run.option_ok(options[i])
		column.add_child(button)


func _show_items() -> void:
	screen = "item"
	var column := _open(800)
	column.add_child(ChestIcon.new())
	if not instant:
		audio.play("chest")
		haptics.play("medium")
	column.add_child(UI.label("找到寶物了！選一件帶回家", 30))
	column.add_child(UI.label("收藏會立刻保存。寶物從下一局開始可以裝備。", 15, UI.MUTED))
	var index := 0
	for id: String in run.item_choices:
		var item: Dictionary = data.items[id]
		var slot: String = "習慣寶物・%s" % data.habits[item.habit].name if item.slot == "habit" else "隨身小物"
		var button: Button = UI.button("%s（%s）\n%s" % [item.name, slot, item.desc], func(): _claim_item(id), id == run.target_item, 17, 74)
		column.add_child(button)
		if not instant:
			button.modulate.a = 0.0
			var tween := button.create_tween()
			tween.tween_interval(0.55 + index * 0.12)
			tween.tween_property(button, "modulate:a", 1.0, 0.18)
		index += 1
	column.add_child(UI.button("都不要", func():
		run.skip_item()
		_sync(), false, 15, 40))


func _claim_item(id: String) -> void:
	var before: Dictionary = run.to_dict()
	if not run.confirm_item(id): return
	if run.practice or profile.acquire_item(id, run.to_dict()):
		audio.play("prey")
		haptics.play("heavy")
		hud.banner("收藏：%s" % data.items[id].name, "下一局可以裝備", "prey", 1.6)
		save_notice = ""
		_sync()
		return
	run.from_dict(before)
	var column := _open(640)
	column.add_child(UI.label("寶物還沒有保存成功：%s" % profile.last_error, 18, UI.DANGER))
	column.add_child(UI.button("再試一次", func(): _claim_item(id), true))
	column.add_child(UI.button("返回選擇", _show_items))


func _show_supply() -> void:
	screen = "supply"
	var supply: Dictionary = data.tuning.supply
	var names := {"heal": "回復 %d 生命" % int(supply.heal), "fish": "小魚乾 +%d" % int(supply.fish), "reroll": "刷新 +%d" % int(supply.reroll)}
	var column := _open(640)
	column.add_child(UI.label("這一區的寶物都收齊了", 26))
	column.add_child(UI.label("改拿一份補給：", 16, UI.MUTED))
	for id: String in run.supply_choices:
		column.add_child(UI.button(str(names[id]), func():
			run.choose_supply(id)
			_sync()))


# ---- pause and results -----------------------------------------------------------------------

func _pause() -> void:
	if run == null: return
	screen = "pause"
	touch.clear()
	_save_active()
	var column := _open(620)
	column.add_child(UI.label("暫停", 32))
	if run.battle != null:
		column.add_child(UI.label("%s · %s · 生命 %d / %d" % [data.regions[run.region_id].name, KIND_NAMES.get(run.battle.kind, ""), ceili(float(run.battle.player.hp)), int(run.battle.player.max_hp)], 16, UI.MUTED))
	column.add_child(UI.button("繼續", _resume, true))
	if not run.practice:
		column.add_child(UI.button("保存並回到首頁", func():
			_save_active()
			_show_title()))
	column.add_child(UI.button("放棄這一局", _confirm_abandon))


func _resume() -> void:
	_clear()
	screen = "battle"
	world.visible = true
	hud.visible = true
	_sync()


func _confirm_abandon() -> void:
	var column := _open(620)
	column.add_child(UI.label("放棄這一局？", 28))
	column.add_child(UI.label("這局的卡片與小魚乾會消失；已經拿到的收藏會留著。", 16, UI.MUTED))
	column.add_child(UI.button("繼續玩", _pause, true))
	column.add_child(UI.button("放棄", func():
		if run.practice:
			_show_title()
			return
		run._finish(false)
		_sync()))


func _finish_run() -> void:
	screen = "result"
	world.visible = false
	hud.visible = false
	var summary: Dictionary = run.summary()
	if run.practice:
		report = {"saved": true, "unlocked": [], "near": []}
	else:
		if not profile.data.tutorial_done: profile.finish_tutorial()
		report = profile.finish_run(summary)
		if not report.saved:
			var column := _open(640)
			column.add_child(UI.label("結果還沒有保存：%s" % profile.last_error, 18, UI.DANGER))
			column.add_child(UI.button("再試一次", _finish_run, true))
			return
	_show_result(summary)


func _show_result(summary: Dictionary) -> void:
	var column := _open(860)
	var region: Dictionary = data.regions[summary.region]
	var title: String = "練習結束" if summary.practice else ("夜巡成功！" if summary.won else "先回家休息")
	column.add_child(UI.label(title, 36))
	if not instant and not summary.practice: music.stinger("win" if summary.won else "lose")
	for id: String in report.get("unlocked", []):
		haptics.play("double")
	if summary.won: column.add_child(UI.label(str(region.win_story), 18, UI.GOLD))
	var metrics: Dictionary = summary.metrics
	column.add_child(UI.label("%s · 夜深 %d · %s · 到達第 %d 層 · %d:%02d" % [region.name, int(summary.night), data.habits[summary.habit].title,
		mini(int(summary.layer), 8), int(summary.time) / 60, int(summary.time) % 60], 17, UI.MUTED))
	var stats := UI.row(column, 18)
	var counters := [["擊敗", int(metrics.get("kills", 0))], ["獵物", int(metrics.get("prey_kills", 0))], ["撲擊", int(metrics.get("pounces", 0))],
		["脫困", int(metrics.get("escape_pounces", 0))], ["夜影", int(metrics.get("ult_uses", 0))], ["等級", int(summary.level)], ["最高連獵", int(director.best_combo)]]
	var stat_index := 0
	for entry: Array in counters:
		var box := VBoxContainer.new()
		var number := UI.label("0" if not instant else str(entry[1]), 30, UI.GOLD)
		box.add_child(number)
		box.add_child(UI.label(str(entry[0]), 14, UI.MUTED))
		stats.add_child(box)
		if not instant:
			var target: int = int(entry[1])
			var tween := number.create_tween()
			tween.tween_interval(0.15 + stat_index * 0.08)
			tween.tween_method(func(v: float):
				var shown := int(round(v))
				if number.text != str(shown): audio.play("tick", minf(12.0, float(shown % 12)))
				number.text = str(shown), 0.0, float(target), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		stat_index += 1
	if not summary.won and not summary.practice and not str(summary.last_hurt).is_empty():
		column.add_child(UI.label("最後受傷來源：%s" % _enemy_name(str(summary.last_hurt)), 15, UI.DANGER))
	var cards: Array = summary.cards.map(func(c): return "%s%s" % [data.cards[c.id].name, "" if str(c.id).begins_with("EV") else " Lv.%d" % int(c.level)])
	if not cards.is_empty(): column.add_child(UI.label("這局的構築：" + "、".join(cards), 15, UI.MUTED))
	if not summary.new_items.is_empty():
		column.add_child(UI.label("新收藏：" + "、".join(summary.new_items.map(func(i): return data.items[i].name)), 18, UI.GOLD))
	for id: String in report.get("unlocked", []):
		var name: String = data.cards[id].name if data.cards.has(id) else data.items[id].name
		column.add_child(UI.label("解鎖！%s%s" % ["新卡片「" if data.cards.has(id) else "新寶物「", name + "」"], 18, UI.GOLD))
	if not summary.practice and not report.get("near", []).is_empty():
		column.add_child(UI.label("差一點就解鎖：", 16, UI.MUTED))
		for row: Dictionary in report.near:
			var target_name: String = data.cards[row.unlock].name if data.cards.has(row.unlock) else data.items[row.unlock].name
			column.add_child(UI.label("%s → %s（%d%%）" % [row.desc, target_name, int(float(row.ratio) * 100.0)], 15, UI.CREAM))
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 10)
			bar.max_value = 1.0
			bar.add_theme_stylebox_override("background", UI.panel(Color("18382c"), 5, 0))
			bar.add_theme_stylebox_override("fill", UI.panel(UI.GOLD, 5, 0))
			column.add_child(bar)
			if instant: bar.value = float(row.ratio)
			else: bar.create_tween().tween_property(bar, "value", float(row.ratio), 0.8).set_delay(0.6).set_ease(Tween.EASE_OUT)
	var buttons := UI.row(column)
	if summary.practice:
		buttons.add_child(UI.expand(UI.button("再練一次", _show_practice, true)))
	else:
		buttons.add_child(UI.expand(UI.button("再出發", func():
			run = null
			_show_setup(), true)))
		buttons.add_child(UI.expand(UI.button("收藏與紀錄", _show_collection)))
	buttons.add_child(UI.expand(UI.button("首頁", _show_title)))


func _enemy_name(id: String) -> String:
	if data.enemies.has(id): return str(data.enemies[id].name)
	return {"thrower": "投擲物"}.get(id, id)


# ---- collection and settings ------------------------------------------------------------------

func _show_collection() -> void:
	screen = "collection"
	var column := _open(980)
	column.add_child(UI.label("收藏與紀錄", 32))
	var tabs := UI.row(column)
	for tab: Array in [["items", "寶物"], ["cards", "本能卡"], ["records", "紀錄"]]:
		tabs.add_child(UI.expand(UI.button(str(tab[1]), func():
			collection_tab = tab[0]
			_show_collection(), collection_tab == tab[0], 18, 44)))
	match collection_tab:
		"items": _collection_items(column)
		"cards": _collection_cards(column)
		_: _collection_records(column)
	column.add_child(UI.button("返回", _show_title))


func _condition_for(target: String) -> Dictionary:
	for condition: Dictionary in data.unlocks:
		if condition.unlock == target: return condition
	return {}


func _collection_items(column: VBoxContainer) -> void:
	var owned := 0
	for id: String in data.items:
		if profile.owned(id): owned += 1
	column.add_child(UI.label("已收藏 %d / %d" % [owned, data.items.size()], 16, UI.GOLD))
	for id: String in data.items:
		var item: Dictionary = data.items[id]
		var slot: String = "習慣・%s" % data.habits[item.habit].name if item.slot == "habit" else "隨身小物"
		var line := UI.row(column)
		if profile.owned(id):
			line.add_child(UI.expand(UI.label("✓ %s（%s）：%s" % [item.name, slot, item.desc], 15, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT)))
		elif item.source == "chest":
			line.add_child(UI.expand(UI.label("？ %s（%s）：在獵物巢與守關的寶箱找到" % [item.name, slot], 15, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT)))
			var targeted: bool = profile.data.target == id
			var target_button: Button = UI.button("目標中" if targeted else "設為尋寶目標", func():
				profile.set_target("" if targeted else id)
				_show_collection(), targeted, 14, 40)
			target_button.custom_minimum_size.x = 150
			line.add_child(target_button)
		else:
			var condition := _condition_for(id)
			line.add_child(UI.expand(UI.label("？ %s（%s）：%s（%d%%）" % [item.name, slot, condition.get("desc", ""),
				int(Progress.condition_ratio(condition, profile.data) * 100.0)], 15, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT)))


func _collection_cards(column: VBoxContainer) -> void:
	var open := 0
	for card: Dictionary in data.card_list:
		if card.starter or card.id in profile.data.unlocked: open += 1
	column.add_child(UI.label("可用本能卡 %d / %d · 進化 %d 種" % [open, data.card_list.size(), data.evolutions.size()], 16, UI.GOLD))
	for category: String in data.categories:
		column.add_child(UI.label("【%s】" % data.categories[category].name, 17, Color(str(data.categories[category].color)), HORIZONTAL_ALIGNMENT_LEFT))
		for card: Dictionary in data.card_list:
			if card.category != category: continue
			if card.starter or card.id in profile.data.unlocked:
				column.add_child(UI.label("%s：%s" % [card.name, card.desc[0]], 14, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT))
			else:
				var condition := _condition_for(card.id)
				column.add_child(UI.label("？ %s：%s（%d%%）" % [card.name, condition.get("desc", ""), int(Progress.condition_ratio(condition, profile.data) * 100.0)], 14, UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	column.add_child(UI.label("進化（第一張卡練到 Lv.3，並持有第二張卡）", 17, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	for evo: Dictionary in data.evolutions:
		column.add_child(UI.label("%s ＝ %s ＋ %s：%s" % [evo.name, data.cards[evo.requires[0]].name, data.cards[evo.requires[1]].name, evo.desc[0]], 14, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT))


func _collection_records(column: VBoxContainer) -> void:
	var progress: Dictionary = profile.data.progress
	for id: String in data.region_order():
		var best: int = int(profile.data.region_night.get(id, -1))
		var text: String = "尚未通關" if best < 0 else "最深通關：夜深 %d" % best
		column.add_child(UI.label("%s：%s" % [data.regions[id].name, text], 17, UI.CREAM if best >= 0 else UI.MUTED, HORIZONTAL_ALIGNMENT_LEFT))
	column.add_child(UI.label("夜巡 %d 次 · 擊敗 %d · 獵物 %d · 精英 %d · 守關 %d · 夜影 %d 次 · 進化 %d 次" % [int(progress.runs), int(progress.kills),
		int(progress.prey_kills), int(progress.elites), int(progress.bosses), int(progress.ult_uses), int(progress.evolutions)], 15, UI.MUTED))
	column.add_child(UI.label("下一個目標：", 16, UI.GOLD, HORIZONTAL_ALIGNMENT_LEFT))
	for row: Dictionary in Progress.nearest(data, profile.data, 5):
		var name: String = data.cards[row.unlock].name if data.cards.has(row.unlock) else data.items[row.unlock].name
		column.add_child(UI.label("%s → %s（%d%%）" % [row.desc, name, int(float(row.ratio) * 100.0)], 14, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT))


func _slider_row(column: VBoxContainer, title: String, key: String, fallback: float) -> void:
	var row := UI.row(column)
	var label := UI.label(title, 17, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.custom_minimum_size.x = 140
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = float(_settings().get(key, fallback))
	slider.custom_minimum_size = Vector2(360, 40)
	slider.value_changed.connect(func(value: float):
		profile.set_setting(key, value)
		_apply_settings()
		if key == "sfx_volume": audio.play("pop", 4.0)
		if key == "shake_level":
			haptics.play("light"))
	row.add_child(slider)


func _choice_row(column: VBoxContainer, title: String, key: String, options: Array, fallback: String) -> void:
	var row := UI.row(column, 8)
	var label := UI.label(title, 17, UI.CREAM, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.custom_minimum_size.x = 140
	row.add_child(label)
	for entry: Array in options:
		var value: String = entry[0]
		row.add_child(UI.expand(UI.button(str(entry[1]), func():
			profile.set_setting(key, value)
			_apply_settings()
			if key == "haptics": haptics.play("heavy")
			_show_settings(), str(_settings().get(key, fallback)) == value, 16, 42)))


func _show_settings() -> void:
	screen = "settings"
	var settings: Dictionary = _settings()
	var column := _open(820)
	column.add_child(UI.label("設定", 32))
	_slider_row(column, "音樂", "music_volume", 0.6)
	_slider_row(column, "音效", "sfx_volume", 0.8)
	_choice_row(column, "震動", "haptics", [["off", "關"], ["low", "弱"], ["medium", "中"], ["high", "強"]], "medium")
	_slider_row(column, "震屏強度", "shake_level", 1.0)
	_choice_row(column, "特效", "effects", [["low", "低"], ["medium", "中"], ["high", "高"]], "high")
	_choice_row(column, "傷害數字", "damage_numbers", [["off", "關"], ["heavy", "只顯示重擊"], ["all", "全部"]], "heavy")
	_choice_row(column, "搖桿大小", "controls", [["small", "小"], ["medium", "中"], ["large", "大"]], "medium")
	for entry: Array in [["low_flash", "低閃光（減弱全畫面閃光）"], ["reduce_motion", "減少動態（關掉停頓、慢動作與推近）"],
			["assist", "輔助模式（敵方傷害 ×0.75，不影響收藏）"], ["perf_overlay", "顯示每幀時間（測試效能用）"]]:
		var key: String = entry[0]
		var on: bool = settings.get(key, false)
		column.add_child(UI.button("%s：%s" % [entry[1], "開" if on else "關"], func():
			profile.set_setting(key, not on)
			_apply_settings()
			_show_settings(), on, 16, 44))
	if perf_lowered: column.add_child(UI.label("這次遊玩中因為畫面吃力，特效已自動降低一級。", 14, UI.GOLD))
	if not profile.last_error.is_empty(): column.add_child(UI.label(profile.last_error, 15, UI.DANGER))
	column.add_child(UI.label("收藏與紀錄存在這台裝置的應用資料中；移除應用程式可能會一起刪除。", 14, UI.MUTED))
	column.add_child(UI.button("返回", _show_title))
