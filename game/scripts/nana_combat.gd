extends RefCounted
## Nana's attacks and ultimate; the run owns enemies, health, movement and time.

const CombatGeometry := preload("res://scripts/combat_geometry.gd")

const CLAW_REACH: float = 145.0
const CLAW_HALF_ANGLE: float = deg_to_rad(50.0)
const BITE_REACH: float = 175.0
const BITE_HALF_ANGLE: float = deg_to_rad(27.5)
const BITE_WINDUP: float = 0.1
const SHADOW_LENGTH: float = 340.0
const SHADOW_WIDTH: float = 90.0
const TARGET_SPECIAL_BONUS: float = deg_to_rad(5.0)
const TARGET_SWITCH_MARGIN: float = deg_to_rad(3.0)
const ULTIMATE_COOLDOWN: float = 40.0
const ULTIMATE_DURATION: float = 6.0
const ULTIMATE_RADIUS: float = 220.0

var bite_charge: int = 0
var cooldown: float = 0.0
var ultimate_remaining: float = 0.0
var pending_bite: Dictionary = {}
var last_attack_was_bite: bool = false
var sweep_count: int = 0
var marked_target_id: int = -1
var marker_remaining: float = 0.0
var shadow_count: int = 0
var shadow_last_hit: float = -100.0
var pending_shadows: Array[Dictionary] = []
var movement_charge: float = 0.0
var prey_id: int = -1
var prey_remaining: float = 0.0
var assisted_target_id: int = -1


func reset() -> void:
	bite_charge = 0
	cooldown = 0.0
	ultimate_remaining = 0.0
	pending_bite.clear()
	last_attack_was_bite = false
	sweep_count = 0
	marked_target_id = -1
	marker_remaining = 0.0
	shadow_count = 0
	shadow_last_hit = -100.0
	pending_shadows.clear()
	movement_charge = 0.0
	prey_id = -1
	prey_remaining = 0.0
	assisted_target_id = -1


func advance(run, delta: float) -> void:
	if run.experiment.active:
		if shadow_count > 0 and run.elapsed - shadow_last_hit > 1.2:
			shadow_count = 0
		if prey_remaining > 0.0:
			prey_remaining = maxf(0.0, prey_remaining - delta)
			if prey_remaining <= 0.0:
				run.experiment.note(run, "mark_expired", {"target": prey_id})
				prey_id = -1
		for i in range(pending_shadows.size() - 1, -1, -1):
			var shadow: Dictionary = pending_shadows[i]
			shadow.remaining = float(shadow.remaining) - delta
			if float(shadow.remaining) <= 0.0:
				var hits := 0
				var directions: Array[Vector2] = [shadow.dir]
				if int(run.experiment.levels.get("a", 1)) >= 2:
					directions.append(-Vector2(shadow.dir))
				var seen: Dictionary = {}
				for direction: Vector2 in directions:
					for enemy: Dictionary in run.enemies:
						if float(enemy.hp) > 0.0 and not seen.has(int(enemy.id)) and CombatGeometry.rectangle_circle(shadow.pos, direction, enemy.pos, float(enemy.radius), SHADOW_LENGTH, SHADOW_WIDTH):
							seen[int(enemy.id)] = true
							run.damage_enemy(enemy, 8.0, "shadow")
							hits += 1
					run.events.append({"kind": "nana_shadow", "pos": shadow.pos, "dir": direction, "reach": SHADOW_LENGTH, "width": SHADOW_WIDTH})
				run.experiment.counts.shadow_hits += hits
				run.experiment.note(run, "shadow_resolved", {"hits": hits})
				pending_shadows.remove_at(i)
	marker_remaining = maxf(0.0, marker_remaining - delta)
	if marker_remaining <= 0.0:
		marked_target_id = -1
	cooldown = maxf(0.0, cooldown - delta)
	ultimate_remaining = maxf(0.0, ultimate_remaining - delta)
	if pending_bite.is_empty():
		return
	pending_bite["remaining"] = float(pending_bite["remaining"]) - delta
	if float(pending_bite["remaining"]) > 0.0:
		return
	var locked_id: int = int(pending_bite["target_id"])
	var sweeping: bool = bool(pending_bite.get("sweeping", false))
	for enemy: Dictionary in run.enemies:
		if (not sweeping and int(enemy["id"]) != locked_id) or float(enemy["hp"]) <= 0.0:
			continue
		if _in_cone(run.player, Vector2(pending_bite["direction"]), enemy,
				float(pending_bite["reach"]), deg_to_rad(75.0) if sweeping else BITE_HALF_ANGLE):
			var is_prey: bool = run.experiment.active and "c" in run.experiment.abilities and int(enemy.id) == prey_id and has_prey()
			var bite_damage: float = float(pending_bite["damage"]) * (36.0 / 14.0 if is_prey else 1.0)
			run.damage_enemy(enemy, bite_damage, "bite")
			if float(enemy["hp"]) > 0.0:
				run.apply_heavy_hit(enemy)
				if bool(pending_bite.get("hunting", false)):
					enemy["vulnerable"] = 2.0
			if run.experiment.active and "c" in run.experiment.abilities:
				var old_prey: int = prey_id
				prey_id = -1
				prey_remaining = 0.0
				if is_prey:
					run.experiment.counts.cash += 1
					run.experiment.note(run, "mark_cash", {"target": int(enemy.id)})
					if int(run.experiment.levels.get("c", 1)) >= 2:
						var wave_hits := 0
						for other: Dictionary in run.enemies:
							if int(other.id) != int(enemy.id) and float(other.hp) > 0.0 and Vector2(other.pos).distance_to(Vector2(enemy.pos)) <= 110.0 + float(other.radius):
								run.damage_enemy(other, 8.0, "cash_wave")
								wave_hits += 1
						run.experiment.note(run, "cash_wave", {"target": int(enemy.id), "hits": wave_hits})
						run.events.append({"kind": "nana_cash_wave", "pos": enemy.pos, "radius": 110.0})
					run.experiment.request_hitstop()
					run.events.append({"kind": "nana_cash", "pos": enemy.pos})
				elif float(enemy.hp) > 0.0:
					prey_id = int(enemy.id)
					prey_remaining = 4.0 if run.experiment.timed_mark else -1.0
					run.experiment.counts.mark += 1
					run.experiment.note(run, "mark_transfer" if old_prey >= 0 else "mark", {"target": prey_id, "previous": old_prey})
		if not sweeping:
			break
	run.events.append({"kind": "nana_bite", "pos": run.player,
		"dir": pending_bite["direction"], "reach": pending_bite["reach"],
		"half_angle": deg_to_rad(75.0) if sweeping else BITE_HALF_ANGLE})
	pending_bite.clear()


