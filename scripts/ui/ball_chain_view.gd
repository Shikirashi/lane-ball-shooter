class_name BallChainView
extends Control

const ConveyorBallLayerScript = preload("res://scripts/ui/conveyor_ball_layer.gd")
const SettlingBallViewScript = preload("res://scripts/ui/settling_ball_view.gd")

var model: ChainModel
var _feedback_time := 0.0
var _feedback_identity := -1
var _feedback_size := 0
var _feedback_points := 0
var _feedback_tier := 0
var _feedback_fever := false
var debug_visible := false
var conveyor_mask: Control
var conveyor_balls: Control
var settling_overlay: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	conveyor_mask = Control.new()
	conveyor_mask.name = "EstablishedConveyorMask"
	conveyor_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	conveyor_mask.clip_contents = true
	add_child(conveyor_mask)
	conveyor_balls = ConveyorBallLayerScript.new()
	conveyor_balls.name = "EstablishedConveyorBalls"
	conveyor_mask.add_child(conveyor_balls)
	settling_overlay = SettlingBallViewScript.new()
	settling_overlay.name = "UnmaskedSettlingOverlay"
	add_child(settling_overlay)
	queue_redraw()

func set_model(value: ChainModel) -> void:
	model = value
	model.state_changed.connect(queue_redraw)
	model.match_completed.connect(_on_match_completed)
	conveyor_balls.set_model(model)
	settling_overlay.set_model(model)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and conveyor_mask != null:
		_configure_layers()

func _configure_layers() -> void:
	var lane_rect := conveyor_window_rect()
	conveyor_mask.position = lane_rect.position
	conveyor_mask.size = lane_rect.size
	conveyor_balls.position = Vector2.ZERO
	conveyor_balls.size = lane_rect.size
	settling_overlay.position = Vector2.ZERO
	settling_overlay.size = size
	settling_overlay.configure_lane_center(lane_rect.get_center().y)

func conveyor_window_rect() -> Rect2:
	return Rect2(0.0, 10.0, size.x, maxf(56.0, size.y - 14.0))

func _process(delta: float) -> void:
	_feedback_time = maxf(0.0, _feedback_time - delta)
	queue_redraw()

func _draw() -> void:
	var lane_rect := conveyor_window_rect()
	draw_style_box(_panel_style(), lane_rect)
	var cy := lane_rect.get_center().y
	draw_line(Vector2(22.0, cy), Vector2(size.x - 22.0, cy), UiPalette.BORDER, 3.0)
	if model != null:
		if debug_visible:
			draw_string(ThemeDB.fallback_font, Vector2(size.x - 248.0, size.y - 5.0), _debug_text(), HORIZONTAL_ALIGNMENT_RIGHT, 232.0, 10, UiPalette.TEXT_SECONDARY)
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
		return "B%d L%d X%.0f A%d U%d G%d V%.0f D%.1f F%d SET%d I%d" % [model.balls.size(), model.offscreen_left_count(), model.leftmost_x(), model.active_population_count(), model.unsupported_segment_count, model.gravity_gap_count, model.max_gravity_speed, model.last_gravity_displacement, model.total_fresh_generated, model.pending_insertions.size(), model.invariant_violations]
	return "B%d L%d X%.0f A%d U%d G%d V%.0f D%.1f F%d M%.0f/%.0f I%d" % [model.balls.size(), model.offscreen_left_count(), model.leftmost_x(), model.active_population_count(), model.unsupported_segment_count, model.gravity_gap_count, model.max_gravity_speed, model.last_gravity_displacement, model.total_fresh_generated, logical_minimum, display_minimum, model.invariant_violations]

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
	settling_overlay.visible = true
	queue_redraw()

func set_settling_visuals_visible(value: bool) -> void:
	if settling_overlay != null:
		settling_overlay.visible = value

func _draw_direction_hint(center: Vector2) -> void:
	var shade := UiPalette.TEXT
	draw_rect(Rect2(center.x - 3.0, center.y - 20.0, 6.0, 40.0), UiPalette.BLACK, true)
	var arrow := PackedVector2Array([
		center + Vector2(-17.0, 0.0),
		center + Vector2(4.0, -11.0),
		center + Vector2(4.0, 11.0),
	])
	draw_colored_polygon(arrow, shade)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiPalette.PANEL
	style.border_color = UiPalette.BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	return style
