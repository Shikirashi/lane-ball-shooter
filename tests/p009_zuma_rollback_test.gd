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

func _display_for_uid(model: ChainModel, uid: int) -> float:
	for ball in model.balls:
		if int(ball.uid) == uid:
			return float(ball.display_x)
	return NAN

func _is_sorted(model: ChainModel) -> bool:
	for index in range(1, model.balls.size()):
		if float(model.balls[index].x) < float(model.balls[index - 1].x) - 0.001:
			return false
	return true

func _middle_clear_model(left_identity: int, right_identity: int) -> ChainModel:
	var model := ChainModel.new()
	var identities: Array[int] = [left_identity, left_identity, TeamData.Identity.BLUE, TeamData.Identity.BLUE, right_identity, right_identity]
	model.set_test_state(identities, 100.0)
	model.try_insert_shot(TeamData.Identity.BLUE, float(model.balls[3].display_x) + 4.0)
	return model

func _run() -> void:
	_test_front_rolls_back_and_right_section_does_not_jump()
	_test_same_color_delayed_cascade()
	_test_multistage_cascade()
	_test_wide_and_end_clears()
	_test_multiple_gaps_and_restart()
	_test_fifo_and_fresh_feed_isolation()
	_test_subdivision_and_collision_during_rollback()
	_test_passive_runs_remain_passive()
	_finish()

func _test_front_rolls_back_and_right_section_does_not_jump() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.GREEN, TeamData.Identity.GREEN]
	model.set_test_state(identities, 100.0)
	var left_uid := int(model.balls[1].uid)
	var right_uid := int(model.balls[4].uid)
	var left_before := _position_for_uid(model, left_uid)
	var right_before := _position_for_uid(model, right_uid)
	model.try_insert_shot(TeamData.Identity.BLUE, float(model.balls[3].display_x) + 4.0)
	var left_after_clear := _position_for_uid(model, left_uid)
	var right_after_clear := _position_for_uid(model, right_uid)
	_check(is_equal_approx(left_after_clear, left_before), "left/front section retains its position immediately after clear")
	_check(is_equal_approx(right_after_clear, right_before + model.spacing), "right/trailing section only reflects insertion spacing, not clear teleport")
	_check(model.rollback_gaps.size() == 1, "middle clear creates one causal rollback gap")
	_check(right_after_clear - left_after_clear > model.spacing * 3.0, "removed middle group leaves a visible spatial gap")
	var left_display := _display_for_uid(model, left_uid)
	model.advance(0.1)
	_check(_position_for_uid(model, left_uid) > left_after_clear, "front section moves backward/right during rollback")
	_check(is_equal_approx(_position_for_uid(model, right_uid), right_after_clear - model.speed * 0.1), "trailing section receives only normal conveyor movement")
	_check(_position_for_uid(model, right_uid) - _position_for_uid(model, left_uid) < right_after_clear - left_after_clear, "causal gap shrinks smoothly")
	_check(_display_for_uid(model, left_uid) > left_display and is_equal_approx(_display_for_uid(model, left_uid), _position_for_uid(model, left_uid)), "front rendered position follows its actual rollback position")
	_check(_is_sorted(model), "rollback preserves ascending chain order")
	model.advance(1.0)
	_check(model.rollback_gaps.is_empty() and model.total_match_events == 1, "different-color ends reconnect without cascade")
	_check(absf((_position_for_uid(model, right_uid) - _position_for_uid(model, left_uid)) - model.spacing) < 0.01, "reconnected ends meet at normal spacing without overlap")

func _test_same_color_delayed_cascade() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.RED]
	model.set_test_state(identities, 100.0)
	model.try_insert_shot(TeamData.Identity.BLUE, float(model.balls[3].display_x) + 4.0)
	_check(model.event_log.size() == 1 and int(model.event_log[0].identity) == TeamData.Identity.BLUE, "player match emits before rollback cascade")
	var gap_before := float(model.balls[2].x) - float(model.balls[1].x)
	model.advance(0.1)
	_check(model.event_log.size() == 1 and float(model.balls[2].x) - float(model.balls[1].x) < gap_before, "same-color ends attract without premature cascade")
	model.advance(1.0)
	_check(model.event_log.size() == 2, "same-color physical contact emits one delayed cascade")
	if model.event_log.size() == 2:
		_check(int(model.event_log[1].identity) == TeamData.Identity.RED and int(model.event_log[1].size) == 3, "causal 2+1 reconnect records true RED group size")
	_check(model.total_rollbacks_completed >= 1 and model.rollback_gaps.is_empty(), "completed cascade retires causal gap state")

