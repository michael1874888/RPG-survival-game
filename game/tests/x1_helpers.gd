extends RefCounted
## Shared helpers for X1 rule tests: controlled battles with no automatic spawning.

const Battle := preload("res://scripts/x1/core/battle.gd")
const Rng := preload("res://scripts/x1/core/rng_streams.gd")
const Data := preload("res://scripts/x1/core/data.gd")


class Owner:
	var xp := 0
	var fish := 0
	var paused := false
	func wants_choice() -> bool: return paused
	func gain_xp(n: int) -> void: xp += n
	func gain_fish(n: int) -> void: fish += n


static func entries(habit: String, cards: Dictionary = {}, items: Array = []) -> Array:
	var data = Data.shared()
	var result: Array = [{"id": "habit:" + habit, "effects": data.habits[habit].effects, "level": 1}]
	for id: String in items: result.append({"id": "item:" + id, "effects": data.items[id].effects, "level": 1})
	for id: String in cards: result.append({"id": id, "effects": data.cards[id].effects, "level": int(cards[id])})
	return result


## A battle in the given region with spawning off and the player at `at`.
static func battle(habit := "roam", cards: Dictionary = {}, region := "courtyard", at := Vector2(1200, 800), kind := "hunt", night := 0, seed_value := 7):
	var rngs = Rng.new()
	rngs.setup(seed_value)
	var b = Battle.new()
	b.setup({"region": region, "kind": kind, "layer": 1, "night": night, "entries": entries(habit, cards)}, rngs, Owner.new())
	b.spawning = false
	b.player.pos = at
	return b


static func enemy(b, kind: String, pos: Vector2, hp := -1.0, opts: Dictionary = {}) -> Dictionary:
	var e: Dictionary = b.spawn_enemy(kind, pos, opts)
	if hp > 0.0:
		e.hp = hp
		e.max_hp = hp
	e.visible_time = 5.0
	return e


static func run_for(b, seconds: float, input: Dictionary = {}) -> void:
	var steps := int(round(seconds * 60.0))
	for i in steps:
		b.step(1.0 / 60.0, input)
		b.take_events()
