extends "res://scripts/nana_experiment.gd"
## Finite, reproducible first-chapter encounters. Entries are also drawn as warnings.

const BUDGETS := [18, 24, 42, 54, 60, 66, 60, 66, 0]
const RECIPES := {
	1: [[{"chaser": 5}, {"chaser": 6}, {"chaser": 7}], [{"chaser": 6}, {"chaser": 6}, {"chaser": 6}]],
	2: [[{"chaser": 5}, {"chaser": 5, "pursuer": 1}, {"chaser": 6, "charger": 1}], [{"chaser": 5}, {"chaser": 5, "charger": 1}, {"chaser": 6, "thrower": 1}]],
	4: [[{"chaser": 6, "charger": 1}, {"chaser": 7, "thrower": 1}, {"chaser": 8, "pursuer": 1}], [{"chaser": 6, "thrower": 1}, {"chaser": 7, "pursuer": 1}, {"chaser": 8, "charger": 1}]],
	5: [[{"chaser": 6, "guard": 1}, {"chaser": 7, "pursuer": 1}, {"chaser": 8, "thrower": 1}], [{"chaser": 6, "charger": 1}, {"chaser": 7, "thrower": 1}, {"chaser": 8, "guard": 1}]],
	7: [[{"chaser": 7, "pursuer": 1}, {"chaser": 8, "thrower": 1}, {"chaser": 8, "guard": 1}], [{"chaser": 7, "charger": 1}, {"chaser": 8, "pursuer": 1}, {"chaser": 8, "thrower": 1}]],
	8: [[{"chaser": 8, "pursuer": 1}, {"chaser": 8, "charger": 1}, {"chaser": 8, "guard": 1, "thrower": 1}], [{"chaser": 8, "thrower": 1}, {"chaser": 8, "pursuer": 1}, {"chaser": 8, "charger": 1, "guard": 1}]],
}
const ELITE_SUPPORT := {
	3: [[{"chaser": 6}, {"chaser": 4, "pursuer": 1}], [{"chaser": 4, "charger": 1}, {"chaser": 6}]],
	6: [[{"chaser": 6, "thrower": 1}, {"chaser": 6}], [{"chaser": 6, "charger": 1}, {"chaser": 6}]],
}
const KIND_CAP := {"pursuer": 3, "charger": 2, "thrower": 2, "guard": 2, "elite": 1}
const WEIGHTS := {"chaser": 1, "pursuer": 2, "charger": 2, "thrower": 2, "guard": 3, "elite": 8}

var node := 1
var route_event := ""
var boss_defeated := false
var boss_phase := 0
var next_boss_support := 0.0
var last_boss_support_cycle := 0
var event_success := false
var event_target_id := -1
var event_elapsed := 0.0
var package_pos := Vector2.ZERO
var package_progress := 0.0
var event_elite_started := false
var r1_seed := 0


func configure_r1(run, current_node: int, seed_value: int, selected_event: String) -> void:
	super.configure(run, [run.growth.opening], {"growth_mode": true, "levels": run.growth.levels})
	abilities.clear()
	for id: String in ["a", "b", "c"]:
		if run.growth.levels.has(id): abilities.append(id)
	levels = run.growth.levels.duplicate()
	charged_mark_bonus = "S05" in run.growth.links
	schedule.clear()
	timeline.clear()
	node = current_node
	route_event = selected_event if node in [4, 7] else ""
	boss_defeated = false
	boss_phase = 0
	next_boss_support = 0.0
	last_boss_support_cycle = 0
	event_success = false
	event_target_id = -1
	event_elapsed = 0.0
	package_progress = 0.0
	event_elite_started = false
	r1_seed = seed_value
	package_pos = run.player + Vector2(145, 0)
	var variant: int = absi(seed_value + node * 31) % 2
	if node in [3, 6]:
		_add_group({"elite": 1}, 0.0, 0, "warden" if node == 3 else "stalker")
		var supports: Array = ELITE_SUPPORT[node][variant]
		_add_group(supports[0], 0.0, 0)
		_add_group(supports[1], 20.0, 1)
	elif node == 9:
		_add_group({"elite": 1}, 0.0, 0, "boss")
	else:
		var waves: Array = RECIPES[node][variant].duplicate(true)
		if route_event == "EV03":
			# Show a back-line threat early without adding enemies or changing the XP budget.
			var moved := false
			for i in range(1, waves.size()):
				if not moved and int(waves[i].get("thrower", 0)) > 0 and int(waves[0].get("chaser", 0)) > 0:
					waves[i]["thrower"] = int(waves[i].thrower) - 1
					waves[i]["chaser"] = int(waves[i].get("chaser", 0)) + 1
					waves[0]["chaser"] = int(waves[0].chaser) - 1
					waves[0]["thrower"] = int(waves[0].get("thrower", 0)) + 1
					moved = true
		if route_event == "EV05":
			waves[0]["chaser"] = int(waves[0].get("chaser", 0)) - 6
		for i in waves.size(): _add_group(waves[i], float(i * 20), i)
		if route_event == "EV05": _add_group({"elite": 1}, 0.0, 0, "event_stalker", true)
		if route_event == "EV06":
			_add_group({"pursuer": 1}, 10.0, 100, "event_extra", true)
			_add_group({"pursuer": 1}, 20.0, 100, "event_extra", true)
		if route_event == "EV04": _add_group({"elite": 1}, 1000000.0, 101, "event_warden", true)
	_assign_xp()