func _test_multistage_cascade() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.GREEN, TeamData.Identity.GREEN,
		TeamData.Identity.BLUE, TeamData.Identity.BLUE,
		TeamData.Identity.GREEN,
		TeamData.Identity.RED,
	]
	model.set_test_state(identities, 100.0)
	model.try_insert_shot(TeamData.Identity.BLUE, float(model.balls[5].display_x) + 4.0)
	model.advance(3.0)
	_check(model.event_log.size() == 3, "player clear can produce two terminating physical cascade stages")
	if model.event_log.size() == 3:
		_check([int(model.event_log[0].identity), int(model.event_log[1].identity), int(model.event_log[2].identity)] == [TeamData.Identity.BLUE, TeamData.Identity.GREEN, TeamData.Identity.RED], "multistage cascade preserves causal event order")
		_check([int(model.event_log[0].size), int(model.event_log[1].size), int(model.event_log[2].size)] == [3, 3, 3], "each cascade group records exactly one true-size event")
	_check(model.rollback_gaps.is_empty(), "multistage cascade terminates without stale motors")

func _test_wide_and_end_clears() -> void:
	var wide := ChainModel.new()
	var wide_ids: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED]
	for unused in range(7):
		wide_ids.append(TeamData.Identity.GREEN)
	wide_ids.append(TeamData.Identity.BLUE)
	wide.set_test_state(wide_ids, 100.0)
	var wide_left_uid := int(wide.balls[1].uid)
	var wide_right_uid := int(wide.balls[-1].uid)
	wide.try_insert_shot(TeamData.Identity.GREEN, float(wide.balls[5].display_x) + 4.0)
	_check(wide.last_match_size == 8 and wide.rollback_gaps.size() == 1, "seven-plus-shot clear creates one wide rollback gap")
	var initial_wide_gap := _position_for_uid(wide, wide_right_uid) - _position_for_uid(wide, wide_left_uid)
	wide.advance(0.2)
	_check(_position_for_uid(wide, wide_right_uid) - _position_for_uid(wide, wide_left_uid) < initial_wide_gap, "wide gap closes incrementally rather than teleporting")
	wide.advance(2.0)
	_check(wide.rollback_gaps.is_empty() and _is_sorted(wide), "wide rollback completes without overlap")

	var left_clear := ChainModel.new()
	var left_ids: Array[int] = [TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.RED, TeamData.Identity.RED]
	left_clear.set_test_state(left_ids, 100.0)
	var surviving_uid := int(left_clear.balls[2].uid)
	var surviving_before := _position_for_uid(left_clear, surviving_uid)
	left_clear.try_insert_shot(TeamData.Identity.BLUE, float(left_clear.balls[1].display_x) + 4.0)
	_check(left_clear.rollback_gaps.is_empty(), "left-edge clear manufactures no reverse actor")
	_check(is_equal_approx(_position_for_uid(left_clear, surviving_uid), surviving_before + left_clear.spacing), "left-edge trailing section is not pulled into cleared space")

	var tail_clear := ChainModel.new()
	var tail_ids: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.BLUE]
	tail_clear.set_test_state(tail_ids, 100.0)
	var tail_uid := int(tail_clear.balls[1].uid)
	var tail_before := _position_for_uid(tail_clear, tail_uid)
	tail_clear.try_insert_shot(TeamData.Identity.BLUE, float(tail_clear.balls[-1].display_x) + 4.0)
	_check(tail_clear.rollback_gaps.size() == 1 and int(tail_clear.rollback_gaps[0].right_uid) < 0, "right-tail clear creates bounded recoil state")
	tail_clear.advance(1.0)
	var tail_net_move := _position_for_uid(tail_clear, tail_uid) - tail_before
	_check(tail_clear.rollback_gaps.is_empty() and tail_net_move > 0.0 and tail_net_move <= tail_clear.spacing * ChainModel.TAIL_RECOIL_SPACING_FACTOR, "tail recoil is visible, bounded and terminates")

	var all_clear := ChainModel.new()
	var pair: Array[int] = [TeamData.Identity.YELLOW, TeamData.Identity.YELLOW]
	all_clear.set_test_state(pair, 100.0)
	all_clear.try_insert_shot(TeamData.Identity.YELLOW, float(all_clear.balls[-1].display_x) + 4.0)
	_check(all_clear.total_match_events == 1 and all_clear.rollback_gaps.is_empty(), "full clear produces no rollback actor")
	_check(all_clear.balls.size() == all_clear.initial_population, "full clear promptly resumes bounded supply")

