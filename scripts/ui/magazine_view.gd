class_name MagazineView
extends Control

signal swap_requested

var _swap_rect := Rect2()
var _swap_hovered := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_swap_hovered = _contains_swap_point(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and _contains_swap_point(event.position)):
			swap_requested.emit()
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and _contains_swap_point(event.position):
			swap_requested.emit()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_swap_hovered = false
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		_update_swap_rect()

func _draw() -> void:
	_update_swap_rect()
	var swap_center := _swap_rect.get_center()
	var button_color := Color(0.29, 0.38, 0.56) if _swap_hovered else Color(0.19, 0.26, 0.4)
	draw_circle(swap_center + Vector2(1.0, 3.0), 29.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(swap_center, 28.0, button_color)
	draw_arc(swap_center, 28.0, 0.0, TAU, 32, Color(0.48, 0.6, 0.8), 2.0)
	_draw_swap_arrow(swap_center, -1.0)
	_draw_swap_arrow(swap_center, 1.0)

func _update_swap_rect() -> void:
	var swap_center := size * 0.5
	_swap_rect = Rect2(swap_center - Vector2(28.0, 28.0), Vector2(56.0, 56.0))

func _contains_swap_point(point: Vector2) -> bool:
	return point.distance_to(_swap_rect.get_center()) <= 28.0

func _draw_swap_arrow(center: Vector2, direction: float) -> void:
	var y := center.y + direction * 7.0
	var start_x := center.x - direction * 13.0
	var end_x := center.x + direction * 13.0
	draw_line(Vector2(start_x, y), Vector2(end_x, y), Color.WHITE, 3.0, true)
	var tip := Vector2(end_x, y)
	draw_line(tip, tip + Vector2(-direction * 6.0, -6.0), Color.WHITE, 3.0, true)
	draw_line(tip, tip + Vector2(-direction * 6.0, 6.0), Color.WHITE, 3.0, true)

