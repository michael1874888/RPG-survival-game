extends SceneTree

const Growth := preload("res://scripts/r1_growth.gd")
const Profile := preload("res://scripts/r1_profile.gd")
const Waves := preload("res://scripts/r1_waves.gd")
const Combat := preload("res://scripts/r1_combat.gd")
const Encounters := preload("res://scripts/r1_encounters.gd")
const Expedition := preload("res://scripts/r1_expedition.gd")
const Run := preload("res://scripts/run_model.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var growth = Growth.new()
	growth.begin_r1("b", 19, "H03")
	check(growth.required(1) == 12 and growth.required(10) == 66 and growth.required(11) == 0, "R1 uses ten explicit XP thresholds")
	check(growth.bell_equipped and not growth.formed("b"), "Bell reserves B formation before level 2")
	growth.levels.b = 2
	check(growth.formed("b") and growth.b_branch == "follow", "Bell grants follow at B2")
	var unique := "user://r1-test-%d" % Time.get_ticks_usec()
	var profile = Profile.new(unique + ".save", unique + ".old")
	check(profile.data.owned == ["U01", "U02"], "New profile starts with both charms")
	check(profile.commit(profile.data), "A profile can be written")
	var reopened = Profile.new(unique + ".save", unique + ".old")
	check(reopened.data.owned == ["U01", "U02"], "A saved profile can be read")
	var run = Run.new()
	var expedition = Expedition.new()
	expedition.begin(run, "b", 135, "H03", "U01", false)
	check(run.r1 == expedition and run.growth.formed("b") == false, "R1 expedition starts with a reserved bell")
	check(run.experiment.schedule.size() == 18, "First room has its finite wave schedule")
	var saved = expedition.snapshot(run)
	check(profile.save_active(saved), "A run snapshot is stored")
	var restored = Expedition.new()
	var restored_run = Run.new()
	check(restored.restore(restored_run, profile.data.active), "A stored run snapshot can be restored")
	check(restored_run.state == "paused" and restored_run.experiment.schedule.size() == 18, "Restored simulation starts paused with its schedule")
	exercise_full_expedition(profile)
	for suffix in [".save", ".save.bak", ".save.tmp", ".save.bak.tmp", ".old"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(unique + suffix))
	print("R1 RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func choose_card(run) -> bool:
	if run.offers.is_empty(): return false
	var id: String = run.offers[0]
	if id in ["a", "b", "c"] and int(run.growth.levels.get(id, 0)) == 2:
		id = {"a": "a_wide", "b": "b_double", "c": "c_hold"}[id]
	return run.choose_upgrade(id)


func exercise_full_expedition(profile) -> void:
	var run = Run.new()
	var expedition = Expedition.new()
	expedition.begin(run, "b", 2468, "", "U01", false)
	var accumulated_xp := 0
	for expected_node in range(1, 10):
		check(expedition.node == expected_node, "Expedition reaches node %d" % expected_node)
		var budget := 0
		for ticket: Dictionary in run.experiment.schedule: budget += int(ticket.xp_value)
		check(budget == run.experiment.BUDGETS[expected_node - 1], "Node %d distributes its exact XP budget" % expected_node)
		var steps := 0
		while run.state not in ["won", "lost"] and steps < 4000:
			if run.state == "upgrade":
				check(choose_card(run), "A legal offered card can be chosen")
			else:
				run.invulnerability = 2.0 # Controlled flow probe, not player balance evidence.
				run.tick(0.1, Vector2.ZERO, Vector2.RIGHT, false)
				if run.state == "playing":
					for enemy: Dictionary in run.enemies:
						if float(enemy.hp) > 0.0: run.damage_enemy(enemy, 10000.0, "test")
			steps += 1
		check(run.state == "won", "Finite node %d completes without timing out" % expected_node)
		if run.state != "won": return
		accumulated_xp += budget
		check(run.growth.total_xp == accumulated_xp, "Collected XP after node %d matches the ledger" % expected_node)
		expedition.finish_node(run)
		if expected_node == 9:
			check(expedition.won and expedition.phase == "result" and run.level == 11, "Boss victory produces a complete Lv.11 result")
			break
		while expedition.phase not in ["between", "result"]:
			match expedition.phase:
				"chest", "chest_event":
					var items: Array[String] = expedition.choose_chest(profile)
					if items.is_empty():
						var supplies: Array[String] = expedition.available_supply(run)
						if supplies.is_empty(): expedition.advance_pending()
						else: check(expedition.use_supply(run, supplies[0]), "A valid chest supply is applied")
					else: check(expedition.acquire_chest(run, profile, items[0]), "A new chest item is persisted")
				"camp":
					var routes: Array[String] = expedition.choose_routes(run)
					check(routes.size() == 2 and expedition.select_route(routes[0]), "Camp offers and applies one safe route")
				"event_common":
					run.growth.free_common = true
					run.offers.assign(run.growth.make_offers(run.level))
					run.state = "upgrade"
					check(choose_card(run), "An earned event common can be chosen")
					expedition.advance_pending()
					run.state = "won"
				"event_supply":
					var supplies: Array[String] = expedition.available_supply(run, true)
					if supplies.is_empty(): expedition.advance_pending()
					else: check(expedition.use_supply(run, supplies[0], true), "An earned event supply can be chosen")
				_:
					check(false, "Unexpected reward phase: " + expedition.phase)
					return
		check(expedition.next_node(run), "Advancing preserves the current run")
	check("H03" in profile.data.owned, "Guaranteed bell persists across the nine-node run")
