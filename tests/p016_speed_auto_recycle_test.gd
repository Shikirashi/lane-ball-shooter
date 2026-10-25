extends SceneTree

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

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
	_test_triple_speed_determinism()
	_test_superseded_recycle_is_physical_retention()
	_test_multiple_crossings_preserve_uids()
	_test_match_and_natural_join_semantics()
	_test_long_no_match_stream()
	_test_long_active_stream()
	await _test_terminal_freeze_and_restart()
	_finish()

func _test_triple_speed_determinism() -> void:
	_check(is_equal_approx(ChainModel.DEFAULT_SPEED, 102.0), "canonical normal conveyor speed is 102 px/s")
	for delta in [1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0, 0.1, 0.8]:
		var model := ChainModel.new()
		var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.GREEN]
		model.set_test_state(identities, 500.0)
		var before := float(model.balls[0].x)
		model.advance(delta)
		_check(absf(float(model.balls[0].x) - before + 102.0 * delta) < 0.002, "source-supported train advances exactly 102*delta at %.5fs" % delta)
		_check(_invariants_hold(model), "speed sample %.5fs remains rigid and non-overlapping" % delta)
	_check(is_equal_approx(ShooterView.SHOT_TRAVEL_TIME, 0.20), "vertical shot travel remains 0.20 seconds")
	_check(is_equal_approx(LaneCombatModel.DEFAULT_ENEMY_SPEED, 0.24), "enemy average movement remains 0.24 units/s")
	_check(is_equal_approx(ChainModel.GRAVITY_INITIAL_RIGHT_SPEED, 60.0) and is_equal_approx(ChainModel.GRAVITY_ACCELERATION, 900.0) and is_equal_approx(ChainModel.GRAVITY_MAX_RIGHT_SPEED, 420.0), "virtual-gravity profile remains 60/900/420")

func _test_superseded_recycle_is_physical_retention() -> void:
	var model := ChainModel.new()
	var colors: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW]
	model.set_test_state(colors, -190.0)
	var uids: Array[int] = []
	for ball in model.balls:
		uids.append(int(ball.uid))
	model.advance(2.0)
	_check(model.offscreen_left_count() >= 3, "RED GREEN BLUE remain physically offscreen-left without a match")
	_check(model.identities().slice(0, colors.size()) == colors, "hidden colors retain original order")
	for index in range(uids.size()):
		_check(model._ball_index_by_uid(uids[index]) == index, "hidden member %d retains its original UID and index" % index)
	_check(model.cache.is_empty() and model.total_cache_returned == 0 and model.return_cached(3) == 0, "superseded right-side recycle path stays inactive in continuous play")
	_check(model.active_population_count() <= model.max_auto_population, "hidden history does not count against active population")
	_check(_invariants_hold(model), "physical left retention preserves zero-overlap geometry")

func _test_multiple_crossings_preserve_uids() -> void:
	var model := ChainModel.new()
	var outgoing: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE, TeamData.Identity.YELLOW, TeamData.Identity.RED, TeamData.Identity.BLUE]
	model.set_test_state(outgoing, -500.0)
	var uids: Array[int] = []
	var positions: Array[float] = []
	for ball in model.balls:
		uids.append(int(ball.uid))
		positions.append(float(ball.x))
	model.advance(1.0)
	_check(model.offscreen_left_count() >= outgoing.size(), "all initially crossed balls remain in offscreen-left history")
	_check(model.identities().slice(0, outgoing.size()) == outgoing, "simultaneous crossings retain exact color order")
	for index in range(uids.size()):
		var ball_index := model._ball_index_by_uid(uids[index])
		_check(ball_index == index and float(model.balls[ball_index].x) < positions[index], "crossed UID %d advances continuously left without teleport" % uids[index])
	_check(model.cache.is_empty() and model.pending_cache_returns == 0, "multiple crossings create no bank or eligible return tokens")
	_check(_invariants_hold(model), "multiple hidden crossings remain rigid")

