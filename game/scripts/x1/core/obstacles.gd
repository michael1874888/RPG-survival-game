extends RefCounted
## Static rectangles and circles that block the player, enemies and pounces.

const Data := preload("res://scripts/x1/core/data.gd")

var rects: Array = []     # Rect2
var circles: Array = []   # {"center": Vector2, "radius": float}
var world := Vector2(2400, 1600)
var edge := 30.0


func setup(region: Dictionary, world_size: Vector2, edge_margin: float) -> void:
	world = world_size
	edge = edge_margin
	rects.clear()
	circles.clear()
	for obstacle: Dictionary in region.get("obstacles", []):
		if obstacle.has("rect"):
			var r: Array = obstacle.rect
			rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
		elif obstacle.has("circle"):
			var c: Array = obstacle.circle
			circles.append({"center": Vector2(float(c[0]), float(c[1])), "radius": float(c[2])})


## Push a circle out of every obstacle and keep it inside the world.
func resolve(pos: Vector2, radius: float) -> Vector2:
	var result := pos
	for circle: Dictionary in circles:
		var offset: Vector2 = result - circle.center
		var min_distance: float = float(circle.radius) + radius
		var distance := offset.length()
		if distance < min_distance:
			var normal := offset / distance if distance > 0.001 else Vector2.UP
			result = circle.center + normal * min_distance
	for rect: Rect2 in rects:
		var closest := Vector2(clampf(result.x, rect.position.x, rect.end.x), clampf(result.y, rect.position.y, rect.end.y))
		var offset := result - closest
		var distance := offset.length()
		if distance < radius:
			if distance > 0.001:
				result = closest + offset / distance * radius
			else:
				# Centre is inside the rectangle: leave by the nearest side.
				var left := result.x - rect.position.x
				var right := rect.end.x - result.x
				var top := result.y - rect.position.y
				var bottom := rect.end.y - result.y
				var smallest := minf(minf(left, right), minf(top, bottom))
				if smallest == left: result.x = rect.position.x - radius
				elif smallest == right: result.x = rect.end.x + radius
				elif smallest == top: result.y = rect.position.y - radius
				else: result.y = rect.end.y + radius
	var low := Vector2.ONE * (edge + radius * 0.5)
	return result.clamp(low, world - low)


func blocked(pos: Vector2, radius: float) -> bool:
	return resolve(pos, radius).distance_squared_to(pos) > 0.25


func is_empty() -> bool:
	return rects.is_empty() and circles.is_empty()
