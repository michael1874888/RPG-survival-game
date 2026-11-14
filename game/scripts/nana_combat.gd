extends RefCounted
## Nana's attacks and ultimate; the run owns enemies, health, movement and time.

const CombatGeometry := preload("res://scripts/combat_geometry.gd")

const CLAW_REACH: float = 145.0
const CLAW_HALF_ANGLE: float = deg_to_rad(50.0)
const BITE_REACH: float = 175.0
const BITE_HALF_ANGLE: float = deg_to_rad(27.5)
const BITE_WINDUP: float = 0.1
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


func reset() -> void:
	bite_charge = 0
	cooldown = 0.0
	ultimate_remaining = 0.0
	pending_bite.clear()
	last_attack_was_bite = false
	sweep_count = 0
	marked_target_id = -1
	marker_remaining = 0.0


func advance(run, delta: float) -> void:
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
			run.damage_enemy(enemy, float(pending_bite["damage"]), "bite")
			if float(enemy["hp"]) > 0.0:
				run.apply_heavy_hit(enemy)
				if bool(pending_bite.get("hunting", false)):
					enemy["vulnerable"] = 2.0
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
	for enemy: Dictionary in claw_targets:
		hit_any = true
		if hunting:
			marked_target_id = int(enemy["id"])
			marker_remaining = 1.0
		run.damage_enemy(enemy, ((21.0 if run.hunt_variant == "heavy" else 14.0) if hunting else 10.0) * damage_multiplier, "ring" if ring else "claw")
		if float(enemy["hp"]) > 0.0 and enemy["kind"] == "chaser":
			var offset: Vector2 = Vector2(enemy["pos"]) - run.player
			var push: Vector2 = offset.normalized() if offset.length_squared() > 0.01 else run.aim
			enemy["pos"] = (Vector2(enemy["pos"]) + push * (24.0 if ring else 12.0)).clamp(Vector2.ONE * 20.0, run.WORLD - Vector2.ONE * 20.0)
	last_attack_was_bite = false
	if bite_charge == 3 and pending_bite.is_empty():
		var bite_half: float = deg_to_rad(75.0) if sweeping else BITE_HALF_ANGLE
		var target: Dictionary = _target(run, BITE_REACH * reach_multiplier, bite_half)
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
		bite_charge = mini(3, bite_charge + 1)
	run.combat_metrics["attacks"].append({"time": run.elapsed, "kind": "ring" if ring else "claw", "targets": claw_targets.size()})
	run.events.append({"kind": "swipe", "style": "nana", "pos": run.player,
		"dir": run.aim, "reach": reach, "half_angle": half_angle})
	return (0.28 if hunting and run.hunt_variant == "fast" else 0.42) / (1.0 + 0.10 * int(run.upgrades["haste"]))


func activate_ultimate(run) -> bool:
	if run.character_id != "nana" or run.state != "playing" or run.hp <= 0.0 or cooldown > 0.0 or ultimate_remaining > 0.0:
		return false
	cooldown = ULTIMATE_COOLDOWN
	ultimate_remaining = ULTIMATE_DURATION
	run.invulnerability = maxf(run.invulnerability, 0.6)
	for enemy: Dictionary in run.enemies:
		if float(enemy["hp"]) <= 0.0:
			continue
		var offset: Vector2 = Vector2(enemy["pos"]) - run.player
		if offset.length() > ULTIMATE_RADIUS + float(enemy["radius"]):
			continue
		run.damage_enemy(enemy, 15.0 * (1.0 + 0.15 * int(run.upgrades["damage"]) + 0.03 * int(run.upgrades["micro_damage"])), "ultimate")
		if float(enemy["hp"]) > 0.0 and enemy["kind"] == "chaser":
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


func _in_cone(origin: Vector2, direction: Vector2, enemy: Dictionary, reach: float, half_angle: float) -> bool:
	return CombatGeometry.sector_circle(origin, direction, enemy["pos"], float(enemy["radius"]), reach, half_angle)
