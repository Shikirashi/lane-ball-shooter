extends SceneTree

const ConveyorBallLayerScript = preload("res://scripts/ui/conveyor_ball_layer.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _position(model: ChainModel, uid: int) -> float:
	var index := model._ball_index_by_uid(uid)
	return float(model.balls[index].x) if index >= 0 else NAN

func _invariants_hold(model: ChainModel) -> bool:
	if model.invariant_violations != 0 or model.segment_gaps.size() != maxi(0, model.segments.size() - 1):
		return false
	var seen := {}
	var prior := -INF
	for ball in model.balls:
		var uid := int(ball.uid)
		if seen.has(uid):
			return false
		seen[uid] = true
		var x := float(ball.x)
		if prior > -INF and x - prior < model.radius * 2.0 - 0.01:
			return false
		prior = x
	return true

func _run() -> void:
	_test_core_same_uid_left_reentry()
	_test_hidden_target_and_clip_contract()
	_test_hidden_population_does_not_throttle_feed()
	_test_long_no_shot_history()
	_test_far_left_motion_is_continuous()
	_test_insertion_and_concurrent_gravity()
	_test_frame_rate_contact_and_cascade()
	await _test_terminal_restart()
	_finish()

func _core_fixture() -> Dictionary:
	var model := ChainModel.new()
	var colors: Array[int] = [
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
	]
	model.set_test_state(colors, -100.0)
	var rear: Array[int] = [TeamData.Identity.BLUE, TeamData.Identity.BLUE]
	model.add_test_segment(rear, 350.0, ChainModel.GapType.FEED)
	return {
		"model": model,
		"red_uids": [int(model.balls[0].uid), int(model.balls[1].uid)],
		"red_colors": [int(model.balls[0].identity), int(model.balls[1].identity)],
	}

func _test_core_same_uid_left_reentry() -> void:
	var fixture := _core_fixture()
	var model: ChainModel = fixture.model
	var red_uids: Array = fixture.red_uids
	_check(_position(model, red_uids[0]) + model.radius < 0.0 and _position(model, red_uids[1]) + model.radius < 0.0, "both original RED circles begin completely outside LEFT")
	_check(model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].x) + 1.0), "visible YELLOW pair accepts the player shot")
	model.advance(0.049)
	_check(model.total_match_events == 0 and model._ball_index_by_uid(red_uids[0]) >= 0, "49ms settlement retains hidden RED UIDs and yellow triple")
	model.advance(0.001)
	_check(model.total_match_events == 1 and model.segment_gaps.size() == 1 and int(model.segment_gaps[0].type) == ChainModel.GapType.CAUSAL, "50ms yellow clear creates one authorized physical gap")
	var before := [_position(model, red_uids[0]), _position(model, red_uids[1])]
	var crossed_from_left := [false, false]
	var prior := before.duplicate()
	var maximum_step := 0.0
	while not model.segment_gaps.is_empty() and model.simulation_time < 3.0:
		model.advance(1.0 / 120.0)
		for index in range(2):
			var x := _position(model, red_uids[index])
			var displacement := x - float(prior[index])
			maximum_step = maxf(maximum_step, displacement)
			_check(displacement >= -0.001, "hidden RED %d moves continuously RIGHT while unsupported" % index)
			if x + model.radius >= 0.0:
				crossed_from_left[index] = true
			prior[index] = x
		_check(_invariants_hold(model), "core reentry frame preserves rigid non-overlap")
	_check(crossed_from_left[0] and crossed_from_left[1], "both same RED circles progressively reappear across the LEFT clip")
	_check(_position(model, red_uids[0]) < _position(model, red_uids[1]) and absf(_position(model, red_uids[1]) - _position(model, red_uids[0]) - model.spacing) < 0.001, "same RED UIDs retain order and exact spacing")
	_check(maximum_step <= ChainModel.GRAVITY_MAX_RIGHT_SPEED / 120.0 + 0.01, "reentry never teleports farther than the gravity speed cap")
	_check(model.cache.is_empty() and model.total_cache_returned == 0, "same RED balls never respawn at RIGHT")
	for uid in red_uids:
		_check(model._ball_index_by_uid(uid) >= 0, "original RED UID %d remains authoritative after reentry" % uid)

