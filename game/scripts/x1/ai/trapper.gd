extends RefCounted
## E06: marks where the player stands; a vine ring appears there after a warning.

const Common := preload("res://scripts/x1/ai/common.gd")


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	match str(e.phase):
		"chase":
			Common.keep_distance(b, e, float(s.keep), dt)
			if b.dist_to_player(e) <= float(s.trigger) and b.can_attack(e, 1):
				e.dir = b.dir_to_player(e)
				e.aim = b.player.pos
				b.begin_attack(e)
				Common.start(b, e, "windup", float(s.windup), {"shape": "circle", "pos": b.player.pos, "radius": float(s.trap_radius)})
		"windup":
			if Common.tick(e, dt):
				b.add_hazard(Vector2(e.aim), float(s.trap_radius), float(e.damage), float(s.linger), float(s.slow), str(e.kind))
				b.end_attack(e)
				Common.start(b, e, "recover", float(s.recover))
		"recover":
			if Common.tick(e, dt): Common.start(b, e, "rest", float(s.rest))
		"rest":
			Common.keep_distance(b, e, float(s.keep), dt)
			if Common.tick(e, dt): e.phase = "chase"
