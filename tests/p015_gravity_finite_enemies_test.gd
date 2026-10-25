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
	_test_noncausal_gravity_closure()
	_test_causal_gravity_and_cascade()
	_test_multiple_gaps_feed_and_restart()
	_test_source_attachment_and_frame_rates()
	_test_lane_spawn_budget_and_neutralization()
	await _test_battlefield_victory_and_defeat_precedence()
	await _test_main_victory_freeze_and_restart()
	_finish()

func _position(model: ChainModel, uid: int) -> float:
	var index := model._ball_index_by_uid(uid)
	return float(model.balls[index].x) if index >= 0 else NAN

func _invariants_hold(model: ChainModel) -> bool:
	if model.invariant_violations != 0 or model.segment_gaps.size() != maxi(0, model.segments.size() - 1):
		return false
	var prior := -INF
	for segment_index in range(model.segments.size()):
		var segment: Dictionary = model.segments[segment_index]
		if segment_index < model.segment_gaps.size():
			var gap: Dictionary = model.segment_gaps[segment_index]
			if int(gap.left_segment_id) != int(segment.id) or int(gap.right_segment_id) != int(model.segments[segment_index + 1].id):
				return false
		for local_index in range((segment.members as Array).size()):
			var x := float(segment.anchor_x) + local_index * model.spacing
			if prior > -INF and x - prior < model.radius * 2.0 - 0.01:
				return false
			if local_index > 0 and absf(x - prior - model.spacing) > 0.001:
				return false
			prior = x
	return true

func _advance_until_joined(model: ChainModel, limit := 4.0) -> float:
	var elapsed := 0.0
	while not model.segment_gaps.is_empty() and elapsed < limit:
		model.advance(1.0 / 120.0)
		_check(_invariants_hold(model), "gravity microstep %.3f preserves rigid non-overlap" % elapsed)
		elapsed += 1.0 / 120.0
	return elapsed

func _test_noncausal_gravity_closure() -> void:
	var model := ChainModel.new()
	var left: Array[int] = [TeamData.Identity.YELLOW, TeamData.Identity.YELLOW]
	var right: Array[int] = [TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW]
	model.set_test_state(left, 300.0)
	model.add_test_segment(right, 820.0, ChainModel.GapType.FEED)
	var left_uids := [int(model.balls[0].uid), int(model.balls[1].uid)]
	var right_uid := int(model.balls[2].uid)
	var left_before := [_position(model, left_uids[0]), _position(model, left_uids[1])]
	var right_before := _position(model, right_uid)
	model.advance(0.1)
	var left_delta_a := _position(model, left_uids[0]) - float(left_before[0])
	var left_delta_b := _position(model, left_uids[1]) - float(left_before[1])
	_check(left_delta_a > 0.0 and absf(left_delta_a - left_delta_b) < 0.001, "unsupported FEED-side yellows fall RIGHT as one rigid segment")
	_check(absf(_position(model, right_uid) - right_before + model.speed * 0.1) < 0.002, "rightmost pusher train moves LEFT at 102 px/s")
	_check(model.unsupported_segment_count == 1 and model.gravity_gap_count == 1 and model.max_gravity_speed > ChainModel.GRAVITY_INITIAL_RIGHT_SPEED, "support diagnostics expose one accelerating unsupported segment")
	var joined_at := 0.1 + _advance_until_joined(model, 3.0)
	_check(model.segment_gaps.is_empty() and model.segments.size() == 1 and joined_at < 3.1, "formerly persistent noncausal yellow gap physically closes")
	_check(model.total_match_events == 0 and model.identities().size() == 7, "noncausal same-color reconnection never auto-matches seven yellows")

func _setup_middle(rear_identity: int) -> ChainModel:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, rear_identity, rear_identity]
	model.set_test_state(identities, 300.0)
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].x) + 1.0)
	return model

