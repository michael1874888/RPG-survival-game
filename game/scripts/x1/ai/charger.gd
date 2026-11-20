extends RefCounted
## E03: locks a direction, charges in a straight line, then stands exposed.

const Common := preload("res://scripts/x1/ai/common.gd")


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	match str(e.phase):
		"chase":
			Common.approach(b, e, 0.0, dt)
			if b.dist_to_player(e) <= float(s.trigger) and b.can_attack(e, 1):
				e.dir = b.dir_to_player(e)
				b.begin_attack(e)
				Common.start(b, e, "windup", float(s.windup), {"shape": "line", "length": float(s.dash_speed) * float(s.dash_time), "width": float(e.radius) * 2.0})
		"windup":
			if Common.tick(e, dt):
				e.phase = "dash"
				e.timer = float(s.dash_time)
				e.travel = 0.0
				e.hit_done = false
				e.tele = {}
		"dash":
			if Common.dash(b, e, float(s.dash_speed), dt):
				b.end_attack(e)
				Common.start(b, e, "recover", float(s.recover))
		"recover":
			if Common.tick(e, dt): Common.start(b, e, "rest", float(s.rest))
		"rest":
			Common.approach(b, e, 0.0, dt, 0.5)
			if Common.tick(e, dt): e.phase = "chase"
