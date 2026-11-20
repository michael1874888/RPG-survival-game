extends RefCounted
## Presentation camera: follows Nana with look-ahead, lags behind a pounce and catches up,
## trauma-based shake (optionally directional), landing kick and zoom punch.
## Produces the world transform; never affects the rules.

var settings: Dictionary = {}
var center := Vector2.ZERO
var zoom := 1.0
var zoom_punch := 0.0
var trauma := 0.0
var shake_dir := Vector2.ZERO
var kick := Vector2.ZERO
var time := 0.0
var shake_scale := 1.0      # from the player's settings (0..1)
var motion := true          # false: reduce motion
var crowd := 0.0
var noise := FastNoiseLite.new()
var initialized := false


func setup(feel_camera: Dictionary) -> void:
	settings = feel_camera
	noise.seed = 7
	noise.frequency = 3.0
	initialized = false


func snap(target: Vector2) -> void:
	center = target
	initialized = true


func add_trauma(amount: float, dir := Vector2.ZERO) -> void:
	trauma = minf(1.0, trauma + amount * shake_scale)
	if dir != Vector2.ZERO: shake_dir = dir.normalized()


func add_kick(dir: Vector2, pixels: float) -> void:
	if not motion: return
	kick += dir.normalized() * pixels * shake_scale


func punch(amount: float) -> void:
	if not motion: return
	zoom_punch = maxf(zoom_punch, amount)


## target: Nana's position; lead: look-ahead direction (move or pounce); dashing: lag behind.
func update(dt: float, target: Vector2, lead: Vector2, dashing: bool, crowd_ratio: float) -> void:
	time += dt
	if not initialized: snap(target)
	var ahead: Vector2 = target + lead.limit_length(1.0) * float(settings.get("lookahead", 60.0))
	var smooth: float = float(settings.get("smooth", 7.0)) * (float(settings.get("pounce_lag", 0.55)) if dashing else 1.0)
	center = center.lerp(ahead, 1.0 - exp(-smooth * dt))
	trauma = maxf(0.0, trauma - float(settings.get("trauma_decay", 1.5)) * dt)
	kick = kick.lerp(Vector2.ZERO, 1.0 - exp(-float(settings.get("kick_return", 14.0)) * dt))
	zoom_punch = lerpf(zoom_punch, 0.0, 1.0 - exp(-float(settings.get("zoom_return", 5.0)) * dt))
	crowd = lerpf(crowd, crowd_ratio, 1.0 - exp(-1.5 * dt))
	zoom = 1.0 + zoom_punch - crowd * float(settings.get("crowd_zoom_out", 0.06))


func shake_offset() -> Vector2:
	var power := trauma * trauma
	if power <= 0.0001: return Vector2.ZERO
	var amount: float = float(settings.get("max_shake", 16.0)) * power
	var wobble := Vector2(noise.get_noise_2d(time * 60.0, 0.0), noise.get_noise_2d(0.0, time * 60.0)) * amount
	if shake_dir != Vector2.ZERO: wobble += shake_dir * amount * 0.6 * noise.get_noise_1d(time * 40.0 + 5.0)
	return wobble


func roll() -> float:
	if not motion: return 0.0
	return deg_to_rad(float(settings.get("max_roll_deg", 1.2))) * trauma * trauma * noise.get_noise_1d(time * 50.0 + 11.0)


## The world node transform: world point `center` maps to the middle of the view.
func world_transform(view: Vector2, world: Vector2) -> Transform2D:
	var half := view * 0.5 / zoom
	var clamped := Vector2(clampf(center.x, half.x, maxf(half.x, world.x - half.x)), clampf(center.y, half.y, maxf(half.y, world.y - half.y)))
	var focus := clamped + kick
	var xf := Transform2D(roll(), Vector2.ONE * zoom, 0.0, view * 0.5 + shake_offset())
	return xf * Transform2D(0.0, -focus)


func screen_to_world(view: Vector2, world: Vector2, screen: Vector2) -> Vector2:
	return world_transform(view, world).affine_inverse() * screen


func world_to_screen(view: Vector2, world: Vector2, point: Vector2) -> Vector2:
	return world_transform(view, world) * point
