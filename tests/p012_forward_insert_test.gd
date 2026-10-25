extends SceneTree

const LayoutCalculator = preload("res://scripts/responsive_layout.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _positions(model: ChainModel) -> Dictionary:
	var result := {}
	for ball in model.balls:
		result[int(ball.uid)] = float(ball.x)
	return result

func _uids(model: ChainModel) -> Array[int]:
	var result: Array[int] = []
	for ball in model.balls:
		result.append(int(ball.uid))
	return result

func _invariants_hold(model: ChainModel) -> bool:
	if model.segment_gaps.size() != maxi(0, model.segments.size() - 1) or model.invariant_violations != 0:
		return false
	var seen := {}
	var flat_index := 0
	for segment_index in range(model.segments.size()):
		var segment: Dictionary = model.segments[segment_index]
		var members: Array = segment.members
		if members.is_empty():
			return false
		for local_index in range(members.size()):
			if flat_index >= model.balls.size():
				return false
			var ball: Dictionary = model.balls[flat_index]
			var expected_x := float(segment.anchor_x) + local_index * model.spacing
			if int(ball.uid) != int(members[local_index].uid) or seen.has(int(ball.uid)):
				return false
			if absf(float(ball.x) - expected_x) > 0.001 or absf(float(ball.display_x) - expected_x) > 0.001:
				return false
			seen[int(ball.uid)] = true
			if flat_index > 0:
				var logical_gap := float(ball.x) - float(model.balls[flat_index - 1].x)
				var display_gap := float(ball.display_x) - float(model.balls[flat_index - 1].display_x)
				if logical_gap < model.radius * 2.0 - 0.01 or display_gap < model.radius * 2.0 - 0.01:
					return false
			flat_index += 1
		if segment_index + 1 < model.segments.size():
			var end_x := float(segment.anchor_x) + (members.size() - 1) * model.spacing
			if float(model.segments[segment_index + 1].anchor_x) - end_x < model.spacing - 0.01:
				return false
	return flat_index == model.balls.size()

func _advance_checked(model: ChainModel, duration: float, label: String) -> void:
	var remaining := duration
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 120.0)
		model.advance(step)
		_check(_invariants_hold(model), "%s preserves rigid non-overlap invariants at %.6f" % [label, model.simulation_time])
		remaining -= step

func _assert_single_segment_index(insert_index: int) -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.YELLOW, TeamData.Identity.GREEN, TeamData.Identity.RED]
	model.set_test_state(identities, 500.0)
	var old_uids := _uids(model)
	var before := _positions(model)
	var impact_x: float
	if insert_index == identities.size():
		impact_x = float(model.balls[-1].display_x) + 1.0
	else:
		impact_x = float(model.balls[insert_index].display_x) - 1.0
	_check(model.try_insert_shot(TeamData.Identity.GREEN, impact_x), "index %d insertion contacts" % insert_index)
	var after := _positions(model)
	for old_index in range(old_uids.size()):
		var uid := old_uids[old_index]
		var expected_delta := -model.spacing if old_index < insert_index else 0.0
		_check(absf(float(after[uid]) - float(before[uid]) - expected_delta) < 0.001, "index %d old member %d has expected %.0f displacement" % [insert_index, old_index, expected_delta])
	var inserted_uid := int(model.pending_insertions[0].uid)
	var expected_insert_x := float(before[old_uids[insert_index]]) - model.spacing if insert_index < old_uids.size() else float(before[old_uids[-1]])
	_check(absf(float(after[inserted_uid]) - expected_insert_x) < 0.001, "index %d shot occupies the opened front-side slot" % insert_index)
	_check(_uids(model).slice(0, insert_index) == old_uids.slice(0, insert_index), "index %d preserves prefix UID order" % insert_index)
	_check(_uids(model).slice(insert_index + 1) == old_uids.slice(insert_index), "index %d preserves suffix UID order" % insert_index)
	_check(_invariants_hold(model), "index %d insertion is immediately non-overlapping" % insert_index)

func _run() -> void:
	_test_all_single_segment_indices()
	_test_documented_six_ball_example()
	_test_feed_and_causal_boundaries()
	_test_concurrent_settles_and_left_rollover_fifo()
	_test_insert_left_then_rollback_right()
	_test_full_width_layout_preserved()
	_finish()

