extends Control
## The night patrol map: layers left to right, links, the path so far and the reachable nodes.

const UI := preload("res://scripts/x1/ui/theme.gd")

const NAMES := {"hunt": "狩獵", "den": "獵物巢", "bed": "貓窩", "shop": "主人房間", "moon": "月光", "boss": "守關"}
const COLORS := {"hunt": Color("5b8a6a"), "den": Color("b0606a"), "bed": Color("6a7fb0"), "shop": Color("b08a4e"),
	"moon": Color("8a6ab0"), "boss": Color("c2454f")}

var run = null
var on_pick: Callable
var positions: Dictionary = {}


func build(run_ref, callback: Callable) -> void:
	run = run_ref
	on_pick = callback
	custom_minimum_size = Vector2(860, 560)
	for child in get_children(): child.queue_free()
	positions.clear()
	var rows: Array = run.map.rows
	var columns: int = rows.size() + 1
	var step_x: float = 770.0 / maxf(1.0, columns - 1)
	for layer in rows.size():
		var row: Array = rows[layer]
		for i in row.size():
			positions[row[i]] = Vector2(75.0 + step_x * layer, 280.0 + (i - (row.size() - 1) * 0.5) * 150.0)
	positions["boss"] = Vector2(75.0 + step_x * rows.size(), 280.0)
	var available: Array = run.available_nodes()
	for id: String in positions:
		var node: Dictionary = run.map.nodes[id]
		var button := Button.new()
		button.text = NAMES.get(node.kind, node.kind)
		button.focus_mode = Control.FOCUS_NONE
		button.size = Vector2(98, 54)
		button.position = Vector2(positions[id]) - Vector2(49, 27)
		button.add_theme_font_override("font", UI.font(true))
		button.add_theme_font_size_override("font_size", 17)
		var color: Color = COLORS.get(node.kind, UI.BUTTON)
		var reachable: bool = id in available
		var visited: bool = id in run.visited
		if not reachable and not visited: color = color.darkened(0.45)
		button.add_theme_stylebox_override("normal", UI.panel(color, 14, 8))
		button.add_theme_stylebox_override("hover", UI.panel(color.lightened(0.15), 14, 8))
		button.add_theme_stylebox_override("pressed", UI.panel(color.darkened(0.1), 14, 8))
		button.add_theme_stylebox_override("disabled", UI.panel(color, 14, 8))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			button.add_theme_color_override(state, UI.CREAM if reachable or visited else Color(0.8, 0.85, 0.8, 0.55))
		button.disabled = not reachable
		if reachable: button.pressed.connect(func(): on_pick.call(id))
		add_child(button)
	queue_redraw()


func _draw() -> void:
	if run == null: return
	for id: String in positions:
		for link in run.map.nodes[id].links:
			if not positions.has(link): continue
			var walked: bool = id in run.visited and str(link) in run.visited
			var next: bool = id == run.at and str(link) in run.available_nodes()
			var color := UI.GOLD if walked else (Color(1.0, 0.9, 0.6, 0.85) if next else Color(0.7, 0.85, 0.75, 0.25))
			draw_line(positions[id], positions[link], color, 5.0 if walked or next else 2.0, true)
	if not run.at.is_empty() and positions.has(run.at):
		draw_arc(positions[run.at], 46.0, 0, TAU, 32, UI.GOLD, 3.0, true)
		draw_string(UI.font(true), Vector2(positions[run.at]) + Vector2(-14, -40), "奈奈", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UI.GOLD)
