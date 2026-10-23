class_name HudView
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	var panel := Rect2(0.0, 0.0, size.x, size.y)
	draw_style_box(_panel_style(), panel)
	draw_string(ThemeDB.fallback_font, Vector2(16.0, 25.0), "LANE BALL SHOOTER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.92, 0.96, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.44, 24.0), "SCORE  000000", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 164.0, 24.0), "COMBO  x0", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.75, 0.82, 0.94))

	var fever_width := clampf(size.x * 0.24, 170.0, 310.0)
	var fever_rect := Rect2(size.x * 0.5 - fever_width * 0.5, size.y - 12.0, fever_width, 7.0)
	draw_rect(fever_rect, Color(0.12, 0.16, 0.24), true)
	draw_rect(fever_rect, Color(0.36, 0.43, 0.56), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(fever_rect.position.x - 58.0, size.y - 5.0), "FEVER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.55, 0.62, 0.74))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.05, 0.09, 0.96)
	style.border_color = Color(0.18, 0.24, 0.36)
	style.border_width_bottom = 1
	return style

