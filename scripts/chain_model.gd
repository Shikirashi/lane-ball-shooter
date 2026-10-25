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
const DEFAULT_SHOT_RADIUS := 12.0
const RETURN_CATCHUP_SPEED := 120.0
const ROLLBACK_SPEED := 360.0
const MAGNETIC_ROLLBACK_SPEED := 480.0
const ROLLBACK_CONTACT_EPSILON := 0.05
const TAIL_RECOIL_SPACING_FACTOR := 1.25
const MAX_SIMULATION_STEP := 1.0 / 60.0
const ADJACENCY_GAP_FACTOR := 1.25
const DEFAULT_FRESH_SEED := 0x1B5C008
const FRESH_RUN_LENGTH_WEIGHTS: Array[int] = [20, 30, 18, 13, 9, 6, 4]
const SEED_PATTERN: Array[int] = [
	TeamData.Identity.RED,
	TeamData.Identity.RED,
	TeamData.Identity.BLUE,
	TeamData.Identity.BLUE,
	TeamData.Identity.BLUE,
	TeamData.Identity.YELLOW,
	TeamData.Identity.YELLOW,
	TeamData.Identity.GREEN,
	TeamData.Identity.GREEN,
	TeamData.Identity.GREEN,
	TeamData.Identity.GREEN,
	TeamData.Identity.RED,
]

var speed := DEFAULT_SPEED
var spacing := DEFAULT_SPACING
var radius := DEFAULT_RADIUS
var initial_population := DEFAULT_INITIAL_POPULATION
var cache_return_batch := DEFAULT_CACHE_RETURN_BATCH
var empty_return_count := DEFAULT_EMPTY_RETURN_COUNT
var max_auto_population := DEFAULT_MAX_AUTO_POPULATION
var lane_width := 1252.0
var continuous_feed_enabled := true

var balls: Array[Dictionary] = []
var cache: Array[int] = []
var total_match_events := 0
var last_match_identity := -1
var last_match_size := 0
var event_log: Array[Dictionary] = []
var pending_cache_returns := 0
var total_fresh_generated := 0
var total_cache_returned := 0
var fresh_seed := DEFAULT_FRESH_SEED
var fresh_identity_counts: Array[int] = [0, 0, 0, 0]
var fresh_run_length_counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
var fresh_runs_generated := 0
var longest_fresh_run := 0
var rollback_gaps: Array[Dictionary] = []
var total_rollbacks_started := 0
var total_rollbacks_completed := 0

var _next_ball_id := 1
var _fresh_color_bag: Array[int] = []
var _fresh_rng := RandomNumberGenerator.new()
var _fresh_run_identity := -1
var _fresh_run_remaining := 0
var _previous_fresh_run_identity := -1
var _returns_since_fresh := 0
var _next_rollback_id := 1

func _init() -> void:
	_reset_fresh_generator()
	seed_stream()

func set_lane_width(value: float) -> void:
	lane_width = maxf(value, spacing * 3.0)

func reset_run() -> void:
	continuous_feed_enabled = true
	balls.clear()
	cache.clear()
	total_match_events = 0
	last_match_identity = -1
	last_match_size = 0
	event_log.clear()
	pending_cache_returns = 0
	total_fresh_generated = 0
	total_cache_returned = 0
	_next_ball_id = 1
	_reset_fresh_generator()
	_returns_since_fresh = 0
	rollback_gaps.clear()
	total_rollbacks_started = 0
	total_rollbacks_completed = 0
	_next_rollback_id = 1
	seed_stream()

