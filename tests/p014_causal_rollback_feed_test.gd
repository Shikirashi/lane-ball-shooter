extends SceneTree

const MAIN_PATTERN: Array[int] = [
	TeamData.Identity.RED, TeamData.Identity.RED,
	TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
	TeamData.Identity.BLUE, TeamData.Identity.BLUE,
]
const CASCADE_PATTERN: Array[int] = [
	TeamData.Identity.RED, TeamData.Identity.RED,
	TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
	TeamData.Identity.RED, TeamData.Identity.RED,
]

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	_test_actual_segment_velocities()
	_test_contact_gated_cascade()
	_test_feed_during_causal_rollback()
	_test_two_causal_gaps_and_fifo()
	_test_insertion_during_rollback()
	_test_frame_rate_stability()
	_test_long_mixed_stream()
	_finish()

func _position(model: ChainModel, uid: int) -> float:
	var index := model._ball_index_by_uid(uid)
	return float(model.balls[index].x) if index >= 0 else NAN

func _segment_anchor(model: ChainModel, segment_id: int) -> float:
	var index := model._segment_index_by_id(segment_id)
	return float(model.segments[index].anchor_x) if index >= 0 else NAN

func _motion(model: ChainModel, segment_id: int) -> Dictionary:
	for sample in model.segment_motion_log:
		if int(sample.segment_id) == segment_id:
			return sample
	return {}

func _setup_clear(pattern: Array[int], continuous := false) -> ChainModel:
	var model := ChainModel.new()
	model.set_test_state(pattern, 300.0)
	model.continuous_feed_enabled = continuous
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].x) + 1.0)
	return model

func _invariants_hold(model: ChainModel) -> bool:
	if model.invariant_violations != 0 or model.segment_gaps.size() != maxi(0, model.segments.size() - 1):
		return false
	var prior_x := -INF
	for segment_index in range(model.segments.size()):
		var segment: Dictionary = model.segments[segment_index]
		if segment_index < model.segment_gaps.size():
			var gap: Dictionary = model.segment_gaps[segment_index]
			if int(gap.left_segment_id) != int(segment.id) or int(gap.right_segment_id) != int(model.segments[segment_index + 1].id):
				return false
		for local_index in range((segment.members as Array).size()):
			var x := float(segment.anchor_x) + local_index * model.spacing
			if local_index > 0 and absf(x - prior_x - model.spacing) > 0.001:
				return false
			if prior_x > -INF and x - prior_x < model.radius * 2.0 - 0.01:
				return false
			prior_x = x
	return true

func _test_actual_segment_velocities() -> void:
	var model := _setup_clear(MAIN_PATTERN)
	var front_uids := [int(model.balls[0].uid), int(model.balls[1].uid)]
	var rear_uids := [int(model.balls[5].uid), int(model.balls[6].uid)]
	model.advance(0.049)
	_check(model.event_log.is_empty() and model.segment_gaps.is_empty(), "49ms has no match or causal motor")
	model.advance(0.001)
	_check(model.event_log.size() == 1 and int(model.event_log[0].identity) == TeamData.Identity.YELLOW and int(model.event_log[0].size) == 3, "50ms emits initial yellow x3")
	_check(model.segment_gaps.size() == 1 and int(model.segment_gaps[0].type) == ChainModel.GapType.CAUSAL, "middle clear creates one typed causal edge")
	var gap_id := int(model.segment_gaps[0].id)
	var left_segment_id := int(model.segment_gaps[0].left_segment_id)
	var right_segment_id := int(model.segment_gaps[0].right_segment_id)
	_check(left_segment_id == int(model.segments[0].id) and right_segment_id == int(model.segments[1].id), "causal edge binds stable actual left/right segment IDs")
	for duration in [0.05, 0.1, 0.2]:
		var front_before := [_position(model, front_uids[0]), _position(model, front_uids[1])]
		var rear_before := [_position(model, rear_uids[0]), _position(model, rear_uids[1])]
		model.advance(duration)
		var front_delta_a := _position(model, front_uids[0]) - float(front_before[0])
		var front_delta_b := _position(model, front_uids[1]) - float(front_before[1])
		var rear_delta_a := _position(model, rear_uids[0]) - float(rear_before[0])
		var rear_delta_b := _position(model, rear_uids[1]) - float(rear_before[1])
		_check(front_delta_a > 0.0 and absf(front_delta_a - front_delta_b) < 0.001, "front reds move RIGHT together over %.2fs" % duration)
		_check(absf(rear_delta_a + model.speed * duration) < 0.002 and absf(rear_delta_a - rear_delta_b) < 0.001, "rear blues retain only the baseline conveyor speed over %.2fs" % duration)
		_check(int(model.segment_gaps[0].id) == gap_id and int(model.segment_gaps[0].left_segment_id) == left_segment_id and int(model.segment_gaps[0].right_segment_id) == right_segment_id, "causal edge binding survives %.2fs integration" % duration)
		_check(model.unsupported_segment_count == 1 and model.gravity_gap_count == 1 and model.last_gravity_displacement > 0.0, "diagnostics report one unsupported segment and positive gravity motion")
		var front_motion := _motion(model, left_segment_id)
		var rear_motion := _motion(model, right_segment_id)
		_check(not front_motion.is_empty() and int(front_motion.right_gap_type) == ChainModel.GapType.CAUSAL and float(front_motion.velocity) > 0.0, "motion log identifies positive causal-front velocity")
		_check(not rear_motion.is_empty() and int(rear_motion.left_gap_type) == ChainModel.GapType.CAUSAL and absf(float(rear_motion.velocity) + model.speed) < 0.002, "motion log identifies baseline causal-rear velocity")
	_check(_invariants_hold(model), "main velocity regression retains rigid non-overlap")

