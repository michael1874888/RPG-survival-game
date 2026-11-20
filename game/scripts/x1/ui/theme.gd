extends RefCounted
## Shared colours, fonts and widget builders for X1 screens.

const CREAM := Color("fff2d4")
const MUTED := Color("a9c9ae")
const GOLD := Color("ffd479")
const INK := Color("17362d")
const PANEL := Color("234638")
const BUTTON := Color("345b47")
const DANGER := Color("ff9e8e")
const PREY := Color("ff9eac")
const SHADOW := Color("9deaff")

static var _regular: Font = null
static var press_hook: Callable = Callable()   # sound + haptic tick on every button press
static var _bold: Font = null


static func font(bold := false) -> Font:
	if _regular == null:
		var base: Font = load("res://assets/fonts/NotoSansTC.ttf") as Font
		var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
		var regular := FontVariation.new()
		regular.base_font = base
		regular.variation_opentype = {tag: 450.0}
		regular.variation_embolden = 0.45
		_regular = regular
		var heavy := FontVariation.new()
		heavy.base_font = base
		heavy.variation_opentype = {tag: 700.0}
		heavy.variation_embolden = 0.9
		_bold = heavy
	return _bold if bold else _regular


static func panel(color: Color, radius := 18, margin := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.75
	style.content_margin_bottom = margin * 0.75
	return style


static func label(text: String, size := 20, color := CREAM, align := HORIZONTAL_ALIGNMENT_CENTER, wrap := true) -> Label:
	var node := Label.new()
	node.text = text
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if wrap: node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font", font(size >= 26))
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func button(text: String, callback: Callable, primary := false, size := 21, height := 54.0) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size = Vector2(0, height)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_override("font", font(true))
	node.add_theme_font_size_override("font_size", size)
	var text_color := INK if primary else CREAM
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, text_color)
	node.add_theme_color_override("font_disabled_color", Color(0.75, 0.8, 0.75, 0.55))
	node.add_theme_stylebox_override("normal", panel(GOLD if primary else BUTTON, 14, 12))
	node.add_theme_stylebox_override("hover", panel(Color("ffe5a4") if primary else Color("47765b"), 14, 12))
	node.add_theme_stylebox_override("pressed", panel(Color("e4af54") if primary else Color("2c4f3e"), 14, 12))
	node.add_theme_stylebox_override("disabled", panel(Color(0.18, 0.28, 0.23, 0.8), 14, 12))
	node.pressed.connect(callback)
	node.resized.connect(func(): node.pivot_offset = node.size * 0.5)
	node.button_down.connect(func():
		node.create_tween().tween_property(node, "scale", Vector2(0.95, 0.95), 0.05)
		if press_hook.is_valid(): press_hook.call())
	node.button_up.connect(func():
		node.create_tween().tween_property(node, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	return node


static func row(parent: Control, separation := 10) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	node.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(node)
	return node


static func expand(node: Control) -> Control:
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


## A full-screen dimmed overlay with a centred scrollable panel; returns the content column.
static func overlay(host: Control, width := 760.0, dim := 0.84) -> VBoxContainer:
	var back := ColorRect.new()
	back.name = "Overlay"
	back.color = Color(0.035, 0.10, 0.075, dim)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(back)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(center)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(width, 0)
	box.add_theme_stylebox_override("panel", panel(PANEL, 26, 20))
	center.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width - 40.0, 0)
	box.add_child(scroll)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	column.resized.connect(func(): scroll.custom_minimum_size.y = minf(column.size.y, host.size.y - 70.0))
	return column
