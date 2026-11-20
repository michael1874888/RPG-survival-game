extends Control
## A treasure chest that shakes, pops open and bursts light; purely decorative.

var t := 0.0
var open_at := 0.45


func _ready() -> void:
	custom_minimum_size = Vector2(0, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var c := Vector2(size.x * 0.5, 80)
	var ink := Color(0.07, 0.05, 0.1)
	var opened: float = clampf((t - open_at) / 0.2, 0.0, 1.0)
	var shake: float = sin(t * 60.0) * 3.0 * (1.0 - opened) * clampf(t / open_at, 0.0, 1.0)
	if opened > 0.0:
		for k in 10:
			var a := -PI * 0.5 + (k - 4.5) * 0.22 + sin(t * 2.0 + k) * 0.04
			draw_line(c + Vector2(0, -20), c + Vector2(0, -20) + Vector2.RIGHT.rotated(a) * (90.0 + 30.0 * sin(t * 3.0 + k)) * opened,
				Color(1.0, 0.85, 0.45, 0.35 * opened), 6.0, true)
	var body := Rect2(c + Vector2(-46 + shake, -20), Vector2(92, 52))
	draw_rect(body.grow(3), ink)
	draw_rect(body, Color("9a5f3a"))
	draw_rect(Rect2(body.position + Vector2(0, 18), Vector2(92, 8)), Color("e0b35a"))
	var lid_angle: float = -1.9 * ease(opened, 0.4)
	draw_set_transform(c + Vector2(-46 + shake, -20), lid_angle, Vector2.ONE)
	draw_rect(Rect2(Vector2(-3, -27), Vector2(98, 30)), ink)
	draw_rect(Rect2(Vector2(0, -24), Vector2(92, 24)), Color("b06f43"))
	draw_rect(Rect2(Vector2(40, -14), Vector2(12, 16)), Color("e0b35a"))
	draw_set_transform(Vector2.ZERO)
