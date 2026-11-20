extends Control
## Draws an X1 battle: ground, obstacles, warnings, enemies, Nana, effects and the HUD.
## Reads battle state and its events; never changes the rules.

const UI := preload("res://scripts/x1/ui/theme.gd")
const Data := preload("res://scripts/x1/core/data.gd")

var battle = null
var run = null
var touch = null
var settings: Dictionary = {}
var aim_mouse := Vector2.ZERO
var mouse_aiming := false
var hint := ""
var hint_time := 0.0
var effects: Array = []
var shake := 0.0
var shake_offset := Vector2.ZERO
var hurt_flash := 0.0
var net_banner := 0.0
var clock := 0.0
var decorations: Array = []
var decoration_region := ""
var font: Font
var bold: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = UI.font(false)
	bold = UI.font(true)


func show_hint(text: String, seconds := 4.0) -> void:
	hint = text
	hint_time = seconds


## Turns rule events into short-lived visuals. Returns nothing; sounds are handled by the caller.
func consume(events: Array) -> void:
	for ev: Dictionary in events:
		match str(ev.kind):
			"swipe": _effect(ev, 0.18)
			"bite": _effect(ev, 0.22)
			"land":
				_effect(ev, 0.25)
				_shake(float(Data.shared().tuning.feel.shake_land))
			"pounce": _effect(ev, 0.22)
			"wave": _effect(ev, 0.35)
			"burst": _effect(ev, 0.25)
			"line": _effect(ev, 0.28)
			"defeat": _effect(ev, 0.45)
			"hit":
				if effects.size() < 220: _effect(ev, 0.12)
			"hurt":
				hurt_flash = 0.25
				_shake(float(Data.shared().tuning.feel.shake_hurt))
			"ult":
				_effect(ev, 0.5)
				_shake(float(Data.shared().tuning.feel.shake_ult))
			"enemy_strike":
				_effect(ev, 0.3)
				_shake(2.0)
			"hazard", "heal", "mark", "cash", "execute", "roam_charge", "refund", "slow": _effect(ev, 0.4)
			"boss_phase":
				_effect(ev, 0.8)
				_shake(float(Data.shared().tuning.feel.shake_boss))
			"net": net_banner = 1.6


func _effect(ev: Dictionary, life: float) -> void:
	var copy := ev.duplicate()
	copy.life = life
	copy.max_life = life
	effects.append(copy)


func _shake(amount: float) -> void:
	if settings.get("shake", true): shake = maxf(shake, amount)


func _process(delta: float) -> void:
	clock += delta
	hint_time = maxf(0.0, hint_time - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	net_banner = maxf(0.0, net_banner - delta)
	shake = maxf(0.0, shake - delta * 40.0)
	shake_offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) if shake > 0.1 else Vector2.ZERO
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life = float(effects[i].life) - delta
		if float(effects[i].life) <= 0.0: effects.remove_at(i)
	queue_redraw()


func _decorate(region_id: String, world: Vector2) -> void:
	if decoration_region == region_id: return
	decoration_region = region_id
	decorations.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(region_id)
	for i in 220:
		decorations.append({"pos": Vector2(rng.randf_range(0, world.x), rng.randf_range(0, world.y)), "size": rng.randf_range(2, 8), "flower": i % 7 == 0})