func _test_multiple_gaps_and_restart() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.BLUE, TeamData.Identity.BLUE,
		TeamData.Identity.GREEN, TeamData.Identity.GREEN,
		TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
	]
	model.set_test_state(identities, 100.0)
	model.try_insert_shot(TeamData.Identity.BLUE, float(model.balls[3].display_x) + 4.0)
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[-1].display_x) + 4.0)
	_check(model.rollback_gaps.size() == 2, "two quick shots create two explicit rollback states")
	var remained_sorted := true
	for unused in range(180):
		model.advance(1.0 / 60.0)
		remained_sorted = remained_sorted and _is_sorted(model)
	_check(remained_sorted, "multiple rollback gaps never invert chain order")
	_check(model.rollback_gaps.is_empty(), "multiple rollback states terminate without becoming stuck")
	_check(model.total_match_events == 2, "independent different-color gaps do not fabricate cascades")

	var restart := _middle_clear_model(TeamData.Identity.RED, TeamData.Identity.GREEN)
	_check(not restart.rollback_gaps.is_empty(), "restart setup has active rollback")
	restart.reset_run()
	_check(restart.rollback_gaps.is_empty() and restart.total_rollbacks_started == 0 and restart.total_rollbacks_completed == 0, "restart clears all transient rollback state and counters")

func _test_fifo_and_fresh_feed_isolation() -> void:
	var fifo := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.GREEN]
	var cached: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	fifo.set_test_state(identities, 100.0, cached)
	fifo.try_insert_shot(TeamData.Identity.BLUE, float(fifo.balls[3].display_x) + 4.0)
	_check(fifo.identities().slice(-3) == cached, "FIFO RED,GREEN,BLUE returns remain ordered during rollback")
	_check(fifo.rollback_gaps.size() == 1, "FIFO return creates no extra causal rollback state")
	fifo.advance(2.0)
	_check(fifo.cache.is_empty() and _is_sorted(fifo), "FIFO catch-up and causal rollback coexist without reversal")

	var feed := ChainModel.new()
	feed.set_test_state(identities, 100.0)
	feed.continuous_feed_enabled = true
	var existing_uids := {}
	for ball in feed.balls:
		existing_uids[int(ball.uid)] = true
	feed.try_insert_shot(TeamData.Identity.BLUE, float(feed.balls[3].display_x) + 4.0)
	var gap_left_x := float(feed.balls[1].x)
	var gap_right_x := float(feed.balls[2].x)
	var new_ball_count := 0
	for ball in feed.balls:
		if not existing_uids.has(int(ball.uid)) and int(ball.identity) != TeamData.Identity.BLUE:
			new_ball_count += 1
			_check(float(ball.x) >= gap_right_x + feed.spacing - 0.01, "fresh feed appears behind trailing section, never inside clear gap")
	_check(new_ball_count > 0 and feed.balls.size() <= feed.max_auto_population, "fresh feeder continues during rollback within live cap")
	_check(float(feed.balls[2].x) - gap_left_x > feed.spacing, "fresh arrivals do not collapse the interior causal gap")

func _test_subdivision_and_collision_during_rollback() -> void:
	var one_step := _middle_clear_model(TeamData.Identity.RED, TeamData.Identity.GREEN)
	var split_step := _middle_clear_model(TeamData.Identity.RED, TeamData.Identity.GREEN)
	var one_left_uid := int(one_step.rollback_gaps[0].left_uid)
	var split_left_uid := int(split_step.rollback_gaps[0].left_uid)
	one_step.advance(0.31)
	for unused in range(31):
		split_step.advance(0.01)
	_check(absf(_position_for_uid(one_step, one_left_uid) - _position_for_uid(split_step, split_left_uid)) < 0.02, "large and subdivided rollback steps produce consistent positions")

	var collision := _middle_clear_model(TeamData.Identity.RED, TeamData.Identity.GREEN)
	var moving_uid := int(collision.rollback_gaps[0].left_uid)
	collision.advance(0.1)
	var rendered_contact := _display_for_uid(collision, moving_uid)
	_check(collision.try_insert_shot(TeamData.Identity.YELLOW, rendered_contact + 2.0), "shot collision uses visible position during retraction")
	_check(_is_sorted(collision), "rollback endpoint insertion preserves stable sorted geometry")

func _test_passive_runs_remain_passive() -> void:
	var seven: Array[int] = []
	for unused in range(7):
		seven.append(TeamData.Identity.GREEN)
	var model := ChainModel.new()
	model.set_test_state(seven, 1000.0)
	model.advance(10.0)
	_check(model.total_match_events == 0 and model.identities() == seven, "passive seven-ball run survives ordinary conveyor movement")
	var cached: Array[int] = seven.duplicate()
	var returned := ChainModel.new()
	var red: Array[int] = [TeamData.Identity.RED]
	returned.set_test_state(red, 100.0, cached)
	returned.return_cached(7)
	returned.advance(20.0)
	_check(returned.total_match_events == 0, "passive long run survives cache catch-up and noncausal reconnection")

func _finish() -> void:
	if _failures.is_empty():
		print("P009 Zuma rollback: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P009 Zuma rollback: " + failure)
	print("P009 Zuma rollback: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
