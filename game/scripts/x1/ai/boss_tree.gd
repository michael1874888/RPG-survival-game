extends RefCounted
## B01 老樹守門者: alternates a double sweep and a long root line. Calls chasers as it weakens.

const Common := preload("res://scripts/x1/ai/common.gd")


static func init(_b, e: Dictionary) -> void:
	e.timer = 1.2
	e.next_attack = "sweep"
	e.approach_time = 0.0
	e.phase_level = 0
	e.support_timer = 0.0


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	Common.boss_support(b, e, dt)
	match str(e.phase):
		"chase":
			Common.approach(b, e, 120.0, dt)
			if not Common.tick(e, dt): return
			e.timer = 0.0
			var distance: float = b.dist_to_player(e)
			if e.next_attack == "sweep":
				if distance <= float(s.sweep_reach) * 0.95 and b.can_attack(e, 2):
					e.dir = b.dir_to_player(e)
					b.begin_attack(e)
					Common.start(b, e, "sweep1", float(s.sweep_windup1), {"shape": "sector", "reach": float(s.sweep_reach), "angle": float(s.sweep_angle1)})
				else:
					e.approach_time = float(e.approach_time) + dt
					if float(e.approach_time) > 2.5:
						e.next_attack = "root"
						e.approach_time = 0.0
			elif distance <= float(s.root_length) and b.can_attack(e, 2):
				e.dir = b.dir_to_player(e)
				b.begin_attack(e)
				Common.start(b, e, "root", float(s.root_windup), {"shape": "line", "length": float(s.root_length), "width": float(s.root_width)})
		"sweep1":
			if Common.tick(e, dt):
				b.sector_attack(e.pos, e.dir, float(s.sweep_reach), float(s.sweep_angle1), float(s.sweep_damage), str(e.kind))
				Common.start(b, e, "sweep_gap", float(s.sweep_gap), {"shape": "sector", "reach": float(s.sweep_reach), "angle": float(s.sweep_angle2), "dim": true})
		"sweep_gap":
			if Common.tick(e, dt):
				e.dir = b.dir_to_player(e)
				Common.start(b, e, "sweep2", float(s.sweep_windup2), {"shape": "sector", "reach": float(s.sweep_reach), "angle": float(s.sweep_angle2)})
		"sweep2":
			if Common.tick(e, dt):
				b.sector_attack(e.pos, e.dir, float(s.sweep_reach), float(s.sweep_angle2), float(s.sweep_damage), str(e.kind))
				_finish(b, e, s, float(s.sweep_recover), "root")
		"root":
			if Common.tick(e, dt):
				b.line_attack(e.pos, e.dir, float(s.root_length), float(s.root_width), float(s.root_damage), str(e.kind))
				_finish(b, e, s, float(s.root_recover), "sweep")
		"recover":
			if Common.tick(e, dt):
				e.phase = "chase"
				e.timer = float(s.rest)


static func _finish(b, e: Dictionary, s: Dictionary, recover: float, next: String) -> void:
	b.end_attack(e)
	e.next_attack = next
	e.approach_time = 0.0
	e.cycle = int(e.cycle) + 1
	if int(e.get("phase_level", 0)) == 1 and int(e.cycle) % 2 == 0:
		Common.call_support(b, e, s.get("support1", []))
	Common.start(b, e, "recover", recover)