func _draw() -> void:
	if battle == null: return
	var region: Dictionary = battle.region
	var palette: Dictionary = region.get("palette", {})
	var cam: Vector2 = battle.camera_rect().position + shake_offset
	draw_rect(Rect2(Vector2.ZERO, size), Color(str(palette.get("ground", "284b3b"))))
	_draw_ground(cam, palette)
	_draw_obstacles(cam, palette)
	for hazard: Dictionary in battle.hazards:
		var pos: Vector2 = Vector2(hazard.pos) - cam
		draw_circle(pos, float(hazard.radius), Color(0.45, 0.8, 0.35, 0.22))
		draw_arc(pos, float(hazard.radius), 0, TAU, 36, Color(0.65, 0.95, 0.5, 0.7), 2.5, true)
	for entry: Dictionary in battle.spawner.pending:
		var pos: Vector2 = Vector2(entry.pos) - cam
		var progress: float = 1.0 - float(entry.timer) / float(Data.shared().tuning.world.spawn_warning)
		var prey: bool = entry.opts.get("prey", false) or entry.opts.get("target", false)
		var color: Color = UI.PREY if prey else UI.GOLD
		draw_circle(pos, 26.0, Color(color.r, color.g, color.b, 0.12))
		draw_arc(pos, 32.0, -PI * 0.5, -PI * 0.5 + maxf(0.02, progress) * TAU, 28, color, 3.0, true)
		draw_string(bold, pos + Vector2(-5, 7), "◆" if prey else "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, color)
	for line: Dictionary in battle.lines:
		_draw_band(Vector2(line.origin) - cam, Vector2(line.dir), float(line.length), float(line.width), Color(0.45, 0.85, 1.0, 0.10), Color(0.7, 0.95, 1.0, 0.35))
	for pickup: Dictionary in battle.pickups:
		var pos: Vector2 = Vector2(pickup.pos) - cam
		if not Rect2(Vector2(-20, -20), size + Vector2(40, 40)).has_point(pos): continue
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -6), pos + Vector2(5, 0), pos + Vector2(0, 6), pos + Vector2(-5, 0)]), UI.GOLD)
	# Nana's own effects sit under enemies; enemy warnings and strikes always draw on top.
	_draw_effects(cam, false)
	for e: Dictionary in battle.enemies:
		_draw_enemy(e, cam)
	for shot: Dictionary in battle.shots:
		var pos: Vector2 = Vector2(shot.pos) - cam
		draw_circle(pos, 8.0, Color("f07870"))
		draw_arc(pos, 11.0, 0.0, TAU, 20, UI.CREAM, 2.0, true)
	for ball: Dictionary in battle.balls:
		var pos: Vector2 = Vector2(ball.pos) - cam
		draw_line(pos, pos - Vector2(ball.vel).normalized() * 18.0, Color(1.0, 0.85, 0.5, 0.4), 6.0, true)
		draw_circle(pos, 7.0, Color("ffd479"))
		draw_arc(pos, 7.0, 0.5, 2.5, 8, Color("c98a3a"), 2.0, true)
	for e: Dictionary in battle.enemies:
		_draw_telegraph(e, cam)
	_draw_effects(cam, true)
	_draw_nana(battle.player.pos - cam)
	_draw_aim(cam)
	_draw_hud()
	if hurt_flash > 0.0:
		var alpha: float = hurt_flash * (0.35 if settings.get("low_flash", false) else 0.8)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.95, 0.42, 0.29, alpha * 0.6))
	if battle.ult_active() and not settings.get("low_flash", false):
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.25, 0.12, 0.4, 0.12))


func _draw_ground(cam: Vector2, palette: Dictionary) -> void:
	_decorate(battle.region_id, battle.world)
	var tuft := Color(str(palette.get("tuft", "4a7a55")))
	for x in range(0, int(battle.world.x), 120):
		for y in range(0, int(battle.world.y), 120):
			var point := Vector2(x, y) - cam
			if Rect2(Vector2(-130, -130), size + Vector2(260, 260)).has_point(point):
				draw_circle(point, 53.0, Color(tuft.r, tuft.g, tuft.b, 0.12))
	for item: Dictionary in decorations:
		var pos: Vector2 = Vector2(item.pos) - cam
		if not Rect2(Vector2(-20, -20), size + Vector2(40, 40)).has_point(pos): continue
		var radius: float = float(item.size)
		draw_line(pos, pos + Vector2(-3, -radius * 2), tuft, 2, true)
		draw_line(pos, pos + Vector2(5, -radius), tuft, 2, true)
		if item.flower: draw_circle(pos + Vector2(-3, -radius * 2), 2.5, Color("c9bc8c"))
	var edge := Rect2(-cam + Vector2(14, 14), battle.world - Vector2(28, 28))
	draw_rect(edge, Color(str(palette.get("edge", "7a9b66"))), false, 12.0)


