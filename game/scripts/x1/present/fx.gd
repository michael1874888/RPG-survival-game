extends RefCounted
## Presentation-only effects: particles, rings, pillars, bite teeth, floating text, damage numbers,
## dissolving bodies and pounce afterimages. Updated with scaled time (freezes during hit-stop).

var feel: Dictionary = {}
var colors: Dictionary = {}
var quality := "high"
var particles: Array = []     # {pos, vel, life, max, size, color, shape, drag, gravity, spin, rot, additive}
var rings: Array = []         # {pos, radius, life, max, color, width, grow}
var pillars: Array = []       # {pos, life, max, color}
var specials: Array = []      # {kind, pos, life, max, dir, color, data}
var texts: Array = []         # {text, pos, life, max, color, size, vel}
var numbers: Array = []       # {value, pos, life, max, color, size, big}
var corpses: Array = []       # {enemy snapshot, life, max}
var afterimages: Array = []   # {pos, dir, life, max, squash}
var rng := RandomNumberGenerator.new()
var glow_texture: Texture2D
var low_flash := false


func setup(feel_data: Dictionary) -> void:
	feel = feel_data
	colors = feel.get("colors", {})
	rng.seed = 5
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.35, Color(1, 1, 1, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	glow_texture = texture


func color(name: String, fallback := Color.WHITE) -> Color:
	if colors.has(name): return Color(str(colors[name]))
	if name == "dust": return Color(0.85, 0.82, 0.7, 0.55)
	if name == "shadow_smoke": return Color(0.25, 0.2, 0.32, 0.5)
	if name.length() == 6 or name.length() == 8:
		return Color.from_string(name, fallback)
	return fallback


func cap() -> int:
	return int(feel.get("limits", {}).get("particles", {}).get(quality, 900))


func scale() -> float:
	return float(feel.get("limits", {}).get("particle_scale", {}).get(quality, 1.0))


func clear() -> void:
	for list: Array in [particles, rings, pillars, specials, texts, numbers, corpses, afterimages]: list.clear()


## preset from feel.json particles; tint used when the preset colour is "enemy".
func burst(preset: String, pos: Vector2, count: int, tint := Color.WHITE, dir := Vector2.ZERO) -> void:
	var spec: Dictionary = feel.get("particles", {}).get(preset, {})
	if spec.is_empty(): return
	var amount := maxi(1, int(round(count * scale())))
	var room := cap() - particles.size()
	if room <= 0: return
	amount = mini(amount, room)
	var speed: Array = spec.get("speed", [100, 200])
	var life: Array = spec.get("life", [0.3, 0.5])
	var size: Array = spec.get("size", [3, 5])
	var col_name: String = str(spec.get("color", "white"))
	var base: Color = tint if col_name == "enemy" else color(col_name)
	for i in amount:
		var angle: float = rng.randf() * TAU
		if dir != Vector2.ZERO: angle = dir.angle() + rng.randf_range(-0.9, 0.9)
		var v := Vector2.RIGHT.rotated(angle) * rng.randf_range(float(speed[0]), float(speed[1]))
		var l := rng.randf_range(float(life[0]), float(life[1]))
		var c := base
		c = c.lightened(rng.randf_range(0.0, 0.25))
		particles.append({"pos": pos + Vector2.RIGHT.rotated(angle) * rng.randf_range(0.0, 6.0), "vel": v, "life": l, "max": l,
			"size": rng.randf_range(float(size[0]), float(size[1])), "color": c, "shape": str(spec.get("shape", "dot")),
			"drag": float(spec.get("drag", 3.0)), "gravity": float(spec.get("gravity", 0.0)), "spin": float(spec.get("spin", 0.0)) * rng.randf_range(-1.0, 1.0),
			"rot": rng.randf() * TAU, "additive": bool(spec.get("additive", false)), "dir": dir})


func ring(kind: String, pos: Vector2, radius := 0.0) -> void:
	var specs := {
		"special": {"r": 46.0, "life": 0.35, "color": "danger_edge", "width": 4.0},
		"prey": {"r": 120.0, "life": 0.5, "color": "prey", "width": 7.0},
		"boss": {"r": 320.0, "life": 0.9, "color": "prey", "width": 10.0},
		"shadow": {"r": 90.0, "life": 0.4, "color": "shadow", "width": 6.0},
		"night": {"r": 240.0, "life": 0.6, "color": "night", "width": 10.0},
		"wave": {"r": 110.0, "life": 0.35, "color": "cream", "width": 5.0},
		"level": {"r": 140.0, "life": 0.6, "color": "prey", "width": 8.0},
	}
	var spec: Dictionary = specs.get(kind, specs.wave)
	var r: float = radius if radius > 0.0 else float(spec.r)
	rings.append({"pos": pos, "radius": r, "life": spec.life, "max": spec.life, "color": color(spec.color), "width": spec.width})
	if kind == "night":
		rings.append({"pos": pos, "radius": r * 0.65, "life": spec.life * 0.8, "max": spec.life * 0.8, "color": color("shadow"), "width": 6.0})
		rings.append({"pos": pos, "radius": r * 1.25, "life": spec.life * 1.2, "max": spec.life * 1.2, "color": color("night"), "width": 4.0})


func pillar(pos: Vector2, col_name := "prey") -> void:
	pillars.append({"pos": pos, "life": 0.55, "max": 0.55, "color": color(col_name)})


func special(kind: String, pos: Vector2, dir := Vector2.RIGHT, data := {}) -> void:
	var lives := {"teeth": 0.28, "mark": 0.5, "refund": 0.4, "slash": 0.18, "land": 0.45, "crack": 0.5}
	var life: float = float(lives.get(kind, 0.3))
	specials.append({"kind": kind, "pos": pos, "life": life, "max": life, "dir": dir, "data": data})


func text(value: String, pos: Vector2, col: Color, size := 30) -> void:
	if texts.size() >= int(feel.get("limits", {}).get("texts", 6)): texts.pop_front()
	texts.append({"text": value, "pos": pos, "life": 0.9, "max": 0.9, "color": col, "size": size, "vel": Vector2(0, -60)})


func number(value: float, pos: Vector2, col: Color, big := false) -> void:
	if numbers.size() >= int(feel.get("limits", {}).get("damage_numbers", 28)): numbers.pop_front()
	var life := 0.75 if big else 0.6
	numbers.append({"value": int(round(value)), "pos": pos + Vector2(rng.randf_range(-10, 10), -18), "life": life, "max": life,
		"color": col, "big": big, "vel": Vector2(rng.randf_range(-30, 30), -110 if big else -80)})


func corpse(snapshot: Dictionary) -> void:
	var life := 0.22 if snapshot.get("role", "") in ["fodder", "hound"] else 0.4
	if snapshot.get("role", "") == "boss": life = 1.0
	corpses.append({"enemy": snapshot, "life": life, "max": life})
	if corpses.size() > 60: corpses.pop_front()


func afterimage(pos: Vector2, dir: Vector2, squash: float) -> void:
	afterimages.append({"pos": pos, "dir": dir, "life": 0.22, "max": 0.22, "squash": squash})
	if afterimages.size() > 12: afterimages.pop_front()


func update(dt: float) -> void:
	if dt <= 0.0: return
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life = float(p.life) - dt
		if float(p.life) <= 0.0:
			particles.remove_at(i)
			continue
		var vel: Vector2 = p.vel
		vel *= exp(-float(p.drag) * dt)
		vel.y += float(p.gravity) * dt
		p.vel = vel
		p.pos = Vector2(p.pos) + vel * dt
		p.rot = float(p.rot) + float(p.spin) * dt
	for list: Array in [rings, pillars, specials, texts, numbers, corpses, afterimages]:
		for i in range(list.size() - 1, -1, -1):
			list[i].life = float(list[i].life) - dt
			if list[i].has("vel"): list[i].pos = Vector2(list[i].pos) + Vector2(list[i].vel) * dt
			if float(list[i].life) <= 0.0: list.remove_at(i)


# ---- drawing (called by world_view on its layers) --------------------------------------------

func draw_particles(canvas: CanvasItem, additive: bool) -> void:
	for p: Dictionary in particles:
		if bool(p.additive) != additive: continue
		var t: float = float(p.life) / float(p.max)
		var c: Color = p.color
		c.a *= minf(1.0, t * 1.6)
		var pos: Vector2 = p.pos
		var size: float = float(p.size) * (0.4 + 0.6 * t)
		match str(p.shape):
			"streak":
				var v: Vector2 = p.vel
				canvas.draw_line(pos, pos - v * 0.04, c, size, true)
			"line":
				var d: Vector2 = Vector2(p.dir) if Vector2(p.dir) != Vector2.ZERO else Vector2.RIGHT
				canvas.draw_line(pos, pos - d * 46.0 * t, c, size, true)
			"shard":
				var r: float = p.rot
				canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(size, 0).rotated(r), pos + Vector2(-size * 0.6, size * 0.5).rotated(r),
					pos + Vector2(-size * 0.4, -size * 0.7).rotated(r)]), c)
			"star":
				canvas.draw_texture_rect(glow_texture, Rect2(pos - Vector2.ONE * size * 2.2, Vector2.ONE * size * 4.4), false, c)
				canvas.draw_line(pos - Vector2(size * 1.6, 0).rotated(p.rot), pos + Vector2(size * 1.6, 0).rotated(p.rot), c, 1.5, true)
				canvas.draw_line(pos - Vector2(0, size * 1.6).rotated(p.rot), pos + Vector2(0, size * 1.6).rotated(p.rot), c, 1.5, true)
			"puff":
				canvas.draw_texture_rect(glow_texture, Rect2(pos - Vector2.ONE * size * (2.0 - t), Vector2.ONE * size * (4.0 - 2.0 * t)), false, c)
			"plus":
				canvas.draw_line(pos - Vector2(size, 0), pos + Vector2(size, 0), c, 2.5, true)
				canvas.draw_line(pos - Vector2(0, size), pos + Vector2(0, size), c, 2.5, true)
			"slash":
				var d: Vector2 = Vector2(p.dir) if Vector2(p.dir) != Vector2.ZERO else Vector2.RIGHT
				var side: Vector2 = d.orthogonal().rotated(0.5) * size
				canvas.draw_line(pos - side, pos + side, c, 5.0 * t + 1.0, true)
			_:
				canvas.draw_circle(pos, size, c)