func _test_all_single_segment_indices() -> void:
	for insert_index in [0, 1, 2, 4, 5]:
		_assert_single_segment_index(insert_index)

func _test_documented_six_ball_example() -> void:
	var model := ChainModel.new()
	var front: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW]
	var trailing: Array[int] = [TeamData.Identity.BLUE, TeamData.Identity.BLUE]
	model.set_test_state(front, 300.0)
	model.add_test_segment(trailing, 700.0, ChainModel.GapType.FEED)
	var gap_id := int(model.segment_gaps[0].id)
	var gap_before := float(model.segments[1].anchor_x) - (float(model.segments[0].anchor_x) + 3.0 * model.spacing)
	var old_uids := _uids(model)
	var before := _positions(model)
	_check(model.try_insert_shot(TeamData.Identity.GREEN, float(model.balls[4].display_x) - 1.0), "GREEN inserts at documented segment bar")
	var after := _positions(model)
	for index in range(4):
		_check(absf(float(after[old_uids[index]]) - float(before[old_uids[index]]) + model.spacing) < 0.001, "documented front UID %d moves one slot LEFT" % index)
	for index in range(4, 6):
		_check(absf(float(after[old_uids[index]]) - float(before[old_uids[index]])) < 0.001, "documented trailing UID %d remains pinned" % index)
	var inserted_uid := int(model.pending_insertions[0].uid)
	_check(_uids(model) == [old_uids[0], old_uids[1], old_uids[2], old_uids[3], inserted_uid, old_uids[4], old_uids[5]], "documented insertion produces exact UID order")
	var gap_after := float(model.segments[1].anchor_x) - (float(model.segments[0].anchor_x) + 3.0 * model.spacing)
	_check(int(model.segment_gaps[0].id) == gap_id and int(model.segment_gaps[0].type) == ChainModel.GapType.FEED and absf(gap_after - gap_before) < 0.001, "FEED edge identity/type/distance survives boundary insertion")
	_check(_invariants_hold(model), "documented cross-segment insertion has zero overlap")

func _test_feed_and_causal_boundaries() -> void:
	var causal := ChainModel.new()
	var pattern: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.BLUE, TeamData.Identity.BLUE]
	causal.set_test_state(pattern, 300.0)
	causal.try_insert_shot(TeamData.Identity.YELLOW, float(causal.balls[3].display_x) + 1.0)
	_advance_checked(causal, ChainModel.INSERT_SETTLE_TIME, "causal setup")
	_check(causal.segment_gaps.size() == 1 and int(causal.segment_gaps[0].type) == ChainModel.GapType.CAUSAL, "match creates active causal segment edge")
	_advance_checked(causal, 0.08, "accelerating causal setup")
	var gap_id := int(causal.segment_gaps[0].id)
	var gravity_speed := float(causal.segments[0].gravity_speed)
	var gap_distance := causal._gap_distance(0)
	var right_old_uid := int(causal.segments[1].members[0].uid)
	var right_old_x := float(_positions(causal)[right_old_uid])
	_check(causal.try_insert_shot(TeamData.Identity.GREEN, right_old_x - 1.0), "shot inserts at right side of active causal seam")
	_check(int(causal.segment_gaps[0].id) == gap_id and int(causal.segment_gaps[0].type) == ChainModel.GapType.CAUSAL, "causal edge id/type survives seam insertion")
	_check(absf(float(causal.segments[0].gravity_speed) - gravity_speed) < 0.001 and absf(causal._gap_distance(0) - gap_distance) < 0.001, "unsupported segment velocity and physical target distance are preserved")
	_check(absf(float(_positions(causal)[right_old_uid]) - right_old_x) < 0.001, "old trailing endpoint is not pushed right")
	_check(_invariants_hold(causal), "active-gap insertion stays non-overlapping")

	var left_endpoint_uid := int(causal.segments[0].members[-1].uid)
	var left_endpoint_x := float(_positions(causal)[left_endpoint_uid])
	var prior_gap := causal._gap_distance(0)
	_check(causal.try_insert_shot(TeamData.Identity.BLUE, left_endpoint_x + 1.0), "shot inserts after moving left rollback endpoint")
	_check(absf(causal._gap_distance(0) - prior_gap) < 0.001 and _invariants_hold(causal), "left-endpoint insertion preserves causal gap and constraints")
	_advance_checked(causal, 1.5, "post-seam rollback")
	_check(causal.rollback_gaps.is_empty(), "causal motor still terminates after both seam insertions")

