extends RefCounted
## One night patrol: map, nodes, level-ups, rewards, shop, events, boss and the result.
## The UI calls these methods; anything permanent (items, records) is saved by the caller.

const Data := preload("res://scripts/x1/core/data.gd")
const Rng := preload("res://scripts/x1/core/rng_streams.gd")
const Build := preload("res://scripts/x1/core/build.gd")
const Battle := preload("res://scripts/x1/core/battle.gd")
const MapGen := preload("res://scripts/x1/core/map_gen.gd")

const TOTALS := ["kills", "claw_kills", "pounce_kills", "shadow_kills", "prey_kills", "elites", "bosses", "bites", "marks",
	"pounces", "escape_pounces", "ult_uses", "roam_charges", "xp", "hits_taken"]

var data
var rngs = Rng.new()
var build = Build.new()
var battle = null
var seed_value := 0
var run_id := ""
var region_id := "courtyard"
var habit := "shadow"
var equip := {"habit": "", "charm": ""}
var night := 0
var assist := false
var practice := false
var tutorial := false
var hitstop := true
var view_size := Vector2(1280, 720)
var map: Dictionary = {}
var at := ""
var visited: Array = []
var phase := "map"     # map, battle, card, bed, upgrade_pick, shop, shop_remove, moon, item, supply, result
var choice_context := ""
var card_mode := "level"
var hp := 100.0
var max_hp_base := 100.0
var level := 1
var xp := 0
var pending_levels := 0
var fish := 0
var node_kind := ""
var node_layer := 0
var next_mods: Dictionary = {}
var battle_mods: Dictionary = {}
var queue: Array = []
var item_choices: Array = []
var supply_choices: Array = []
var shop_stock: Array = []
var event_id := ""
var seen_events: Array = []
var owned_items: Array = []
var target_item := ""
var bell_guarantee := false
var new_items: Array = []
var metrics: Dictionary = {}
var elapsed := 0.0
var battles_won := 0
var won := false
var finished := false
var last_battle: Dictionary = {}
var notice := ""


## params: seed, region, habit, equip {habit, charm}, night, assist, unlocked, owned, target, tutorial, practice, bell_guarantee
func begin(params: Dictionary) -> void:
	data = Data.shared()
	seed_value = int(params.get("seed", 1))
	run_id = "%d-%d" % [seed_value, Time.get_unix_time_from_system()]
	rngs.setup(seed_value)
	region_id = str(params.get("region", "courtyard"))
	habit = str(params.get("habit", "shadow"))
	equip = params.get("equip", {"habit": "", "charm": ""}).duplicate()
	night = int(params.get("night", 0))
	assist = bool(params.get("assist", false))
	practice = bool(params.get("practice", false))
	tutorial = bool(params.get("tutorial", false))
	hitstop = bool(params.get("hitstop", true))
	view_size = params.get("view_size", Vector2(1280, 720))
	owned_items = params.get("owned", []).duplicate()
	target_item = str(params.get("target", ""))
	bell_guarantee = bool(params.get("bell_guarantee", false))
	build.setup(habit, [equip.get("habit", ""), equip.get("charm", "")], params.get("unlocked", []))
	max_hp_base = float(data.tuning.player.hp)
	hp = max_hp()
	level = 1
	xp = 0
	pending_levels = 0
	fish = 0
	metrics = {"shop_buys": 0, "moon_events": 0, "no_hit_battles": 0, "evolutions": 0}
	for key: String in TOTALS: metrics[key] = 0
	map = MapGen.generate(rngs.get_rng("map"), data.tuning.map)
	at = ""
	visited.clear()
	queue.clear()
	new_items.clear()
	seen_events.clear()
	next_mods = {}
	won = false
	finished = false
	elapsed = 0.0
	battles_won = 0
	phase = "map"
	if practice:
		node_kind = "practice"
		node_layer = 3
		_start_battle("practice")


