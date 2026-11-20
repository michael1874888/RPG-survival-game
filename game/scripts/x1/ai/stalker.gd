extends RefCounted
## EL02: fast hunter; two warned straight lunges, each aimed afresh, then a long rest.

const Common := preload("res://scripts/x1/ai/common.gd")


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	match str(e.phase):
		"chase":
			Common.approach(b, e, float(s.trigger) * 0.8, dt)
			if b.dist_to_player(e) <= float(s.trigger) and b.can_attack(e, 1):
				e.count = 0
				b.begin_attack(e)
				_aim(b, e, s)
		"windup":
			if Common.tick(e, dt):
				e.phase = "lunge"
				e.travel = 0.0
				e.hit_done = false
				e.tele = {}
		"lunge":
			if Common.dash(b, e, float(s.lunge_speed), dt, float(s.lunge_max)):
				e.count = int(e.count) + 1
				if int(e.count) < int(s.lunges):
					_aim(b, e, s)
				else:
					b.end_attack(e)
					Common.start(b, e, "recover", float(s.recover))
		"recover":
			if Common.tick(e, dt): Common.start(b, e, "rest", float(s.rest))
		"rest":
			Common.approach(b, e, float(s.trigger), dt, 0.4)
			if Common.tick(e, dt): e.phase = "chase"


static func _aim(b, e: Dictionary, s: Dictionary) -> void:
	e.dir = b.dir_to_player(e)
	Common.start(b, e, "windup", float(s.windup), {"shape": "line", "length": float(s.lunge_max), "width": float(e.radius) * 2.0})
