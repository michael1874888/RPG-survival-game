extends RefCounted
## Nine-node expedition, rewards, and an explicitly serializable simulation snapshot.

const Growth := preload("res://scripts/r1_growth.gd")
const Waves := preload("res://scripts/r1_waves.gd")
const Combat := preload("res://scripts/r1_combat.gd")
const Encounters := preload("res://scripts/r1_encounters.gd")
const EVENTS := {
	"EV01": ["樹洞歇腳", "完成下一戰後恢復 20 生命"],
	"EV02": ["長廊練步", "追兵排成兩列；完成後刷新 +1"],
	"EV03": ["窺見前路", "提早遇見後排；下下戰特殊攻擊延後至 4 秒"],
	"EV04": ["守寶挑戰", "清場後追加精英；擊敗獲得收藏箱"],
	"EV05": ["限時獵場", "45 秒內擊敗精英，額外選一個共通強化"],
	"EV06": ["搶回包裹", "35 秒內在包裹旁累計 6 秒，換取補給"],
}
const RUN_FIELDS := ["state", "player", "aim", "hp", "max_hp", "elapsed", "invulnerability", "shot_timer",
	"level", "xp", "kills", "next_enemy_id", "upgrades", "offers", "enemies", "projectiles", "pickups",
	"combat_metrics", "view_size", "fixed_abilities", "drop_xp", "warning_positions", "warning_remaining", "wave_count"]
const GROWTH_FIELDS := ["levels", "common", "decisions", "offers", "last_progress", "stage_complete_pending", "total_xp",
	"seed_used", "b_branch", "bell_equipped", "habit", "opening", "a_branch", "c_branch", "stage_completed", "mods",
	"links", "rerolls", "respec_used", "free_common", "avoid_offers", "formed_offer_age"]
const COMBAT_FIELDS := ["bite_charge", "cooldown", "ultimate_remaining", "pending_bite", "last_attack_was_bite", "sweep_count",
	"marked_target_id", "marker_remaining", "shadow_count", "shadow_power", "shadow_last_hit", "pending_shadows",
	"movement_charge", "prey_id", "prey_remaining", "assisted_target_id", "follow_target_id", "follow_remaining", "link_s03_cooldown"]
const WAVE_FIELDS := ["active", "abilities", "levels", "growth_mode", "guardian_thresholds", "last_guardian_wave_at",
	"guardian_first_warning", "legacy_c", "timed_mark", "charged_mark_bonus", "schedule", "timeline", "samples", "counts",
	"hitstop", "hitstop_seconds", "pause_seconds", "wall_seconds", "sample_timer", "move_distance", "initial_position",
	"elite_born", "logged", "saved_path", "input_kind", "context", "node", "route_event", "boss_defeated", "boss_phase",
	"next_boss_support", "last_boss_support_cycle", "event_success", "event_target_id", "event_elapsed", "package_pos", "package_progress", "event_elite_started", "r1_seed"]
const ENCOUNTER_FIELDS := ["enemy_projectiles", "next_start", "spawn_countdown", "pending_spawns", "elite_scheduled",
	"elite_defeated", "retry_queue", "retry_countdown", "special_countdown", "sample_countdown", "population_samples", "spawn_stats"]
const SELF_FIELDS := ["node", "seed_used", "opening", "habit", "charm", "assist", "phase", "pending", "route_event", "event_history",
	"route_choices", "chest_choices", "new_items", "total_kills", "total_seconds", "pending_damage", "pending_damage_source",
	"first_hit_available", "last_injury", "completed", "won", "event_window_next", "save_clock", "practice", "respec_from", "respec_offers", "respec_cache"]

var node := 1
var seed_used := 0
var opening := "a"
var habit := ""
var charm := ""
var assist := false
var phase := "battle"
var pending: Array[String] = []
var route_event := ""
var event_history: Array[String] = []
var route_choices: Array[String] = []
var chest_choices: Array[String] = []
var new_items: Array[String] = []
var total_kills := 0
var total_seconds := 0.0
var pending_damage := 0.0
var pending_damage_source := ""
var first_hit_available := true
var last_injury := ""
var completed := false
var won := false
var event_window_next := false
var save_clock := 0.0
var practice := false
var respec_from := ""
var respec_offers: Array[String] = []
var respec_cache := {}
var route_rng := RandomNumberGenerator.new()
var loot_rng := RandomNumberGenerator.new()