func _test_causal_gravity_and_cascade() -> void:
	var ordinary := _setup_middle(TeamData.Identity.BLUE)
	var front_uids := [int(ordinary.balls[0].uid), int(ordinary.balls[1].uid)]
	var rear_uids := [int(ordinary.balls[5].uid), int(ordinary.balls[6].uid)]
	ordinary.advance(0.049)
	_check(ordinary.event_log.is_empty() and ordinary.segment_gaps.is_empty(), "initial match waits through 49ms settlement")
	ordinary.advance(0.001)
	_check(ordinary.event_log.size() == 1 and int(ordinary.event_log[0].identity) == TeamData.Identity.YELLOW, "yellow x3 removes at exactly 50ms")
	var front_before := [_position(ordinary, front_uids[0]), _position(ordinary, front_uids[1])]
	var rear_before := [_position(ordinary, rear_uids[0]), _position(ordinary, rear_uids[1])]
	ordinary.advance(0.1)
	_check(_position(ordinary, front_uids[0]) > float(front_before[0]) and absf((_position(ordinary, front_uids[0]) - float(front_before[0])) - (_position(ordinary, front_uids[1]) - float(front_before[1]))) < 0.001, "causal front reds fall RIGHT rigidly")
	_check(absf(_position(ordinary, rear_uids[0]) - float(rear_before[0]) + ordinary.speed * 0.1) < 0.002 and absf(_position(ordinary, rear_uids[1]) - float(rear_before[1]) + ordinary.speed * 0.1) < 0.002, "causal rear blues remain source-pushed at -102 px/s")
	_advance_until_joined(ordinary)
	_check(ordinary.total_match_events == 1 and ordinary.identities() == [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.BLUE], "different-color authorized contact joins without cascade")

	var cascade := _setup_middle(TeamData.Identity.RED)
	var progression := MatchProgression.new()
	cascade.match_completed.connect(progression.register_match)
	cascade.advance(0.05)
	var yellow_time := float(cascade.event_log[0].time)
	while cascade.event_log.size() < 2 and cascade.simulation_time < 3.0:
		cascade.advance(1.0 / 120.0)
	_check(cascade.event_log.size() == 2 and int(cascade.event_log[0].identity) == TeamData.Identity.YELLOW and int(cascade.event_log[1].identity) == TeamData.Identity.RED, "authorized cascade preserves yellow then red event order")
	_check(int(cascade.event_log[1].size) == 4 and float(cascade.event_log[1].time) > yellow_time, "red x4 waits for later physical contact")
	_check(progression.score == 250 and progression.combo_count == 2, "yellow x3 plus red x4 awards 100+150 and two combo steps")

func _test_multiple_gaps_feed_and_restart() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.GREEN, TeamData.Identity.GREEN, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.RED]
	var entrants: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	model.set_test_state(identities, 180.0)
	model.try_insert_shot(TeamData.Identity.BLUE, float(model.balls[3].x) + 1.0)
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[7].x) + 1.0)
	model.advance(0.05)
	model.add_test_segment(entrants, model.entry_spawn_x(), ChainModel.GapType.FEED)
	_check(model.identities().slice(-3) == entrants, "separated fresh batch enters in RED GREEN BLUE order")
	_check(model.segment_gaps.size() >= 3 and model.gap_type_counts().causal == 2 and model.gap_type_counts().feed == 1, "rapid matches and fresh feed coexist as causal/noncausal metadata")
	var first_uid := int(model.balls[0].uid)
	var before_insert := _position(model, first_uid)
	model.try_insert_shot(TeamData.Identity.GREEN, float(model.balls[2].x) + 1.0)
	_check(absf(_position(model, first_uid) - before_insert + model.spacing) < 0.001, "insertion while unsupported still pushes preceding prefix LEFT")
	var elapsed := _advance_until_joined(model, 6.0)
	_check(model.segment_gaps.is_empty() and elapsed < 6.0 and _invariants_hold(model), "all concurrent gravity gaps eventually close without overlap")

	var restart := ChainModel.new()
	var a: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED]
	var b: Array[int] = [TeamData.Identity.BLUE, TeamData.Identity.BLUE]
	restart.set_test_state(a, 200.0)
	restart.add_test_segment(b, 700.0, ChainModel.GapType.FEED)
	restart.advance(0.2)
	_check(restart.unsupported_segment_count == 1 and float(restart.segments[0].gravity_speed) > 0.0, "restart fixture begins mid-fall")
	restart.reset_run()
	_check(restart.segment_gaps.is_empty() and restart.unsupported_segment_count == 0 and restart.segment_motion_log.is_empty(), "restart clears gaps, velocity diagnostics and transient gravity state")

func _gravity_join_time(step: float) -> float:
	var model := ChainModel.new()
	var left: Array[int] = [TeamData.Identity.RED, TeamData.Identity.BLUE]
	var right: Array[int] = [TeamData.Identity.GREEN, TeamData.Identity.YELLOW]
	model.set_test_state(left, 250.0)
	model.add_test_segment(right, 720.0, ChainModel.GapType.FEED)
	while not model.segment_gaps.is_empty() and model.simulation_time < 3.0:
		model.advance(step)
	return model.simulation_time

