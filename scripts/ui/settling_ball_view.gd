class_name SettlingBallView
extends Control

var model: ChainModel
var lane_center_y := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false

func set_model(value: ChainModel) -> void:
	model = value
	model.state_changed.connect(queue_redraw)
	queue_redraw()

func configure_lane_center(value: float) -> void:
	lane_center_y = value
	queue_redraw()

func rendered_uids() -> Array[int]:
	var result: Array[int] = []
	if model == null:
		return result
	for ball in model.balls:
		if model.is_settling(int(ball.uid)):
			result.append(int(ball.uid))
	return result

func _draw() -> void:
	if model == null:
		return
	for ball in model.balls:
		var uid := int(ball.uid)
		if not model.is_settling(uid):
			continue
		var center := Vector2(float(ball.display_x), lane_center_y)
		var draw_radius := model.radius * lerpf(0.72, 1.0, model.settle_ratio(uid))
		draw_circle(center + Vector2(2.0, 4.0), draw_radius + 1.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_circle(center, draw_radius, TeamData.color(int(ball.identity)))
		draw_arc(center, draw_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.34), 2.0)
		TeamData.draw_symbol(self, int(ball.identity), center, draw_radius, Color(0.08, 0.1, 0.16, 0.88))