func _test_hidden_target_and_clip_contract() -> void:
	var model := ChainModel.new()
	var colors: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	model.set_test_state(colors, -240.0)
	var uids := [int(model.balls[0].uid), int(model.balls[1].uid), int(model.balls[2].uid)]
	_check(not model.try_insert_shot(TeamData.Identity.YELLOW, -120.0), "wholly hidden left ball cannot be targeted")
	var layer: ConveyorBallLayer = ConveyorBallLayerScript.new()
	root.add_child(layer)
	layer.set_model(model)
	layer.size = Vector2(model.lane_width, 70.0)
	_check(layer.rendered_uids().is_empty(), "established conveyor layer omits wholly clipped left balls")
	model.segments[0].anchor_x = -20.0
	model._refresh_snapshot()
	_check(layer.rendered_uids().has(uids[0]), "crossing circle becomes render-eligible progressively at LEFT")
	_check(model.try_insert_shot(TeamData.Identity.YELLOW, 0.0), "partially visible crossing ball can be targeted")
	layer.queue_free()

func _test_hidden_population_does_not_throttle_feed() -> void:
	var model := ChainModel.new()
	model.set_fresh_seed(0x170017)
	var initial_fresh := model.total_fresh_generated
	for frame in range(90 * 60):
		model.advance(1.0 / 60.0)
	_check(model.offscreen_left_count() > 24, "more than 24 authoritative balls can remain beyond LEFT")
	_check(model.total_fresh_generated > initial_fresh + 100, "fresh right source continues after hidden history exceeds old cap")
	_check(model.active_population_count() <= model.max_auto_population and model.offscreen_right_count() <= 1, "active/right population remains bounded independently")
	_check(model.cache.is_empty() and model.total_cache_returned == 0, "right feeder creates only new weighted colors")
	_check(_invariants_hold(model), "large hidden prefix remains ordered and unique")

func _test_long_no_shot_history() -> void:
	var model := ChainModel.new()
	model.set_fresh_seed(0x517017)
	var started_ms := Time.get_ticks_msec()
	var prior_leftmost := model.leftmost_x()
	for frame in range(180 * 60):
		model.advance(1.0 / 60.0)
		if frame % 1800 == 0 and frame > 0:
			_check(model.leftmost_x() < prior_leftmost, "no-shot leftmost position keeps advancing at minute sample")
			prior_leftmost = model.leftmost_x()
	var elapsed_ms := Time.get_ticks_msec() - started_ms
	_check(model.offscreen_left_count() > 100 and model.balls.size() > model.max_auto_population, "three-minute history grows without deleting hidden members")
	_check(model.total_fresh_generated > 250 and model.total_match_events == 0, "three-minute no-shot stream remains fresh and nonmatching")
	_check(model.active_population_count() <= model.max_auto_population and model.offscreen_right_count() <= 1, "three-minute active geometry remains bounded")
	_check(elapsed_ms < 10000, "three-minute deterministic history simulation remains bounded (%dms)" % elapsed_ms)
	_check(_invariants_hold(model), "three-minute history has zero overlap or duplicate UID")

func _test_far_left_motion_is_continuous() -> void:
	var model := ChainModel.new()
	var colors: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED]
	for index in range(8):
		colors.append(TeamData.Identity.GREEN if index % 2 == 0 else TeamData.Identity.BLUE)
	colors.append(TeamData.Identity.YELLOW)
	colors.append(TeamData.Identity.YELLOW)
	colors.append(TeamData.Identity.BLUE)
	model.set_test_state(colors, -600.0)
	var red_uid := int(model.balls[0].uid)
	var yellow_index := 11
	_check(float(model.balls[yellow_index].x) >= 0.0, "far-left fixture retains a visible yellow target")
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[yellow_index].x) + 1.0)
	model.advance(ChainModel.INSERT_SETTLE_TIME)
	var before := _position(model, red_uid)
	model.advance(0.1)
	var after := _position(model, red_uid)
	_check(after > before and after < -300.0, "far-left group begins physical rightward fall but is not summoned to x=0")
	_check(after - before <= ChainModel.GRAVITY_MAX_RIGHT_SPEED * 0.1 + 0.01, "far-left return distance obeys gravity cap")
	_check(model._ball_index_by_uid(red_uid) == 0 and model.cache.is_empty(), "far-left RED remains the same first member")