func _add_group(group: Dictionary, at: float, wave: int, variant := "", no_xp := false) -> void:
	for kind: String in group:
		for i in int(group[kind]):
			var angle := TAU * float((schedule.size() * 7 + wave * 5) % 24) / 24.0
			if route_event == "EV02" and kind == "chaser":
				angle = (0.0 if i % 2 == 0 else PI) + float(int(i / 2) - 2) * 0.08
			schedule.append({"id": schedule.size() + 1, "at": at, "kind": kind, "pos": initial_position,
				"angle": angle, "state": "scheduled", "conditional": false, "warned_once": false,
				"timer": 0.0, "wave": wave, "variant": variant, "xp_value": 0, "no_xp": no_xp})


func _assign_xp() -> void:
	var eligible: Array[Dictionary] = []
	var total_weight := 0
	for entry: Dictionary in schedule:
		if not bool(entry.no_xp) and node != 9:
			eligible.append(entry)
			total_weight += int(WEIGHTS[entry.kind])
	if eligible.is_empty(): return
	var remainder: int = BUDGETS[node - 1] - eligible.size()
	assert(remainder >= 0)
	var cumulative := 0
	for entry: Dictionary in eligible:
		var before := cumulative
		cumulative += int(WEIGHTS[entry.kind])
		entry.xp_value = 1 + floori(float(remainder * cumulative) / total_weight) - floori(float(remainder * before) / total_weight)


func _earlier_wave_cleared(run, wave: int) -> bool:
	for entry: Dictionary in schedule:
		if int(entry.wave) != wave: continue
		if node in [3, 6] and wave == 0 and entry.kind == "elite": continue
		if entry.state not in ["born", "cancelled"]: return false
		if entry.state == "born":
			for enemy: Dictionary in run.enemies:
				if int(enemy.id) == int(entry.get("enemy_id", -1)) and float(enemy.hp) > 0.0: return false
	return true


