extends RefCounted
## The cards held this run: up to 6 slots, levels 1-3, evolutions, offers, rerolls.

const Data := preload("res://scripts/x1/core/data.gd")

var data
var habit := "shadow"
var items: Array = []        # equipped item ids that are active this run
var cards: Dictionary = {}   # id -> level
var order: Array = []        # slot order
var evolved: Array = []
var unlocked: Array = []     # non-starter cards available this run
var offers: Array = []
var last_offers: Array = []
var rerolls := 2


func setup(habit_id: String, item_ids: Array, unlocked_ids: Array) -> void:
	data = Data.shared()
	habit = habit_id
	items.clear()
	for id in item_ids:
		var item: Dictionary = data.items.get(str(id), {})
		if item.is_empty(): continue
		if item.slot == "habit" and item.habit != habit: continue
		items.append(str(id))
	unlocked = unlocked_ids.duplicate()
	cards.clear()
	order.clear()
	evolved.clear()
	offers.clear()
	last_offers.clear()
	rerolls = int(data.tuning.build.rerolls) + int(_item_stat("rerolls"))


func _item_stat(stat: String) -> float:
	var total := 0.0
	for id: String in items:
		for effect: Dictionary in data.items[id].get("effects", []):
			if effect.get("type", "") == "stat" and effect.stat == stat: total += float(Data.lv(effect.value, 1))
	return total


## Effect bundles for stats and triggers: habit, items, then cards in slot order.
func entries() -> Array:
	var result: Array = [{"id": "habit:" + habit, "effects": data.habits[habit].effects, "level": 1}]
	for id: String in items:
		result.append({"id": "item:" + id, "effects": data.items[id].get("effects", []), "level": 1})
	for id: String in order:
		result.append({"id": id, "effects": data.cards[id].get("effects", []), "level": int(cards[id])})
	return result


func max_level(id: String) -> int:
	return 1 if id.begins_with("EV") else int(data.tuning.build.max_level)


func slots_free() -> int:
	return int(data.tuning.build.slots) - order.size()


func available(id: String) -> bool:
	var card: Dictionary = data.cards.get(id, {})
	if card.is_empty() or id.begins_with("EV"): return false
	return bool(card.get("starter", false)) or id in unlocked


func can_add(id: String) -> bool:
	return available(id) and not cards.has(id) and slots_free() > 0 and not _replaced_by_evolution(id)


func _replaced_by_evolution(id: String) -> bool:
	for evo_id: String in evolved:
		if str(data.cards[evo_id].requires[0]) == id: return true
	return false


func can_upgrade(id: String) -> bool:
	return cards.has(id) and int(cards[id]) < max_level(id)


func upgradable() -> Array:
	var result: Array = []
	for id: String in order:
		if can_upgrade(id): result.append(id)
	return result


## An evolution needs its first card at max level and its second card held at any level.
func eligible_evolutions() -> Array:
	var result: Array = []
	for evo: Dictionary in data.evolutions:
		if evo.id in evolved: continue
		var first: String = str(evo.requires[0])
		var second: String = str(evo.requires[1])
		if cards.has(first) and int(cards[first]) >= max_level(first) and cards.has(second): result.append(str(evo.id))
	return result


## mode: "level" (normal), "rare" (rare new cards first), "any" (new or upgrade, no evolution)
func make_offers(rng: RandomNumberGenerator, mode := "level") -> Array:
	offers.clear()
	var count: int = int(data.tuning.build.offer_count)
	if mode in ["level", "rare"]:
		var evos := eligible_evolutions()
		if not evos.is_empty(): offers.append(evos[rng.randi_range(0, evos.size() - 1)])
	var pool := _pool(mode)
	if mode == "rare":
		var rare := {}
		for id in pool:
			if not cards.has(id) and data.cards[id].rarity == "rare": rare[id] = pool[id]
		if rare.size() >= 1: pool = rare
	_draw(rng, pool, count, last_offers)
	if offers.size() < count: _draw(rng, _pool(mode), count, [])
	last_offers = offers.duplicate()
	return offers


func _pool(_mode: String) -> Dictionary:
	var pool := {}
	var weights: Dictionary = data.tuning.build.rarity_weight
	var bias: Array = data.habits[habit].get("bias", [])
	for id: String in order:
		if can_upgrade(id): pool[id] = 12.0
	for card: Dictionary in data.card_list:
		var id: String = card.id
		if not can_add(id): continue
		var weight: float = float(weights.get(card.rarity, 5))
		if card.category in bias: weight *= float(data.tuning.build.habit_bias)
		pool[id] = weight
	return pool


func _draw(rng: RandomNumberGenerator, pool: Dictionary, count: int, avoid: Array) -> void:
	var keys: Array = pool.keys()
	keys.sort()
	while offers.size() < count:
		var total := 0.0
		for id in keys:
			if id in offers or id in avoid: continue
			total += float(pool[id])
		if total <= 0.0: return
		var roll := rng.randf() * total
		for id in keys:
			if id in offers or id in avoid: continue
			roll -= float(pool[id])
			if roll <= 0.0:
				offers.append(id)
				break


func reroll(rng: RandomNumberGenerator, mode := "level") -> bool:
	if rerolls <= 0: return false
	rerolls -= 1
	make_offers(rng, mode)
	return true


## Take a card from the offers (or force=true for shop/bed/event grants).
func take(id: String, force := false) -> bool:
	if not force and id not in offers: return false
	if id.begins_with("EV"):
		if id not in eligible_evolutions(): return false
		var evo: Dictionary = data.cards[id]
		var first: String = str(evo.requires[0])
		var index: int = order.find(first)
		order[index] = id
		cards.erase(first)
		cards[id] = 1
		evolved.append(id)
	elif cards.has(id):
		if not can_upgrade(id): return false
		cards[id] = int(cards[id]) + 1
	else:
		if not can_add(id): return false
		cards[id] = 1
		order.append(id)
	offers.clear()
	return true


func upgrade(id: String) -> bool:
	if not can_upgrade(id): return false
	cards[id] = int(cards[id]) + 1
	return true


func upgrade_random(rng: RandomNumberGenerator, count: int) -> Array:
	var done: Array = []
	for i in count:
		var options := upgradable()
		if options.is_empty(): break
		var id: String = options[rng.randi_range(0, options.size() - 1)]
		upgrade(id)
		done.append(id)
	return done


func remove(id: String) -> bool:
	if not cards.has(id): return false
	cards.erase(id)
	order.erase(id)
	evolved.erase(id)
	return true


func random_new(rng: RandomNumberGenerator) -> String:
	var options: Array = []
	for card: Dictionary in data.card_list:
		if can_add(card.id): options.append(card.id)
	if options.is_empty(): return ""
	var id: String = options[rng.randi_range(0, options.size() - 1)]
	take(id, true)
	return id


func to_dict() -> Dictionary:
	return {"habit": habit, "items": items.duplicate(), "cards": cards.duplicate(), "order": order.duplicate(),
		"evolved": evolved.duplicate(), "unlocked": unlocked.duplicate(), "offers": offers.duplicate(),
		"last_offers": last_offers.duplicate(), "rerolls": rerolls}


func from_dict(saved: Dictionary) -> void:
	data = Data.shared()
	habit = saved.habit
	items = saved.items.duplicate()
	cards = saved.cards.duplicate()
	order = saved.order.duplicate()
	evolved = saved.evolved.duplicate()
	unlocked = saved.unlocked.duplicate()
	offers = saved.offers.duplicate()
	last_offers = saved.last_offers.duplicate()
	rerolls = int(saved.rerolls)
