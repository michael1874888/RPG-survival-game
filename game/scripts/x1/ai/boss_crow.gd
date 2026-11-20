extends RefCounted
## B03 鐘樓夜鴉: chained straight swoops, and a moon ring that always leaves a safe quarter.

const Common := preload("res://scripts/x1/ai/common.gd")


static func init(_b, e: Dictionary) -> void:
	e.timer = 1.2
	e.next_attack = "swoop"
	e.phase_level = 0
	e.support_timer = 0.0


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	Common.boss_support(b, e, dt)
	match str(e.phase):
		"chase":
			Common.keep_distance(b, e, 260.0, dt)
			if not Common.tick(e, dt): return
			e.timer = 0.0
			if not b.can_attack(e, 2): return
			b.begin_attack(e)
			if e.next_attack == "swoop":
				e.count = 0
				_aim(b, e, s)
			else:
				var safe_dir := Vector2.RIGHT.rotated(b.rng_spawn.randf() * TAU)
				e.safe_dir = safe_dir
				Common.start(b, e, "ring", float(s.ring_windup), {"shape": "ring", "radius": float(s.ring_radius),
					"safe_dir": safe_dir, "safe": float(s.ring_safe)})
		"windup":
			if Common.tick(e, dt):
				e.phase = "swoop"
				e.travel = 0.0
				e.hit_done = false
				e.tele = {}
		"swoop":
			if Common.dash(b, e, float(s.swoop_speed), dt, float(s.swoop_max)):
				e.count = int(e.count) + 1
				var total: int = int(s.swoops2) if int(e.get("phase_level", 0)) >= 1 else int(s.swoops)
				if int(e.count) < total: _aim(b, e, s)
				else: _finish(b, e, float(s.swoop_recover), "ring")
		"ring":
			if Common.tick(e, dt):
				var offset: Vector2 = b.player.pos - e.pos
				var inside: bool = offset.length() <= float(s.ring_radius) + b.player_radius()
				var safe: bool = offset.length() > 0.01 and absf(Vector2(e.safe_dir).angle_to(offset)) <= deg_to_rad(float(s.ring_safe) * 0.5)
				b.event("enemy_strike", {"pos": e.pos, "radius": float(s.ring_radius), "shape": "ring", "safe_dir": e.safe_dir, "safe": float(s.ring_safe)})
				if inside and not safe: b.hurt_player(float(s.ring_damage), str(e.kind))
				_finish(b, e, float(s.ring_recover), "swoop")
		"recover":
			if Common.tick(e, dt):
				e.phase = "chase"
				e.timer = float(s.rest)


static func _aim(b, e: Dictionary, s: Dictionary) -> void:
	e.dir = b.dir_to_player(e)
	e.damage = float(s.swoop_damage)
	Common.start(b, e, "windup", float(s.swoop_windup), {"shape": "line", "length": float(s.swoop_max), "width": float(e.radius) * 2.0})


static func _finish(b, e: Dictionary, recover: float, next: String) -> void:
	b.end_attack(e)
	e.next_attack = next
	e.cycle = int(e.cycle) + 1
	Common.start(b, e, "recover", recover)