func begin(run, selected: String, run_seed: int, chosen_habit: String, chosen_charm: String, easy: bool, training := false) -> void:
	node = 1
	seed_used = run_seed if run_seed != 0 else int(Time.get_unix_time_from_system())
	opening = selected
	habit = chosen_habit if {"H01": "a", "H03": "b", "H05": "c"}.get(chosen_habit, "") == selected else ""
	charm = chosen_charm
	assist = easy
	practice = training
	respec_from = ""
	respec_offers.clear()
	respec_cache.clear()
	phase = "battle"
	pending.clear()
	route_event = ""
	event_history.clear()
	route_choices.clear()
	chest_choices.clear()
	new_items.clear()
	total_kills = 0
	total_seconds = 0.0
	pending_damage = 0.0
	last_injury = ""
	completed = false
	won = false
	event_window_next = false
	save_clock = 0.0
	route_rng.seed = seed_used + 20011
	loot_rng.seed = seed_used + 30011
	var growth = Growth.new()
	growth.begin_r1(selected, seed_used + 10011, habit)
	_load_node(run, growth, {})


func _load_node(run, growth, carry: Dictionary) -> void:
	run.reset(seed_used + node * 101, "nana", "standard", "nana_build_s1")
	run.r1 = self
	run.growth = growth
	run.nana = Combat.new()
	run.encounters = Encounters.new()
	run.encounters.reset(run, run.scenario_id)
	run.experiment = Waves.new()
	run.experiment.configure_r1(run, node, seed_used, route_event)
	run.drop_xp = true
	if not carry.is_empty():
		run.hp = float(carry.hp)
		run.max_hp = float(carry.max_hp)
		run.level = int(carry.level)
		run.xp = int(carry.xp)
		run.nana.cooldown = float(carry.cooldown)
		run.nana.bite_charge = int(carry.bite)
		run.nana.movement_charge = minf(float(carry.charge), growth.charge_limit())
		run.shot_timer = maxf(0.0, float(carry.shot_timer))
	if event_window_next:
		# The scheduler compares elapsed + windup; 4.9 prevents windups before 4 s.
		run.encounters.next_start = 4.9
		event_window_next = false
	first_hit_available = true
	respec_cache.clear()
	pending_damage = 0.0
	pending_damage_source = ""
	phase = "battle"
	if practice:
		# Practice uses the same rules and can be exited from pause without affecting progress.
		run.growth.stage_completed = 3


func queue_damage(amount: float, source: String) -> void:
	if amount > pending_damage:
		pending_damage = amount
		pending_damage_source = source


func resolve_damage(run) -> void:
	if pending_damage <= 0.0: return
	var amount := pending_damage * (0.75 if assist else 1.0)
	if charm == "U01" and first_hit_available:
		amount = maxf(1.0, amount - 8.0)
	first_hit_available = false
	last_injury = pending_damage_source
	pending_damage = 0.0
	pending_damage_source = ""
	run.apply_damage_now(amount, last_injury)


func finish_node(run) -> void:
	if phase != "battle" or run.state not in ["won", "lost"]: return
	total_kills += run.kills
	total_seconds += run.elapsed
	if run.state == "lost":
		completed = true
		won = false
		phase = "result"
		return
	if practice:
		completed = true
		won = true
		phase = "result"
		return
	run.growth.stage_completed = node
	if node == 9:
		completed = true
		won = true
		phase = "result"
		return
	pending.clear()
	match route_event:
		"EV01": run.hp = minf(run.max_hp, run.hp + 20.0)
		"EV02": run.growth.rerolls = mini(4, run.growth.rerolls + 1)
		"EV03": event_window_next = true
		"EV04": pending.append("chest_event")
		"EV05":
			if run.experiment.event_success: pending.append("event_common")
		"EV06":
			if run.experiment.event_success: pending.append("event_supply")
	if node in [3, 6]:
		pending.append("chest")
		run.hp = minf(run.max_hp, run.hp + 25.0)
		pending.append("camp")
	else:
		pending.append("between")
	phase = pending[0]
	chest_choices.clear()
	route_choices.clear()


func advance_pending() -> void:
	if not pending.is_empty(): pending.pop_front()
	phase = pending[0] if not pending.is_empty() else "between"


func choose_chest(profile) -> Array[String]:
	if not chest_choices.is_empty(): return chest_choices
	var pool: Array[String] = []
	for id: String in ["H01", "H03", "H05", "U03"]:
		if id not in profile.data.owned: pool.append(id)
	if phase == "chest" and node == 3 and "H03" in pool:
		chest_choices.append("H03")
		return chest_choices
	if phase == "chest" and str(profile.data.target) in pool:
		chest_choices.append(str(profile.data.target))
		pool.erase(str(profile.data.target))
	while chest_choices.size() < 3 and not pool.is_empty():
		var index := loot_rng.randi_range(0, pool.size() - 1)
		chest_choices.append(pool.pop_at(index))
	return chest_choices


