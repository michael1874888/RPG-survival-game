extends RefCounted
## Short, fixed encounters for checking Nana's attacks and enemy tells.

const CombatGeometry := preload("res://scripts/combat_geometry.gd")

const DEFINITIONS := {
	"chaser": {"hp": 18.0, "speed": 90.0, "radius": 17.0, "damage": 8.0},
	"pursuer": {"hp": 48.0, "speed": 280.0, "radius": 18.0, "damage": 8.0},
	"charger": {"hp": 40.0, "speed": 100.0, "radius": 22.0, "damage": 16.0},
	"thrower": {"hp": 26.0, "speed": 85.0, "radius": 19.0, "damage": 12.0},
	"guard": {"hp": 90.0, "speed": 65.0, "radius": 28.0, "damage": 20.0},
	"elite": {"hp": 260.0, "speed": 65.0, "radius": 34.0, "damage": 20.0},
}
const ENCOUNTERS := {
	"nana_chasers": ["chaser", "chaser", "chaser", "chaser", "chaser"],
	"nana_charger": ["charger", "chaser", "chaser"],
	"nana_thrower": ["thrower", "chaser", "chaser"],
	"nana_guard": ["guard", "chaser", "chaser"],
	"nana_mixed": ["charger", "thrower", "guard", "chaser", "chaser", "chaser"],
	"nana_compare_group": ["chaser", "chaser", "chaser", "chaser", "chaser", "chaser", "chaser", "chaser"],
	"nana_compare_thrower": ["thrower", "chaser", "chaser", "chaser", "chaser"],
	"nana_compare_guard": ["guard", "chaser", "chaser"],
	"nana_compare_elite": ["elite", "chaser", "chaser"],
}

var enemy_projectiles: Array[Dictionary] = []
var next_start: float = 0.0
var spawn_countdown: float = 1.0
var pending_spawns: Array[Dictionary] = []
var elite_scheduled: bool = false
var elite_defeated: bool = false
var retry_queue: Array[String] = []
var retry_countdown: float = 0.0
var special_countdown: float = 24.0
var sample_countdown: float = 1.0
var population_samples: Array[int] = []
var spawn_stats: Dictionary = {}

func reset(run, scenario: String) -> void:
	enemy_projectiles.clear()
	next_start = 0.0
	spawn_countdown = 1.0
	pending_spawns.clear()
	retry_queue.clear()
	retry_countdown = 0.0
	special_countdown = 24.0
	sample_countdown = 1.0
	population_samples.clear()
	spawn_stats = {"requested": 0, "warned": 0, "born": 0, "cancelled": 0, "retried": 0}
	elite_scheduled = false
	elite_defeated = false
	if not ENCOUNTERS.has(scenario):
		return
	var kinds: Array = ENCOUNTERS[scenario]
	for i in kinds.size():
		var angle: float = TAU * float(i) / float(kinds.size())
		add_enemy(run, kinds[i], run.player + Vector2.RIGHT.rotated(angle) * 320.0)

func add_enemy(run, kind: String, pos: Vector2) -> void:
	var data: Dictionary = DEFINITIONS[kind]
	run.enemies.append({"id": run.next_enemy_id, "pos": pos, "kind": kind,
		"hp": data.hp, "max_hp": data.hp, "speed": data.speed, "radius": data.radius,
		"damage": data.damage, "phase": "chase", "timer": 0.0, "dir": Vector2.RIGHT,
		"flash": 0.0, "visible_time": 0.0, "heavy_resist": 0.0, "extended": false})
	run.next_enemy_id += 1

func heavy_hit(enemy: Dictionary) -> void:
	var kind: String = enemy.kind
	if kind in ["charger", "thrower"] and enemy.phase == "windup" and float(enemy.get("heavy_resist", 0.0)) <= 0.0:
		enemy.phase = "recover"
		enemy.timer = 1.1 if kind == "charger" else 1.0
		enemy.heavy_resist = 2.0
	elif kind in ["guard", "elite"] and enemy.phase == "recover" and not bool(enemy.get("extended", false)):
		enemy.timer = float(enemy.timer) + 0.2
		enemy.extended = true

func can_start(run, windup: float) -> bool:
	var active: int = enemy_projectiles.size()
	for e: Dictionary in run.enemies:
		if float(e.hp) > 0.0 and e.phase in ["windup", "dash", "second_wait"]:
			active += 1
	return active < 2 and run.elapsed + windup >= next_start

