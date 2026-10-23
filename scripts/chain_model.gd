class_name ChainModel
extends RefCounted

signal state_changed
signal match_completed(identity: int, group_size: int)

const DEFAULT_SPEED := 34.0
const DEFAULT_SPACING := 58.0
const DEFAULT_RADIUS := 22.0
const DEFAULT_INITIAL_POPULATION := 12
const DEFAULT_CACHE_RETURN_BATCH := 3
const DEFAULT_EMPTY_RETURN_COUNT := 8
const DEFAULT_MAX_AUTO_POPULATION := 24
const MATCH_SIZE := 3
const GAP_CLOSE_SPEED := 420.0
const SEED_PATTERN: Array[int] = [
	TeamData.Identity.RED,
	TeamData.Identity.BLUE,
	TeamData.Identity.BLUE,
	TeamData.Identity.YELLOW,
	TeamData.Identity.GREEN,
	TeamData.Identity.RED,
	TeamData.Identity.YELLOW,
	TeamData.Identity.YELLOW,
	TeamData.Identity.GREEN,
	TeamData.Identity.BLUE,
	TeamData.Identity.RED,
	TeamData.Identity.GREEN,
]

var speed := DEFAULT_SPEED
var spacing := DEFAULT_SPACING
var radius := DEFAULT_RADIUS
var initial_population := DEFAULT_INITIAL_POPULATION
var cache_return_batch := DEFAULT_CACHE_RETURN_BATCH
var empty_return_count := DEFAULT_EMPTY_RETURN_COUNT
var max_auto_population := DEFAULT_MAX_AUTO_POPULATION
var lane_width := 1252.0

var balls: Array[Dictionary] = []
var cache: Array[int] = []
var total_match_events := 0
var last_match_identity := -1
var last_match_size := 0
var event_log: Array[Dictionary] = []

var _next_ball_id := 1

func _init() -> void:
	seed_stream()

func set_lane_width(value: float) -> void:
	lane_width = maxf(value, spacing * 3.0)

func advance(delta: float) -> void:
	var travel := speed * maxf(delta, 0.0)
	for index in range(balls.size()):
		var ball := balls[index]
		ball.x -= travel
		ball.display_x -= travel
		ball.display_x = move_toward(float(ball.display_x), float(ball.x), GAP_CLOSE_SPEED * maxf(delta, 0.0))
		balls[index] = ball

	var rolled_off := false
	while not balls.is_empty() and float(balls[0].x) + radius < 0.0:
		var exited: Dictionary = balls.pop_front()
		cache.append(int(exited.identity))
		rolled_off = true
	if balls.is_empty():
		_ensure_playable_stream()
	if travel > 0.0 or rolled_off:
		state_changed.emit()

func insert_shot(identity: int, impact_x: float) -> int:
	if balls.is_empty():
		var empty_ball := _make_ball(identity, clampf(impact_x, radius, lane_width - radius))
		balls.append(empty_ball)
		state_changed.emit()
		_resolve_inserted_match(0)
		return int(empty_ball.uid)

	var insert_index := _nearest_gap_index(impact_x)
	var logical_x: float
	if insert_index == 0:
		logical_x = float(balls[0].x) - spacing
	elif insert_index == balls.size():
		logical_x = float(balls[-1].x) + spacing
	else:
		logical_x = float(balls[insert_index - 1].x) + spacing
		_shift_logical_positions(insert_index, spacing)

	var inserted := _make_ball(identity, logical_x, impact_x)
	balls.insert(insert_index, inserted)
	state_changed.emit()
	_resolve_inserted_match(insert_index)
	return int(inserted.uid)

func return_cached(requested_count: int = -1) -> int:
	var count := cache_return_batch if requested_count < 0 else requested_count
	count = mini(maxi(count, 0), cache.size())
	for unused in range(count):
		_append_on_right(cache.pop_front())
	if count > 0:
		state_changed.emit()
	return count

