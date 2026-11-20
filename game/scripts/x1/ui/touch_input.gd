extends RefCounted
## Two-thumb input for X1. Left half moves; right half drags a pounce line and pounces on release.
## Releasing within the deadzone cancels. Each finger keeps its role until it lifts.

var move_id := -1
var aim_id := -1
var move_origin := Vector2.ZERO
var move_point := Vector2.ZERO
var aim_origin := Vector2.ZERO
var aim_point := Vector2.ZERO
var radius := 72.0
var deadzone := 24.0
var pending_pounce := Vector2.ZERO
var cancelled := false


func handle(event: InputEvent, viewport_size: Vector2) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			# A press from a finger we still think is down means its release went elsewhere.
			if event.index == move_id: move_id = -1
			if event.index == aim_id: aim_id = -1
		if not event.pressed or event.canceled:
			if event.index == move_id: move_id = -1
			if event.index == aim_id:
				aim_point = event.position
				var drag := aim_point - aim_origin
				if not event.canceled and drag.length() >= deadzone: pending_pounce = drag.normalized()
				else: cancelled = true
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
		if event.index == move_id: move_point = event.position
		if event.index == aim_id: aim_point = event.position


func movement() -> Vector2:
	if move_id == -1: return Vector2.ZERO
	return ((move_point - move_origin) / radius).limit_length()


func aiming() -> bool:
	return aim_id != -1 and aim_point.distance_to(aim_origin) >= deadzone


func aim_direction() -> Vector2:
	return (aim_point - aim_origin).normalized() if aiming() else Vector2.ZERO


func take_pounce() -> Vector2:
	var result := pending_pounce
	pending_pounce = Vector2.ZERO
	return result


func clear() -> void:
	move_id = -1
	aim_id = -1
	pending_pounce = Vector2.ZERO