func update_legacy_growth(run, delta: float) -> void:
	for i in range(pending_spawns.size() - 1, -1, -1):
		var spawn: Dictionary = pending_spawns[i]
		spawn.timer = float(spawn.timer) - delta
		if float(spawn.timer) <= 0.0:
			if Vector2(spawn.pos).distance_to(run.player) >= 320.0:
				add_enemy(run, spawn.kind, spawn.pos)
			pending_spawns.remove_at(i)
			if spawn.kind == "elite" and Vector2(spawn.pos).distance_to(run.player) < 320.0:
				elite_scheduled = false
	spawn_countdown -= delta
	if spawn_countdown > 0.0:
		return
	var breathing: bool = fmod(run.elapsed, 45.0) >= 36.0
	spawn_countdown = 2.8 if breathing else maxf(0.65, 1.5 - run.elapsed / 500.0)
	if run.enemies.size() + pending_spawns.size() >= 45:
		return
	var kind: String = "chaser"
	if run.elapsed >= 150.0 and not elite_scheduled and not elite_defeated:
		kind = "elite"
	elif run.elapsed >= 24.0:
		var available: Array[String] = ["chaser", "chaser", "chaser", "charger"]
		if run.elapsed >= 50.0:
			available.append("thrower")
		if run.elapsed >= 80.0:
			available.append("guard")
		kind = available[run.rng.randi_range(0, available.size() - 1)]
		var active: int = 0
		for e: Dictionary in run.enemies:
			if e.kind == kind and float(e.hp) > 0.0:
				active += 1
		for spawn: Dictionary in pending_spawns:
			if spawn.kind == kind:
				active += 1
		if kind != "chaser" and active >= (1 if kind == "guard" else 2):
			kind = "chaser"
	var bounds := Rect2(run.camera_origin() + Vector2(40, 40), run.view_size - Vector2(80, 80))
	for attempt in 24:
		var pos := Vector2(run.rng.randf_range(bounds.position.x, bounds.end.x), run.rng.randf_range(bounds.position.y, bounds.end.y))
		if pos.distance_to(run.player) < 320.0:
			continue
		pending_spawns.append({"kind": kind, "pos": pos, "timer": 1.0})
		if kind == "elite":
			elite_scheduled = true
		return

# Capacity includes warnings and retries, so cancelled warnings remain bounded.
func _occupied(run) -> int:
	return run.enemies.size() + pending_spawns.size() + retry_queue.size()

func _warn_spawn(run, kind: String) -> bool:
	var bounds := Rect2(run.camera_origin() + Vector2(40, 40), run.view_size - Vector2(80, 80))
	for attempt in 32:
		var pos := Vector2(run.rng.randf_range(bounds.position.x, bounds.end.x), run.rng.randf_range(bounds.position.y, bounds.end.y))
		if pos.distance_to(run.player) < 320.0:
			continue
		var clear: bool = true
		for pending: Dictionary in pending_spawns:
			if pos.distance_to(pending.pos) < 40.0:
				clear = false
				break
		if clear:
			pending_spawns.append({"kind": kind, "pos": pos, "timer": 1.0})
			spawn_stats.warned += 1
			return true
	return false

func _count_kind(run, kind: String) -> int:
	var count: int = 0
	for enemy: Dictionary in run.enemies:
		if enemy.kind == kind and float(enemy.hp) > 0.0:
			count += 1
	for spawn: Dictionary in pending_spawns:
		if spawn.kind == kind:
			count += 1
	for queued: String in retry_queue:
		if queued == kind:
			count += 1
	return count

func _request(run, kind: String) -> bool:
	if _occupied(run) >= 45:
		return false
	if not _warn_spawn(run, kind):
		return false
	spawn_stats.requested += 1
	if kind == "elite":
		elite_scheduled = true
	return true

func update_growth(run, delta: float) -> void:
	for i in range(pending_spawns.size() - 1, -1, -1):
		var spawn: Dictionary = pending_spawns[i]
		spawn.timer = float(spawn.timer) - delta
		if float(spawn.timer) <= 0.0:
			if Vector2(spawn.pos).distance_to(run.player) >= 320.0:
				add_enemy(run, spawn.kind, spawn.pos)
				spawn_stats.born += 1
			else:
				retry_queue.append(spawn.kind)
				spawn_stats.cancelled += 1
			pending_spawns.remove_at(i)
	retry_countdown -= delta
	if retry_countdown <= 0.0 and not retry_queue.is_empty():
		if _warn_spawn(run, retry_queue[0]):
			retry_queue.pop_front()
			spawn_stats.retried += 1
		retry_countdown = 0.45
	if run.elapsed >= 150.0 and not elite_scheduled and not elite_defeated:
		_request(run, "elite")
	special_countdown -= delta
	if special_countdown <= 0.0:
		special_countdown = 8.0
		var kinds: Array[String] = ["charger"]
		if run.elapsed >= 50.0:
			kinds.append("thrower")
		if run.elapsed >= 80.0:
			kinds.append("guard")
		var kind: String = kinds[run.rng.randi_range(0, kinds.size() - 1)]
		if _count_kind(run, kind) < (1 if kind == "guard" else 2):
			_request(run, kind)
	spawn_countdown -= delta
	if spawn_countdown <= 0.0:
		var phase: float = fmod(run.elapsed, 35.0)
		var breathing: bool = phase >= 28.0
		var peak: bool = phase >= 22.0 and not breathing
		spawn_countdown = 3.5 if breathing else (2.0 if peak else 2.4)
		var target: int = 12 if run.elapsed < 30.0 else (16 if breathing else (36 if peak else 24))
		var amount: int = 2 if breathing else (5 if peak else 3)
		# Reserve room for the required elite before it becomes eligible.
		var limit: int = 44 if run.elapsed >= 145.0 and not elite_scheduled and not elite_defeated else 45
		for i in mini(amount, maxi(0, mini(target, limit) - _occupied(run))):
			_request(run, "chaser")
	sample_countdown -= delta
	if sample_countdown <= 0.0:
		population_samples.append(run.enemies.size())
		sample_countdown += 1.0

