extends SceneTree
const Run = preload("res://scripts/run_model.gd")
const Series = preload("res://scripts/nana_series.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func all_offer_states_valid() -> bool:
	for packed in range(64):
		var ranks := [packed % 4, (packed / 4) % 4, (packed / 16) % 4]
		var core_sum: int = int(ranks[0]) + int(ranks[1]) + int(ranks[2])
		var slots: int = int(ranks[0] > 0) + int(ranks[1] > 0) + int(ranks[2] > 0)
		var capstones: int = int(ranks[0] == 3) + int(ranks[1] == 3) + int(ranks[2] == 3)
		if slots < 1 or slots > 2 or capstones > 1: continue
		for packed_common in range(27):
			var common := [packed_common % 3, (packed_common / 3) % 3, (packed_common / 9) % 3]
			var spent: int = core_sum - 1 + int(common[0]) + int(common[1]) + int(common[2])
			if spent < 0 or spent > 5 or (capstones > 0 and spent < 2): continue
			var growth = Run.GrowthRun.new()
			growth.begin("a", 1701)
			growth.levels.clear()
			for i in 3:
				if int(ranks[i]) > 0: growth.levels[["a", "b", "c"][i]] = int(ranks[i])
			growth.common = {"power": common[0], "reach": common[1], "vitality": common[2]}
			var picks: Array[String] = growth.make_offers(spent + 2)
			if picks.size() != 3 or picks[0] == picks[1] or picks[0] == picks[2] or picks[1] == picks[2]:
				push_error("Invalid offers for %s %s: %s" % [ranks, common, picks])
				return false
	return true

func _initialize() -> void:
	check(all_offer_states_valid(), "All legal growth states provide three distinct cards")
	var run = Run.new()
	var series = Series.new()
	check(series.begin(run, "a", true, true), "Growth run starts")
	check(run.growth != null and run.drop_xp and run.level == 1, "Short run uses growth and XP")
	run.enemies.clear()
	run.encounters.add_enemy(run, "pursuer", run.player + Vector2(80, 0))
	var enemy: Dictionary = run.enemies[0]
	run.damage_enemy(enemy, 1000.0)
	check(run.pickups.size() == 1 and run.pickups[0].value == 3, "Pursuer drops three XP")
	run.pickups.clear()
	run.xp = 12 + 20 + 28
	run.maybe_level_up()
	check(run.state == "upgrade" and run.level == 2 and run.offers.size() == 3, "XP opens three legal cards")
	check("a" in run.offers, "Owned core progression guaranteed")
	check(run.choose_upgrade("a") and run.level == 3 and run.state == "upgrade", "Excess XP queues second upgrade")
	check(run.choose_upgrade(run.offers[0]) and run.level == 4 and run.state == "upgrade", "Excess XP queues third upgrade")
	check(run.choose_upgrade(run.offers[0]) and run.state == "playing", "Choosing all queued levels resumes")
	check(run.growth.decisions.size() == 3, "Choices are recorded")
	# Even after two common upgrades are maxed, both core choices fill the final card.
	var offers_test = run.GrowthRun.new()
	offers_test.begin("a", 123)
	offers_test.levels = {"a": 1, "b": 1}
	offers_test.common = {"power": 2, "reach": 2, "vitality": 0}
	check(offers_test.make_offers(7).size() == 3, "Valid core advances fill empty common-card slot")
	# A receives damage: real injury resets, invulnerable contact does not.
	run.experiment.levels["a"] = 3
	run.nana.shadow_count = 2
	run.nana.shadow_power = 3
	run.invulnerability = 1.0
	run.take_damage(5.0)
	check(run.nana.shadow_count == 2 and run.nana.shadow_power == 3, "Blocked hit retains A combo")
	run.invulnerability = 0.0
	run.take_damage(5.0)
	check(run.nana.shadow_count == 0 and run.nana.shadow_power == 0, "Actual injury resets A combo")
	# A3 builds three shadow tiers; a hit resets future combo but not pending shadows.
	run.enemies.clear()
	run.encounters.add_enemy(run, "guard", run.player + Vector2(100, 0))
	enemy = run.enemies[0]
	enemy.hp = 1000.0
	run.invulnerability = 0.0
	for i in 9:
		run.nana.attack(run)
		run.elapsed += 0.42
	check(run.nana.shadow_power == 3 and run.nana.pending_shadows[-1].width == 180.0, "A3 gains the wide shadow after sustained hits")
	var saved_shadows: int = run.nana.pending_shadows.size()
	run.take_damage(1.0)
	check(run.nana.shadow_power == 0 and run.nana.pending_shadows.size() == saved_shadows, "Injury resets A without cancelling already queued shadows")
	# Two charges and partial progress survive a successful attack.
	run.experiment.abilities.assign(["b"])
	run.experiment.levels = {"b": 3}
	run.enemies.clear()
	run.encounters.add_enemy(run, "guard", run.player + Vector2(100, 0))
	run.nana.movement_charge = 520.0
	run.nana.attack(run)
	check(is_equal_approx(run.nana.movement_charge, 260.0), "One charged hit consumes only one of two charges")
	run.nana.attack(run)
	check(is_zero_approx(run.nana.movement_charge), "Second charged hit consumes second charge")
	# B3 branch selection and follow-up hit use the same upgrade.
	series.begin(run, "b", true, true)
	run.growth.levels = {"b": 2}
	run.experiment.levels = {"b": 2}
	run.state = "upgrade"
	run.growth.offers.assign(["b", "power", "reach"])
	check(run.choose_upgrade("b_follow") and run.growth.b_branch == "follow" and run.growth.levels.b == 3, "B3 selects follow branch in one upgrade")
	run.enemies.clear()
	run.encounters.add_enemy(run, "pursuer", run.player + Vector2(100, 0))
	enemy = run.enemies[0]
	enemy.hp = 200.0
	run.aim = Vector2.RIGHT
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	check(run.nana.follow_target_id == enemy.id and is_equal_approx(run.nana.follow_remaining, 2.0), "Charged push marks living target")
	var hp_before: float = enemy.hp
	run.player = Vector2(enemy.pos) - Vector2(100, 0)
	run.nana.attack(run)
	check(is_equal_approx(hp_before - float(enemy.hp), 20.0) and run.nana.follow_target_id == -1, "Next claw grants one follow-up bite")
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	run.nana.advance(run, 2.1)
	check(run.nana.follow_target_id == -1, "Follow mark expires")
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	run.aim = Vector2.LEFT
	run.nana.attack(run)
	check(run.nana.follow_target_id == -1, "A missed next claw clears follow mark")
	run.aim = Vector2.RIGHT
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	run.damage_enemy(enemy, 1000.0)
	check(run.nana.follow_target_id == -1, "Target death clears follow mark")
	run.enemies.clear()
	run.encounters.add_enemy(run, "guard", run.player + Vector2(100, 0))
	enemy = run.enemies[0]
	enemy.hp = 200.0
	run.nana.prey_id = int(enemy.id)
	run.nana.prey_remaining = -1.0
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	check(run.nana.follow_target_id == -1 and run.nana.prey_id == int(enemy.id), "C prey is not pushed or follow-marked")
	run.nana.prey_id = -1
	run.nana.movement_charge = 260.0
	run.nana.attack(run)
	run.state = "won"
	check(series.collect(run) and series.advance_growth(run) and run.growth.b_branch == "follow" and run.nana.follow_target_id == -1, "Branch persists across stages while mark clears")
	check(series.begin(run, "b", true, true) and run.growth.b_branch == "double", "Retry resets branch selection")
	# Cashout retains a living C3 prey, without granting a free extra bite.
	run.experiment.abilities.assign(["c"])
	run.experiment.levels = {"c": 3}
	run.enemies.clear()
	run.encounters.add_enemy(run, "guard", run.player + Vector2(100, 0))
	enemy = run.enemies[0]
	run.nana.prey_id = int(enemy.id)
	run.nana.prey_remaining = -1.0
	run.nana.pending_bite = {"remaining": 0.01, "target_id": enemy.id, "direction": Vector2.RIGHT, "reach": 175.0, "damage": 14.0, "sweeping": false, "hunting": false}
	run.nana.advance(run, 0.02)
	check(run.nana.prey_id == int(enemy.id) and float(enemy.hp) > 0.0, "C3 cashout retains surviving prey")
	# At stage clear remaining drops are banked before transition, including queued levels.
	series.begin(run, "b", true, true)
	for event in run.experiment.schedule: event.state = "born"
	run.enemies.clear()
	run.pickups.clear()
	run.pickups.append({"pos": run.player + Vector2(700, 0), "value": 40})
	run.tick(0.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(run.state == "upgrade" and run.growth.stage_complete_pending, "Stage clear banks distant XP before intermission")
	while run.state == "upgrade": run.choose_upgrade(run.offers[0])
	check(run.state == "won" and run.level == 3 and run.xp == 8, "Queued upgrades finish before stage victory")
	var expected_levels: Dictionary = run.growth.levels.duplicate()
	check(series.collect(run) and series.between and series.advance_growth(run), "Growth intermission advances")
	check(run.level == 3 and run.xp == 8 and run.growth.levels == expected_levels, "Growth survives stage reset")
	check(run.hp == 100.0 and run.max_hp == 100.0, "Stage heal respects max HP")
	series.stage = 3
	series.snapshot = {}
	series._load_stage(run, run.experiment.abilities)
	check(run.experiment.growth_mode and run.experiment.schedule.size() == 8, "Final stage has one boss, six chasers and one thrower")
	run.enemies.clear()
	run.encounters.add_enemy(run, "elite", run.player + Vector2(150, 0))
	enemy = run.enemies[0]
	enemy.hp = 900.0
	enemy.max_hp = 900.0
	run.damage_enemy(enemy, 610.0)
	check(run.experiment.guardian_thresholds.size() == 2, "One hit crossing both thresholds queues both waves")
	check(is_equal_approx(float(run.experiment.schedule[-1].at) - float(run.experiment.schedule[-7].at), 2.0), "Crossed thresholds are spaced two seconds apart")
	# The second wave cannot warn until two seconds after the first actual warning.
	for entry in run.experiment.schedule:
		if int(entry.get("guardian_phase", 0)) == 1: entry.at = 100.0
		elif int(entry.get("guardian_phase", 0)) == 2: entry.at = 0.0
		else: entry.state = "born"
	run.elapsed = 10.0
	run.experiment.update_schedule(run, 0.01)
	check(not run.experiment.schedule.any(func(e): return int(e.get("guardian_phase", 0)) == 2 and e.state == "warning"), "Second wave waits if first is delayed")
	for entry in run.experiment.schedule:
		if int(entry.get("guardian_phase", 0)) == 1: entry.at = 0.0
	run.experiment.update_schedule(run, 0.01)
	check(run.experiment.guardian_first_warning == 10.0, "First wave records actual warning time")
	run.elapsed = 11.9
	run.experiment.update_schedule(run, 0.01)
	check(not run.experiment.schedule.any(func(e): return int(e.get("guardian_phase", 0)) == 2 and e.state == "warning"), "Second warning waits full two seconds")
	run.damage_enemy(enemy, 1000.0)
	run.tick(0.01, Vector2.ZERO, Vector2.RIGHT, false)
	check(run.state == "won", "Defeating guardian wins without clearing support")
	check(not run.experiment.schedule.any(func(e): return e.state not in ["born", "cancelled"]), "Guardian defeat cancels pending spawns")
	print("GROWTH RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
