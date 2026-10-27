class_name ShooterView
extends Control

signal shot_reached_lane(identity: int, impact_x: float)

const SHOT_TRAVEL_TIME := 0.20

var loaded_identity: int = TeamData.Identity.RED
var next_identity: int = TeamData.Identity.BLUE
var shooter_x := 400.0
var shooter_y := 650.0
var track_left := 42.0
var track_right := 850.0
var shot_ceiling := 118.0
var safe_left := 0.0
var safe_right := 900.0
var _preview_on_left := false
var _shots: Array[Dictionary] = []
var _muzzle_flash := 0.0
var simulation_paused := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func configure_layout(y_position: float, left_edge: float, right_edge: float, ceiling: float, safe_left_edge := 0.0, safe_right_edge := 0.0) -> void:
	shooter_y = y_position
	track_left = left_edge
	track_right = maxf(left_edge + 120.0, right_edge)
	shot_ceiling = ceiling
	safe_left = safe_left_edge
	safe_right = safe_right_edge if safe_right_edge > safe_left_edge else right_edge + 48.0
	shooter_x = clampf(shooter_x, track_left, track_right)
	_update_preview_side()
	queue_redraw()

func set_loaded(identity: int) -> void:
	loaded_identity = identity
	queue_redraw()

func set_ammunition(loaded: int, next_value: int) -> void:
	loaded_identity = loaded
	next_identity = next_value
	queue_redraw()

func loaded_ball_center() -> Vector2:
	return Vector2(shooter_x, shooter_y - 23.0)

func next_ball_center() -> Vector2:
	return Vector2(shooter_x + (-34.0 if _preview_on_left else 34.0), shooter_y - 23.0)

func reset_run() -> void:
	_shots.clear()
	_muzzle_flash = 0.0
	simulation_paused = false
	set_process(true)
	queue_redraw()

func set_simulation_paused(value: bool) -> void:
	simulation_paused = value

func move_to(screen_x: float) -> void:
	shooter_x = clampf(screen_x, track_left, track_right)
	_update_preview_side()
	queue_redraw()

func _update_preview_side() -> void:
	if not _preview_on_left and shooter_x + 45.0 > safe_right:
		_preview_on_left = true
	elif _preview_on_left and shooter_x + 58.0 < safe_right:
		_preview_on_left = false

func launch(identity: int) -> void:
	var start := Vector2(shooter_x, shooter_y - 42.0)
	_shots.append({
		"position": start,
		"start": start,
		"target_y": shot_ceiling,
		"elapsed": 0.0,
		"identity": identity,
	})
	_muzzle_flash = 0.12
	queue_redraw()

func _process(delta: float) -> void:
	if simulation_paused:
		return
	var needs_redraw := false
	for index in range(_shots.size() - 1, -1, -1):
		var shot: Dictionary = _shots[index]
		shot.elapsed = minf(float(shot.elapsed) + maxf(delta, 0.0), SHOT_TRAVEL_TIME)
		var ratio := clampf(float(shot.elapsed) / SHOT_TRAVEL_TIME, 0.0, 1.0)
		var start: Vector2 = shot.start
		shot.position = Vector2(start.x, lerpf(start.y, float(shot.target_y), ratio))
		_shots[index] = shot
		if ratio >= 1.0:
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
	var ball_center := loaded_ball_center()
	draw_circle(ball_center, 19.0, TeamData.color(loaded_identity))
	TeamData.draw_symbol(self, loaded_identity, ball_center, 19.0, Color(0.07, 0.09, 0.14, 0.9))
	var preview_center := next_ball_center()
	draw_circle(preview_center + Vector2(1.0, 2.0), 10.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(preview_center, 9.0, TeamData.color(next_identity))
	draw_arc(preview_center, 9.0, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.4), 1.0)
	TeamData.draw_symbol(self, next_identity, preview_center, 9.0, Color(0.07, 0.09, 0.14, 0.9))
	if _muzzle_flash > 0.0:
		draw_circle(Vector2(shooter_x, shooter_y - 50.0), 8.0 + _muzzle_flash * 55.0, Color(1.0, 0.92, 0.55, _muzzle_flash * 5.0))

	for shot in _shots:
		var shot_position: Vector2 = shot.position
		var identity: int = shot.identity
		draw_circle(shot_position + Vector2(1.0, 3.0), 13.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_circle(shot_position, 12.0, TeamData.color(identity))
		TeamData.draw_symbol(self, identity, shot_position, 12.0, Color(0.06, 0.08, 0.12, 0.9))

