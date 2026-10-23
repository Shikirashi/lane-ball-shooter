class_name ShooterView
extends Control

signal shot_reached_lane(identity: int, impact_x: float)

var loaded_identity: int = TeamData.Identity.RED
var shooter_x := 400.0
var shooter_y := 650.0
var track_left := 42.0
var track_right := 850.0
var shot_ceiling := 118.0
var _shots: Array[Dictionary] = []
var _muzzle_flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func configure_layout(y_position: float, left_edge: float, right_edge: float, ceiling: float) -> void:
	shooter_y = y_position
	track_left = left_edge
	track_right = maxf(left_edge + 120.0, right_edge)
	shot_ceiling = ceiling
	shooter_x = clampf(shooter_x, track_left, track_right)
	queue_redraw()

func set_loaded(identity: int) -> void:
	loaded_identity = identity
	queue_redraw()

func move_to(screen_x: float) -> void:
	shooter_x = clampf(screen_x, track_left, track_right)
	queue_redraw()

func launch(identity: int) -> void:
	_shots.append({"position": Vector2(shooter_x, shooter_y - 42.0), "identity": identity})
	_muzzle_flash = 0.12
	queue_redraw()

func _process(delta: float) -> void:
	var needs_redraw := false
	for index in range(_shots.size() - 1, -1, -1):
		var shot: Dictionary = _shots[index]
		var previous_y := float(shot.position.y)
		shot.position.y -= 610.0 * delta
		_shots[index] = shot
		if previous_y >= shot_ceiling and float(shot.position.y) <= shot_ceiling:
			shot_reached_lane.emit(int(shot.identity), float(shot.position.x))
			_shots.remove_at(index)
		needs_redraw = true
	if _muzzle_flash > 0.0:
		_muzzle_flash = maxf(0.0, _muzzle_flash - delta)
		needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	var track_color := Color(0.32, 0.4, 0.55, 0.8)
	draw_line(Vector2(track_left, shooter_y + 27.0), Vector2(track_right, shooter_y + 27.0), track_color, 4.0)
	draw_circle(Vector2(track_left, shooter_y + 27.0), 5.0, track_color)
	draw_circle(Vector2(track_right, shooter_y + 27.0), 5.0, track_color)
	draw_dashed_line(Vector2(shooter_x, shooter_y - 48.0), Vector2(shooter_x, shot_ceiling), Color(0.75, 0.88, 1.0, 0.17), 1.0, 8.0)

	var body_color := Color(0.18, 0.22, 0.33)
	draw_colored_polygon(PackedVector2Array([
		Vector2(shooter_x - 28.0, shooter_y + 23.0),
		Vector2(shooter_x + 28.0, shooter_y + 23.0),
		Vector2(shooter_x + 18.0, shooter_y - 12.0),
		Vector2(shooter_x - 18.0, shooter_y - 12.0),
	]), body_color)
	draw_rect(Rect2(shooter_x - 7.0, shooter_y - 34.0, 14.0, 30.0), Color(0.55, 0.63, 0.75), true)
	var ball_center := Vector2(shooter_x, shooter_y - 23.0)
	draw_circle(ball_center, 19.0, TeamData.color(loaded_identity))
	TeamData.draw_symbol(self, loaded_identity, ball_center, 19.0, Color(0.07, 0.09, 0.14, 0.9))
	if _muzzle_flash > 0.0:
		draw_circle(Vector2(shooter_x, shooter_y - 50.0), 8.0 + _muzzle_flash * 55.0, Color(1.0, 0.92, 0.55, _muzzle_flash * 5.0))

	for shot in _shots:
		var shot_position: Vector2 = shot.position
		var identity: int = shot.identity
		draw_circle(shot_position + Vector2(1.0, 3.0), 13.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_circle(shot_position, 12.0, TeamData.color(identity))
		TeamData.draw_symbol(self, identity, shot_position, 12.0, Color(0.06, 0.08, 0.12, 0.9))

