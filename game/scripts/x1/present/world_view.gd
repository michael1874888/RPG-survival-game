extends Node2D
## The battle world, drawn in five layers: ground, entities, normal effects, additive glow, and a
## top layer for enemy warnings, markers, bite teeth, texts and damage numbers (always readable).
## Positions are interpolated between simulation steps so slow motion stays smooth.

const Looks := preload("res://scripts/x1/present/looks.gd")
const NanaRig := preload("res://scripts/x1/present/nana_rig.gd")
const FX := preload("res://scripts/x1/present/fx.gd")
const UI := preload("res://scripts/x1/ui/theme.gd")
const Data := preload("res://scripts/x1/core/data.gd")

var battle = null
var fx = FX.new()
var nana = NanaRig.new()
var views: Dictionary = {}
var prev: Dictionary = {}
var alpha := 1.0
var clock := 0.0
var time_scale := 1.0
var settings: Dictionary = {}
var colors: Dictionary = {}
var decorations: Array = []
var decoration_region := ""
var strikes: Array = []
var aim_dir := Vector2.ZERO
var layers: Dictionary = {}
var font: Font
var bold: Font


func _ready() -> void:
	font = UI.font(false)
	bold = UI.font(true)
	var data = Data.shared()
	fx.setup(data.feel)
	colors = data.feel.get("colors", {})
	for name: String in ["ground", "entities", "fx_normal", "fx_glow", "top"]:
		var layer := Node2D.new()
		layer.name = name
		add_child(layer)
		layers[name] = layer
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	layers.fx_glow.material = additive
	layers.ground.draw.connect(func(): _draw_ground(layers.ground))
	layers.entities.draw.connect(func(): _draw_entities(layers.entities))
	layers.fx_normal.draw.connect(func(): fx.draw_particles(layers.fx_normal, false))
	layers.fx_glow.draw.connect(func(): _draw_glow(layers.fx_glow))
	layers.top.draw.connect(func(): _draw_top(layers.top))


func col(name: String) -> Color:
	return fx.color(name)


func set_battle(b) -> void:
	battle = b
	views.clear()
	prev.clear()
	strikes.clear()
	fx.clear()
	if b != null:
		nana.last_pos = b.player.pos
		_decorate(b.region_id, b.world)


## Called right before the last simulation step of a frame.
func capture() -> void:
	if battle == null: return
	prev.clear()
	prev["nana"] = battle.player.pos
	for e: Dictionary in battle.enemies: prev[int(e.id)] = e.pos


func lerp_pos(key, current: Vector2) -> Vector2:
	if not prev.has(key): return current
	var from: Vector2 = prev[key]
	if from.distance_squared_to(current) > 200.0 * 200.0: return current
	return from.lerp(current, alpha)


func view(id: int) -> Dictionary:
	if not views.has(id): views[id] = {"squash": 0.0, "tilt": 0.0, "flash": 0.0, "spawn": 1.0, "look": Vector2.RIGHT}
	return views[id]


func on_event(kind: String, ev: Dictionary) -> void:
	nana.on_event(kind, ev)
	match kind:
		"hit":
			if ev.has("id"):
				var v := view(int(ev.id))
				v.squash = minf(1.0, float(v.squash) + (0.7 if ev.get("prey", false) else 0.5))
				v.flash = 1.0
				var dir: Vector2 = ev.get("dir", Vector2.RIGHT)
				v.tilt = clampf(dir.x, -1.0, 1.0) * 0.35
		"spawn":
			view(int(ev.get("id", -1))).spawn = 0.0
		"defeat":
			var snapshot := {"id": int(ev.get("id", 0)), "kind": str(ev.get("kind", "E01")), "ai": str(Data.shared().enemies.get(str(ev.get("kind", "E01")), {}).get("ai", "chaser")),
				"role": ev.get("role", "fodder"), "radius": float(ev.get("radius", 15.0)), "pos": ev.pos, "phase": "", "flash": 0.0}
			fx.corpse(snapshot)
			views.erase(int(ev.get("id", 0)))
		"enemy_strike":
			var copy: Dictionary = ev.duplicate()
			copy.life = 0.28
			copy.max = 0.28
			strikes.append(copy)
		"pounce":
			for i in 4: fx.afterimage(Vector2(ev.pos) + Vector2(ev.dir) * 40.0 * i, Vector2(ev.dir), 1.0)
		"land":
			fx.special("land", Vector2(ev.pos), Vector2(ev.dir))


