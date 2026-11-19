extends SceneTree

const Run := preload("res://scripts/run_model.gd")
const Expedition := preload("res://scripts/r1_expedition.gd")
const Profile := preload("res://scripts/r1_profile.gd")
const Legacy := preload("res://scripts/treasure_collection.gd")

var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func make_run(core := "a", habit := "", charm := "", assist := false):
	var run = Run.new()
	var expedition = Expedition.new()
	expedition.begin(run, core, 20261120, habit, charm, assist)
	run.player = Vector2(1200.0, 1200.0)
	run.aim = Vector2.RIGHT
	run.enemies.clear()
	return run


func target(run, position: Vector2, hp := 1000.0) -> Dictionary:
	run.encounters.add_enemy(run, "guard", position)
	var e: Dictionary = run.enemies[-1]
	e.hp = hp
	e.max_hp = hp
	return e


func shadow_cast(run, branch: String) -> void:
	run.growth.levels.a = 3
	run.growth.a_branch = branch
	run.experiment.levels = run.growth.levels.duplicate()
	for i in 9:
		run.elapsed = float(i) * 0.42
		run.nana.attack(run)
		if i < 8: run.nana.advance(run, 0.4)


func resolve_bite(run, e: Dictionary) -> void:
	run.nana.pending_bite = {"remaining": 0.01, "target_id": int(e.id), "direction": Vector2.RIGHT, "reach": 175.0, "empowered": false}
	run.nana.advance(run, 0.02)


func test_builds() -> void:
	var run = make_run("a")
	var e = target(run, run.player + Vector2(90, 0))
	shadow_cast(run, "wide")
	check(run.nana.pending_shadows.size() == 1 and float(run.nana.pending_shadows[0].width) == 180.0, "A-W produces one wider third shadow")
	run = make_run("a")
	e = target(run, run.player + Vector2(90, 0))
	shadow_cast(run, "echo")
	check(run.nana.pending_shadows.size() == 2 and bool(run.nana.pending_shadows[1].echo), "A-E schedules an additional echo")
	var before = float(e.hp)
	run.nana.advance(run, 1.0)
	check(is_equal_approx(before - float(e.hp), 22.4) and run.nana.pending_shadows.is_empty(), "A-E echo deals 40 percent and cannot recurse")
	run = make_run("b")
	e = target(run, run.player + Vector2(70, 0))
	run.growth.levels.b = 3
	run.growth.b_branch = "double"
	run.experiment.levels = run.growth.levels.duplicate()
	run.nana.movement_charge = 520.0
	run.nana.attack(run)
	check(run.nana.movement_charge == 260.0, "B-D stores two charges and spends exactly one")
	e.pos = run.player + Vector2(70, 0)
	run.nana.attack(run)
	check(run.nana.movement_charge == 0.0, "B-D second hit consumes the stored charge")
	run = make_run("b")
	e = target(run, run.player + Vector2(70, 0))
	run.growth.levels.b = 3
	run.growth.b_branch = "follow"
	run.experiment.levels = run.growth.levels.duplicate()
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	check(run.nana.follow_target_id == int(e.id), "B-F marks the pushed enemy")
	e.pos = run.player + Vector2(70, 0)
	before = float(e.hp)
	run.nana.attack(run)
	check(is_equal_approx(before - float(e.hp), 20.0) and run.nana.follow_target_id == -1, "B-F next claw adds one follow bite")
	run = make_run("c")
	e = target(run, run.player + Vector2(70, 0))
	run.growth.levels.c = 3
	run.growth.c_branch = "hold"
	run.experiment.levels = run.growth.levels.duplicate()
	run.nana.prey_id = e.id
	run.nana.prey_remaining = -1.0
	resolve_bite(run, e)
	check(is_equal_approx(float(e.hp), 964.0) and run.nana.prey_id == int(e.id), "C-H cashes in and retains the surviving prey")
	run = make_run("c")
	e = target(run, run.player + Vector2(70, 0), 20.0)
	var other = target(run, run.player + Vector2(140, 0))
	run.growth.levels.c = 3
	run.growth.c_branch = "jump"
	run.experiment.levels = run.growth.levels.duplicate()
	run.nana.prey_id = e.id
	run.nana.prey_remaining = -1.0
	resolve_bite(run, e)
	check(float(e.hp) <= 0.0 and run.nana.prey_id == int(other.id), "C-J moves a defeated prey mark to one nearby enemy")
	check(is_equal_approx(float(other.hp), 992.0), "C2 cash wave reaches the nearby enemy once")
	for pair in [["a", "H01"], ["b", "H03"], ["c", "H05"]]:
		run = make_run(pair[0], pair[1])
		run.growth.levels[pair[0]] = 2
		check(run.growth.formed(pair[0]), "Habit %s grants its own early form" % pair[1])
		run = make_run(pair[0], "H03" if pair[0] != "b" else "H01")
		run.growth.levels[pair[0]] = 2
		check(not run.growth.formed(pair[0]), "An unrelated habit cannot grant an early form")