func advance(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	var rolled_off := false
	if remaining <= 0.0:
		rolled_off = _advance_step(0.0)
	while remaining > 0.000001:
		var step := minf(remaining, MAX_SIMULATION_STEP)
		rolled_off = _advance_step(step) or rolled_off
		remaining -= step
	if delta > 0.0 or rolled_off:
		state_changed.emit()

func _advance_step(delta: float) -> bool:
	var travel := speed * delta
	for index in range(balls.size()):
		var ball := balls[index]
		ball.x -= travel
		ball.display_x -= travel
		balls[index] = ball
	_close_disconnected_gaps(delta)
	_update_rollbacks(delta)
	for index in range(balls.size()):
		var ball := balls[index]
		ball.display_x = move_toward(float(ball.display_x), float(ball.x), GAP_CLOSE_SPEED * delta)
		balls[index] = ball

	var rolled_off := false
	while not balls.is_empty() and float(balls[0].x) + radius < 0.0:
		var exited: Dictionary = balls.pop_front()
		cache.append(int(exited.identity))
		rolled_off = true
	if continuous_feed_enabled:
		_feed_right_edge()
	elif balls.is_empty():
		_ensure_playable_stream()
	_prune_invalid_rollbacks()
	return rolled_off

## Returns true only when the projectile horizontally overlaps a rendered chain ball.
## The tolerance is the chain-ball radius plus the projectile's visual radius.
func try_insert_shot(identity: int, impact_x: float, shot_radius := DEFAULT_SHOT_RADIUS) -> bool:
	var contact_index := _find_contact_index(impact_x, radius + maxf(shot_radius, 0.0))
	if contact_index < 0:
		return false
	var insert_after := impact_x >= float(balls[contact_index].display_x)
	_insert_beside_contact(identity, contact_index, insert_after, impact_x)
	return true

func return_cached(requested_count: int = -1) -> int:
	var count := cache_return_batch if requested_count < 0 else requested_count
	if not continuous_feed_enabled:
		count = mini(maxi(count, 0), cache.size())
		for unused in range(count):
			_append_on_right(cache.pop_front())
		if count > 0:
			state_changed.emit()
		return count
	var available_to_request := maxi(0, cache.size() - pending_cache_returns)
	count = mini(maxi(count, 0), available_to_request)
	pending_cache_returns += count
	var returned_before := total_cache_returned
	_feed_right_edge()
	var admitted := total_cache_returned - returned_before
	if count > 0 or admitted > 0:
		state_changed.emit()
	return admitted

func seed_stream() -> void:
	if balls.size() + cache.size() > 0:
		return
	var count := mini(initial_population, max_auto_population)
	var right_x := lane_width - radius
	var left_x := right_x - spacing * (count - 1)
	for index in range(count):
		balls.append(_make_ball(SEED_PATTERN[index % SEED_PATTERN.size()], left_x + spacing * index))
		total_fresh_generated += 1
	state_changed.emit()

func set_test_state(identities: Array[int], start_x := 100.0, cached: Array[int] = []) -> void:
	continuous_feed_enabled = false
	balls.clear()
	cache = cached.duplicate()
	total_match_events = 0
	last_match_identity = -1
	last_match_size = 0
	event_log.clear()
	pending_cache_returns = 0
	_returns_since_fresh = 0
	rollback_gaps.clear()
	total_rollbacks_started = 0
	total_rollbacks_completed = 0
	_next_rollback_id = 1
	for index in range(identities.size()):
		balls.append(_make_ball(identities[index], start_x + spacing * index))
	state_changed.emit()

func identities() -> Array[int]:
	var result: Array[int] = []
	for ball in balls:
		result.append(int(ball.identity))
	return result

func _find_contact_index(impact_x: float, tolerance: float) -> int:
	var closest_index := -1
	var closest_distance := INF
	for index in range(balls.size()):
		var distance := absf(impact_x - float(balls[index].display_x))
		if distance <= tolerance and distance < closest_distance:
			closest_index = index
			closest_distance = distance
	return closest_index

func _insert_beside_contact(identity: int, contact_index: int, insert_after: bool, impact_x: float) -> void:
	var insert_index := contact_index + 1 if insert_after else contact_index
	var logical_x: float
	if insert_after:
		logical_x = float(balls[contact_index].x) + spacing
		if contact_index + 1 < balls.size():
			var next_segment_end := _connected_segment_end(contact_index + 1)
			if _are_adjacent(contact_index, contact_index + 1):
				_shift_logical_positions(contact_index + 1, next_segment_end, spacing)
			else:
				var gap_to_next := float(balls[contact_index + 1].x) - float(balls[contact_index].x)
				if gap_to_next < spacing * 2.0:
					_shift_logical_positions(contact_index + 1, next_segment_end, spacing * 2.0 - gap_to_next)
	else:
		logical_x = float(balls[contact_index].x) - spacing
		if contact_index > 0:
			var current_segment_end := _connected_segment_end(contact_index)
			if _are_adjacent(contact_index - 1, contact_index):
				logical_x = float(balls[contact_index].x)
				_shift_logical_positions(contact_index, current_segment_end, spacing)
			else:
				var gap_from_previous := float(balls[contact_index].x) - float(balls[contact_index - 1].x)
				if gap_from_previous < spacing * 2.0:
					var required_shift := spacing * 2.0 - gap_from_previous
					logical_x += required_shift
					_shift_logical_positions(contact_index, current_segment_end, required_shift)

	var contact_uid := int(balls[contact_index].uid)
	var inserted_ball := _make_ball(identity, logical_x, impact_x)
	balls.insert(insert_index, inserted_ball)
	_update_rollback_endpoint_after_insert(contact_uid, int(inserted_ball.uid), insert_after)
	state_changed.emit()
	_resolve_inserted_match(insert_index)

func _resolve_inserted_match(insert_index: int) -> void:
	if insert_index < 0 or insert_index >= balls.size():
		return
	var group := _group_at(insert_index)
	if int(group.size) < MATCH_SIZE:
		return

	_remove_group(int(group.start), int(group.size), int(group.identity))
	return_cached(cache_return_batch)
	_ensure_playable_stream()
	state_changed.emit()

func _group_at(index: int) -> Dictionary:
	var identity := int(balls[index].identity)
	var start := index
	var end := index
	while start > 0 and _are_adjacent(start - 1, start) and int(balls[start - 1].identity) == identity:
		start -= 1
	while end + 1 < balls.size() and _are_adjacent(end, end + 1) and int(balls[end + 1].identity) == identity:
		end += 1
	return {"start": start, "size": end - start + 1, "identity": identity}

func _remove_group(start: int, count: int, identity: int) -> void:
	var left_uid := int(balls[start - 1].uid) if start > 0 else -1
	var right_uid := int(balls[start + count].uid) if start + count < balls.size() else -1
	for unused in range(count):
		balls.remove_at(start)
	_create_rollback(left_uid, right_uid, count)
	total_match_events += 1
	last_match_identity = identity
	last_match_size = count
	event_log.append({"identity": identity, "size": count})
	match_completed.emit(identity, count)

func _shift_logical_positions(from_index: int, through_index: int, amount: float) -> void:
	for index in range(from_index, mini(through_index + 1, balls.size())):
		var ball := balls[index]
		ball.x += amount
		balls[index] = ball

func _are_adjacent(left_index: int, right_index: int) -> bool:
	if left_index < 0 or right_index >= balls.size() or right_index != left_index + 1:
		return false
	if _is_rollback_boundary(int(balls[left_index].uid), int(balls[right_index].uid)):
		return false
	var gap := float(balls[right_index].x) - float(balls[left_index].x)
	return gap >= 0.0 and gap <= spacing * ADJACENCY_GAP_FACTOR

func _connected_segment_end(start_index: int) -> int:
	var result := start_index
	while result + 1 < balls.size() and _are_adjacent(result, result + 1):
		result += 1
	return result

func _connected_segment_start(end_index: int) -> int:
	var result := end_index
	while result > 0 and _are_adjacent(result - 1, result):
		result -= 1
	return result

func _close_disconnected_gaps(delta: float) -> void:
	if delta <= 0.0:
		return
	for boundary in range(1, balls.size()):
		var gap := float(balls[boundary].x) - float(balls[boundary - 1].x)
		if gap <= spacing:
			continue
		if _is_rollback_boundary(int(balls[boundary - 1].uid), int(balls[boundary].uid)):
			continue
		var catchup := minf(RETURN_CATCHUP_SPEED * delta, gap - spacing)
		for index in range(boundary, balls.size()):
			var ball := balls[index]
			ball.x -= catchup
			ball.display_x -= catchup
			balls[index] = ball

func _create_rollback(left_uid: int, right_uid: int, removed_count: int) -> void:
	if left_uid < 0:
		return
	var state := {
		"id": _next_rollback_id,
		"left_uid": left_uid,
		"right_uid": right_uid,
		"tail_remaining": minf(spacing * removed_count, spacing * TAIL_RECOIL_SPACING_FACTOR) if right_uid < 0 else 0.0,
	}
	_next_rollback_id += 1
	rollback_gaps.append(state)
	total_rollbacks_started += 1

func _update_rollbacks(delta: float) -> void:
	if delta <= 0.0 or rollback_gaps.is_empty():
		return
	var state_ids: Array[int] = []
	for state in rollback_gaps:
		state_ids.append(int(state.id))
	for state_id in state_ids:
		var state_index := _rollback_index_by_id(state_id)
		if state_index < 0:
			continue
		var state := rollback_gaps[state_index]
		var left_index := _ball_index_by_uid(int(state.left_uid))
		if left_index < 0:
			rollback_gaps.remove_at(state_index)
			continue
		var segment_start := _connected_segment_start(left_index)
		var right_uid := int(state.right_uid)
		if right_uid < 0:
			var tail_move := minf(float(state.tail_remaining), ROLLBACK_SPEED * delta)
			_shift_positions(segment_start, left_index, tail_move, true)
			state.tail_remaining = float(state.tail_remaining) - tail_move
			if float(state.tail_remaining) <= ROLLBACK_CONTACT_EPSILON:
				rollback_gaps.remove_at(state_index)
				total_rollbacks_completed += 1
			else:
				rollback_gaps[state_index] = state
			continue

		var right_index := _ball_index_by_uid(right_uid)
		if right_index != left_index + 1:
			rollback_gaps.remove_at(state_index)
			continue
		var gap := float(balls[right_index].x) - float(balls[left_index].x)
		var matching_ends := int(balls[left_index].identity) == int(balls[right_index].identity)
		var rollback_speed := MAGNETIC_ROLLBACK_SPEED if matching_ends else ROLLBACK_SPEED
		var rollback_move := minf(maxf(0.0, gap - spacing), rollback_speed * delta)
		_shift_positions(segment_start, left_index, rollback_move, true)
		gap -= rollback_move
		if gap <= spacing + ROLLBACK_CONTACT_EPSILON:
			_complete_rollback(state_id)

func _complete_rollback(state_id: int) -> void:
	var state_index := _rollback_index_by_id(state_id)
	if state_index < 0:
		return
	var state := rollback_gaps[state_index]
	rollback_gaps.remove_at(state_index)
	total_rollbacks_completed += 1
	var left_index := _ball_index_by_uid(int(state.left_uid))
	var right_index := _ball_index_by_uid(int(state.right_uid))
	if left_index < 0 or right_index != left_index + 1:
		return
	if int(balls[left_index].identity) != int(balls[right_index].identity):
		return
	var cascade := _group_at(left_index)
	if int(cascade.size) < MATCH_SIZE:
		return
	_remove_group(int(cascade.start), int(cascade.size), int(cascade.identity))
	return_cached(cache_return_batch)
	_ensure_playable_stream()

func _shift_positions(from_index: int, through_index: int, amount: float, include_display: bool) -> void:
	if amount <= 0.0:
		return
	for index in range(maxi(0, from_index), mini(through_index + 1, balls.size())):
		var ball := balls[index]
		ball.x += amount
		if include_display:
			ball.display_x += amount
		balls[index] = ball

func _is_rollback_boundary(left_uid: int, right_uid: int) -> bool:
	for state in rollback_gaps:
		if int(state.left_uid) == left_uid and int(state.right_uid) == right_uid:
			return true
	return false

func _update_rollback_endpoint_after_insert(contact_uid: int, inserted_uid: int, insert_after: bool) -> void:
	for index in range(rollback_gaps.size()):
		var state := rollback_gaps[index]
		if insert_after and int(state.left_uid) == contact_uid:
			state.left_uid = inserted_uid
		elif not insert_after and int(state.right_uid) == contact_uid:
			state.right_uid = inserted_uid
		rollback_gaps[index] = state

func _ball_index_by_uid(uid: int) -> int:
	for index in range(balls.size()):
		if int(balls[index].uid) == uid:
			return index
	return -1

func _rollback_index_by_id(state_id: int) -> int:
	for index in range(rollback_gaps.size()):
		if int(rollback_gaps[index].id) == state_id:
			return index
	return -1

func _prune_invalid_rollbacks() -> void:
	for index in range(rollback_gaps.size() - 1, -1, -1):
		var state := rollback_gaps[index]
		if _ball_index_by_uid(int(state.left_uid)) < 0:
			rollback_gaps.remove_at(index)
		elif int(state.right_uid) >= 0 and _ball_index_by_uid(int(state.right_uid)) < 0:
			rollback_gaps.remove_at(index)

func _append_on_right(identity: int) -> void:
	var spawn_x := lane_width - radius
	if not balls.is_empty():
		spawn_x = float(balls[-1].x) + spacing if continuous_feed_enabled else maxf(spawn_x, float(balls[-1].x) + spacing)
	var display_x := spawn_x if continuous_feed_enabled else spawn_x + minf(spacing * 0.35, 18.0)
	balls.append(_make_ball(identity, spawn_x, display_x))

func _ensure_playable_stream() -> void:
	if continuous_feed_enabled:
		_feed_right_edge()
	elif balls.is_empty():
		if not cache.is_empty():
			return_cached(mini(empty_return_count, cache.size()))
		else:
			seed_stream()

## Fills only physically available slots up to the right boundary. Requested FIFO
## returns are admitted in batches, followed by at least one fresh shuffle-bag ball,
## so recycling cannot starve the independent infinite source. The live array stays
## bounded; the rollover cache intentionally grows linearly with legitimate exits.
func _feed_right_edge() -> void:
	var right_edge := lane_width - radius
	while balls.size() < max_auto_population:
		if not balls.is_empty() and float(balls[-1].x) + spacing > right_edge + 0.001:
			break
		var use_return := pending_cache_returns > 0 and not cache.is_empty() and _returns_since_fresh < cache_return_batch
		if use_return:
			_append_on_right(cache.pop_front())
			pending_cache_returns -= 1
			total_cache_returned += 1
			_returns_since_fresh += 1
		else:
			_append_on_right(_draw_fresh_identity())
			total_fresh_generated += 1
			_returns_since_fresh = 0

func _draw_fresh_identity() -> int:
	if _fresh_run_remaining <= 0:
		_fresh_run_identity = _draw_fresh_run_color()
		_fresh_run_remaining = _draw_fresh_run_length()
		_previous_fresh_run_identity = _fresh_run_identity
		fresh_runs_generated += 1
		longest_fresh_run = maxi(longest_fresh_run, _fresh_run_remaining)
		fresh_run_length_counts[_fresh_run_remaining - 1] += 1
	_fresh_run_remaining -= 1
	fresh_identity_counts[_fresh_run_identity] += 1
	return _fresh_run_identity

func set_fresh_seed(seed_value: int) -> void:
	fresh_seed = seed_value if seed_value != 0 else 1
	_reset_fresh_generator()

func _reset_fresh_generator() -> void:
	_fresh_rng.seed = fresh_seed
	_fresh_color_bag.clear()
	_fresh_run_identity = -1
	_fresh_run_remaining = 0
	_previous_fresh_run_identity = -1
	fresh_identity_counts = [0, 0, 0, 0]
	fresh_run_length_counts = [0, 0, 0, 0, 0, 0, 0]
	fresh_runs_generated = 0
	longest_fresh_run = 0

func _draw_fresh_run_color() -> int:
	if _fresh_color_bag.is_empty():
		for identity in range(TeamData.COUNT):
			_fresh_color_bag.append(identity)
		for index in range(_fresh_color_bag.size() - 1, 0, -1):
			var swap_index := _fresh_rng.randi_range(0, index)
			var temporary := _fresh_color_bag[index]
			_fresh_color_bag[index] = _fresh_color_bag[swap_index]
			_fresh_color_bag[swap_index] = temporary
	if _fresh_color_bag.size() > 1 and _fresh_color_bag[-1] == _previous_fresh_run_identity:
		var swap_index := _fresh_rng.randi_range(0, _fresh_color_bag.size() - 2)
		var temporary := _fresh_color_bag[-1]
		_fresh_color_bag[-1] = _fresh_color_bag[swap_index]
		_fresh_color_bag[swap_index] = temporary
	return _fresh_color_bag.pop_back()

func _draw_fresh_run_length() -> int:
	var roll := _fresh_rng.randi_range(1, 100)
	var cumulative := 0
	for index in range(FRESH_RUN_LENGTH_WEIGHTS.size()):
		cumulative += FRESH_RUN_LENGTH_WEIGHTS[index]
		if roll <= cumulative:
			return index + 1
	return FRESH_RUN_LENGTH_WEIGHTS.size()

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