func acquire_chest(run, profile, id: String) -> bool:
	if phase not in ["chest", "chest_event"] or id not in chest_choices: return false
	var old_pending := pending.duplicate()
	var old_phase := phase
	var old_choices := chest_choices.duplicate()
	new_items.append(id)
	advance_pending()
	chest_choices.clear()
	if profile.acquire(id, snapshot(run)): return true
	new_items.erase(id)
	pending.assign(old_pending)
	phase = old_phase
	chest_choices.assign(old_choices)
	return false


func available_supply(run, event_supply := false) -> Array[String]:
	var result: Array[String] = []
	if run.hp < run.max_hp: result.append("heal")
	if run.nana.cooldown > 0.0: result.append("cooldown")
	if (not event_supply or result.is_empty()) and run.growth.rerolls < 4: result.append("reroll")
	return result


func use_supply(run, id: String, event_supply := false) -> bool:
	if id not in available_supply(run, event_supply): return false
	match id:
		"heal": run.hp = minf(run.max_hp, run.hp + 20.0)
		"cooldown": run.nana.cooldown = maxf(0.0, run.nana.cooldown - (12.0 if event_supply else 8.0))
		"reroll": run.growth.rerolls = mini(4, run.growth.rerolls + 1)
	advance_pending()
	chest_choices.clear()
	return true


func choose_routes(run) -> Array[String]:
	if not route_choices.is_empty(): return route_choices
	var safe: Array[String] = []
	var risky: Array[String] = []
	for id: String in ["EV01", "EV02", "EV03"]:
		if id not in event_history and (id != "EV02" or run.growth.rerolls < 4): safe.append(id)
	for id: String in ["EV04", "EV05", "EV06"]:
		if id not in event_history: risky.append(id)
	if safe.is_empty(): safe.append("EV03")
	if risky.is_empty(): risky.append("EV06")
	route_choices.append(safe[route_rng.randi_range(0, safe.size() - 1)])
	route_choices.append(risky[route_rng.randi_range(0, risky.size() - 1)])
	return route_choices


func select_route(id: String) -> bool:
	if phase != "camp" or id not in route_choices: return false
	route_event = id
	event_history.append(id)
	route_choices.clear()
	advance_pending()
	return true


func respec_owned(run) -> Array[String]:
	var owned: Array[String] = []
	owned.append_array(run.growth.mods)
	owned.append_array(run.growth.links)
	for id: String in run.growth.COMMON_R1:
		if int(run.growth.common[id]) > 0: owned.append(id)
	return owned


func _remove_talent(run, id: String, apply_stats: bool) -> void:
	var g = run.growth
	if id in g.mods:
		if id == "M05" and apply_stats:
			var ratio: float = run.nana.movement_charge / g.charge_cost()
			g.mods.erase(id)
			run.nana.movement_charge = minf(g.charge_limit(), ratio * g.charge_cost())
		else: g.mods.erase(id)
	elif id in g.links:
		g.links.erase(id)
	elif g.common.has(id) and int(g.common[id]) > 0:
		g.common[id] = int(g.common[id]) - 1
		if apply_stats and id == "vitality":
			run.max_hp -= 15.0
			run.hp = minf(run.hp, run.max_hp)
		elif apply_stats and id == "cooldown" and run.nana.cooldown > 0.0:
			run.nana.cooldown = minf(40.0 - 4.0 * int(g.common.cooldown), run.nana.cooldown + 4.0)


func begin_respec(run, old: String) -> Array[String]:
	if phase != "camp" or run.growth.respec_used or run.growth.rerolls <= 0 or old not in respec_owned(run): return []
	if respec_cache.has(old):
		respec_from = old
		respec_offers.assign(respec_cache[old])
		return respec_offers
	var g = run.growth
	var old_mods: Array = g.mods.duplicate()
	var old_links: Array = g.links.duplicate()
	var old_common: Dictionary = g.common.duplicate()
	_remove_talent(run, old, false)
	var groups: Array = g._groups()
	var pool: Array[String] = []
	for id in groups[1] + groups[2]:
		if id not in g.CORES and id != old and id not in pool: pool.append(id)
	g.mods.assign(old_mods)
	g.links.assign(old_links)
	g.common = old_common
	respec_from = old
	respec_offers.clear()
	while respec_offers.size() < 3 and not pool.is_empty():
		respec_offers.append(pool.pop_at(g.rng.randi_range(0, pool.size() - 1)))
	if respec_offers.size() < 3 and old not in respec_offers: respec_offers.append(old)
	respec_cache[old] = respec_offers.duplicate()
	return respec_offers


