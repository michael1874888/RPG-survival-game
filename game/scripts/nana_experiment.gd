extends RefCounted
## Isolated encounter schedule and observations for Nana's build experiment.

const VERSION := "nana-build-v2.1"
const LIMIT := 45
const WARNING := 1.0
const SAFE_DISTANCE := 320.0

var active := false
var abilities: Array[String] = []
var schedule: Array[Dictionary] = []
var timeline: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var counts := {"shadow": 0, "shadow_hits": 0, "charged": 0, "charged_hits": 0, "mark": 0, "cash": 0}
var hitstop := 0.0
var hitstop_seconds := 0.0
var pause_seconds := 0.0
var wall_seconds := 0.0
var started_usec := 0
var paused_usec := 0
var sample_timer := 0.0
var move_distance := 0.0
var initial_position := Vector2.ZERO
var elite_born := false
var logged := false
var saved_path := ""
var input_kind := "unknown"


func configure(run, selected: Array) -> void:
	active = true
	abilities.clear()
	for id in selected:
		if id in ["a", "b", "c"] and id not in abilities and abilities.size() < 2:
			abilities.append(id)
	schedule.clear()
	timeline.clear()
	samples.clear()
	counts = {"shadow": 0, "shadow_hits": 0, "charged": 0, "charged_hits": 0, "mark": 0, "cash": 0}
	hitstop = 0.0
	hitstop_seconds = 0.0
	pause_seconds = 0.0
	wall_seconds = 0.0
	started_usec = Time.get_ticks_usec()
	paused_usec = 0
	sample_timer = 0.0
	move_distance = 0.0
	initial_position = run.player
	elite_born = false
	logged = false
	saved_path = ""
	input_kind = "unknown"
	match run.scenario_id:
		"nana_build_e1":
			_add_wave(0.0, "chaser", 8, 0)
			for i in range(1, 9):
				_add_wave(float(i * 2), "chaser", 4, 1 if i % 2 == 1 else -1)
		"nana_build_e2":
			_add_wave(0.0, "chaser", 5, 0)
			_add_wave(0.0, "thrower", 1, 1)
			_add_wave(4.0, "guard", 1, -1)
			_add_wave(4.0, "chaser", 3, -1)
			_add_wave(10.0, "charger", 1, 1)
			_add_wave(10.0, "thrower", 1, -1)
			_add_wave(10.0, "chaser", 4, 1)
			_add_wave(15.0, "chaser", 4, -1)
		"nana_build_e3":
			_add_wave(0.0, "elite", 1, 1)
			_add_wave(0.0, "chaser", 3, -1)
			for t in [2, 8, 14, 20, 26, 32, 38]:
				_add_wave(float(t), "chaser", 3, 1 if int(t) % 4 == 2 else -1, true)
	note(run, "start", {"abilities": abilities.duplicate(), "scenario": run.scenario_id})


func _add_wave(at: float, kind: String, amount: int, side: int, conditional: bool = false) -> void:
	for i in amount:
		var angle: float
		if side == 0:
			angle = TAU * float(i) / float(amount)
		else:
			angle = (0.0 if side > 0 else PI) + (float(i) - float(amount - 1) * 0.5) * 0.21
		var point := initial_position + Vector2.RIGHT.rotated(angle) * (370.0 + 15.0 * float(i % 2))
		schedule.append({"id": schedule.size() + 1, "at": at, "kind": kind, "pos": point, "angle": angle,
			"state": "scheduled", "conditional": conditional, "warned_once": false, "timer": 0.0})


func note(run, kind: String, data: Dictionary = {}) -> void:
	if not active:
		return
	var entry := {"time": run.elapsed, "wall_seconds": float(Time.get_ticks_usec() - started_usec) / 1000000.0, "kind": kind}
	entry.merge(data, true)
	timeline.append(entry)


func request_hitstop() -> void:
	hitstop = maxf(hitstop, 0.05)


func clock(_delta: float, _state: String) -> void:
	if not active or logged:
		return
	wall_seconds = float(Time.get_ticks_usec() - started_usec) / 1000000.0


func pause_clock() -> void:
	if active and paused_usec == 0:
		paused_usec = Time.get_ticks_usec()


func resume_clock() -> void:
	if active and paused_usec != 0:
		pause_seconds += float(Time.get_ticks_usec() - paused_usec) / 1000000.0
		paused_usec = 0


func update_schedule(run, delta: float) -> void:
	for entry: Dictionary in schedule:
		if entry.state in ["born", "cancelled"]:
			continue
		if bool(entry.conditional) and run.encounters.elite_defeated and not bool(entry.warned_once):
			entry.state = "cancelled"
			note(run, "spawn_cancelled", {"event_id": entry.id, "reason": "elite_defeated"})
			continue
		if entry.state == "warning":
			entry.timer = float(entry.timer) - delta
			if float(entry.timer) <= 0.0:
				if Vector2(entry.pos).distance_to(run.player) >= SAFE_DISTANCE:
					run.encounters.add_enemy(run, entry.kind, entry.pos)
					entry.state = "born"
					entry.enemy_id = run.next_enemy_id - 1
					run.enemies[-1]["born_at"] = run.elapsed
					if entry.kind == "elite":
						elite_born = true
						run.encounters.elite_scheduled = true
					note(run, "spawn_born", {"event_id": entry.id, "enemy_id": entry.enemy_id, "enemy_kind": entry.kind})
				else:
					entry.state = "retry"
					note(run, "spawn_retry", {"event_id": entry.id})
			continue
		if run.elapsed < float(entry.at) or (bool(entry.conditional) and not elite_born):
			continue
		if run.enemies.size() + _reserved() >= LIMIT and not bool(entry.warned_once):
			continue
		var point: Vector2 = _safe_anchor(run, entry)
		if point == Vector2.INF:
			continue
		entry.pos = point
		entry.state = "warning"
		entry.warned_once = true
		entry.timer = WARNING
		note(run, "spawn_warning", {"event_id": entry.id, "enemy_kind": entry.kind, "pos": [point.x, point.y]})


