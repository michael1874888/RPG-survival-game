extends Control
## The night patrol map: layers left to right, links, the path so far and the reachable nodes.
## Nana's head walks along the link to the chosen node; reachable nodes bob, the boss pulses.

const UI := preload("res://scripts/x1/ui/theme.gd")

const NAMES := {"hunt": "狩獵", "den": "獵物巢", "bed": "貓窩", "shop": "主人房間", "moon": "月光", "boss": "守關"}
const COLORS := {"hunt": Color("5b8a6a"), "den": Color("b0606a"), "bed": Color("6a7fb0"), "shop": Color("b08a4e"),
	"moon": Color("8a6ab0"), "boss": Color("c2454f")}
const WALK_TIME := 0.5

var run = null
var audio = null
var on_pick: Callable
var positions: Dictionary = {}
var buttons: Dictionary = {}
var token := Vector2.ZERO
var walking := false
var walk_from := Vector2.ZERO
var walk_to := Vector2.ZERO
var walk_t := 0.0
var walk_done: Callable
var hops := 0
var t := 0.0


func build(run_ref, callback: Callable) -> void:
	run = run_ref
	on_pick = callback
	custom_minimum_size = Vector2(860, 560)
	for child in get_children(): child.queue_free()
	positions.clear()
	buttons.clear()
	var rows: Array = run.map.rows
	var columns: int = rows.size() + 1
	var step_x: float = 770.0 / maxf(1.0, columns - 1)
	for layer in rows.size():
		var row: Array = rows[layer]
		for i in row.size():
			positions[row[i]] = Vector2(75.0 + step_x * layer, 280.0 + (i - (row.size() - 1) * 0.5) * 150.0)
	positions["boss"] = Vector2(75.0 + step_x * rows.size(), 280.0)
	token = positions.get(run.at, Vector2(20.0, 280.0)) if not run.at.is_empty() else Vector2(20.0, 280.0)
	var available: Array = run.available_nodes()
	for id: String in positions:
		var node: Dictionary = run.map.nodes[id]
		var button := Button.new()
		button.text = NAMES.get(node.kind, node.kind)
		button.focus_mode = Control.FOCUS_NONE
		button.size = Vector2(98, 54)
		button.position = Vector2(positions[id]) - Vector2(49, 27)
		button.pivot_offset = Vector2(49, 27)
		button.add_theme_font_override("font", UI.font(true))
		button.add_theme_font_size_override("font_size", 17)
		var color: Color = COLORS.get(node.kind, UI.BUTTON)
		var reachable: bool = id in available
		var visited: bool = id in run.visited
		if not reachable and not visited: color = color.darkened(0.45)
		var normal := UI.panel(color, 14, 8)
		if reachable:
			normal.border_color = Color(1.0, 0.9, 0.6)
			normal.set_border_width_all(3)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", UI.panel(color.lightened(0.15), 14, 8))
		button.add_theme_stylebox_override("pressed", UI.panel(color.darkened(0.1), 14, 8))
		button.add_theme_stylebox_override("disabled", UI.panel(color, 14, 8))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			button.add_theme_color_override(state, UI.CREAM if reachable or visited else Color(0.8, 0.85, 0.8, 0.55))
		button.disabled = not reachable
		if reachable:
			button.pressed.connect(func():
				if walking: return
				if UI.press_hook.is_valid(): UI.press_hook.call()
				on_pick.call(id))
		if node.kind == "boss":
			var pulse := button.create_tween().set_loops()
			pulse.tween_property(button, "self_modulate", Color(1.3, 0.9, 0.9), 0.7)
			pulse.tween_property(button, "self_modulate", Color.WHITE, 0.7)
		add_child(button)
		buttons[id] = button
	queue_redraw()


func walk(id: String, done: Callable) -> void:
	walk_from = token
	walk_to = positions.get(id, token)
	walk_t = 0.0
	hops = 0
	walking = true
	walk_done = done
	for button: Button in buttons.values(): button.disabled = true


func _process(delta: float) -> void:
	t += delta
	if run == null: return
	var available: Array = run.available_nodes()
	var index := 0
	for id: String in buttons:
		var button: Button = buttons[id]
		if not is_instance_valid(button): continue
		var bob: float = sin(t * 2.5 + index) * 3.0 if id in available and not walking else 0.0
		button.position = Vector2(positions[id]) - Vector2(49, 27) + Vector2(0, bob)
		index += 1
	if walking:
		walk_t = minf(1.0, walk_t + delta / WALK_TIME)
		token = walk_from.lerp(walk_to, ease(walk_t, -1.6))
		var hop := int(walk_t * 3.0)
		if hop > hops and hop < 3:
			hops = hop
			if audio != null: audio.play("step")
		if walk_t >= 1.0:
			walking = false
			if audio != null: audio.play("step")
			walk_done.call()
	queue_redraw()


func _draw() -> void:
	if run == null: return
	for id: String in positions:
		for link in run.map.nodes[id].links:
			if not positions.has(link): continue
			var walked: bool = id in run.visited and str(link) in run.visited
			var next: bool = id == run.at and str(link) in run.available_nodes()
			var color := UI.GOLD if walked else (Color(1.0, 0.9, 0.6, 0.6 + 0.3 * sin(t * 4.0)) if next else Color(0.7, 0.85, 0.75, 0.22))
			if next:
				var from: Vector2 = positions[id]
				var to: Vector2 = positions[link]
				for k in 10:
					var a := from.lerp(to, (k + fmod(t * 1.5, 1.0)) / 10.0)
					var b := from.lerp(to, minf(1.0, (k + 0.5 + fmod(t * 1.5, 1.0)) / 10.0))
					draw_line(a, b, color, 4.0, true)
			else:
				draw_line(positions[id], positions[link], color, 5.0 if walked else 2.0, true)
	if run.at.is_empty():
		for id in run.available_nodes():
			draw_line(Vector2(20, 280), positions[id], Color(1.0, 0.9, 0.6, 0.35), 2.0, true)
	var hop_y: float = -absf(sin(walk_t * PI * 3.0)) * 12.0 if walking else sin(t * 3.0) * 2.0
	_head(token + Vector2(0, -44 + hop_y))


func _head(pos: Vector2) -> void:
	var ink := Color(0.07, 0.05, 0.1)
	var fur := Color("2a2733")
	for s: float in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([pos + Vector2(6 * s, -8), pos + Vector2(14 * s, -24), pos + Vector2(16 * s, -4)]), ink)
	draw_circle(pos, 16.0, ink)
	draw_circle(pos, 14.0, fur)
	for s: float in [-1.0, 1.0]:
		draw_circle(pos + Vector2(5 * s, -1), 3.0, Color("f2dc8a"))
		draw_circle(pos + Vector2(5 * s, 0), 1.4, ink)
	draw_circle(pos + Vector2(0, 5), 1.8, Color("efb0b4"))
	draw_arc(pos + Vector2(0, 30), 10.0, 0, TAU, 16, Color(0, 0, 0, 0.25), 6.0, true)
