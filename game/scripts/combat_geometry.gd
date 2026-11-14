extends RefCounted
## Intersection between a finite sector and a circular collision area.

static func sector_circle(origin: Vector2, direction: Vector2, center: Vector2, radius: float, reach: float, half_angle: float) -> bool:
	var offset: Vector2 = center - origin
	var distance: float = offset.length()
	if distance > reach + radius:
		return false
	if distance <= radius:
		return true
	var unit: Vector2 = direction.normalized()
	var angle: float = absf(unit.angle_to(offset))
	if angle <= half_angle:
		return distance <= reach + radius
	var edge: Vector2 = unit.rotated(half_angle if unit.cross(offset) >= 0.0 else -half_angle) * reach
	var closest: Vector2 = Geometry2D.get_closest_point_to_segment(offset, Vector2.ZERO, edge)
	return closest.distance_squared_to(offset) <= radius * radius
