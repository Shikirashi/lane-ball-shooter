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
	_test_combo_tiers_and_fever()
	_test_score_and_same_tick_events()
	_test_timeout_boundaries()
	_test_shuffle_bag()
	await _test_scene_integration()
	_finish()

func _test_combo_tiers_and_fever() -> void:
	var progression := MatchProgression.new()
	var expected_tiers: Array[int] = [1, 2, 3, 3, 3]
	for match_index in range(5):
		if match_index > 0:
			progression.update(2.0)
		var result := progression.register_match(match_index % TeamData.COUNT, 3)
		_check(int(result.combo_count) == match_index + 1, "timely match %d advances combo once" % (match_index + 1))
		_check(int(result.tier) == expected_tiers[match_index], "match %d has expected tier" % (match_index + 1))
		_check(bool(result.fever) == (match_index >= 3), "fever state is correct at match %d" % (match_index + 1))
	_check(progression.score == 500, "five 3-ball matches award 500 without multiplier")
	_check(progression.fever_active and progression.tier == 3, "fifth timely match sustains tier-3 fever")

func _test_score_and_same_tick_events() -> void:
	var progression := MatchProgression.new()
	var captured: Array[Dictionary] = []
	progression.match_resolved.connect(func(result: Dictionary) -> void: captured.append(result))
	var large := progression.register_match(TeamData.Identity.YELLOW, 7)
	_check(int(large.points) == 300 and progression.score == 300, "7-ball group awards configured 300 points")
	_check(progression.combo_count == 1 and progression.tier == 1, "large group advances combo only once")
	var formula := MatchProgression.new()
	var sizes: Array[int] = [3, 4, 5, 7]
	var expected_points: Array[int] = [100, 150, 200, 300]
	for index in range(sizes.size()):
		var scored := formula.register_match(TeamData.Identity.BLUE, sizes[index])
		_check(int(scored.points) == expected_points[index], "%d-ball group awards %d points" % [sizes[index], expected_points[index]])
	_check(formula.score == 750, "group-size points accumulate without combo multiplier")

	var chain := ChainModel.new()
	var cascade_progression := MatchProgression.new()
	var cascade_results: Array[Dictionary] = []
	chain.match_completed.connect(cascade_progression.register_match)
	cascade_progression.match_resolved.connect(func(result: Dictionary) -> void: cascade_results.append(result))
	var identities: Array[int] = [
		TeamData.Identity.GREEN,
		TeamData.Identity.GREEN,
		TeamData.Identity.RED,
		TeamData.Identity.RED,
		TeamData.Identity.GREEN,
		TeamData.Identity.BLUE,
	]
	chain.set_test_state(identities)
	chain.try_insert_shot(TeamData.Identity.RED, 284.0)
	_check(cascade_results.size() == 1, "inserted group resolves before physical cascade reconnection")
	chain.advance(1.0)
	_check(cascade_results.size() == 2, "delayed physical cascade produces a second result")
	_check(cascade_progression.combo_count == 2 and cascade_progression.tier == 2, "delayed cascade advances combo in emission order")
	_check(cascade_progression.score == 200, "two 3-ball cascade events award 200 total")
	if cascade_results.size() == 2:
		_check(int(cascade_results[0].identity) == TeamData.Identity.RED and int(cascade_results[0].combo_count) == 1, "inserted group result is locked first")
		_check(int(cascade_results[1].identity) == TeamData.Identity.GREEN and int(cascade_results[1].combo_count) == 2, "cascade result is locked second")
	_check(captured.size() == 1, "one large group emits one structured result")

func _test_timeout_boundaries() -> void:
	var near := MatchProgression.new()
	near.register_match(TeamData.Identity.RED, 3)
	near.update(2.999)
	_check(near.combo_count == 1 and near.window_ratio() > 0.0, "window remains active just before 3 seconds")
	var near_result := near.register_match(TeamData.Identity.BLUE, 3)
	_check(int(near_result.combo_count) == 2, "match just before boundary advances combo")

	var boundary := MatchProgression.new()
	for identity in range(TeamData.COUNT):
		boundary.register_match(identity, 3)
	_check(boundary.fever_active and boundary.combo_count == 4, "four same-tick matches enter fever before timeout")
	boundary.update(3.0)
	_check(boundary.combo_count == 0 and boundary.tier == 0 and not boundary.fever_active, "exactly 3.0 seconds expires combo and fever")
	_check(is_zero_approx(boundary.window_ratio()), "expired window bar is empty")
	_check(boundary.score == 400, "timeout preserves score")
	var restarted := boundary.register_match(TeamData.Identity.GREEN, 3)
	_check(int(restarted.combo_count) == 1 and int(restarted.tier) == 1, "post-timeout match restarts at tier 1")
	_check(boundary.score == 500, "post-timeout score continues accumulating")

