extends Control
## Battle HUD and screen effects: health with a damage ghost, level, fish counter with fly-in icons,
## target icons, boss bar, combo counter, off-screen markers for prey/elites/bosses, pounce pips by
## the right thumb, the night-shadow ring, banners, flashes, vignettes and a debug frame-time line.

const UI := preload("res://scripts/x1/ui/theme.gd")
const Data := preload("res://scripts/x1/core/data.gd")
const INK := Color(0.07, 0.05, 0.1)

var battle = null
var run = null
var touch = null
var colors: Dictionary = {}
var settings: Dictionary = {}
var world_xf := Transform2D.IDENTITY
var ult_rect := Rect2()
var clock := 0.0
var hp_ghost := 100.0
var hp_shake := 0.0
var boss_ghost := 1.0
var fish_shown := 0.0
var fish_bump := 0.0
var flyers: Array = []          # {from, life, max}
var combo := 0
var combo_tier := {}
var combo_bump := 0.0
var combo_fade := 0.0
var combo_broken := 0.0
var combo_rank := 0.0            # 1 → 0 after reaching a new combo tier
var level_pop := 0.0             # 1 → 0 after a level-up
var banners: Array = []          # {text, sub, color, life, max, big}
var flash := {}                  # {color, life, max}
var hurt_t := 0.0
var low_hp := false
var beat := 0.0
var hint := ""
var hint_time := 0.0
var level_glow := 0.0
var pip_flash := 0.0
var empty_flash := 0.0      # a released pounce found no charge: the arc shakes red with a word
var last_charges := 0
var perf_text := ""
var font: Font
var bold: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = UI.font(false)
	bold = UI.font(true)
	colors = Data.shared().feel.get("colors", {})


func col(name: String) -> Color:
	return Color(str(colors.get(name, "ffffff")))


func reset_battle(b, r) -> void:
	battle = b
	run = r
	flyers.clear()
	banners.clear()
	flash = {}
	combo = 0
	combo_fade = 0.0
	hurt_t = 0.0
	empty_flash = 0.0
	if b != null:
		hp_ghost = float(b.player.hp)
		last_charges = int(b.pounce.charges)
	if r != null: fish_shown = float(r.fish)


func show_hint(text: String, seconds := 4.0) -> void:
	hint = text
	hint_time = seconds


func banner(text: String, sub := "", color_name := "cream", seconds := 1.4, big := true) -> void:
	banners.append({"text": text, "sub": sub, "color": col(color_name), "life": seconds, "max": seconds, "big": big})
	if banners.size() > 3: banners.pop_front()


## Screen y that world words should stay below: the HUD strip, or under a banner while one shows.
func reserved_top() -> float:
	var top := 130.0
	for b: Dictionary in banners:
		top = maxf(top, size.y * (0.26 if b.big else 0.34) + 50.0)
	return top


func screen_flash(color_name: String, strength := 1.0) -> void:
	var a: float = strength * (0.35 if settings.get("low_flash", false) else 1.0)
	flash = {"color": col(color_name), "life": 0.22, "max": 0.22, "alpha": a}


func hurt(from_screen: Vector2) -> void:
	hurt_t = 1.0
	hp_shake = 1.0


func fly_fish(from_screen: Vector2) -> void:
	flyers.append({"from": from_screen, "life": 0.7, "max": 0.7})


func set_combo(count: int, tier: Dictionary) -> void:
	if count > combo: combo_bump = 1.0
	combo = count
	combo_tier = tier
	combo_fade = 2.0


## A new combo tier: the counter swells, flashes and throws rays instead of a screen banner.
func combo_tier_up() -> void:
	combo_rank = 1.0
	combo_bump = 1.0


func level_up() -> void:
	level_pop = 1.0


func pounce_empty() -> void:
	empty_flash = 1.0


func break_combo() -> void:
	if combo >= 5: combo_broken = 0.8
	combo = 0