func test_modifiers_and_links() -> void:
	var run = make_run("a")
	var e = target(run, run.player + Vector2(70, 0))
	run.growth.mods.append("M01")
	run.nana.attack(run)
	run.elapsed = 1.5
	run.nana.attack(run)
	check(run.nana.shadow_count == 2, "M01 retains the chain at 1.5 seconds")
	run.growth.mods.append("M02")
	run.elapsed = 1.6
	run.nana.attack(run)
	check(is_equal_approx(float(run.nana.pending_shadows[0].damage), 10.8) and is_equal_approx(float(run.nana.pending_shadows[0].remaining), 0.25), "M02 changes shadow damage and delay")
	run.take_damage(8.0, "test")
	run.r1.resolve_damage(run)
	check(run.nana.shadow_power == 0, "Taking damage resets the A chain")
	run = make_run("b")
	e = target(run, run.player + Vector2(70, 0))
	run.growth.mods.assign(["M05", "M07"])
	run.nana.movement_charge = 220.0
	var before = float(e.hp)
	run.nana.attack(run)
	check(run.nana.movement_charge == 0.0 and is_equal_approx(before - float(e.hp), 18.0), "M05 makes charged attacks cost 220 and add 8 damage")
	check(is_equal_approx(float(e.slow_factor), 0.30) and is_equal_approx(float(e.slow_remaining), 1.5), "M07 slows ordinary enemies even at B1")
	run = make_run("c")
	e = target(run, run.player + Vector2(70, 0), 5.0)
	var other = target(run, run.player + Vector2(130, 0))
	run.growth.mods.append("M09")
	run.nana.prey_id = e.id
	run.nana.prey_remaining = -1.0
	run.nana.attack(run)
	check(run.nana.prey_id == int(other.id), "M09 transfers a mark killed by a normal claw")
	run = make_run("c")
	e = target(run, run.player + Vector2(70, 0))
	run.growth.mods.append("M10")
	resolve_bite(run, e)
	check(is_equal_approx(float(e.hp), 980.0), "M10 raises the unmarked bite to 20")
	run = make_run("a")
	e = target(run, run.player + Vector2(70, 0))
	run.growth.levels.b = 1
	run.growth.links.append("S01")
	run.experiment.abilities.append("b")
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	check(run.nana.shadow_count == 2, "S01 counts a charged hit as two A hits")
	run = make_run("a")
	e = target(run, run.player + Vector2(70, 0))
	run.growth.levels.c = 1
	run.growth.links.append("S03")
	run.experiment.abilities.append("c")
	run.nana.prey_id = e.id
	run.nana.prey_remaining = -1.0
	run.nana.pending_shadows.append({"remaining": 0.0, "pos": run.player, "dir": Vector2.RIGHT, "length": 340.0, "width": 90.0, "damage": 8.0, "echo": false})
	run.nana.advance(run, 0.01)
	check(run.nana.bite_charge == 1 and run.nana.link_s03_cooldown > 0.0, "S03 original shadow on prey grants one bite charge")
	run.nana.pending_shadows.append({"remaining": 0.0, "pos": run.player, "dir": Vector2.RIGHT, "length": 340.0, "width": 90.0, "damage": 8.0, "echo": true})
	run.nana.link_s03_cooldown = 0.0
	run.nana.advance(run, 0.01)
	check(run.nana.bite_charge == 1, "S03 cannot trigger from an echo")
	run = make_run("b")
	e = target(run, run.player + Vector2(70, 0))
	run.growth.levels.c = 1
	run.growth.links.append("S05")
	run.experiment.abilities.append("c")
	run.nana.prey_id = e.id
	run.nana.prey_remaining = -1.0
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	check(run.nana.bite_charge == 3 and run.nana.pending_bite.is_empty(), "S05 fills bite for the next attack rather than firing it immediately")


