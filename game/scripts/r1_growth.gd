extends "res://scripts/nana_growth_run.gd"
## First-chapter growth. Legacy short-run rules remain in the parent script.

const R1_THRESHOLDS := [12, 18, 24, 30, 36, 42, 48, 54, 60, 66]
const MODS := {"a": ["M01", "M02"], "b": ["M05", "M07"], "c": ["M09", "M10"]}
const LINKS := {"S01": ["a", "b"], "S03": ["a", "c"], "S05": ["b", "c"]}
const COMMON_R1 := ["power", "reach", "vitality", "speed", "haste", "cooldown"]
const LABELS := {
	"M01": "續爪\n連擊容忍 1.8 秒",
	"M02": "聚影\n爪影傷害 +35%，延遲較長",
	"M05": "輕足\n蓄勢距離縮短，爆發較輕",
	"M07": "截路\n蓄勢命中後減速敵人",
	"M09": "餘味\n獵物被爪或爪影擊敗，獵痕轉移",
	"M10": "淺嚐\n未標記目標的重咬更強",
	"S01": "借勢成影\n蓄勢爪算兩次穿影連擊",
	"S03": "影中獵味\n爪影命中獵痕，加速重咬",
	"S05": "蓄勢追獵\n蓄勢爪命中獵痕，重咬準備滿格",
}

var habit := ""
var opening := "a"
var a_branch := "wide"
var c_branch := "hold"
var stage_completed := 0
var mods: Array[String] = []
var links: Array[String] = []
var rerolls := 2
var respec_used := false
var free_common := false
var avoid_offers: Array[String] = []
var formed_offer_age := 0


func begin_r1(first: String, seed_value: int, chosen_habit: String) -> void:
	super.begin(first, seed_value, false)
	opening = first
	habit = chosen_habit if {"H01": "a", "H03": "b", "H05": "c"}.get(chosen_habit, "") == first else ""
	bell_equipped = habit == "H03"
	b_branch = "follow" if bell_equipped else "double"
	a_branch = "wide"
	c_branch = "hold"
	common = {"power": 0, "reach": 0, "vitality": 0, "speed": 0, "haste": 0, "cooldown": 0}
	stage_completed = 0
	mods.clear()
	links.clear()
	rerolls = 2
	respec_used = false
	free_common = false
	avoid_offers.clear()
	formed_offer_age = 0


func required(level: int) -> int:
	return R1_THRESHOLDS[level - 1] if level >= 1 and level <= R1_THRESHOLDS.size() else 0


func formed(id: String) -> bool:
	if int(levels.get(id, 0)) >= 3:
		return true
	return int(levels.get(id, 0)) >= 2 and {"H01": "a", "H03": "b", "H05": "c"}.get(habit, "") == id


func capstone_reserved() -> bool:
	return not habit.is_empty() or levels.values().has(3)


func charge_cost() -> float:
	return 220.0 if "M05" in mods else 260.0


func charge_limit() -> float:
	return charge_cost() * (2.0 if formed("b") and b_branch == "double" else 1.0)


func _groups() -> Array:
	var progress: Array[String] = []
	var new_or_mod: Array[String] = []
	var link_or_common: Array[String] = []
	for id: String in CORES:
		if levels.has(id):
			var current := int(levels[id])
			if current == 1 or (current == 2 and stage_completed >= 3 and not capstone_reserved()):
				progress.append(id)
			if mods.size() < 2:
				for mod: String in MODS[id]:
					if mod not in mods:
						new_or_mod.append(mod)
		elif levels.size() < 2:
			new_or_mod.append(id)
	if links.size() < 2:
		for id: String in LINKS:
			if id not in links and levels.has(LINKS[id][0]) and levels.has(LINKS[id][1]):
				link_or_common.append(id)
	for id: String in COMMON_R1:
		if int(common[id]) < 2:
			link_or_common.append(id)
	return [progress, new_or_mod, link_or_common]


func _pick(pool: Array, excluded: Array) -> String:
	var candidates: Array[String] = []
	for candidate in pool:
		if candidate not in offers and candidate not in excluded:
			candidates.append(str(candidate))
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else ""


