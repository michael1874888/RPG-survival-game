extends RefCounted
## Procedural character art: outlined, two-tone bodies with highlights, per-type silhouettes,
## squash/tilt from hits, wind-up bulge, and the shared markers (prey, mark, opening, shield).

const INK := Color(0.07, 0.05, 0.1)


static func ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, col: Color, n := 22) -> void:
	var points := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(points, col)


## Outlined body with a lighter top and a specular dot, in the current transform.
static func body(c: CanvasItem, r: float, base: Color, rx_scale := 1.0, ry_scale := 1.0) -> void:
	ellipse(c, Vector2.ZERO, r * rx_scale + 2.5, r * ry_scale + 2.5, INK)
	ellipse(c, Vector2.ZERO, r * rx_scale, r * ry_scale, base.darkened(0.18))
	ellipse(c, Vector2(-r * 0.12, -r * 0.18), r * rx_scale * 0.78, r * ry_scale * 0.7, base)
	ellipse(c, Vector2(-r * 0.35, -r * 0.42), r * 0.22, r * 0.14, base.lightened(0.45), 10)


static func eyes(c: CanvasItem, r: float, look: Vector2, col := Color(1, 0.96, 0.85), pupil := INK, size := 1.0) -> void:
	var side := look.orthogonal()
	for s: float in [-1.0, 1.0]:
		var p: Vector2 = look * r * 0.32 + side * r * 0.3 * s + Vector2(0, -r * 0.1)
		c.draw_circle(p, r * 0.17 * size, col)
		c.draw_circle(p + look * r * 0.05, r * 0.09 * size, pupil)


