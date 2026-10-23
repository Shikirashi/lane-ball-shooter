class_name BallChainView
extends Control

const SPACING := 58.0
const BALL_RADIUS := 22.0
const SPEED := 34.0
const SAMPLE: Array[int] = [0, 1, 2, 3, 0, 2, 1, 3, 3, 0, 1, 2, 0, 3, 2, 1, 0, 2, 3, 1, 2, 0, 3, 1]

var _travel := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	queue_redraw()

func _process(delta: float) -> void:
	_travel = fmod(_travel + SPEED * delta, SPACING)
	queue_redraw()

func _draw() -> void:
	var lane_rect := Rect2(0.0, 10.0, size.x, maxf(56.0, size.y - 14.0))
	draw_style_box(_panel_style(), lane_rect)
	var cy := lane_rect.get_center().y
	draw_line(Vector2(22.0, cy), Vector2(size.x - 22.0, cy), Color(0.3, 0.38, 0.52, 0.75), 3.0)
	var count := ceili(size.x / SPACING) + 2
	for index in range(count):
		var identity := SAMPLE[index % SAMPLE.size()]
		var center := Vector2(size.x - 36.0 - index * SPACING - _travel, cy)
		if center.x < -BALL_RADIUS:
			continue
		draw_circle(center + Vector2(2.0, 4.0), BALL_RADIUS + 1.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_circle(center, BALL_RADIUS, TeamData.color(identity))
		draw_arc(center, BALL_RADIUS, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.34), 2.0)
		TeamData.draw_symbol(self, identity, center, BALL_RADIUS, Color(0.08, 0.1, 0.16, 0.88))
	_draw_direction_hint(Vector2(36.0, cy))

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