func attack(run) -> float:
	var sweeping: bool = int(run.upgrades["sweep"]) > 0
	var hunting: bool = int(run.upgrades["hunt"]) > 0
	var empowered: bool = ultimate_remaining > 0.0
	var reach_multiplier: float = 1.4 if empowered else 1.0
	var damage_multiplier: float = (1.5 if empowered else 1.0) * (1.0 + 0.15 * int(run.upgrades["damage"]) + 0.03 * int(run.upgrades["micro_damage"]))
	var reach: float = (175.0 if hunting else CLAW_REACH) * reach_multiplier * (1.0 + 0.1 * int(run.upgrades["reach"]))
	var half_angle: float = (BITE_HALF_ANGLE if hunting else (deg_to_rad(70.0) if sweeping else CLAW_HALF_ANGLE)) + deg_to_rad(7.5 * int(run.upgrades["wide"]))
	var charged: bool = run.experiment.active and "b" in run.experiment.abilities and movement_charge >= 260.0
	if charged:
		reach = 175.0 * reach_multiplier
		half_angle = PI * 0.5
	var ring: bool = false
	if sweeping:
		sweep_count = (sweep_count + 1) % 3
		ring = sweep_count == 0
		if ring:
			half_angle = PI
	var hit_any: bool = false
	var claw_targets: Array[Dictionary] = []
	if hunting:
		var chosen: Dictionary = _target(run, reach, half_angle)
		if not chosen.is_empty():
			claw_targets.append(chosen)
	else:
		for enemy: Dictionary in run.enemies:
			if float(enemy["hp"]) > 0.0 and _in_cone(run.player, run.aim, enemy, reach, half_angle):
				claw_targets.append(enemy)
	var hit_prey: bool = false
	var hit_prey_id: int = prey_id
	var engaged_before: bool = run.experiment.engaged(run) if run.experiment.active else false
	if run.experiment.active:
		var target_ids: Array[int] = []
		for target: Dictionary in claw_targets:
			target_ids.append(int(target.id))
		run.experiment.note(run, "claw", {"targets": target_ids, "charged": charged, "pos": [run.player.x, run.player.y], "aim": [run.aim.x, run.aim.y]})
	for enemy: Dictionary in claw_targets:
		hit_any = true
		if int(enemy.id) == prey_id and has_prey():
			hit_prey = true
		if hunting:
			marked_target_id = int(enemy["id"])
			marker_remaining = 1.0
		var claw_damage: float = ((21.0 if run.hunt_variant == "heavy" else 14.0) if hunting else 10.0) + (12.0 if charged else 0.0)
		run.damage_enemy(enemy, claw_damage * damage_multiplier, "ring" if ring else "claw")
		if float(enemy["hp"]) > 0.0 and enemy["kind"] in ["chaser", "pursuer"]:
			var offset: Vector2 = Vector2(enemy["pos"]) - run.player
			var push: Vector2 = offset.normalized() if offset.length_squared() > 0.01 else run.aim
			enemy["pos"] = (Vector2(enemy["pos"]) + push * (24.0 if ring else 12.0)).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
		if float(enemy.hp) > 0.0 and charged and int(run.experiment.levels.get("b", 1)) >= 2 and int(enemy.id) != hit_prey_id:
			var away: Vector2 = Vector2(enemy.pos) - run.player
			enemy.pos = (Vector2(enemy.pos) + (away.normalized() if away.length_squared() > 0.01 else run.aim) * 65.0).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
			run.events.append({"kind": "nana_push", "pos": enemy.pos})
	last_attack_was_bite = false
	if run.experiment.active and charged:
		if hit_any:
			movement_charge = 0.0
			run.experiment.counts.charged += 1
			run.experiment.counts.charged_hits += claw_targets.size()
			run.experiment.note(run, "charged_hit", {"hits": claw_targets.size(), "engaged": engaged_before})
			run.experiment.request_hitstop()
			run.events.append({"kind": "nana_charged", "pos": run.player})
		else:
			run.experiment.note(run, "charged_miss")
	if run.experiment.active and "a" in run.experiment.abilities and hit_any:
		if run.elapsed - shadow_last_hit > 1.2:
			shadow_count = 0
		shadow_last_hit = run.elapsed
		shadow_count += 1
		if shadow_count == 3:
			shadow_count = 0
			pending_shadows.append({"remaining": 0.12, "pos": run.player, "dir": run.aim})
			run.experiment.counts.shadow += 1
			run.experiment.note(run, "shadow_trigger")
	if bite_charge == 3 and pending_bite.is_empty():
		var bite_half: float = deg_to_rad(75.0) if sweeping else BITE_HALF_ANGLE
		if run.experiment.active:
			update_bite_target(run, BITE_REACH * reach_multiplier, bite_half)
		var target: Dictionary = bite_target(run, BITE_REACH * reach_multiplier, bite_half)
		if not target.is_empty():
			bite_charge = 0
			last_attack_was_bite = true
			var bite_base: float = 8.0 if sweeping else (22.0 if hunting else 14.0)
			pending_bite = {"remaining": BITE_WINDUP, "target_id": int(target["id"]),
				"direction": run.aim, "reach": BITE_REACH * reach_multiplier,
				"damage": bite_base * damage_multiplier * (1.0 + 0.25 * int(run.upgrades["bite"]) + 0.03 * int(run.upgrades["micro_bite"])),
				"sweeping": sweeping, "hunting": hunting}
			run.events.append({"kind": "nana_bite_windup", "pos": run.player,
				"dir": run.aim, "reach": BITE_REACH * reach_multiplier, "half_angle": bite_half})
	if hit_any and not last_attack_was_bite:
		var extra: int = 1 if run.experiment.active and "c" in run.experiment.abilities and hit_prey else 0
		var charged_mark: bool = run.experiment.active and run.experiment.charged_mark_bonus and charged and hit_prey and prey_id == hit_prey_id and has_prey()
		bite_charge = 3 if charged_mark else mini(3, bite_charge + 1 + extra)
		if charged_mark:
			run.experiment.note(run, "charged_mark_ready", {"target": hit_prey_id})
			run.events.append({"kind": "nana_ready", "pos": run.player})
		if extra > 0:
			run.experiment.note(run, "mark_charge", {"target": hit_prey_id})
	run.combat_metrics["attacks"].append({"time": run.elapsed, "kind": "ring" if ring else "claw", "targets": claw_targets.size()})
	run.events.append({"kind": "swipe", "style": "nana", "pos": run.player,
		"dir": run.aim, "reach": reach, "half_angle": half_angle})
	return (0.28 if hunting and run.hunt_variant == "fast" else 0.42) / (1.0 + 0.10 * int(run.upgrades["haste"]))


