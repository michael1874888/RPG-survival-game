extends RefCounted
## E05: slow and sturdy; a wide warned swing, then a long opening.

const Common := preload("res://scripts/x1/ai/common.gd")


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	match str(e.phase):
		"chase":
			Common.approach(b, e, float(s.reach) * 0.6, dt)
			if b.dist_to_player(e) <= float(s.trigger) and b.can_attack(e, 1):
				e.dir = b.dir_to_player(e)
				b.begin_attack(e)
				Common.start(b, e, "windup", float(s.windup), {"shape": "sector", "reach": float(s.reach), "angle": float(s.angle)})
		"windup":
			if Common.tick(e, dt):
				b.sector_attack(e.pos, e.dir, float(s.reach), float(s.angle), float(e.damage), str(e.kind))
				b.end_attack(e)
				Common.start(b, e, "recover", float(s.recover))
		"recover":
			if Common.tick(e, dt): Common.start(b, e, "rest", float(s.rest))
		"rest":
			Common.approach(b, e, float(s.reach) * 0.6, dt, 0.5)
			if Common.tick(e, dt): e.phase = "chase"