func draw_glow(canvas: CanvasItem) -> void:
	draw_particles(canvas, true)
	for r: Dictionary in rings:
		var t: float = 1.0 - float(r.life) / float(r.max)
		var c: Color = r.color
		c.a = (1.0 - t) * 0.9
		canvas.draw_arc(r.pos, float(r.radius) * (0.25 + 0.75 * ease(t, 0.4)), 0.0, TAU, 56, c, float(r.width) * (1.0 - t) + 1.0, true)
	for p: Dictionary in pillars:
		var t: float = float(p.life) / float(p.max)
		var c: Color = p.color
		c.a = t * 0.55
		var width: float = 46.0 * (0.4 + 0.6 * t)
		canvas.draw_texture_rect(glow_texture, Rect2(Vector2(p.pos) - Vector2(width, 360), Vector2(width * 2.0, 380)), false, c)
	for a: Dictionary in afterimages:
		var t: float = float(a.life) / float(a.max)
		canvas.draw_texture_rect(glow_texture, Rect2(Vector2(a.pos) - Vector2.ONE * 34.0, Vector2.ONE * 68.0), false, Color(0.55, 0.42, 0.85, 0.35 * t))


func draw_specials(canvas: CanvasItem, font: Font) -> void:
	for s: Dictionary in specials:
		var t: float = 1.0 - float(s.life) / float(s.max)
		var pos: Vector2 = s.pos
		match str(s.kind):
			"teeth":
				var close: float = clampf(t * 3.0, 0.0, 1.0)
				var gap: float = lerpf(22.0, 2.0, ease(close, 0.3))
				var alpha: float = 1.0 - clampf((t - 0.5) * 2.0, 0.0, 1.0)
				var col := Color(1, 1, 1, alpha)
				var prey: bool = s.data.get("prey", false)
				if prey: col = Color(color("prey").r, color("prey").g, color("prey").b, alpha)
				for side: float in [-1.0, 1.0]:
					var y: float = gap * side
					for k in 4:
						var x: float = -18.0 + k * 12.0
						canvas.draw_colored_polygon(PackedVector2Array([pos + Vector2(x - 5, y), pos + Vector2(x + 5, y),
							pos + Vector2(x, y - 10.0 * side)]), col)
					canvas.draw_line(pos + Vector2(-24, y), pos + Vector2(24, y), Color(col.r, col.g, col.b, alpha * 0.7), 3.0, true)
				if close >= 1.0:
					canvas.draw_texture_rect(glow_texture, Rect2(pos - Vector2.ONE * 40, Vector2.ONE * 80), false, Color(1, 1, 1, alpha * 0.4))
			"mark":
				canvas.draw_arc(pos, 18.0 + 26.0 * t, 0, TAU, 32, Color(color("shadow").r, color("shadow").g, color("shadow").b, 1.0 - t), 3.0, true)
			"refund":
				canvas.draw_arc(pos, 30.0 + 10.0 * t, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - t), 28, Color(color("prey").r, color("prey").g, color("prey").b, 1.0 - t), 3.0, true)
			"land":
				canvas.draw_arc(pos, 18.0 + 48.0 * ease(t, 0.4), 0, TAU, 36, Color(0.95, 0.9, 0.8, (1.0 - t) * 0.8), 4.0 * (1.0 - t) + 1.0, true)
				for k in 5:
					var a: float = TAU * k / 5.0 + 0.3
					var from: Vector2 = pos + Vector2.RIGHT.rotated(a) * 14.0
					canvas.draw_line(from, from + Vector2.RIGHT.rotated(a) * 16.0 * (1.0 - t), Color(0.3, 0.25, 0.2, (1.0 - t) * 0.6), 2.0, true)
			"crack":
				for k in 6:
					var a: float = TAU * k / 6.0
					canvas.draw_line(pos, pos + Vector2.RIGHT.rotated(a + 0.2 * sin(k)) * 34.0 * ease(t, 0.3), Color(1, 0.4, 0.4, 1.0 - t), 2.5, true)
	for entry: Dictionary in texts:
		var t: float = float(entry.life) / float(entry.max)
		var pop: float = 1.0 + 0.35 * maxf(0.0, (t - 0.8) / 0.2)
		var size := int(float(entry.size) * pop)
		var c: Color = entry.color
		c.a = minf(1.0, t * 2.5)
		_outlined(canvas, font, Vector2(entry.pos) - Vector2(size * str(entry.text).length() * 0.5, 0), str(entry.text), size, c)
	for n: Dictionary in numbers:
		var t: float = float(n.life) / float(n.max)
		var pop: float = 1.0 + (0.6 if n.big else 0.3) * maxf(0.0, (t - 0.75) / 0.25)
		var size := int((30 if n.big else 20) * pop)
		var c: Color = n.color
		c.a = minf(1.0, t * 3.0)
		var label := str(n.value)
		_outlined(canvas, font, Vector2(n.pos) - Vector2(size * 0.3 * label.length(), 0), label, size, c)


func _outlined(canvas: CanvasItem, font: Font, pos: Vector2, value: String, size: int, c: Color) -> void:
	var outline := Color(0.08, 0.06, 0.1, c.a * 0.9)
	canvas.draw_string_outline(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, outline)
	canvas.draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
