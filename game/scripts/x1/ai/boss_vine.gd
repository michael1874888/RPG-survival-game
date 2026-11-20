extends RefCounted
## B02 藤棚織者: seed fans with a centre gap later on, and vine rings either side of the player.

const Common := preload("res://scripts/x1/ai/common.gd")


static func init(_b, e: Dictionary) -> void:
	e.timer = 1.2
	e.next_attack = "seed"
	e.phase_level = 0
	e.support_timer = 0.0


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	Common.boss_support(b, e, dt)
	match str(e.phase):
		"chase":
			Common.keep_distance(b, e, 300.0, dt)
			if not Common.tick(e, dt): return
			e.timer = 0.0
			if not b.can_attack(e, 2): return
			e.dir = b.dir_to_player(e)
			b.begin_attack(e)
			if e.next_attack == "seed":
				Common.start(b, e, "seed", float(s.seed_windup), {"shape": "fan", "length": float(s.seed_speed) * float(s.seed_life),
					"angle": float(s.seed_spread), "count": _seed_angles(e, s).size()})
			else:
				var perp: Vector2 = b.dir_to_player(e).orthogonal() * (float(s.vine_radius) + float(s.vine_gap) * 0.5)
				e.points = [b.player.pos + perp, b.player.pos - perp]
				Common.start(b, e, "vine", float(s.vine_windup), {"shape": "circles", "points": e.points, "radius": float(s.vine_radius)})
		"seed":
			if Common.tick(e, dt):
				for angle: float in _seed_angles(e, s):
					b.fire_shot(e.pos, Vector2(e.dir).rotated(deg_to_rad(angle)), float(s.seed_speed), float(s.seed_life), float(s.seed_damage), str(e.kind))
				_finish(b, e, float(s.seed_recover), "vine")
		"vine":
			if Common.tick(e, dt):
				for point: Vector2 in e.points:
					b.add_hazard(point, float(s.vine_radius), float(s.vine_damage), float(s.vine_linger), float(s.vine_slow), str(e.kind))
				_finish(b, e, float(s.vine_recover), "seed")
		"recover":
			if Common.tick(e, dt):
				e.phase = "chase"
				e.timer = float(s.rest)


## Later fans add shots but always leave the centre lane open.
static func _seed_angles(e: Dictionary, s: Dictionary) -> Array:
	var later: bool = int(e.get("phase_level", 0)) >= 1
	var count: int = int(s.seed_count2) if later else int(s.seed_count)
	var spread: float = float(s.seed_spread)
	var angles: Array = []
	for i in count:
		var angle: float = -spread * 0.5 + spread * i / maxf(1.0, count - 1.0)
		if later and absf(angle) < 1.0: continue
		angles.append(angle)
	return angles


static func _finish(b, e: Dictionary, recover: float, next: String) -> void:
	b.end_attack(e)
	e.next_attack = next
	e.cycle = int(e.cycle) + 1
	Common.start(b, e, "recover", recover)
