extends RefCounted
## Nana's procedural rig: breathing, tail and ear motion, running bob and lean, paw swipes,
## pounce squash -> stretch -> landing squash, bite mouth, hurt flinch, night-shadow aura.

const Looks := preload("res://scripts/x1/present/looks.gd")

const INK := Color(0.07, 0.05, 0.1)

var t := 0.0
var facing := Vector2.RIGHT
var speed := 0.0
var last_pos := Vector2.ZERO
var run_phase := 0.0
var lean := 0.0
var squash := Vector2.ONE       # current scale along the stretch axis (x) and across (y)
var squash_dir := Vector2.RIGHT
var squash_vel := Vector2.ZERO
var paw_t := 0.0
var paw_dir := Vector2.RIGHT
var paw_side := 1.0
var mouth_t := 0.0
var hurt_t := 0.0
var blink_t := 2.0
var ear_t := 0.0
var dashing := false
var dash_dir := Vector2.RIGHT
var ult := false
var ult_ready := false
var invuln := false


func on_event(kind: String, ev: Dictionary) -> void:
	match kind:
		"swipe":
			if int(ev.get("depth", 0)) == 0:
				paw_t = 1.0
				paw_dir = Vector2(ev.dir)
				paw_side = -paw_side
		"pounce":
			_impulse(Vector2(ev.dir), Vector2(0.72, 1.28))
		"land":
			_impulse(Vector2(ev.dir), Vector2(0.7, 1.32))
		"bite":
			mouth_t = 1.0
		"hurt":
			hurt_t = 1.0
			_impulse(Vector2.RIGHT, Vector2(1.18, 0.84))


func _impulse(dir: Vector2, scale_xy: Vector2) -> void:
	squash_dir = dir if dir.length_squared() > 0.01 else Vector2.RIGHT
	squash = scale_xy


func update(dt: float, pos: Vector2, b) -> void:
	t += dt
	var moved: float = pos.distance_to(last_pos) / maxf(dt, 0.0001)
	last_pos = pos
	speed = lerpf(speed, clampf(moved / 260.0, 0.0, 1.6), 1.0 - exp(-12.0 * dt))
	run_phase += dt * (6.0 + speed * 12.0)
	var face: Vector2 = b.player.facing
	facing = facing.slerp(face, 1.0 - exp(-18.0 * dt)) if facing.length_squared() > 0.01 else face
	var move_dir: Vector2 = b.player.move_dir
	lean = lerpf(lean, clampf(move_dir.x, -1.0, 1.0) * 0.12 * minf(1.0, speed), 1.0 - exp(-10.0 * dt))
	dashing = b.dashing()
	if dashing:
		dash_dir = Vector2(b.pounce.dash.dir)
		squash = squash.lerp(Vector2(1.45, 0.72), 1.0 - exp(-30.0 * dt))
		squash_dir = dash_dir
	else:
		# Spring back to 1,1 with a little overshoot.
		var force: Vector2 = (Vector2.ONE - squash) * 260.0 - squash_vel * 16.0
		squash_vel += force * dt
		squash += squash_vel * dt
	paw_t = maxf(0.0, paw_t - dt * 5.5)
	mouth_t = maxf(0.0, mouth_t - dt * 4.0)
	hurt_t = maxf(0.0, hurt_t - dt * 3.0)
	blink_t -= dt
	if blink_t < -0.12: blink_t = randf_range(2.0, 4.5)
	ear_t = maxf(0.0, ear_t - dt * 4.0)
	if randf() < dt * 0.25: ear_t = 1.0
	ult = b.ult_active()
	ult_ready = b.ult_ready()
	invuln = float(b.player.invuln) > 0.0 and not dashing


