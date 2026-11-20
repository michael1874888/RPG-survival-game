extends RefCounted
## E07: stops to call two chasers; limited calls and summons, worth stopping early.

const Common := preload("res://scripts/x1/ai/common.gd")


static func init(_b, e: Dictionary) -> void:
	e.cool = 2.0
	e.used = 0


static func update(b, e: Dictionary, dt: float) -> void:
	var s: Dictionary = b.spec(e)
	e.cool = float(e.cool) - dt
	match str(e.phase):
		"chase":
			Common.keep_distance(b, e, float(s.keep), dt)
			if float(e.cool) <= 0.0 and int(e.used) < int(s.max_summons) and b.dist_to_player(e) <= float(s.trigger) \
					and b.support_count(int(e.id)) < int(s.max_alive) and b.can_attack(e, 1):
				b.begin_attack(e)
				Common.start(b, e, "windup", float(s.windup), {"shape": "circle", "pos": e.pos, "radius": 55.0})
		"windup":
			if Common.tick(e, dt):
				for i in int(s.summon_count):
					var offset := Vector2.RIGHT.rotated(TAU * i / float(s.summon_count) + b.rng_spawn.randf()) * (float(e.radius) + 30.0)
					b.spawn_enemy(str(s.summon), e.pos + offset, {"summoned": true, "no_xp": true, "summoner": int(e.id)})
				e.used = int(e.used) + 1
				e.cool = float(s.interval)
				b.end_attack(e)
				Common.start(b, e, "recover", float(s.recover))
		"recover":
			if Common.tick(e, dt): e.phase = "chase"
