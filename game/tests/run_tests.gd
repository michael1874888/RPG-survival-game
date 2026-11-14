extends SceneTree

const Run := preload("res://scripts/run_model.gd")
const Touch := preload("res://scripts/touch_controls.gd")
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_test_touch_ownership()
	_test_pause_and_ending()
	_test_upgrade_pool()
	_test_projectile_combinations()
	_test_bear_combat()
	_test_nana_combat()
	_test_nana_ultimate()
	_test_nana_encounters()
	_test_nana_growth()
	_test_nana_pressure()
	_test_nana_specialization_rework()
	_test_nana_full_run()
	_test_comparison_modes()
	_test_scenarios()
	_test_spawn_safety()
	_test_full_run()
	_test_full_run("bloom")
	_test_full_run("focus")
	for scenario: String in ["surround", "queue"]:
		for mode: String in ["bloom", "focus"]:
			_test_scenario_flow(mode, scenario)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func touch_event(index: int, pos: Vector2, pressed: bool, canceled: bool = false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = pos
	event.pressed = pressed
	event.canceled = canceled
	return event


func drag_event(index: int, pos: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	return event


func _test_touch_ownership() -> void:
	var controls = Touch.new()
	var viewport := Vector2(1280, 720)
	controls.handle(touch_event(4, Vector2(100, 550), true), viewport)
	controls.handle(touch_event(9, Vector2(1100, 550), true), viewport)
	controls.handle(drag_event(4, Vector2(160, 550)), viewport)
	controls.handle(drag_event(9, Vector2(1040, 550)), viewport)
	check(controls.movement().x > 0.5 and controls.aim_direction().x < -0.9, "Two fingers must independently move and aim")
	controls.handle(touch_event(4, Vector2(160, 550), false), viewport)
	check(controls.movement() == Vector2.ZERO and controls.firing(), "Releasing movement must not stop attack")
	controls.handle(drag_event(9, Vector2(400, 550)), viewport)
	check(controls.aim_id == 9 and controls.move_id == -1, "Crossing midpoint must not steal finger ownership")
	controls.handle(touch_event(9, Vector2(400, 550), true, true), viewport)
	check(not controls.firing() and controls.aim_id == -1, "Canceled touch must release the stick")
	controls.handle(touch_event(2, Vector2(100, 550), true), viewport)
	controls.handle(touch_event(3, Vector2(150, 550), true), viewport)
	check(controls.move_id == 2, "Extra finger cannot replace occupied movement stick")
	controls.clear()
	check(controls.move_id == -1 and controls.aim_id == -1, "Pause must clear all touch ownership")


func _test_pause_and_ending() -> void:
	var model = Run.new(11)
	model.pause()
	model.tick(1.0, Vector2.RIGHT, Vector2.RIGHT, true)
	check(model.elapsed == 0.0 and model.projectiles.is_empty(), "Pause must freeze time, movement and attacks")
	model.resume()
	model.spawn_timer = 1000.0
	model.tick(0.1, Vector2.RIGHT, Vector2.RIGHT, true)
	check(model.elapsed > 0.0 and model.player.x > Run.WORLD.x * 0.5 and model.projectiles.size() == 1, "Resume restores gameplay")
	model.take_damage(10)
	model.take_damage(10)
	check(model.hp == 90.0, "Global invulnerability must prevent same-frame repeated damage")
	model.reset(11)
	model.spawn_timer = 1000.0
	model.elapsed = 179.99
	model.tick(0.02, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.state == "won" and model.elapsed == 180.0, "Surviving three simulated minutes wins")
	model.reset(11)
	model.hp = 0.0
	model.tick(0.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.state == "lost", "Zero health loses")
	model.upgrades["scatter"] = 2
	model.kills = 10
	model.reset(11)
	check(model.hp == 100.0 and model.kills == 0 and model.elapsed == 0 and model.upgrades["scatter"] == 0 and model.pickups.is_empty(), "Restart must remove previous run state")


func _test_upgrade_pool() -> void:
	var model = Run.new(25)
	model.xp = model.required_xp() + 1
	model.maybe_level_up()
	check(model.state == "upgrade" and model.level == 2 and model.xp == 1, "Level-up preserves overflow XP")
	check(model.offers.size() == 3 and model.offers[0] != model.offers[1] and model.offers[0] != model.offers[2] and model.offers[1] != model.offers[2], "Offers must contain three distinct upgrades")
	var before: float = model.elapsed
	model.tick(1.0, Vector2.ONE, Vector2.RIGHT, true)
	check(model.elapsed == before, "Upgrade selection freezes battle")
	check(not model.choose_upgrade("invalid"), "Reject upgrade outside the offered set")
	var chosen: String = model.offers[0]
	check(model.choose_upgrade(chosen) and model.upgrades[chosen] == 1 and model.state == "playing", "Selecting a valid upgrade resumes and applies it once")
	check(not model.choose_upgrade(chosen), "Repeated UI input cannot apply a choice twice")
	for id: String in ["scatter", "pierce", "bounce"]:
		model.upgrades[id] = Run.UPGRADE_DATA[id]["cap"]
	for i in 20:
		model.make_offers()
		check(model.offers.size() == 3 and "scatter" not in model.offers and "pierce" not in model.offers and "bounce" not in model.offers, "Capped upgrades leave pool while repeatable stats keep three choices")
	model.reset(8)
	model.upgrades["scatter"] = 1
	model.fire()
	check(model.projectiles.size() == 3 and float(model.projectiles[0]["damage"]) < 13.0, "Scatter increases coverage with a per-projectile damage tradeoff")


func enemy(id: int, pos: Vector2, health: float = 10.0) -> Dictionary:
	return {"id": id, "pos": pos, "hp": health, "max_hp": health, "kind": "chaser",
		"radius": 10.0, "speed": 0.0, "phase": "chase", "timer": 0.0, "dir": Vector2.ZERO, "flash": 0.0}


func _test_projectile_combinations() -> void:
	var model = Run.new(7)
	model.player = Vector2(100, 100)
	model.enemies.assign([enemy(2, Vector2(190, 100)), enemy(1, Vector2(150, 100)), enemy(3, Vector2(215, 150))])
	model.upgrades["pierce"] = 1
	model.upgrades["bounce"] = 1
	model.fire()
	model.update_projectiles(0.12)
	check(model.kills == 2 and model.projectiles.size() == 1, "Swept collision must hit near enemy before far enemy regardless of insertion order")
	check(model.projectiles[0]["pierce"] == 0 and model.projectiles[0]["bounce"] == 0, "Pierce is spent before bounce")
	check(model.projectiles[0]["dir"].y > 0.0, "Bounce retargets a new nearby enemy")
	model.update_projectiles(0.1)
	check(model.kills == 3 and model.projectiles.is_empty() and model.pickups.size() == 3, "Combined projectile must terminate and award one drop per kill")
	model.reset(7)
	model.player = Vector2(100, 100)
	model.upgrades["bounce"] = 1
	model.enemies.assign([enemy(1, Vector2(150, 100), 100.0)])
	model.fire()
	model.update_projectiles(0.08)
	check(model.projectiles.is_empty() and model.kills == 0 and model.enemies[0]["hp"] == 87.0, "Bounce cannot re-hit the same enemy or loop without a new target")


func _test_bear_combat() -> void:
	var model = Run.new(14, "bear")
	model.player = Vector2(300, 300)
	var front: Dictionary = enemy(1, Vector2(380, 300), 100.0)
	var behind: Dictionary = enemy(2, Vector2(220, 300), 100.0)
	var distant: Dictionary = enemy(3, Vector2(600, 300), 100.0)
	model.enemies.assign([front, behind, distant])
	model.fire()
	check(model.projectiles.is_empty() and model.character_id == "bear", "Bear must use a real melee attack, never hidden projectiles")
	check(front["hp"] == 70.0 and behind["hp"] == 100.0 and distant["hp"] == 100.0, "Melee only damages nearby enemies in the aimed cone")
	check(Vector2(front["pos"]).x > 380.0 and float(front["stagger"]) > 0.0, "Surviving melee target is pushed away and briefly staggered")
	model.enemies.assign([enemy(4, Vector2(380, 300))])
	model.fire()
	model.fire()
	model.update_projectiles(0.0)
	check(model.kills == 1 and model.pickups.size() == 1 and model.enemies.is_empty(), "Melee death cleanup and repeated swings award a kill/drop only once")
	model.make_offers()
	check(model.offers.size() == 3 and "scatter" not in model.offers and "pierce" not in model.offers and "bounce" not in model.offers, "Bear does not receive projectile-only upgrades")
	var base_reach: float = model.melee_reach()
	var base_angle: float = model.melee_half_angle()
	model.upgrades["reach"] = 1
	model.upgrades["wide"] = 1
	check(model.melee_reach() > base_reach and model.melee_half_angle() > base_angle, "Bear-specific upgrades change actual collision geometry")
	model.upgrades["wide"] = 2
	model.upgrades["reach"] = 3
	model.upgrades["push"] = 3
	model.make_offers()
	check(model.offers.size() == 3 and "wide" not in model.offers and "reach" not in model.offers and "push" not in model.offers, "Capped bear abilities leave three legal shared stat choices")
	model.reset(14, "hedgehog")
	model.fire()
	check(model.projectiles.size() == 1 and model.upgrades["reach"] == 0 and model.kills == 0, "Changing animals resets upgrades and restores ranged attack")


func _test_nana_combat() -> void:
	var model = Run.new(14, "nana")
	model.player = Vector2(500, 500)
	model.spawn_timer = 1000.0
	var front: Dictionary = enemy(1, Vector2(590, 500), 1000.0)
	var side: Dictionary = enemy(2, Vector2(575, 540), 1000.0)
	var behind: Dictionary = enemy(3, Vector2(440, 500), 1000.0)
	model.enemies.assign([front, side, behind])
	model.nana.attack(model)
	check(front["hp"] == 990.0 and side["hp"] == 990.0 and behind["hp"] == 1000.0, "Nana claws hit each target once within the aimed cone")
	check(model.nana.bite_charge == 1 and model.projectiles.is_empty(), "A multi-target claw grants one charge without a projectile")
	model.aim = Vector2.UP
	model.nana.attack(model)
	check(model.nana.bite_charge == 1, "A missed claw cannot gain a bite charge")
	model.aim = Vector2.RIGHT
	model.nana.attack(model)
	model.nana.attack(model)
	check(model.nana.bite_charge == 3, "Three successful claws prepare a bite")
	var before_front: float = float(front["hp"])
	var before_side: float = float(side["hp"])
	var interval: float = model.nana.attack(model)
	check(model.nana.bite_charge == 0 and not model.nana.pending_bite.is_empty() and interval == 0.42, "Prepared bite consumes the charge and keeps the claw interval")
	model.nana.advance(model, 0.11)
	check(front["hp"] == before_front - 24.0 and side["hp"] == before_side - 10.0, "Bite adds single-target damage while preserving the claw")
	model.nana.bite_charge = 3
	model.aim = Vector2.UP
	model.nana.attack(model)
	check(model.nana.bite_charge == 3 and model.nana.pending_bite.is_empty(), "Without a bite target, attacking preserves the prepared bite")
	model.aim = Vector2.RIGHT
	model.nana.attack(model)
	front["pos"] = Vector2(1000, 1000)
	var previous_hp: float = float(front["hp"])
	model.nana.advance(model, 0.11)
	check(front["hp"] == previous_hp and model.nana.pending_bite.is_empty(), "A locked bite can miss when its target leaves during windup")
	model.nana.bite_charge = 3
	model.reset(11, "nana")
	check(model.nana.bite_charge == 0 and model.nana.pending_bite.is_empty(), "Restart clears bite charge and pending attack")
	model.xp = 1000
	model.maybe_level_up()
	check(model.state == "playing" and model.level == 1, "Nana's first hand-feel build keeps abilities fixed")
	model.elapsed = 90.0
	for i in 12:
		model.spawn_enemy()
	var only_chasers: bool = model.enemies.size() == 12
	for item: Dictionary in model.enemies:
		only_chasers = only_chasers and item["kind"] == "chaser" and item["hp"] == 18.0
	check(only_chasers, "Nana's hand-feel build spawns only the intended pursuit enemy")


func _test_nana_ultimate() -> void:
	var model = Run.new(22, "nana")
	model.player = Vector2(500, 500)
	model.spawn_timer = 1000.0
	var near: Dictionary = enemy(1, Vector2(600, 500), 100.0)
	var far: Dictionary = enemy(2, Vector2(900, 500), 100.0)
	model.enemies.assign([near, far])
	model.invulnerability = 0.75
	check(model.nana.activate_ultimate(model), "Nana can activate a ready ultimate during gameplay")
	check(near["hp"] == 85.0 and far["hp"] == 100.0 and Vector2(near["pos"]).x == 680.0, "Ultimate pulse damages and pushes nearby chasers only")
	check(model.nana.cooldown == 40.0 and model.nana.ultimate_remaining == 6.0 and model.invulnerability == 0.75, "Ultimate starts cooldown and never shortens existing invulnerability")
	check(not model.nana.activate_ultimate(model) and near["hp"] == 85.0, "Repeated activation cannot deal damage or restart the cooldown")
	model.aim = Vector2.RIGHT
	model.nana.attack(model)
	check(near["hp"] == 70.0, "Shadow form extends claw reach and increases damage")
	model.pause()
	model.tick(5.0, Vector2.ZERO, Vector2.ZERO, false)
	check(model.nana.cooldown == 40.0 and model.nana.ultimate_remaining == 6.0 and not model.nana.activate_ultimate(model), "Pause freezes and rejects ultimate input")
	model.resume()
	model.tick(6.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.nana.ultimate_remaining == 0.0 and model.nana.cooldown > 33.0 and model.nana.cooldown < 34.0, "Shadow ends while the cooldown continues")
	model.tick(34.0, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.nana.cooldown == 0.0 and model.nana.activate_ultimate(model), "Ultimate becomes available again after 40 seconds")
	model.hp = 0.0
	model.nana.cooldown = 0.0
	model.nana.ultimate_remaining = 0.0
	check(not model.nana.activate_ultimate(model), "Ultimate cannot revive a zero-health character")
	model.reset(22, "nana")
	check(model.nana.cooldown == 0.0 and model.nana.ultimate_remaining == 0.0 and model.hp == 100.0, "Restart restores a ready ultimate without an active effect")
	model.player = Vector2(500, 500)
	model.aim = Vector2.RIGHT
	var target: Dictionary = enemy(9, Vector2(600, 500), 100.0)
	target["kind"] = "guard"
	model.enemies.assign([target])
	model.nana.bite_charge = 3
	model.nana.attack(model)
	model.nana.activate_ultimate(model)
	model.nana.advance(model, 0.11)
	check(target["hp"] == 61.0, "A bite started before shadow activation keeps its original damage snapshot")


func _test_nana_encounters() -> void:
	var model = Run.new(1, "nana", "standard", "nana_mixed")
	check(model.enemies.size() == 6 and model.fixed_abilities, "Mixed encounter starts with its fixed enemies and abilities")
	var kinds: Array = []
	for e: Dictionary in model.enemies:
		if e.kind not in kinds:
			kinds.append(e.kind)
	check(kinds.size() == 4, "Mixed encounter contains the four ordinary roles")
	var corner := {"pos": model.player + Vector2.RIGHT.rotated(deg_to_rad(55.0)) * 160.0, "radius": 17.0}
	check(not model.nana._in_cone(model.player, Vector2.RIGHT, corner, 145.0, deg_to_rad(50.0)), "Circle outside sector corner is not hit")
	corner.pos = model.player + Vector2.RIGHT.rotated(deg_to_rad(55.0)) * 155.0
	check(model.nana._in_cone(model.player, Vector2.RIGHT, corner, 145.0, deg_to_rad(50.0)), "Circle intersecting sector corner is hit")
	model = Run.new(1, "nana", "standard", "nana_charger")
	var charger: Dictionary = model.enemies[0]
	charger.pos = model.player + Vector2(200, 0)
	model.tick(0.51, Vector2.ZERO, Vector2.RIGHT, false)
	check(charger.phase == "windup" and Vector2(charger.dir) == Vector2.LEFT, "Charger locks its direction after becoming visible")
	model.apply_heavy_hit(charger)
	check(charger.phase == "recover" and charger.timer > 1.0, "Heavy bite interrupts charger windup")
	charger.phase = "dash"
	charger.timer = 0.5
	charger.pos = model.player + Vector2(120, 0)
	charger.dir = Vector2.LEFT
	model.hp = 100.0
	model.invulnerability = 0.0
	model.encounters.update(model, 0.4)
	check(model.hp == 84.0, "Charger swept collision deals its own damage")
	model = Run.new(1, "nana", "standard", "nana_thrower")
	var thrower: Dictionary = model.enemies[0]
	thrower.pos = model.player + Vector2(300, 0)
	model.tick(0.51, Vector2.ZERO, Vector2.RIGHT, false)
	model.tick(0.81, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.encounters.enemy_projectiles.size() == 1 and thrower.phase == "recover", "Thrower fires a locked projectile after its tell")
	model.invulnerability = 0.0
	model.encounters.update(model, 0.7)
	check(model.hp == 88.0 and model.encounters.enemy_projectiles.is_empty(), "Enemy projectile swept collision damages the player once")
	model = Run.new(1, "nana", "standard", "nana_guard")
	var guard: Dictionary = model.enemies[0]
	guard.pos = model.player + Vector2(150, 0)
	model.tick(0.51, Vector2.ZERO, Vector2.RIGHT, false)
	model.tick(1.11, Vector2.ZERO, Vector2.RIGHT, false)
	check(guard.phase == "recover" and model.hp == 80.0, "Guard damages once when its aimed sector resolves")
	model.enemies.clear()
	model.tick(0.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.state == "won", "Encounter succeeds after all enemies are defeated")
	model = Run.new(1, "nana", "standard", "nana_chasers")
	model.elapsed = 179.99
	model.tick(0.02, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.state == "lost", "Encounter times out if enemies remain")


func _test_nana_growth() -> void:
	var model = Run.new(17, "nana", "standard", "nana_growth")
	check(not model.fixed_abilities and model.drop_xp and model.enemies.is_empty(), "Growth run starts with upgrades enabled")
	model.tick(1.1, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.encounters.pending_spawns.size() == 3 and model.enemies.is_empty(), "Growth enemy is announced before spawning")
	var spawn: Dictionary = model.encounters.pending_spawns[0]
	check(Vector2(spawn.pos).distance_to(model.player) >= 320.0, "Spawn warning is at least 320 units from player")
	model.tick(1.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.enemies.size() == 3, "Announced enemies appear after warning")
	model.xp = model.required_xp()
	model.maybe_level_up()
	check(model.state == "upgrade" and model.level == 2 and model.offers.size() == 3, "Experience pauses growth run and provides three choices")
	var elapsed: float = model.elapsed
	model.tick(1.0, Vector2.RIGHT, Vector2.RIGHT, true)
	check(model.elapsed == elapsed, "Upgrade choice freezes gameplay time")
	model.choose_upgrade(model.offers[0])
	model.level = 4
	model.make_offers()
	check("sweep" in model.offers and "hunt" in model.offers, "Level four offers both specializations")
	model.state = "upgrade"
	model.choose_upgrade("sweep")
	model.level = 5
	model.make_offers()
	check(int(model.upgrades.sweep) == 1 and "hunt" not in model.offers, "Specialization selection is exclusive")
	model.enemies.clear()
	model.player = Vector2(500, 500)
	model.aim = Vector2.RIGHT
	var front: Dictionary = enemy(500, Vector2(590, 500), 1000.0)
	var side: Dictionary = enemy(501, Vector2(580, 570), 1000.0)
	model.enemies.assign([front, side])
	model.nana.bite_charge = 3
	model.nana.attack(model)
	model.nana.advance(model, 0.11)
	check(float(front.hp) < 982.1 and float(side.hp) < 982.1, "Sweep bite hits both targets in addition to claw")
	model = Run.new(17, "nana", "standard", "nana_growth")
	model.upgrades.hunt = 1
	model.player = Vector2(500, 500)
	var target: Dictionary = enemy(502, Vector2(590, 500), 1000.0)
	model.enemies.assign([target])
	model.nana.bite_charge = 3
	model.nana.attack(model)
	model.nana.advance(model, 0.11)
	check(float(target.hp) == 964.0 and float(target.vulnerable) == 2.0, "Hunt bite deals single-target damage then applies vulnerability")
	model.damage_enemy(target, 10.0)
	check(float(target.hp) == 952.0, "Subsequent hit benefits from hunt vulnerability")
	model.enemies.clear()
	model.encounters.add_enemy(model, "elite", model.player + Vector2(150, 0))
	var elite: Dictionary = model.enemies[0]
	elite.phase = "windup"
	elite.dir = Vector2.LEFT
	elite.timer = 0.01
	model.encounters.update(model, 0.02)
	check(elite.phase == "second_wait", "Elite enters second-attack pause after its first sweep")
	model.encounters.update(model, 0.51)
	check(elite.phase == "windup" and bool(elite.second_strike), "Elite telegraphs its second sweep separately")
	model.encounters.update(model, 0.91)
	check(elite.phase == "recover", "Elite recovers after its second sweep")
	model.damage_enemy(elite, 1000.0)
	check(model.encounters.elite_defeated, "Defeating elite satisfies the growth run objective")


func _test_nana_pressure() -> void:
	for variant: String in ["current", "fast", "heavy"]:
		var model = Run.new(123, "nana", "standard", "nana_pressure_dense")
		model.upgrades.hunt = 1
		model.hunt_variant = variant
		model.player = Vector2(500, 500)
		model.aim = Vector2.RIGHT
		var target: Dictionary = enemy(500, Vector2(590, 500), 1000.0)
		model.enemies.assign([target])
		var interval: float = model.nana.attack(model)
		check(is_equal_approx(interval, 0.28 if variant == "fast" else 0.42), "Hunt variant interval matches preset")
		check(is_equal_approx(float(target.hp), 979.0 if variant == "heavy" else 986.0), "Hunt variant damage matches preset")
		check(model.fixed_abilities and not model.drop_xp, "Pressure comparison keeps abilities fixed")
	var model = Run.new(42, "nana", "standard", "nana_growth")
	model.encounters.spawn_countdown = 100.0
	model.encounters.special_countdown = 100.0
	model.encounters.pending_spawns.append({"kind": "chaser", "pos": model.player, "timer": 0.1})
	model.encounters.update_growth(model, 0.2)
	check(model.enemies.is_empty() and model.encounters.spawn_stats.cancelled == 1, "Unsafe spawn is cancelled")
	check(model.encounters.spawn_stats.retried == 1 and model.encounters.pending_spawns.size() == 1 and is_equal_approx(float(model.encounters.pending_spawns[0].timer), 1.0), "Cancelled spawn gets a new full warning")
	check(model.encounters._occupied(model) <= 45, "Population cap includes pending and retry queue")
	model = Run.new(42, "nana", "standard", "nana_pressure_standard")
	model.tick(1.1, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.encounters.pending_spawns.size() == 1, "Standard density preserves original single spawn")


func _test_nana_specialization_rework() -> void:
	var model = Run.new(1, "nana", "standard", "nana_growth")
	model.player = Vector2(500, 500)
	model.aim = Vector2.RIGHT
	model.upgrades.sweep = 1
	var front: Dictionary = enemy(701, Vector2(590, 500), 1000.0)
	var back: Dictionary = enemy(702, Vector2(410, 500), 1000.0)
	front.kind = "guard"
	back.kind = "guard"
	model.enemies.assign([front, back])
	model.nana.attack(model)
	model.nana.attack(model)
	check(float(back.hp) == 1000.0 and model.nana.sweep_count == 2, "First two sweep attacks leave rear target unharmed and prepare ring")
	model.pause()
	model.tick(1.0, Vector2.ZERO, Vector2.RIGHT, true)
	check(model.nana.sweep_count == 2, "Pause freezes ring cycle")
	model.resume()
	model.nana.attack(model)
	check(float(front.hp) == 970.0 and float(back.hp) == 990.0 and model.nana.sweep_count == 0, "Third sweep hits front and rear once each")
	check(model.nana.bite_charge == 3, "Multi-target ring grants only one bite charge")
	check(model.combat_metrics.attacks.size() == 3 and int(model.combat_metrics.attacks[2].targets) == 2 and float(model.combat_metrics.damage.ring) == 20.0, "Metrics record ring target count and applied damage")
	model.nana.bite_charge = 3
	var edge: Dictionary = enemy(703, model.player + Vector2.RIGHT.rotated(deg_to_rad(60.0)) * 175.0, 100.0)
	edge.kind = "guard"
	model.enemies.assign([edge])
	model.nana.attack(model)
	check(not model.nana.pending_bite.is_empty() and model.nana.bite_charge == 0, "Sweep bite can start on a target near the wide cone edge")
	model.nana.advance(model, 0.11)
	check(float(edge.hp) == 92.0, "Sweep bite resolves in the wider cone")
	model = Run.new(1, "nana", "standard", "nana_growth")
	model.player = Vector2(500, 500)
	model.aim = Vector2.RIGHT
	model.upgrades.hunt = 1
	model.upgrades.wide = 2
	front = enemy(710, Vector2(590, 500), 1000.0)
	var other: Dictionary = enemy(711, Vector2(600, 515), 1000.0)
	front.kind = "guard"
	other.kind = "guard"
	model.enemies.assign([front, other])
	model.nana.attack(model)
	check(float(front.hp) == 986.0 and float(other.hp) == 1000.0 and model.nana.marked_target_id == 710, "Hunt's widened aim still claws only one aligned target")
	front.hp = 14.0
	model.nana.bite_charge = 3
	model.nana.attack(model)
	check(float(front.hp) <= 0.0 and int(model.nana.pending_bite.get("target_id", -1)) == 711, "Hunt reselects living target after claw kills prior target")
	model.nana.advance(model, 0.11)
	check(float(other.hp) == 978.0, "Reselected target receives bite")
	check(float(model.combat_metrics.damage.bite) == 22.0, "Metrics record actual bite damage")
	model.nana.bite_charge = 3
	model.enemies.assign([front])
	front.hp = 14.0
	model.nana.attack(model)
	check(model.nana.bite_charge == 3 and model.nana.pending_bite.is_empty(), "Hunt preserves charge when claw leaves no living target")
	model.reset(1, "nana", "standard", "nana_growth")
	check(model.nana.sweep_count == 0 and model.nana.marked_target_id == -1, "Restart clears specialization feedback state")
	model.upgrades.sweep = 1
	model.upgrades.wide = 2
	model.upgrades.reach = 2
	model.nana.ultimate_remaining = 6.0
	model.nana.attack(model)
	model.nana.attack(model)
	check(model.nana.sweep_count == 2 and model.nana.bite_charge == 0, "Missed attacks advance ring cycle without granting bite charge")
	back = enemy(712, model.player + Vector2.LEFT * 180.0, 1000.0)
	back.kind = "guard"
	model.enemies.assign([back])
	model.nana.attack(model)
	check(float(back.hp) == 985.0 and model.nana.sweep_count == 0, "Upgraded shadow ring remains all-directional")
	model.reset(1, "nana", "standard", "nana_growth")
	model.upgrades.hunt = 1
	model.upgrades.wide = 2
	model.upgrades.reach = 2
	model.nana.ultimate_remaining = 6.0
	front = enemy(713, model.player + Vector2.RIGHT * 200.0, 1000.0)
	other = enemy(714, model.player + Vector2.RIGHT * 210.0, 1000.0)
	front.kind = "guard"
	other.kind = "guard"
	model.enemies.assign([front, other])
	model.nana.attack(model)
	check(float(front.hp) == 979.0 and float(other.hp) == 1000.0, "Upgraded shadow hunt still hits only one target")


func _test_nana_full_run() -> void:
	# Fixed automated inputs and invulnerability exercise the path, not player balance.
	var model = Run.new(901, "nana")
	var activations: int = 0
	var max_enemies: int = 0
	var only_chasers: bool = true
	for frame in 60 * 181:
		if model.state != "playing":
			break
		if model.nana.activate_ultimate(model):
			activations += 1
		var move := Vector2.RIGHT.rotated(model.elapsed * 0.7)
		var target: Dictionary = model.nearest_target(model.player, [])
		var direction: Vector2 = Vector2(target["pos"]) - model.player if not target.is_empty() else move
		model.invulnerability = 1.0
		model.tick(1.0 / 60.0, move, direction, true)
		model.events.clear()
		max_enemies = maxi(max_enemies, model.enemies.size())
		for item: Dictionary in model.enemies:
			only_chasers = only_chasers and item["kind"] == "chaser"
	check(model.state == "won" and model.elapsed == 180.0 and model.kills > 0, "Nana's full practice reaches its result while exercising combat")
	check(activations == 5 and only_chasers and max_enemies <= 60 and model.level == 1 and model.pickups.is_empty(), "Full practice repeats ultimate use and keeps the intended fixed enemy and ability scope")
	print("NANA PRACTICE: kills=%d ultimates=%d max_enemies=%d (test-only invulnerability)" % [model.kills, activations, max_enemies])


func _test_comparison_modes() -> void:
	var broad = Run.new(0, "hedgehog", "bloom")
	var focused = Run.new(0, "hedgehog", "focus")
	check(broad.level == 1 and broad.xp == 0 and broad.chosen_upgrades.is_empty(), "Starter abilities are not falsely counted as earned levels or choices")
	check(broad.upgrades["scatter"] == 1 and broad.upgrades["bounce"] == 2 and broad.upgrades["damage"] == 1, "Broad build starts with its four advertised upgrade ranks")
	check(focused.upgrades["pierce"] == 2 and focused.upgrades["haste"] == 1 and focused.upgrades["damage"] == 1, "Focused build starts with its four advertised upgrade ranks")
	broad.fire()
	focused.fire()
	check(broad.projectiles.size() == 3 and focused.projectiles.size() == 1 and focused.shot_interval() < broad.shot_interval(), "Comparison builds produce different actual coverage and firing rhythm")
	# Drawing upgrade cards may consume a different number of random values after
	# caps, but must not change the shared enemy random stream.
	for i in 5:
		broad.make_offers()
	broad.spawn_enemy()
	focused.spawn_enemy()
	check(broad.enemies[0]["pos"] == focused.enemies[0]["pos"] and broad.enemies[0]["hp"] == focused.enemies[0]["hp"], "Upgrade draws cannot perturb matched comparison enemy generation")
	broad.xp = broad.required_xp()
	broad.maybe_level_up()
	var chosen: String = broad.offers[0]
	broad.choose_upgrade(chosen)
	check(broad.chosen_upgrades.size() == 1 and broad.chosen_upgrades[0] == chosen and broad.upgrades[chosen] == int(broad.starting_upgrades.get(chosen, 0)) + 1, "Earned choice history and starter counts stay separate")
	check(not broad.choose_upgrade(chosen) and broad.chosen_upgrades.size() == 1, "Repeated input cannot duplicate build history")
	broad.reset(0, "hedgehog", "bloom")
	check(broad.chosen_upgrades.is_empty() and broad.upgrades[chosen] == int(broad.starting_upgrades.get(chosen, 0)) and broad.kills == 0, "Comparison restart reapplies only the starter build")
	broad.reset(0, "bear", "bloom")
	check(broad.mode_id == "standard" and broad.starting_upgrades.is_empty() and broad.upgrades["scatter"] == 0, "Bear cannot inherit hedgehog comparison abilities")
	broad.reset(0, "hedgehog", "invalid")
	check(broad.mode_id == "standard" and broad.starting_upgrades.is_empty(), "Unknown mode safely falls back to ordinary play")
	# Off-axis targets distinguish bounce targeting from straight piercing.
	for mode: String in ["bloom", "focus"]:
		var model = Run.new(50, "hedgehog", mode)
		model.player = Vector2(100, 100)
		model.enemies.assign([enemy(1, Vector2(150, 100)), enemy(2, Vector2(205, 155)), enemy(3, Vector2(205, 45))])
		model.fire()
		for frame in 20:
			model.update_projectiles(0.02)
		check(model.kills > 1 if mode == "bloom" else model.kills == 1, "Broad bounce reaches off-axis targets; focused piercing retains its aimed line (%s)" % mode)


func _test_scenarios() -> void:
	var model = Run.new(0, "hedgehog", "focus", "queue")
	check(model.scenario_id == "queue" and model.duration() == 45.0, "Short queue encounter uses its own end time")
	var positions: Array[Vector2] = model.scenario_positions()
	var aligned: bool = positions.size() == 8
	for i in positions.size():
		aligned = aligned and positions[i].y == model.player.y and positions[i].x > model.player.x
		if i > 0:
			aligned = aligned and is_equal_approx(positions[i].x - positions[i - 1].x, 36.0)
	check(aligned, "Queue schedules eight targets along one direction at fixed spacing")
	model.tick(0.8, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.enemies.is_empty() and model.warning_positions.size() == 8 and model.warning_remaining == Run.WAVE_WARNING, "Arrival warnings precede enemies rather than appearing as a same-frame hit")
	model.pause()
	model.tick(2.0, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.enemies.is_empty() and model.warning_remaining == Run.WAVE_WARNING and model.elapsed == 0.8, "Pause freezes warning and encounter clocks")
	model.resume()
	model.tick(0.5, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.enemies.is_empty() and model.warning_remaining > 0.0, "Enemies cannot arrive halfway through warning")
	model.tick(0.51, Vector2.ZERO, Vector2.RIGHT, false)
	var identical: bool = model.enemies.size() == 8 and model.warning_positions.is_empty()
	for item: Dictionary in model.enemies:
		identical = identical and item["kind"] == "chaser" and item["hp"] == 19.0 and item["speed"] == 72.0
	check(identical, "Scenario spawns only the documented identical ordinary targets")
	model.xp = 1000
	model.maybe_level_up()
	check(model.state == "playing" and model.level == 1 and model.offers.is_empty() and model.chosen_upgrades.is_empty(), "Scenario pickups cannot alter fixed builds or open upgrade UI")
	model.reset(0, "hedgehog", "bloom", "surround")
	positions = model.scenario_positions()
	var surrounding: bool = positions.size() == 8
	var quadrants: Array[bool] = [false, false, false, false]
	for pos: Vector2 in positions:
		var offset: Vector2 = pos - model.player
		surrounding = surrounding and is_equal_approx(offset.length(), 300.0)
		var quadrant: int = (2 if offset.y < 0.0 else 0) + (1 if offset.x < 0.0 else 0)
		quadrants[quadrant] = true
	check(surrounding and not false in quadrants, "Surround pattern covers all quadrants at fixed radius")
	var other = Run.new(0, "hedgehog", "focus", "surround")
	other.player += Vector2(400, 100)
	check(other.scenario_positions() == positions, "Build selection and player movement cannot move scheduled arrival coordinates")
	model.elapsed = 44.99
	model.spawn_timer = 1000.0
	model.tick(0.02, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.state == "won" and model.elapsed == 45.0, "Short encounter finishes at 45 seconds")
	model.reset(0, "hedgehog", "bloom", "surround")
	check(model.elapsed == 0.0 and model.wave_count == 0 and model.warning_positions.is_empty() and model.enemies.is_empty(), "Restart clears encounter waves and pending arrivals")
	model.hp = 0.0
	model.tick(0.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(model.state == "lost", "Short encounter retains real loss conditions")
	model.reset(0, "bear", "bloom", "queue")
	check(model.mode_id == "standard" and model.scenario_id == "normal" and model.duration() == 180.0, "Bear cannot accidentally inherit short comparison encounter")
	model.reset(0, "hedgehog", "standard", "queue")
	model.xp = model.required_xp()
	model.maybe_level_up()
	check(model.scenario_id == "normal" and model.state == "upgrade", "Ordinary play still levels up and retains original encounter")
	model.reset(0, "hedgehog", "bloom", "invalid")
	check(model.scenario_id == "normal", "Invalid scenario safely falls back to original survival")


func _test_scenario_flow(mode: String, scenario: String) -> void:
	# Fixed aim/movement and invulnerability are test harness input only.
	var model = Run.new(0, "hedgehog", mode, scenario)
	var starter: Dictionary = model.upgrades.duplicate()
	for frame in 60 * 46:
		if model.state != "playing":
			break
		model.invulnerability = 1.0
		model.tick(1.0 / 60.0, Vector2.ZERO, Vector2.RIGHT, true)
		model.events.clear()
	check(model.state == "won" and model.elapsed == 45.0 and model.wave_count == 8, "Full short encounter traverses all eight waves: %s / %s" % [scenario, mode])
	check(model.next_enemy_id == 65 and model.upgrades == starter and model.level == 1 and model.kills > 0, "Full encounter exercises 64 arrivals and combat while preserving build: %s / %s" % [scenario, mode])
	print("SCENARIO [%s / %s]: kills=%d arrivals=%d (fixed aim, test-only invulnerability)" % [scenario, mode, model.kills, model.next_enemy_id - 1])


func _test_spawn_safety() -> void:
	var model = Run.new(71)
	model.elapsed = 90.0
	for i in 60:
		model.spawn_enemy()
	var visible := Rect2(model.camera_origin() - Vector2.ONE * 45.0, model.view_size + Vector2.ONE * 90.0)
	var safe: bool = true
	for item: Dictionary in model.enemies:
		safe = safe and not visible.has_point(item["pos"]) and Vector2(item["pos"]).distance_to(model.player) > 380.0
	check(safe and model.enemies.size() == 60, "Enemy spawn points stay offscreen and away from player")
	var charger: Dictionary = enemy(900, model.player + Vector2(160, 0), 100)
	charger["kind"] = "charger"
	model.enemies.assign([charger])
	model.update_enemies(0.1)
	var locked_direction: Vector2 = charger["dir"]
	check(charger["phase"] == "windup", "Charger must visibly wind up before dashing")
	model.player += Vector2(0, 180)
	model.update_enemies(0.5)
	check(charger["dir"] == locked_direction, "Charger telegraph must not secretly track movement")


func _test_full_run(mode: String = "standard") -> void:
	# Automated integration traversal, not a claim about human win rate or balance.
	var model = Run.new(901, "hedgehog", mode)
	var choices: int = 0
	var max_enemies: int = 0
	for frame in 60 * 181:
		if model.state == "upgrade":
			model.choose_upgrade(model.offers[0])
			choices += 1
		if model.state != "playing":
			break
		# Auto-run route and aim are test harness input only, never a player option.
		var move := Vector2.RIGHT.rotated(model.elapsed * 0.7)
		var target: Dictionary = model.nearest_target(model.player, [])
		var direction: Vector2 = Vector2(target["pos"]) - model.player if not target.is_empty() else move
		model.invulnerability = 1.0
		model.tick(1.0 / 60.0, move, direction, true)
		model.events.clear()
		max_enemies = maxi(max_enemies, model.enemies.size())
	check(model.state == "won" and model.elapsed == 180.0, "Full run reaches success across spawns, collision, pickup and upgrades")
	check(model.kills > 0 and choices > 0 and max_enemies <= 110, "Full run must exercise combat/growth and honor enemy cap")
	print("INTEGRATION [%s]: kills=%d upgrades=%d max_enemies=%d (test-only invulnerability)" % [mode, model.kills, choices, max_enemies])