func _process(delta: float) -> void:
	clock += delta
	var scaled := delta * time_scale
	fx.update(scaled)
	for id in views:
		var v: Dictionary = views[id]
		v.squash = maxf(0.0, float(v.squash) - scaled * 6.0)
		v.tilt = lerpf(float(v.tilt), 0.0, 1.0 - exp(-10.0 * scaled))
		v.flash = maxf(0.0, float(v.flash) - scaled * 9.0)
		v.spawn = minf(1.0, float(v.spawn) + scaled * 3.5)
	for i in range(strikes.size() - 1, -1, -1):
		strikes[i].life = float(strikes[i].life) - scaled
		if float(strikes[i].life) <= 0.0: strikes.remove_at(i)
	if battle != null:
		nana.update(scaled if scaled > 0.0 else 0.0001, battle.player.pos, battle)
		if battle.dashing() and int(clock * 60.0) % 2 == 0:
			fx.afterimage(battle.player.pos, Vector2(battle.pounce.dash.dir), 1.0)
		for e: Dictionary in battle.enemies:
			var v := view(int(e.id))
			var look: Vector2 = Vector2(e.dir) if e.ai != "chaser" and not e.get("tele", {}).is_empty() else (battle.player.pos - e.pos).normalized()
			if look.length_squared() > 0.01: v.look = Vector2(v.look).slerp(look, 1.0 - exp(-10.0 * maxf(scaled, 0.001)))
	for layer: Node2D in layers.values(): layer.queue_redraw()


func _decorate(region_id: String, world: Vector2) -> void:
	if decoration_region == region_id: return
	decoration_region = region_id
	decorations.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region_id)
	for i in 260:
		decorations.append({"pos": Vector2(rng.randf_range(0, world.x), rng.randf_range(0, world.y)), "size": rng.randf_range(2, 8),
			"flower": i % 7 == 0, "stone": i % 23 == 0})


func _visible_rect() -> Rect2:
	var inv := get_global_transform().affine_inverse()
	var view_rect := get_viewport_rect()
	var a: Vector2 = inv * view_rect.position
	var b: Vector2 = inv * view_rect.end
	return Rect2(a, b - a).abs().grow(80.0)


# ---- layers -------------------------------------------------------------------------------------