func _test_contact_gated_cascade() -> void:
	var model := _setup_clear(CASCADE_PATTERN)
	model.advance(0.05)
	var initial_time := float(model.event_log[0].time)
	_check(model.event_log.size() == 1 and model.identities() == [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.RED], "yellow clear leaves two disconnected red pairs")
	var contact_time := -1.0
	while model.event_log.size() == 1 and model.simulation_time < 2.0:
		model.advance(1.0 / 120.0)
		if model.event_log.size() > 1:
			contact_time = float(model.event_log[1].time)
	_check(model.event_log.size() == 2 and int(model.event_log[1].identity) == TeamData.Identity.RED and int(model.event_log[1].size) == 4, "red x4 cascades only at physical contact")
	_check(contact_time > initial_time + 0.1, "cascade time is distinctly later than initial settle pop")

func _test_feed_during_causal_rollback() -> void:
	var model := _setup_clear(MAIN_PATTERN, true)
	model.set_lane_width(900.0)
	model.advance(0.05)
	var causal_gap_id := -1
	for gap in model.segment_gaps:
		if int(gap.type) == ChainModel.GapType.CAUSAL:
			causal_gap_id = int(gap.id)
	var front_uid := int(model.balls[0].uid)
	var rear_uid := int(model.balls[2].uid)
	var entrant_uid := int(model.balls[-1].uid)
	var front_before := _position(model, front_uid)
	var rear_before := _position(model, rear_uid)
	var entrant_before := _position(model, entrant_uid)
	model.advance(0.1)
	_check(_position(model, front_uid) > front_before, "front rollback persists while an entrant is offscreen")
	_check(_position(model, rear_uid) > rear_before, "intermediate rear segment is unsupported by the separated entrant and also falls right")
	_check(absf(_position(model, entrant_uid) - entrant_before + model.speed * 0.1) < 0.002, "offscreen entrant stays at baseline 102 px/s")
	_check(model.unsupported_segment_count == 2 and model.segment_gaps.any(func(gap): return int(gap.id) == causal_gap_id and int(gap.type) == ChainModel.GapType.CAUSAL), "unified gravity preserves causal authorization while both gaps close")
	model.advance(2.0)
	if model._ball_index_by_uid(entrant_uid) >= 0:
		var visible_before := _position(model, entrant_uid)
		model.advance(0.1)
		_check(absf(_position(model, entrant_uid) - visible_before + model.speed * 0.1) < 0.002, "entrant has no speed jump after becoming visible")
	_check(_invariants_hold(model), "feed/causal coexistence remains non-overlapping")

