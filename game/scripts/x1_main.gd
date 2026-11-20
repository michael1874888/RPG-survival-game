extends Control
## X1 「奈奈夜巡」 entry: title, setup, map, battle, rewards, results, collection and settings.
## Rules live in scripts/x1/core; this script only connects them to the screen, input and saves.

const UI := preload("res://scripts/x1/ui/theme.gd")
const Data := preload("res://scripts/x1/core/data.gd")
const Run := preload("res://scripts/x1/core/run.gd")
const Profile := preload("res://scripts/x1/core/profile.gd")
const Progress := preload("res://scripts/x1/core/progress.gd")
const Touch := preload("res://scripts/x1/ui/touch_input.gd")
const BattleView := preload("res://scripts/x1/render/battle_view.gd")
const MapView := preload("res://scripts/x1/ui/map_view.gd")
const Synth := preload("res://scripts/x1/render/synth.gd")

const HABIT_ORDER := ["shadow", "roam", "hunt"]
const STICK_SIZES := {"small": 60.0, "medium": 72.0, "large": 90.0}
const KIND_NAMES := {"hunt": "狩獵", "den": "獵物巢", "boss": "守關", "practice": "練習場"}

var data
var profile = null
var run = null
var view
var synth
var touch = Touch.new()
var overlay: Control = null
var screen := "title"
var pause_button: Button
var ult_button: Button
var ult_touches: Dictionary = {}
var ult_request := false
var mouse_pos := Vector2.ZERO
var mouse_pounce := false
var keyboard_pounce := false
var setup: Dictionary = {}
var snapshot_clock := 0.0
var report: Dictionary = {}
var save_notice := ""
var shop_pick_index := -1
var collection_tab := "items"
var tutorial_flags: Dictionary = {}
var last_ult_ready := false
var autosave_enabled := true


func _ready() -> void:
	data = Data.shared()
	if profile == null: profile = Profile.new()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = BattleView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.touch = touch
	view.visible = false
	add_child(view)
	synth = Synth.new()
	add_child(synth)
	pause_button = UI.button("暫停 Ⅱ", _pause, false, 17, 44)
	add_child(pause_button)
	ult_button = UI.button("夜影解放", func(): ult_request = true, false, 18, 74)
	ult_button.add_theme_stylebox_override("normal", UI.panel(Color("564478"), 18, 10))
	ult_button.add_theme_stylebox_override("hover", UI.panel(Color("725c9a"), 18, 10))
	add_child(ult_button)
	resized.connect(_layout)
	_layout()
	_apply_settings()
	get_window().focus_exited.connect(_on_focus_lost)
	_show_title()


func _layout() -> void:
	pause_button.position = Vector2(size.x - 124.0, 22.0)
	pause_button.size = Vector2(100, 44)
	ult_button.position = Vector2(size.x - 360.0, size.y - 310.0)
	ult_button.size = Vector2(150.0, 74.0)


func _apply_settings() -> void:
	var settings: Dictionary = profile.data.settings
	synth.volume = float(settings.get("volume", 0.7))
	touch.radius = float(STICK_SIZES.get(str(settings.get("controls", "medium")), 72.0))
	touch.deadzone = float(data.tuning.pounce.deadzone)
	view.settings = settings


func _sound(name: String) -> void:
	synth.play(name)


func _vibrate(ms: int) -> void:
	if profile.data.settings.get("vibration", true) and OS.has_feature("mobile"): Input.vibrate_handheld(ms)


# ---- frame loop -------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var in_battle: bool = screen == "battle" and run != null and run.phase == "battle" and run.battle != null
	pause_button.visible = in_battle
	ult_button.visible = in_battle
	if not in_battle: return
	if run.needs_level_choice():
		_show_cards()
		return
	var b = run.battle
	b.view_size = size
	view.battle = b
	view.run = run
	var input := _gather_input(b)
	var ended: bool = run.tick(delta, input)
	var events: Array = b.take_events()
	view.consume(events)
	_react(events, b)
	_tutorial(b)
	_update_ult_button(b)
	if run.needs_level_choice():
		_sound("level")
		_show_cards()
		return
	snapshot_clock += delta
	if snapshot_clock >= float(data.tuning.save.battle_snapshot_every) and not ended:
		snapshot_clock = 0.0
		_save_active()
	if ended or run.phase != "battle": _sync()


func _gather_input(b) -> Dictionary:
	var move: Vector2 = touch.movement()
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if keys.length_squared() > 0.0: move = keys.normalized()
	var pounce: Vector2 = touch.take_pounce()
	var player_screen: Vector2 = b.player.pos - b.camera_rect().position
	if mouse_pounce:
		mouse_pounce = false
		var offset: Vector2 = mouse_pos - player_screen
		if offset.length() > 8.0: pounce = offset.normalized()
	if keyboard_pounce:
		keyboard_pounce = false
		pounce = move.normalized() if move.length_squared() > 0.01 else Vector2(b.player.facing)
	view.aim_mouse = mouse_pos
	var ult := ult_request
	ult_request = false
	return {"move": move, "pounce": pounce, "ult": ult}


