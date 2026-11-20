extends RefCounted
## Combines stat effects from habit, items and cards, plus short-lived buffs.

const Data := preload("res://scripts/x1/core/data.gd")

var base: Dictionary = {}
var temp: Array = []   # {stat, amount, remaining, key}


## entries: [{"effects": Array, "level": int}]
func rebuild(entries: Array) -> void:
	base.clear()
	for entry: Dictionary in entries:
		var level: int = int(entry.get("level", 1))
		for effect: Dictionary in entry.get("effects", []):
			if effect.get("type", "") != "stat": continue
			var stat: String = effect.stat
			var value: float = float(Data.lv(effect.value, level))
			match str(Data.STATS.get(stat, "add")):
				"min_set":
					if value > 0.0 and (not base.has(stat) or value < float(base[stat])): base[stat] = value
				"max":
					base[stat] = maxf(float(base.get(stat, 0.0)), value)
				_:
					base[stat] = float(base.get(stat, 0.0)) + value


func value(stat: String) -> float:
	var total: float = float(base.get(stat, 0.0))
	for buff: Dictionary in temp:
		if buff.stat == stat: total += float(buff.amount)
	return total


## A buff with the same key refreshes instead of stacking.
func add_buff(stat: String, amount: float, duration: float, key: String) -> void:
	for buff: Dictionary in temp:
		if buff.key == key:
			buff.amount = amount
			buff.remaining = maxf(float(buff.remaining), duration)
			return
	temp.append({"stat": stat, "amount": amount, "remaining": duration, "key": key})


func tick(delta: float) -> void:
	for i in range(temp.size() - 1, -1, -1):
		temp[i].remaining = float(temp[i].remaining) - delta
		if float(temp[i].remaining) <= 0.0: temp.remove_at(i)


func to_dict() -> Dictionary:
	return {"temp": temp.duplicate(true)}


func from_dict(saved: Dictionary) -> void:
	temp = saved.get("temp", []).duplicate(true)