func _process(delta: float) -> void:
	clock += delta
	hint_time = maxf(0.0, hint_time - delta)
	hurt_t = maxf(0.0, hurt_t - delta * 2.5)
	hp_shake = maxf(0.0, hp_shake - delta * 4.0)
	fish_bump = maxf(0.0, fish_bump - delta * 4.0)
	combo_bump = maxf(0.0, combo_bump - delta * 5.0)
	combo_fade = maxf(0.0, combo_fade - delta)
	combo_broken = maxf(0.0, combo_broken - delta)
	combo_rank = maxf(0.0, combo_rank - delta * 1.4)
	level_pop = maxf(0.0, level_pop - delta * 1.2)
	level_glow = maxf(0.0, level_glow - delta)
	pip_flash = maxf(0.0, pip_flash - delta * 3.0)
	empty_flash = maxf(0.0, empty_flash - delta * 1.4)
	if not flash.is_empty():
		flash.life = float(flash.life) - delta
		if float(flash.life) <= 0.0: flash = {}
	for list: Array in [banners, flyers]:
		for i in range(list.size() - 1, -1, -1):
			list[i].life = float(list[i].life) - delta
			if float(list[i].life) <= 0.0:
				if list == flyers: fish_bump = 1.0
				list.remove_at(i)
	if battle != null:
		var hp: float = float(battle.player.hp)
		hp_ghost = hp if hp > hp_ghost else move_toward(hp_ghost, hp, delta * 40.0 * (1.0 if hp_shake <= 0.0 else 0.0) + delta * 8.0)
		var ratio: float = hp / maxf(1.0, float(battle.player.max_hp))
		low_hp = ratio < float(Data.shared().feel.get("low_hp", {}).get("ratio", 0.3)) and battle.state == "playing"
		var boss: Dictionary = battle.boss()
		if not boss.is_empty(): boss_ghost = move_toward(boss_ghost, float(boss.hp) / float(boss.max_hp), delta * 0.25)
		var charges: int = int(battle.pounce.charges)
		if charges > last_charges: pip_flash = 1.0
		last_charges = charges
	if run != null:
		fish_shown = move_toward(fish_shown, float(run.fish), delta * 30.0)
		if run.xp_needed() > 0 and float(run.xp) / run.xp_needed() > 0.8: level_glow = 0.3
	queue_redraw()


var draw_ms := 0.0


func _draw() -> void:
	if battle == null: return
	var t0 := Time.get_ticks_usec()
	_draw_all()
	draw_ms = lerpf(draw_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.1)


func _draw_all() -> void:
	_draw_screen_fx()
	_draw_status()
	_draw_center()
	_draw_combo()
	_draw_markers()
	_draw_controls()
	_draw_banners()
	_draw_flyers()
	if not perf_text.is_empty():
		draw_string(font, Vector2(20, size.y - 12), perf_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))


func _draw_screen_fx() -> void:
	if battle.ult_active() and not settings.get("low_flash", false):
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.18, 0.08, 0.32, 0.16))
	var edge := 0.0
	var edge_col := col("hurt")
	if hurt_t > 0.0: edge = hurt_t * 0.55
	if low_hp:
		beat += get_process_delta_time()
		var period: float = float(Data.shared().feel.get("low_hp", {}).get("beat", 0.9))
		var phase: float = fmod(clock, period) / period
		edge = maxf(edge, 0.18 + 0.22 * maxf(0.0, 1.0 - phase * 3.0))
	if battle.ult_active():
		edge = maxf(edge, 0.25)
		edge_col = col("night")
	if edge > 0.0:
		var w := 90.0
		for i in 6:
			var inset := i * w / 6.0
			var a: float = edge * (1.0 - i / 6.0) * 0.5
			draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), Color(edge_col.r, edge_col.g, edge_col.b, a), false, w / 6.0)
	if not flash.is_empty():
		var t: float = float(flash.life) / float(flash.max)
		var c: Color = flash.color
		c.a = t * 0.55 * float(flash.alpha)
		draw_rect(Rect2(Vector2.ZERO, size), c)


func _bar(rect: Rect2, ratio: float, ghost: float, fill: Color, back := Color("18382c")) -> void:
	draw_style_box(UI.panel(INK, 6, 0), rect.grow(2))
	draw_style_box(UI.panel(back, 5, 0), rect)
	if ghost > ratio: draw_style_box(UI.panel(Color(1, 1, 1, 0.85), 5, 0), Rect2(rect.position, Vector2(rect.size.x * clampf(ghost, 0.0, 1.0), rect.size.y)))
	if ratio > 0.0:
		draw_style_box(UI.panel(fill, 5, 0), Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)))
		draw_rect(Rect2(rect.position + Vector2(3, 2), Vector2(rect.size.x * clampf(ratio, 0.0, 1.0) - 6, 3)), Color(1, 1, 1, 0.25))