func max_hp() -> float:
	var total: float = max_hp_base
	for entry: Dictionary in build.entries():
		for effect: Dictionary in entry.effects:
			if effect.get("type", "") == "stat" and effect.stat == "max_hp": total += float(Data.lv(effect.value, int(entry.level)))
	return total


func region() -> Dictionary:
	return data.regions[region_id]


# ---- map ----------------------------------------------------------------------------------

func available_nodes() -> Array:
	if phase != "map": return []
	if at.is_empty(): return map.rows[0].duplicate()
	return map.nodes[at].links.duplicate()


func enter(node_id: String) -> bool:
	if node_id not in available_nodes(): return false
	at = node_id
	visited.append(node_id)
	var node: Dictionary = map.nodes[node_id]
	node_kind = node.kind
	node_layer = int(node.layer)
	notice = ""
	match node_kind:
		"hunt", "den", "boss": _start_battle(node_kind)
		"bed": phase = "bed"
		"shop":
			_stock_shop()
			phase = "shop"
		"moon":
			_pick_event()
			phase = "moon"
	return true


func _start_battle(kind: String) -> void:
	battle = Battle.new()
	battle_mods = next_mods.duplicate()
	next_mods = {}
	battle.setup({"region": region_id, "kind": kind, "layer": mini(node_layer, 7), "night": night, "assist": assist,
		"hp": hp, "max_hp_base": max_hp_base, "entries": build.entries(), "next_mods": battle_mods,
		"view_size": view_size, "hitstop": hitstop}, rngs, self)
	phase = "battle"


# ---- battle callbacks ---------------------------------------------------------------------

func wants_choice() -> bool:
	return pending_levels > 0


func gain_xp(amount: int) -> void:
	xp += amount
	var thresholds: Array = data.tuning.xp.thresholds
	while level - 1 < thresholds.size() and xp >= int(thresholds[level - 1]):
		xp -= int(thresholds[level - 1])
		level += 1
		pending_levels += 1


func xp_needed() -> int:
	var thresholds: Array = data.tuning.xp.thresholds
	return int(thresholds[level - 1]) if level - 1 < thresholds.size() else 0


func gain_fish(amount: int) -> void:
	fish += amount


## Advance the battle; returns true when the battle just ended.
func tick(dt: float, input: Dictionary) -> bool:
	if phase != "battle" or battle == null: return false
	if pending_levels > 0:
		if build.offers.is_empty(): _offer_level()
		return false
	battle.step(dt, input)
	elapsed += dt
	if battle.state == "won":
		_battle_won()
		return true
	if battle.state == "lost":
		_battle_lost()
		return true
	return false


func _offer_level() -> void:
	card_mode = "level"
	choice_context = "level"
	build.make_offers(rngs.get_rng("cards"), "level")
	if build.offers.is_empty():
		# Nothing left to learn: the level becomes a small heal.
		pending_levels -= 1
		_heal(float(data.tuning.build.skip_heal))


func needs_level_choice() -> bool:
	return phase == "battle" and pending_levels > 0 and not build.offers.is_empty()


func _merge_metrics(source: Dictionary) -> void:
	for key: String in TOTALS:
		metrics[key] = int(metrics.get(key, 0)) + int(source.get(key, 0))


func _battle_won() -> void:
	hp = float(battle.player.hp)
	last_battle = {"kind": node_kind, "metrics": battle.metrics.duplicate(true), "time": battle.elapsed}
	_merge_metrics(battle.metrics)
	if int(battle.metrics.hits_taken) == 0 and node_kind != "practice": metrics.no_hit_battles = int(metrics.no_hit_battles) + 1
	battles_won += 1
	battle = null
	if practice:
		_finish(true)
		return
	queue.clear()
	match node_kind:
		"hunt":
			fish += int(data.tuning.fish.hunt_clear)
		"den":
			fish += int(data.tuning.fish.den_clear)
			queue.append_array(data.tuning.rewards.den)
		"boss":
			queue.append_array(data.tuning.rewards.boss)
			queue.append("finish")
	if int(battle_mods.get("item_reward", 0)) > 0 and node_kind != "boss": queue.append("item")
	advance_queue()


