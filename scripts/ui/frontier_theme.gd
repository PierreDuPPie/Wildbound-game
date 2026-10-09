extends RefCounted
const INK := Color("152827")
const PANEL := Color("192e2d")
const GOLD := Color("e2bc76")
const TEXT := Color("f3efdf")
const MUTED := Color("a4b9ae")
const GREEN := Color("86ccab")

static func panel(color: Color = PANEL, border: Color = Color("40554b")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

static func create_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 21
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD)
	theme.set_color("font_disabled_color", "Button", Color("72867b"))
	theme.set_stylebox("normal", "Button", panel(Color("263d36")))
	theme.set_stylebox("hover", "Button", panel(Color("345546"), GOLD))
	theme.set_stylebox("pressed", "Button", panel(Color("40634f"), GOLD))
	theme.set_stylebox("disabled", "Button", panel(Color("21322d")))
	theme.set_stylebox("focus", "Button", panel(Color(0,0,0,0), GOLD))
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_stylebox("normal", "LineEdit", panel(INK))
	theme.set_stylebox("focus", "LineEdit", panel(INK, GOLD))
	theme.set_color("font_color", "LineEdit", TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	theme.set_constant("separation", "VBoxContainer", 12)
	theme.set_constant("separation", "HBoxContainer", 12)
	return theme

static func label(text: String, font_size: int = 21, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

static func button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 52
	result.pressed.connect(callback)
	return result