func activate_ultimate(run) -> bool:
	if run.character_id != "nana" or run.state != "playing" or run.hp <= 0.0 or cooldown > 0.0 or ultimate_remaining > 0.0:
		return false
	cooldown = ULTIMATE_COOLDOWN
	ultimate_remaining = ULTIMATE_DURATION
	if run.experiment.active:
		run.experiment.note(run, "ultimate")
	run.invulnerability = maxf(run.invulnerability, 0.6)
	for enemy: Dictionary in run.enemies:
		if float(enemy["hp"]) <= 0.0:
			continue
		var offset: Vector2 = Vector2(enemy["pos"]) - run.player
		if offset.length() > ULTIMATE_RADIUS + float(enemy["radius"]):
			continue
		run.damage_enemy(enemy, 15.0 * (1.0 + 0.15 * int(run.upgrades["damage"]) + 0.03 * int(run.upgrades["micro_damage"])), "ultimate")
		if float(enemy["hp"]) > 0.0 and enemy["kind"] in ["chaser", "pursuer"]:
			var push: Vector2 = offset.normalized() if offset.length_squared() > 0.01 else run.aim
			enemy["pos"] = (Vector2(enemy["pos"]) + push * 80.0).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
	run.events.append({"kind": "nana_ultimate", "pos": run.player, "radius": ULTIMATE_RADIUS})
	return true


