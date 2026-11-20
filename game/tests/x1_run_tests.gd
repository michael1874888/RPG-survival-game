extends SceneTree
## X1 run layer: map generation, node flow, rewards, shop, events, boss, results,
## and the profile: saves, recovery, migration, unlocks, records and exact snapshot resume.

const Data := preload("res://scripts/x1/core/data.gd")
const Rng := preload("res://scripts/x1/core/rng_streams.gd")
const MapGen := preload("res://scripts/x1/core/map_gen.gd")
const Run := preload("res://scripts/x1/core/run.gd")
const Profile := preload("res://scripts/x1/core/profile.gd")
const Progress := preload("res://scripts/x1/core/progress.gd")
const LegacyProfile := preload("res://scripts/r1_profile.gd")
const Bot := preload("res://tests/x1_bot.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	map_tests()
	flow_tests()
	shop_and_event_tests()
	profile_tests()
	snapshot_tests()
	print("X1 RUN: %d checks, %d failures" % [checks, failures])
	Data.release()
	quit(1 if failures > 0 else 0)


func map_tests() -> void:
	var data = Data.shared()
	var shape_ok := true
	var reach_ok := true
	var first_ok := true
	var last_ok := true
	var den_ok := true
	for seed_value in 1000:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map: Dictionary = MapGen.generate(rng, data.tuning.map)
		var rows: Array = map.rows
		if rows.size() != 7: shape_ok = false
		for row: Array in rows:
			if row.size() < 2 or row.size() > 3: shape_ok = false
		for id in rows[0]:
			if map.nodes[id].kind != "hunt": first_ok = false
		var has_bed := false
		for id in rows[6]:
			if map.nodes[id].kind == "bed": has_bed = true
			if map.nodes[id].kind not in ["bed", "shop"]: last_ok = false
		if not has_bed: last_ok = false
		var early_den := false
		for layer in [1, 2]:
			for id in rows[layer]:
				if map.nodes[id].kind == "den": early_den = true
		if not early_den: den_ok = false
		var reached := {}
		var frontier: Array = rows[0].duplicate()
		while not frontier.is_empty():
			var id: String = frontier.pop_back()
			if reached.has(id): continue
			reached[id] = true
			frontier.append_array(map.nodes[id].links)
		if reached.size() != map.nodes.size(): reach_ok = false
		for id in map.nodes:
			if id != "boss" and map.nodes[id].links.is_empty(): reach_ok = false
	check(shape_ok, "1000 maps: 7 layers of 2-3 nodes")
	check(reach_ok, "1000 maps: every node reachable and every path reaches the boss")
	check(first_ok, "1000 maps: the first layer is always a hunt")
	check(last_ok, "1000 maps: the last layer is rest or shop, always with a bed")
	check(den_ok, "1000 maps: an elite den appears in layer 2 or 3")


func _play_battle(run, bot) -> void:
	var guard := 0
	while run.phase == "battle" and guard < 60 * 400:
		guard += 1
		if run.needs_level_choice():
			run.choose_card(bot.pick_card(run))
			continue
		run.battle.player.invuln = 1.0
		run.tick(1.0 / 60.0, bot.battle_input(run.battle, 1.0 / 60.0))
		if run.battle != null: run.battle.take_events()


func flow_tests() -> void:
	var run = Run.new()
	run.begin({"seed": 3, "region": "courtyard", "habit": "roam", "owned": ["U01", "U02"], "bell_guarantee": true})
	check(run.phase == "map" and run.available_nodes() == run.map.rows[0], "a run starts on the map at layer 1")
	check(not run.enter("boss"), "cannot skip ahead to the boss")
	var bot = Bot.new()
	run.enter(run.available_nodes()[0])
	check(run.phase == "battle" and run.battle != null and run.battle.kind == "hunt", "entering a hunt starts a battle")
	var fish_before: int = run.fish
	_play_battle(run, bot)
	check(run.phase == "map" and run.battles_won == 1, "winning a hunt returns to the map")
	check(run.fish >= fish_before + 2, "hunts pay fish")
	check(run.level >= 2, "hunting gives levels (level %d)" % run.level)
	check(run.available_nodes() == run.map.nodes[run.at].links, "next choices follow the map links")
	# Force a den next to test its rewards.
	var den_id: String = run.available_nodes()[0]
	run.map.nodes[den_id].kind = "den"
	run.enter(den_id)
	_play_battle(run, bot)
	check(run.phase == "card" and run.choice_context == "reward", "an elite den offers a card reward first")
	run.choose_card(run.build.offers[0])
	check(run.phase == "item" and "H03" in run.item_choices, "first chest guarantees 回身鈴鐺")
	var snapshot_before: Dictionary = run.to_dict()
	check(run.confirm_item("H03") and "H03" in run.new_items, "the chosen item is recorded")
	check(not run.confirm_item("H03"), "an item cannot be claimed twice")
	check(run.phase == "map", "after rewards the map continues")
	# Bed.
	run.phase = "bed"
	run.hp = 10.0
	check(run.bed_rest() and run.hp > 10.0 and run.phase == "map", "the bed heals")
	run.phase = "bed"
	if not run.build.upgradable().is_empty():
		var id: String = run.build.upgradable()[0]
		var level: int = run.build.cards[id]
		check(run.bed_train() and run.pick_upgrade(id) and run.build.cards[id] == level + 1, "the bed can train a card instead")
	# Boss.
	run.at = run.map.rows[6][0]
	run.phase = "map"
	check(run.available_nodes() == ["boss"], "the last layer leads to the boss")
	run.enter("boss")
	check(run.battle.kind == "boss", "the boss node starts the boss battle")
	var boss_guard := 0
	while run.phase == "battle" and boss_guard < 60 * 60:
		boss_guard += 1
		if run.needs_level_choice():
			run.choose_card(bot.pick_card(run))
			continue
		var boss: Dictionary = run.battle.boss()
		if not boss.is_empty(): run.battle.damage_enemy(boss, 999999.0, "claw", 0)
		run.battle.player.invuln = 1.0
		run.tick(1.0 / 60.0, {})
	while run.phase in ["item", "supply", "card"]:
		if run.phase == "item": run.confirm_item(run.item_choices[0])
		elif run.phase == "supply": run.choose_supply(run.supply_choices[0])
		else: run.choose_card(run.build.offers[0])
	check(run.phase == "result" and run.won and run.finished, "beating the boss wins the run")
	var summary: Dictionary = run.summary()
	check(summary.region == "courtyard" and summary.won and summary.metrics.kills > 0 and summary.cards.size() > 0, "the summary records the run")
	var loss = Run.new()
	loss.begin({"seed": 4, "region": "courtyard", "habit": "hunt"})
	loss.enter(loss.available_nodes()[0])
	loss.battle.player.hp = 1.0
	loss.battle.hurt_player(50.0, "E01")
	loss.tick(1.0 / 60.0, {})
	check(loss.phase == "result" and not loss.won and loss.summary().last_hurt == "E01", "dying ends the run and names what hit last")
	var late = Run.new()
	late.begin({"seed": 6, "region": "courtyard", "habit": "roam"})
	late.enter(late.available_nodes()[0])
	late.battle.begin_net()
	late.battle.pickups.append({"pos": late.battle.player.pos + Vector2(400, 0), "value": 30})
	for i in 200:
		late.tick(1.0 / 60.0, {})
		if late.phase != "battle": break
	check(late.phase == "card" and late.choice_context == "level" and late.battle == null, "level-ups from the net are offered right after the battle")
	var level_guard := 0
	while late.phase == "card" and level_guard < 10:
		level_guard += 1
		late.choose_card(late.build.offers[0])
	check(late.phase == "map" and late.pending_levels == 0, "after the leftover level-ups the map continues")
	var practice = Run.new()
	practice.begin({"seed": 5, "region": "courtyard", "habit": "shadow", "practice": true})
	check(practice.phase == "battle" and practice.battle.kind == "practice", "practice starts a single practice battle")


func shop_and_event_tests() -> void:
	var run = Run.new()
	run.begin({"seed": 8, "region": "greenhouse", "habit": "shadow"})
	run.phase = "map"
	run.at = run.map.rows[0][0]
	var shop_id: String = run.available_nodes()[0]
	run.map.nodes[shop_id].kind = "shop"
	run.fish = 40
	run.enter(shop_id)
	check(run.phase == "shop" and run.shop_stock.size() >= 5, "the owner's room has cards and services")
	var card_index := -1
	for i in run.shop_stock.size():
		if run.shop_stock[i].type == "card": card_index = i
	var price: int = run.shop_stock[card_index].price
	check(run.shop_buy(card_index) and run.fish == 40 - price and run.build.cards.has(run.shop_stock[card_index].id), "buying a card spends fish")
	check(not run.shop_buy(card_index), "a sold item cannot be bought again")
	run.fish = 0
	for i in run.shop_stock.size(): check(not run.shop_can_buy(i), "nothing is affordable without fish")
	run.leave_node()
	check(run.phase == "map", "leaving the shop returns to the map")
	var seen := {}
	for seed_value in 60:
		var event_run = Run.new()
		event_run.begin({"seed": seed_value, "region": "belltower", "habit": "roam"})
		event_run.at = event_run.map.rows[0][0]
		var moon_id: String = event_run.available_nodes()[0]
		event_run.map.nodes[moon_id].kind = "moon"
		event_run.enter(moon_id)
		seen[event_run.event_id] = true
		var entry: Dictionary = event_run.data.event(event_run.event_id)
		check(entry.regions.is_empty() or "belltower" in entry.regions, "belltower only shows its own and shared events")
		var chosen := -1
		for i in entry.options.size():
			if event_run.option_ok(entry.options[i]):
				chosen = i
				break
		check(chosen >= 0 and event_run.choose_event(chosen), "an event always has an available choice")
		check(event_run.phase in ["map", "card", "upgrade_pick", "item", "supply"], "event choices lead somewhere valid")
	check(not seen.has("M07") and not seen.has("M08"), "greenhouse events stay in the greenhouse")
	var paid = Run.new()
	paid.begin({"seed": 1, "region": "courtyard", "habit": "roam"})
	paid.phase = "moon"
	paid.event_id = "M03"
	paid.fish = 5
	check(not paid.option_ok(paid.data.event("M03").options[0]) and not paid.choose_event(0), "events check costs before allowing a choice")
	paid.event_id = "M06"
	paid.choose_event(1)
	check(paid.next_mods.get("full_meter", 0) == 1, "event effects can change the next battle")


func _fresh_path(tag: String) -> String:
	return "user://x1-test-%s-%d" % [tag, Time.get_ticks_usec()]


func profile_tests() -> void:
	var data = Data.shared()
	var path := _fresh_path("profile")
	var profile = Profile.new(path + ".save", path + ".r1", path + ".old")
	check(not profile.load_failed and profile.data.owned == ["U01", "U02"], "a new profile starts with the two starter charms")
	check(profile.region_unlocked("courtyard") and not profile.region_unlocked("greenhouse"), "only the courtyard is open at first")
	check(profile.max_night("courtyard") == 0, "night levels open one at a time")
	check(profile.set_equip("charm", "U01") and Profile.new(path + ".save").data.equip.charm == "U01", "equipment choice is saved")
	check(not profile.set_equip("habit", "H01"), "cannot equip an item you do not own")
	check(profile.set_target("H05") and profile.data.target == "H05", "a chest item can be the hunt target")
	check(profile.acquire_item("H05", {"phase": "map"}) and profile.owned("H05") and profile.data.target == "", "acquiring the target saves it and clears the target")
	var report: Dictionary = profile.finish_run({"region": "courtyard", "habit": "shadow", "night": 0, "won": true, "practice": false,
		"metrics": {"kills": 600, "ult_uses": 6, "prey_kills": 16}, "time": 500.0})
	check(report.saved and "CL05" in report.unlocked and "SH06" in report.unlocked and "HU06" in report.unlocked and "CL08" in report.unlocked,
		"finishing a run applies counters and win unlocks")
	check(profile.region_unlocked("greenhouse") and profile.max_night("courtyard") == 1, "a win opens the next region and night")
	check(report.near.size() == 3, "the result shows the three nearest goals")
	var again: Dictionary = profile.finish_run({"region": "courtyard", "habit": "roam", "night": 0, "won": false, "practice": false, "metrics": {}})
	check("CL07" in again.unlocked, "two finished runs unlock 撕裂")
	var practice_report: Dictionary = profile.finish_run({"region": "courtyard", "habit": "roam", "night": 0, "won": true, "practice": true, "metrics": {"kills": 9999}})
	check(practice_report.unlocked.is_empty() and int(profile.data.progress.kills) == 600, "practice never counts toward unlocks")
	var reloaded = Profile.new(path + ".save")
	check(reloaded.data == profile.data, "the profile reloads exactly")
	# Corruption: main file damaged, backup used.
	var file := FileAccess.open(path + ".save", FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	var recovered = Profile.new(path + ".save")
	check(not recovered.load_failed and recovered.notice.contains("復原"), "a damaged save recovers from the backup")
	var both := _fresh_path("both")
	for suffix: String in [".save", ".save.bak"]:
		var bad := FileAccess.open(both + suffix, FileAccess.WRITE)
		bad.store_string("broken")
		bad.close()
	var failed = Profile.new(both + ".save")
	check(failed.load_failed and not failed.set_setting("volume", 0.1), "when both copies are damaged nothing is overwritten")
	check(FileAccess.get_file_as_string(both + ".save") == "broken", "the damaged original is kept")
	# Migration from v0.20.
	var old := _fresh_path("legacy")
	var legacy = LegacyProfile.new(old + ".save", old + ".old")
	var legacy_data: Dictionary = legacy.data.duplicate(true)
	legacy_data.owned.append("H03")
	legacy_data.owned.append("H05")
	check(legacy.commit(legacy_data), "test v0.20 save written")
	var migrated = Profile.new(_fresh_path("migrated") + ".save", old + ".save", old + ".old")
	check(migrated.owned("H03") and migrated.owned("H05") and migrated.data.bell_given, "v0.20 treasures carry over to X1")
	check(FileAccess.file_exists(old + ".save"), "the v0.20 save is left in place")
	check(Progress.nearest(data, migrated.data, 30).size() == 30, "all 30 goals are listed while locked")


## Restoring a snapshot mid-battle continues exactly like the uninterrupted run.
func snapshot_tests() -> void:
	var run = Run.new()
	run.begin({"seed": 77, "region": "greenhouse", "habit": "hunt", "unlocked": ["HU05", "BI05"]})
	run.enter(run.available_nodes()[0])
	var bot_a = Bot.new()
	for i in 60 * 22:
		if run.needs_level_choice():
			run.choose_card(bot_a.pick_card(run))
			continue
		run.tick(1.0 / 60.0, bot_a.battle_input(run.battle, 1.0 / 60.0))
		run.battle.take_events()
	check(run.phase == "battle" and run.battle.enemies.size() > 5, "snapshot taken mid-battle")
	var saved: Dictionary = bytes_to_var(var_to_bytes(run.to_dict()))
	var copy = Run.new()
	check(copy.from_dict(saved), "snapshot restores")
	var bot_b = Bot.new()
	bot_b.pounce_cooldown = bot_a.pounce_cooldown
	for i in 60 * 15:
		for pair in [[run, bot_a], [copy, bot_b]]:
			var r = pair[0]
			if r.phase != "battle": continue
			if r.needs_level_choice():
				r.choose_card(pair[1].pick_card(r))
				continue
			r.tick(1.0 / 60.0, pair[1].battle_input(r.battle, 1.0 / 60.0))
			if r.battle != null: r.battle.take_events()
	var a: Dictionary = run.to_dict()
	var b: Dictionary = copy.to_dict()
	a.erase("run_id")
	b.erase("run_id")
	check(var_to_bytes(a) == var_to_bytes(b), "15 s after restoring, the restored run matches the original exactly")
