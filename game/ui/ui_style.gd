class_name UiStyle
extends RefCounted
## The shared look of the menus: the pixel font, dark panels, and a yellow
## border on the focused button, so keyboard and gamepad players see where
## they are.

const FONT := preload("res://assets/fonts/pixel.png")
const FONT_SIZE := 8
const INK := Color("f4f4f4")
const DIM := Color("94b0c2")
const PANEL := Color(Color("1a1c2c"), 0.85)
const BUTTON := Color("333c57")
const HOVER := Color("566c86")
const FOCUS := Color("ffcd75")
const FOCUS_BORDER := 1
const PAD := 4


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = FONT_SIZE
	t.set_color(&"font_color", &"Label", INK)
	for state: StringName in [
		&"font_color",
		&"font_focus_color",
		&"font_hover_color",
		&"font_pressed_color",
	]:
		t.set_color(state, &"Button", INK)
	t.set_color(&"font_disabled_color", &"Button", DIM)
	t.set_stylebox(&"normal", &"Button", _box(BUTTON))
	t.set_stylebox(&"hover", &"Button", _box(HOVER))
	t.set_stylebox(&"pressed", &"Button", _box(HOVER))
	t.set_stylebox(&"disabled", &"Button", _box(BUTTON))
	var focus := _box(Color.TRANSPARENT)
	focus.draw_center = false
	focus.set_border_width_all(FOCUS_BORDER)
	focus.border_color = FOCUS
	t.set_stylebox(&"focus", &"Button", focus)
	t.set_stylebox(&"panel", &"PanelContainer", _box(PANEL))
	return t


static func label(text: String, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func _box(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_content_margin_all(PAD)
	return b
