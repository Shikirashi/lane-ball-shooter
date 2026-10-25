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
	return model.pending_cache_returns == model.cache.size()

func _run() -> void:
	_test_triple_speed_determinism()
	_test_no_match_fifo_recirculation()
	_test_large_exit_and_compatibility_api()
	_test_match_does_not_double_schedule()
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

func _test_no_match_fifo_recirculation() -> void:
	var model := ChainModel.new()
	var colors: Array[int] = [
		TeamData.Identity.RED,
		TeamData.Identity.GREEN,
		TeamData.Identity.BLUE,
		TeamData.Identity.YELLOW,
		TeamData.Identity.YELLOW,
	]
	model.set_test_state(colors, -190.0)
	model.continuous_feed_enabled = true
	var returned: Array[int] = []
	var returned_before := model.total_cache_returned
	model.advance(0.0)
	if model.total_cache_returned > returned_before:
		returned.append(int(model.balls[-1].identity))
		returned_before = model.total_cache_returned
	while returned.size() < 3 and model.simulation_time < 8.0:
		model.advance(1.0 / 120.0)
		if model.total_cache_returned > returned_before:
			_check(model.total_cache_returned == returned_before + 1, "microstep admits at most one FIFO return")
			returned.append(int(model.balls[-1].identity))
			returned_before = model.total_cache_returned
	_check(model.total_exited >= 3, "RED GREEN BLUE all exit without a player match")
	_check(returned.slice(0, 3) == [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE], "automatic no-match admissions preserve RED GREEN BLUE FIFO order")
	_check(model.total_match_events == 0 and model.total_automatic_cache_returned >= 3, "automatic recirculation does not require or cause a match")
	_check(model.total_exited == model.total_cache_returned + model.cache.size(), "every exit is exactly one returned or queued color")
	_check(_invariants_hold(model), "no-match FIFO recirculation preserves unique UIDs and zero overlap")

func _test_large_exit_and_compatibility_api() -> void:
	var model := ChainModel.new()
	var outgoing: Array[int] = [
		TeamData.Identity.RED,
		TeamData.Identity.GREEN,
		TeamData.Identity.BLUE,
		TeamData.Identity.YELLOW,
		TeamData.Identity.RED,
		TeamData.Identity.BLUE,
	]
	model.set_test_state(outgoing, -500.0)
	model.continuous_feed_enabled = true
	model.advance(0.0)
	_check(model.total_exited == outgoing.size(), "one update captures every fully crossed ball exactly once")
	_check(model.total_cache_returned == 1 and int(model.balls[-1].identity) == outgoing[0], "empty lane immediately restarts with the FIFO front")
	_check(model.cache == outgoing.slice(1), "remaining simultaneous exits retain exact FIFO order")
	var queue_before := model.cache.duplicate()
	var returned_before := model.total_cache_returned
	_check(model.return_cached(3) == 0 and model.return_cached(3) == 0, "compatibility return requests truthfully report no admission without a legal slot")
	_check(model.cache == queue_before and model.total_cache_returned == returned_before and model.pending_cache_returns == queue_before.size(), "repeated return requests create no duplicate or phantom quota")
	model.advance(1.0)
	_check(model.total_cache_returned > returned_before and model.pending_cache_returns == model.cache.size(), "ordinary advance drains eligible FIFO colors once space opens")
	_check(model.total_exited == model.total_cache_returned + model.cache.size(), "multi-exit bookkeeping remains exactly reconciled")
	_check(_invariants_hold(model), "large-delta rollover and admission stay non-overlapping")