func _battle_lost() -> void:
	hp = 0.0
	last_battle = {"kind": node_kind, "metrics": battle.metrics.duplicate(true), "time": battle.elapsed}
	_merge_metrics(battle.metrics)
	battle = null
	_finish(false)


func _finish(victory: bool) -> void:
	won = victory and not practice
	finished = true
	phase = "result"
	queue.clear()


## Moves through rewards queued by the last node, then back to the map.
func advance_queue() -> void:
	while not queue.is_empty():
		var step: String = queue.pop_front()
		match step:
			"card_rare":
				card_mode = "rare"
				choice_context = "reward"
				build.make_offers(rngs.get_rng("cards"), "rare")
				if not build.offers.is_empty():
					phase = "card"
					return
			"item":
				if _prepare_items():
					phase = "item"
				else:
					_prepare_supply()
					phase = "supply"
				return
			"finish":
				_finish(true)
				return
	phase = "map"


# ---- card choices -------------------------------------------------------------------------

func choose_card(id: String) -> bool:
	var was_evolution := id.begins_with("EV")
	if not build.take(id): return false
	if was_evolution: metrics.evolutions = int(metrics.evolutions) + 1
	_after_card()
	return true


func skip_card() -> void:
	build.offers.clear()
	_heal(float(data.tuning.build.skip_heal))
	_after_card()


func reroll_cards() -> bool:
	return build.reroll(rngs.get_rng("cards"), card_mode)


func _after_card() -> void:
	match choice_context:
		"level":
			pending_levels -= 1
			if battle != null:
				battle.refresh_build(build.entries())
				if pending_levels > 0: _offer_level()
		_:
			hp = minf(hp, max_hp())
			advance_queue()


func _heal(amount: float) -> void:
	if battle != null: battle.heal(amount)
	else: hp = minf(max_hp(), hp + amount)


# ---- items and supply ---------------------------------------------------------------------

func _prepare_items() -> bool:
	item_choices.clear()
	var pool: Array = []
	for id in region().get("chest_pool", []):
		if str(id) not in owned_items and str(id) not in new_items: pool.append(str(id))
	if pool.is_empty(): return false
	var loot: RandomNumberGenerator = rngs.get_rng("loot")
	if bell_guarantee and "H03" in pool:
		item_choices.append("H03")
		pool.erase("H03")
		bell_guarantee = false
	if not target_item.is_empty() and target_item in pool:
		item_choices.append(target_item)
		pool.erase(target_item)
	while item_choices.size() < 3 and not pool.is_empty():
		item_choices.append(pool.pop_at(loot.randi_range(0, pool.size() - 1)))
	return true


## Call after the profile saved the item successfully.
func confirm_item(id: String) -> bool:
	if phase != "item" or id not in item_choices: return false
	new_items.append(id)
	if target_item == id: target_item = ""
	item_choices.clear()
	advance_queue()
	return true


func skip_item() -> void:
	item_choices.clear()
	advance_queue()


func _prepare_supply() -> void:
	supply_choices.clear()
	if hp < max_hp(): supply_choices.append("heal")
	supply_choices.append("fish")
	if build.rerolls < 4: supply_choices.append("reroll")


func choose_supply(id: String) -> bool:
	if phase != "supply" or id not in supply_choices: return false
	var supply: Dictionary = data.tuning.supply
	match id:
		"heal": hp = minf(max_hp(), hp + float(supply.heal))
		"fish": fish += int(supply.fish)
		"reroll": build.rerolls += int(supply.reroll)
	supply_choices.clear()
	advance_queue()
	return true


# ---- bed -----------------------------------------------------------------------------------

func bed_heal_pct() -> float:
	return maxf(5.0, float(data.tuning.bed.heal_pct) + float(data.night_mods(night).get("bed_heal_pct", 0.0)))


func bed_rest() -> bool:
	if phase != "bed": return false
	hp = minf(max_hp(), hp + max_hp() * bed_heal_pct() / 100.0)
	phase = "map"
	return true


