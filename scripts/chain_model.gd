class_name ChainModel
extends RefCounted

signal state_changed
signal match_completed(identity: int, group_size: int)

enum GapType { FEED, CAUSAL }

const DEFAULT_SPEED := 34.0
const DEFAULT_SPACING := 58.0
const DEFAULT_RADIUS := 22.0
const DEFAULT_INITIAL_POPULATION := 12
const DEFAULT_CACHE_RETURN_BATCH := 3
const DEFAULT_EMPTY_RETURN_COUNT := 8
const DEFAULT_MAX_AUTO_POPULATION := 24
const MATCH_SIZE := 3
const DEFAULT_SHOT_RADIUS := 12.0
const RETURN_CATCHUP_SPEED := 120.0
const INSERT_SETTLE_TIME := 0.05
const ROLLBACK_INITIAL_SPEED := 60.0
const ROLLBACK_ACCELERATION := 900.0
const ROLLBACK_MAX_SPEED := 420.0
const ROLLBACK_CONTACT_EPSILON := 0.05
const TAIL_RECOIL_SPACING_FACTOR := 1.25
const MAX_SIMULATION_STEP := 1.0 / 60.0
const ADJACENCY_GAP_FACTOR := 1.25
const POSITION_EPSILON := 0.01
const DEFAULT_FRESH_SEED := 0x1B5C008
const FRESH_RUN_LENGTH_WEIGHTS: Array[int] = [20, 30, 18, 13, 9, 6, 4]
const SEED_PATTERN: Array[int] = [
	TeamData.Identity.RED, TeamData.Identity.RED,
	TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.BLUE,
	TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
	TeamData.Identity.GREEN, TeamData.Identity.GREEN, TeamData.Identity.GREEN, TeamData.Identity.GREEN,
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

# Authoritative physics state. Each segment owns one anchor and an ordered list of
# UID/color members. Member positions are always anchor + index * spacing.
var segments: Array[Dictionary] = []
var segment_gaps: Array[Dictionary] = []
var tail_recoils: Array[Dictionary] = []

# Read-only-by-convention flattened compatibility snapshot for views/older tests.
var balls: Array[Dictionary] = []
var cache: Array[int] = []
var rollback_gaps: Array[Dictionary] = []
var pending_insertions: Array[Dictionary] = []
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
var total_rollbacks_started := 0
var total_rollbacks_completed := 0
var simulation_time := 0.0

# Bounded diagnostics used by F3 and stress tests.
var max_concurrent_events := 0
var min_logical_spacing := INF
var min_display_spacing := INF
var invariant_violations := 0

var _next_ball_id := 1
var _next_segment_id := 1
var _next_gap_id := 1
var _fresh_color_bag: Array[int] = []
var _fresh_rng := RandomNumberGenerator.new()
var _fresh_run_identity := -1
var _fresh_run_remaining := 0
var _previous_fresh_run_identity := -1
var _returns_since_fresh := 0

func _init() -> void:
	_reset_fresh_generator()
	seed_stream()

func set_lane_width(value: float) -> void:
	lane_width = maxf(value, spacing * 3.0)

func reset_run() -> void:
	continuous_feed_enabled = true
	segments.clear()
	segment_gaps.clear()
	tail_recoils.clear()
	balls.clear()
	cache.clear()
	rollback_gaps.clear()
	pending_insertions.clear()
	total_match_events = 0
	last_match_identity = -1
	last_match_size = 0
	event_log.clear()
	pending_cache_returns = 0
	total_fresh_generated = 0
	total_cache_returned = 0
	total_rollbacks_started = 0
	total_rollbacks_completed = 0
	simulation_time = 0.0
	max_concurrent_events = 0
	min_logical_spacing = INF
	min_display_spacing = INF
	invariant_violations = 0
	_next_ball_id = 1
	_next_segment_id = 1
	_next_gap_id = 1
	_returns_since_fresh = 0
	_reset_fresh_generator()
	seed_stream()

func advance(delta: float) -> void:
	var remaining := maxf(delta, 0.0)
	var changed := false
	if remaining <= 0.0:
		changed = _advance_step(0.0)
	while remaining > 0.000001:
		var step := minf(remaining, MAX_SIMULATION_STEP)
		var settle_deadline := _time_until_next_settle()
		if settle_deadline > 0.000001:
			step = minf(step, settle_deadline)
		changed = _advance_step(step) or changed
		remaining -= step
	if delta > 0.0 or changed:
		state_changed.emit()

func _advance_step(delta: float) -> bool:
	var event_count_before := total_match_events
	if delta > 0.0:
		simulation_time += delta
		_integrate_segments(delta)
	_process_contacts()
	var rolled_off := _roll_off_left()
	if continuous_feed_enabled:
		_feed_right_edge()
	elif segments.is_empty():
		_ensure_playable_stream()
	_update_pending_insertions(delta)
	_refresh_snapshot()
	max_concurrent_events = maxi(max_concurrent_events, total_match_events - event_count_before)
	return rolled_off or total_match_events != event_count_before

## Projectile-to-chain contact uses the actual rendered center and the sum of the
## 22px chain radius plus the 12px projectile radius; this is collision tolerance,
## not permission for live chain balls to overlap.
func try_insert_shot(identity: int, impact_x: float, shot_radius := DEFAULT_SHOT_RADIUS) -> bool:
	_refresh_snapshot()
	var contact_index := _find_contact_index(impact_x, radius + maxf(shot_radius, 0.0))
	if contact_index < 0:
		return false
	var contact_uid := int(balls[contact_index].uid)
	var location := _locate_uid(contact_uid)
	if location.is_empty():
		return false
	var segment_index := int(location.segment)
	var local_index := int(location.local)
	var insert_after := impact_x >= float(balls[contact_index].display_x)
	var insert_index := local_index + 1 if insert_after else local_index
	_insert_into_segment(identity, segment_index, insert_index)
	state_changed.emit()
	return true

func return_cached(requested_count: int = -1) -> int:
	var count := cache_return_batch if requested_count < 0 else requested_count
	if not continuous_feed_enabled:
		count = mini(maxi(count, 0), cache.size())
		for unused in range(count):
			_admit_on_right(cache.pop_front(), true)
			total_cache_returned += 1
		_refresh_snapshot()
		if count > 0:
			state_changed.emit()
		return count
	var available := maxi(0, cache.size() - pending_cache_returns)
	count = mini(maxi(count, 0), available)
	pending_cache_returns += count
	var returned_before := total_cache_returned
	_feed_right_edge()
	var admitted := total_cache_returned - returned_before
	if count > 0 or admitted > 0:
		state_changed.emit()
	return admitted

func seed_stream() -> void:
	if not segments.is_empty() or not cache.is_empty():
		return
	var count := mini(initial_population, max_auto_population)
	var right_x := lane_width - radius
	var left_x := right_x - spacing * (count - 1)
	var members: Array[Dictionary] = []
	for index in range(count):
		members.append(_new_member(SEED_PATTERN[index % SEED_PATTERN.size()]))
		total_fresh_generated += 1
	segments.append(_new_segment(members, left_x))
	_refresh_snapshot()
	state_changed.emit()

func set_test_state(identities_value: Array[int], start_x := 100.0, cached: Array[int] = []) -> void:
	continuous_feed_enabled = false
	segments.clear()
	segment_gaps.clear()
	tail_recoils.clear()
	balls.clear()
	cache = cached.duplicate()
	rollback_gaps.clear()
	pending_insertions.clear()
	total_match_events = 0
	last_match_identity = -1
	last_match_size = 0
	event_log.clear()
	pending_cache_returns = 0
	_returns_since_fresh = 0
	total_rollbacks_started = 0
	total_rollbacks_completed = 0
	simulation_time = 0.0
	max_concurrent_events = 0
	min_logical_spacing = INF
	min_display_spacing = INF
	invariant_violations = 0
	_next_segment_id = 1
	_next_gap_id = 1
	var members: Array[Dictionary] = []
	for identity in identities_value:
		members.append(_new_member(identity))
	if not members.is_empty():
		segments.append(_new_segment(members, start_x))
	_refresh_snapshot()
	state_changed.emit()

func add_test_segment(identities_value: Array[int], anchor_x: float, gap_type := GapType.FEED) -> void:
	var members: Array[Dictionary] = []
	for identity in identities_value:
		members.append(_new_member(identity))
	if members.is_empty():
		return
	if not segments.is_empty():
		segment_gaps.append(_new_gap(gap_type))
	segments.append(_new_segment(members, anchor_x))
	_refresh_snapshot()

func identities() -> Array[int]:
	var result: Array[int] = []
	for segment in segments:
		for member in segment.members:
			result.append(int(member.identity))
	return result

func settle_ratio(uid: int) -> float:
	for state in pending_insertions:
		if int(state.uid) == uid:
			return clampf(float(state.elapsed) / INSERT_SETTLE_TIME, 0.0, 1.0)
	return 1.0

func gap_type_counts() -> Dictionary:
	var result := {"feed": 0, "causal": 0, "tail": tail_recoils.size()}
	for gap in segment_gaps:
		if int(gap.type) == GapType.CAUSAL:
			result.causal += 1
		else:
			result.feed += 1
	return result

func _insert_into_segment(identity: int, segment_index: int, insert_index: int) -> void:
	var segment := segments[segment_index]
	var members: Array = segment.members
	insert_index = clampi(insert_index, 0, members.size())
	var member := _new_member(identity)
	# The conveyor flows right-to-left. Open the new slot by advancing the entire
	# front prefix one spacing LEFT: all earlier segments plus this segment's old
	# members before insert_index. Moving this segment's anchor left while adding
	# the member at insert_index leaves its old suffix at the exact same world X.
	# Translating every preceding segment equally also preserves all typed gaps.
	for preceding in range(segment_index):
		var shifted := segments[preceding]
		shifted.anchor_x = float(shifted.anchor_x) - spacing
		segments[preceding] = shifted
	segment.anchor_x = float(segment.anchor_x) - spacing
	members.insert(insert_index, member)
	segment.members = members
	segments[segment_index] = segment
	pending_insertions.append({"uid": int(member.uid), "elapsed": 0.0})
	_refresh_snapshot()

func _integrate_segments(delta: float) -> void:
	if segments.is_empty() or delta <= 0.0:
		return
	var adjustments: Array[float] = []
	adjustments.resize(segments.size())
	adjustments.fill(0.0)
	for index in range(segments.size()):
		var segment := segments[index]
		segment.anchor_x = float(segment.anchor_x) - speed * delta
		segments[index] = segment

	# One segment receives at most one special motor: its causal right edge has
	# priority over feed catch-up at its left edge.
	for gap_index in range(segment_gaps.size()):
		var gap := segment_gaps[gap_index]
		if int(gap.type) == GapType.CAUSAL:
			var distance := _accelerated_distance(gap, delta)
			gap.speed = minf(ROLLBACK_MAX_SPEED, float(gap.speed) + ROLLBACK_ACCELERATION * delta)
			segment_gaps[gap_index] = gap
			adjustments[gap_index] = maxf(adjustments[gap_index], distance)
		elif adjustments[gap_index + 1] <= 0.0:
			adjustments[gap_index + 1] = -RETURN_CATCHUP_SPEED * delta

	for recoil_index in range(tail_recoils.size() - 1, -1, -1):
		var recoil := tail_recoils[recoil_index]
		var segment_index := _segment_index_by_id(int(recoil.segment_id))
		if segment_index < 0:
			tail_recoils.remove_at(recoil_index)
			continue
		var distance := minf(float(recoil.remaining), _accelerated_distance(recoil, delta))
		recoil.speed = minf(ROLLBACK_MAX_SPEED, float(recoil.speed) + ROLLBACK_ACCELERATION * delta)
		adjustments[segment_index] = maxf(adjustments[segment_index], distance)
		recoil.step_distance = distance
		tail_recoils[recoil_index] = recoil

	_solve_non_overlap(adjustments)
	for index in range(segments.size()):
		var segment := segments[index]
		segment.anchor_x = float(segment.anchor_x) + adjustments[index]
		segments[index] = segment
	for recoil_index in range(tail_recoils.size() - 1, -1, -1):
		var recoil := tail_recoils[recoil_index]
		var segment_index := _segment_index_by_id(int(recoil.segment_id))
		if segment_index < 0:
			tail_recoils.remove_at(recoil_index)
			continue
		var actual_move := maxf(0.0, adjustments[segment_index])
		recoil.remaining = maxf(0.0, float(recoil.remaining) - minf(actual_move, float(recoil.step_distance)))
		if float(recoil.remaining) <= ROLLBACK_CONTACT_EPSILON:
			tail_recoils.remove_at(recoil_index)
			total_rollbacks_completed += 1
		else:
			tail_recoils[recoil_index] = recoil
	_refresh_rollback_snapshot()

func _solve_non_overlap(adjustments: Array[float]) -> void:
	# Resolve desired segment translations before applying any of them. Causal
	# leftward-edge motors yield first; feed right-side catch-up yields second.
	for unused in range(maxi(1, segments.size() * 2)):
		var changed := false
		for gap_index in range(segment_gaps.size()):
			var available := maxf(0.0, _gap_distance(gap_index) - spacing)
			var closure := adjustments[gap_index] - adjustments[gap_index + 1]
			if closure <= available + POSITION_EPSILON:
				continue
			var excess := closure - available
			if adjustments[gap_index] > 0.0:
				adjustments[gap_index] = maxf(0.0, adjustments[gap_index] - excess)
			elif adjustments[gap_index + 1] < 0.0:
				adjustments[gap_index + 1] = minf(0.0, adjustments[gap_index + 1] + excess)
			changed = true
		if not changed:
			break

func _process_contacts() -> void:
	var safety := max_auto_population * 2
	while safety > 0:
		safety -= 1
		var contact_index := -1
		for index in range(segment_gaps.size()):
			if _gap_distance(index) <= spacing + ROLLBACK_CONTACT_EPSILON:
				contact_index = index
				break
		if contact_index < 0:
			break
		var gap := segment_gaps[contact_index]
		var was_causal := int(gap.type) == GapType.CAUSAL
		var left_segment := segments[contact_index]
		var right_segment := segments[contact_index + 1]
		var left_members: Array = left_segment.members
		var right_members: Array = right_segment.members
		var matching_ends := int(left_members[-1].identity) == int(right_members[0].identity)
		# Clamp to exact physical contact, then merge the two rigid lists.
		right_segment.anchor_x = _segment_end_x(left_segment) + spacing
		for member in right_members:
			left_members.append(member)
		left_segment.members = left_members
		segments[contact_index] = left_segment
		segments.remove_at(contact_index + 1)
		segment_gaps.remove_at(contact_index)
		if was_causal:
			total_rollbacks_completed += 1
		if was_causal and matching_ends:
			var boundary_member_index := left_members.size() - right_members.size() - 1
			var group := _group_in_segment(contact_index, boundary_member_index)
			if int(group.size) >= MATCH_SIZE:
				_remove_group(contact_index, int(group.start), int(group.size), int(group.identity))
				return_cached(cache_return_batch)
				_ensure_playable_stream()
		_refresh_snapshot()

func _remove_group(segment_index: int, start: int, count: int, identity: int) -> void:
	if segment_index < 0 or segment_index >= segments.size() or count <= 0:
		return
	var segment := segments[segment_index]
	var members: Array = segment.members
	var left_members := members.slice(0, start)
	var right_members := members.slice(start + count, members.size())
	for removed in members.slice(start, start + count):
		_retire_pending_insertion(int(removed.uid))
	var original_anchor := float(segment.anchor_x)
	var has_previous := segment_index > 0
	var has_next := segment_index + 1 < segments.size()

	if not left_members.is_empty() and not right_members.is_empty():
		segment.members = left_members
		segments[segment_index] = segment
		var right_anchor := original_anchor + float(start + count) * spacing
		segments.insert(segment_index + 1, _new_segment_from_members(right_members, right_anchor))
		segment_gaps.insert(segment_index, _new_gap(GapType.CAUSAL, count))
		_register_rollback_started()
	elif not left_members.is_empty():
		segment.members = left_members
		segments[segment_index] = segment
		if has_next:
			segment_gaps[segment_index] = _new_gap(GapType.CAUSAL, count)
			_register_rollback_started()
		else:
			_create_tail_recoil(int(segment.id), count)
	elif not right_members.is_empty():
		segment.members = right_members
		segment.anchor_x = original_anchor + float(start + count) * spacing
		segments[segment_index] = segment
		if has_previous:
			segment_gaps[segment_index - 1] = _new_gap(GapType.CAUSAL, count)
			_register_rollback_started()
	else:
		var removed_segment_id := int(segment.id)
		segments.remove_at(segment_index)
		_remove_tail_recoil(removed_segment_id)
		if has_previous and has_next:
			segment_gaps.remove_at(segment_index)
			segment_gaps[segment_index - 1] = _new_gap(GapType.CAUSAL, count)
			_register_rollback_started()
		elif has_previous:
			segment_gaps.remove_at(segment_index - 1)
			_create_tail_recoil(int(segments[segment_index - 1].id), count)
		elif has_next:
			segment_gaps.remove_at(0)

	total_match_events += 1
	last_match_identity = identity
	last_match_size = count
	event_log.append({"identity": identity, "size": count, "time": simulation_time})
	_refresh_snapshot()
	match_completed.emit(identity, count)

func _resolve_inserted_match(uid: int) -> void:
	var location := _locate_uid(uid)
	if location.is_empty():
		return
	var group := _group_in_segment(int(location.segment), int(location.local))
	if int(group.size) < MATCH_SIZE:
		return
	_remove_group(int(location.segment), int(group.start), int(group.size), int(group.identity))
	return_cached(cache_return_batch)
	_ensure_playable_stream()

func _group_in_segment(segment_index: int, member_index: int) -> Dictionary:
	var members: Array = segments[segment_index].members
	var identity := int(members[member_index].identity)
	var start := member_index
	var end := member_index
	while start > 0 and int(members[start - 1].identity) == identity:
		start -= 1
	while end + 1 < members.size() and int(members[end + 1].identity) == identity:
		end += 1
	return {"start": start, "size": end - start + 1, "identity": identity}

func _time_until_next_settle() -> float:
	var result := INF
	for state in pending_insertions:
		result = minf(result, maxf(0.0, INSERT_SETTLE_TIME - float(state.elapsed)))
	return result

func _update_pending_insertions(delta: float) -> void:
	var matured: Array[int] = []
	for index in range(pending_insertions.size() - 1, -1, -1):
		var state := pending_insertions[index]
		if _locate_uid(int(state.uid)).is_empty():
			pending_insertions.remove_at(index)
			continue
		state.elapsed = minf(INSERT_SETTLE_TIME, float(state.elapsed) + delta)
		pending_insertions[index] = state
		if float(state.elapsed) >= INSERT_SETTLE_TIME - 0.000001:
			matured.push_front(int(state.uid))
	for uid in matured:
		_retire_pending_insertion(uid)
		_resolve_inserted_match(uid)

func _retire_pending_insertion(uid: int) -> void:
	for index in range(pending_insertions.size() - 1, -1, -1):
		if int(pending_insertions[index].uid) == uid:
			pending_insertions.remove_at(index)

func _roll_off_left() -> bool:
	var rolled_off := false
	while not segments.is_empty():
		var first := segments[0]
		var members: Array = first.members
		if members.is_empty() or float(first.anchor_x) + radius >= 0.0:
			break
		var exited: Dictionary = members.pop_front()
		cache.append(int(exited.identity))
		_retire_pending_insertion(int(exited.uid))
		rolled_off = true
		if members.is_empty():
			var segment_id := int(first.id)
			segments.remove_at(0)
			_remove_tail_recoil(segment_id)
			if not segment_gaps.is_empty():
				segment_gaps.remove_at(0)
		else:
			first.members = members
			first.anchor_x = float(first.anchor_x) + spacing
			segments[0] = first
	_refresh_snapshot()
	return rolled_off

func _ensure_playable_stream() -> void:
	if continuous_feed_enabled:
		_feed_right_edge()
	elif segments.is_empty():
		if not cache.is_empty():
			return_cached(mini(empty_return_count, cache.size()))
		else:
			seed_stream()

func _feed_right_edge() -> void:
	var right_edge := lane_width - radius
	while _live_count() < max_auto_population:
		if not segments.is_empty() and _segment_end_x(segments[-1]) + spacing > right_edge + POSITION_EPSILON:
			break
		var use_return := pending_cache_returns > 0 and not cache.is_empty() and _returns_since_fresh < cache_return_batch
		if use_return:
			_admit_on_right(cache.pop_front(), false)
			pending_cache_returns -= 1
			total_cache_returned += 1
			_returns_since_fresh += 1
		else:
			_admit_on_right(_draw_fresh_identity(), false)
			total_fresh_generated += 1
			_returns_since_fresh = 0
	_refresh_snapshot()

func _admit_on_right(identity: int, force_right_edge: bool) -> void:
	var spawn_x := lane_width - radius
	if segments.is_empty():
		segments.append(_new_segment([_new_member(identity)], spawn_x))
		return
	var last := segments[-1]
	var last_end := _segment_end_x(last)
	spawn_x = maxf(spawn_x, last_end + spacing) if force_right_edge else last_end + spacing
	if absf(spawn_x - (last_end + spacing)) <= POSITION_EPSILON:
		var members: Array = last.members
		members.append(_new_member(identity))
		last.members = members
		segments[-1] = last
	else:
		segment_gaps.append(_new_gap(GapType.FEED))
		segments.append(_new_segment([_new_member(identity)], spawn_x))

func _find_contact_index(impact_x: float, tolerance: float) -> int:
	var closest := -1
	var closest_distance := INF
	for index in range(balls.size()):
		var distance := absf(impact_x - float(balls[index].display_x))
		if distance <= tolerance and distance < closest_distance:
			closest = index
			closest_distance = distance
	return closest

func _locate_uid(uid: int) -> Dictionary:
	for segment_index in range(segments.size()):
		var members: Array = segments[segment_index].members
		for local_index in range(members.size()):
			if int(members[local_index].uid) == uid:
				return {"segment": segment_index, "local": local_index}
	return {}

func _ball_index_by_uid(uid: int) -> int:
	for index in range(balls.size()):
		if int(balls[index].uid) == uid:
			return index
	return -1

func _segment_index_by_id(segment_id: int) -> int:
	for index in range(segments.size()):
		if int(segments[index].id) == segment_id:
			return index
	return -1

func _segment_end_x(segment: Dictionary) -> float:
	return float(segment.anchor_x) + float((segment.members as Array).size() - 1) * spacing

func _gap_distance(index: int) -> float:
	return float(segments[index + 1].anchor_x) - _segment_end_x(segments[index])

func _accelerated_distance(state: Dictionary, delta: float) -> float:
	var current_speed := float(state.speed)
	var acceleration_time := minf(delta, maxf(0.0, (ROLLBACK_MAX_SPEED - current_speed) / ROLLBACK_ACCELERATION))
	return current_speed * acceleration_time + 0.5 * ROLLBACK_ACCELERATION * acceleration_time * acceleration_time + ROLLBACK_MAX_SPEED * (delta - acceleration_time)

func _create_tail_recoil(segment_id: int, removed_count: int) -> void:
	if segment_id < 0:
		return
	_remove_tail_recoil(segment_id)
	tail_recoils.append({
		"id": _next_gap_id,
		"segment_id": segment_id,
		"remaining": minf(spacing * removed_count, spacing * TAIL_RECOIL_SPACING_FACTOR),
		"speed": ROLLBACK_INITIAL_SPEED,
		"step_distance": 0.0,
	})
	_next_gap_id += 1
	_register_rollback_started()

func _remove_tail_recoil(segment_id: int) -> void:
	for index in range(tail_recoils.size() - 1, -1, -1):
		if int(tail_recoils[index].segment_id) == segment_id:
			tail_recoils.remove_at(index)

func _register_rollback_started() -> void:
	total_rollbacks_started += 1
	_refresh_rollback_snapshot()

func _new_gap(type: int, removed_count := 0) -> Dictionary:
	var result := {
		"id": _next_gap_id,
		"type": type,
		"speed": ROLLBACK_INITIAL_SPEED if type == GapType.CAUSAL else 0.0,
		"removed_count": removed_count,
	}
	_next_gap_id += 1
	return result

func _new_segment(members: Array[Dictionary], anchor_x: float) -> Dictionary:
	var result := {"id": _next_segment_id, "anchor_x": anchor_x, "members": members}
	_next_segment_id += 1
	return result

func _new_segment_from_members(members: Array, anchor_x: float) -> Dictionary:
	var typed_members: Array[Dictionary] = []
	for member in members:
		typed_members.append(member)
	return _new_segment(typed_members, anchor_x)

func _new_member(identity: int) -> Dictionary:
	var result := {"uid": _next_ball_id, "identity": posmod(identity, TeamData.COUNT)}
	_next_ball_id += 1
	return result

func _make_ball(identity: int, logical_x: float, display_x := NAN) -> Dictionary:
	var member := _new_member(identity)
	var resolved_display := logical_x if is_nan(display_x) else display_x
	return {"uid": member.uid, "identity": member.identity, "x": logical_x, "display_x": resolved_display}

func _live_count() -> int:
	var count := 0
	for segment in segments:
		count += (segment.members as Array).size()
	return count

func _refresh_snapshot() -> void:
	balls.clear()
	for segment in segments:
		var members: Array = segment.members
		for index in range(members.size()):
			var x := float(segment.anchor_x) + index * spacing
			balls.append({"uid": int(members[index].uid), "identity": int(members[index].identity), "x": x, "display_x": x})
	_refresh_rollback_snapshot()
	_validate_invariants()

func _refresh_rollback_snapshot() -> void:
	rollback_gaps.clear()
	for index in range(segment_gaps.size()):
		var gap := segment_gaps[index]
		if int(gap.type) != GapType.CAUSAL:
			continue
		var left_members: Array = segments[index].members
		var right_members: Array = segments[index + 1].members
		rollback_gaps.append({
			"id": int(gap.id),
			"left_uid": int(left_members[-1].uid),
			"right_uid": int(right_members[0].uid),
			"tail_remaining": 0.0,
			"speed": float(gap.speed),
		})
	for recoil in tail_recoils:
		var segment_index := _segment_index_by_id(int(recoil.segment_id))
		if segment_index < 0:
			continue
		var members: Array = segments[segment_index].members
		rollback_gaps.append({
			"id": int(recoil.id),
			"left_uid": int(members[-1].uid),
			"right_uid": -1,
			"tail_remaining": float(recoil.remaining),
			"speed": float(recoil.speed),
		})

func _validate_invariants() -> void:
	var step_min_logical := INF
	var step_min_display := INF
	var seen := {}
	var valid := segment_gaps.size() == maxi(0, segments.size() - 1)
	for index in range(balls.size()):
		var ball := balls[index]
		var uid := int(ball.uid)
		valid = valid and not seen.has(uid) and is_finite(float(ball.x)) and is_finite(float(ball.display_x))
		seen[uid] = true
		if index > 0:
			var logical_gap := float(ball.x) - float(balls[index - 1].x)
			var display_gap := float(ball.display_x) - float(balls[index - 1].display_x)
			step_min_logical = minf(step_min_logical, logical_gap)
			step_min_display = minf(step_min_display, display_gap)
			valid = valid and logical_gap >= radius * 2.0 - POSITION_EPSILON and display_gap >= radius * 2.0 - POSITION_EPSILON
	for segment in segments:
		var members: Array = segment.members
		valid = valid and not members.is_empty()
	min_logical_spacing = minf(min_logical_spacing, step_min_logical)
	min_display_spacing = minf(min_display_spacing, step_min_display)
	if not valid:
		invariant_violations += 1

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
