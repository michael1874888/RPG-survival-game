extends "res://scripts/nana_encounters.gd"
## First-chapter enemies, including the two elites and the guardian.


func _sector_hit(run, enemy: Dictionary, distance: float, half_angle: float) -> void:
	if CombatGeometry.sector_circle(enemy.pos, enemy.dir, run.player, run.PLAYER_RADIUS, distance, half_angle):
		run.take_damage(float(enemy.damage), str(enemy.get("variant", enemy.kind)))


func _line_hit(run, enemy: Dictionary, distance: float, half_width: float, damage: float = -1.0) -> void:
	var start: Vector2 = enemy.pos
	var end: Vector2 = start + Vector2(enemy.dir) * distance
	var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(run.player, start, end)
	if nearest.distance_to(run.player) <= half_width + run.PLAYER_RADIUS:
		run.take_damage(damage if damage >= 0.0 else float(enemy.damage), str(enemy.get("variant", enemy.kind)))


func _elite_update(run, e: Dictionary, delta: float, visible: bool) -> void:
	var pos: Vector2 = e.pos
	var offset: Vector2 = run.player - pos
	var distance := offset.length()
	var variant: String = e.get("variant", "")
	var stalker := variant in ["stalker", "event_stalker"]
	var boss := variant == "boss"
	e.timer = maxf(0.0, float(e.timer) - delta)
	if e.phase == "chase":
		var threshold := 250.0 if stalker else (190.0 if boss else 175.0)
		if distance <= threshold and visible and float(e.visible_time) >= 0.4 and can_start(run, 0.9):
			e.phase = "windup"
			e.dir = offset.normalized() if distance > 0.001 else Vector2.RIGHT
			e["attack_kind"] = "dash" if stalker else ("root" if boss and int(e.get("attack_cycle", 0)) % 2 == 1 else "sweep")
			e.timer = 0.8 if stalker else (1.0 if e.attack_kind == "root" else 0.9)
			e["second_strike"] = false
			e.extended = false
			next_start = run.elapsed + float(e.timer) + 0.4
		else:
			var slow := 1.0 - float(e.get("slow_factor", 0.0)) if float(e.get("slow_remaining", 0.0)) > 0.0 else 1.0
			e.pos = (pos + offset.normalized() * float(e.speed) * slow * delta).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
	elif e.phase == "windup" and float(e.timer) <= 0.0:
		if stalker:
			e.phase = "dash"
			e.timer = 0.44
		elif e.get("attack_kind", "") == "root":
			_line_hit(run, e, 400.0, 40.0, 18.0)
			e.phase = "recover"
			e.timer = 1.3
			e.attack_cycle = int(e.get("attack_cycle", 0)) + 1
		else:
			var half := deg_to_rad(80.0 if bool(e.get("second_strike", false)) else 55.0)
			_sector_hit(run, e, 190.0 if boss else 175.0, half)
			if not bool(e.get("second_strike", false)):
				e.phase = "second_wait"
				e.timer = 0.45
			else:
				e.phase = "recover"
				e.timer = 1.5 if boss else 1.4
				e.attack_cycle = int(e.get("attack_cycle", 0)) + 1
	elif e.phase == "second_wait" and float(e.timer) <= 0.0:
		e.phase = "windup"
		e.timer = 0.8 if stalker else 0.65
		e.dir = offset.normalized() if distance > 0.001 else Vector2.RIGHT
		e.second_strike = true
	elif e.phase == "dash":
		var next: Vector2 = (pos + Vector2(e.dir) * 500.0 * delta).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
		var closest := Geometry2D.get_closest_point_to_segment(run.player, pos, next)
		if closest.distance_to(run.player) <= float(e.radius) + run.PLAYER_RADIUS:
			run.take_damage(float(e.damage), variant)
		e.pos = next
		if float(e.timer) <= 0.0:
			if not bool(e.get("second_strike", false)):
				e.phase = "second_wait"
				e.timer = 0.45
			else:
				e.phase = "recover"
				e.timer = 1.5
	elif e.phase == "recover" and float(e.timer) <= 0.0:
		e.phase = "wait"
		e.timer = 0.8 if boss else 1.0
	elif e.phase == "wait" and float(e.timer) <= 0.0:
		e.phase = "chase"


