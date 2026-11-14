extends RefCounted
## Own each finger until release/cancel, independent of which zone it crosses.

var move_id: int = -1
var aim_id: int = -1
var move_origin := Vector2.ZERO
var aim_origin := Vector2.ZERO
var move_point := Vector2.ZERO
var aim_point := Vector2.ZERO
var radius: float = 72.0


func handle(event: InputEvent, viewport_size: Vector2) -> void:
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if event.index == move_id:
				move_id = -1
			if event.index == aim_id:
				aim_id = -1
		elif event.position.x < viewport_size.x * 0.5 and move_id == -1:
			move_id = event.index
			move_origin = event.position
			move_point = event.position
		elif event.position.x >= viewport_size.x * 0.5 and aim_id == -1:
			aim_id = event.index
			aim_origin = event.position
			aim_point = event.position
	elif event is InputEventScreenDrag:
		if event.index == move_id:
			move_point = event.position
		if event.index == aim_id:
			aim_point = event.position


func movement() -> Vector2:
	if move_id == -1:
		return Vector2.ZERO
	return ((move_point - move_origin) / radius).limit_length()


func aim_direction() -> Vector2:
	if aim_id == -1 or aim_point.distance_to(aim_origin) < 10.0:
		return Vector2.ZERO
	return (aim_point - aim_origin).normalized()


func firing() -> bool:
	return aim_id != -1 and aim_point.distance_to(aim_origin) >= 10.0


func clear() -> void:
	move_id = -1
	aim_id = -1