func _safe_anchor(run, entry: Dictionary) -> Vector2:
	# Deterministic fixed candidates; each retry receives a complete new warning.
	var visible := Rect2(run.camera_origin(), run.view_size).grow(-20.0)
	for radius: float in [370.0, 700.0, 1050.0, 1400.0]:
		for i in 24:
			var angle: float = float(entry.angle) + TAU * float(i) / 24.0
			var point: Vector2 = (initial_position + Vector2.RIGHT.rotated(angle) * radius).clamp(Vector2.ONE * 40.0, run.WORLD - Vector2.ONE * 40.0)
			if not visible.has_point(point) or point.distance_to(run.player) < SAFE_DISTANCE:
				continue
			var clear := true
			for other: Dictionary in schedule:
				if other.state == "warning" and Vector2(other.pos).distance_to(point) < 40.0:
					clear = false
					break
			if clear:
				return point
	return Vector2.INF


func _reserved() -> int:
	var count := 0
	for entry: Dictionary in schedule:
		if entry.state in ["warning", "retry"]:
			count += 1
	return count


func all_finished() -> bool:
	for entry: Dictionary in schedule:
		if entry.state not in ["born", "cancelled"]:
			return false
	return true


func observe(run, delta: float, movement: Vector2, firing: bool, displacement: float) -> void:
	move_distance += displacement
	sample_timer -= delta
	if sample_timer > 0.0:
		return
	sample_timer += 0.1
	var camera: Vector2 = run.camera_origin()
	var visible := Rect2(camera, run.view_size)
	var enemies: Array[Dictionary] = []
	var closest: Variant = null
	var engaged := false
	var projectiles: Array[Dictionary] = []
	for enemy: Dictionary in run.enemies:
		if float(enemy.hp) <= 0.0:
			continue
		var pos: Vector2 = enemy.pos
		var dist: float = pos.distance_to(run.player)
		closest = dist if closest == null else minf(float(closest), dist)
		var is_visible := visible.has_point(pos)
		if is_visible and dist <= 390.0:
			engaged = true
		enemies.append({"id": enemy.id, "kind": enemy.kind, "pos": [pos.x, pos.y],
			"hp": enemy.hp, "visible": is_visible, "phase": enemy.phase})
	for projectile: Dictionary in run.encounters.enemy_projectiles:
		var projectile_pos: Vector2 = projectile.pos
		var projectile_visible: bool = visible.has_point(projectile_pos)
		projectiles.append({"pos": [projectile_pos.x, projectile_pos.y], "visible": projectile_visible})
		if projectile_visible:
			engaged = true
	samples.append({"time": run.elapsed, "player": [run.player.x, run.player.y],
		"movement": [movement.x, movement.y], "aim": [run.aim.x, run.aim.y], "firing": firing,
		"hp": run.hp, "bite_charge": run.nana.bite_charge, "shadow_count": run.nana.shadow_count,
		"movement_charge": run.nana.movement_charge, "prey_id": run.nana.prey_id,
		"prey_remaining": run.nana.prey_remaining, "projectiles": projectiles,
		"enemies": enemies, "nearest": closest, "engaged": engaged, "movement_distance": move_distance})


func engaged(run) -> bool:
	var visible := Rect2(run.camera_origin(), run.view_size)
	for enemy: Dictionary in run.enemies:
		if float(enemy.hp) > 0.0 and visible.has_point(enemy.pos) and Vector2(enemy.pos).distance_to(run.player) <= 390.0:
			return true
	for projectile: Dictionary in run.encounters.enemy_projectiles:
		if visible.has_point(projectile.pos):
			return true
	return false


func save(run, final_state: String) -> String:
	if not active or logged:
		return ""
	resume_clock()
	wall_seconds = float(Time.get_ticks_usec() - started_usec) / 1000000.0
	var output_schedule: Array[Dictionary] = []
	for entry: Dictionary in schedule:
		var copy := entry.duplicate(true)
		var point: Vector2 = copy.pos
		copy.pos = [point.x, point.y]
		output_schedule.append(copy)
	var record := {"version": VERSION, "scenario": run.scenario_id, "abilities": abilities,
		"result": final_state, "game_seconds": run.elapsed, "wall_seconds": wall_seconds,
		"pause_seconds": pause_seconds, "hitstop_seconds": hitstop_seconds,
		"platform": OS.get_name(), "model": OS.get_model_name(), "input": input_kind,
		"counts": counts, "damage": run.combat_metrics.damage,
		"damage_taken": run.combat_metrics.damage_taken, "attacks": run.combat_metrics.attacks, "schedule": output_schedule,
		"timeline": timeline, "samples": samples}
	var dir := "user://build-experiment"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%s-%d.json" % [dir, Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_usec()]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save experiment observations: %s" % FileAccess.get_open_error())
		return ""
	file.store_string(JSON.stringify(record))
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		push_warning("Could not finish saving experiment observations: %s" % error)
		return ""
	logged = true
	saved_path = ProjectSettings.globalize_path(path)
	return saved_path