func update_schedule(run, delta: float) -> void:
	event_elapsed += delta
	if route_event == "EV06" and not event_success and event_elapsed <= 35.0:
		if run.player.distance_to(package_pos) <= 90.0:
			package_progress += delta
			if package_progress >= 6.0: event_success = true
	# Early wave release gives strong builds a faster completion, without deleting enemies.
	for wave in [1, 2]:
		var elite_gone := false
		if node in [3, 6] and wave == 1:
			for entry: Dictionary in schedule:
				if entry.kind != "elite" or entry.state != "born": continue
				elite_gone = true
				for enemy: Dictionary in run.enemies:
					if int(enemy.id) == int(entry.get("enemy_id", -1)) and float(enemy.hp) > 0.0: elite_gone = false
		if _earlier_wave_cleared(run, wave - 1) or elite_gone:
			for entry: Dictionary in schedule:
				if int(entry.wave) == wave and entry.state == "scheduled": entry.at = minf(float(entry.at), run.elapsed)
	if route_event == "EV04" and not event_elite_started and _earlier_wave_cleared(run, 0) and _earlier_wave_cleared(run, 1) and _earlier_wave_cleared(run, 2):
		for entry: Dictionary in schedule:
			if entry.variant == "event_warden": entry.at = run.elapsed
		event_elite_started = true
	var boss_cycle := -1
	if node == 9 and boss_phase > 0 and not boss_defeated:
		for enemy: Dictionary in run.enemies:
			if enemy.get("variant", "") == "boss" and float(enemy.hp) > 0.0:
				boss_cycle = int(enemy.get("attack_cycle", 0))
				break
	if boss_cycle >= last_boss_support_cycle + 2 and run.elapsed >= next_boss_support:
		var support_count := 0
		for enemy: Dictionary in run.enemies:
			if enemy.get("variant", "") == "boss_support": support_count += 1
		for entry: Dictionary in schedule:
			if entry.get("variant", "") == "boss_support" and entry.state in ["scheduled", "warning", "retry"]: support_count += 1
		if support_count == 0:
			_add_group({"chaser": 2} if boss_phase == 1 else {"chaser": 1, "pursuer": 1}, run.elapsed, 102, "boss_support", true)
			last_boss_support_cycle = boss_cycle
			next_boss_support = run.elapsed + 15.0
	for entry: Dictionary in schedule:
		if entry.state in ["born", "cancelled"]: continue
		if boss_defeated and node == 9:
			entry.state = "cancelled"
			continue
		if entry.state == "warning":
			entry.timer = float(entry.timer) - delta
			if float(entry.timer) <= 0.0:
				if Vector2(entry.pos).distance_to(run.player) >= SAFE_DISTANCE:
					run.encounters.add_enemy(run, entry.kind, entry.pos)
					var enemy: Dictionary = run.enemies[-1]
					entry.state = "born"
					entry.enemy_id = int(enemy.id)
					enemy["born_at"] = run.elapsed
					enemy["xp_value"] = int(entry.xp_value)
					enemy["variant"] = str(entry.variant)
					if entry.variant in ["warden", "event_warden"]:
						enemy.hp = 160.0 if entry.variant == "event_warden" else 240.0
						enemy.speed = 70.0
						enemy.radius = 32.0
					elif entry.variant in ["stalker", "event_stalker"]:
						enemy.hp = 120.0 if entry.variant == "event_stalker" else 200.0
						enemy.speed = 280.0
						enemy.radius = 26.0
						enemy.damage = 14.0
					elif entry.variant == "boss":
						enemy.hp = 900.0
						enemy.radius = 40.0
						enemy.speed = 70.0
					if not str(entry.variant).is_empty() and str(entry.kind) == "elite": enemy.max_hp = enemy.hp
					if entry.variant == "event_stalker": event_target_id = int(enemy.id)
				else:
					entry.state = "retry"
			continue
		if run.elapsed < float(entry.at): continue
		var kind: String = entry.kind
		var count := 0
		for enemy: Dictionary in run.enemies:
			if enemy.kind == kind and float(enemy.hp) > 0.0: count += 1
		for other: Dictionary in schedule:
			if other.state == "warning" and other.kind == kind: count += 1
		if KIND_CAP.has(kind) and count >= int(KIND_CAP[kind]): continue
		if run.enemies.size() + _reserved() >= LIMIT: continue
		var point: Vector2 = _safe_anchor(run, entry)
		if point == Vector2.INF: continue
		entry.pos = point
		entry.state = "warning"
		entry.warned_once = true
		entry.timer = WARNING


func on_enemy_damage(run, enemy: Dictionary, before: float) -> void:
	if enemy.get("variant", "") == "boss":
		if float(enemy.hp) <= 0.0:
			boss_defeated = true
			return
		var phase := 2 if float(enemy.hp) <= 270.0 else (1 if float(enemy.hp) <= 540.0 else 0)
		if phase > boss_phase:
			if boss_phase == 0: last_boss_support_cycle = int(enemy.get("attack_cycle", 0))
			boss_phase = phase
			next_boss_support = maxf(run.elapsed, next_boss_support)
			run.events.append({"kind": "guardian_wave", "pos": enemy.pos})
	if enemy.get("variant", "") == "event_stalker" and before > 0.0 and float(enemy.hp) <= 0.0 and event_elapsed <= 45.0:
		event_success = true


func note(run, kind: String, data: Dictionary = {}) -> void:
	super.note(run, kind, data)
	if timeline.size() > 2000: timeline.pop_front()
