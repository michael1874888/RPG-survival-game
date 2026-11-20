extends RefCounted
## Shared movement and phase helpers for enemy behaviours.


static func tick(e: Dictionary, dt: float) -> bool:
	e.timer = float(e.timer) - dt
	return float(e.timer) <= 0.0


static func start(b, e: Dictionary, phase: String, duration: float, tele: Dictionary = {}) -> void:
	e.phase = phase
	e.timer = duration
	e.windup_total = duration
	e.tele = tele.duplicate()
	if not tele.is_empty():
		e.tele["dir"] = e.dir
		b.event("telegraph", {"pos": e.pos, "kind": e.kind, "role": e.role, "time": duration})


## Keep roughly `keep` distance: approach, back off, or circle.
static func keep_distance(b, e: Dictionary, keep: float, dt: float, speed_scale := 1.0) -> void:
	var distance: float = b.dist_to_player(e)
	var dir: Vector2 = b.dir_to_player(e)
	var speed: float = float(e.speed) * speed_scale
	var velocity := Vector2.ZERO
	if distance > keep + 40.0: velocity = dir * speed
	elif distance < keep - 40.0: velocity = -dir * speed
	else: velocity = dir.orthogonal() * speed * 0.4 * (1.0 if int(e.id) % 2 == 0 else -1.0)
	b.move_enemy(e, velocity, dt)


static func approach(b, e: Dictionary, stop: float, dt: float, speed_scale := 1.0) -> void:
	if b.dist_to_player(e) > stop:
		b.move_enemy(e, b.dir_to_player(e) * float(e.speed) * speed_scale, dt)


## Dash along e.dir; returns true when the dash should end (time up or blocked).
static func dash(b, e: Dictionary, speed: float, dt: float, max_travel: float = -1.0) -> bool:
	var from: Vector2 = e.pos
	var blocked: bool = b.move_enemy(e, Vector2(e.dir) * speed, dt)
	e.travel = float(e.get("travel", 0.0)) + from.distance_to(e.pos)
	if not e.get("hit_done", false):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(b.player.pos, from, e.pos)
		if closest.distance_to(b.player.pos) <= float(e.radius) + b.player_radius():
			b.hurt_player(float(e.damage), str(e.kind), from)
			e.hit_done = true
	e.timer = float(e.timer) - dt
	if blocked: return true
	if max_travel > 0.0 and float(e.travel) >= max_travel: return true
	return max_travel <= 0.0 and float(e.timer) <= 0.0


static func boss_phase(b, e: Dictionary) -> int:
	var s: Dictionary = b.spec(e)
	var ratio: float = float(e.hp) / maxf(1.0, float(e.max_hp))
	var last: float = float(b.mods.get("boss_phase2", s.get("phase2", 0.3)))
	if ratio <= last: return 2
	if ratio <= float(s.get("phase1", 0.6)): return 1
	return 0


## Phase changes announce themselves; in the last phase support arrives on a timer.
static func boss_support(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	var phase := boss_phase(b, e)
	if phase != int(e.get("phase_level", 0)):
		e.phase_level = phase
		e.support_timer = 2.0
		b.event("boss_phase", {"pos": e.pos, "phase": phase})
	if phase < 2 or not s.has("support2"): return
	e.support_timer = float(e.get("support_timer", 0.0)) - dt
	if float(e.support_timer) > 0.0: return
	e.support_timer = float(s.get("support_every", 15.0))
	call_support(b, e, s.support2)


static func call_support(b, e: Dictionary, kinds: Array) -> void:
	if b.support_count(int(e.id)) >= 2: return
	for kind_id in kinds:
		if b.support_count(int(e.id)) >= 2: break
		var offset := Vector2.RIGHT.rotated(b.rng_spawn.randf() * TAU) * 150.0
		b.spawner.queue(b, str(kind_id), b.obstacles.resolve(e.pos + offset, 20.0),
			{"summoned": true, "no_xp": true, "summoner": int(e.id), "support": true})
