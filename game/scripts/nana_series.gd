extends RefCounted
## Three fixed encounters, with explicit choices and combat state carried between them.

const STAGES := ["nana_build_e1", "nana_build_e2", "nana_build_e3"]
const SHORT_STAGES := ["nana_build_s1", "nana_build_s2", "nana_build_s3", "nana_build_s4"]
const HEAL := 25.0
const VERSION := "nana-series-v4"
var active := false
var between := false
var finished := false
var stage := 0
var opening := "a"
var series_id := ""
var results: Array[Dictionary] = []
var snapshot: Dictionary = {}
var save_failures := 0
var levels: Dictionary = {}
var decisions: Array[Dictionary] = []
var short_run := false
var growth_mode := false

func stages() -> Array:
	return SHORT_STAGES if short_run else STAGES

func begin(run, ability: String, short_mode := false, use_growth := false, growth_seed: int = 0) -> bool:
	if ability not in ["a", "b", "c"]:
		return false
	active = true
	short_run = short_mode
	growth_mode = short_mode and use_growth
	between = false
	finished = false
	stage = 0
	opening = ability
	series_id = "%s-%d" % [Time.get_datetime_string_from_system(), Time.get_ticks_usec()]
	results.clear()
	decisions.clear()
	snapshot.clear()
	save_failures = 0
	levels = {ability: 1}
	if growth_mode:
		run.growth = run.GrowthRun.new()
		run.growth.begin(ability, growth_seed)
	_load_stage(run, [ability])
	return true

func _load_stage(run, abilities: Array) -> void:
	var growth_state = run.growth if growth_mode else null
	run.reset(0, "nana", "standard", stages()[stage])
	run.growth = growth_state
	if growth_mode: run.drop_xp = true
	run.experiment.configure(run, abilities, {"levels": levels, "growth_mode": growth_mode})
	if not snapshot.is_empty():
		run.hp = float(snapshot.hp)
		if growth_mode:
			run.max_hp = float(snapshot.max_hp)
			run.level = int(snapshot.level)
			run.xp = int(snapshot.xp)
		run.nana.cooldown = float(snapshot.cooldown)
		run.nana.ultimate_remaining = float(snapshot.ultimate)
		run.nana.bite_charge = int(snapshot.bite)
		run.shot_timer = float(snapshot.shot_timer)
		if not growth_mode and "a" in abilities and "a" in snapshot.abilities and float(snapshot.shadow_remaining) > 0.0:
			run.nana.shadow_count = int(snapshot.shadow_count)
			run.nana.shadow_last_hit = -(1.2 - float(snapshot.shadow_remaining))
		if "b" in abilities and "b" in snapshot.abilities:
			run.nana.movement_charge = float(snapshot.movement_charge)
	run.experiment.context = {"mode": "short_run" if short_run else "series", "rules": VERSION, "series_id": series_id, "stage": stage + 1,
		"starting_hp": run.hp, "starting_cooldown": run.nana.cooldown,
		"previous_results": results.duplicate(true), "decisions": decisions.duplicate(true)}
	if growth_mode:
		run.experiment.context["growth_seed"] = run.growth.seed_used
		run.experiment.context["growth_decisions"] = run.growth.decisions.duplicate(true)
		run.experiment.context["growth_common"] = run.growth.common.duplicate()
	run.experiment.note(run, "series_stage_start", run.experiment.context)

func collect(run) -> bool:
	if growth_mode and run.growth != null: levels = run.growth.levels.duplicate()
	if not active or finished or between or results.size() != stage or run.state not in ["won", "lost", "unfinished"]:
		return false
	results.append({"stage": stage + 1, "scenario": run.scenario_id, "result": run.state,
		"abilities": run.experiment.abilities.duplicate(), "levels": levels.duplicate(), "time": run.elapsed, "hp": run.hp,
		"cooldown": run.nana.cooldown, "kills": run.kills, "counts": run.experiment.counts.duplicate()})
	run.experiment.context["results"] = results.duplicate(true)
	if run.experiment.save(run, run.state).is_empty():
		save_failures += 1
	between = run.state == "won" and stage < stages().size() - 1
	finished = not between
	if between:
		snapshot = {"hp": minf(run.max_hp, run.hp + HEAL), "cooldown": run.nana.cooldown,
			"ultimate": run.nana.ultimate_remaining, "bite": run.nana.bite_charge,
			"max_hp": run.max_hp, "level": run.level, "xp": run.xp,
			"shot_timer": maxf(0.0, run.shot_timer), "abilities": run.experiment.abilities.duplicate(),
			"movement_charge": run.nana.movement_charge, "shadow_count": run.nana.shadow_count,
			"shadow_remaining": maxf(0.0, 1.2 - (run.elapsed - run.nana.shadow_last_hit))}
	return true

func choices() -> Array:
	if not between:
		return []
	var options: Array = []
	for id in ["a", "b", "c"]:
		if levels.has(id) and int(levels[id]) < 2:
			options.append({"kind": "upgrade", "id": id, "remove": ""})
	if levels.size() < 2:
		for id in ["a", "b", "c"]:
			if not levels.has(id): options.append({"kind": "add", "id": id, "remove": ""})
	else:
		for removed in ["a", "b", "c"]:
			if not levels.has(removed): continue
			for added in ["a", "b", "c"]:
				if not levels.has(added): options.append({"kind": "replace", "id": added, "remove": removed})
	return options

func advance_growth(run) -> bool:
	if not growth_mode or not active or not between or finished or run.state != "won": return false
	levels = run.growth.levels.duplicate()
	var abilities: Array[String] = []
	for id: String in ["a", "b", "c"]:
		if levels.has(id): abilities.append(id)
	between = false
	stage += 1
	_load_stage(run, abilities)
	return true

func advance(run, selected: Dictionary) -> bool:
	if not active or not between or finished or run.state != "won":
		return false
	var valid := false
	for option in choices():
		if option.kind == selected.get("kind") and option.id == selected.get("id") and option.remove == selected.get("remove", ""):
			valid = true
	if not valid:
		return false
	var kind: String = selected.kind
	var id: String = selected.id
	decisions.append({"after_stage": stage + 1, "kind": kind, "id": id, "remove": str(selected.get("remove", "")), "offered": choices().duplicate(true)})
	if kind == "upgrade":
		levels[id] = 2
	elif kind == "add":
		levels[id] = 1
	elif kind == "replace":
		levels.erase(str(selected.remove))
		levels[id] = 1
	var abilities: Array[String] = []
	for candidate in ["a", "b", "c"]:
		if levels.has(candidate): abilities.append(candidate)
	between = false
	stage += 1
	_load_stage(run, abilities)
	return true

func total_seconds() -> float:
	var total := 0.0
	for result in results:
		total += float(result.time)
	return total