func _target(run, reach: float, half_angle: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dot: float = -2.0
	var best_distance: float = INF
	for enemy: Dictionary in run.enemies:
		if float(enemy["hp"]) <= 0.0 or not _in_cone(run.player, run.aim, enemy, reach, half_angle):
			continue
		var offset: Vector2 = Vector2(enemy["pos"]) - run.player
		var distance: float = offset.length()
		var alignment: float = run.aim.dot(offset.normalized()) if distance > 0.001 else 1.0
		if alignment > best_dot + 0.00001 or (is_equal_approx(alignment, best_dot) and distance < best_distance):
			best = enemy
			best_dot = alignment
			best_distance = distance
	return best


func has_prey() -> bool:
	return prey_id >= 0 and prey_remaining != 0.0


func bite_target(run, reach: float, half_angle: float) -> Dictionary:
	if run.experiment.active and not pending_bite.is_empty():
		for enemy: Dictionary in run.enemies:
			if int(enemy.id) == int(pending_bite.target_id) and float(enemy.hp) > 0.0:
				return enemy
		return {}
	if run.experiment.active and "c" in run.experiment.abilities and has_prey():
		for enemy: Dictionary in run.enemies:
			if int(enemy.id) == prey_id and float(enemy.hp) > 0.0 and _in_cone(run.player, run.aim, enemy, reach, half_angle):
				return enemy
	if not run.experiment.active:
		return _target(run, reach, half_angle)
	var best: Dictionary = {}
	var current: Dictionary = {}
	var best_score := INF
	var best_distance := INF
	var current_score := INF
	for enemy: Dictionary in run.enemies:
		if float(enemy.hp) <= 0.0 or not _in_cone(run.player, run.aim, enemy, reach, half_angle):
			continue
		var offset: Vector2 = Vector2(enemy.pos) - run.player
		var angle: float = absf(run.aim.angle_to(offset)) if offset.length_squared() > 0.000001 else 0.0
		var score: float = angle - (TARGET_SPECIAL_BONUS if enemy.kind != "chaser" else 0.0)
		if score < best_score - 0.00001 or (is_equal_approx(score, best_score) and offset.length_squared() < best_distance):
			best = enemy
			best_score = score
			best_distance = offset.length_squared()
		if int(enemy.id) == assisted_target_id:
			current = enemy
			current_score = score
	if not current.is_empty() and best_score >= current_score - TARGET_SWITCH_MARGIN:
		return current
	return best


func update_bite_target(run, reach: float, half_angle: float) -> void:
	if not pending_bite.is_empty():
		return
	var target := bite_target(run, reach, half_angle)
	assisted_target_id = int(target.id) if not target.is_empty() else -1


func _in_cone(origin: Vector2, direction: Vector2, enemy: Dictionary, reach: float, half_angle: float) -> bool:
	return CombatGeometry.sector_circle(origin, direction, enemy["pos"], float(enemy["radius"]), reach, half_angle)