func _draw_ground(c: CanvasItem) -> void:
	if battle == null: return
	var palette: Dictionary = battle.region.get("palette", {})
	var ground := Color(str(palette.get("ground", "284b3b")))
	var tuft := Color(str(palette.get("tuft", "4a7a55")))
	var area := _visible_rect()
	c.draw_rect(area.grow(400), ground.darkened(0.45))
	c.draw_rect(Rect2(Vector2.ZERO, battle.world), ground)
	var step := 160
	for x in range(int(area.position.x / step) * step, int(area.end.x) + step, step):
		for y in range(int(area.position.y / step) * step, int(area.end.y) + step, step):
			if x < 0 or y < 0 or x > battle.world.x or y > battle.world.y: continue
			var jitter := Vector2(sin(x * 0.13 + y) * 30.0, cos(y * 0.11 + x) * 30.0)
			c.draw_texture_rect(fx.glow_texture, Rect2(Vector2(x, y) + jitter - Vector2.ONE * 90, Vector2.ONE * 180), false, Color(tuft.r, tuft.g, tuft.b, 0.10))
	for item: Dictionary in decorations:
		var pos: Vector2 = item.pos
		if not area.has_point(pos): continue
		var r: float = item.size
		if item.stone:
			Looks.ellipse(c, pos, r * 2.2, r * 1.4, ground.darkened(0.25), 10)
			Looks.ellipse(c, pos + Vector2(-1, -2), r * 1.8, r * 1.0, ground.lightened(0.1), 10)
			continue
		c.draw_line(pos, pos + Vector2(-3, -r * 2), tuft, 2.0, true)
		c.draw_line(pos, pos + Vector2(4, -r * 1.4), tuft, 2.0, true)
		c.draw_line(pos, pos + Vector2(0, -r * 2.4), tuft.lightened(0.1), 2.0, true)
		if item.flower: c.draw_circle(pos + Vector2(-3, -r * 2), 3.0, Color("e8d9a0"))
	var edge := Rect2(Vector2(10, 10), battle.world - Vector2(20, 20))
	c.draw_rect(edge, Color(str(palette.get("edge", "7a9b66"))), false, 14.0)
	c.draw_rect(edge.grow(-12), Color(0, 0, 0, 0.18), false, 6.0)
	var obstacle := Color(str(palette.get("obstacle", "35593f")))
	for rect: Rect2 in battle.obstacles.rects:
		c.draw_style_box(UI.panel(Color(0, 0, 0, 0.25), 22, 0), Rect2(rect.position + Vector2(6, 12), rect.size))
		c.draw_style_box(UI.panel(Looks.INK, 22, 0), rect.grow(3))
		c.draw_style_box(UI.panel(obstacle, 20, 0), rect)
		c.draw_style_box(UI.panel(obstacle.lightened(0.12), 16, 0), Rect2(rect.position + Vector2(10, 8), rect.size - Vector2(20, 26)))
		for i in 6:
			var dot: Vector2 = rect.position + Vector2(rect.size.x * (0.12 + 0.15 * i), rect.size.y * (0.35 + 0.3 * (i % 2)))
			c.draw_circle(dot + Vector2(0, 2), 7.0, Color(0, 0, 0, 0.25))
			c.draw_circle(dot, 7.0, Color("e7a6c4") if i % 2 == 0 else Color("f1d27a"))
			c.draw_circle(dot + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.7))
	for circle: Dictionary in battle.obstacles.circles:
		var pos: Vector2 = circle.center
		var r: float = circle.radius
		c.draw_texture_rect(fx.glow_texture, Rect2(pos + Vector2(-r * 1.2, -r * 0.6), Vector2(r * 2.4, r * 2.2)), false, Color(0, 0, 0, 0.4))
		c.draw_circle(pos, r + 3.0, Looks.INK)
		c.draw_circle(pos, r, obstacle)
		c.draw_circle(pos + Vector2(-r * 0.15, -r * 0.18), r * 0.78, obstacle.lightened(0.1))
		c.draw_arc(pos, r - 6.0, PI * 1.05, PI * 1.7, 20, obstacle.lightened(0.35), 4.0, true)
	for hazard: Dictionary in battle.hazards:
		var pos: Vector2 = hazard.pos
		var r: float = hazard.radius
		c.draw_circle(pos, r, Color(0.32, 0.55, 0.25, 0.35))
		for k in 7:
			var a := TAU * k / 7.0 + clock * 0.6
			c.draw_arc(pos + Vector2.RIGHT.rotated(a) * r * 0.55, r * 0.35, a, a + 2.4, 10, Color(0.55, 0.85, 0.4, 0.7), 3.0, true)
		c.draw_arc(pos, r, 0, TAU, 40, Color(0.65, 0.95, 0.5, 0.8), 3.0, true)
	var warning: float = float(Data.shared().tuning.world.spawn_warning)
	for entry: Dictionary in battle.spawner.pending:
		var pos: Vector2 = entry.pos
		var progress: float = clampf(1.0 - float(entry.timer) / warning, 0.0, 1.0)
		var r: float = float(Data.shared().enemies.get(str(entry.kind), {}).get("radius", 18)) * (0.6 + progress)
		Looks.ellipse(c, pos + Vector2(0, 6), r * 1.3, r * 0.55, Color(0.05, 0.02, 0.1, 0.35 + 0.35 * progress), 18)
	for line: Dictionary in battle.lines:
		_band(c, line.origin, line.dir, float(line.length), float(line.width), Color(0.45, 0.85, 1.0, 0.07), Color(0.7, 0.95, 1.0, 0.25))