func _test_match_does_not_double_schedule() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.BLUE, TeamData.Identity.GREEN,
		TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
	]
	var cached: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	model.set_test_state(identities, 600.0, cached)
	model.continuous_feed_enabled = true
	var eligible_before := model.total_cache_returned + model.cache.size()
	model.return_cached(3)
	model.return_cached(3)
	_check(model.total_cache_returned + model.cache.size() == eligible_before and model.pending_cache_returns == model.cache.size(), "manual match-era requests may admit but cannot double-book eligible colors")
	model.try_insert_shot(TeamData.Identity.RED, float(model.balls[1].x) + 1.0)
	model.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(model.total_match_events == 1, "player insertion still resolves after the 50ms settle")
	var accounted_after_match := model.total_cache_returned + model.cache.size()
	model.return_cached(3)
	model.advance(3.0)
	_check(model.total_cache_returned + model.cache.size() >= accounted_after_match, "match callback and compatibility request never lose eligible cached colors")
	_check(model.pending_cache_returns == model.cache.size() and _invariants_hold(model), "post-match feeder has one canonical eligible queue")

	var seven := ChainModel.new()
	var greens: Array[int] = []
	for unused in range(7):
		greens.append(TeamData.Identity.GREEN)
	seven.set_test_state(greens, 300.0)
	seven.add_test_segment(greens, 900.0, ChainModel.GapType.FEED)
	seven.advance(4.0)
	_check(seven.total_match_events == 0 and seven.identities().size() == 14, "natural seven-ball FEED reconnection remains noncausal")
	_check(seven.segment_gaps.is_empty() and _invariants_hold(seven), "virtual gravity closes the natural gap without overlap")

func _test_long_no_match_stream() -> void:
	var model := ChainModel.new()
	model.set_fresh_seed(0x160016)
	var max_live := model.balls.size()
	var max_offscreen := model.offscreen_right_count()
	for frame in range(120 * 60):
		model.advance(1.0 / 60.0)
		max_live = maxi(max_live, model.balls.size())
		max_offscreen = maxi(max_offscreen, model.offscreen_right_count())
		if frame % 600 == 0:
			_check(_invariants_hold(model), "two-minute no-match stream is valid at second %d" % (frame / 60))
	_check(model.total_match_events == 0 and model.total_exited > 0 and model.total_automatic_cache_returned > 0, "two-minute stream automatically recycles without matches")
	_check(model.total_exited == model.total_cache_returned + model.cache.size(), "two-minute exit/return/queue counters reconcile exactly")
	_check(model.total_fresh_generated > model.initial_population, "three-return/one-fresh scheduler preserves infinite fresh generation")
	_check(max_live <= model.max_auto_population and max_offscreen <= 1, "long stream keeps live and offscreen populations bounded")

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
	_check(model.total_exited > 0 and model.total_cache_returned > 0 and model.total_fresh_generated > model.initial_population, "active stream keeps exits, returns and fresh supply moving")
	_check(model.total_exited == model.total_cache_returned + model.cache.size(), "active-stream FIFO accounting has no duplicates or losses")
	_check(model.segment_gaps.is_empty() and _invariants_hold(model), "all unsupported groups reconnect after active stress settles")

func _test_terminal_freeze_and_restart() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var chain: ChainModel = main.get("_chain_model")
	chain.advance(20.0)
	_check(chain.total_exited > 0 and chain.total_cache_returned > 0, "main stream accumulates automatic recycle diagnostics")
	main.call("_on_game_over_requested", TeamData.Identity.RED)
	var frozen_time := chain.simulation_time
	var frozen_exited := chain.total_exited
	var frozen_returned := chain.total_cache_returned
	main.call("_process", 5.0)
	_check(chain.simulation_time == frozen_time and chain.total_exited == frozen_exited and chain.total_cache_returned == frozen_returned, "terminal defeat freezes spawning, exits and returns")
	main.call("_restart_run")
	_check(chain.total_exited == 0 and chain.total_cache_returned == 0 and chain.total_automatic_cache_returned == 0 and chain.pending_cache_returns == 0 and chain.cache.is_empty(), "restart clears FIFO queue and all recycle counters")
	_check(chain.balls.size() == chain.initial_population and is_equal_approx(chain.speed, 102.0), "restart restores the original seeded stream at 102 px/s")
	var battlefield: Battlefield = main.get("_battlefield")
	_check(battlefield.encounter_total() == 32 and battlefield.encounter_spawned() == 4, "restart preserves eight-per-lane finite encounter")
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P016 speed/automatic recycle: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P016 speed/automatic recycle: " + failure)
	print("P016 speed/automatic recycle: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