func seed_stream() -> void:
	if balls.size() + cache.size() > 0:
		return
	var count := mini(initial_population, max_auto_population)
	var right_x := lane_width - radius
	var left_x := right_x - spacing * (count - 1)
	for index in range(count):
		balls.append(_make_ball(SEED_PATTERN[index % SEED_PATTERN.size()], left_x + spacing * index))
	state_changed.emit()

func set_test_state(identities: Array[int], start_x := 100.0, cached: Array[int] = []) -> void:
	balls.clear()
	cache = cached.duplicate()
	total_match_events = 0
	last_match_identity = -1
	last_match_size = 0
	event_log.clear()
	for index in range(identities.size()):
		balls.append(_make_ball(identities[index], start_x + spacing * index))
	state_changed.emit()

func identities() -> Array[int]:
	var result: Array[int] = []
	for ball in balls:
		result.append(int(ball.identity))
	return result

func _nearest_gap_index(impact_x: float) -> int:
	var best_index := 0
	var best_distance := absf(impact_x - (float(balls[0].x) - spacing * 0.5))
	for index in range(1, balls.size()):
		var gap_x := (float(balls[index - 1].x) + float(balls[index].x)) * 0.5
		var distance := absf(impact_x - gap_x)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	var end_distance := absf(impact_x - (float(balls[-1].x) + spacing * 0.5))
	if end_distance < best_distance:
		best_index = balls.size()
	return best_index

func _resolve_inserted_match(insert_index: int) -> void:
	if insert_index < 0 or insert_index >= balls.size():
		return
	var group := _group_at(insert_index)
	if int(group.size) < MATCH_SIZE:
		return

	var return_requests := 0
	var boundary := int(group.start)
	_remove_group(int(group.start), int(group.size), int(group.identity))
	return_requests += cache_return_batch

	while boundary > 0 and boundary < balls.size():
		if int(balls[boundary - 1].identity) != int(balls[boundary].identity):
			break
		var cascade := _group_at(boundary)
		if int(cascade.size) < MATCH_SIZE:
			break
		boundary = int(cascade.start)
		_remove_group(int(cascade.start), int(cascade.size), int(cascade.identity))
		return_requests += cache_return_batch

	if return_requests > 0:
		return_cached(return_requests)
	_ensure_playable_stream()
	state_changed.emit()

func _group_at(index: int) -> Dictionary:
	var identity := int(balls[index].identity)
	var start := index
	var end := index
	while start > 0 and int(balls[start - 1].identity) == identity:
		start -= 1
	while end + 1 < balls.size() and int(balls[end + 1].identity) == identity:
		end += 1
	return {"start": start, "size": end - start + 1, "identity": identity}

func _remove_group(start: int, count: int, identity: int) -> void:
	for unused in range(count):
		balls.remove_at(start)
	_shift_logical_positions(start, -spacing * count)
	total_match_events += 1
	last_match_identity = identity
	last_match_size = count
	event_log.append({"identity": identity, "size": count})
	match_completed.emit(identity, count)

func _shift_logical_positions(from_index: int, amount: float) -> void:
	for index in range(from_index, balls.size()):
		var ball := balls[index]
		ball.x += amount
		balls[index] = ball

func _append_on_right(identity: int) -> void:
	var spawn_x := lane_width - radius
	if not balls.is_empty():
		spawn_x = maxf(spawn_x, float(balls[-1].x) + spacing)
	balls.append(_make_ball(identity, spawn_x, spawn_x + minf(spacing * 0.35, 18.0)))

func _ensure_playable_stream() -> void:
	if not balls.is_empty():
		return
	if not cache.is_empty():
		return_cached(mini(empty_return_count, cache.size()))
	else:
		seed_stream()

func _make_ball(identity: int, logical_x: float, display_x := NAN) -> Dictionary:
	var resolved_display := logical_x if is_nan(display_x) else display_x
	var result := {
		"uid": _next_ball_id,
		"identity": posmod(identity, TeamData.COUNT),
		"x": logical_x,
		"display_x": resolved_display,
	}
	_next_ball_id += 1
	return result
