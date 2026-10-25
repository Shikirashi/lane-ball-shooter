extends SceneTree

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	_test_bounded_seed()
	_test_three_ball_threshold()
	_test_large_group_single_event()
	_test_boundary_cascade_order()
	_test_fifo_rollover_and_partial_return()
	_test_empty_recovery()
	_test_continuous_identity_motion()
	_test_shot_contact_guard()
	_test_recycled_gap_adjacency()
	await _test_shot_pipeline()
	_finish()

func _test_bounded_seed() -> void:
	var model := ChainModel.new()
	_check(model.balls.size() == model.initial_population, "seed uses configured initial population")
	_check(model.balls.size() + model.cache.size() <= model.max_auto_population, "seed respects automatic population cap")
	for identity in range(TeamData.COUNT):
		_check(model.identities().has(identity), "seed includes team identity %d" % identity)
	var longest_run := 1
	var current_run := 1
	var seeded := model.identities()
	for index in range(1, seeded.size()):
		if seeded[index] == seeded[index - 1]:
			current_run += 1
			longest_run = maxi(longest_run, current_run)
		else:
			current_run = 1
	_check(longest_run >= 4, "seed intentionally demonstrates a passive same-color cluster")
	_check(model.total_match_events == 0, "seeded match-ready clusters do not clear without player insertion")

func _test_three_ball_threshold() -> void:
	var model := ChainModel.new()
	var reds: Array[int] = [TeamData.Identity.RED]
	var cached: Array[int] = [TeamData.Identity.GREEN]
	model.set_test_state(reds, 100.0, cached)
	model.try_insert_shot(TeamData.Identity.RED, 110.0)
	_check(model.identities() == [TeamData.Identity.RED, TeamData.Identity.RED], "two adjacent balls remain")
	_check(model.total_match_events == 0, "two adjacent balls emit no match")
	model.advance(0.2)
	model.try_insert_shot(TeamData.Identity.RED, float(model.balls[-1].display_x) + 10.0)
	model.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(model.total_match_events == 1, "inserted third emits one match")
	_check(model.last_match_identity == TeamData.Identity.RED and model.last_match_size == 3, "three-ball event reports identity and actual size")
	_check(model.identities() == [TeamData.Identity.GREEN], "match returns cached ball without fabricating survivors")

func _test_large_group_single_event() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.BLUE]
	var cached: Array[int] = [TeamData.Identity.YELLOW]
	model.set_test_state(identities, 100.0, cached)
	model.try_insert_shot(TeamData.Identity.BLUE, 226.0)
	model.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(model.total_match_events == 1, "four-ball group is one event")
	_check(model.event_log.size() == 1 and int(model.event_log[0].size) == 4, "large group reports four removed")

func _test_boundary_cascade_order() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [
		TeamData.Identity.GREEN,
		TeamData.Identity.GREEN,
		TeamData.Identity.RED,
		TeamData.Identity.RED,
		TeamData.Identity.GREEN,
		TeamData.Identity.BLUE,
		TeamData.Identity.BLUE,
		TeamData.Identity.BLUE,
	]
	model.set_test_state(identities)
	model.try_insert_shot(TeamData.Identity.RED, 284.0)
	model.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(model.event_log.size() == 1 and model.rollback_gaps.size() == 1, "insertion clears first group and starts one physical rollback")
	model.advance(1.0)
	_check(model.event_log.size() == 2, "physical reconnection produces a distinct delayed cascade event")
	if model.event_log.size() == 2:
		_check(int(model.event_log[0].identity) == TeamData.Identity.RED and int(model.event_log[0].size) == 3, "inserted red group resolves first")
		_check(int(model.event_log[1].identity) == TeamData.Identity.GREEN and int(model.event_log[1].size) == 3, "newly connected green group cascades second")
	_check(model.identities() == [TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.BLUE], "unrelated preexisting blue group remains")

func _test_fifo_rollover_and_partial_return() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [
		TeamData.Identity.RED,
		TeamData.Identity.GREEN,
		TeamData.Identity.BLUE,
		TeamData.Identity.YELLOW,
		TeamData.Identity.YELLOW,
	]
	model.set_test_state(identities, -190.0)
	model.advance(0.0)
	_check(model.cache == [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE], "left exits append RED, GREEN, BLUE to FIFO cache")
	model.return_cached(2)
	_check(model.cache == [TeamData.Identity.BLUE], "partial return consumes cache front")
	_check(model.identities().slice(-2) == [TeamData.Identity.RED, TeamData.Identity.GREEN], "partial return appends RED then GREEN on right")
	model.return_cached(1)
	_check(model.identities().slice(-3) == [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE], "fully restored subgroup preserves left-to-right order")

func _test_empty_recovery() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	model.set_test_state(identities, -220.0)
	model.advance(0.0)
	_check(model.identities() == identities and model.cache.is_empty(), "empty visible chain immediately re-enters from cache in FIFO order")
	var none: Array[int] = []
	model.set_test_state(none)
	model.advance(0.0)
	_check(model.balls.size() == model.initial_population, "empty model and cache reseed bounded stream")
	_check(model.balls.size() + model.cache.size() <= model.max_auto_population, "automatic reseed respects population cap")