func _test_source_attachment_and_frame_rates() -> void:
	var baseline := _gravity_join_time(1.0 / 120.0)
	for step in [1.0 / 60.0, 1.0 / 30.0, 0.08]:
		var sample := _gravity_join_time(step)
		_check(absf(sample - baseline) <= maxf(step, 1.0 / 60.0) + 0.02, "gravity contact time is stable for %.4fs updates" % step)

	var stream := ChainModel.new()
	stream.set_lane_width(900.0)
	stream.reset_run()
	var max_active := stream.active_population_count()
	for frame in range(7200):
		stream.advance(1.0 / 120.0)
		max_active = maxi(max_active, stream.active_population_count())
		if frame % 120 == 0:
			_check(_invariants_hold(stream), "60s source stream remains valid at second %d" % (frame / 120))
	_check(stream.total_fresh_generated > stream.initial_population and max_active <= stream.max_auto_population and stream.offscreen_left_count() > 0, "right source remains infinite while active population is bounded")
	_check(stream.offscreen_right_count() <= 1, "source attachment does not build an offscreen tail")

func _test_lane_spawn_budget_and_neutralization() -> void:
	var reset_model := LaneCombatModel.new(TeamData.Identity.RED)
	reset_model.reset_run(3.0, 0.1)
	_check(reset_model.enemy_spawn_budget == 8 and reset_model.spawned_this_encounter == 1 and reset_model.remaining_to_spawn() == 7, "initial enemy consumes one of eight lane slots")

	var budget := LaneCombatModel.new(TeamData.Identity.BLUE)
	budget.clear_for_test()
	budget.spawn_interval = 0.01
	budget.spawn_timer = 0.0
	for unused in range(5):
		budget.spawn_enemy()
	budget.auto_spawn = true
	budget.update(1.0)
	_check(budget.active_enemy_count() == 5 and budget.spawned_this_encounter == 5 and budget.remaining_to_spawn() == 3, "saturated lane defers three quota slots without consuming them")
	budget.clear_enemies_for_tier3()
	budget.update(1.0)
	_check(budget.spawned_this_encounter == 8 and budget.active_enemy_count() == 3 and budget.encounter_spawn_complete(), "lane emits exactly the remaining three after capacity opens")
	budget.clear_enemies_for_tier3()
	budget.update(600.0)
	_check(budget.total_spawned == 8 and budget.active_enemy_count() == 0 and budget.encounter_cleared(), "spent lane budget never produces a ninth enemy over ten simulated minutes")

	var tier_one := LaneCombatModel.new(TeamData.Identity.RED)
	tier_one.clear_for_test()
	var uid := tier_one.spawn_enemy(-2.0, 2)
	tier_one._damage_enemy(uid, 1, -2.0)
	tier_one._damage_enemy(uid, 1, -2.0)
	_check(tier_one.total_killed == 1 and tier_one.total_neutralized() == 1, "tier-1 two-hit kill counts one neutralization")
	var tier_two := LaneCombatModel.new(TeamData.Identity.BLUE)
	tier_two.clear_for_test()
	uid = tier_two.spawn_enemy(-2.0, 2)
	tier_two._damage_enemy(uid, 2, -2.0)
	_check(tier_two.total_killed == 1, "tier-2 two-damage hit counts one neutralization")
	var emergency := LaneCombatModel.new(TeamData.Identity.GREEN)
	emergency.clear_for_test()
	emergency.spawn_enemy(1.0, 2)
	emergency.spawn_enemy(2.0, 2)
	emergency._discharge_emergency()
	_check(emergency.total_emergency_cleared == 2 and emergency.total_neutralized() == 2, "emergency clear counts every removed enemy without replenishing quota")
	var tier_three := LaneCombatModel.new(TeamData.Identity.YELLOW)
	tier_three.clear_for_test()
	tier_three.spawn_enemy(1.0, 2)
	tier_three.spawn_enemy(2.0, 2)
	_check(tier_three.clear_enemies_for_tier3() == 2 and tier_three.total_killed == 2, "tier-3 lane clear counts both neutralizations")

func _configure_small_encounter(battlefield: Battlefield, budget: int) -> void:
	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(budget)