func make_offers(_level: int) -> Array[String]:
	var groups := _groups()
	offers.clear()
	if free_common:
		var free_pool: Array[String] = []
		for id: String in COMMON_R1:
			if int(common[id]) < 2: free_pool.append(id)
		while offers.size() < 3:
			var id := _pick(free_pool, avoid_offers)
			if id.is_empty(): id = _pick(free_pool, [])
			if id.is_empty(): break
			offers.append(id)
		avoid_offers.clear()
		return offers
	# Offer one owned core's progress when possible, alternating between cores.
	var progress: Array = groups[0]
	if not progress.is_empty():
		var first: String = progress[0]
		if progress.size() > 1 and first == last_progress: first = progress[1]
		offers.append(first)
		last_progress = first
	for group_index in [1, 2, 0]:
		if offers.size() >= 3: break
		var picked := _pick(groups[group_index], avoid_offers)
		if picked.is_empty(): picked = _pick(groups[group_index], [])
		if not picked.is_empty(): offers.append(picked)
	var all: Array = groups[0] + groups[1] + groups[2]
	while offers.size() < 3:
		var picked := _pick(all, avoid_offers)
		if picked.is_empty(): picked = _pick(all, [])
		if picked.is_empty(): break
		offers.append(picked)
	avoid_offers.clear()
	return offers


func reroll(run) -> bool:
	if run.state != "upgrade" or rerolls <= 0 or free_common:
		return false
	var previous := offers.duplicate()
	var before_state := rng.state
	avoid_offers.assign(previous)
	make_offers(run.level)
	if offers == previous:
		rng.state = before_state
		offers.assign(previous)
		return false
	rerolls -= 1
	run.offers.assign(offers)
	return true


func choose(run, chosen_id: String) -> bool:
	if run.state != "upgrade": return false
	var id := chosen_id
	var branches := {"a_wide": ["a", "wide"], "a_echo": ["a", "echo"],
		"b_double": ["b", "double"], "b_follow": ["b", "follow"],
		"c_hold": ["c", "hold"], "c_jump": ["c", "jump"]}
	if branches.has(id):
		id = branches[id][0]
		if id not in offers or int(levels.get(id, 0)) != 2 or capstone_reserved() or stage_completed < 3: return false
		match id:
			"a": a_branch = branches[chosen_id][1]
			"b": b_branch = branches[chosen_id][1]
			"c": c_branch = branches[chosen_id][1]
	elif id in CORES and int(levels.get(id, 0)) == 2:
		return false # The player must choose a concrete branch.
	if id != "skip" and id not in offers: return false
	if id == "skip":
		run.hp = minf(run.max_hp, run.hp + 10.0)
	elif id in CORES:
		levels[id] = int(levels.get(id, 0)) + 1
		run.experiment.levels = levels.duplicate()
		if id not in run.experiment.abilities: run.experiment.abilities.append(id)
	elif id.begins_with("M"):
		mods.append(id)
	elif id.begins_with("S"):
		links.append(id)
	else:
		common[id] = int(common[id]) + 1
		if id == "vitality":
			run.max_hp += 15.0
			run.hp += 15.0
		elif id == "cooldown":
			run.nana.cooldown = maxf(0.0, run.nana.cooldown - 4.0)
	decisions.append({"id": chosen_id, "offered": offers.duplicate(), "level": run.level, "stage": stage_completed + 1, "free": free_common})
	free_common = false
	offers.clear()
	run.offers.clear()
	run.state = "playing"
	run.events.append({"kind": "growth_choice", "pos": run.player, "id": chosen_id})
	run.maybe_level_up()
	if run.state == "playing" and stage_complete_pending:
		stage_complete_pending = false
		run.state = "won"
	return true


func label(id: String) -> String:
	if LABELS.has(id): return LABELS[id]
	if id in CORES:
		var names := {"a": "穿影爪", "b": "游走蓄勢", "c": "獵痕重咬"}
		var detail := {"a": "三次命中產生爪影", "b": "停手移動，換取蓄勢爪", "c": "重咬留下獵痕，再咬兌現"}
		var current := int(levels.get(id, 0))
		if current == 1:
			detail = {"a": "連續爪影更強", "b": "蓄勢爪推開敵人", "c": "兌現波及周圍"}
			if {"H01": "a", "H03": "b", "H05": "c"}.get(habit, "") == id:
				detail[id] += "＋寶物提早成形"
		elif current == 2:
			detail = {"a": "選擇寬影或回聲", "b": "選擇雙發或追咬", "c": "選擇緊咬或逐隻追獵"}
		return "%s Lv.%d\n%s" % [names[id], current + 1, detail[id]]
	var common_names := {"power": ["利爪", "所有傷害 +10%"], "reach": ["伸展", "爪、咬與爪影距離 +10%"],
		"vitality": ["護身", "最大生命與目前生命 +15"], "speed": ["貓步", "移動速度 +6%"],
		"haste": ["快爪", "一般出手頻率 +8%"], "cooldown": ["夜瞳", "大絕冷卻 -4 秒"]}
	if common_names.has(id): return "%s %d / 2\n%s" % [common_names[id][0], int(common[id]) + 1, common_names[id][1]]
	return id
