extends "res://scripts/main.gd"
## Player-facing first-chapter expedition; historical experiment scene stays available to tests.

const ProfileR1 := preload("res://scripts/r1_profile.gd")
const ExpeditionR1 := preload("res://scripts/r1_expedition.gd")
const WavesR1 := preload("res://scripts/r1_waves.gd")

var profile = null
var adventure = null
var opening_r1 := "b"
var save_problem := false
var save_action := ""
var show_assist := false


func _show_title() -> void:
	if profile == null: profile = ProfileR1.new()
	if run.r1 != null: run.experiment.logged = true
	super._show_title()
	adventure = null
	var column: VBoxContainer = _make_overlay(900)
	column.add_theme_constant_override("separation", 10)
	column.add_child(_label("BRAMBLE · 奈奈夜巡", 36))
	column.add_child(_label("帶著你的狩獵習慣，出發找回寶物", 20, GOLD))
	if profile.load_failed:
		column.add_child(_label(profile.last_error, 18, Color("ffb58e")))
		column.add_child(_label("舊資料已保留，請先處理存檔問題。", 16, MUTED))
		return
	if not profile.data.active.is_empty():
		column.add_child(_button("繼續上次冒險", _continue_saved, true))
	column.add_child(_button("準備出發 · 月下庭院", _show_r1_setup, profile.data.active.is_empty()))
	column.add_child(_button("練習六種狩獵方式", _show_training))
	column.add_child(_button("寶物收藏", _show_collection))
	column.add_child(_label("左側移動，右側瞄準並攻擊；按夜影按鈕突破包圍。\n戰鬥可暫停，並可稍後繼續。", 16, MUTED))
	if not profile.last_error.is_empty(): column.add_child(_label(profile.last_error, 15, GOLD))