func _test_two_causal_gaps_and_fifo() -> void:
	var pattern: Array[int] = [
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
		TeamData.Identity.BLUE, TeamData.Identity.BLUE,
		TeamData.Identity.GREEN, TeamData.Identity.GREEN,
		TeamData.Identity.RED, TeamData.Identity.RED,
	]
	var cache_values: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	var model := ChainModel.new()
	model.set_test_state(pattern, 180.0, cache_values)
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].x) + 1.0)
	model.advance(0.05)
	var green_index := -1
	for index in range(model.balls.size()):
		if int(model.balls[index].identity) == TeamData.Identity.GREEN:
			green_index = index
			break
	model.try_insert_shot(TeamData.Identity.GREEN, float(model.balls[green_index].x) + 1.0)
	model.advance(0.05)
	_check(model.gap_type_counts().causal == 2, "second match creates a second independent causal edge")
	var bindings := []
	for gap in model.segment_gaps:
		if int(gap.type) == ChainModel.GapType.CAUSAL:
			bindings.append([int(gap.id), int(gap.left_segment_id), int(gap.right_segment_id)])
	model.return_cached(3)
	var anchors := {}
	for segment in model.segments:
		anchors[int(segment.id)] = float(segment.anchor_x)
	model.advance(0.05)
	for binding in bindings:
		var left_id := int(binding[1])
		if model._segment_index_by_id(left_id) >= 0:
			_check(_segment_anchor(model, left_id) > float(anchors[left_id]), "causal front segment %d moves right as a rigid motor" % left_id)
	_check(model.gravity_gap_count >= 1 and _invariants_hold(model), "FIFO and causal gaps share one rigid gravity integrator")

func _test_insertion_during_rollback() -> void:
	var model := _setup_clear(MAIN_PATTERN)
	model.advance(0.05)
	model.advance(0.08)
	var gap_id := int(model.segment_gaps[0].id)
	var front_uid := int(model.balls[0].uid)
	var before_insert := _position(model, front_uid)
	var rear_index := model.balls.size() - 1
	model.try_insert_shot(TeamData.Identity.GREEN, float(model.balls[rear_index].x) - 1.0)
	_check(absf(_position(model, front_uid) - before_insert + model.spacing) < 0.001, "rollback-time insertion still pushes preceding front LEFT one slot")
	_check(model.segment_gaps.any(func(gap): return int(gap.id) == gap_id and int(gap.type) == ChainModel.GapType.CAUSAL), "insertion preserves existing causal ID and type")
	var after_insert := _position(model, front_uid)
	model.advance(0.05)
	_check(_position(model, front_uid) > after_insert, "preserved causal motor resumes RIGHT after insertion")
	_check(_invariants_hold(model), "rollback-time insertion preserves segment invariants")

func _cascade_contact_time(step: float) -> Dictionary:
	var model := _setup_clear(CASCADE_PATTERN)
	while model.event_log.size() < 2 and model.simulation_time < 2.0:
		model.advance(step)
	return {"events": model.event_log.duplicate(true), "time": float(model.event_log[1].time) if model.event_log.size() > 1 else -1.0}

func _test_frame_rate_stability() -> void:
	var baseline := _cascade_contact_time(1.0 / 120.0)
	for step in [1.0 / 60.0, 1.0 / 30.0, 0.08]:
		var sample := _cascade_contact_time(step)
		_check((sample.events as Array).size() == 2 and int(sample.events[0].identity) == TeamData.Identity.YELLOW and int(sample.events[1].identity) == TeamData.Identity.RED, "step %.4f preserves event colors/order" % step)
		_check(absf(float(sample.time) - float(baseline.time)) <= maxf(step, 1.0 / 60.0) + 0.002, "step %.4f keeps physical contact time stable" % step)

func _test_long_mixed_stream() -> void:
	var model := ChainModel.new()
	model.set_lane_width(900.0)
	model.reset_run()
	var accepted := 0
	for frame in range(7200):
		if frame % 24 == 0 and not model.balls.is_empty():
			var target_index := posmod(floori(frame / 24.0) * 7, model.balls.size())
			var target: Dictionary = model.balls[target_index]
			if model.try_insert_shot(int(target.identity), float(target.x) + (1.0 if frame % 48 == 0 else -1.0)):
				accepted += 1
		if frame % 601 == 0 and not model.cache.is_empty():
			model.return_cached(mini(3, model.cache.size()))
		model.advance(1.0 / 60.0)
		if frame % 60 == 0:
			_check(_invariants_hold(model), "120s mixed stream remains valid at second %d" % floori(frame / 60.0))
			_check(model.balls.size() <= model.max_auto_population + 8 and model.offscreen_right_count() <= model.max_auto_population, "120s mixed stream remains bounded at second %d" % floori(frame / 60.0))
	_check(accepted > 100 and model.total_match_events > 100 and model.total_rollbacks_started > 0, "long stress exercises rapid shots, many matches and causal rollback (%d/%d/%d)" % [accepted, model.total_match_events, model.total_rollbacks_started])
	_check(model.total_fresh_generated > model.initial_population, "long stress preserves continuing offscreen fresh arrivals")
	_check(model.invariant_violations == 0, "long stress finishes without feed sprint or overlap")

func _finish() -> void:
	if _failures.is_empty():
		print("P014 causal rollback/feed: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P014 causal rollback/feed: " + failure)
	print("P014 causal rollback/feed: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
