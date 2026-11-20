extends RefCounted
## The limited action library that card, habit and item triggers can call.
## Every action produces attacks one depth level deeper so chains stay bounded.

const Data := preload("res://scripts/x1/core/data.gd")


static func _p(params: Dictionary, key: String, level: int, fallback = 0.0):
	return Data.lv(params.get(key, fallback), level)


static func _target(ctx: Dictionary):
	var target = ctx.get("target", null)
	return target if target is Dictionary and not target.is_empty() else null


static func _origin(b, params: Dictionary, ctx: Dictionary) -> Vector2:
	match str(params.get("at", params.get("origin", "player"))):
		"target":
			var target = _target(ctx)
			return target.pos if target != null else Vector2(ctx.get("pos", b.player.pos))
		"ctx":
			return Vector2(ctx.get("pos", b.player.pos))
		_:
			return b.player.pos


static func run(b, action: String, params: Dictionary, level: int, ctx: Dictionary, key: String) -> void:
	var depth: int = int(ctx.get("depth", 0)) + 1
	match action:
		"bounce_ball":
			var target = _target(ctx)
			var from: Vector2 = target.pos if target != null else Vector2(ctx.get("pos", b.player.pos))
			b.spawn_ball(from, float(_p(params, "damage", level, 8)), int(_p(params, "bounces", level, 2)),
				float(_p(params, "speed", level, 520)), float(_p(params, "range", level, 260)), depth,
				int(target.id) if target != null else -1, params)
		"shadow_line":
			var origin := _origin(b, params, ctx)
			var dir := Vector2.ZERO
			match str(params.get("dir", "facing")):
				"pounce": dir = Vector2(ctx.get("dir", b.player.facing))
				"back": dir = -b.player.move_dir
				"nearest":
					var nearest: Dictionary = b.nearest_enemy(origin, float(_p(params, "length", level, 300)) + 40.0, [])
					if nearest.is_empty(): return
					dir = (nearest.pos - origin).normalized()
				_: dir = b.player.facing
			if dir.length_squared() < 0.01: dir = Vector2.RIGHT
			var length_value = params.get("length", 300)
			var length: float = float(ctx.get("length", 230.0)) if str(length_value) == "pounce" else float(Data.lv(length_value, level))
			b.add_line(origin, dir.normalized(), length, float(_p(params, "width", level, 60)), float(_p(params, "damage", level, 8)),
				float(_p(params, "delay", level, 0.1)), str(params.get("source", "shadow")), depth)
		"shockwave":
			var kills: int = b.shockwave(_origin(b, params, ctx), float(_p(params, "radius", level, 100)), float(_p(params, "damage", level, 10)),
				float(_p(params, "knockback", level, 0)), "wave", depth)
			if kills > 0 and int(params.get("refund_on_kill", 0)) > 0:
				b.refund_pounce(int(params.refund_on_kill))
		"claw_burst":
			b.claw_burst(float(_p(params, "radius", level, 110)), float(_p(params, "damage_pct", level, 100)), depth)
		"extra_claw":
			b.extra_claw(str(params.get("dir", "next")), float(_p(params, "damage_pct", level, 100)), depth)
		"heal":
			b.heal(float(_p(params, "amount", level, 1)))
		"refund_pounce":
			b.refund_pounce(int(_p(params, "amount", level, 1)))
		"meter":
			b.add_meter(float(_p(params, "amount", level, 5)))
		"bleed":
			var target = _target(ctx)
			if target != null: b.apply_bleed(target, float(_p(params, "dps", level, 5)), float(_p(params, "duration", level, 3)))
		"slow":
			var radius: float = float(_p(params, "radius", level, 0))
			var pct: float = float(_p(params, "pct", level, 30))
			var duration: float = float(_p(params, "duration", level, 1.5))
			if radius <= 0.0:
				var target = _target(ctx)
				if target != null: b.apply_slow(target, pct, duration)
			else:
				b.slow_area(_origin(b, params, ctx), radius, pct, duration)
		"buff":
			b.stats.add_buff(str(params.stat), float(_p(params, "amount", level, 0)), float(_p(params, "duration", level, 2)), key)
		"mark":
			var target = _target(ctx)
			if target != null: b.mark_or_cash(target, depth)
		"execute":
			var target = _target(ctx)
			if target != null: b.execute(target, float(_p(params, "threshold_pct", level, 15)), float(_p(params, "boss_mult", level, 1.5)), depth)