func _draw_obstacles(cam: Vector2, palette: Dictionary) -> void:
	var color := Color(str(palette.get("obstacle", "35593f")))
	for rect: Rect2 in battle.obstacles.rects:
		var shifted := Rect2(rect.position - cam, rect.size)
		draw_style_box(UI.panel(color, 18, 0), shifted)
		draw_rect(shifted.grow(-8), Color(color.lightened(0.18).r, color.lightened(0.18).g, color.lightened(0.18).b, 0.5), false, 3.0)
		for i in 5:
			var dot: Vector2 = shifted.position + Vector2(shifted.size.x * (0.15 + 0.17 * i), shifted.size.y * (0.35 + 0.3 * (i % 2)))
			draw_circle(dot, 6.0, Color("e7a6c4") if i % 2 == 0 else Color("f1d27a"))
	for circle: Dictionary in battle.obstacles.circles:
		var pos: Vector2 = Vector2(circle.center) - cam
		draw_circle(pos + Vector2(0, 8), float(circle.radius), Color(0, 0, 0, 0.18))
		draw_circle(pos, float(circle.radius), color)
		draw_arc(pos, float(circle.radius) - 6.0, 0, TAU, 40, color.lightened(0.2), 3.0, true)


func _draw_band(origin: Vector2, dir: Vector2, length: float, width: float, fill: Color, edge: Color) -> void:
	var side := dir.orthogonal() * width * 0.5
	var end := origin + dir * length
	draw_colored_polygon(PackedVector2Array([origin - side, end - side, end + side, origin + side]), fill)
	draw_polyline(PackedVector2Array([origin - side, end - side, end + side, origin + side, origin - side]), edge, 2.0, true)


func _draw_telegraph(e: Dictionary, cam: Vector2) -> void:
	var tele: Dictionary = e.get("tele", {})
	if tele.is_empty(): return
	var pos: Vector2 = e.pos - cam
	var total: float = maxf(0.01, float(e.get("windup_total", 1.0)))
	var progress: float = clampf(1.0 - float(e.timer) / total, 0.0, 1.0)
	var dim: bool = tele.get("dim", false)
	var fill := Color(1.0, 0.55, 0.3, (0.08 if dim else 0.12) + 0.18 * progress)
	var edge := Color(1.0, 0.75, 0.45, 0.45 if dim else 0.9)
	var dir: Vector2 = Vector2(tele.get("dir", e.dir))
	match str(tele.get("shape", "")):
		"sector":
			var reach: float = float(tele.reach)
			var half: float = deg_to_rad(float(tele.angle) * 0.5)
			var points := PackedVector2Array([pos])
			for i in 21: points.append(pos + dir.rotated(-half + 2.0 * half * i / 20.0) * reach)
			draw_colored_polygon(points, fill)
			draw_arc(pos, reach, dir.angle() - half, dir.angle() + half, 24, edge, 3.0, true)
			draw_arc(pos, reach * progress, dir.angle() - half, dir.angle() + half, 24, Color(1, 0.9, 0.6, 0.6), 2.0, true)
		"line", "fan":
			var length: float = float(tele.get("length", 200))
			if tele.shape == "fan":
				var spread: float = deg_to_rad(float(tele.angle))
				var count: int = maxi(1, int(tele.get("count", 3)))
				for i in count:
					var a: float = -spread * 0.5 + spread * i / maxf(1.0, count - 1.0)
					_draw_band(pos, dir.rotated(a), length, 14.0, fill, edge)
			else:
				_draw_band(pos, dir, length, float(tele.get("width", 30)), fill, edge)
				draw_line(pos, pos + dir * length * progress, Color(1, 0.9, 0.6, 0.8), 3.0, true)
		"circle":
			var center: Vector2 = Vector2(tele.get("pos", e.pos)) - cam
			draw_circle(center, float(tele.radius), fill)
			draw_arc(center, float(tele.radius), 0, TAU, 32, edge, 3.0, true)
			draw_arc(center, float(tele.radius) * progress, 0, TAU, 32, Color(1, 0.9, 0.6, 0.6), 2.0, true)
		"circles":
			for point in tele.points:
				var center: Vector2 = Vector2(point) - cam
				draw_circle(center, float(tele.radius), fill)
				draw_arc(center, float(tele.radius), 0, TAU, 32, edge, 3.0, true)
		"ring":
			var radius: float = float(tele.radius)
			var safe_dir: Vector2 = Vector2(tele.safe_dir)
			var half_safe: float = deg_to_rad(float(tele.safe) * 0.5)
			var points := PackedVector2Array([pos])
			var start: float = safe_dir.angle() + half_safe
			for i in 41: points.append(pos + Vector2.RIGHT.rotated(start + (TAU - 2.0 * half_safe) * i / 40.0) * radius)
			draw_colored_polygon(points, fill)
			draw_arc(pos, radius, start, start + TAU - 2.0 * half_safe, 40, edge, 3.0, true)
			var safe_points := PackedVector2Array([pos])
			for i in 11: safe_points.append(pos + Vector2.RIGHT.rotated(safe_dir.angle() - half_safe + 2.0 * half_safe * i / 10.0) * radius)
			draw_colored_polygon(safe_points, Color(0.5, 0.95, 0.7, 0.18))
			draw_string(bold, pos + safe_dir * radius * 0.6 + Vector2(-16, 8), "安全", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 1.0, 0.8))


