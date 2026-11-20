extends RefCounted
## Independent random streams so movement never changes future cards, loot or maps.

const NAMES := ["map", "spawn", "combat", "cards", "loot", "events"]

var streams: Dictionary = {}


func setup(seed_value: int) -> void:
	streams.clear()
	for i in NAMES.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [seed_value, NAMES[i]])
		streams[NAMES[i]] = rng


func get_rng(name: String) -> RandomNumberGenerator:
	return streams[name]


func to_dict() -> Dictionary:
	var result := {}
	for name: String in streams:
		var rng: RandomNumberGenerator = streams[name]
		result[name] = {"seed": rng.seed, "state": rng.state}
	return result


func from_dict(saved: Dictionary) -> void:
	streams.clear()
	for name: String in NAMES:
		var rng := RandomNumberGenerator.new()
		var entry: Dictionary = saved.get(name, {})
		rng.seed = int(entry.get("seed", 0))
		rng.state = int(entry.get("state", rng.state))
		streams[name] = rng


## Weighted pick from {id: weight}; deterministic order by sorted keys.
static func weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var keys: Array = weights.keys()
	keys.sort()
	var total := 0.0
	for key in keys: total += maxf(0.0, float(weights[key]))
	if total <= 0.0: return "" if keys.is_empty() else str(keys[0])
	var roll := rng.randf() * total
	for key in keys:
		roll -= maxf(0.0, float(weights[key]))
		if roll <= 0.0: return str(key)
	return str(keys[-1])