func _draw_entities(c: CanvasItem) -> void:
	if battle == null: return
	var data = Data.shared()
	var area := _visible_rect()
	var prey_col := col("prey")
	for pickup: Dictionary in battle.pickups:
		if area.has_point(pickup.pos): Looks.gem(c, pickup.pos, int(pickup.value), clock, fx.glow_texture, Color("8fe0ff") if int(pickup.value) < 5 else prey_col)
	for corpse: Dictionary in fx.corpses:
		var t: float = float(corpse.life) / float(corpse.max)
		var e: Dictionary = corpse.enemy
		var spec: Dictionary = data.enemies.get(e.kind, {})
		Looks.enemy(c, e, Vector2(e.pos), {"flash": 1.0 - t * 0.5, "spawn": 1.0, "look": Vector2.RIGHT}, spec, clock, fx.glow_texture, t, 1.0 + (1.0 - t) * 0.35)
	var order: Array = []
	for e: Dictionary in battle.enemies:
		var pos := lerp_pos(int(e.id), e.pos)
		if area.has_point(pos): order.append([pos.y, e, pos])
	order.sort_custom(func(a, b): return a[0] < b[0])
	var nana_pos := lerp_pos("nana", battle.player.pos)
	var nana_drawn := false
	for item: Array in order:
		if not nana_drawn and item[0] > nana_pos.y:
			nana.draw(c, nana_pos, fx.glow_texture, col("night"))
			nana_drawn = true
		var e: Dictionary = item[1]
		Looks.enemy(c, e, item[2], view(int(e.id)), data.enemies[e.kind], clock, fx.glow_texture)
	if not nana_drawn: nana.draw(c, nana_pos, fx.glow_texture, col("night"))
	for shot: Dictionary in battle.shots:
		var pos: Vector2 = shot.pos
		c.draw_texture_rect(fx.glow_texture, Rect2(pos - Vector2.ONE * 18, Vector2.ONE * 36), false, Color(1.0, 0.45, 0.35, 0.6))
		c.draw_circle(pos, 8.0, Looks.INK)
		c.draw_circle(pos, 6.5, col("danger"))
		c.draw_circle(pos + Vector2(-2, -2), 2.5, Color(1, 0.9, 0.8))
	for ball: Dictionary in battle.balls:
		var pos: Vector2 = ball.pos
		c.draw_circle(pos, 8.0, Looks.INK)
		c.draw_circle(pos, 6.5, prey_col)
		c.draw_arc(pos, 4.5, clock * 12.0, clock * 12.0 + 3.0, 8, Color("c98a3a"), 2.0, true)


func _draw_glow(c: CanvasItem) -> void:
	fx.draw_glow(c)
	if battle == null: return
	for ball: Dictionary in battle.balls:
		c.draw_line(ball.pos, Vector2(ball.pos) - Vector2(ball.vel).normalized() * 26.0, Color(1.0, 0.8, 0.4, 0.5), 7.0, true)
	if battle.ult_active():
		var pos := lerp_pos("nana", battle.player.pos)
		var left: float = float(battle.ult.active)
		var total: float = float(Data.shared().tuning.ult.duration) + battle.stats.value("ult_duration")
		var blink: bool = left < 1.0 and int(clock * 12.0) % 2 == 0
		if not blink:
			c.draw_arc(pos, 44.0, -PI * 0.5, -PI * 0.5 + TAU * left / maxf(0.1, total), 40, Color(0.75, 0.6, 1.0, 0.8), 4.0, true)