func draw(c: CanvasItem, pos: Vector2, glow: Texture2D, night: Color) -> void:
	var breathe: float = sin(t * 3.0) * 0.025 * (1.0 - minf(1.0, speed))
	var bob: float = -absf(sin(run_phase)) * 4.0 * minf(1.0, speed)
	c.draw_texture_rect(glow, Rect2(pos + Vector2(-30, 8), Vector2(60, 26)), false, Color(0, 0, 0, 0.4))
	if ult:
		c.draw_texture_rect(glow, Rect2(pos - Vector2.ONE * 70, Vector2.ONE * 140), false, Color(night.r, night.g, night.b, 0.45 + 0.1 * sin(t * 10.0)))
	var axis: float = squash_dir.angle()
	var xf := Transform2D(0.0, pos + Vector2(0, bob)) * Transform2D(axis, Vector2.ZERO) * Transform2D(0.0, squash, 0.0, Vector2.ZERO) * Transform2D(-axis, Vector2.ZERO) * Transform2D(lean, Vector2(1.0, 1.0 + breathe), 0.0, Vector2.ZERO)
	c.draw_set_transform_matrix(xf)
	var blink: bool = invuln and int(t * 18.0) % 2 == 0
	var fur := Color("2a2733") if not blink else Color("8a84a0")
	if ult: fur = fur.lerp(night.darkened(0.4), 0.45)
	if hurt_t > 0.0: fur = fur.lerp(Color(0.9, 0.3, 0.3), hurt_t * 0.6)
	var shine := fur.lightened(0.25)
	# tail
	var tail := PackedVector2Array()
	var back: Vector2 = -facing if absf(facing.x) > 0.2 else Vector2(-1, 0)
	for i in 8:
		var k := i / 7.0
		var sway: float = sin(t * 4.0 - k * 2.5) * 10.0 * k
		tail.append(back * (18.0 + k * 26.0) + Vector2(0, 6.0 - k * 22.0) + back.orthogonal() * sway)
	c.draw_polyline(tail, INK, 10.0, true)
	c.draw_polyline(tail, fur, 6.5, true)
	# body
	_ellipse(c, Vector2(0, 8), 23.0, 17.0, INK)
	_ellipse(c, Vector2(0, 8), 20.5, 14.5, fur)
	_ellipse(c, Vector2(-4, 4), 13.0, 8.0, shine)
	# head
	var head := facing * 7.0 + Vector2(0, -8)
	var ear_lift: float = ear_t * 4.0
	for s: float in [-1.0, 1.0]:
		var base_l: Vector2 = head + Vector2(13.0 * s, -8.0)
		c.draw_colored_polygon(PackedVector2Array([base_l + Vector2(-7.0 * s, 4), head + Vector2(17.0 * s, -30.0 - ear_lift * (1.0 if s > 0 else 0.4)), base_l + Vector2(6.0 * s, 4)]), INK)
		c.draw_colored_polygon(PackedVector2Array([base_l + Vector2(-4.0 * s, 2), head + Vector2(15.5 * s, -25.0 - ear_lift * (1.0 if s > 0 else 0.4)), base_l + Vector2(3.0 * s, 2)]), Color(0.85, 0.55, 0.62))
	Looks.disc(c, head, 18.5, INK)
	Looks.disc(c, head, 16.0, fur)
	Looks.disc(c, head + Vector2(-5, -6), 6.0, shine)
	# face
	var eye_side := facing.orthogonal()
	var eye_col := Color("f2dc8a")
	if ult_ready or ult: eye_col = Color(0.85, 0.75, 1.0)
	for s: float in [-1.0, 1.0]:
		var eye: Vector2 = head + facing * 6.0 + eye_side * 6.5 * s + Vector2(0, -1)
		if blink_t <= 0.0:
			c.draw_line(eye - Vector2(3, 0), eye + Vector2(3, 0), INK, 2.0, true)
		else:
			if ult_ready or ult: c.draw_texture_rect(glow, Rect2(eye - Vector2.ONE * 9, Vector2.ONE * 18), false, Color(0.8, 0.65, 1.0, 0.6))
			Looks.disc(c, eye, 3.6, eye_col)
			Looks.disc(c, eye + facing * 1.2, 1.7, INK)
	var nose: Vector2 = head + facing * 12.0 + Vector2(0, 3)
	if mouth_t > 0.0:
		var open: float = sin(mouth_t * PI) * 7.0
		c.draw_colored_polygon(PackedVector2Array([nose + Vector2(-5, 1), nose + Vector2(5, 1), nose + Vector2(0, 2 + open)]), Color(0.75, 0.2, 0.3))
		c.draw_line(nose + Vector2(-4, 1), nose + Vector2(-2, 4), Color.WHITE, 1.5)
		c.draw_line(nose + Vector2(4, 1), nose + Vector2(2, 4), Color.WHITE, 1.5)
	Looks.disc(c, nose, 2.4, Color("efb0b4"))
	c.draw_set_transform(Vector2.ZERO)
	# paw swipe (world aligned so the arc points at the target)
	if paw_t > 0.0:
		var swing: float = (1.0 - paw_t) * 1.6 - 0.8
		var dir: Vector2 = paw_dir.rotated(swing * paw_side)
		var paw: Vector2 = pos + Vector2(0, bob) + dir * (20.0 + 18.0 * sin((1.0 - paw_t) * PI))
		Looks.disc(c, paw, 7.5, INK)
		Looks.disc(c, paw, 5.5, fur.lightened(0.15))
		for k in 3:
			var claw_dir: Vector2 = dir.rotated((k - 1) * 0.35)
			c.draw_line(paw + claw_dir * 5.0, paw + claw_dir * 11.0, Color(1, 1, 1, paw_t), 2.0, true)


func _ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(points, col)