func _test_match_and_natural_join_semantics() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.BLUE, TeamData.Identity.GREEN]
	model.set_test_state(identities, -120.0)
	var red_uids := [int(model.balls[0].uid), int(model.balls[1].uid)]
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].x) + 1.0)
	model.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(model.total_match_events == 1 and model.segment_gaps.size() == 1, "player insertion still resolves after 50ms and opens one gap")
	model.advance(2.0)
	_check(model._ball_index_by_uid(red_uids[0]) >= 0 and model._ball_index_by_uid(red_uids[1]) >= 0, "match does not recreate or lose hidden red UIDs")
	_check(model.cache.is_empty() and _invariants_hold(model), "post-match gravity uses physical members rather than recycling")

	var seven := ChainModel.new()
	var greens: Array[int] = []
	for unused in range(7):
		greens.append(TeamData.Identity.GREEN)
	seven.set_test_state(greens, 300.0)
	seven.add_test_segment(greens, 900.0, ChainModel.GapType.FEED)
	seven.advance(4.0)
	_check(seven.total_match_events == 0 and seven.identities().size() == 14, "natural seven-ball FEED reconnection remains noncausal")
	_check(seven.segment_gaps.is_empty() and _invariants_hold(seven), "virtual gravity closes natural gap without overlap")

func _test_long_no_match_stream() -> void:
	var model := ChainModel.new()
	model.set_fresh_seed(0x160016)
	var max_active := model.active_population_count()
	var max_offscreen_right := model.offscreen_right_count()
	for frame in range(120 * 60):
		model.advance(1.0 / 60.0)
		max_active = maxi(max_active, model.active_population_count())
		max_offscreen_right = maxi(max_offscreen_right, model.offscreen_right_count())
		if frame % 600 == 0:
			_check(_invariants_hold(model), "two-minute no-match stream is valid at second %d" % (frame / 60))
	_check(model.total_match_events == 0 and model.offscreen_left_count() > 24, "two-minute stream retains growing physical left history")
	_check(model.total_cache_returned == 0 and model.cache.is_empty(), "two-minute stream never respawns an exited color on the right")
	_check(model.total_fresh_generated > model.initial_population, "independent weighted fresh generation remains infinite")
	_check(max_active <= model.max_auto_population and max_offscreen_right <= 1, "long stream bounds active and offscreen-right populations")

func _find_pair_impact(model: ChainModel) -> Dictionary:
	for index in range(model.balls.size() - 1):
		var left: Dictionary = model.balls[index]
		var right: Dictionary = model.balls[index + 1]
		if int(left.identity) == int(right.identity) and float(right.x) - float(left.x) <= model.spacing + 0.01 and float(right.x) >= model.radius and float(right.x) <= model.lane_width - model.radius:
			return {"identity": int(right.identity), "x": float(right.x) + 1.0}
	return {}

func _test_long_active_stream() -> void:
	var model := ChainModel.new()
	model.set_fresh_seed(0x516016)
	var next_shot := 0.4
	for frame in range(120 * 60):
		if model.simulation_time + 0.0001 >= next_shot:
			var target := _find_pair_impact(model)
			if not target.is_empty():
				model.try_insert_shot(int(target.identity), float(target.x))
			next_shot += 0.4
		model.advance(1.0 / 60.0)
		if frame % 600 == 0:
			_check(_invariants_hold(model), "two-minute active stream is valid at second %d" % (frame / 60))
	model.advance(10.0)
	_check(model.total_match_events > 10, "frequent deterministic insertions exercise staged matches")
	_check(model.offscreen_left_count() > 0 and model.total_fresh_generated > model.initial_population, "active stream keeps physical history and fresh supply moving")
	_check(model.total_cache_returned == 0 and model.cache.is_empty(), "active matches never schedule a right-side return")
	_check(model.segment_gaps.is_empty() and _invariants_hold(model), "all unsupported groups reconnect after active stress settles")

func _test_terminal_freeze_and_restart() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var chain: ChainModel = main.get("_chain_model")
	chain.advance(20.0)
	_check(chain.offscreen_left_count() > 0 and chain.total_cache_returned == 0, "main stream accumulates hidden physical history without recycling")
	main.call("_on_game_over_requested", TeamData.Identity.RED)
	var frozen_time := chain.simulation_time
	var frozen_leftmost := chain.leftmost_x()
	main.call("_process", 5.0)
	_check(chain.simulation_time == frozen_time and chain.leftmost_x() == frozen_leftmost, "terminal defeat freezes hidden and visible chain physics")
	main.call("_restart_run")
	_check(chain.offscreen_left_count() == 0 and chain.cache.is_empty() and chain.total_cache_returned == 0, "restart discards hidden history and retired recycle state")
	_check(chain.balls.size() == chain.initial_population and is_equal_approx(chain.speed, 102.0), "restart restores original seeded stream at 102 px/s")
	var battlefield: Battlefield = main.get("_battlefield")
	_check(battlefield.encounter_total() == 32 and battlefield.encounter_spawned() == 4, "restart preserves eight-per-lane finite encounter")
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P016 speed/retained-history compatibility: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P016 speed/retained-history compatibility: " + failure)
	print("P016 speed/retained-history compatibility: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
