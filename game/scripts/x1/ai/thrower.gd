extends RefCounted
## E04: keeps its distance and throws a slow, non-homing shot along a locked line.

const Common := preload("res://scripts/x1/ai/common.gd")


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	match str(e.phase):
		"chase":
			Common.keep_distance(b, e, float(s.keep), dt)
			if b.dist_to_player(e) <= float(s.trigger) and b.can_attack(e, 1):
				e.dir = b.dir_to_player(e)
				b.begin_attack(e)
				Common.start(b, e, "windup", float(s.windup), {"shape": "line", "length": float(s.shot_speed) * float(s.shot_life), "width": 16.0})
		"windup":
			if Common.tick(e, dt):
				b.fire_shot(e.pos + Vector2(e.dir) * (float(e.radius) + 6.0), e.dir, float(s.shot_speed), float(s.shot_life), float(e.damage), "thrower")
				b.end_attack(e)
				Common.start(b, e, "recover", float(s.recover))
		"recover":
			if Common.tick(e, dt): Common.start(b, e, "rest", float(s.rest))
		"rest":
			Common.keep_distance(b, e, float(s.keep), dt)
			if Common.tick(e, dt): e.phase = "chase"