func apply_respec(run, id: String) -> bool:
	var g = run.growth
	if phase != "camp" or respec_from.is_empty() or id not in respec_offers or g.rerolls <= 0 or g.respec_used: return false
	if id == respec_from:
		g.rerolls -= 1
		g.respec_used = true
		respec_from = ""
		respec_offers.clear()
		return true
	_remove_talent(run, respec_from, true)
	var old_cost: float = g.charge_cost()
	if id.begins_with("M"):
		g.mods.append(id)
		if id == "M05": run.nana.movement_charge = minf(g.charge_limit(), run.nana.movement_charge / old_cost * g.charge_cost())
	elif id.begins_with("S"):
		g.links.append(id)
	else:
		g.common[id] = int(g.common[id]) + 1
		if id == "vitality":
			run.max_hp += 15.0
			run.hp += 15.0
		elif id == "cooldown": run.nana.cooldown = maxf(0.0, run.nana.cooldown - 4.0)
	g.rerolls -= 1
	g.respec_used = true
	respec_from = ""
	respec_offers.clear()
	return true


func next_node(run) -> bool:
	if phase != "between" or node >= 9: return false
	var carry := {"hp": run.hp, "max_hp": run.max_hp, "level": run.level, "xp": run.xp,
		"cooldown": run.nana.cooldown, "bite": run.nana.bite_charge, "charge": run.nana.movement_charge,
		"shot_timer": run.shot_timer}
	var growth = run.growth
	node += 1
	if node not in [4, 7]: route_event = ""
	pending.clear()
	_load_node(run, growth, carry)
	return true


func result_summary() -> Dictionary:
	return {"won": won, "node": node, "opening": opening, "habit": habit, "charm": charm,
		"assist": assist, "kills": total_kills, "seconds": total_seconds, "new_items": new_items.duplicate(), "injury": last_injury}


func _values(object: Object, names: Array) -> Dictionary:
	var result := {}
	for key: String in names:
		var value = object.get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


func _set_values(object: Object, values: Dictionary, names: Array) -> void:
	for key: String in names:
		if not values.has(key): continue
		var existing = object.get(key)
		if existing is Array and values[key] is Array:
			existing.assign(values[key])
		else:
			object.set(key, values[key])


func snapshot(run) -> Dictionary:
	return {"schema": 1, "self": _values(self, SELF_FIELDS), "run": _values(run, RUN_FIELDS),
		"growth": _values(run.growth, GROWTH_FIELDS), "combat": _values(run.nana, COMBAT_FIELDS),
		"waves": _values(run.experiment, WAVE_FIELDS), "encounters": _values(run.encounters, ENCOUNTER_FIELDS),
		"run_rng": run.rng.state, "upgrade_rng": run.upgrade_rng.state, "growth_rng": run.growth.rng.state,
		"route_rng": route_rng.state, "loot_rng": loot_rng.state}


func restore(run, saved: Dictionary) -> bool:
	for key: String in ["self", "run", "growth", "combat", "waves", "encounters", "run_rng", "upgrade_rng", "growth_rng", "route_rng", "loot_rng"]:
		if not saved.has(key): return false
	if int(saved.get("schema", 0)) != 1: return false
	_set_values(self, saved.self, SELF_FIELDS)
	var growth = Growth.new()
	growth.begin_r1(opening, seed_used + 10011, habit)
	_load_node(run, growth, {})
	_set_values(self, saved.self, SELF_FIELDS)
	_set_values(run, saved.run, RUN_FIELDS)
	_set_values(run.growth, saved.growth, GROWTH_FIELDS)
	_set_values(run.nana, saved.combat, COMBAT_FIELDS)
	_set_values(run.experiment, saved.waves, WAVE_FIELDS)
	_set_values(run.encounters, saved.encounters, ENCOUNTER_FIELDS)
	run.rng.state = int(saved.run_rng)
	run.upgrade_rng.state = int(saved.upgrade_rng)
	run.growth.rng.state = int(saved.growth_rng)
	route_rng.state = int(saved.route_rng)
	loot_rng.state = int(saved.loot_rng)
	if run.state == "playing": run.state = "paused"
	return true
