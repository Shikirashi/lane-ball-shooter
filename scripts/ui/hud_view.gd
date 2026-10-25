class_name HudView
extends Control

var score := 0
var combo_count := 0
var tier := 0
var fever_active := false
var window_ratio := 0.0
var _fever_pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func set_progress(score_value: int, combo_value: int, tier_value: int, fever_value: bool, ratio_value: float) -> void:
	score = score_value
	combo_count = combo_value
	tier = tier_value
	fever_active = fever_value
	window_ratio = clampf(ratio_value, 0.0, 1.0)
	queue_redraw()

func _process(delta: float) -> void:
	if fever_active:
		_fever_pulse = fmod(_fever_pulse + delta * 3.2, TAU)
		queue_redraw()

func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_style_box(_panel_style(), panel)
	var compact := size.x < 1100.0
	var control_reserve := clampf(size.x * 0.20, 190.0, 230.0) + 12.0
	var info_right := size.x - control_reserve
	var title_font_size := 14 if compact else 17
	var value_font_size := 13 if compact else 15
	var baseline := minf(25.0, size.y - 13.0)

	draw_string(ThemeDB.fallback_font, Vector2(14.0, baseline), "LBS" if compact else "LANE BALL SHOOTER", HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_font_size, Color(0.92, 0.96, 1.0))
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.30, baseline), "SCORE  %06d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_font_size, Color.WHITE)
	var combo_color := Color(0.82, 0.9, 1.0) if combo_count > 0 else Color(0.52, 0.59, 0.7)
	draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.54, baseline), "COMBO  x%d" % combo_count, HORIZONTAL_ALIGNMENT_LEFT, -1.0, value_font_size, combo_color)

	var state_text := "READY"
	var state_color := Color(0.55, 0.62, 0.74)
	if fever_active:
		state_text = "FEVER"
		state_color = Color(1.0, 0.72 + sin(_fever_pulse) * 0.08, 0.22)
	elif tier > 0:
		state_text = "TIER %d" % tier
		state_color = Color(0.67, 0.86, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(info_right - 94.0, baseline), state_text, HORIZONTAL_ALIGNMENT_CENTER, 88.0, value_font_size, state_color)

	var meter_left := size.x * 0.29
	var meter_right := info_right - 8.0
	var meter_rect := Rect2(meter_left, size.y - 8.0, meter_right - meter_left, 5.0)
	draw_rect(meter_rect, Color(0.1, 0.14, 0.22), true)
	if window_ratio > 0.0:
		var fill_color := Color(1.0, 0.55, 0.14) if fever_active else Color(0.3, 0.68, 1.0)
		draw_rect(Rect2(meter_rect.position, Vector2(meter_rect.size.x * window_ratio, meter_rect.size.y)), fill_color, true)
	draw_rect(meter_rect, Color(0.36, 0.44, 0.58), false, 1.0)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.055, 0.055, 0.98) if fever_active else Color(0.035, 0.05, 0.09, 0.96)
	style.border_color = Color(0.78, 0.46, 0.12) if fever_active else Color(0.18, 0.24, 0.36)
	style.border_width_bottom = 2 if fever_active else 1
	return style
