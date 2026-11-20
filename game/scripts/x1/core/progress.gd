extends RefCounted
## Cross-run counters, wins and unlock conditions. No permanent stat growth.

const Data := preload("res://scripts/x1/core/data.gd")


static func empty_counters() -> Dictionary:
	var result := {}
	for key: String in Data.COUNTERS: result[key] = 0
	return result


static func is_unlocked(profile: Dictionary, target: String) -> bool:
	return target in profile.get("unlocked", []) or target in profile.get("owned", [])


static func condition_met(condition: Dictionary, profile: Dictionary) -> bool:
	return condition_ratio(condition, profile) >= 1.0


static func condition_ratio(condition: Dictionary, profile: Dictionary) -> float:
	match str(condition.get("type", "")):
		"counter":
			var have: float = float(profile.get("progress", {}).get(str(condition.counter), 0))
			return clampf(have / maxf(1.0, float(condition.value)), 0.0, 1.0)
		"win":
			for win: Dictionary in profile.get("wins", []):
				if condition.has("habit") and win.get("habit", "") != condition.habit: continue
				if condition.has("region") and win.get("region", "") != condition.region: continue
				if condition.has("night") and int(win.get("night", 0)) < int(condition.night): continue
				return 1.0
	return 0.0


## Applies a finished run to a copy of the profile; returns {"profile", "unlocked", "near"}.
static func apply(data, profile: Dictionary, summary: Dictionary) -> Dictionary:
	var next := profile.duplicate(true)
	var counters: Dictionary = next.progress
	if not summary.get("practice", false):
		var metrics: Dictionary = summary.get("metrics", {})
		for key: String in Data.COUNTERS:
			if metrics.has(key): counters[key] = int(counters.get(key, 0)) + int(metrics[key])
		counters.runs = int(counters.get("runs", 0)) + 1
		if summary.get("won", false):
			next.wins.append({"region": summary.region, "habit": summary.habit, "night": int(summary.night), "assist": summary.get("assist", false)})
			while next.wins.size() > 200: next.wins.pop_front()
			var best: int = int(next.region_night.get(summary.region, -1))
			next.region_night[summary.region] = maxi(best, int(summary.night))
	var unlocked: Array = []
	for condition: Dictionary in data.unlocks:
		var target: String = condition.unlock
		if is_unlocked(next, target) or not condition_met(condition, next): continue
		if data.items.has(target): next.owned.append(target)
		else: next.unlocked.append(target)
		unlocked.append(target)
	return {"profile": next, "unlocked": unlocked, "near": nearest(data, next, 3)}


## The conditions closest to completion, for "almost there" hints.
static func nearest(data, profile: Dictionary, count: int) -> Array:
	var rows: Array = []
	for condition: Dictionary in data.unlocks:
		if is_unlocked(profile, condition.unlock): continue
		rows.append({"id": condition.id, "unlock": condition.unlock, "desc": condition.desc, "ratio": condition_ratio(condition, profile)})
	rows.sort_custom(func(a, b): return a.ratio > b.ratio or (a.ratio == b.ratio and a.id < b.id))
	return rows.slice(0, count)
