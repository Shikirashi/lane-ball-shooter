extends SceneTree

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _position_for_uid(model: ChainModel, uid: int) -> float:
	for ball in model.balls:
		if int(ball.uid) == uid:
			return float(ball.x)
	return NAN

func _is_sorted(model: ChainModel) -> bool:
	for index in range(1, model.balls.size()):
		if float(model.balls[index].x) < float(model.balls[index - 1].x) - 0.001:
			return false
	return true

func _theatrical_model() -> ChainModel:
	var model := ChainModel.new()
	var identities: Array[int] = [
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
		TeamData.Identity.RED, TeamData.Identity.RED,
	]
	model.set_test_state(identities, 100.0)
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].display_x) + 4.0)
	return model

func _run() -> void:
	_test_exact_settle_and_accelerating_cascade()
	_test_subdivision_and_large_delta_order()
	_test_match_guards_and_large_group()
	_test_concurrent_shots_and_cleanup()
	await _test_live_event_routing_and_pause()
	_finish()

func _test_exact_settle_and_accelerating_cascade() -> void:
	var model := _theatrical_model()
	_check(model.balls.size() == 7 and model.identities().slice(2, 5) == [TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW], "contact immediately shows the real seven-ball chain and yellow triple")
	_check(model.pending_insertions.size() == 1 and model.total_match_events == 0 and model.rollback_gaps.is_empty(), "contact registers settling only, without match or rollback")
	var inserted_uid := int(model.pending_insertions[0].uid)
	_check(model._ball_index_by_uid(inserted_uid) >= 0, "settling shot has a stable live UID")
	model.advance(0.049)
	_check(model.balls.size() == 7 and model.total_match_events == 0 and model.pending_insertions.size() == 1, "t=0.049 keeps all balls visible and emits no match")
	_check(absf(float(model.pending_insertions[0].elapsed) - 0.049) < 0.00001, "settle clock advances by deterministic gameplay delta")
	model.advance(0.001)
	_check(model.event_log.size() == 1 and int(model.event_log[0].identity) == TeamData.Identity.YELLOW and int(model.event_log[0].size) == 3, "t=0.050 emits exactly one YELLOW size-3 event")
	_check(absf(float(model.event_log[0].time) - 0.05) < 0.00001, "initial match event is timestamped at the 50ms boundary")
	_check(model.balls.size() == 4 and model.pending_insertions.is_empty() and model.rollback_gaps.size() == 1, "yellow pop leaves four reds, retires settle, and creates one physical gap")

	var left_a_uid := int(model.balls[0].uid)
	var left_b_uid := int(model.balls[1].uid)
	var right_uid := int(model.balls[2].uid)
	var left_a_before := _position_for_uid(model, left_a_uid)
	var left_b_before := _position_for_uid(model, left_b_uid)
	var right_before := _position_for_uid(model, right_uid)
	var spacing_before := left_b_before - left_a_before
	var initial_motor_speed := float(model.rollback_gaps[0].speed)
	model.advance(0.01)
	var left_a_delta := _position_for_uid(model, left_a_uid) - left_a_before
	var left_b_delta := _position_for_uid(model, left_b_uid) - left_b_before
	var right_delta := _position_for_uid(model, right_uid) - right_before
	_check(left_a_delta > 0.0 and absf(left_a_delta - left_b_delta) < 0.00001, "first rollback update moves both front reds right by one rigid-group delta")
	_check(absf((_position_for_uid(model, left_b_uid) - _position_for_uid(model, left_a_uid)) - spacing_before) < 0.00001, "front pair preserves exact internal spacing")
	_check(absf(right_delta + model.speed * 0.01) < 0.00001, "receiving right pair gets ordinary conveyor travel only")
	_check(float(model.rollback_gaps[0].speed) > initial_motor_speed and float(model.rollback_gaps[0].speed) <= ChainModel.ROLLBACK_MAX_SPEED, "shared rollback motor accelerates from its initial speed")
	_check(model.event_log.size() == 1, "red cascade remains pending before contact")

	var previous_gap := _position_for_uid(model, right_uid) - _position_for_uid(model, left_b_uid)
	var speed_rose := false
	var previous_speed := float(model.rollback_gaps[0].speed)
	for unused in range(480):
		if model.event_log.size() >= 2:
			break
		model.advance(1.0 / 240.0)
		if not model.rollback_gaps.is_empty():
			var current_speed := float(model.rollback_gaps[0].speed)
			speed_rose = speed_rose or current_speed > previous_speed
			previous_speed = current_speed
			var current_gap := _position_for_uid(model, right_uid) - _position_for_uid(model, left_b_uid)
			_check(current_gap <= previous_gap + 0.0001, "physical gap decreases monotonically before contact")
			previous_gap = current_gap
	_check(speed_rose, "rollback velocity continues rising over successive updates")
	_check(model.event_log.size() == 2, "physical contact eventually produces one cascade")
	if model.event_log.size() == 2:
		_check(int(model.event_log[1].identity) == TeamData.Identity.RED and int(model.event_log[1].size) == 4, "contact emits exactly one RED size-4 cascade")
		_check(float(model.event_log[1].time) > float(model.event_log[0].time), "yellow and red events have distinct increasing simulation timestamps")
	_check(model.total_match_events == 2 and model.rollback_gaps.is_empty(), "cascade completes once without an orphaned motor")