func _react(events: Array, b) -> void:
	var feel: Dictionary = data.tuning.feel
	for ev: Dictionary in events:
		match str(ev.kind):
			"swipe": if int(ev.get("depth", 0)) == 0: _sound("swipe")
			"pounce": _sound("pounce")
			"land": _sound("land")
			"bite":
				_sound("bite")
				_vibrate(int(feel.vibrate_bite))
			"hurt":
				_sound("hurt")
				_vibrate(int(feel.vibrate_hurt))
			"defeat":
				if ev.get("role", "") in ["elite", "boss"] or ev.get("prey", false): _sound("prey")
				else: _sound("defeat")
			"ult":
				_sound("ult")
				_vibrate(int(feel.vibrate_ult))
			"pickup": _sound("pickup")
			"telegraph": if ev.get("role", "") in ["elite", "boss"]: _sound("warn")
			"boss_phase": _sound("boss")
			"net": _sound("net")
	if b.ult_ready() and not last_ult_ready: _sound("ready")
	last_ult_ready = b.ult_ready()


func _update_ult_button(b) -> void:
	if b.ult_active():
		ult_button.text = "夜影解放\n影化 %.1f 秒" % float(b.ult.active)
	elif b.ult_ready():
		ult_button.text = "夜影解放\n準備好了！"
	else:
		ult_button.text = "夜影解放\n%d%%" % int(100.0 * float(b.ult.meter) / float(data.tuning.ult.meter_max))
	ult_button.add_theme_stylebox_override("normal", UI.panel(Color("8a6ac4") if b.ult_ready() else Color("564478"), 18, 10))


func _tutorial(b) -> void:
	if not run.tutorial or b.kind == "practice": return
	var steps := [
		["move", 0.4, "左手拖曳移動。爪子會自動抓身邊的敵人。"],
		["pounce", 4.5, "右手拖曳、放開：撲出去！撲擊途中不會受傷，落地會咬一口。"],
	]
	for entry: Array in steps:
		if not tutorial_flags.has(entry[0]) and b.elapsed >= float(entry[1]):
			tutorial_flags[entry[0]] = true
			view.show_hint(str(entry[2]), 5.0)
	if not tutorial_flags.has("prey"):
		for e: Dictionary in b.enemies:
			if e.get("target", false):
				tutorial_flags["prey"] = true
				view.show_hint("頭上有 ◆ 的是目標獵物。全部打倒就能收網、結束這場。", 5.0)
				break
	if not tutorial_flags.has("ult") and b.ult_ready():
		tutorial_flags["ult"] = true
		view.show_hint("夜影解放充滿了！按右下的按鈕（或空白鍵）突破包圍。", 5.0)


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
				var volume: float = 0.0 if synth.volume > 0.0 else 0.7
				profile.set_setting("volume", volume)
				_apply_settings()
			KEY_F5:
				if OS.is_debug_build(): _debug_reload()
	if screen != "battle": return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch.handle(event, size)
	elif event is InputEventMouseMotion:
		mouse_pos = event.position
		view.mouse_aiming = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		mouse_pos = event.position
		mouse_pounce = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED: _on_focus_lost()


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
	view.show_hint("已重新載入資料檔（F5）", 2.0)


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
	if not save_notice.is_empty(): column.add_child(UI.label(save_notice, 15, UI.DANGER))
	return column


func _sync() -> void:
	if run == null:
		_show_title()
		return
	view.visible = run.phase == "battle"
	match run.phase:
		"battle":
			screen = "battle"
			_clear()
			if run.battle != null:
				view.battle = run.battle
				view.run = run
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
	view.visible = false
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
		"hitstop": profile.data.settings.get("shake", true), "view_size": size})
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
		"assist": profile.data.settings.get("assist", false), "hitstop": profile.data.settings.get("shake", true), "view_size": size})
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
	map_view.build(run, func(id: String):
		_sound("click")
		run.enter(id)
		snapshot_clock = 0.0
		_sync())
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
	button.add_theme_stylebox_override("normal", UI.panel(Color(str(category.color)).darkened(0.55) if not id.begins_with("EV") else UI.GOLD, 16, 12))
	button.add_theme_stylebox_override("hover", UI.panel(Color(str(category.color)).darkened(0.4) if not id.begins_with("EV") else Color("ffe5a4"), 16, 12))
	return button