func test_saves() -> void:
	var unique = "user://r1-deep-test-%d" % Time.get_ticks_usec()
	var legacy = Legacy.new(unique + ".old")
	check(legacy.acquire() and legacy.set_equipped(true), "Test legacy bell can be created")
	var profile = Profile.new(unique + ".save", unique + ".old")
	check("H03" in profile.data.owned and profile.data.habit == "H03", "Owned and equipped v0.19 bell migrates")
	check(profile.commit(profile.data) and profile.select_item("charm", "U01"), "Migrated collection is committed with a verified backup")
	var original = FileAccess.get_file_as_bytes(unique + ".save")
	var invalid = profile.data.duplicate(true)
	invalid.owned = ["not-an-item"]
	check(not profile.commit(invalid) and FileAccess.get_file_as_bytes(unique + ".save") == original, "Invalid profile cannot overwrite a valid save")
	var file = FileAccess.open(unique + ".save", FileAccess.WRITE)
	file.store_var({"payload": var_to_bytes({"test": true}), "hash": "intentionally-wrong"}, false)
	file.close()
	var recovered = Profile.new(unique + ".save", unique + ".old")
	check(not recovered.load_failed and "H03" in recovered.data.owned, "Corrupt primary recovers the verified previous copy")
	check(recovered.select_item("charm", "U02"), "Recovery remains writable without copying damaged data over the backup")
	var reopened = Profile.new(unique + ".save", unique + ".old")
	check(reopened.data.charm == "U02" and reopened.data.habit == "H03", "Recovered state survives a second launch")
	var run = make_run("b")
	run.r1.route_event = "EV06"
	run.experiment.event_elapsed = 12.5
	run.experiment.package_progress = 2.5
	run.nana.movement_charge = 175.0
	run.nana.pending_bite = {"remaining": 0.2, "target_id": 3, "direction": Vector2.RIGHT, "reach": 175.0, "empowered": false}
	run.encounters.enemy_projectiles.append({"pos": Vector2(100, 100), "dir": Vector2.LEFT, "life": 1.0, "damage": 12.0, "speed": 240.0})
	var snapshot = run.r1.snapshot(run)
	check(reopened.save_active(snapshot), "A live encounter snapshot is committed")
	var expected_random = run.r1.route_rng.randi()
	var resumed_run = Run.new()
	var resumed = Expedition.new()
	check(resumed.restore(resumed_run, reopened.data.active), "Live encounter snapshot restores")
	check(resumed_run.state == "paused" and resumed_run.nana.movement_charge == 175.0 and resumed_run.nana.pending_bite.target_id == 3, "Resuming pauses and keeps pending combat")
	check(resumed_run.experiment.package_progress == 2.5 and resumed_run.encounters.enemy_projectiles.size() == 1, "Resuming retains event and projectile state")
	check(resumed.route_rng.randi() == expected_random, "Random stream resumes from the saved state")
	for suffix in [".save", ".save.bak", ".save.tmp", ".save.bak.tmp", ".old", ".old.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(unique + suffix))


func test_damage_and_respec() -> void:
	var run = make_run("a", "", "U01", true)
	run.take_damage(8.0, "weak")
	run.take_damage(20.0, "strong")
	run.r1.resolve_damage(run)
	check(is_equal_approx(run.hp, 93.0) and run.r1.last_injury == "strong", "Same-step damage chooses largest hit before assist and first-hit charm")
	run.invulnerability = 0.0
	run.take_damage(8.0, "later")
	run.r1.resolve_damage(run)
	check(is_equal_approx(run.hp, 87.0), "First-hit charm applies only once per battle")
	run = make_run("b")
	run.growth.mods.append("M05")
	run.nana.movement_charge = 110.0
	run.r1.phase = "camp"
	var offers = run.r1.begin_respec(run, "M05")
	check(not offers.is_empty() and "M05" not in offers, "Camp replacement offers valid alternatives")
	var first_offers = offers.duplicate()
	check(run.r1.begin_respec(run, "M05") == first_offers, "Cancelling and reopening cannot reroll a camp replacement for free")
	check(run.r1.apply_respec(run, offers[0]) and is_equal_approx(run.nana.movement_charge, 130.0), "Removing M05 preserves half a charge and spends one reroll")
	check(run.growth.rerolls == 1 and run.growth.respec_used and run.r1.begin_respec(run, "M05").is_empty(), "Only one camp replacement is allowed")
	run.hp = run.max_hp
	run.nana.cooldown = 20.0
	check(run.r1.available_supply(run, true) == ["cooldown"], "Event supply cannot offer a reroll while a direct supply is useful")
	run.nana.cooldown = 0.0
	check(run.r1.available_supply(run, true) == ["reroll"], "Event supply falls back to a reroll when both direct supplies are full")


func test_candidate_paths() -> void:
	for seed_value in range(1, 81):
		var core = ["a", "b", "c"][seed_value % 3]
		var habit = {"a": "H01", "b": "H03", "c": "H05"}[core] if seed_value % 4 == 0 else ""
		var run = Run.new()
		var expedition = Expedition.new()
		expedition.begin(run, core, seed_value, habit, "", false)
		for turn in range(10):
			run.growth.stage_completed = 3 if turn >= 3 else 0
			var groups: Array = run.growth._groups()
			var legal: Array = groups[0] + groups[1] + groups[2]
			run.state = "upgrade"
			run.offers.assign(run.growth.make_offers(run.level))
			check(run.offers.size() == 3 and run.offers[0] != run.offers[1] and run.offers[0] != run.offers[2] and run.offers[1] != run.offers[2], "Seed %d turn %d offers three different cards" % [seed_value, turn])
			check(run.offers.all(func(id): return id in legal), "Seed %d turn %d offers only legal cards" % [seed_value, turn])
			check(groups[0].is_empty() or run.offers[0] in groups[0], "Seed %d turn %d reserves an eligible core opportunity" % [seed_value, turn])
			var chosen = str(run.offers[(seed_value + turn) % 3])
			if chosen in ["a", "b", "c"] and int(run.growth.levels.get(chosen, 0)) == 2:
				chosen = {"a": "a_echo", "b": "b_follow", "c": "c_jump"}[chosen]
			check(run.choose_upgrade(chosen), "Seed %d turn %d accepts its offered choice" % [seed_value, turn])
			check(run.growth.levels.size() <= 2 and run.growth.mods.size() <= 2 and run.growth.links.size() <= 2, "Seed %d turn %d respects build capacity" % [seed_value, turn])


func test_boss_priority() -> void:
	var run = make_run("a")
	run.r1.node = 9
	run.r1._load_node(run, run.growth, {})
	run.experiment.schedule.clear()
	run.enemies.clear()
	run.player = Vector2(1200, 1200)
	run.encounters.add_enemy(run, "elite", run.player + Vector2(100, 0))
	var boss: Dictionary = run.enemies[0]
	boss.variant = "boss"
	boss.hp = 900.0
	boss.max_hp = 900.0
	boss["attack_cycle"] = 0
	run.damage_enemy(boss, 400.0, "test")
	check(run.experiment.boss_phase == 1, "Boss enters its first support phase at 60 percent")
	boss.attack_cycle = 1
	run.experiment.update_schedule(run, 0.1)
	check(run.experiment.schedule.is_empty(), "Boss does not summon before two attacks finish")
	boss.attack_cycle = 2
	run.experiment.update_schedule(run, 0.1)
	check(run.experiment.schedule.size() == 2 and run.experiment.schedule.all(func(e): return e.kind == "chaser" and e.no_xp), "Boss adds two XP-free chasers after two attacks")
	run.damage_enemy(boss, 300.0, "test")
	check(run.experiment.boss_phase == 2, "Boss enters its second support phase at 30 percent")
	run.experiment.schedule.clear()
	boss.attack_cycle = 4
	run.experiment.update_schedule(run, 0.1)
	check(run.experiment.schedule.is_empty(), "Boss support respects its 15-second interval")
	run.elapsed = 15.0
	run.experiment.update_schedule(run, 0.1)
	check(run.experiment.schedule.size() == 2 and run.experiment.schedule.any(func(e): return e.kind == "pursuer"), "Boss second phase adds a pursuer after the interval")
	run = make_run("a")
	run.r1.node = 9
	run.r1._load_node(run, run.growth, {})
	run.enemies.clear()
	run.player = Vector2(1200, 1200)
	run.encounters.add_enemy(run, "elite", run.player + Vector2(70, 0))
	boss = run.enemies[0]
	boss.variant = "boss"
	boss.hp = 5.0
	boss.max_hp = 900.0
	run.hp = 5.0
	run.shot_timer = 0.0
	run.encounters.enemy_projectiles.append({"pos": run.player, "dir": Vector2.RIGHT, "life": 1.0, "damage": 20.0, "speed": 0.0})
	run.tick(0.1, Vector2.ZERO, Vector2.RIGHT, true)
	check(run.state == "won" and run.hp == 5.0, "A lethal boss hit wins before same-step hostile damage")


func test_boss_attacks() -> void:
	var run = make_run("a")
	var boss = target(run, run.player + Vector2(100, 0), 900.0)
	boss.kind = "elite"
	boss.variant = "boss"
	boss.damage = 20.0
	boss.speed = 70.0
	boss.visible_time = 1.0
	run.encounters.update(run, 0.01)
	check(boss.phase == "windup" and boss.attack_kind == "sweep", "Boss announces the first sweep")
	boss.timer = 0.001
	run.encounters.update(run, 0.01)
	check(boss.phase == "second_wait", "Boss first sweep is followed by a second windup")
	boss.timer = 0.001
	run.encounters.update(run, 0.01)
	boss.timer = 0.001
	run.encounters.update(run, 0.01)
	check(boss.phase == "recover" and int(boss.attack_cycle) == 1, "Boss completes its two-sweep cycle")
	run.r1.pending_damage = 0.0
	run.invulnerability = 0.0
	run.hp = 100.0
	run.elapsed = 10.0
	boss.phase = "chase"
	run.encounters.update(run, 0.01)
	check(boss.phase == "windup" and boss.attack_kind == "root", "Boss alternates to the telegraphed root strike")
	boss.timer = 0.001
	run.encounters.update(run, 0.01)
	run.r1.resolve_damage(run)
	check(is_equal_approx(run.hp, 82.0) and boss.phase == "recover", "Boss root deals 18 and enters recovery")


func finish_event(event: String, succeed := true):
	var run = make_run("a")
	var expedition = run.r1
	expedition.node = 4
	expedition.route_event = event
	expedition._load_node(run, run.growth, {})
	run.hp = 50.0
	if event == "EV05" and not succeed: run.experiment.event_elapsed = 46.0
	if event == "EV06" and succeed:
		run.player = run.experiment.package_pos
		for i in 61:
			run.invulnerability = 2.0
			run.tick(0.1, Vector2.ZERO, Vector2.RIGHT, false)
	if event == "EV06" and not succeed: run.experiment.event_elapsed = 36.0
	var steps = 0
	var seen_event_elite = false
	while run.state not in ["won", "lost"] and steps < 4000:
		if run.state == "upgrade":
			var card = str(run.offers[0])
			if card in ["a", "b", "c"] and int(run.growth.levels.get(card, 0)) == 2: card = {"a": "a_wide", "b": "b_double", "c": "c_hold"}[card]
			run.choose_upgrade(card)
		else:
			run.invulnerability = 2.0 # Controlled probe; no claim of player difficulty.
			run.tick(0.1, Vector2.ZERO, Vector2.RIGHT, false)
			if run.state == "playing":
				for enemy: Dictionary in run.enemies:
					if enemy.get("variant", "") in ["event_warden", "event_stalker"]: seen_event_elite = true
					if float(enemy.hp) > 0.0: run.damage_enemy(enemy, 10000.0, "test")
		steps += 1
	check(run.state == "won", "%s %s still completes its normal encounter" % [event, succeed])
	if event in ["EV04", "EV05"]: check(seen_event_elite, "%s spawns its required event elite" % event)
	var xp = run.growth.total_xp
	check(xp == 54, "%s preserves the 54 XP node budget" % event)
	expedition.finish_node(run)
	return run


func test_events() -> void:
	var run = finish_event("EV01")
	check(is_equal_approx(run.hp, 70.0), "EV01 restores 20 HP after the fight")
	run = finish_event("EV02")
	check(run.growth.rerolls == 3, "EV02 gives one reroll")
	run = finish_event("EV03")
	check(run.r1.event_window_next and run.r1.next_node(run), "EV03 advances its protection to the following fight")
	run.elapsed = 3.99
	check(not run.encounters.can_start(run, 0.9), "EV03 prevents the first special windup before four seconds")
	run.elapsed = 4.0
	check(run.encounters.can_start(run, 0.9), "EV03 permits the first special windup after four seconds")
	run = finish_event("EV04")
	check(run.r1.phase == "chest_event", "EV04 offers an extra collection chest")
	run = finish_event("EV05")
	check(run.experiment.event_success and run.r1.phase == "event_common", "EV05 timely kill grants a free common talent")
	run = finish_event("EV05", false)
	check(not run.experiment.event_success and run.r1.phase == "between", "EV05 timeout forfeits reward without ending the run")
	run = finish_event("EV06")
	check(run.experiment.event_success and run.r1.phase == "event_supply", "EV06 collecting package grants a supply choice")
	run = finish_event("EV06", false)
	check(not run.experiment.event_success and run.r1.phase == "between", "EV06 timeout forfeits reward without ending the run")


func _initialize() -> void:
	test_builds()
	test_modifiers_and_links()
	test_saves()
	test_damage_and_respec()
	test_candidate_paths()
	test_boss_priority()
	test_boss_attacks()
	test_events()
	print("R1 MECHANICS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