## e: enemy dict (rules data, read only); view: {squash, tilt, flash, spawn, look}; t: clock.
static func enemy(c: CanvasItem, e: Dictionary, pos: Vector2, view: Dictionary, spec: Dictionary, t: float, glow: Texture2D, alpha := 1.0, extra_scale := 1.0) -> void:
	var r: float = float(e.radius)
	var base := Color(str(spec.get("color", "ac9acc")))
	var look: Vector2 = view.get("look", Vector2.RIGHT)
	var squash: float = float(view.get("squash", 0.0))
	var tilt: float = float(view.get("tilt", 0.0))
	var spawn: float = clampf(float(view.get("spawn", 1.0)), 0.0, 1.0)
	var flash: float = maxf(float(view.get("flash", 0.0)), float(e.get("flash", 0.0)) * 8.0)
	var phase: String = str(e.get("phase", ""))
	var windup := phase in ["windup", "windup1", "windup2", "sweep1", "sweep2", "root", "seed", "vine", "ring"]
	var bulge := 0.0
	if windup and not e.get("tele", {}).is_empty():
		var total: float = maxf(0.01, float(e.get("windup_total", 1.0)))
		bulge = clampf(1.0 - float(e.timer) / total, 0.0, 1.0)
	var opening: bool = phase == "recover" and e.role not in ["fodder", "hound"]
	if e.get("fleeing", false): base = base.darkened(0.35)
	if float(e.get("slow_t", 0.0)) > 0.0: base = base.lerp(Color("9deaff"), 0.3)
	if bulge > 0.0: base = base.lerp(Color(1.0, 0.45, 0.35), 0.25 * bulge + 0.15 * (0.5 + 0.5 * sin(t * 30.0)) * bulge)
	if opening: base = base.lerp(Color(0.55, 0.6, 0.75), 0.35)
	if flash > 0.0: base = base.lerp(Color.WHITE, clampf(flash, 0.0, 1.0))
	base.a = alpha
	var bob: float = sin(t * 7.0 + float(e.id)) * (1.5 if e.role in ["fodder", "hound"] else 1.0)
	var scale_xy := Vector2(1.0 + squash * 0.28 + bulge * 0.12, 1.0 - squash * 0.22 + bulge * 0.12) * (0.2 + 0.8 * ease(spawn, 0.4)) * extra_scale
	if opening: scale_xy *= Vector2(1.08, 0.86)
	# soft ground shadow
	c.draw_texture_rect(glow, Rect2(pos + Vector2(-r * 1.2, r * 0.25), Vector2(r * 2.4, r * 1.2)), false, Color(0, 0, 0, 0.32 * alpha))
	c.draw_set_transform(pos + Vector2(0, bob), tilt, scale_xy)
	match str(e.ai):
		"chaser":
			if e.role == "hound":
				for s: float in [-1.0, 1.0]:
					c.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.25 * s, -r * 0.6), Vector2(r * 0.85 * s, -r * 1.35), Vector2(r * 0.75 * s, -r * 0.3)]), INK)
					c.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.33 * s, -r * 0.6), Vector2(r * 0.75 * s, -r * 1.15), Vector2(r * 0.68 * s, -r * 0.4)]), base.darkened(0.3))
				body(c, r, base, 1.08, 0.94)
				eyes(c, r, look, Color(1.0, 0.45, 0.4), INK)
			else:
				for k in 3:
					var x: float = (k - 1) * r * 0.5
					ellipse(c, Vector2(x, r * 0.75 + sin(t * 9.0 + k + float(e.id)) * 2.0), r * 0.22, r * 0.3, base.darkened(0.3), 10)
				body(c, r, base)
				eyes(c, r, look)
		"charger":
			body(c, r, base, 1.05, 1.0)
			var horn: Vector2 = look
			c.draw_colored_polygon(PackedVector2Array([horn * r * 0.6 + horn.orthogonal() * r * 0.35, horn * r * 1.55, horn * r * 0.6 - horn.orthogonal() * r * 0.35]), Color(0.95, 0.85, 0.65, alpha))
			eyes(c, r, look, Color(1.0, 0.9, 0.5))
		"thrower":
			body(c, r, base)
			var hand: Vector2 = look.orthogonal() * r * 0.9 + Vector2(0, -r * 0.7)
			c.draw_line(Vector2.ZERO, hand, INK, 4.0, true)
			c.draw_circle(hand, r * 0.38 + bulge * 4.0, Color(1.0, 0.6, 0.5, alpha))
			c.draw_circle(hand, r * 0.22, Color(1.0, 0.85, 0.75, alpha))
			eyes(c, r, look)
		"guard", "warden":
			if e.ai == "warden":
				for k in 8:
					var a := TAU * k / 8.0 + t * 0.3
					c.draw_colored_polygon(PackedVector2Array([Vector2.RIGHT.rotated(a - 0.18) * r * 0.9, Vector2.RIGHT.rotated(a) * r * 1.35, Vector2.RIGHT.rotated(a + 0.18) * r * 0.9]), INK)
			body(c, r, base, 1.05, 1.0)
			var shield: Vector2 = look * r * 0.95
			c.draw_arc(shield - look * r * 0.4, r * 0.85, look.angle() - 1.0, look.angle() + 1.0, 14, INK, 9.0, true)
			c.draw_arc(shield - look * r * 0.4, r * 0.85, look.angle() - 0.95, look.angle() + 0.95, 14, Color(0.85, 0.72, 0.55, alpha), 5.0, true)
			eyes(c, r, look, Color(1, 0.9, 0.7), INK, 0.85)
		"trapper":
			body(c, r, base)
			for k in 5:
				var a := -PI * 0.5 + (k - 2) * 0.45
				ellipse(c, Vector2.RIGHT.rotated(a) * r * 0.95, r * 0.28, r * 0.14, Color(0.55, 0.85, 0.4, alpha), 8)
			eyes(c, r, look)
		"caller":
			body(c, r, base)
			c.draw_line(Vector2(0, -r * 0.8), Vector2(0, -r * 1.5), INK, 3.0, true)
			c.draw_circle(Vector2(0, -r * 1.55), r * 0.25 + bulge * 6.0, Color(1.0, 0.75, 0.95, alpha))
			eyes(c, r, look)
		"lantern":
			c.draw_texture_rect(glow, Rect2(-Vector2.ONE * r * 2.4, Vector2.ONE * r * 4.8), false, Color(1.0, 0.92, 0.5, 0.35 * alpha))
			body(c, r * 0.9, base)
			c.draw_circle(Vector2(0, r * 0.1), r * 0.35, Color(1.0, 0.98, 0.8, alpha))
		"stalker":
			for s: float in [-1.0, 1.0]:
				c.draw_colored_polygon(PackedVector2Array([Vector2(r * 0.3 * s, -r * 0.55), Vector2(r * 0.9 * s, -r * 1.45), Vector2(r * 0.8 * s, -r * 0.25)]), INK)
			body(c, r, base, 1.25, 0.9)
			eyes(c, r, look, Color(1.0, 0.35, 0.35), INK)
		"boss_tree":
			for k in 5:
				var a := -PI * 0.5 + (k - 2) * 0.5
				c.draw_line(Vector2.RIGHT.rotated(a) * r * 0.7, Vector2.RIGHT.rotated(a) * r * 1.6, INK, 9.0, true)
				c.draw_line(Vector2.RIGHT.rotated(a) * r * 0.7, Vector2.RIGHT.rotated(a) * r * 1.55, base.darkened(0.2), 5.0, true)
				c.draw_circle(Vector2.RIGHT.rotated(a) * r * 1.6, r * 0.28, Color(0.35, 0.55, 0.32, alpha))
			body(c, r, base, 1.0, 1.1)
			eyes(c, r, look, Color(1.0, 0.8, 0.35), INK, 1.1)
		"boss_vine":
			for k in 7:
				var a := TAU * k / 7.0 + t * 0.4
				ellipse(c, Vector2.RIGHT.rotated(a) * r * 0.95, r * 0.5, r * 0.26, Color(0.95, 0.55, 0.7, alpha).lerp(base, 0.3), 12)
			body(c, r, base)
			eyes(c, r, look, Color(1.0, 0.95, 0.6), INK, 1.1)
		"boss_crow":
			var flap: float = sin(t * (14.0 if e.phase == "swoop" else 5.0))
			for s: float in [-1.0, 1.0]:
				var wing := PackedVector2Array([Vector2(r * 0.4 * s, 0), Vector2(r * 2.1 * s, -r * (0.6 + 0.4 * flap)), Vector2(r * 1.7 * s, r * 0.35), Vector2(r * 0.6 * s, r * 0.5)])
				c.draw_colored_polygon(wing, base.darkened(0.25))
			body(c, r, base, 0.95, 1.05)
			c.draw_colored_polygon(PackedVector2Array([look * r * 0.7 + look.orthogonal() * r * 0.25, look * r * 1.35, look * r * 0.7 - look.orthogonal() * r * 0.25]), Color(1.0, 0.8, 0.3, alpha))
			eyes(c, r, look, Color(1.0, 0.9, 0.4), INK, 0.9)
		_:
			body(c, r, base)
			eyes(c, r, look)
	c.draw_set_transform(Vector2.ZERO)