func _draw_enemy(e: Dictionary, cam: Vector2) -> void:
	var pos: Vector2 = e.pos - cam
	if not Rect2(Vector2(-120, -120), size + Vector2(240, 240)).has_point(pos): return
	var spec: Dictionary = Data.shared().enemies[e.kind]
	var radius: float = float(e.radius)
	var body := Color(str(spec.get("color", "ac9acc")))
	if float(e.flash) > 0.0: body = UI.CREAM
	elif e.get("fleeing", false): body = body.darkened(0.35)
	if float(e.get("slow_t", 0.0)) > 0.0: body = body.lerp(Color("9deaff"), 0.3)
	draw_circle(pos + Vector2(0, radius * 0.45), radius, Color(0.03, 0.08, 0.06, 0.28))
	draw_circle(pos, radius + sin(clock * 4.0 + int(e.id)) * 1.0, body)
	if e.role in ["elite", "boss"]: draw_arc(pos, radius + 5.0, 0.0, TAU, 36, UI.GOLD, 3.0, true)
	if e.get("prey", false):
		draw_arc(pos, radius + 11.0, 0.0, TAU, 32, UI.PREY, 3.0, true)
		draw_string(bold, pos + Vector2(-8, -radius - 16), "◆", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UI.PREY)
	if e.get("marked", false):
		draw_arc(pos, radius + 17.0, clock * 3.0, clock * 3.0 + TAU * 0.75, 24, UI.SHADOW, 3.0, true)
	if int(e.get("shield_by", -1)) >= 0 and battle.by_id.has(int(e.shield_by)):
		var lantern: Dictionary = battle.by_id[int(e.shield_by)]
		draw_line(pos, lantern.pos - cam, Color(1.0, 0.92, 0.5, 0.5), 2.0, true)
		draw_arc(pos, radius + 7.0, 0, TAU, 24, Color(1.0, 0.92, 0.5, 0.8), 2.0, true)
	if e.ai == "chaser" and e.role == "hound":
		draw_colored_polygon(PackedVector2Array([pos + Vector2(-11, -10), pos + Vector2(-11, -24), pos + Vector2(-2, -14)]), Color("a84950"))
		draw_colored_polygon(PackedVector2Array([pos + Vector2(11, -10), pos + Vector2(11, -24), pos + Vector2(2, -14)]), Color("a84950"))
	draw_circle(pos + Vector2(-radius * 0.33, -2), 2.2, UI.INK)
	draw_circle(pos + Vector2(radius * 0.33, -2), 2.2, UI.INK)
	if str(e.phase) == "recover" and e.role != "fodder" and e.role != "hound":
		draw_string(bold, pos + Vector2(-18, -radius - (34 if e.get("prey", false) else 14)), "空檔", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9deaff"))
	if e.role == "boss": return
	if float(e.hp) < float(e.max_hp) and e.role != "fodder":
		var top: float = -radius - 8.0
		draw_line(pos + Vector2(-radius, top), pos + Vector2(radius, top), UI.INK, 4.0)
		draw_line(pos + Vector2(-radius, top), pos + Vector2(-radius + radius * 2.0 * float(e.hp) / float(e.max_hp), top), UI.GOLD, 3.0)


const ENEMY_FX := ["enemy_strike", "boss_phase"]


func _draw_effects(cam: Vector2, enemy_layer: bool) -> void:
	for fx: Dictionary in effects:
		if (str(fx.kind) in ENEMY_FX) != enemy_layer: continue
		var t: float = 1.0 - float(fx.life) / float(fx.max_life)
		var fade: float = 1.0 - t
		var pos: Vector2 = Vector2(fx.get("pos", fx.get("origin", Vector2.ZERO))) - cam
		match str(fx.kind):
			"swipe":
				var a: float = Vector2(fx.dir).angle()
				var half: float = float(fx.half)
				var color := Color(0.85, 0.75, 1.0, fade * (0.55 if int(fx.get("depth", 0)) == 0 else 0.35))
				for f: float in [0.7, 0.85, 1.0]:
					draw_arc(pos, float(fx.reach) * f, a - half, a + half, 24, color, 4.0 * fade + 1.0, true)
			"pounce":
				var end: Vector2 = pos + Vector2(fx.dir) * float(fx.dist)
				draw_line(pos, end, Color(0.8, 0.7, 1.0, fade * 0.3), 26.0 * fade + 2.0, true)
			"land": draw_arc(pos, 30.0 + 40.0 * t, 0, TAU, 28, Color(0.9, 0.85, 1.0, fade), 3.0, true)
			"bite":
				var color := UI.PREY if fx.get("prey", false) else Color(0.95, 0.85, 1.0)
				for i in 4:
					var angle := TAU * i / 4.0 + 0.4
					draw_line(pos + Vector2.RIGHT.rotated(angle) * (10.0 + 14.0 * t), pos + Vector2.RIGHT.rotated(angle) * (24.0 + 14.0 * t), Color(color.r, color.g, color.b, fade), 4.0, true)
			"wave", "ult", "burst":
				var radius: float = float(fx.get("radius", 100.0))
				var color := Color(0.8, 0.68, 1.0, fade * 0.9) if fx.kind == "ult" else Color(1.0, 0.85, 0.6, fade * 0.8)
				draw_arc(pos, radius * (0.3 + 0.7 * t), 0, TAU, 48, color, 6.0 * fade + 1.0, true)
			"line":
				var source: String = str(fx.get("source", "shadow"))
				var color := Color(0.5, 0.9, 1.0, fade * 0.18) if source == "shadow" else Color(1.0, 0.9, 0.6, fade * 0.18)
				_draw_band(Vector2(fx.origin) - cam, Vector2(fx.dir), float(fx.length), float(fx.width), color, Color(color.r, color.g, color.b, fade * 0.55))
			"defeat":
				var color := Color(str(fx.get("color", "ffffff")))
				color.a = fade
				for i in 6:
					draw_circle(pos + Vector2.RIGHT.rotated(i * TAU / 6.0 + float(fx.get("radius", 10))) * t * (24.0 + float(fx.get("radius", 10))), 3.5 * fade + 1.0, color)
			"hit": draw_circle(pos, 4.0 + 6.0 * t, Color(1, 1, 0.9, fade * 0.7))
			"enemy_strike":
				if fx.get("shape", "") == "sector":
					var a: float = Vector2(fx.dir).angle()
					draw_arc(pos, float(fx.reach), a - float(fx.half), a + float(fx.half), 24, Color(1.0, 0.5, 0.4, fade), 6.0, true)
				elif fx.get("shape", "") == "line":
					_draw_band(pos, Vector2(fx.dir), float(fx.length), float(fx.width), Color(1.0, 0.45, 0.35, fade * 0.35), Color(1.0, 0.6, 0.5, fade))
				elif fx.get("shape", "") == "ring":
					draw_arc(pos, float(fx.radius), 0, TAU, 48, Color(1.0, 0.5, 0.4, fade), 8.0, true)
			"heal": draw_string(bold, pos + Vector2(-10, -30 - 20 * t), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.6, 1.0, 0.7, fade))
			"mark", "cash": draw_arc(pos, 26.0 + 20.0 * t, 0, TAU, 24, Color(UI.SHADOW.r, UI.SHADOW.g, UI.SHADOW.b, fade), 3.0, true)
			"execute": draw_string(bold, pos + Vector2(-12, -30), "✕", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.5, 0.5, fade))
			"roam_charge", "refund": draw_arc(pos, 34.0 + 12.0 * t, -PI * 0.5, -PI * 0.5 + TAU * fade, 24, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, fade), 3.0, true)
			"boss_phase": draw_arc(pos, 60.0 + 160.0 * t, 0, TAU, 48, Color(1.0, 0.6, 0.4, fade), 5.0, true)


