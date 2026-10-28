class_name UiPalette
extends RefCounted

const BACKGROUND := Color("#050505")
const PANEL := Color("#101010")
const SURFACE := Color("#161616")
const SURFACE_RAISED := Color("#242424")
const SEPARATOR := Color("#454545")
const BORDER := Color("#777777")
const TEXT := Color("#f4f4f4")
const TEXT_SECONDARY := Color("#a8a8a8")
const TEXT_DISABLED := Color("#666666")
const WHITE := Color("#ffffff")
const BLACK := Color("#000000")
const OVERLAY := Color(0.0, 0.0, 0.0, 0.86)
const FEVER := Color("#ffb52e")
const COMBO := Color("#ff9142")
const SUCCESS := Color("#66dd88")
const FAILURE := Color("#ff5a48")

static func panel_style(background := PANEL, border := SEPARATOR, border_width := 1, corner_radius := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style

static func apply_button(button: Button, selected := false) -> void:
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_focus_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_disabled_color", TEXT if selected else TEXT_DISABLED)
	var normal := panel_style(SURFACE_RAISED if selected else SURFACE, WHITE if selected else BORDER, 2 if selected else 1, 4)
	var hover := panel_style(SURFACE_RAISED, WHITE, 2, 4)
	var pressed := panel_style(TEXT, TEXT, 2, 4)
	var disabled := panel_style(SURFACE_RAISED if selected else PANEL, WHITE if selected else SEPARATOR, 2 if selected else 1, 4)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_pressed_color", BLACK)