func _draw_status() -> void:
	var p: Dictionary = battle.player
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * hp_shake
	var origin := Vector2(22, 18) + shake
	draw_style_box(UI.panel(Color(0.05, 0.12, 0.1, 0.82), 16, 0), Rect2(origin, Vector2(310, 96)))
	draw_string(bold, origin + Vector2(16, 30), "奈奈", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col("cream"))
	draw_string(font, origin + Vector2(176, 30), "%d / %d" % [ceili(float(p.hp)), int(p.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.85, 0.9, 0.85))
	var hp_col := Color("e9a47c") if not low_hp else Color("ff5f5f").lerp(Color("e9a47c"), 0.5 + 0.5 * sin(clock * 9.0))
	_bar(Rect2(origin + Vector2(16, 40), Vector2(276, 12)), float(p.hp) / float(p.max_hp), hp_ghost / float(p.max_hp), hp_col)
	if run != null:
		var need: int = run.xp_needed()
		var lv_size := int(17.0 * (1.0 + 0.5 * ease(level_pop, 2.0)))
		if level_pop > 0.0:
			var glow := col("prey")
			glow.a = level_pop * 0.8
			draw_arc(origin + Vector2(38, 74), 14.0 + 30.0 * ease(1.0 - level_pop, 0.4), 0.0, TAU, 32, glow, 3.0 * level_pop + 1.0, true)
		draw_string_outline(bold, origin + Vector2(16, 80), "Lv.%d" % run.level, HORIZONTAL_ALIGNMENT_LEFT, -1, lv_size, 4, INK)
		draw_string(bold, origin + Vector2(16, 80), "Lv.%d" % run.level, HORIZONTAL_ALIGNMENT_LEFT, -1, lv_size, col("prey") if level_pop <= 0.0 else Color.WHITE.lerp(col("prey"), 1.0 - level_pop))
		var xp_col := col("prey") if level_glow <= 0.0 else col("prey").lightened(0.3 + 0.2 * sin(clock * 14.0))
		_bar(Rect2(origin + Vector2(76, 68), Vector2(216, 8)), float(run.xp) / maxf(1.0, need) if need > 0 else 1.0, 0.0, xp_col, Color("2c4f3e"))
		var fish_pos := _fish_anchor()
		var s := 1.0 + fish_bump * 0.35
		draw_set_transform(fish_pos, 0.0, Vector2.ONE * s)
		_fish_icon(Vector2.ZERO, 1.0)
		draw_string(bold, Vector2(18, 7), "%d" % int(round(fish_shown)), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col("cream"))
		draw_set_transform(Vector2.ZERO)


func _fish_anchor() -> Vector2:
	return Vector2(40, 140)


func _fish_icon(pos: Vector2, alpha: float) -> void:
	var c := Color(0.55, 0.8, 0.95, alpha)
	UI_ellipse(pos, 11.0, 6.0, c)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-9, 0), pos + Vector2(-17, -6), pos + Vector2(-17, 6)]), c)
	draw_circle(pos + Vector2(5, -1), 1.6, INK)


func UI_ellipse(center: Vector2, rx: float, ry: float, c: Color) -> void:
	var points := PackedVector2Array()
	for i in 16: points.append(center + Vector2(cos(TAU * i / 16.0) * rx, sin(TAU * i / 16.0) * ry))
	draw_colored_polygon(points, c)


