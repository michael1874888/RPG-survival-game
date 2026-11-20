extends RefCounted
## Uniform grid over enemy positions for neighbour and area queries.

var cell := 72.0
var buckets: Dictionary = {}


func rebuild(enemies: Array) -> void:
	buckets.clear()
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		if float(e.hp) <= 0.0: continue
		var key := _key(e.pos)
		if buckets.has(key): buckets[key].append(i)
		else: buckets[key] = [i]


func _key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / cell), floori(pos.y / cell))


## Indices of enemies whose cell overlaps the square around pos.
func query(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var low := _key(pos - Vector2.ONE * radius)
	var high := _key(pos + Vector2.ONE * radius)
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var key := Vector2i(x, y)
			if buckets.has(key): result.append_array(buckets[key])
	return result
