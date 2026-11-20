extends Control
## Claw-mark screen transition: starts covering the screen with three slashes and tears away.
## Non-blocking: the screen underneath has already switched.

var life := 0.0
var duration := 0.42
var title := ""
var subtitle := ""
var font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	font = load("res://scripts/x1/ui/theme.gd").font(true)


func play(text := "", sub := "", seconds := 0.42) -> void:
	title = text
	subtitle = sub
	duration = seconds + (0.5 if not text.is_empty() else 0.0)
	life = duration
	visible = true


func _process(delta: float) -> void:
	if life <= 0.0:
		visible = false
		return
	life -= delta
	queue_redraw()


func _draw() -> void:
	if life <= 0.0: return
	var t: float = 1.0 - life / duration
	var hold: float = 0.45 if not title.is_empty() else 0.0
	var open: float = clampf((t - hold) / maxf(0.01, 1.0 - hold), 0.0, 1.0)
	var dark := Color(0.04, 0.03, 0.07)
	var bands := 3
	for i in bands:
		var h: float = size.y / bands
		var y: float = i * h
		var offset: float = ease(open, 2.2) * (size.x + 200.0) * (1.0 if i % 2 == 0 else -1.0)
		var skew := 80.0
		var points := PackedVector2Array([Vector2(-100 + offset, y), Vector2(size.x + 100 + offset, y - skew * 0.3),
			Vector2(size.x + 100 + offset, y + h + skew * 0.3), Vector2(-100 + offset, y + h)])
		draw_colored_polygon(points, dark)
		draw_line(Vector2(-100 + offset, y + h), Vector2(size.x + 100 + offset, y + h + skew * 0.3), Color(0.75, 0.6, 1.0, 0.6 * (1.0 - open)), 3.0, true)
	if not title.is_empty() and open < 0.6:
		var a: float = 1.0 - open / 0.6
		var pop: float = 1.0 + 0.2 * maxf(0.0, 1.0 - t / 0.15)
		draw_string(font, Vector2(0, size.y * 0.48), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, int(52 * pop), Color(1.0, 0.95, 0.85, a))
		if not subtitle.is_empty():
			draw_string(font, Vector2(0, size.y * 0.48 + 44), subtitle, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(1.0, 0.83, 0.47, a))
