class_name BallChainView
extends Control

var model: ChainModel
var _feedback_time := 0.0
var _feedback_identity := -1
var _feedback_size := 0
var _feedback_points := 0
var _feedback_tier := 0
var _feedback_fever := false
var debug_visible := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()

func set_model(value: ChainModel) -> void:
	model = value
	model.state_changed.connect(queue_redraw)
	model.match_completed.connect(_on_match_completed)
	queue_redraw()

func _process(delta: float) -> void:
	_feedback_time = maxf(0.0, _feedback_time - delta)
	queue_redraw()

func _draw() -> void:
	var lane_rect := Rect2(0.0, 10.0, size.x, maxf(56.0, size.y - 14.0))
	draw_style_box(_panel_style(), lane_rect)
	var cy := lane_rect.get_center().y
	draw_line(Vector2(22.0, cy), Vector2(size.x - 22.0, cy), Color(0.3, 0.38, 0.52, 0.75), 3.0)
	if model != null:
		for ball in model.balls:
			var identity := int(ball.identity)
			var center := Vector2(float(ball.display_x), cy)
			if center.x < -model.radius or center.x > size.x + model.radius:
				continue
			var settle_scale := lerpf(0.72, 1.0, model.settle_ratio(int(ball.uid)))
			var draw_radius := model.radius * settle_scale
			draw_circle(center + Vector2(2.0, 4.0), draw_radius + 1.0, Color(0.0, 0.0, 0.0, 0.35))
			draw_circle(center, draw_radius, TeamData.color(identity))
			draw_arc(center, draw_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.34), 2.0)
			TeamData.draw_symbol(self, identity, center, draw_radius, Color(0.08, 0.1, 0.16, 0.88))
		if debug_visible:
			draw_string(ThemeDB.fallback_font, Vector2(size.x - 248.0, size.y - 5.0), _debug_text(), HORIZONTAL_ALIGNMENT_RIGHT, 232.0, 10, Color(0.65, 0.72, 0.84, 0.85))
	if _feedback_time > 0.0:
		var feedback_color := TeamData.color(_feedback_identity).lightened(0.18)
		var feedback_text := "MATCH %s x%d" % [TeamData.display_name(_feedback_identity), _feedback_size]
		if _feedback_points > 0:
			var state_text := "FEVER" if _feedback_fever else "TIER %d" % _feedback_tier
			feedback_text = "%s  +%d  %s" % [feedback_text, _feedback_points, state_text]
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 150.0, 26.0), feedback_text, HORIZONTAL_ALIGNMENT_CENTER, 300.0, 15, feedback_color)
		var pulse_radius := 25.0 + (0.65 - _feedback_time) * 32.0
		draw_arc(Vector2(size.x * 0.5, cy), pulse_radius, 0.0, TAU, 32, Color(feedback_color, _feedback_time), 2.0)
	_draw_direction_hint(Vector2(36.0, cy))

func _debug_text() -> String:
	var gap_counts := model.gap_type_counts()
	var logical_minimum := model.min_logical_spacing if is_finite(model.min_logical_spacing) else 0.0
	var display_minimum := model.min_display_spacing if is_finite(model.min_display_spacing) else 0.0
	if model.last_match_identity < 0:
		return "B%d S%d G%d/%d SET%d M%.0f/%.0f I%d" % [model.balls.size(), model.segments.size(), int(gap_counts.feed), int(gap_counts.causal), model.pending_insertions.size(), logical_minimum, display_minimum, model.invariant_violations]
	return "B%d S%d G%d/%d E%d M%.0f/%.0f I%d" % [model.balls.size(), model.segments.size(), int(gap_counts.feed), int(gap_counts.causal), model.max_concurrent_events, logical_minimum, display_minimum, model.invariant_violations]

func _on_match_completed(identity: int, group_size: int) -> void:
	_feedback_identity = identity
	_feedback_size = group_size
	_feedback_points = 0
	_feedback_tier = 0
	_feedback_fever = false
	_feedback_time = 0.65
	queue_redraw()

func show_progression_feedback(result: Dictionary) -> void:
	_feedback_identity = int(result.identity)
	_feedback_size = int(result.group_size)
	_feedback_points = int(result.points)
	_feedback_tier = int(result.tier)
	_feedback_fever = bool(result.fever)
	_feedback_time = 0.9
	queue_redraw()

func toggle_debug() -> void:
	debug_visible = not debug_visible
	queue_redraw()

func reset_feedback() -> void:
	_feedback_time = 0.0
	_feedback_identity = -1
	_feedback_size = 0
	_feedback_points = 0
	_feedback_tier = 0
	_feedback_fever = false
	queue_redraw()

func _draw_direction_hint(center: Vector2) -> void:
	var shade := Color(0.92, 0.96, 1.0, 0.92)
	draw_rect(Rect2(center.x - 3.0, center.y - 20.0, 6.0, 40.0), Color(0.02, 0.03, 0.06, 0.75), true)
	var arrow := PackedVector2Array([
		center + Vector2(-17.0, 0.0),
		center + Vector2(4.0, -11.0),
		center + Vector2(4.0, 11.0),
	])
	draw_colored_polygon(arrow, shade)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.115, 0.96)
	style.border_color = Color(0.25, 0.33, 0.48, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	return style
