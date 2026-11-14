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
