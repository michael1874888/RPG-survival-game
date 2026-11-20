extends RefCounted
## Dispatches data-defined triggers ("when <hook>, do <action>") from cards, habits and items.

const Data := preload("res://scripts/x1/core/data.gd")
const Actions := preload("res://scripts/x1/core/effect_actions.gd")

var triggers: Dictionary = {}   # hook -> [{key, effect, level}]
var runtime: Dictionary = {}    # key -> {icd, count, used, timer, distance}


## entries: [{"id": String, "effects": Array, "level": int}]
func rebuild(entries: Array) -> void:
	triggers.clear()
	var keep := {}
	for entry: Dictionary in entries:
		var effects: Array = entry.get("effects", [])
		for i in effects.size():
			var effect: Dictionary = effects[i]
			if effect.get("type", "") != "trigger": continue
			var key := "%s#%d" % [entry.get("id", "?"), i]
			var hook: String = effect.hook
			if not triggers.has(hook): triggers[hook] = []
			triggers[hook].append({"key": key, "effect": effect, "level": int(entry.get("level", 1))})
			keep[key] = true
			if not runtime.has(key):
				runtime[key] = {"icd": 0.0, "count": 0, "used": 0, "timer": 0.0, "distance": 0.0}
	for key in runtime.keys():
		if not keep.has(key): runtime.erase(key)


func has_hook(hook: String) -> bool:
	return triggers.has(hook) and not triggers[hook].is_empty()


func tick(b, delta: float) -> void:
	for key in runtime:
		var state: Dictionary = runtime[key]
		state.icd = maxf(0.0, float(state.icd) - delta)
	for trigger: Dictionary in triggers.get("tick", []):
		var state: Dictionary = runtime[trigger.key]
		state.timer = float(state.timer) + delta
		var interval: float = maxf(0.2, float(Data.lv(trigger.effect.interval, trigger.level)))
		if float(state.timer) >= interval:
			state.timer = float(state.timer) - interval
			_fire_one(b, trigger, {"source": "tick", "depth": 0, "pos": b.player.pos})


func moved(b, distance: float) -> void:
	for trigger: Dictionary in triggers.get("move", []):
		var state: Dictionary = runtime[trigger.key]
		state.distance = float(state.distance) + distance
		var step: float = maxf(20.0, float(Data.lv(trigger.effect.every_distance, trigger.level)))
		var guard := 0
		while float(state.distance) >= step and guard < 3:
			state.distance = float(state.distance) - step
			guard += 1
			_fire_one(b, trigger, {"source": "move", "depth": 0, "pos": b.player.pos})


func fire(b, hook: String, ctx: Dictionary) -> void:
	if int(ctx.get("depth", 0)) >= b.max_depth: return
	for trigger: Dictionary in triggers.get(hook, []):
		_fire_one(b, trigger, ctx)


func _target_ok(b, filter: Dictionary, target) -> bool:
	if filter.is_empty(): return true
	if not target is Dictionary or target.is_empty(): return false
	if filter.get("marked", false) and not bool(target.get("marked", false)): return false
	if filter.get("prey", false) and not b.is_prey(target): return false
	return true


func _fire_one(b, trigger: Dictionary, ctx: Dictionary) -> void:
	var effect: Dictionary = trigger.effect
	var level: int = trigger.level
	var state: Dictionary = runtime[trigger.key]
	if effect.has("sources") and str(ctx.get("source", "")) not in effect.sources: return
	if effect.has("target") and not _target_ok(b, effect.target, ctx.get("target", null)): return
	if float(state.icd) > 0.0: return
	if effect.has("max_per_battle") and int(state.used) >= int(effect.max_per_battle): return
	if effect.has("every"):
		state.count = int(state.count) + 1
		if int(state.count) < int(Data.lv(effect.every, level)): return
		state.count = 0
	if effect.has("chance") and b.rng_combat.randf() >= float(Data.lv(effect.chance, level)): return
	if effect.action == "mark":
		# Habit and card can both grant marking; one bite marks or cashes once.
		if ctx.get("mark_done", false): return
		ctx["mark_done"] = true
	state.icd = float(Data.lv(effect.get("icd", 0.0), level))
	state.used = int(state.used) + 1
	Actions.run(b, str(effect.action), effect.get("params", {}), level, ctx, str(trigger.key))


func reset_battle() -> void:
	for key in runtime:
		runtime[key] = {"icd": 0.0, "count": 0, "used": 0, "timer": 0.0, "distance": 0.0}


func to_dict() -> Dictionary:
	return {"runtime": runtime.duplicate(true)}


func from_dict(saved: Dictionary) -> void:
	var stored: Dictionary = saved.get("runtime", {})
	for key in stored:
		if runtime.has(key): runtime[key] = stored[key].duplicate(true)