func update(run, delta: float) -> void:
	for e: Dictionary in run.enemies:
		if float(e.hp) <= 0.0:
			continue
		e.flash = maxf(0.0, float(e.flash) - delta)
		e.vulnerable = maxf(0.0, float(e.get("vulnerable", 0.0)) - delta)
		e.heavy_resist = maxf(0.0, float(e.get("heavy_resist", 0.0)) - delta)
		var pos: Vector2 = e.pos
		var offset: Vector2 = run.player - pos
		var distance: float = offset.length()
		var kind: String = e.kind
		var visible := Rect2(run.camera_origin(), run.view_size).has_point(pos)
		e.visible_time = float(e.get("visible_time", 0.0)) + delta if visible else 0.0
		if kind in ["chaser", "pursuer"]:
			var separation := Vector2.ZERO
			if run.experiment.active or run.scenario_id == "nana_growth" or run.scenario_id.begins_with("nana_pressure_"):
				for other: Dictionary in run.enemies:
					if other == e or float(other.hp) <= 0.0:
						continue
					var away: Vector2 = pos - Vector2(other.pos)
					if away.length_squared() > 0.01 and away.length() < float(e.radius) + float(other.radius):
						separation += away.normalized()
			var velocity: Vector2 = (offset.normalized() + separation.limit_length() * 0.6).limit_length() * float(e.speed)
			e.pos = (pos + velocity * delta).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
			if Vector2(e.pos).distance_to(run.player) <= float(e.radius) + run.PLAYER_RADIUS:
				run.take_damage(float(e.damage), kind)
			continue
		e.timer = maxf(0.0, float(e.timer) - delta)
		if e.phase == "chase":
			var threshold: float = 390.0 if kind == "charger" else (380.0 if kind == "thrower" else 170.0)
			var windup: float = 0.9 if kind == "charger" else (0.8 if kind == "thrower" else 1.1)
			if distance <= threshold and float(e.visible_time) >= 0.5 and can_start(run, windup):
				e.phase = "windup"
				e.timer = windup
				e.dir = offset.normalized() if distance > 0.001 else Vector2.RIGHT
				e.extended = false
				next_start = run.elapsed + windup + 0.4
			else:
				var move: Vector2 = offset.normalized() * float(e.speed) * delta
				if kind == "thrower" and distance < 300.0:
					move = -move
				e.pos = (pos + move).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
		elif e.phase == "windup" and float(e.timer) <= 0.0:
			if kind == "charger":
				e.phase = "dash"
				e.timer = 0.55
			elif kind == "thrower":
				enemy_projectiles.append({"pos": pos, "dir": e.dir, "life": 650.0 / 210.0, "damage": e.damage})
				e.phase = "recover"
				e.timer = 2.2
			else:
				if CombatGeometry.sector_circle(pos, e.dir, run.player, run.PLAYER_RADIUS, 170.0, deg_to_rad(55.0)):
					run.take_damage(float(e.damage), kind)
				if kind == "elite" and not bool(e.get("second_strike", false)):
					e.phase = "second_wait"
					e.timer = 0.5
				else:
					e.phase = "recover"
					e.timer = 1.8 if kind == "elite" else 1.3
		elif e.phase == "second_wait" and float(e.timer) <= 0.0:
			e.phase = "windup"
			e.timer = 0.9
			e.dir = offset.normalized() if distance > 0.001 else Vector2.RIGHT
			e.second_strike = true
		elif e.phase == "dash":
			var next: Vector2 = (pos + Vector2(e.dir) * 430.0 * delta).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(run.player, pos, next)
			if closest.distance_to(run.player) <= float(e.radius) + run.PLAYER_RADIUS:
				run.take_damage(float(e.damage), kind)
			e.pos = next
			if float(e.timer) <= 0.0 or next.distance_to(pos + Vector2(e.dir) * 430.0 * delta) > 0.01:
				e.phase = "recover"
				e.timer = 1.1
		elif e.phase == "recover" and float(e.timer) <= 0.0:
			e.phase = "chase"
			e.second_strike = false
	for i in range(enemy_projectiles.size() - 1, -1, -1):
		var p: Dictionary = enemy_projectiles[i]
		var from: Vector2 = p.pos
		var to: Vector2 = from + Vector2(p.dir) * 210.0 * delta
		p.pos = to
		p.life = float(p.life) - delta
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(run.player, from, to)
		if closest.distance_to(run.player) <= run.PLAYER_RADIUS + 8.0:
			run.take_damage(float(p.damage), "thrower_projectile")
			enemy_projectiles.remove_at(i)
		elif float(p.life) <= 0.0 or not Rect2(Vector2.ZERO, run.WORLD).has_point(to):
			enemy_projectiles.remove_at(i)
