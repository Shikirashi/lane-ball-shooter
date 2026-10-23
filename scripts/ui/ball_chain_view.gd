class_name BallChainView
extends Control

var model: ChainModel
var _feedback_time := 0.0
var _feedback_identity := -1
var _feedback_size := 0

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
			draw_circle(center + Vector2(2.0, 4.0), model.radius + 1.0, Color(0.0, 0.0, 0.0, 0.35))
			draw_circle(center, model.radius, TeamData.color(identity))
			draw_arc(center, model.radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.34), 2.0)
			TeamData.draw_symbol(self, identity, center, model.radius, Color(0.08, 0.1, 0.16, 0.88))
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 248.0, size.y - 5.0), _debug_text(), HORIZONTAL_ALIGNMENT_RIGHT, 232.0, 10, Color(0.65, 0.72, 0.84, 0.85))
	if _feedback_time > 0.0:
		var feedback_color := TeamData.color(_feedback_identity).lightened(0.18)
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 90.0, 26.0), "MATCH %s x%d" % [TeamData.display_name(_feedback_identity), _feedback_size], HORIZONTAL_ALIGNMENT_CENTER, 180.0, 15, feedback_color)
		var pulse_radius := 25.0 + (0.65 - _feedback_time) * 32.0
		draw_arc(Vector2(size.x * 0.5, cy), pulse_radius, 0.0, TAU, 32, Color(feedback_color, _feedback_time), 2.0)
	_draw_direction_hint(Vector2(36.0, cy))

func _debug_text() -> String:
	if model.last_match_identity < 0:
		return "VISIBLE %d  CACHE %d  MATCHES 0" % [model.balls.size(), model.cache.size()]
	return "VISIBLE %d  CACHE %d  LAST %s x%d  EVENTS %d" % [model.balls.size(), model.cache.size(), TeamData.display_name(model.last_match_identity), model.last_match_size, model.total_match_events]

func _on_match_completed(identity: int, group_size: int) -> void:
	_feedback_identity = identity
	_feedback_size = group_size
	_feedback_time = 0.65
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