func _test_shuffle_bag() -> void:
	var magazine := MagazineState.new(0xC0FFEE)
	var draws_before_swap := magazine.draw_count
	var bag_before_swap := magazine.bag_remaining()
	var loaded_before_swap := magazine.loaded_identity
	var next_before_swap := magazine.next_identity
	magazine.swap()
	_check(magazine.loaded_identity == next_before_swap and magazine.next_identity == loaded_before_swap, "swap exchanges visible slots")
	_check(magazine.draw_count == draws_before_swap and magazine.bag_remaining() == bag_before_swap, "swap neither draws nor mutates remaining bag")
	magazine.swap()

	while magazine.generated_history.size() < 12:
		var previous_next := magazine.next_identity
		var before_draws := magazine.draw_count
		magazine.consume_loaded()
		_check(magazine.loaded_identity == previous_next, "shot advances NEXT to LOADED")
		_check(magazine.draw_count == before_draws + 1, "shot draws exactly one replacement")
	for bag_index in range(3):
		var seen := {}
		for identity in magazine.generated_history.slice(bag_index * TeamData.COUNT, (bag_index + 1) * TeamData.COUNT):
			seen[int(identity)] = true
		_check(seen.size() == TeamData.COUNT, "shuffle bag %d contains each identity exactly once" % (bag_index + 1))

func _test_scene_integration() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var chain: ChainModel = main.get("_chain_model")
	var progression: MatchProgression = main.get("_progression")
	var hud: HudView = main.get("_hud_view")
	var shooter: ShooterView = main.get("_shooter_view")
	var magazine: MagazineState = main.get("_magazine")
	var chain_view: BallChainView = main.get("_chain_view")

	var safe: Array[int] = [TeamData.Identity.RED, TeamData.Identity.BLUE]
	chain.set_test_state(safe, 1000.0)
	var draws_before_miss := magazine.draw_count
	main.call("_shoot")
	shooter._process(1.0)
	_check(magazine.draw_count == draws_before_miss + 1, "miss still draws exactly one magazine replacement")
	_check(progression.score == 0 and progression.combo_count == 0, "miss awards no score or combo")

	var match_identity := magazine.loaded_identity
	var pair: Array[int] = [match_identity, match_identity]
	var cached: Array[int] = [(match_identity + 1) % TeamData.COUNT]
	var local_shooter_x := shooter.shooter_x - chain_view.position.x
	chain.set_test_state(pair, local_shooter_x, cached)
	main.set("_cooldown_remaining", 0.0)
	main.call("_shoot")
	shooter._process(1.0)
	_check(progression.score == 100 and progression.combo_count == 1 and progression.tier == 1, "genuine chain clear updates central progression")
	_check(hud.score == 100 and hud.combo_count == 1 and hud.tier == 1, "HUD receives live progression state")
	_check(is_equal_approx(hud.window_ratio, 1.0), "valid match refills HUD meter")

	var score_after_match := progression.score
	chain.advance(100.0)
	_check(progression.score == score_after_match, "cache rollover does not award score")
	chain.try_insert_shot(TeamData.Identity.RED, -500.0)
	_check(progression.score == score_after_match, "model-level miss does not alter progression")
	await process_frame
	await process_frame
	_check(progression.score == score_after_match, "render/process updates do not double-count match")

	progression.register_match(TeamData.Identity.BLUE, 3)
	progression.register_match(TeamData.Identity.YELLOW, 3)
	progression.register_match(TeamData.Identity.GREEN, 3)
	_check(hud.fever_active and hud.combo_count == 4 and hud.tier == 3, "fourth timely result drives distinct HUD fever state")
	main.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("P003 progression and magazine: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P003 progression and magazine: " + failure)
	print("P003 progression and magazine: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
