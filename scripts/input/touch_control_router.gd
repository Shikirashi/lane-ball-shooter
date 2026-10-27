class_name TouchControlRouter
extends RefCounted

enum Mode { CLASSIC, SIDE }
enum Handedness { RIGHT, LEFT }

var mode := Mode.CLASSIC
var handedness := Handedness.RIGHT
var safe_rect := Rect2()
var primary_id := -1
var secondary_id := -1
var _roles := {}
var _last_positions := {}

func configure(mode_value: int, handedness_value: int, usable_rect: Rect2) -> void:
	mode = clampi(mode_value, Mode.CLASSIC, Mode.SIDE)
	handedness = clampi(handedness_value, Handedness.RIGHT, Handedness.LEFT)
	safe_rect = usable_rect
	cancel_all()

func press(touch_id: int, position: Vector2) -> Dictionary:
	if _roles.has(touch_id):
		return {}
	_last_positions[touch_id] = position
	if mode == Mode.CLASSIC:
		if primary_id < 0:
			primary_id = touch_id
			_roles[touch_id] = &"classic_aim"
			return {"aim_absolute": position.x}
		if secondary_id < 0:
			secondary_id = touch_id
			_roles[touch_id] = &"classic_swap"
			return {"swap": true}
		_roles[touch_id] = &"ignored"
		return {}
	var quarter := safe_rect.size.x * 0.25
	var aim_on_right := handedness == Handedness.RIGHT
	var aim_rect := Rect2(Vector2(safe_rect.end.x - quarter if aim_on_right else safe_rect.position.x, safe_rect.position.y), Vector2(quarter, safe_rect.size.y))
	var action_rect := Rect2(Vector2(safe_rect.position.x if aim_on_right else safe_rect.end.x - quarter, safe_rect.position.y), Vector2(quarter, safe_rect.size.y))
	if aim_rect.has_point(position):
		_roles[touch_id] = &"side_aim"
		return {}
	if action_rect.has_point(position):
		var top := position.y < action_rect.get_center().y
		_roles[touch_id] = &"side_action"
		return {"swap": true} if top else {"shoot": true}
	_roles[touch_id] = &"ignored"
	return {}

func drag(touch_id: int, position: Vector2, relative := Vector2.ZERO) -> Dictionary:
	if not _roles.has(touch_id):
		return {}
	var previous: Vector2 = _last_positions.get(touch_id, position)
	_last_positions[touch_id] = position
	var role := StringName(_roles[touch_id])
	if role == &"classic_aim":
		return {"aim_absolute": position.x}
	if role == &"side_aim":
		var delta_x := relative.x if not is_zero_approx(relative.x) else position.x - previous.x
		return {"aim_relative": delta_x}
	return {}

func release(touch_id: int, position: Vector2, canceled := false) -> Dictionary:
	if not _roles.has(touch_id):
		return {}
	var role := StringName(_roles[touch_id])
	_roles.erase(touch_id)
	_last_positions.erase(touch_id)
	if touch_id == primary_id:
		primary_id = -1
	if touch_id == secondary_id:
		secondary_id = -1
	if role == &"classic_aim" and not canceled:
		return {"aim_absolute": position.x, "shoot": true}
	return {}

func cancel_all() -> void:
	primary_id = -1
	secondary_id = -1
	_roles.clear()
	_last_positions.clear()

func role_for(touch_id: int) -> StringName:
	return StringName(_roles.get(touch_id, &""))