func bed_train() -> bool:
	if phase != "bed" or build.upgradable().is_empty(): return false
	phase = "upgrade_pick"
	choice_context = "bed"
	return true


func pick_upgrade(id: String) -> bool:
	if phase != "upgrade_pick" or not build.upgrade(id): return false
	hp = minf(hp, max_hp())
	phase = "map"
	advance_queue()
	return true


# ---- shop ---------------------------------------------------------------------------------

func _stock_shop() -> void:
	shop_stock.clear()
	var rng: RandomNumberGenerator = rngs.get_rng("loot")
	var prices: Dictionary = data.shop.card_price
	var options: Array = []
	for card: Dictionary in data.card_list:
		if build.can_add(card.id): options.append(card.id)
	for i in int(data.shop.card_offers):
		if options.is_empty(): break
		var id: String = options.pop_at(rng.randi_range(0, options.size() - 1))
		shop_stock.append({"type": "card", "id": id, "price": int(prices.get(data.cards[id].rarity, 12)), "sold": false})
	shop_stock.append({"type": "heal", "price": int(data.shop.heal.price), "sold": false})
	shop_stock.append({"type": "upgrade", "price": int(data.shop.upgrade.price), "sold": false})
	shop_stock.append({"type": "remove", "price": int(data.shop.remove.price), "sold": false})
	shop_stock.append({"type": "reroll", "price": int(data.shop.reroll.price), "sold": false})


func shop_can_buy(index: int) -> bool:
	if phase != "shop" or index < 0 or index >= shop_stock.size(): return false
	var entry: Dictionary = shop_stock[index]
	if entry.sold or fish < int(entry.price): return false
	match str(entry.type):
		"card": return build.can_add(str(entry.id))
		"heal": return hp < max_hp()
		"upgrade": return not build.upgradable().is_empty()
		"remove": return not build.order.is_empty()
	return true


## For "upgrade" and "remove" pass the card id.
func shop_buy(index: int, card_id := "") -> bool:
	if not shop_can_buy(index): return false
	var entry: Dictionary = shop_stock[index]
	match str(entry.type):
		"card":
			if not build.take(str(entry.id), true): return false
		"heal":
			hp = minf(max_hp(), hp + max_hp() * float(data.shop.heal.pct) / 100.0)
		"upgrade":
			if not build.upgrade(card_id): return false
		"remove":
			if not build.remove(card_id): return false
		"reroll":
			build.rerolls += int(data.shop.reroll.amount)
	fish -= int(entry.price)
	entry.sold = true
	metrics.shop_buys = int(metrics.shop_buys) + 1
	hp = minf(hp, max_hp())
	return true


func leave_node() -> void:
	if phase in ["shop", "bed", "moon"]:
		phase = "map"


# ---- moonlight events ------------------------------------------------------------------------

func _pick_event() -> void:
	var options: Array = []
	for entry: Dictionary in data.events:
		var regions: Array = entry.get("regions", [])
		if (regions.is_empty() or region_id in regions) and entry.id not in seen_events: options.append(entry.id)
	if options.is_empty():
		for entry: Dictionary in data.events:
			if entry.get("regions", []).is_empty(): options.append(entry.id)
	event_id = options[rngs.get_rng("events").randi_range(0, options.size() - 1)]
	seen_events.append(event_id)


func option_ok(option: Dictionary) -> bool:
	var needs: Dictionary = option.get("requires", {})
	if needs.has("fish") and fish < int(needs.fish): return false
	if needs.has("hp") and hp <= float(needs.hp): return false
	if needs.has("max_hp") and max_hp() <= float(needs.max_hp): return false
	if needs.has("upgradable") and build.upgradable().is_empty(): return false
	if needs.has("card_room") and build.slots_free() <= 0: return false
	return true