func _draw_top(c: CanvasItem) -> void:
	if battle == null: return
	var prey_col := col("prey")
	var shadow_col := col("shadow")
	for e: Dictionary in battle.enemies:
		_telegraph(c, e, lerp_pos(int(e.id), e.pos))
	for e: Dictionary in battle.enemies:
		Looks.markers(c, e, lerp_pos(int(e.id), e.pos), clock, bold, battle.by_id, prey_col, shadow_col)
	for entry: Dictionary in battle.spawner.pending:
		if not (entry.opts.get("prey", false) or entry.opts.get("target", false) or Data.shared().enemies.get(str(entry.kind), {}).get("role", "") in ["elite", "boss"]): continue
		var progress: float = clampf(1.0 - float(entry.timer) / float(Data.shared().tuning.world.spawn_warning), 0.0, 1.0)
		c.draw_arc(entry.pos, 30.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, prey_col, 3.0, true)
		c.draw_string_outline(bold, Vector2(entry.pos) + Vector2(-7, 8), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Looks.INK)
		c.draw_string(bold, Vector2(entry.pos) + Vector2(-7, 8), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, prey_col)
	for s: Dictionary in strikes:
		var t: float = float(s.life) / float(s.max)
		var red := Color(1.0, 0.4, 0.3, t)
		match str(s.get("shape", "")):
			"sector":
				var a: float = Vector2(s.dir).angle()
				var half: float = float(s.half)
				var points := PackedVector2Array([s.pos])
				for i in 17: points.append(Vector2(s.pos) + Vector2.RIGHT.rotated(a - half + 2.0 * half * i / 16.0) * float(s.reach))
				c.draw_colored_polygon(points, Color(1.0, 0.35, 0.25, t * 0.35))
				c.draw_arc(s.pos, float(s.reach), a - half, a + half, 24, red, 6.0, true)
			"line":
				_band(c, s.pos, s.dir, float(s.length), float(s.width), Color(1.0, 0.35, 0.25, t * 0.35), red)
			"ring":
				c.draw_arc(s.pos, float(s.radius), 0, TAU, 56, red, 10.0 * t + 2.0, true)
	_draw_aim(c)
	fx.draw_specials(c, bold)


func _draw_aim(c: CanvasItem) -> void:
	if aim_dir == Vector2.ZERO or battle == null: return
	var from := lerp_pos("nana", battle.player.pos)
	var distance: float = float(Data.shared().tuning.pounce.distance) * (1.0 + battle.stats.value("pounce_distance_pct") / 100.0)
	var ready: bool = int(battle.pounce.charges) >= 1
	var color := Color(1.0, 0.88, 0.55, 0.9) if ready else Color(0.7, 0.7, 0.7, 0.45)
	var end: Vector2 = from + aim_dir * distance
	for i in 12:
		var a: Vector2 = from.lerp(end, i / 12.0 + fmod(clock * 1.5, 1.0) / 12.0)
		var b: Vector2 = from.lerp(end, minf(1.0, (i + 0.5) / 12.0 + fmod(clock * 1.5, 1.0) / 12.0))
		c.draw_line(a, b, color, 4.0, true)
	var radius: float = battle.bite_radius()
	c.draw_arc(end, radius, 0, TAU, 40, Color(color.r, color.g, color.b, 0.55), 2.5, true)
	if not ready: return
	var target: Dictionary = battle.bite_target(end, radius, [])
	if target.is_empty(): return
	var pos := lerp_pos(int(target.id), target.pos)
	var r: float = float(target.radius) + 10.0 + sin(clock * 12.0) * 2.0
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		c.draw_arc(pos, r, a - 0.35, a + 0.35, 6, color, 4.0, true)
	c.draw_string_outline(bold, pos + Vector2(-12, -r - 8), "咬", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Looks.INK)
	c.draw_string(bold, pos + Vector2(-12, -r - 8), "咬", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)


func _band(c: CanvasItem, origin: Vector2, dir: Vector2, length: float, width: float, fill: Color, edge: Color) -> void:
	var side := dir.orthogonal() * width * 0.5
	var end := origin + dir * length
	c.draw_colored_polygon(PackedVector2Array([origin - side, end - side, end + side, origin + side]), fill)
	c.draw_polyline(PackedVector2Array([origin - side, end - side, end + side, origin + side, origin - side]), edge, 2.5, true)


