extends "res://scripts/nana_combat.gd"
## R1 combat: the same targeting and geometry as the prototype, with bounded effects.

var link_s03_cooldown := 0.0


func reset() -> void:
	super.reset()
	link_s03_cooldown = 0.0


func _transfer_prey(run, from: Vector2, excluded: int) -> void:
	var best: Dictionary = {}
	var distance := INF
	for enemy: Dictionary in run.enemies:
		if int(enemy.id) == excluded or float(enemy.hp) <= 0.0: continue
		var d := from.distance_to(Vector2(enemy.pos))
		if d <= 220.0 and (d < distance or (is_equal_approx(d, distance) and (best.is_empty() or int(enemy.id) < int(best.id)))):
			best = enemy
			distance = d
	prey_id = int(best.id) if not best.is_empty() else -1
	prey_remaining = -1.0 if prey_id >= 0 else 0.0


func advance(run, delta: float) -> void:
	var growth = run.growth
	link_s03_cooldown = maxf(0.0, link_s03_cooldown - delta)
	if follow_remaining > 0.0:
		follow_remaining = maxf(0.0, follow_remaining - delta)
		if follow_remaining == 0.0: follow_target_id = -1
	var tolerance := 1.8 if "M01" in growth.mods else 1.2
	if (shadow_count > 0 or shadow_power > 0) and run.elapsed - shadow_last_hit > tolerance:
		shadow_count = 0
		shadow_power = 0
	for i in range(pending_shadows.size() - 1, -1, -1):
		var shadow: Dictionary = pending_shadows[i]
		shadow.remaining = float(shadow.remaining) - delta
		if float(shadow.remaining) > 0.0: continue
		var hits := 0
		var original := not bool(shadow.get("echo", false))
		for enemy: Dictionary in run.enemies:
			if float(enemy.hp) <= 0.0 or not CombatGeometry.rectangle_circle(shadow.pos, shadow.dir, enemy.pos, float(enemy.radius), float(shadow.length), float(shadow.width)): continue
			var was_prey: bool = int(enemy.id) == prey_id and has_prey()
			if original and was_prey and "S03" in growth.links and link_s03_cooldown <= 0.0:
				bite_charge = mini(3, bite_charge + 1)
				link_s03_cooldown = 2.0
			run.damage_enemy(enemy, float(shadow.damage), "shadow" if original else "shadow_echo")
			if original and was_prey and float(enemy.hp) <= 0.0 and "M09" in growth.mods:
				_transfer_prey(run, enemy.pos, int(enemy.id))
			hits += 1
		run.events.append({"kind": "nana_shadow", "pos": shadow.pos, "dir": shadow.dir, "reach": shadow.length, "width": shadow.width})
		run.experiment.counts.shadow_hits += hits
		pending_shadows.remove_at(i)
	cooldown = maxf(0.0, cooldown - delta)
	ultimate_remaining = maxf(0.0, ultimate_remaining - delta)
	if pending_bite.is_empty(): return
	pending_bite.remaining = float(pending_bite.remaining) - delta
	if float(pending_bite.remaining) > 0.0: return
	var locked_id := int(pending_bite.target_id)
	for enemy: Dictionary in run.enemies:
		if int(enemy.id) != locked_id or float(enemy.hp) <= 0.0: continue
		if not _in_cone(run.player, pending_bite.direction, enemy, float(pending_bite.reach), BITE_HALF_ANGLE): break
		var was_prey: bool = "c" in run.experiment.abilities and int(enemy.id) == prey_id and has_prey()
		var bite_base := 36.0 if was_prey else (20.0 if "M10" in growth.mods else 14.0)
		var multiplier := 1.5 if bool(pending_bite.empowered) else 1.0
		run.damage_enemy(enemy, bite_base * multiplier, "bite")
		if float(enemy.hp) > 0.0: run.apply_heavy_hit(enemy)
		if "c" in run.experiment.abilities:
			prey_id = -1
			prey_remaining = 0.0
			if was_prey:
				run.experiment.counts.cash += 1
				if growth.formed("c") and growth.c_branch == "hold" and float(enemy.hp) > 0.0:
					prey_id = int(enemy.id)
					prey_remaining = -1.0
				elif growth.formed("c") and growth.c_branch == "jump" and float(enemy.hp) <= 0.0:
					_transfer_prey(run, enemy.pos, int(enemy.id))
				if int(growth.levels.get("c", 0)) >= 2:
					for other: Dictionary in run.enemies:
						if int(other.id) != int(enemy.id) and float(other.hp) > 0.0 and Vector2(other.pos).distance_to(Vector2(enemy.pos)) <= 110.0 + float(other.radius):
							run.damage_enemy(other, 8.0 * multiplier, "cash_wave")
					run.events.append({"kind": "nana_cash_wave", "pos": enemy.pos, "radius": 110.0})
				run.events.append({"kind": "nana_cash", "pos": enemy.pos})
			elif float(enemy.hp) > 0.0:
				prey_id = int(enemy.id)
				prey_remaining = -1.0
				run.experiment.counts.mark += 1
		break
	run.events.append({"kind": "nana_bite", "pos": run.player, "dir": pending_bite.direction,
		"reach": pending_bite.reach, "half_angle": BITE_HALF_ANGLE})
	pending_bite.clear()