func _draw_nana(pos: Vector2) -> void:
	var facing: Vector2 = battle.player.facing
	if battle.dashing():
		var dash: Dictionary = battle.pounce.dash
		for i in 4:
			draw_circle(pos - Vector2(dash.dir) * (16.0 * (i + 1)), 22.0 - 4.0 * i, Color(0.55, 0.45, 0.75, 0.25 - 0.05 * i))
	draw_set_transform(pos)
	draw_circle(Vector2(0, 17), 27.0, Color(0.02, 0.09, 0.055, 0.4))
	if battle.ult_active():
		draw_circle(Vector2.ZERO, 40.0, Color(0.59, 0.42, 0.82, 0.22))
		draw_arc(Vector2.ZERO, 38.0, 0, TAU, 32, Color(0.82, 0.70, 1.0, 0.9), 2.5, true)
	var blink: bool = float(battle.player.invuln) > 0.0 and not battle.dashing() and int(clock * 16.0) % 2 == 0
	var fur: Color = Color("807a94") if blink else Color("25232d")
	draw_arc(Vector2(-27, 7), 16.0, -PI * 0.55, PI * 0.6, 20, fur, 8.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-21, -12), Vector2(-20, -34), Vector2(-5, -23)]), fur)
	draw_colored_polygon(PackedVector2Array([Vector2(21, -12), Vector2(20, -34), Vector2(5, -23)]), fur)
	draw_circle(Vector2.ZERO, 26.0, Color("b3a7c2"))
	draw_circle(Vector2.ZERO, 23.5, fur)
	var face: Vector2 = facing * 7.0
	var eyes: Vector2 = facing.orthogonal() * 8.0
	for side: float in [-1.0, 1.0]:
		var eye: Vector2 = face + facing * 4.0 + eyes * side
		draw_circle(eye, 3.5, Color("eddb8f"))
		draw_circle(eye + facing, 1.5, Color("201d28"))
	draw_circle(face + facing * 13.0, 2.5, Color("efb0b4"))
	draw_set_transform(Vector2.ZERO)
	var charges: int = int(battle.pounce.charges)
	var cap: int = battle.max_charges() + int(battle.stats.value("roam_overcap"))
	for i in cap:
		var marker: Vector2 = pos + Vector2(-8.0 * (cap - 1) + 16.0 * i, -46.0)
		draw_circle(marker, 5.0, UI.GOLD if i < charges else Color("4a4656"))


