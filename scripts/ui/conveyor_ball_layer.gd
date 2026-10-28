class_name ConveyorBallLayer
extends Control

var model: ChainModel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false

func set_model(value: ChainModel) -> void:
	model = value
	model.state_changed.connect(queue_redraw)
	queue_redraw()

func rendered_uids() -> Array[int]:
	var result: Array[int] = []
	if model == null:
		return result
	for ball in model.balls:
		var x := float(ball.x)
		if x + model.radius >= 0.0 and x - model.radius <= model.lane_width and not model.is_settling(int(ball.uid)):
			result.append(int(ball.uid))
	return result

func _draw() -> void:
	if model == null:
		return
	var cy := size.y * 0.5
	for ball in model.balls:
		var uid := int(ball.uid)
		if model.is_settling(uid):
			continue
		var x := float(ball.display_x)
		if x + model.radius < 0.0 or x - model.radius > model.lane_width:
			continue
		var center := Vector2(x, cy)
		_draw_ball(center, model.radius, int(ball.identity))

func _draw_ball(center: Vector2, draw_radius: float, identity: int) -> void:
	draw_circle(center + Vector2(2.0, 4.0), draw_radius + 1.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(center, draw_radius, TeamData.color(identity))
	draw_arc(center, draw_radius, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.34), 2.0)
	TeamData.draw_symbol(self, identity, center, draw_radius, Color(0.04, 0.04, 0.04, 0.9))