func choose_event(index: int) -> bool:
	if phase != "moon": return false
	var entry: Dictionary = data.event(event_id)
	var options: Array = entry.get("options", [])
	if index < 0 or index >= options.size() or not option_ok(options[index]): return false
	metrics.moon_events = int(metrics.moon_events) + 1
	var follow := ""
	for effect: Dictionary in options[index].get("effects", []):
		match str(effect.type):
			"heal": hp = minf(max_hp(), hp + float(effect.amount))
			"heal_pct": hp = minf(max_hp(), hp + max_hp() * float(effect.amount) / 100.0)
			"damage": hp = maxf(1.0, hp - float(effect.amount))
			"max_hp":
				max_hp_base += float(effect.amount)
				hp = clampf(hp + maxf(0.0, float(effect.amount)), 1.0, max_hp())
			"fish": fish = maxi(0, fish + int(effect.amount))
			"rerolls": build.rerolls += int(effect.amount)
			"upgrade_random":
				var done: Array = build.upgrade_random(rngs.get_rng("cards"), int(effect.get("count", 1)))
				notice = "升級：" + "、".join(done.map(func(id): return data.cards[id].name)) if not done.is_empty() else ""
			"random_card":
				var id: String = build.random_new(rngs.get_rng("cards"))
				if not id.is_empty(): notice = "得到：" + str(data.cards[id].name)
			"next_battle":
				next_mods[str(effect.mod)] = effect.value
			"card_choice":
				follow = "card_rare" if effect.get("rarity", "any") == "rare" else "card_any"
			"upgrade_choice":
				follow = "upgrade"
			"item_choice":
				follow = "item"
	match follow:
		"card_rare", "card_any":
			card_mode = "rare" if follow == "card_rare" else "any"
			choice_context = "event"
			build.make_offers(rngs.get_rng("cards"), card_mode)
			phase = "card" if not build.offers.is_empty() else "map"
		"upgrade":
			phase = "upgrade_pick"
			choice_context = "event"
		"item":
			queue = ["item"]
			advance_queue()
		_:
			phase = "map"
	return true


# ---- summary and snapshot -------------------------------------------------------------------

func summary() -> Dictionary:
	var cards: Array = []
	for id: String in build.order: cards.append({"id": id, "level": int(build.cards[id])})
	var result := {"run_id": run_id, "region": region_id, "habit": habit, "night": night, "won": won, "practice": practice,
		"assist": assist, "layer": node_layer, "battles": battles_won, "time": elapsed, "level": level, "cards": cards,
		"new_items": new_items.duplicate(), "metrics": metrics.duplicate(true), "last_hurt": "", "equip": equip.duplicate()}
	if not last_battle.is_empty(): result.last_hurt = str(last_battle.metrics.get("last_hurt", ""))
	return result


const SAVED := ["seed_value", "run_id", "region_id", "habit", "equip", "night", "assist", "practice", "tutorial", "hitstop",
	"view_size", "map", "at", "visited", "phase", "choice_context", "card_mode", "hp", "max_hp_base", "level", "xp",
	"pending_levels", "fish", "node_kind", "node_layer", "next_mods", "battle_mods", "queue", "item_choices",
	"supply_choices", "shop_stock", "event_id", "seen_events", "owned_items", "target_item", "bell_guarantee",
	"new_items", "metrics", "elapsed", "battles_won", "won", "finished", "last_battle"]


func to_dict() -> Dictionary:
	var result := {"version": 1}
	for key: String in SAVED:
		var value = get(key)
		result[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	result["rngs"] = rngs.to_dict()
	result["build"] = build.to_dict()
	result["battle"] = battle.to_dict() if battle != null else {}
	return result


func from_dict(saved: Dictionary) -> bool:
	data = Data.shared()
	if int(saved.get("version", 0)) != 1: return false
	for key: String in SAVED:
		if not saved.has(key): return false
		var value = saved[key]
		set(key, value.duplicate(true) if value is Dictionary or value is Array else value)
	rngs.from_dict(saved.rngs)
	build.from_dict(saved.build)
	battle = null
	if not saved.battle.is_empty():
		battle = Battle.new()
		battle.from_dict(saved.battle, rngs, build.entries(), self)
	return true
