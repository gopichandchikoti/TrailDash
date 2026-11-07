class_name UIFactory
extends RefCounted

const TEXT := Color("effbf7")
const MUTED := Color("a3b5c9")
const ACCENT := Color("6ff2cd")


static func label(parent: Node, value: String, size: int = 24, color: Color = TEXT) -> Label:
	var view := Label.new()
	view.text = value
	view.add_theme_font_size_override("font_size", size)
	view.add_theme_color_override("font_color", color)
	view.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	return view


static func button(parent: Node, value: String, callback: Callable, primary: bool = false) -> Button:
	var view := Button.new()
	view.text = value
	view.custom_minimum_size.y = 78
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_theme_font_size_override("font_size", 25)
	var color := ACCENT if primary else Color("182d47")
	view.add_theme_stylebox_override("normal", style(color))
	view.add_theme_stylebox_override("hover", style(color.lightened(0.12)))
	view.add_theme_stylebox_override("pressed", style(color.darkened(0.15)))
	view.add_theme_stylebox_override("disabled", style(Color("142238")))
	var focus := style(Color.TRANSPARENT)
	focus.set_border_width_all(3)
	focus.border_color = Color("ffdc87")
	view.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		view.add_theme_color_override(state, Color("0b182c") if primary else TEXT)
	view.pressed.connect(callback)
	parent.add_child(view)
	return view


static func style(color: Color) -> StyleBoxFlat:
	var value := StyleBoxFlat.new()
	value.bg_color = color
	value.set_corner_radius_all(16)
	value.content_margin_left = 20
	value.content_margin_right = 20
	value.content_margin_top = 12
	value.content_margin_bottom = 12
	return value


static func stack(parent: Node, separation: int = 16) -> VBoxContainer:
	var view := VBoxContainer.new()
	view.add_theme_constant_override("separation", separation)
	parent.add_child(view)
	return view


static func fill(view: Control) -> void:
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func margin(parent: Node, padding: int = 40) -> MarginContainer:
	var view := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		view.add_theme_constant_override("margin_" + side, padding)
	parent.add_child(view)
	return view