func _test_subdivision_and_large_delta_order() -> void:
	var step_sizes: Array[float] = [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]
	var positions: Array[float] = []
	for delta in step_sizes:
		var model := _theatrical_model()
		var left_uid := int(model.balls[1].uid)
		var elapsed := 0.0
		while elapsed < 0.25 - 0.000001:
			var step := minf(delta, 0.25 - elapsed)
			model.advance(step)
			elapsed += step
		positions.append(_position_for_uid(model, left_uid))
		_check(model.event_log.size() == 1 and int(model.event_log[0].identity) == TeamData.Identity.YELLOW, "%d FPS has only the initial event before red contact" % roundi(1.0 / delta))
		_check(_is_sorted(model), "%d FPS preserves chain ordering" % roundi(1.0 / delta))
	_check(absf(positions[0] - positions[1]) < 0.02 and absf(positions[1] - positions[2]) < 0.02, "30/60/120 FPS subdivisions produce consistent rollback positions")

	var large := _theatrical_model()
	large.advance(1.5)
	_check(large.event_log.size() == 2, "one large update processes settle, rollback and cascade without skipping stages")
	if large.event_log.size() == 2:
		_check([int(large.event_log[0].identity), int(large.event_log[1].identity)] == [TeamData.Identity.YELLOW, TeamData.Identity.RED], "large update preserves YELLOW then RED ordering")
		_check(float(large.event_log[0].time) >= 0.05 and float(large.event_log[1].time) > float(large.event_log[0].time), "large update retains distinct event times")

func _test_match_guards_and_large_group() -> void:
	var seven: Array[int] = []
	for unused in range(7):
		seven.append(TeamData.Identity.GREEN)
	var wrong := ChainModel.new()
	wrong.set_test_state(seven, 200.0)
	wrong.try_insert_shot(TeamData.Identity.RED, float(wrong.balls[3].display_x) + 4.0)
	wrong.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(wrong.total_match_events == 0 and wrong.balls.size() == 8, "wrong-color settled shot does not clear a passive seven-run")
	wrong.advance(1.0)
	_check(wrong.total_match_events == 0, "passive long run remains after ordinary movement")

	var matching := ChainModel.new()
	matching.set_test_state(seven, 200.0)
	matching.try_insert_shot(TeamData.Identity.GREEN, float(matching.balls[3].display_x) + 4.0)
	matching.advance(0.049)
	_check(matching.total_match_events == 0 and matching.balls.size() == 8, "matching shot into seven still waits the full settle interval")
	matching.advance(0.001)
	_check(matching.total_match_events == 1 and matching.last_match_size == 8, "settled matching insertion clears all eight as one event")

	var miss := ChainModel.new()
	miss.set_test_state(seven, 800.0)
	_check(not miss.try_insert_shot(TeamData.Identity.GREEN, 100.0), "shot outside collision tolerance is rejected")
	_check(miss.pending_insertions.is_empty() and miss.total_match_events == 0, "miss registers no settle check or event")