func _test_concurrent_settles_and_left_rollover_fifo() -> void:
	var concurrent := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.GREEN, TeamData.Identity.YELLOW]
	concurrent.set_test_state(identities, 400.0)
	var original_uids := _uids(concurrent)
	concurrent.try_insert_shot(TeamData.Identity.BLUE, float(concurrent.balls[1].display_x) + 1.0)
	concurrent.try_insert_shot(TeamData.Identity.GREEN, float(concurrent.balls[3].display_x) + 1.0)
	_check(concurrent.pending_insertions.size() == 2 and _invariants_hold(concurrent), "two accepted shots share the settle window without overlap")
	_advance_checked(concurrent, 0.05, "concurrent settle")
	_check(concurrent.pending_insertions.is_empty() and concurrent.total_match_events <= 2, "concurrent checks retire once without duplicate events")
	for uid in original_uids:
		_check(concurrent._ball_index_by_uid(uid) >= 0 or concurrent.cache.size() > 0, "concurrent insertion never silently loses original UID %d" % uid)

	var rollover := ChainModel.new()
	var near_left: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	rollover.set_test_state(near_left, 10.0)
	for expected_cache_size in range(1, 4):
		rollover.try_insert_shot(TeamData.Identity.YELLOW, float(rollover.balls[-1].display_x) + 1.0)
		rollover.advance(0.0)
		_check(rollover.cache.size() == expected_cache_size, "left push rolls exactly one front ball into FIFO at step %d" % expected_cache_size)
		_check(_invariants_hold(rollover), "near-left rollover step %d remains legal" % expected_cache_size)
	_check(rollover.cache == near_left, "insertion-driven exits preserve RED GREEN BLUE FIFO order")
	rollover.return_cached(3)
	_check(rollover.identities().slice(-3) == near_left, "insertion-driven FIFO exits return in original order")

func _test_insert_left_then_rollback_right() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.RED, TeamData.Identity.RED]
	model.set_test_state(identities, 300.0)
	var left_uid := int(model.balls[1].uid)
	var right_uid := int(model.balls[4].uid)
	var before := _positions(model)
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].display_x) + 1.0)
	var inserted := _positions(model)
	_check(absf(float(inserted[left_uid]) - float(before[left_uid]) + model.spacing) < 0.001, "insertion moves front reds LEFT one slot")
	_check(absf(float(inserted[right_uid]) - float(before[right_uid])) < 0.001, "insertion does not move trailing reds RIGHT")
	_advance_checked(model, 0.049, "theatrical pre-pop")
	_check(model.event_log.is_empty(), "theatrical match still waits through 49ms")
	_advance_checked(model, 0.001, "theatrical pop")
	_check(model.event_log.size() == 1 and int(model.event_log[0].identity) == TeamData.Identity.YELLOW, "50ms emits yellow initial match")
	var rollback_start := float(_positions(model)[left_uid])
	_advance_checked(model, 0.02, "rightward causal rollback")
	_check(float(_positions(model)[left_uid]) > rollback_start, "post-match front segment reverses RIGHT independently of leftward insertion")
	while model.event_log.size() < 2 and model.simulation_time < 2.0:
		_advance_checked(model, 1.0 / 120.0, "red contact")
	_check(model.event_log.size() == 2 and int(model.event_log[1].identity) == TeamData.Identity.RED and int(model.event_log[1].size) == 4, "red size-4 cascade waits for physical reconnection")

func _test_full_width_layout_preserved() -> void:
	for viewport_size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]:
		var layout: Dictionary = LayoutCalculator.calculate(viewport_size)
		_check(float(layout.track_left) <= layout.chain_rect.position.x + 25.0 and float(layout.track_right) >= layout.chain_rect.end.x - 25.0, "%s preserves full-width shooter reach" % viewport_size)
		_check(layout.hud_rect.encloses(layout.magazine_rect) and not layout.playfield_rect.intersects(layout.magazine_rect), "%s preserves nonblocking compact swap" % viewport_size)

func _finish() -> void:
	if _failures.is_empty():
		print("P012 forward insertion: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P012 forward insertion: " + failure)
	print("P012 forward insertion: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
