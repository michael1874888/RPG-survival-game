extends RefCounted
## EL01: two warned sweeps; the second is wider. A long opening follows.

const Common := preload("res://scripts/x1/ai/common.gd")


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	match str(e.phase):
		"chase":
			Common.approach(b, e, float(s.reach) * 0.55, dt)
			if b.dist_to_player(e) <= float(s.trigger) and b.can_attack(e, 1):
				e.dir = b.dir_to_player(e)
				b.begin_attack(e)
				Common.start(b, e, "windup1", float(s.windup1), {"shape": "sector", "reach": float(s.reach), "angle": float(s.angle1)})
		"windup1":
			if Common.tick(e, dt):
				b.sector_attack(e.pos, e.dir, float(s.reach), float(s.angle1), float(e.damage), str(e.kind))
				Common.start(b, e, "gap", float(s.gap), {"shape": "sector", "reach": float(s.reach), "angle": float(s.angle2), "dim": true})
		"gap":
			if Common.tick(e, dt):
				e.dir = b.dir_to_player(e)
				Common.start(b, e, "windup2", float(s.windup2), {"shape": "sector", "reach": float(s.reach), "angle": float(s.angle2)})
		"windup2":
			if Common.tick(e, dt):
				b.sector_attack(e.pos, e.dir, float(s.reach), float(s.angle2), float(e.damage), str(e.kind))
				b.end_attack(e)
				Common.start(b, e, "recover", float(s.recover))
		"recover":
			if Common.tick(e, dt): Common.start(b, e, "rest", float(s.rest))
		"rest":
			Common.approach(b, e, float(s.reach) * 0.55, dt, 0.5)
			if Common.tick(e, dt): e.phase = "chase"