func _test_concurrent_shots_and_cleanup() -> void:
	var concurrent := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.RED, TeamData.Identity.RED]
	concurrent.set_test_state(identities, 200.0)
	concurrent.try_insert_shot(TeamData.Identity.BLUE, float(concurrent.balls[1].display_x) + 4.0)
	concurrent.try_insert_shot(TeamData.Identity.RED, float(concurrent.balls[-1].display_x) + 4.0)
	_check(concurrent.pending_insertions.size() == 2 and concurrent.total_match_events == 0, "two accepted shots can settle concurrently without early clearing")
	concurrent.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(concurrent.total_match_events == 2 and concurrent.pending_insertions.is_empty(), "concurrent settled checks each resolve at most once")
	concurrent.advance(1.0)
	_check(concurrent.total_match_events == 2, "retired pending checks never emit duplicates")

	var active := _theatrical_model()
	active.advance(ChainModel.INSERT_SETTLE_TIME)
	active.advance(0.08)
	var endpoint_index := active._ball_index_by_uid(int(active.rollback_gaps[0].left_uid))
	var contact_x := float(active.balls[endpoint_index].display_x)
	_check(active.try_insert_shot(TeamData.Identity.GREEN, contact_x + 2.0), "additional shot can hit the rendered front segment during rollback")
	_check(active.pending_insertions.size() == 1 and _is_sorted(active), "rollback-time insertion retains a pending UID and sorted geometry")
	active.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(active.total_match_events == 1 and active.pending_insertions.is_empty(), "nonmatching rollback-time shot settles without fabricating a clear")

	var restart_settle := _theatrical_model()
	_check(not restart_settle.pending_insertions.is_empty(), "restart test begins mid-settle")
	restart_settle.reset_run()
	_check(restart_settle.pending_insertions.is_empty() and restart_settle.rollback_gaps.is_empty() and restart_settle.total_match_events == 0, "restart cancels settle checks and motors")
	var restart_rollback := _theatrical_model()
	restart_rollback.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(not restart_rollback.rollback_gaps.is_empty(), "restart test begins mid-rollback")
	restart_rollback.reset_run()
	_check(restart_rollback.pending_insertions.is_empty() and restart_rollback.rollback_gaps.is_empty(), "restart cannot resume a stale rollback")

func _test_live_event_routing_and_pause() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var chain: ChainModel = main.get("_chain_model")
	var progression: MatchProgression = main.get("_progression")
	var sfx = main.get("_sfx")
	var chain_view: BallChainView = main.get("_chain_view")
	var battlefield: Battlefield = main.get("_battlefield")
	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.RED, TeamData.Identity.RED]
	chain.set_test_state(identities, 200.0)
	main.call("_on_shot_reached_lane", TeamData.Identity.YELLOW, chain_view.position.x + float(chain.balls[3].display_x) + 4.0)
	_check(int(sfx.play_counts.insert) == 1 and int(sfx.play_counts.match) == 0 and progression.score == 0, "insert SFX occurs at contact without score, match SFX or attack")
	chain.advance(0.049)
	_check(int(sfx.play_counts.match) == 0 and progression.combo_count == 0, "live routing remains silent for the first 49ms")
	chain.advance(0.001)
	_check(int(sfx.play_counts.match) == 1 and int(sfx.play_counts.attack) == 1, "yellow pop routes exactly one match and defender attack cue")
	_check(progression.score == 100 and progression.combo_count == 1 and int(progression.last_result.identity) == TeamData.Identity.YELLOW, "yellow event awards first score/combo step")
	for unused in range(180):
		if chain.total_match_events >= 2:
			break
		chain.advance(1.0 / 120.0)
	_check(chain.total_match_events == 2 and int(sfx.play_counts.match) == 2 and int(sfx.play_counts.attack) == 2, "red contact routes one later match SFX and defender response")
	_check(progression.score == 250 and progression.combo_count == 2 and int(progression.last_result.identity) == TeamData.Identity.RED, "red size-4 cascade awards larger score and next combo step")

	chain.set_test_state([TeamData.Identity.BLUE, TeamData.Identity.BLUE], 300.0)
	chain.try_insert_shot(TeamData.Identity.BLUE, float(chain.balls[1].display_x) + 4.0)
	main.set("_game_over", true)
	main.call("_process", 0.5)
	_check(chain.total_match_events == 0 and chain.pending_insertions.size() == 1, "game over freezes a pending settle clock")
	main.call("_restart_run")
	_check(chain.pending_insertions.is_empty() and chain.rollback_gaps.is_empty(), "restart clears frozen theatrical state")
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P010 staged cascade: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P010 staged cascade: " + failure)
	print("P010 staged cascade: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
