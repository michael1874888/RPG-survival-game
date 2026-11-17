extends RefCounted
## Per-run growth state. The experiment and combat read this same state.
const THRESHOLDS := [12, 20, 28, 32, 40, 44]
const CORES := ["a", "b", "c"]
const COMMON := ["power", "reach", "vitality"]
var levels: Dictionary = {}
var common := {"power": 0, "reach": 0, "vitality": 0}
var decisions: Array[Dictionary] = []
var offers: Array[String] = []
var rng := RandomNumberGenerator.new()
var last_progress := ""
var stage_complete_pending := false
var total_xp := 0
var seed_used: int = 0

func begin(opening: String, seed_value: int = 0) -> void:
	levels = {opening: 1}
	common = {"power": 0, "reach": 0, "vitality": 0}
	decisions.clear()
	offers.clear()
	stage_complete_pending = false
	total_xp = 0
	last_progress = ""
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	seed_used = rng.seed

func required(level: int) -> int:
	return THRESHOLDS[level - 1] if level >= 1 and level <= THRESHOLDS.size() else 0

func make_offers(level: int) -> Array[String]:
	var progress: Array[String] = []
	var unowned: Array[String] = []
	var general: Array[String] = []
	var has_capstone := levels.values().has(3)
	for id: String in CORES:
		if not levels.has(id):
			if levels.size() < 2: unowned.append(id)
		elif int(levels[id]) == 1 or (int(levels[id]) == 2 and level >= 4 and not has_capstone):
			progress.append(id)
	for id: String in COMMON:
		if int(common[id]) < 2: general.append(id)
	offers.clear()
	if not progress.is_empty():
		var picked: String = progress[0]
		if progress.size() > 1:
			picked = progress[1] if progress[0] == last_progress else progress[0]
		offers.append(picked)
		last_progress = picked
	if not unowned.is_empty(): offers.append(unowned[rng.randi_range(0, unowned.size() - 1)])
	while offers.size() < 3 and not general.is_empty():
		var i := rng.randi_range(0, general.size() - 1)
		offers.append(general.pop_at(i))
	for id: String in progress:
		if offers.size() >= 3: break
		if id not in offers: offers.append(id)
	return offers

func choose(run, id: String) -> bool:
	if id not in offers or run.state != "upgrade": return false
	var decision := {"id": id, "offered": offers.duplicate(), "stage": run.scenario_id, "level": run.level, "time": run.elapsed}
	decisions.append(decision)
	run.experiment.note(run, "growth_chosen", decision)
	run.experiment.context["growth_decisions"] = decisions.duplicate(true)
	if id in CORES:
		levels[id] = int(levels.get(id, 0)) + 1
		run.experiment.levels = levels.duplicate()
		if id not in run.experiment.abilities: run.experiment.abilities.append(id)
	else:
		common[id] = int(common[id]) + 1
		if id == "vitality":
			run.max_hp += 15.0
			run.hp += 15.0
	offers.clear()
	run.state = "playing"
	run.events.append({"kind": "growth_choice", "pos": run.player, "id": id})
	run.maybe_level_up()
	if run.state == "playing" and stage_complete_pending:
		stage_complete_pending = false
		run.state = "won"
	return true

func label(id: String) -> String:
	match id:
		"a":
			match int(levels.get(id, 0)):
				0: return "穿影爪 Lv.1\n連續命中，發出爪影"
				1: return "穿影爪 Lv.2\n連擊增強；受傷重置"
				_: return "穿影爪 Lv.3\n滿連擊的爪影更寬"
		"b":
			match int(levels.get(id, 0)):
				0: return "游走蓄勢 Lv.1\n停手移動，換取爆發"
				1: return "游走蓄勢 Lv.2\n蓄勢爪推開敵人"
				_: return "游走蓄勢 Lv.3\n最多儲存兩次蓄勢"
		"c":
			match int(levels.get(id, 0)):
				0: return "獵痕重咬 Lv.1\n標記獵物，重咬兌現"
				1: return "獵痕重咬 Lv.2\n兌現波及附近敵人"
				_: return "獵痕重咬 Lv.3\n強敵存活時保留獵痕"
		"power": return "利爪 %d / 2\n所有攻擊傷害 +10%%" % (int(common[id]) + 1)
		"reach": return "伸展 %d / 2\n爪擊、重咬與爪影距離 +10%%" % (int(common[id]) + 1)
		"vitality": return "護身 %d / 2\n最大生命與目前生命 +15" % (int(common[id]) + 1)
	return id