func _test_battlefield_victory_and_defeat_precedence() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	battlefield.set_process(false)
	_configure_small_encounter(battlefield, 2)
	var wins := {"count": 0}
	battlefield.encounter_cleared.connect(func() -> void: wins.count += 1)
	battlefield.call("_evaluate_terminal_state")
	_check(not battlefield.victory and battlefield.encounter_live() == 0 and battlefield.encounter_spawned() == 0, "temporarily empty battlefield with pending quotas does not win")
	for lane in battlefield.lanes:
		lane.combat_model.spawn_enemy(1.0, 2)
		lane.combat_model.spawn_enemy(2.0, 2)
	_check(battlefield.encounter_total() == 8 and battlefield.encounter_spawned() == 8, "configured two-per-lane encounter schedules exactly eight")
	for lane_index in range(battlefield.lanes.size()):
		battlefield.lanes[lane_index].combat_model.clear_enemies_for_tier3()
	_check(battlefield.victory and not battlefield.game_over and int(wins.count) == 1, "quota exhaustion plus zero live enemies emits exactly one victory")
	battlefield.call("_evaluate_terminal_state")
	_check(int(wins.count) == 1 and battlefield.encounter_neutralized() == 8, "victory is idempotent with correct neutralized total")
	battlefield.queue_free()
	await process_frame

	var defeat := Battlefield.new()
	root.add_child(defeat)
	await process_frame
	defeat.set_process(false)
	_configure_small_encounter(defeat, 1)
	for lane_index in range(1, defeat.lanes.size()):
		defeat.lanes[lane_index].combat_model.spawn_enemy(1.0, 1)
		defeat.lanes[lane_index].combat_model.clear_enemies_for_tier3()
	var breach_lane := defeat.lanes[0].combat_model
	breach_lane.defender_state = LaneCombatModel.DefenderState.DOWN
	breach_lane.emergency_available = false
	breach_lane.spawn_enemy(LaneCombatModel.LEFT_BOUNDARY - 0.01, 2)
	defeat.call("_evaluate_terminal_state")
	_check(defeat.game_over and not defeat.victory, "terminal breach takes precedence over otherwise completed quotas")
	defeat.queue_free()
	await process_frame

func _test_main_victory_freeze_and_restart() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var battlefield: Battlefield = main.get("_battlefield")
	var chain: ChainModel = main.get("_chain_model")
	var progression: MatchProgression = main.get("_progression")
	var overlay: GameOverOverlay = main.get("_game_over_overlay")
	var hud: HudView = main.get("_hud_view")
	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()
	_check(not bool(main.get("_game_over")) and not battlefield.victory, "empty lanes with unspent default budgets keep encounter active")
	var before_x := float(chain.balls[0].x)
	main.call("_process", 0.5)
	_check(float(chain.balls[0].x) != before_x, "infinite ball conveyor remains active while enemy spawns are pending")
	progression.register_match(TeamData.Identity.RED, 3)
	for lane in battlefield.lanes:
		lane.combat_model.spawned_this_encounter = lane.combat_model.enemy_spawn_budget
		lane.combat_model.total_spawned = lane.combat_model.enemy_spawn_budget
		lane.combat_model.total_killed = lane.combat_model.enemy_spawn_budget
		lane.combat_model.enemies.clear()
	battlefield.call("_evaluate_terminal_state")
	_check(bool(main.get("_game_over")) and bool(main.get("_victory")) and battlefield.victory, "real battlefield completion routes one terminal victory to Main")
	_check(overlay.visible and overlay.victory and overlay.final_score == progression.score, "WAVE CLEARED overlay preserves final score")
	_check(hud.enemies_total == 32 and hud.enemies_remaining == 0, "HUD reports complete 32-enemy objective")
	var frozen_x := float(chain.balls[0].x)
	main.call("_process", 1.0)
	main.call("_shoot")
	_check(absf(float(chain.balls[0].x) - frozen_x) < 0.001 and main.get("_shooter_view").get("_shots").is_empty(), "victory freezes chain and shooting")
	main.call("_restart_run")
	_check(not bool(main.get("_game_over")) and not bool(main.get("_victory")) and not overlay.visible, "R/restart clears terminal victory state")
	_check(progression.score == 0 and chain.cache.is_empty(), "restart clears score and FIFO state")
	for lane in battlefield.lanes:
		_check(lane.combat_model.enemy_spawn_budget == 8 and lane.combat_model.spawned_this_encounter == 1 and lane.combat_model.active_enemy_count() == 1, "restart restores lane %d to one-of-eight initial state" % lane.team_identity)
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P015 gravity/finite enemies: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P015 gravity/finite enemies: " + failure)
	print("P015 gravity/finite enemies: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