func _show_cards() -> void:
	screen = "card"
	var titles := {"level": "升級！選一張本能卡", "reward": "獵物巢的獎勵", "event": "月光下的收穫"}
	var column := _open(900, 0.7)
	column.add_child(UI.label(titles.get(run.choice_context, "選一張卡"), 28))
	column.add_child(UI.label("卡片格 %d / %d" % [run.build.order.size(), int(data.tuning.build.slots)], 15, UI.MUTED))
	var cards := UI.row(column, 14)
	for id: String in run.build.offers:
		cards.add_child(UI.expand(_card_button(id, func():
			_sound("click")
			run.choose_card(id)
			_after_card())))
	var actions := UI.row(column)
	var reroll: Button = UI.expand(UI.button("刷新（剩 %d）" % run.build.rerolls, func():
		if run.reroll_cards(): _show_cards(), false, 17, 46))
	reroll.disabled = run.build.rerolls <= 0
	actions.add_child(reroll)
	actions.add_child(UI.expand(UI.button("略過（回復 %d）" % int(data.tuning.build.skip_heal), func():
		run.skip_card()
		_after_card(), false, 17, 46)))


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
	if run.shop_buy(index): _sound("click")
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
	column.add_child(UI.label("找到寶物了！選一件帶回家", 30))
	column.add_child(UI.label("收藏會立刻保存。寶物從下一局開始可以裝備。", 15, UI.MUTED))
	for id: String in run.item_choices:
		var item: Dictionary = data.items[id]
		var slot: String = "習慣寶物・%s" % data.habits[item.habit].name if item.slot == "habit" else "隨身小物"
		column.add_child(UI.button("%s（%s）\n%s" % [item.name, slot, item.desc], func(): _claim_item(id), id == run.target_item, 17, 74))
	column.add_child(UI.button("都不要", func():
		run.skip_item()
		_sync(), false, 15, 40))


func _claim_item(id: String) -> void:
	var before: Dictionary = run.to_dict()
	if not run.confirm_item(id): return
	if run.practice or profile.acquire_item(id, run.to_dict()):
		_sound("prey")
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
	view.visible = true
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
	view.visible = false
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
	if summary.won: column.add_child(UI.label(str(region.win_story), 18, UI.GOLD))
	var metrics: Dictionary = summary.metrics
	column.add_child(UI.label("%s · 夜深 %d · %s · 到達第 %d 層 · %d:%02d" % [region.name, int(summary.night), data.habits[summary.habit].title,
		mini(int(summary.layer), 8), int(summary.time) / 60, int(summary.time) % 60], 17, UI.MUTED))
	column.add_child(UI.label("擊敗 %d · 獵物 %d · 撲擊 %d（脫困 %d） · 夜影 %d 次 · Lv.%d · 進化 %d" % [int(metrics.get("kills", 0)),
		int(metrics.get("prey_kills", 0)), int(metrics.get("pounces", 0)), int(metrics.get("escape_pounces", 0)),
		int(metrics.get("ult_uses", 0)), int(summary.level), int(metrics.get("evolutions", 0))], 16))
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


func _show_settings() -> void:
	screen = "settings"
	var settings: Dictionary = profile.data.settings
	var column := _open(720)
	column.add_child(UI.label("設定", 32))
	var volume_row := UI.row(column)
	volume_row.add_child(UI.label("音量", 18, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, false))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = float(settings.get("volume", 0.7))
	slider.custom_minimum_size = Vector2(320, 40)
	slider.value_changed.connect(func(value: float):
		profile.set_setting("volume", value)
		_apply_settings())
	volume_row.add_child(slider)
	for entry: Array in [["vibration", "震動"], ["shake", "震屏與命中停頓"], ["low_flash", "低閃光"], ["assist", "輔助模式（敵方傷害 ×0.75，不影響收藏）"]]:
		var key: String = entry[0]
		var on: bool = settings.get(key, false)
		column.add_child(UI.button("%s：%s" % [entry[1], "開" if on else "關"], func():
			profile.set_setting(key, not on)
			_apply_settings()
			_show_settings(), on, 17, 46))
	var size_row := UI.row(column)
	size_row.add_child(UI.label("搖桿大小", 17, UI.CREAM, HORIZONTAL_ALIGNMENT_CENTER, false))
	for entry: Array in [["small", "小"], ["medium", "中"], ["large", "大"]]:
		size_row.add_child(UI.expand(UI.button(str(entry[1]), func():
			profile.set_setting("controls", entry[0])
			_apply_settings()
			_show_settings(), settings.get("controls", "medium") == entry[0], 17, 44)))
	if not profile.last_error.is_empty(): column.add_child(UI.label(profile.last_error, 15, UI.DANGER))
	column.add_child(UI.label("收藏與紀錄存在這台裝置的應用資料中；移除應用程式可能會一起刪除。", 14, UI.MUTED))
	column.add_child(UI.button("返回", _show_title))