func _row(column: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	return row


func _small_button(row: HBoxContainer, title: String, callback: Callable, active := false) -> Button:
	var button := _button(title, callback, active)
	button.custom_minimum_size.y = 43
	button.add_theme_font_size_override("font_size", 16)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(button)
	return button


func _set_opening(id: String) -> void:
	opening_r1 = id
	_show_r1_setup()


func _set_item(slot: String, id: String) -> void:
	if not profile.select_item(slot, id):
		_show_error("儲存裝備選擇失敗", "setup")
		return
	_show_r1_setup()


func _set_target(id: String) -> void:
	if not profile.set_target(id):
		_show_error("儲存尋寶目標失敗", "setup")
		return
	_show_r1_setup()


func _toggle_assist() -> void:
	var next: Dictionary = profile.data.duplicate(true)
	next.assist = not bool(next.assist)
	if not profile.commit(next):
		_show_error("儲存難度設定失敗", "setup")
		return
	_show_r1_setup()


func _show_r1_setup() -> void:
	screen = "title"
	touch.clear()
	mouse_held = false
	pause_button.hide()
	ultimate_button.hide()
	var column := _make_overlay(1120)
	column.add_theme_constant_override("separation", 4)
	column.add_child(_label("月下庭院 · 出發準備", 28))
	column.add_child(_label("九場冒險 · 兩次營地選路 · 打倒守關者", 16, GOLD))
	var starts := _row(column)
	for item: Array in [["a", "穿影爪\n連擊爪影"], ["b", "游走蓄勢\n移動蓄勢"], ["c", "獵痕重咬\n標記與兌現"]]:
		_small_button(starts, str(item[1]), _set_opening.bind(item[0]), opening_r1 == item[0])
	column.add_child(_label("習慣寶物：二級提早成形，並占用本局成形名額", 14, MUTED))
	var habits := _row(column)
	_small_button(habits, "不裝習慣", _set_item.bind("habit", ""), profile.data.habit == "")
	for id: String in ["H01", "H03", "H05"]:
		if id in profile.data.owned:
			var suffix := "（本局不生效）" if ProfileR1.ITEMS[id].core != opening_r1 else ""
			_small_button(habits, str(ProfileR1.ITEMS[id].name) + suffix, _set_item.bind("habit", id), profile.data.habit == id)
	column.add_child(_label("隨身小物：選擇一件帶進本局", 14, MUTED))
	var charms := _row(column)
	_small_button(charms, "不裝小物", _set_item.bind("charm", ""), profile.data.charm == "")
	for id: String in ["U01", "U02", "U03"]:
		if id in profile.data.owned:
			_small_button(charms, str(ProfileR1.ITEMS[id].name), _set_item.bind("charm", id), profile.data.charm == id)
	var item_details: Array[String] = []
	for id: String in [str(profile.data.habit), str(profile.data.charm)]:
		if ProfileR1.ITEMS.has(id): item_details.append(str(ProfileR1.ITEMS[id].name) + "：" + str(ProfileR1.ITEMS[id].desc))
	column.add_child(_label("　·　".join(item_details) if not item_details.is_empty() else "可空裝出發，也能稍後換裝。", 14, MUTED))
	var targets := _row(column)
	_small_button(targets, "不指定目標", _set_target.bind(""), profile.data.target == "")
	for id: String in ["H01", "H03", "H05", "U03"]:
		if id not in profile.data.owned:
			_small_button(targets, "找 " + str(ProfileR1.ITEMS[id].name), _set_target.bind(id), profile.data.target == id)
	if "H03" not in profile.data.owned:
		column.add_child(_label("首次完成第三戰會先取得回身鈴鐺。", 13, GOLD))
	var actions := _row(column)
	_small_button(actions, "輔助：" + ("開啟" if profile.data.assist else "關閉"), _toggle_assist, bool(profile.data.assist))
	_small_button(actions, "開始冒險", _start_adventure, true)
	_small_button(actions, "回起點", _show_title)


func _start_adventure() -> void:
	if profile.load_failed: return
	if not profile.data.active.is_empty():
		_show_replace_confirmation()
		return
	_begin_adventure()


func _show_replace_confirmation() -> void:
	var column := _make_overlay(880)
	column.add_child(_label("目前還有未結束的冒險", 28))
	column.add_child(_label("開始新局會放棄原本的局內成長；已收藏的寶物會保留。", 17, MUTED))
	column.add_child(_button("放棄舊局，開始新局", _begin_adventure, true))
	column.add_child(_button("返回準備", _show_r1_setup))


func _begin_adventure() -> void:
	adventure = ExpeditionR1.new()
	adventure.begin(run, opening_r1, 0, str(profile.data.habit), str(profile.data.charm), bool(profile.data.assist))
	effects.clear()
	if not _save_active(): return
	screen = ""
	_sync_screen()


func _continue_saved() -> void:
	adventure = ExpeditionR1.new()
	if not adventure.restore(run, profile.data.active):
		adventure = null
		_show_error("冒險進度無法讀取，已保留原存檔", "title")
		return
	screen = ""
	_sync_screen()


func _show_training() -> void:
	screen = "title"
	var column := _make_overlay(1000)
	column.add_theme_constant_override("separation", 8)
	column.add_child(_label("狩獵練習", 30))
	column.add_child(_label("直接試用成形；練習不會改變收藏或冒險進度。", 16, MUTED))
	for choices: Array in [
		[["a", "wide", "寬影掃群"], ["a", "echo", "回聲追擊"]],
		[["b", "double", "雙發蓄勢"], ["b", "follow", "回身追咬"]],
		[["c", "hold", "緊咬獵物"], ["c", "jump", "逐隻追獵"]],
	]:
		var row := _row(column)
		for item: Array in choices: _small_button(row, str(item[2]), _start_training.bind(item[0], item[1]))
	column.add_child(_button("回起點", _show_title))


func _start_training(core: String, branch: String) -> void:
	adventure = ExpeditionR1.new()
	adventure.begin(run, core, 417, "", "", false, true)
	run.growth.levels[core] = 3
	run.experiment.levels[core] = 3
	match core:
		"a": run.growth.a_branch = branch
		"b": run.growth.b_branch = branch
		"c": run.growth.c_branch = branch
	run.experiment.configure_r1(run, 5, 417, "")
	effects.clear()
	screen = ""
	_sync_screen()


func _show_collection() -> void:
	screen = "title"
	var column := _make_overlay(1100)
	column.add_theme_constant_override("separation", 7)
	column.add_child(_label("奈奈的寶物", 29))
	column.add_child(_label("收藏後可在出發前裝備；每局各帶一件。", 15, MUTED))
	for ids: Array in [["H01", "H03", "H05"], ["U01", "U02", "U03"]]:
		var row := _row(column)
		for id: String in ids:
			var text: String = str(ProfileR1.ITEMS[id].name) + "\n" + (str(ProfileR1.ITEMS[id].desc) if id in profile.data.owned else "尚未收藏 · 庭院尋寶")
			var label := _label(text, 15, CREAM if id in profile.data.owned else MUTED)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
	column.add_child(_label("已收藏 %d / 6" % profile.data.owned.size(), 17, GOLD))
	column.add_child(_button("準備出發", _show_r1_setup, true))
	column.add_child(_button("回起點", _show_title))


func _save_active() -> bool:
	if adventure == null or adventure.practice or adventure.phase == "result": return true
	if profile.save_active(adventure.snapshot(run)):
		save_problem = false
		return true
	_show_error("冒險進度尚未保存", "active")
	return false


func _show_error(message: String, action: String) -> void:
	save_problem = true
	save_action = action
	if run.r1 != null and run.state == "playing": run.state = "paused"
	screen = "save_error"
	touch.clear()
	mouse_held = false
	pause_button.hide()
	ultimate_button.hide()
	var column := _make_overlay(930)
	column.add_child(_label(message, 28, Color("ffb58e")))
	column.add_child(_label(profile.last_error + "\n請確認儲存空間後重試，既有存檔已保留。", 17, MUTED))
	column.add_child(_button("重新儲存", _retry_save, true))


func _retry_save() -> void:
	var ok := false
	match save_action:
		"active": ok = profile.save_active(adventure.snapshot(run))
		"finish": ok = profile.finish(adventure.result_summary())
		"setup", "title":
			save_problem = false
			_show_r1_setup() if save_action == "setup" else _show_title()
			return
	if not ok:
		_show_error("保存失敗，請再試一次", save_action)
		return
	save_problem = false
	screen = ""
	_sync_screen()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if adventure != null and run.r1 == adventure and not adventure.practice and not save_problem and adventure.phase == "battle" and run.state == "playing":
		adventure.save_clock += delta
		if adventure.save_clock >= 5.0:
			adventure.save_clock = 0.0
			_save_active()


func _on_focus_lost() -> void:
	super._on_focus_lost()
	if adventure != null and run.r1 == adventure and not save_problem: _save_active()


func _sync_screen() -> void:
	if run.r1 == null or adventure == null:
		super._sync_screen()
		return
	if save_problem: return
	if adventure.phase == "battle" and run.state in ["won", "lost"]:
		adventure.finish_node(run)
		if adventure.phase == "result":
			if not adventure.practice and not profile.finish(adventure.result_summary()):
				_show_error("結算尚未保存", "finish")
				return
		elif not _save_active(): return
	if adventure.phase != "battle":
		if screen != adventure.phase:
			screen = adventure.phase
			touch.clear()
			ultimate_touches.clear()
			mouse_held = false
			pause_button.hide()
			ultimate_button.hide()
			_show_adventure_phase()
		return
	if screen == run.state: return
	screen = run.state
	keyboard_released = false
	touch.clear()
	ultimate_touches.clear()
	mouse_held = false
	_clear_overlay()
	pause_button.visible = screen == "playing"
	ultimate_button.visible = screen == "playing"
	match screen:
		"paused": _show_pause()
		"upgrade":
			if not _save_active(): return
			_show_r1_upgrade()


func _show_pause() -> void:
	if run.r1 == null:
		super._show_pause()
		return
	var column := _make_overlay(900)
	column.add_child(_label("喘口氣，森林會等你", 30))
	column.add_child(_label("第 %d / 9 戰 · 生命 %d / %d" % [adventure.node, int(run.hp), int(run.max_hp)], 18, MUTED))
	column.add_child(_button("繼續冒險", _resume_run, true))
	column.add_child(_button("結束練習" if adventure.practice else "保存並回到起點", _save_and_leave))
	if not adventure.practice: column.add_child(_button("放棄本局", _confirm_abandon))


func _save_and_leave() -> void:
	if _save_active(): _show_title()


func _confirm_abandon() -> void:
	var column := _make_overlay(900)
	column.add_child(_label("放棄這次冒險？", 30))
	column.add_child(_label("本局成長會結束，已收藏的寶物保留。", 18, MUTED))
	column.add_child(_button("放棄本局", _abandon))
	column.add_child(_button("繼續冒險", _resume_run, true))


func _abandon() -> void:
	adventure.won = false
	adventure.completed = true
	adventure.phase = "result"
	if not profile.finish(adventure.result_summary()):
		_show_error("結算尚未保存", "finish")
		return
	screen = ""
	_sync_screen()


func _show_r1_upgrade() -> void:
	var column := _make_overlay(1110)
	column.add_theme_constant_override("separation", 8)
	column.add_child(_label("額外共通強化" if run.growth.free_common else "Lv.%d · 選擇這次的成長" % run.level, 29))
	column.add_child(_label("最多兩個核心、一個成形；強化會影響這一局。", 15, MUTED))
	var row := _row(column)
	for id: String in run.offers:
		var button := _small_button(row, run.growth.label(id), _choose_r1.bind(id))
		button.custom_minimum_size.y = 112
	if not run.growth.free_common:
		column.add_child(_button("刷新三個候選 · 剩餘 %d" % run.growth.rerolls, _reroll_r1))
		column.add_child(_button("略過這次成長，回復 10 生命", _choose_r1.bind("skip")))


func _reroll_r1() -> void:
	if run.growth.reroll(run):
		if _save_active(): _show_r1_upgrade()


func _choose_r1(id: String) -> void:
	if id in ["a", "b", "c"] and int(run.growth.levels.get(id, 0)) == 2:
		_show_r1_branches(id)
		return
	_finish_r1_choice(id)


func _show_r1_branches(core: String) -> void:
	var column := _make_overlay(1000)
	column.add_child(_label("選擇本局成形", 30))
	var options := {
		"a": [["a_wide", "寬影掃群\n滿連擊時爪影更寬"], ["a_echo", "回聲追擊\n滿連擊再留一道爪影"]],
		"b": [["b_double", "雙發蓄勢\n可儲存兩次蓄勢"], ["b_follow", "回身追咬\n推開後追擊同一目標"]],
		"c": [["c_hold", "緊咬獵物\n兌現後存活的目標保留獵痕"], ["c_jump", "逐隻追獵\n兌現擊敗後獵痕轉移"]],
	}
	var row := _row(column)
	for item: Array in options[core]:
		var button := _small_button(row, str(item[1]), _finish_r1_choice.bind(item[0]))
		button.custom_minimum_size.y = 105
	column.add_child(_button("返回候選", _show_r1_upgrade))


func _finish_r1_choice(id: String) -> void:
	var free: bool = run.growth.free_common
	if not run.growth.choose(run, id): return
	if free:
		adventure.advance_pending()
		run.state = "won"
	if not _save_active(): return
	screen = ""
	_sync_screen()


func _show_adventure_phase() -> void:
	match adventure.phase:
		"between": _show_r1_between()
		"chest", "chest_event": _show_r1_chest()
		"camp": _show_r1_camp()
		"event_common": _show_r1_event_common()
		"event_supply": _show_r1_supply(true)
		"result": _show_r1_result()


func _show_r1_between() -> void:
	var column := _make_overlay(920)
	column.add_child(_label("第 %d 戰完成" % adventure.node, 31))
	column.add_child(_label("生命 %d / %d　·　下一戰：%s" % [int(run.hp), int(run.max_hp), "守關者" if adventure.node == 8 else "庭院遭遇"], 18, GOLD))
	column.add_child(_label("成長、生命、大絕冷卻與蓄勢會帶到下一戰。", 16, MUTED))
	column.add_child(_button("進入下一戰", _next_node, true))
	column.add_child(_button("保存並離開", _save_and_leave))


func _next_node() -> void:
	if adventure.next_node(run) and _save_active():
		screen = ""
		_sync_screen()


func _show_r1_chest() -> void:
	var choices: Array[String] = adventure.choose_chest(profile)
	if not _save_active(): return
	if choices.is_empty():
		_show_r1_supply(false)
		return
	var column := _make_overlay(1100)
	column.add_child(_label("發現寶物！", 31, GOLD))
	column.add_child(_label("選一件永久收藏；本局結束後可自由裝備。", 17, MUTED))
	var row := _row(column)
	for id: String in choices:
		var info: Dictionary = ProfileR1.ITEMS[id]
		var button := _small_button(row, str(info.name) + "\n" + str(info.desc), _claim_r1.bind(id), true)
		button.custom_minimum_size.y = 115


func _claim_r1(id: String) -> void:
	if not adventure.acquire_chest(run, profile, id):
		_show_error("收藏尚未保存，請重試", "active")
		return
	screen = ""
	_sync_screen()


func _show_r1_supply(event_supply: bool) -> void:
	var column := _make_overlay(990)
	var options: Array[String] = adventure.available_supply(run, event_supply)
	column.add_child(_label("獲得補給" if not options.is_empty() else "這裡的寶物已收藏完成", 30, GOLD))
	var names := {"heal": "回復 20 生命", "cooldown": "縮短大絕冷卻", "reroll": "刷新次數 +1"}
	for id: String in options: column.add_child(_button(str(names[id]), _choose_supply.bind(id, event_supply), true))
	if options.is_empty(): column.add_child(_button("繼續", _skip_supply, true))


func _choose_supply(id: String, event_supply: bool) -> void:
	if adventure.use_supply(run, id, event_supply) and _save_active():
		screen = ""
		_sync_screen()


func _skip_supply() -> void:
	adventure.advance_pending()
	if _save_active():
		screen = ""
		_sync_screen()


func _show_r1_camp() -> void:
	var choices: Array[String] = adventure.choose_routes(run)
	if not _save_active(): return
	var column := _make_overlay(1100)
	column.add_theme_constant_override("separation", 8)
	column.add_child(_label("營地 · 選擇下一條路", 30))
	column.add_child(_label("已恢復 25 生命，現在 %d / %d" % [int(run.hp), int(run.max_hp)], 17, GOLD))
	var row := _row(column)
	for id: String in choices:
		var info: Array = ExpeditionR1.EVENTS[id]
		var button := _small_button(row, str(info[0]) + (" · 額外挑戰" if id in ["EV04", "EV05", "EV06"] else " · 穩健") + "\n" + str(info[1]), _choose_route.bind(id))
		button.custom_minimum_size.y = 100
	if "EV03" in choices:
		column.add_child(_button("查看下一戰敵人與守關者招式", _show_threat_preview))
	if not run.growth.respec_used and run.growth.rerolls > 0 and not adventure.respec_owned(run).is_empty():
		column.add_child(_button("調整一張天賦 · 消耗一次刷新", _show_respec))
	column.add_child(_button("保存並離開", _save_and_leave))


func _show_threat_preview() -> void:
	var preview := WavesR1.new()
	preview.configure_r1(run, adventure.node + 1, adventure.seed_used, "EV03")
	var enemy_names := {"chaser": "追逐", "pursuer": "疾追", "charger": "衝撞", "thrower": "投擲", "guard": "守衛"}
	var column := _make_overlay(1050)
	column.add_child(_label("窺見前路", 30))
	for wave in range(3):
		var counts := {}
		for ticket: Dictionary in preview.schedule:
			if int(ticket.wave) == wave: counts[ticket.kind] = int(counts.get(ticket.kind, 0)) + 1
		var parts: Array[String] = []
		for kind: String in counts: parts.append("%s × %d" % [enemy_names.get(kind, kind), counts[kind]])
		column.add_child(_label("第 %d 波：%s" % [wave + 1, "、".join(parts)], 18, GOLD))
	column.add_child(_label("庭院守關者：先連續掃擊兩次，接著預警直線根擊；\n兩招都會鎖定方向，可在預警後側移。", 17, MUTED))
	column.add_child(_button("返回營地", _show_r1_camp))


func _choose_route(id: String) -> void:
	if adventure.select_route(id) and _save_active():
		screen = ""
		_sync_screen()


func _show_respec() -> void:
	var column := _make_overlay(1080)
	column.add_child(_label("選擇要調整的天賦", 29))
	column.add_child(_label("核心和成形不會被移除；確認後消耗一次刷新。", 16, MUTED))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for id: String in adventure.respec_owned(run):
		var button := _button(run.growth.label(id).split("\n")[0], _begin_respec.bind(id))
		button.custom_minimum_size = Vector2(250, 44)
		button.add_theme_font_size_override("font_size", 17)
		grid.add_child(button)
	column.add_child(_button("返回營地", _show_r1_camp))


func _begin_respec(id: String) -> void:
	var choices: Array[String] = adventure.begin_respec(run, id)
	if not _save_active(): return
	var column := _make_overlay(1100)
	column.add_child(_label("選擇替換的天賦", 29))
	column.add_child(_label("原天賦：" + run.growth.label(id).split("\n")[0] + "　·　確認後才生效", 16, MUTED))
	var row := _row(column)
	for choice: String in choices:
		var button := _small_button(row, run.growth.label(choice), _apply_respec.bind(choice))
		button.custom_minimum_size.y = 104
	column.add_child(_button("取消", _show_r1_camp))


func _apply_respec(id: String) -> void:
	if adventure.apply_respec(run, id) and _save_active(): _show_r1_camp()


func _show_r1_event_common() -> void:
	if not run.growth.free_common:
		run.growth.free_common = true
		run.offers.assign(run.growth.make_offers(run.level))
	run.state = "upgrade"
	if run.offers.is_empty():
		run.growth.free_common = false
		run.state = "won"
		adventure.advance_pending()
		screen = ""
		_sync_screen()
		return
	if _save_active(): _show_r1_upgrade()


func _show_r1_result() -> void:
	var column := _make_overlay(980)
	column.add_theme_constant_override("separation", 10)
	column.add_child(_label("練習完成" if adventure.practice else ("守住庭院，奈奈回家了！" if adventure.won else "先休息，再出發"), 34))
	column.add_child(_label("完成至第 %d / 9 戰　·　擊敗 %d　·　%s" % [adventure.node, adventure.total_kills, _format_time(adventure.total_seconds)], 19, GOLD))
	if not adventure.new_items.is_empty():
		var names: Array[String] = []
		for id: String in adventure.new_items: names.append(str(ProfileR1.ITEMS[id].name))
		column.add_child(_label("本局新收藏：" + "、".join(names), 18, GOLD))
	if not adventure.last_injury.is_empty():
		var names := {"chaser": "追逐者", "pursuer": "疾追者", "charger": "衝撞者", "guard": "守衛者",
			"thrower_projectile": "投擲物", "warden": "荊棘守衛", "stalker": "追獵首領", "boss": "老樹守門者",
			"event_warden": "守寶精英", "event_stalker": "限時獵物"}
		column.add_child(_label("最後受傷來源：" + str(names.get(adventure.last_injury, "敵方攻擊")), 15, MUTED))
	column.add_child(_label("這局：" + _ability_names(run.experiment.abilities, run.experiment.levels), 16, MUTED))
	column.add_child(_button("再出發 · 選擇裝備", _show_r1_setup, true))
	column.add_child(_button("查看收藏", _show_collection))
	column.add_child(_button("回到起點", _show_title))


func _draw_hud() -> void:
	if run.r1 == null:
		super._draw_hud()
		return
	draw_style_box(panel_style(Color(0.06, 0.16, 0.12, 0.9), 18), Rect2(22, 20, 295, 76))
	draw_string(bold_font, Vector2(40, 48), "奈奈", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, CREAM)
	draw_string(font, Vector2(205, 48), "%d / %d" % [int(run.hp), int(run.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
	draw_rect(Rect2(40, 63, 254, 10), Color("18382c"))
	draw_rect(Rect2(40, 63, 254 * run.hp / run.max_hp, 10), Color("e9a47c"))
	draw_string(font, Vector2(40, 118), "重咬準備 %d / 3" % run.nana.bite_charge, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
	var level_text := "構築完成 · Lv.11" if run.level >= 11 else "Lv.%d  經驗 %d / %d" % [run.level, run.xp, run.required_xp()]
	draw_string(font, Vector2(40, 142), level_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, CREAM)
	if run.level < 11 and run.required_xp() > 0:
		draw_rect(Rect2(40, 146, 200, 6), Color("345b47"))
		draw_rect(Rect2(40, 146, 200 * minf(1.0, float(run.xp) / run.required_xp()), 6), GOLD)
	var y := 172.0
	for id: String in run.experiment.abilities:
		var line := ""
		match id:
			"a": line = "穿影 Lv.%d · 連擊 %d / 3" % [run.growth.levels.a, run.nana.shadow_count]
			"b": line = "蓄勢 Lv.%d · %d%%" % [run.growth.levels.b, int(100.0 * run.nana.movement_charge / run.growth.charge_cost())]
			"c": line = "獵痕 Lv.%d · %s" % [run.growth.levels.c, "追蹤中" if run.nana.has_prey() else "等待重咬"]
		if run.growth.formed(id): line += " · 成形"
		draw_string(font, Vector2(40, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
		y += 24.0
	draw_string(bold_font, Vector2(size.x * 0.5 - 65, 50), "第 %d / 9 戰" % adventure.node, HORIZONTAL_ALIGNMENT_LEFT, -1, 23, CREAM)
	draw_string(font, Vector2(size.x * 0.5 - 45, 73), _format_time(run.elapsed), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
	if adventure.route_event == "EV05" and not run.experiment.event_success:
		draw_string(font, Vector2(size.x * 0.5 - 75, 94), "挑戰剩餘 %d 秒" % maxi(0, 45 - int(run.experiment.event_elapsed)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
	if adventure.route_event == "EV06" and not run.experiment.event_success:
		draw_string(font, Vector2(size.x * 0.5 - 75, 94), "包裹剩餘 %d 秒" % maxi(0, 35 - int(run.experiment.event_elapsed)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
	if adventure.node == 9:
		for enemy: Dictionary in run.enemies:
			if enemy.get("variant", "") == "boss" and float(enemy.hp) > 0.0:
				draw_string(font, Vector2(size.x * 0.5 - 150, 112), "老樹守門者", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD)
				draw_rect(Rect2(size.x * 0.5 - 150, 120, 300, 9), Color("452d31"))
				draw_rect(Rect2(size.x * 0.5 - 150, 120, 300 * float(enemy.hp) / float(enemy.max_hp), 9), Color("e37b76"))
				break


func _draw_enemy(enemy: Dictionary, camera: Vector2) -> void:
	var variant: String = enemy.get("variant", "")
	if enemy.phase == "windup" and (enemy.kind in ["guard", "charger", "thrower"] or variant in ["warden", "event_warden", "boss", "stalker", "event_stalker"]):
		var pos: Vector2 = Vector2(enemy.pos) - camera
		var axis: Vector2 = enemy.dir
		if enemy.kind in ["charger", "thrower"] or variant in ["stalker", "event_stalker"] or (variant == "boss" and enemy.get("attack_kind", "") == "root"):
			var length := 480.0 if enemy.kind == "thrower" else (208.0 if enemy.kind == "charger" else (400.0 if variant == "boss" else 220.0))
			var width := 16.0 if enemy.kind == "thrower" else (80.0 if variant == "boss" else float(enemy.radius) * 2.0)
			draw_line(pos, pos + axis * length, Color(1.0, 0.63, 0.29, 0.2), width, true)
			draw_line(pos, pos + axis * length, GOLD, 2.0, true)
		else:
			var reach := 150.0 if enemy.kind == "guard" else (190.0 if variant == "boss" else 175.0)
			var half := deg_to_rad(50.0 if enemy.kind == "guard" else (80.0 if bool(enemy.get("second_strike", false)) else 55.0))
			var angle := axis.angle()
			draw_arc(pos, reach, angle - half, angle + half, 32, GOLD, 3.0, true)
			draw_line(pos, pos + Vector2.RIGHT.rotated(angle - half) * reach, GOLD, 2.0, true)
			draw_line(pos, pos + Vector2.RIGHT.rotated(angle + half) * reach, GOLD, 2.0, true)
		var old_phase: String = enemy.phase
		enemy.phase = "shown_windup"
		super._draw_enemy(enemy, camera)
		enemy.phase = old_phase
	else:
		super._draw_enemy(enemy, camera)
	if variant in ["boss", "warden", "stalker", "event_warden", "event_stalker"] and float(enemy.hp) > 0.0:
		var tag := "守關者" if variant == "boss" else ("追獵精英" if variant in ["stalker", "event_stalker"] else "荊棘精英")
		draw_string(font, Vector2(enemy.pos) - camera + Vector2(-32, -float(enemy.radius) - 28), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)


func _draw() -> void:
	super._draw()
	if run.r1 != null and adventure.route_event == "EV06" and adventure.phase == "battle" and not run.experiment.event_success and run.experiment.event_elapsed <= 35.0:
		var point: Vector2 = run.experiment.package_pos - run.camera_origin()
		draw_circle(point, 90.0, Color(1.0, 0.82, 0.40, 0.10))
		draw_arc(point, 90.0, 0.0, TAU, 48, GOLD, 3.0, true)
		draw_string(bold_font, point + Vector2(-32, 0), "包裹 %.1f / 6 秒" % run.experiment.package_progress, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)
