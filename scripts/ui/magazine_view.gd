class_name MagazineView
extends Control

signal swap_requested

var loaded_identity: int = TeamData.Identity.RED
var next_identity: int = TeamData.Identity.BLUE
var _swap_rect := Rect2()
var _swap_hovered := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()

func set_identities(loaded: int, next_value: int) -> void:
	loaded_identity = loaded
	next_identity = next_value
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_swap_hovered = _swap_rect.has_point(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and _swap_rect.has_point(event.position)):
			swap_requested.emit()
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and _swap_rect.has_point(event.position):
			swap_requested.emit()
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_swap_hovered = false
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		_update_swap_rect()

func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	var loaded_center := Vector2(size.x * 0.18, size.y * 0.58)
	var swap_center := Vector2(size.x * 0.5, size.y * 0.55)
	var next_center := Vector2(size.x * 0.82, size.y * 0.58)
	_update_swap_rect()

	_draw_slot(loaded_center, loaded_identity)
	_draw_slot(next_center, next_identity)
	draw_string(ThemeDB.fallback_font, Vector2(loaded_center.x - 25.0, 14.0), "LOAD", HORIZONTAL_ALIGNMENT_CENTER, 50.0, 10, Color(0.82, 0.88, 0.98))
	draw_string(ThemeDB.fallback_font, Vector2(next_center.x - 22.0, 14.0), "NEXT", HORIZONTAL_ALIGNMENT_CENTER, 44.0, 10, Color(0.82, 0.88, 0.98))

	var button_color := Color(0.29, 0.38, 0.56) if _swap_hovered else Color(0.19, 0.26, 0.4)
	draw_style_box(_button_style(button_color), _swap_rect)
	draw_string(ThemeDB.fallback_font, Vector2(swap_center.x - 18.0, swap_center.y + 7.0), "<>", HORIZONTAL_ALIGNMENT_CENTER, 36.0, 21, Color.WHITE)

func _update_swap_rect() -> void:
	var swap_center := Vector2(size.x * 0.5, size.y * 0.55)
	_swap_rect = Rect2(swap_center - Vector2(32.0, 28.0), Vector2(64.0, 56.0))

func _draw_slot(center: Vector2, identity: int) -> void:
	draw_circle(center + Vector2(1.0, 3.0), 20.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(center, 18.0, TeamData.color(identity))
	TeamData.draw_symbol(self, identity, center, 18.0, Color(0.06, 0.08, 0.12, 0.9))

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.13, 0.97)
	style.border_color = Color(0.28, 0.37, 0.54)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	return style

func _button_style(color_value: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color_value
	style.border_color = Color(0.48, 0.6, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