func _test_continuous_identity_motion() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.GREEN]
	model.set_test_state(identities, 500.0)
	var before: Array[Dictionary] = model.balls.duplicate(true)
	model.advance(0.25)
	_check(model.balls.size() == before.size(), "sub-spacing movement does not replace balls")
	for index in range(before.size()):
		_check(int(model.balls[index].uid) == int(before[index].uid), "moving ball keeps stable uid at index %d" % index)
		_check(int(model.balls[index].identity) == int(before[index].identity), "moving ball keeps identity at index %d" % index)
		_check(is_equal_approx(float(model.balls[index].x), float(before[index].x) - model.speed * 0.25), "moving ball advances continuously at index %d" % index)

func _test_shot_contact_guard() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.BLUE, TeamData.Identity.GREEN]
	model.set_test_state(identities, 900.0)
	var before_ids := model.identities()
	var before_cache := model.cache.duplicate()
	_check(not model.try_insert_shot(TeamData.Identity.RED, 100.0), "far-left shot misses far-right train")
	_check(model.identities() == before_ids and model.cache == before_cache, "miss leaves chain and cache unchanged")
	_check(model.total_match_events == 0, "miss emits no match event")
	_check(model.try_insert_shot(TeamData.Identity.RED, 910.0), "shot within combined radii contacts a ball")
	_check(model.balls.size() == 3, "legitimate contact inserts exactly once")

	model.set_test_state(identities, 700.0)
	model.advance(0.5)
	var moving_contact_x := float(model.balls[0].display_x) + 8.0
	_check(model.try_insert_shot(TeamData.Identity.RED, moving_contact_x), "shot contacts train at its updated moving position")
	_check(model.balls.size() == 3, "moving-train contact inserts exactly once")

func _test_recycled_gap_adjacency() -> void:
	var model := ChainModel.new()
	var tail: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED]
	var cached: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	model.set_test_state(tail, 500.0, cached)
	model.return_cached(3)
	_check(model.identities().slice(-3) == cached, "recycled RED, GREEN, BLUE retain left-to-right FIFO order")
	var initial_gap := float(model.balls[2].x) - float(model.balls[1].x)
	_check(initial_gap > model.spacing * ChainModel.ADJACENCY_GAP_FACTOR, "returned batch starts physically disconnected at right boundary")
	_check(model.try_insert_shot(TeamData.Identity.RED, float(model.balls[2].display_x)), "shot can contact returned right-side segment")
	_check(model.total_match_events == 0, "same colors across recycled wide gap do not match")
	_check(model.identities().slice(0, 4) == [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.RED], "disconnected same-color runs remain ordered")

	model.advance(6.0)
	var connected_gap := float(model.balls[2].x) - float(model.balls[1].x)
	_check(is_equal_approx(connected_gap, model.spacing), "returned segment catches up without overlap or teleport")
	var rightmost_red_index := 3
	_check(model.try_insert_shot(TeamData.Identity.RED, float(model.balls[rightmost_red_index].display_x) + 8.0), "shot inserts after recycled segment reconnects")
	model.advance(ChainModel.INSERT_SETTLE_TIME)
	_check(model.total_match_events == 1 and model.last_match_size == 5, "reconnected physical run matches with true size")

func _test_shot_pipeline() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var model: ChainModel = main.get("_chain_model")
	var shooter: ShooterView = main.get("_shooter_view")
	var magazine: MagazineState = main.get("_magazine")
	var safe_chain: Array[int] = [TeamData.Identity.BLUE, TeamData.Identity.GREEN, TeamData.Identity.YELLOW]
	model.set_test_state(safe_chain, 1000.0)
	var before_count := model.balls.size()
	var fired_identity := magazine.loaded_identity
	var expected_loaded := magazine.next_identity
	main.call("_shoot")
	_check(magazine.loaded_identity == expected_loaded, "normal shot consumes magazine exactly once")
	_check(model.balls.size() == before_count, "shot does not insert before reaching lane")
	_check(shooter.get("_shots").size() == 1 and int(shooter.get("_shots")[0].identity) == fired_identity, "projectile locks fired identity")
	shooter._process(1.0)
	_check(shooter.get("_shots").is_empty(), "projectile is consumed at lane crossing")
	_check(model.balls.size() == before_count, "far shot misses without changing chain")
	_check(model.total_match_events == 0 and model.cache.is_empty(), "miss changes neither matches nor cache")
	_check(magazine.loaded_identity == expected_loaded, "miss does not refund or consume magazine twice")

	model.set_test_state(safe_chain, 860.0)
	main.set("_cooldown_remaining", 0.0)
	shooter.move_to(874.0)
	var near_fired_identity := magazine.loaded_identity
	var identity_count_before := model.identities().count(near_fired_identity)
	main.call("_shoot")
	shooter._process(1.0)
	_check(model.balls.size() == safe_chain.size() + 1, "contacting lane crossing inserts exactly one ball")
	_check(model.identities().count(near_fired_identity) == identity_count_before + 1, "contact insertion retains projectile identity")
	main.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("P002 gameplay logic: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P002 gameplay logic: " + failure)
	print("P002 gameplay logic: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