func update(run, delta: float) -> void:
	for e: Dictionary in run.enemies:
		if float(e.hp) <= 0.0: continue
		e.flash = maxf(0.0, float(e.flash) - delta)
		e.heavy_resist = maxf(0.0, float(e.get("heavy_resist", 0.0)) - delta)
		e["slow_remaining"] = maxf(0.0, float(e.get("slow_remaining", 0.0)) - delta)
		var pos: Vector2 = e.pos
		var offset: Vector2 = run.player - pos
		var distance := offset.length()
		var kind: String = e.kind
		var visible := Rect2(run.camera_origin(), run.view_size).has_point(pos)
		e.visible_time = float(e.get("visible_time", 0.0)) + delta if visible else 0.0
		if kind == "elite":
			_elite_update(run, e, delta, visible)
			continue
		var slow := 1.0 - float(e.get("slow_factor", 0.0)) if float(e.slow_remaining) > 0.0 else 1.0
		if kind in ["chaser", "pursuer"]:
			var separation := Vector2.ZERO
			for other: Dictionary in run.enemies:
				if other == e or float(other.hp) <= 0.0: continue
				var away: Vector2 = pos - Vector2(other.pos)
				if away.length_squared() > 0.01 and away.length() < float(e.radius) + float(other.radius): separation += away.normalized()
			var velocity: Vector2 = (offset.normalized() + separation.limit_length() * 0.6).limit_length() * float(e.speed) * slow
			e.pos = (pos + velocity * delta).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
			if Vector2(e.pos).distance_to(run.player) <= float(e.radius) + run.PLAYER_RADIUS: run.take_damage(float(e.damage), kind)
			continue
		e.timer = maxf(0.0, float(e.timer) - delta)
		if e.phase == "chase":
			var threshold := 220.0 if kind == "charger" else (380.0 if kind == "thrower" else 170.0)
			var windup := 0.85 if kind == "charger" else 0.9
			if distance <= threshold and visible and float(e.visible_time) >= 0.4 and can_start(run, windup):
				e.phase = "windup"
				e.timer = windup
				e.dir = offset.normalized() if distance > 0.001 else Vector2.RIGHT
				e.extended = false
				next_start = run.elapsed + windup + 0.4
			else:
				var move: Vector2 = offset.normalized() * float(e.speed) * slow * delta
				if kind == "thrower" and distance < 260.0: move = -move
				e.pos = (pos + move).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
		elif e.phase == "windup" and float(e.timer) <= 0.0:
			if kind == "charger":
				e.phase = "dash"
				e.timer = 0.4
			elif kind == "thrower":
				enemy_projectiles.append({"pos": pos, "dir": e.dir, "life": 2.0, "damage": e.damage, "speed": 240.0})
				e.phase = "recover"
				e.timer = 1.0
			else:
				_sector_hit(run, e, 150.0, deg_to_rad(50.0))
				e.phase = "recover"
				e.timer = 1.2
		elif e.phase == "dash":
			var next: Vector2 = (pos + Vector2(e.dir) * 520.0 * delta).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
			var closest := Geometry2D.get_closest_point_to_segment(run.player, pos, next)
			if closest.distance_to(run.player) <= float(e.radius) + run.PLAYER_RADIUS: run.take_damage(float(e.damage), kind)
			e.pos = next
			if float(e.timer) <= 0.0:
				e.phase = "recover"
				e.timer = 1.1
		elif e.phase == "recover" and float(e.timer) <= 0.0:
			e.phase = "wait"
			e.timer = 1.0
		elif e.phase == "wait" and float(e.timer) <= 0.0:
			e.phase = "chase"
	for i in range(enemy_projectiles.size() - 1, -1, -1):
		var p: Dictionary = enemy_projectiles[i]
		var from: Vector2 = p.pos
		var to: Vector2 = from + Vector2(p.dir) * float(p.get("speed", 240.0)) * delta
		p.pos = to
		p.life = float(p.life) - delta
		var closest := Geometry2D.get_closest_point_to_segment(run.player, from, to)
		if closest.distance_to(run.player) <= run.PLAYER_RADIUS + 8.0:
			run.take_damage(float(p.damage), "thrower_projectile")
			enemy_projectiles.remove_at(i)
		elif float(p.life) <= 0.0 or not Rect2(Vector2.ZERO, run.WORLD).has_point(to):
			enemy_projectiles.remove_at(i)
