extends SceneTree

const EnemyTypesScript = preload("res://scripts/world/enemy_types.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	_test_generator_determinism_and_schema()
	_test_known_sequence_metrics()
	_test_default_guardrails()
	_test_fixed_x_shot_fidelity()
	await _test_time_to_danger()
	await _test_real_scenario_reproducibility()
	_finish()

func _test_generator_determinism_and_schema() -> void:
	var first := BalanceLab.sample_generator(28001, 240)
	var repeat := BalanceLab.sample_generator(28001, 240)
	var different := BalanceLab.sample_generator(28002, 240)
	_check(first == repeat, "same seed produces byte-equivalent generator statistics")
	_check(first.sequence_hash != different.sequence_hash, "different source seed changes the generated sequence")
	_check(first.has_all(["seed_tuple", "starting_preset_counts", "fresh_counts", "fresh_percent", "run_color_counts", "run_length_counts", "drought_balls", "window_max_spread"]), "generator sample exposes the stable P028A schema")
	_check(_sum(first.starting_preset_counts) == 12 and first.starting_preset_counts == [3, 3, 2, 4], "fixed starter preset is separate and conserved")
	_check(_sum(first.fresh_counts) == 240, "fresh color counts conserve exactly the requested generated balls")
	_check(_sum(first.fresh_ball_counts_by_run_length) == 240, "run-length ball shares count emitted balls exactly, including a partial final run")
	_check(first.run_color_counts.max() - first.run_color_counts.min() <= 1, "four-color run bag balances direct run-color selections")
	var sweep := BalanceLab.generator_sweep(28001, 3, 120)
	_check(sweep.seed_samples.size() == 3 and _sum(sweep.seed_samples[1].fresh_counts) == 120, "machine results retain bounded per-seed metrics without frame histories")

func _test_known_sequence_metrics() -> void:
	var all_red: Array[int] = []
	all_red.resize(25)
	all_red.fill(TeamData.Identity.RED)
	var metrics := BalanceLab.sequence_metrics(all_red)
	_check(metrics.drought_balls == [0, 25, 25, 25], "known all-red sequence reports exact per-color droughts")
	_check(int(metrics.window_max_spread["25"]) == 25, "known 25-ball window reports exact max color spread")
	var alternating: Array[int] = []
	for index in range(100):
		alternating.append(index % TeamData.COUNT)
	metrics = BalanceLab.sequence_metrics(alternating)
	_check(metrics.drought_balls == [3, 3, 3, 3], "balanced handcrafted sequence has a three-ball maximum absence")
	_check(int(metrics.window_max_spread["100"]) == 0, "balanced 100-ball window has zero spread")
	var chain := ChainModel.new()
	chain.set_test_state([TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.BLUE], 100.0)
	var groups := BalanceLab.visible_group_counts(chain)
	_check(groups.pairs == [2, 1, 0, 0] and groups.groups3 == [1, 0, 0, 0], "visible geometry distinguishes adjacent pairs from pre-existing 3+ groups")

func _test_default_guardrails() -> void:
	_check(ChainModel.DEFAULT_SPEED == 102.0 and ChainModel.FRESH_RUN_LENGTH_WEIGHTS == BalanceLab.BASELINE_WEIGHTS, "production speed and run weights remain authoritative")
	var untouched := ChainModel.new()
	_check(untouched.speed == 102.0 and untouched.fresh_run_length_weights == ChainModel.FRESH_RUN_LENGTH_WEIGHTS, "ordinary production instance retains exact defaults")
	var reference := ChainModel.new()
	var injected := ChainModel.new()
	reference.set_fresh_seed(99117)
	injected.set_fresh_seed(99117)
	_check(injected.set_analysis_fresh_run_length_weights(BalanceLab.BASELINE_WEIGHTS), "analysis seam accepts a valid per-instance distribution")
	var reference_sequence: Array[int] = []
	var injected_sequence: Array[int] = []
	for unused in range(300):
		reference_sequence.append(reference._draw_fresh_identity())
		injected_sequence.append(injected._draw_fresh_identity())
	_check(reference_sequence == injected_sequence, "baseline injection preserves exact production RNG sequence")
	_check(not untouched.set_analysis_fresh_run_length_weights([1, 2, 3]), "invalid analysis weights fail without mutating production defaults")
	var empty_opportunities: Array[Array] = [[], [], [], []]
	var magazine := MagazineState.new(17)
	_check(BalanceLab.choose_action("basic_matcher", magazine, empty_opportunities, [1.0, 1.0, 1.0, 1.0]).is_empty(), "policy cannot invent a match action without real geometry")

func _test_fixed_x_shot_fidelity() -> void:
	var moving := ChainModel.new()
	moving.set_test_state([TeamData.Identity.RED], 200.0)
	moving.speed = 240.0
	var target_uid := int(moving.balls[0].uid)
	var pending := {"identity": TeamData.Identity.RED, "target_uid": target_uid, "shot_x": 199.0, "remaining": BalanceLab.SHOT_FLIGHT_TIME}
	var event := BalanceLab.advance_chain_with_fixed_shot(moving, pending, 0.20)
	_check(bool(event.arrived) and absf(float(event.impact_time) - 0.20) < 0.0001, "fixed shot impacts after the full 0.20-second chain movement")
	_check(float(event.shot_x) == 199.0 and absf(float(event.target_drift) + 47.0) < 0.001, "launch X remains immutable while the originally aimed ball moves away")
	_check(not bool(event.inserted) and not bool(event.original_target_contact) and moving.balls.size() == 1, "moving target genuinely misses instead of receiving the former UID-homing insertion")
	_check(moving.event_log.is_empty(), "a realistic miss creates no match event or free attack input")

	var replacement := ChainModel.new()
	replacement.set_test_state([TeamData.Identity.BLUE], 200.0)
	replacement.speed = 0.0
	pending = {"identity": TeamData.Identity.BLUE, "target_uid": 999999, "shot_x": 200.0, "remaining": 0.20}
	event = BalanceLab.advance_chain_with_fixed_shot(replacement, pending, 0.20)
	_check(bool(event.target_gone) and bool(event.inserted), "collision uses actual geometry at fixed X even when the reporting target UID is gone")

	var coarse := ChainModel.new()
	coarse.set_test_state([TeamData.Identity.YELLOW], 200.0)
	coarse.speed = 240.0
	var coarse_pending := {"identity": TeamData.Identity.YELLOW, "target_uid": int(coarse.balls[0].uid), "shot_x": 199.0, "remaining": 0.20}
	var coarse_event := BalanceLab.advance_chain_with_fixed_shot(coarse, coarse_pending, 0.20)
	var fine := ChainModel.new()
	fine.set_test_state([TeamData.Identity.YELLOW], 200.0)
	fine.speed = 240.0
	var fine_pending := {"identity": TeamData.Identity.YELLOW, "target_uid": int(fine.balls[0].uid), "shot_x": 199.0, "remaining": 0.20}
	var fine_event: Dictionary
	for unused in range(4):
		fine_event = BalanceLab.advance_chain_with_fixed_shot(fine, fine_pending, 0.05)
	_check(bool(coarse_event.arrived) and bool(fine_event.arrived) and not bool(coarse_event.inserted) and not bool(fine_event.inserted), "coarse and fine steps preserve the same fixed-X miss")
	_check(absf(coarse.simulation_time - 0.20) < 0.0001 and absf(fine.simulation_time - 0.20) < 0.0001 and absf(float(coarse.balls[0].x) - float(fine.balls[0].x)) < 0.001, "flight arrival and chain position remain step-invariant")

func _test_time_to_danger() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.clear_for_test()
	battlefield.lanes[0].combat_model.spawn_enemy(LaneCombatModel.DEFENDER_X + LaneCombatModel.DEFAULT_ENEMY_SPEED * 5.0, -1, false, EnemyTypesScript.Type.HOPPER, 101)
	var snake_uid := battlefield.lanes[1].combat_model.spawn_enemy(LaneCombatModel.DEFENDER_X + EnemyTypesScript.speed(EnemyTypesScript.Type.SICKLE_SNAKE, LaneCombatModel.DEFAULT_ENEMY_SPEED) * 4.0, -1, false, EnemyTypesScript.Type.SICKLE_SNAKE, 102)
	for index in range(battlefield.lanes[1].combat_model.enemies.size()):
		if int(battlefield.lanes[1].combat_model.enemies[index].uid) == snake_uid:
			battlefield.lanes[1].combat_model.enemies[index].special_state = &"stunned"
			battlefield.lanes[1].combat_model.enemies[index].special_timer = 0.5
	battlefield.lanes[2].combat_model.spawn_enemy(0.0, -1, false, EnemyTypesScript.Type.HEALYZARD, 103)
	var times := BalanceLab.lane_time_to_danger(battlefield)
	_check(absf(times[0] - 5.0) < 0.001, "Hopper time-to-danger uses authoritative average movement")
	_check(absf(times[1] - 4.5) < 0.001, "Snake time-to-danger includes current stun delay")
	_check(is_inf(times[2]), "stationary Healyzard has no direct defender-arrival time")
	battlefield.queue_free()
	await process_frame

func _test_real_scenario_reproducibility() -> void:
	var first: Dictionary = await BalanceLab.run_scenario(self, 28111, 8.0, 0.1, "basic_matcher")
	var repeat: Dictionary = await BalanceLab.run_scenario(self, 28111, 8.0, 0.1, "basic_matcher")
	var different: Dictionary = await BalanceLab.run_scenario(self, 28112, 8.0, 0.1, "basic_matcher")
	_check(first == repeat, "real chain/magazine/combat scenario is identical for the same seed tuple")
	_check(first.fresh_counts != different.fresh_counts or first.magazine_generated_counts != different.magazine_generated_counts, "real scenario has deterministic diversity across seeds")
	_check(_sum(first.fresh_counts) == int(first.fresh_generated), "scenario fresh-color accounting conserves generator output")
	_check(_sum(first.fired_counts) == int(first.counts.shots) and int(first.counts.insertions) + int(first.counts.shot_misses) <= int(first.counts.shots), "fired, inserted and missed ammunition definitions remain distinct and conserved")
	_check(first.starting_preset_counts == [3, 3, 2, 4] and first.visible_mean.size() == 4 and first.left_clipped_mean.size() == 4 and first.right_clipped_mean.size() == 4, "scenario schema separates starter, visible, off-left and off-right layers")
	_check(first.loaded_fraction.size() == 4 and first.next_fraction.size() == 4 and first.visible_adjacent_pair_mean.size() == 4 and first.visible_preexisting_group3_fraction.size() == 4, "scenario schema separates loaded/next ammo and pair/pre-existing-group geometry")
	var fine_step: Dictionary = await BalanceLab.run_scenario(self, 28111, 8.0, 0.05, "basic_matcher")
	_check(absf(float(first.minimum_flight_time) - 0.20) < 0.0001 and absf(float(first.maximum_flight_time) - 0.20) < 0.0001 and absf(float(fine_step.minimum_flight_time) - 0.20) < 0.0001 and absf(float(fine_step.maximum_flight_time) - 0.20) < 0.0001, "0.20-second fixed-X flight survives 0.10 and 0.05 outer steps")
	_check(float(first.minimum_shot_interval) >= BalanceLab.SHOT_COOLDOWN - 0.0001 and float(fine_step.minimum_shot_interval) >= BalanceLab.SHOT_COOLDOWN - 0.0001, "0.4-second cooldown survives different outer steps")
	var observed: Dictionary = await BalanceLab.run_scenario(self, 28113, 8.0, 0.1, "observe_only")
	_check(int(observed.counts.shots) == 0 and int(observed.counts.matches) == 0 and _sum(observed.fired_counts) == 0, "observe-only policy creates no fake shots, matches or attacks")

func _sum(values: Array) -> int:
	var total := 0
	for value in values:
		total += int(value)
	return total

func _finish() -> void:
	if _failures.is_empty():
		print("P028A balance lab: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P028A balance lab: " + failure)
	print("P028A balance lab: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
