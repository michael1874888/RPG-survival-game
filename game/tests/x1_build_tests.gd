extends SceneTree
## X1 cards: offers, slots and levels, evolutions, rerolls, unlock gating, determinism,
## and one controlled scenario per card showing each of its effects actually happens.

const H := preload("res://tests/x1_helpers.gd")
const Data := preload("res://scripts/x1/core/data.gd")
const Build := preload("res://scripts/x1/core/build.gd")
const Run := preload("res://scripts/x1/core/run.gd")
const Bot := preload("res://tests/x1_bot.gd")

var checks := 0
var failures := 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	offer_tests()
	evolution_tests()
	determinism_tests()
	card_effect_tests()
	chain_tests()
	print("X1 BUILD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func offer_tests() -> void:
	var data = Data.shared()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var build = Build.new()
	build.setup("shadow", [], [])
	var all_legal := true
	var all_distinct := true
	var saw_locked := false
	for i in 400:
		var offers: Array = build.make_offers(rng)
		var seen := {}
		for id in offers:
			if seen.has(id): all_distinct = false
			seen[id] = true
			if not (build.can_add(id) or build.can_upgrade(id) or id in build.eligible_evolutions()): all_legal = false
			if not id.begins_with("EV") and not data.cards[id].starter: saw_locked = true
		var legal: int = build.upgradable().size() + build.eligible_evolutions().size()
		for card: Dictionary in data.card_list:
			if build.can_add(card.id): legal += 1
		if offers.size() != mini(3, legal): all_legal = false
		if i % 2 == 0 and not offers.is_empty(): build.take(offers[0])
		if build.order.size() >= 6 and build.upgradable().is_empty() and build.eligible_evolutions().is_empty(): break
	check(all_legal, "offers are always 3 legal choices while choices remain")
	check(all_distinct, "offers never repeat a card")
	check(not saw_locked, "locked cards never appear")
	check(build.order.size() <= 6, "never more than 6 cards")
	for id: String in build.cards: check(int(build.cards[id]) <= build.max_level(id), "%s stays within its level cap" % id)
	var bias = Build.new()
	bias.setup("shadow", [], [])
	var counts := {}
	for i in 600:
		for id in bias.make_offers(rng): counts[data.cards[id].category] = int(counts.get(data.cards[id].category, 0)) + 1
	check(int(counts.get("shadow", 0)) > int(counts.get("bite", 0)), "habit categories appear more often")
	var unlocked = Build.new()
	unlocked.setup("hunt", [], ["HU05"])
	var saw := false
	for i in 300:
		if "HU05" in unlocked.make_offers(rng): saw = true
	check(saw, "unlocked cards join the pool")
	var reroll = Build.new()
	reroll.setup("roam", ["U06"], [])
	check(reroll.rerolls == 3, "記事結繩 adds a reroll")
	reroll.make_offers(rng)
	var before: Array = reroll.offers.duplicate()
	check(reroll.reroll(rng) and reroll.rerolls == 2 and reroll.offers != before, "reroll spends one and changes the offers")
	var habit_item = Build.new()
	habit_item.setup("roam", ["H01", "U02"], [])
	check(habit_item.items == ["U02"], "a habit item for another habit does nothing")


func evolution_tests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var build = Build.new()
	build.setup("roam", [], [])
	build.take("PO04", true)
	build.take("PO04", true)
	build.take("PO01", true)
	check(build.eligible_evolutions().is_empty(), "no evolution before the first card is maxed")
	build.take("PO04", true)
	check(build.eligible_evolutions() == ["EV02"], "first card maxed and second held unlocks 夜行連撲")
	var offers: Array = build.make_offers(rng)
	check(offers.size() == 3 and offers[0] == "EV02", "eligible evolution is always offered first")
	check(build.take("EV02"), "evolution can be taken")
	check(build.order.find("EV02") == 0 and not build.cards.has("PO04") and build.cards.has("PO01"), "evolution replaces its first card's slot")
	check(build.eligible_evolutions().is_empty(), "an evolution is taken once")


func determinism_tests() -> void:
	var first := _first_offers(1)
	var second := _first_offers(2)
	check(not first.is_empty() and first == second, "card offers depend on the seed, not on movement")


func _first_offers(style: int) -> Array:
	var run = Run.new()
	run.begin({"seed": 99, "region": "courtyard", "habit": "shadow"})
	run.enter(run.available_nodes()[0])
	var bot = Bot.new()
	for i in 60 * 120:
		if run.needs_level_choice(): return run.build.offers.duplicate()
		var input: Dictionary = bot.battle_input(run.battle, 1.0 / 60.0)
		if style == 2: input.move = -Vector2(input.move).rotated(0.7)
		run.tick(1.0 / 60.0, input)
		if run.battle != null: run.battle.take_events()
	return []


## Every trigger of every card and evolution fires in a controlled fight; stats add up.
func card_effect_tests() -> void:
	var data = Data.shared()
	for card: Dictionary in data.card_list + data.evolutions:
		var id: String = card.id
		var cards := {}
		if id.begins_with("EV"):
			cards[str(card.requires[0])] = 3
			cards[str(card.requires[1])] = 3
			cards.erase(str(card.requires[0]))
		var marks_itself := false
		for effect: Dictionary in card.effects:
			if effect.get("action", "") == "mark": marks_itself = true
		if not marks_itself: cards["HU01"] = 1
		cards[id] = 1 if id.begins_with("EV") else 3
		var b = H.battle("shadow", cards)
		var tanks: Array = []
		for k in 2: tanks.append(H.enemy(b, "E05", b.player.pos + Vector2(170, 0).rotated(PI * k), 100000.0))
		for step in 60 * 10:
			var t: float = step / 60.0
			if step % 45 == 0:
				for k in 5: H.enemy(b, "E01", b.player.pos + Vector2(95, 0).rotated(TAU * k / 5.0 + t), 4.0)
			if step % 120 == 30: H.enemy(b, "E04", b.player.pos + Vector2(120, 0).rotated(t), 6.0, {"prey": true})
			if step == 150: b.add_meter(100.0)
			b.player.invuln = 1.0
			b.player.hp = minf(b.player.hp, 50.0)
			var input := {"move": Vector2.RIGHT.rotated(t * 1.3), "ult": step == 151}
			if step % 70 == 10:
				var nearest: Dictionary = b.nearest_enemy(b.player.pos, 400.0, [])
				input.pounce = (nearest.pos - b.player.pos).normalized() if not nearest.is_empty() else Vector2.RIGHT
			b.step(1.0 / 60.0, input)
			b.take_events()
			for tank: Dictionary in tanks:
				if tank.pos.distance_to(b.player.pos) > 260.0: tank.pos = b.player.pos + (tank.pos - b.player.pos).normalized() * 150.0
		var effects: Array = card.effects
		for i in effects.size():
			var effect: Dictionary = effects[i]
			if effect.type == "trigger":
				var state: Dictionary = b.effects.runtime.get("%s#%d" % [id, i], {})
				check(int(state.get("used", 0)) > 0, "%s %s: trigger on %s fired" % [id, card.name, effect.hook])
			elif effect.type == "stat":
				var expected: float = float(Data.lv(effect.value, int(cards[id])))
				check(float(b.stats.base.get(effect.stat, 0.0)) >= expected - 0.001 or Data.STATS[effect.stat] == "min_set",
					"%s %s: stat %s applied" % [id, card.name, effect.stat])


## Many triggers at once still finish quickly and stay within the attack limits.
func chain_tests() -> void:
	var data = Data.shared()
	var cards := {}
	for evo: Dictionary in data.evolutions: cards[evo.id] = 1
	for id: String in ["CL05", "SH01", "SH08", "PO07", "BI06"]: cards[id] = 3
	var b = H.battle("shadow", cards)
	var start := Time.get_ticks_msec()
	var most_balls := 0
	for step in 60 * 10:
		if step % 30 == 0:
			for k in 10: H.enemy(b, "E01", b.player.pos + Vector2(110, 0).rotated(TAU * k / 10.0), 5.0)
		b.player.invuln = 1.0
		b.step(1.0 / 60.0, {"move": Vector2.RIGHT.rotated(step * 0.02), "pounce": Vector2.UP if step % 50 == 0 else Vector2.ZERO})
		b.take_events()
		most_balls = maxi(most_balls, b.balls.size())
	check(Time.get_ticks_msec() - start < 20000, "a full evolution build runs without runaway chains")
	check(most_balls <= int(data.tuning.effects.max_balls) and b.lines.size() <= int(data.tuning.effects.max_lines) + 40, "projectiles stay within caps")
	check(int(b.metrics.kills) > 50, "the chain build actually kills (%d)" % b.metrics.kills)