func _test_insertion_and_concurrent_gravity() -> void:
	var model := ChainModel.new()
	var colors: Array[int] = [
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.BLUE, TeamData.Identity.BLUE,
		TeamData.Identity.GREEN, TeamData.Identity.GREEN,
		TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
		TeamData.Identity.BLUE,
	]
	model.set_test_state(colors, -80.0)
	var first_uid := int(model.balls[0].uid)
	model.try_insert_shot(TeamData.Identity.BLUE, float(model.balls[3].x) + 1.0)
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[7].x) + 1.0)
	model.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(model.gap_type_counts().causal == 2, "two rapid matches create two causal gravity gaps")
	var before_insert := _position(model, first_uid)
	var visible_target := -1
	for index in range(model.balls.size()):
		if float(model.balls[index].x) + model.radius >= 0.0:
			visible_target = index
			break
	_check(visible_target >= 0 and model.try_insert_shot(TeamData.Identity.GREEN, float(model.balls[visible_target].x) + 1.0), "insertion during concurrent gravity targets a visible member")
	_check(absf(_position(model, first_uid) - before_insert + model.spacing) < 0.001, "insertion shifts offscreen-left prefix LEFT one full slot")
	model.advance(6.0)
	_check(model.segment_gaps.is_empty() and _invariants_hold(model), "concurrent gaps physically close without overlap")
	_check(model._ball_index_by_uid(first_uid) >= 0, "unmatched hidden UID survives concurrent operations")

func _cascade_time(step: float) -> Dictionary:
	var fixture := _core_fixture()
	var model: ChainModel = fixture.model
	# RED on both sides makes the post-yellow contact an authorized cascade.
	var right_members: Array = model.segments[1].members
	right_members[-2].identity = TeamData.Identity.RED
	right_members[-1].identity = TeamData.Identity.RED
	model.segments[1].members = right_members
	model._refresh_snapshot()
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].x) + 1.0)
	while model.event_log.size() < 2 and model.simulation_time < 3.0:
		model.advance(step)
	return {"events": model.event_log.duplicate(true), "valid": _invariants_hold(model)}

func _test_frame_rate_contact_and_cascade() -> void:
	var baseline := _cascade_time(1.0 / 120.0)
	_check((baseline.events as Array).size() == 2 and int(baseline.events[0].identity) == TeamData.Identity.YELLOW and int(baseline.events[1].identity) == TeamData.Identity.RED, "offscreen-left causal contact emits yellow then red cascade")
	for step in [1.0 / 60.0, 1.0 / 30.0, 0.08]:
		var sample := _cascade_time(step)
		_check((sample.events as Array).size() == 2 and bool(sample.valid), "cascade completes without overlap at %.4fs updates" % step)
		_check(float(sample.events[1].time) > float(sample.events[0].time), "cascade at %.4fs waits for physical contact" % step)

func _test_terminal_restart() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var chain: ChainModel = main.get("_chain_model")
	chain.advance(30.0)
	_check(chain.offscreen_left_count() > 0, "live Main owns retained hidden history")
	main.call("_on_game_over_requested", TeamData.Identity.RED)
	var frozen_x := chain.leftmost_x()
	main.call("_process", 2.0)
	_check(chain.leftmost_x() == frozen_x, "GAME OVER freezes hidden chain physics")
	main.call("_restart_run")
	_check(chain.offscreen_left_count() == 0 and chain.balls.size() == chain.initial_population and chain.cache.is_empty(), "restart discards hidden history and restores seed")
	var battlefield: Battlefield = main.get("_battlefield")
	_check(battlefield.encounter_total() == 32 and battlefield.encounter_spawned() == 4, "restart preserves 32-enemy encounter")
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P017 offscreen-left reentry: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P017 offscreen-left reentry: " + failure)
	print("P017 offscreen-left reentry: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
