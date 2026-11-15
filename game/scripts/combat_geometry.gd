extends RefCounted
## Intersection between a finite sector and a circular collision area.

static func rectangle_circle(origin: Vector2, direction: Vector2, center: Vector2, radius: float, length: float, width: float) -> bool:
	var axis := direction.normalized()
	var offset := center - origin
	var along := offset.dot(axis)
	var across := offset.dot(axis.orthogonal())
	var closest := Vector2(clampf(along, 0.0, length), clampf(across, -width * 0.5, width * 0.5))
	return Vector2(along, across).distance_squared_to(closest) <= radius * radius

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
