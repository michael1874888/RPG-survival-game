extends SceneTree
## Every X1 data file parses and every cross-reference resolves.

const Data := preload("res://scripts/x1/core/data.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	var data = Data.reload_data()
	for message: String in data.errors:
		push_error(message)
	check(data.errors.is_empty(), "X1 data has no validation errors (%d found)" % data.errors.size())
	check(data.card_list.size() == 48, "48 normal cards (found %d)" % data.card_list.size())
	check(data.evolutions.size() == 8, "8 evolutions")
	var starters := 0
	var per_category := {}
	for card: Dictionary in data.card_list:
		if card.starter: starters += 1
		per_category[card.category] = int(per_category.get(card.category, 0)) + 1
	check(starters == 24, "24 starter cards (found %d)" % starters)
	for category: String in data.categories:
		check(int(per_category.get(category, 0)) == 8, "category %s has 8 cards" % category)
	check(data.items.size() == 12, "12 items")
	check(data.regions.size() == 3 and data.region_order() == ["courtyard", "greenhouse", "belltower"], "three regions in order")
	check(data.habits.size() == 3, "three habits")
	check(data.unlocks.size() == 30, "30 unlock conditions")
	check(data.events.size() >= 10, "at least 10 moonlight events")
	check(int(data.night.get("max", 0)) == 8 and data.night.levels.size() == 8, "night levels 1-8")
	check(data.night_mods(0).is_empty() and data.night_mods(8).has("fodder_hp_pct"), "night mods accumulate")
	check(data.night_mods(4).get("bed_heal_pct", 0.0) == -10.0, "night 4 reduces bed heal")
	check(Data.lv([1, 2, 3], 2) == 2 and Data.lv(5, 3) == 5 and Data.lv([1, 2], 9) == 2, "level lookup clamps")
	# Warnings must never be shortened: night mods do not touch windups.
	for entry: Dictionary in data.night.levels:
		for key: String in entry.mods:
			check(not key.contains("windup") and not key.contains("warning"), "night %d does not shorten warnings" % entry.level)
	# Every chest item can actually be owned; every unlock item is marked unlock.
	for id: String in data.items:
		check(data.items[id].source in ["starter", "chest", "unlock"], "item %s has a known source" % id)
	print("X1 DATA: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
