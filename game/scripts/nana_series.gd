extends RefCounted
## Three fixed encounters, with explicit choices and combat state carried between them.

const STAGES := ["nana_build_e1", "nana_build_e2", "nana_build_e3"]
const HEAL := 25.0
const VERSION := "nana-series-v2"
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

func begin(run, ability: String) -> bool:
	if ability not in ["a", "b", "c"]:
		return false
	active = true
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
	_load_stage(run, [ability])
	return true

func _load_stage(run, abilities: Array) -> void:
	run.reset(0, "nana", "standard", STAGES[stage])
	run.experiment.configure(run, abilities, {"levels": levels})
	if not snapshot.is_empty():
		run.hp = float(snapshot.hp)
		run.nana.cooldown = float(snapshot.cooldown)
		run.nana.ultimate_remaining = float(snapshot.ultimate)
		run.nana.bite_charge = int(snapshot.bite)
		run.shot_timer = float(snapshot.shot_timer)
		if "a" in abilities and "a" in snapshot.abilities and float(snapshot.shadow_remaining) > 0.0:
			run.nana.shadow_count = int(snapshot.shadow_count)
			run.nana.shadow_last_hit = -(1.2 - float(snapshot.shadow_remaining))
		if "b" in abilities and "b" in snapshot.abilities:
			run.nana.movement_charge = float(snapshot.movement_charge)
	run.experiment.context = {"mode": "series", "rules": VERSION, "series_id": series_id, "stage": stage + 1,
		"starting_hp": run.hp, "starting_cooldown": run.nana.cooldown,
		"previous_results": results.duplicate(true), "decisions": decisions.duplicate(true)}
	run.experiment.note(run, "series_stage_start", run.experiment.context)

func collect(run) -> bool:
	if not active or finished or between or results.size() != stage or run.state not in ["won", "lost", "unfinished"]:
		return false
	results.append({"stage": stage + 1, "scenario": run.scenario_id, "result": run.state,
		"abilities": run.experiment.abilities.duplicate(), "levels": levels.duplicate(), "time": run.elapsed, "hp": run.hp,
		"cooldown": run.nana.cooldown, "kills": run.kills, "counts": run.experiment.counts.duplicate()})
	run.experiment.context["results"] = results.duplicate(true)
	if run.experiment.save(run, run.state).is_empty():
		save_failures += 1
	between = run.state == "won" and stage < STAGES.size() - 1
	finished = not between
	if between:
		snapshot = {"hp": minf(run.max_hp, run.hp + HEAL), "cooldown": run.nana.cooldown,
			"ultimate": run.nana.ultimate_remaining, "bite": run.nana.bite_charge,
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