func _draw_center() -> void:
	var titles := {"hunt": "狩獵", "den": "獵物巢", "boss": "守關", "practice": "練習場"}
	var cx := size.x * 0.5
	draw_string_outline(bold, Vector2(cx - 120, 40), titles.get(battle.kind, ""), HORIZONTAL_ALIGNMENT_CENTER, 240, 22, 6, INK)
	draw_string(bold, Vector2(cx - 120, 40), titles.get(battle.kind, ""), HORIZONTAL_ALIGNMENT_CENTER, 240, 22, col("cream"))
	draw_string(font, Vector2(cx - 40, 62), "%d:%02d" % [int(battle.elapsed) / 60, int(battle.elapsed) % 60], HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Color(0.8, 0.88, 0.8))
	var total: int = int(battle.spawner.targets_total)
	if total > 0 and battle.kind != "boss":
		var killed: int = int(battle.spawner.targets_killed)
		var w := 30.0
		var start := cx - w * total * 0.5 + w * 0.5
		for i in total:
			var p := Vector2(start + i * w, 84)
			var done := i < killed
			var diamond := PackedVector2Array([p + Vector2(0, -10), p + Vector2(9, 0), p + Vector2(0, 10), p + Vector2(-9, 0)])
			draw_colored_polygon(diamond, col("prey") if done else Color(0.2, 0.18, 0.12, 0.8))
			draw_polyline(diamond + PackedVector2Array([p + Vector2(0, -10)]), col("prey"), 2.0, true)
			if done: draw_string(bold, p + Vector2(-6, 6), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, INK)
	var boss: Dictionary = battle.boss()
	if not boss.is_empty():
		var width := minf(520.0, size.x * 0.4)
		var left := cx - width * 0.5
		var spec: Dictionary = Data.shared().enemies[boss.kind]
		draw_string_outline(bold, Vector2(left, 92), str(spec.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, INK)
		draw_string(bold, Vector2(left, 92), str(spec.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, col("prey"))
		_bar(Rect2(left, 100, width, 12), float(boss.hp) / float(boss.max_hp), boss_ghost, Color("e3615a"), Color("3a2226"))
		var last: float = float(battle.mods.get("boss_phase2", spec.get("phase2", 0.3)))
		for mark: float in [float(spec.get("phase1", 0.6)), last]:
			draw_line(Vector2(left + width * mark, 96), Vector2(left + width * mark, 116), col("cream"), 2.0)
	if hint_time > 0.0 and not hint.is_empty():
		var a := minf(1.0, hint_time)
		draw_style_box(UI.panel(Color(0.04, 0.1, 0.08, 0.86 * a), 14, 0), Rect2(cx - 340, 128, 680, 48))
		draw_string(font, Vector2(cx - 330, 159), hint, HORIZONTAL_ALIGNMENT_CENTER, 660, 19, Color(1, 0.96, 0.86, a))


func _draw_combo() -> void:
	var show_broken := combo_broken > 0.0
	if combo < 3 and not show_broken: return
	if combo_fade <= 0.0 and not show_broken: return
	var anchor := Vector2(size.x - 150, 120)
	if show_broken:
		var a := combo_broken / 0.8
		draw_string_outline(bold, anchor + Vector2(0, 40), "斷", HORIZONTAL_ALIGNMENT_CENTER, 120, 40, 7, Color(0, 0, 0, a))
		draw_string(bold, anchor + Vector2(0, 40), "斷", HORIZONTAL_ALIGNMENT_CENTER, 120, 40, Color(1, 0.4, 0.4, a))
		for k in 4: draw_line(anchor + Vector2(60, 25), anchor + Vector2(60, 25) + Vector2.RIGHT.rotated(k * 1.6 + 0.4) * 46.0 * (1.0 - a * 0.5), Color(1, 0.5, 0.5, a), 2.0, true)
		return
	var tier_col: Color = Color(str(combo_tier.get("color", "fff2d4")))
	var alpha := minf(1.0, combo_fade)
	var s := 1.0 + combo_bump * 0.4 + ease(combo_rank, 3.0) * 0.6
	var center := anchor + Vector2(60, 30)
	if combo_rank > 0.0:
		var spread: float = 1.0 - combo_rank
		var ray := Color(tier_col.r, tier_col.g, tier_col.b, combo_rank * 0.8)
		for k in 12:
			var a: float = TAU * k / 12.0 + clock * 0.8
			var dir := Vector2.RIGHT.rotated(a)
			draw_line(center + dir * (34.0 + 30.0 * spread), center + dir * (52.0 + 60.0 * spread), ray, 3.0, true)
		draw_circle(center, 40.0 + 24.0 * spread, Color(tier_col.r, tier_col.g, tier_col.b, combo_rank * 0.25))
	draw_set_transform(center, (sin(clock * 20.0) * 0.04 * combo_bump), Vector2.ONE * s)
	var label := "×%d" % combo
	draw_string_outline(bold, Vector2(-60, 12), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 40, 8, Color(0, 0, 0, alpha))
	draw_string(bold, Vector2(-60, 12), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 40, Color(tier_col.r, tier_col.g, tier_col.b, alpha))
	var name: String = str(combo_tier.get("name", "連獵"))
	var name_col := Color(tier_col.r, tier_col.g, tier_col.b, alpha)
	if combo_rank > 0.0: name_col = name_col.lerp(Color(1, 1, 1, alpha), combo_rank * 0.7)
	draw_string_outline(bold, Vector2(-60, 38), name, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, 5, Color(0, 0, 0, alpha))
	draw_string(bold, Vector2(-60, 38), name, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, name_col)
	draw_set_transform(Vector2.ZERO)


func _draw_markers() -> void:
	var rect := Rect2(Vector2.ZERO, size).grow(-46.0)
	var center := size * 0.5
	var shown := 0
	for e: Dictionary in battle.enemies:
		if not (e.get("prey", false) or e.role in ["elite", "boss"]) or shown >= 8: continue
		var screen: Vector2 = world_xf * Vector2(e.pos)
		if Rect2(Vector2.ZERO, size).grow(-10.0).has_point(screen): continue
		shown += 1
		var dir := (screen - center).normalized()
		var tx := INF
		var ty := INF
		if absf(dir.x) > 0.001: tx = (rect.size.x * 0.5) / absf(dir.x)
		if absf(dir.y) > 0.001: ty = (rect.size.y * 0.5) / absf(dir.y)
		var p := center + dir * minf(tx, ty)
		var danger: bool = e.role in ["elite", "boss"]
		var c: Color = col("danger") if danger else col("prey")
		var pulse := 1.0 + 0.12 * sin(clock * 8.0)
		var tip := p + dir * 18.0 * pulse
		var side := dir.orthogonal() * 12.0 * pulse
		draw_colored_polygon(PackedVector2Array([tip + dir * 3.0, p - side, p + side]), INK)
		draw_colored_polygon(PackedVector2Array([tip, p - side * 0.8, p + side * 0.8]), c)
		draw_circle(p - dir * 14.0, 13.0, INK)
		draw_circle(p - dir * 14.0, 11.0, c.darkened(0.2))
		draw_string(bold, p - dir * 14.0 + Vector2(-7, 7), "◆" if not danger else "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK if not danger else col("cream"))


func _draw_controls() -> void:
	if touch == null: return
	var left: Vector2 = touch.move_origin if touch.move_id != -1 else Vector2(130, size.y - 130)
	var right: Vector2 = touch.aim_origin if touch.aim_id != -1 else Vector2(size.x - 130, size.y - 130)
	var radius: float = touch.radius
	for center: Vector2 in [left, right]:
		draw_circle(center, radius - 6.0, Color(0.91, 0.95, 0.78, 0.05))
		draw_arc(center, radius - 6.0, 0, TAU, 48, Color(0.91, 0.95, 0.78, 0.22), 1.5, true)
	var move_delta: Vector2 = (touch.move_point - left).limit_length(radius * 0.66) if touch.move_id != -1 else Vector2.ZERO
	var aim_delta: Vector2 = (touch.aim_point - right).limit_length(radius * 0.66) if touch.aim_id != -1 else Vector2.ZERO
	draw_circle(left + move_delta, 22, Color(0.94, 0.88, 0.68, 0.22))
	draw_circle(right + aim_delta, 22, Color(1.0, 0.8, 0.4, 0.3) if touch.aiming() else Color(1.0, 0.8, 0.4, 0.18))
	draw_string(font, left + Vector2(-17, radius + 22), "移動", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.85, 0.75))
	draw_string(font, right + Vector2(-48, radius + 22), "拖曳放開撲擊", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.75, 0.85, 0.75))
	# Pounce charges arc around the right thumb.
	var cap: int = battle.max_charges() + int(battle.stats.value("roam_overcap"))
	var charges: int = int(battle.pounce.charges)
	var recharge: float = float(battle.pounce.recharge) / maxf(0.01, battle.recharge_time())
	var arc_center := right + Vector2(sin(clock * 70.0) * 5.0 * empty_flash, 0.0)
	for i in cap:
		var a0 := -PI * 0.92 + i * 0.32
		var full := i < charges
		var c := col("prey") if full else Color(0.3, 0.28, 0.25, 0.8)
		if full and pip_flash > 0.0 and i == charges - 1: c = c.lightened(pip_flash * 0.6)
		if not full and empty_flash > 0.0: c = c.lerp(col("danger"), empty_flash)
		draw_arc(arc_center, radius + 8.0, a0, a0 + 0.26, 8, INK, 11.0, true)
		draw_arc(arc_center, radius + 8.0, a0, a0 + 0.26, 8, c, 7.0, true)
		if i == charges and charges < battle.max_charges():
			draw_arc(arc_center, radius + 8.0, a0, a0 + 0.26 * recharge, 8, Color(col("prey").r, col("prey").g, col("prey").b, 0.55), 7.0, true)
	if empty_flash > 0.0:
		var word := "撲擊次數用完"
		var at := arc_center + Vector2(-54, -radius - 26)
		draw_string_outline(bold, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(INK, empty_flash))
		draw_string(bold, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(col("danger"), empty_flash))
	# Night shadow ring on the ult button.
	if ult_rect.size.x > 0.0:
		var c2 := ult_rect.get_center()
		var r := minf(ult_rect.size.x, ult_rect.size.y) * 0.5
		var meter: float = float(battle.ult.meter) / float(Data.shared().tuning.ult.meter_max)
		var night := col("night")
		var ready: bool = battle.ult_ready()
		var active: bool = battle.ult_active()
		if ready:
			var pulse := 0.5 + 0.5 * sin(clock * 6.0)
			draw_circle(c2, r + 10.0 + pulse * 4.0, Color(night.r, night.g, night.b, 0.25 + 0.2 * pulse))
		draw_circle(c2, r + 2.0, INK)
		draw_circle(c2, r - 2.0, Color(0.2, 0.14, 0.3, 0.92) if not ready else night.darkened(0.25))
		var fill := meter if not active else float(battle.ult.active) / maxf(0.1, float(Data.shared().tuning.ult.duration) + battle.stats.value("ult_duration"))
		draw_arc(c2, r - 4.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 48, night.lightened(0.2) if not active else col("shadow"), 6.0, true)
		var label := "夜影" if not active else "影化"
		draw_string_outline(bold, c2 + Vector2(-r, 2), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 20, 5, INK)
		draw_string(bold, c2 + Vector2(-r, 2), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 20, col("cream"))
		var sub := "準備好了！" if ready else ("%.1f 秒" % float(battle.ult.active) if active else "%d%%" % int(meter * 100.0))
		draw_string(font, c2 + Vector2(-r, 24), sub, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 14, col("cream"))


func _draw_banners() -> void:
	for i in banners.size():
		var b: Dictionary = banners[i]
		var t: float = 1.0 - float(b.life) / float(b.max)
		var enter: float = clampf(t / 0.15, 0.0, 1.0)
		var leave: float = clampf((1.0 - t) / 0.2, 0.0, 1.0)
		var a: float = minf(enter, leave)
		var x_off: float = (1.0 - ease(enter, 0.3)) * -120.0 + (1.0 - leave) * 120.0
		var y: float = size.y * (0.26 if b.big else 0.34) + i * 8.0
		var size_px := 48 if b.big else 30
		var c: Color = b.color
		c.a = a
		var half: float = minf(size.x * 0.32, 340.0)
		var top: float = y - size_px * 0.95
		var bottom: float = y + (36.0 if not str(b.sub).is_empty() else size_px * 0.35)
		var shade := Color(0.02, 0.02, 0.05, 0.5 * a)
		var clear := Color(0.02, 0.02, 0.05, 0.0)
		var cx := size.x * 0.5
		for side: float in [-1.0, 1.0]:
			draw_polygon(PackedVector2Array([Vector2(cx, top), Vector2(cx + side * half, top), Vector2(cx + side * half, bottom), Vector2(cx, bottom)]),
				PackedColorArray([shade, clear, clear, shade]))
		draw_line(Vector2(cx - half * 0.7, top), Vector2(cx + half * 0.7, top), Color(c.r, c.g, c.b, a * 0.5), 2.0, true)
		draw_line(Vector2(cx - half * 0.7, bottom), Vector2(cx + half * 0.7, bottom), Color(c.r, c.g, c.b, a * 0.5), 2.0, true)
		draw_string_outline(bold, Vector2(x_off, y), str(b.text), HORIZONTAL_ALIGNMENT_CENTER, size.x, size_px, 9, Color(0, 0, 0, a))
		draw_string(bold, Vector2(x_off, y), str(b.text), HORIZONTAL_ALIGNMENT_CENTER, size.x, size_px, c)
		if not str(b.sub).is_empty():
			draw_string_outline(font, Vector2(x_off, y + 28), str(b.sub), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, 4, Color(0, 0, 0, a * 0.8))
			draw_string(font, Vector2(x_off, y + 28), str(b.sub), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(1, 1, 1, a * 0.9))


func _draw_flyers() -> void:
	var target := _fish_anchor()
	for f: Dictionary in flyers:
		var t: float = 1.0 - float(f.life) / float(f.max)
		var e := ease(t, -2.0)
		var from: Vector2 = f.from
		var mid := (from + target) * 0.5 + Vector2(0, -160)
		var p := from.lerp(mid, e).lerp(mid.lerp(target, e), e)
		_fish_icon(p, 1.0)