func attack(run) -> float:
	var growth = run.growth
	var empowered := ultimate_remaining > 0.0
	var multiplier := 1.5 if empowered else 1.0
	var reach_multiplier: float = (1.4 if empowered else 1.0) * (1.0 + 0.1 * int(growth.common.reach))
	var charged: bool = "b" in run.experiment.abilities and movement_charge >= growth.charge_cost()
	var reach: float = (175.0 if charged else CLAW_REACH) * reach_multiplier
	var half_angle: float = PI * 0.5 if charged else CLAW_HALF_ANGLE
	var previous_follow := follow_target_id
	follow_target_id = -1
	follow_remaining = 0.0
	var marked_before := prey_id
	var hit_prey := false
	var targets: Array[Dictionary] = []
	var follow_candidates: Array[Dictionary] = []
	for enemy: Dictionary in run.enemies:
		if float(enemy.hp) > 0.0 and _in_cone(run.player, run.aim, enemy, reach, half_angle): targets.append(enemy)
	for enemy: Dictionary in targets:
		var was_prey: bool = int(enemy.id) == marked_before and marked_before >= 0
		if was_prey: hit_prey = true
		var extra := (8.0 if "M05" in growth.mods else 12.0) if charged else 0.0
		run.damage_enemy(enemy, (10.0 + extra) * multiplier, "claw")
		if was_prey and float(enemy.hp) <= 0.0 and "M09" in growth.mods:
			_transfer_prey(run, enemy.pos, int(enemy.id))
		if int(enemy.id) == previous_follow and float(enemy.hp) > 0.0:
			run.damage_enemy(enemy, 10.0 * multiplier, "follow_bite")
			run.events.append({"kind": "nana_cash", "pos": enemy.pos})
		if float(enemy.hp) <= 0.0: continue
		if charged and "M07" in growth.mods:
			enemy["slow_remaining"] = 1.5
			enemy["slow_factor"] = 0.15 if enemy.get("variant", "") == "boss" else 0.30
		var away: Vector2 = (Vector2(enemy.pos) - run.player).normalized()
		if away.length_squared() < 0.01: away = run.aim
		if enemy.kind in ["chaser", "pursuer"]:
			enemy.pos = (Vector2(enemy.pos) + away * 12.0).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
		if charged and int(growth.levels.get("b", 0)) >= 2 and not was_prey:
			var before: Vector2 = enemy.pos
			var factor := 0.2 if enemy.get("variant", "") == "boss" else (0.5 if enemy.kind == "elite" else 1.0)
			enemy.pos = (before + away * 65.0 * factor).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
			if before.distance_to(Vector2(enemy.pos)) > 0.01:
				run.events.append({"kind": "nana_push", "pos": enemy.pos})
				if growth.formed("b") and growth.b_branch == "follow": follow_candidates.append(enemy)
	if not follow_candidates.is_empty():
		var best_score := -INF
		var best_distance := INF
		for enemy: Dictionary in follow_candidates:
			var offset: Vector2 = Vector2(enemy.pos) - run.player
			var distance := offset.length()
			var score: float = run.aim.dot(offset.normalized()) if distance > 0.001 else 1.0
			if score > best_score + 0.00001 or (is_equal_approx(score, best_score) and distance < best_distance):
				follow_target_id = int(enemy.id)
				best_score = score
				best_distance = distance
		follow_remaining = 2.0
	var hit_any := not targets.is_empty()
	if charged and hit_any:
		movement_charge = maxf(0.0, movement_charge - growth.charge_cost())
		run.experiment.counts.charged += 1
		run.experiment.counts.charged_hits += targets.size()
		run.events.append({"kind": "nana_charged", "pos": run.player})
	if hit_any and "a" in run.experiment.abilities:
		var tolerance := 1.8 if "M01" in growth.mods else 1.2
		if run.elapsed - shadow_last_hit > tolerance:
			shadow_count = 0
			shadow_power = 0
		shadow_last_hit = run.elapsed
		shadow_count += 2 if charged and "S01" in growth.links else 1
		if shadow_count >= 3:
			shadow_count -= 3
			shadow_power = mini(3, shadow_power + 1) if int(growth.levels.get("a", 0)) >= 2 else 1
			var damage := (8.0 + 4.0 * float(shadow_power - 1)) * multiplier * (1.35 if "M02" in growth.mods else 1.0)
			var wide: bool = growth.formed("a") and growth.a_branch == "wide" and shadow_power == 3
			var shadow := {"remaining": 0.25 if "M02" in growth.mods else 0.12, "pos": run.player, "dir": run.aim,
				"damage": damage, "width": 180.0 if wide else SHADOW_WIDTH,
				"length": SHADOW_LENGTH * (1.0 + 0.1 * int(growth.common.reach)), "echo": false}
			pending_shadows.append(shadow)
			if growth.formed("a") and growth.a_branch == "echo" and shadow_power == 3:
				var echo := shadow.duplicate(true)
				echo.remaining = float(shadow.remaining) + 0.25
				echo.damage = damage * 0.4
				echo.echo = true
				pending_shadows.append(echo)
			run.experiment.counts.shadow += 1
	last_attack_was_bite = false
	if bite_charge == 3 and pending_bite.is_empty():
		update_bite_target(run, BITE_REACH * reach_multiplier, BITE_HALF_ANGLE)
		var target := bite_target(run, BITE_REACH * reach_multiplier, BITE_HALF_ANGLE)
		if not target.is_empty():
			bite_charge = 0
			last_attack_was_bite = true
			pending_bite = {"remaining": BITE_WINDUP, "target_id": int(target.id), "direction": run.aim,
				"reach": BITE_REACH * reach_multiplier, "empowered": empowered}
			run.events.append({"kind": "nana_bite_windup", "pos": run.player, "dir": run.aim,
				"reach": BITE_REACH * reach_multiplier, "half_angle": BITE_HALF_ANGLE})
	if hit_any and not last_attack_was_bite:
		var extra := 1 if "c" in run.experiment.abilities and hit_prey else 0
		bite_charge = 3 if charged and hit_prey and "S05" in growth.links else mini(3, bite_charge + 1 + extra)
	run.events.append({"kind": "swipe", "style": "nana", "pos": run.player, "dir": run.aim, "reach": reach, "half_angle": half_angle})
	return 0.42 / (1.0 + 0.08 * int(growth.common.haste))


func activate_ultimate(run) -> bool:
	if run.state != "playing" or run.hp <= 0.0 or cooldown > 0.0 or ultimate_remaining > 0.0: return false
	cooldown = 40.0 - 4.0 * int(run.growth.common.cooldown)
	ultimate_remaining = 6.0
	run.invulnerability = maxf(run.invulnerability, 0.6)
	for enemy: Dictionary in run.enemies:
		if float(enemy.hp) <= 0.0: continue
		var offset: Vector2 = Vector2(enemy.pos) - run.player
		if offset.length() > ULTIMATE_RADIUS + float(enemy.radius): continue
		run.damage_enemy(enemy, 15.0, "ultimate")
		if float(enemy.hp) > 0.0 and enemy.kind in ["chaser", "pursuer"]:
			enemy.pos = (Vector2(enemy.pos) + (offset.normalized() if offset.length_squared() > 0.01 else run.aim) * 80.0).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
	run.events.append({"kind": "nana_ultimate", "pos": run.player, "radius": ULTIMATE_RADIUS})
	return true