## Markers drawn above every enemy: prey diamond, hunt mark, opening, health, shield link.
static func markers(c: CanvasItem, e: Dictionary, pos: Vector2, t: float, font: Font, by_id: Dictionary, prey_col: Color, shadow_col: Color) -> void:
	var r: float = float(e.radius)
	if e.get("prey", false):
		var bob: float = sin(t * 5.0) * 3.0
		var top := pos + Vector2(0, -r - 22 + bob)
		c.draw_arc(pos, r + 9.0, 0.0, TAU, 32, Color(prey_col.r, prey_col.g, prey_col.b, 0.85), 3.0, true)
		c.draw_colored_polygon(PackedVector2Array([top + Vector2(0, -9), top + Vector2(7, 0), top + Vector2(0, 9), top + Vector2(-7, 0)]), prey_col)
		c.draw_polyline(PackedVector2Array([top + Vector2(0, -9), top + Vector2(7, 0), top + Vector2(0, 9), top + Vector2(-7, 0), top + Vector2(0, -9)]), INK, 2.0, true)
	if e.role in ["elite", "boss"]:
		c.draw_arc(pos, r + 5.0, 0.0, TAU, 40, Color(prey_col.r, prey_col.g, prey_col.b, 0.6 + 0.3 * sin(t * 4.0)), 3.0, true)
	if e.get("marked", false):
		for k in 3:
			var a := t * 3.0 + TAU * k / 3.0
			c.draw_arc(pos, r + 15.0, a, a + 1.4, 10, shadow_col, 3.5, true)
	var shield: int = int(e.get("shield_by", -1))
	if shield >= 0 and by_id.has(shield):
		var lantern: Dictionary = by_id[shield]
		c.draw_line(pos, lantern.pos, Color(1.0, 0.92, 0.5, 0.45), 2.0, true)
		c.draw_arc(pos, r + 7.0, 0, TAU, 24, Color(1.0, 0.92, 0.5, 0.75), 2.0, true)
	if str(e.get("phase", "")) == "recover" and e.role not in ["fodder", "hound"]:
		c.draw_arc(pos, r + 11.0, 0, TAU, 28, Color(0.6, 0.92, 1.0, 0.8), 2.5, true)
		c.draw_string_outline(font, pos + Vector2(-18, -r - (36 if e.get("prey", false) else 16)), "空檔", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, INK)
		c.draw_string(font, pos + Vector2(-18, -r - (36 if e.get("prey", false) else 16)), "空檔", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.6, 0.92, 1.0))
	if e.role not in ["fodder", "boss"] and float(e.hp) < float(e.max_hp):
		var top: float = -r - 9.0
		c.draw_line(pos + Vector2(-r, top), pos + Vector2(r, top), INK, 5.0)
		c.draw_line(pos + Vector2(-r, top), pos + Vector2(-r + r * 2.0 * float(e.hp) / float(e.max_hp), top), prey_col, 3.0)


static func gem(c: CanvasItem, pos: Vector2, value: int, t: float, glow: Texture2D, col: Color) -> void:
	var s: float = 5.0 + minf(5.0, value * 0.6)
	var bob := sin(t * 5.0 + pos.x * 0.05) * 2.0
	var p := pos + Vector2(0, bob)
	c.draw_texture_rect(glow, Rect2(p - Vector2.ONE * s * 2.2, Vector2.ONE * s * 4.4), false, Color(col.r, col.g, col.b, 0.35))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.75, 0), p + Vector2(0, s), p + Vector2(-s * 0.75, 0)]), col)
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.75, 0), p + Vector2(0, -s * 0.1)]), col.lightened(0.5))