func _telegraph(c: CanvasItem, e: Dictionary, pos: Vector2) -> void:
	var tele: Dictionary = e.get("tele", {})
	if tele.is_empty(): return
	var total: float = maxf(0.01, float(e.get("windup_total", 1.0)))
	var left: float = float(e.timer)
	var progress: float = clampf(1.0 - left / total, 0.0, 1.0)
	var dim: bool = tele.get("dim", false)
	var late: bool = left < 0.3 and not dim
	var blink: float = (0.5 + 0.5 * sin(clock * (40.0 if late else 12.0))) if late else 0.0
	var danger := col("danger")
	var fill := Color(danger.r, danger.g, danger.b, (0.06 if dim else 0.1) + 0.22 * progress + 0.12 * blink)
	var edge := Color(1.0, 0.8, 0.55, 0.45 if dim else 0.75 + 0.25 * blink)
	var dir: Vector2 = Vector2(tele.get("dir", e.dir))
	match str(tele.get("shape", "")):
		"sector":
			var reach: float = float(tele.reach)
			var half: float = deg_to_rad(float(tele.angle) * 0.5)
			var points := PackedVector2Array([pos])
			for i in 21: points.append(pos + dir.rotated(-half + 2.0 * half * i / 20.0) * reach)
			c.draw_colored_polygon(points, fill)
			c.draw_arc(pos, reach, dir.angle() - half, dir.angle() + half, 24, edge, 3.5, true)
			c.draw_arc(pos, reach * progress, dir.angle() - half, dir.angle() + half, 24, Color(1, 0.95, 0.7, 0.75), 2.5, true)
		"line", "fan":
			var length: float = float(tele.get("length", 200))
			if tele.shape == "fan":
				var spread: float = deg_to_rad(float(tele.angle))
				var count: int = maxi(1, int(tele.get("count", 3)))
				for i in count:
					var a: float = -spread * 0.5 + spread * i / maxf(1.0, count - 1.0)
					_band(c, pos, dir.rotated(a), length, 14.0, fill, edge)
			else:
				_band(c, pos, dir, length, float(tele.get("width", 30)), fill, edge)
				c.draw_line(pos, pos + dir * length * progress, Color(1, 0.95, 0.7, 0.9), 3.5, true)
		"circle":
			var center: Vector2 = Vector2(tele.get("pos", e.pos))
			c.draw_circle(center, float(tele.radius), fill)
			c.draw_arc(center, float(tele.radius), 0, TAU, 36, edge, 3.5, true)
			c.draw_arc(center, float(tele.radius) * progress, 0, TAU, 36, Color(1, 0.95, 0.7, 0.7), 2.5, true)
		"circles":
			for point in tele.points:
				c.draw_circle(Vector2(point), float(tele.radius), fill)
				c.draw_arc(Vector2(point), float(tele.radius), 0, TAU, 36, edge, 3.5, true)
		"ring":
			var radius: float = float(tele.radius)
			var safe_dir: Vector2 = Vector2(tele.safe_dir)
			var half_safe: float = deg_to_rad(float(tele.safe) * 0.5)
			var start: float = safe_dir.angle() + half_safe
			var points := PackedVector2Array([pos])
			for i in 41: points.append(pos + Vector2.RIGHT.rotated(start + (TAU - 2.0 * half_safe) * i / 40.0) * radius)
			c.draw_colored_polygon(points, fill)
			c.draw_arc(pos, radius, start, start + TAU - 2.0 * half_safe, 40, edge, 3.5, true)
			var safe_points := PackedVector2Array([pos])
			for i in 11: safe_points.append(pos + Vector2.RIGHT.rotated(safe_dir.angle() - half_safe + 2.0 * half_safe * i / 10.0) * radius)
			c.draw_colored_polygon(safe_points, Color(0.5, 0.95, 0.7, 0.22))
			c.draw_string_outline(bold, pos + safe_dir * radius * 0.6 + Vector2(-18, 8), "安全", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Looks.INK)
			c.draw_string(bold, pos + safe_dir * radius * 0.6 + Vector2(-18, 8), "安全", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.7, 1.0, 0.8))
	if progress < 0.25 and not dim:
		var pop: float = 1.0 + (0.25 - progress) * 3.0
		var top := pos + Vector2(-6 * pop, -float(e.radius) - 26)
		c.draw_string_outline(bold, top, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * pop), 6, Looks.INK)
		c.draw_string(bold, top, "!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * pop), danger)