func _draw_aim(cam: Vector2) -> void:
	var dir := Vector2.ZERO
	if touch != null and touch.aiming(): dir = touch.aim_direction()
	elif mouse_aiming:
		var offset: Vector2 = aim_mouse - (battle.player.pos - cam)
		if offset.length() > 24.0: dir = offset.normalized()
	if dir == Vector2.ZERO: return
	var from: Vector2 = battle.player.pos - cam
	var distance: float = float(Data.shared().tuning.pounce.distance) * (1.0 + battle.stats.value("pounce_distance_pct") / 100.0)
	var ready: bool = int(battle.pounce.charges) >= 1
	var color := Color(1.0, 0.85, 0.5, 0.85) if ready else Color(0.7, 0.7, 0.7, 0.5)
	var end: Vector2 = from + dir * distance
	for i in 10:
		var a: Vector2 = from.lerp(end, i / 10.0)
		var b: Vector2 = from.lerp(end, (i + 0.55) / 10.0)
		draw_line(a, b, color, 4.0, true)
	draw_arc(end, battle.bite_radius(), 0, TAU, 32, Color(color.r, color.g, color.b, 0.6), 2.0, true)


func _draw_hud() -> void:
	var player: Dictionary = battle.player
	draw_style_box(UI.panel(Color(0.06, 0.16, 0.12, 0.88), 16, 0), Rect2(20, 18, 300, 92))
	draw_string(bold, Vector2(36, 46), "奈奈", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, UI.CREAM)
	draw_string(font, Vector2(190, 46), "%d / %d" % [ceili(float(player.hp)), int(player.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.MUTED)
	draw_rect(Rect2(36, 56, 268, 10), Color("18382c"))
	draw_rect(Rect2(36, 56, 268 * clampf(float(player.hp) / float(player.max_hp), 0.0, 1.0), 10), Color("e9a47c"))
	if run != null:
		var need: int = run.xp_needed()
		draw_string(font, Vector2(36, 90), "Lv.%d" % run.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.GOLD)
		draw_rect(Rect2(92, 82, 212, 7), Color("345b47"))
		if need > 0: draw_rect(Rect2(92, 82, 212 * minf(1.0, float(run.xp) / need), 7), UI.GOLD)
		draw_string(font, Vector2(36, 134), "小魚乾 %d" % run.fish, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.MUTED)
	var titles := {"hunt": "狩獵", "den": "獵物巢", "boss": "守關", "practice": "練習場"}
	var info: String = titles.get(battle.kind, "")
	var remaining: int = battle.remaining_targets()
	if battle.kind in ["hunt", "den"] and battle.state == "playing": info += " · 目標獵物 ◆ 還剩 %d" % remaining
	if battle.kind == "practice": info += " · 剩 %d 秒" % maxi(0, int(ceilf(float(Data.shared().spawns.practice.duration) - battle.elapsed)))
	draw_string(bold, Vector2(size.x * 0.5 - 170, 44), info, HORIZONTAL_ALIGNMENT_CENTER, 340, 20, UI.CREAM)
	draw_string(font, Vector2(size.x * 0.5 - 40, 68), "%d:%02d" % [int(battle.elapsed) / 60, int(battle.elapsed) % 60], HORIZONTAL_ALIGNMENT_CENTER, 80, 15, UI.MUTED)
	var boss: Dictionary = battle.boss()
	if not boss.is_empty():
		var width := 420.0
		var left: float = size.x * 0.5 - width * 0.5
		draw_string(bold, Vector2(left, 92), str(Data.shared().enemies[boss.kind].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.GOLD)
		draw_rect(Rect2(left, 100, width, 10), Color("452d31"))
		draw_rect(Rect2(left, 100, width * float(boss.hp) / float(boss.max_hp), 10), Color("e37b76"))
		var spec: Dictionary = Data.shared().enemies[boss.kind]
		var last: float = float(battle.mods.get("boss_phase2", spec.get("phase2", 0.3)))
		for mark: float in [float(spec.get("phase1", 0.6)), last]:
			draw_line(Vector2(left + width * mark, 97), Vector2(left + width * mark, 113), UI.CREAM, 2.0)
	if net_banner > 0.0:
		draw_string(bold, Vector2(size.x * 0.5 - 150, size.y * 0.32), "收網！", HORIZONTAL_ALIGNMENT_CENTER, 300, 44, Color(UI.GOLD.r, UI.GOLD.g, UI.GOLD.b, minf(1.0, net_banner)))
	if hint_time > 0.0 and not hint.is_empty():
		var alpha: float = minf(1.0, hint_time)
		draw_style_box(UI.panel(Color(0.05, 0.12, 0.09, 0.82 * alpha), 14, 0), Rect2(size.x * 0.5 - 330, 128, 660, 46))
		draw_string(font, Vector2(size.x * 0.5 - 320, 158), hint, HORIZONTAL_ALIGNMENT_CENTER, 640, 19, Color(UI.CREAM.r, UI.CREAM.g, UI.CREAM.b, alpha))
	_draw_sticks()


func _draw_sticks() -> void:
	if touch == null: return
	var left: Vector2 = touch.move_origin if touch.move_id != -1 else Vector2(130, size.y - 130)
	var right: Vector2 = touch.aim_origin if touch.aim_id != -1 else Vector2(size.x - 130, size.y - 130)
	var radius: float = touch.radius
	for center: Vector2 in [left, right]:
		draw_circle(center, radius - 6.0, Color(0.91, 0.95, 0.78, 0.04))
		draw_arc(center, radius - 6.0, 0, TAU, 48, Color(0.91, 0.95, 0.78, 0.2), 1.5, true)
	var move_delta: Vector2 = (touch.move_point - left).limit_length(radius * 0.66) if touch.move_id != -1 else Vector2.ZERO
	var aim_delta: Vector2 = (touch.aim_point - right).limit_length(radius * 0.66) if touch.aim_id != -1 else Vector2.ZERO
	draw_circle(left + move_delta, 22, Color(0.94, 0.88, 0.68, 0.2))
	draw_circle(right + aim_delta, 22, Color(1.0, 0.8, 0.4, 0.25))
	draw_string(font, left + Vector2(-17, radius + 22), "移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.MUTED)
	draw_string(font, right + Vector2(-48, radius + 22), "拖曳放開撲擊", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.MUTED)
