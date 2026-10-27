extends SceneTree

const ThreatRunSelectorScript = preload("res://scripts/analysis/threat_run_selector.gd")
const ThreatBiasLabScript = preload("res://scripts/analysis/threat_bias_lab.gd")
const EnemyTypes = preload("res://scripts/world/enemy_types.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_baseline_equivalence_and_bags()
	_test_controlled_sampler()
	_test_conservation_and_fixed_shot()
	await _test_live_danger()
	_finish()

func _test_baseline_equivalence_and_bags() -> void:
	var reference := ChainModel.new()
	var observed := ChainModel.new()
	reference.set_fresh_seed(280281)
	observed.set_fresh_seed(280281)
	var baseline_controller = ThreatRunSelectorScript.new("baseline", 91)
	observed.set_analysis_fresh_run_callbacks(Callable(), Callable(baseline_controller, "observe"))
	var reference_sequence: Array[int] = []
	var observed_sequence: Array[int] = []
	for unused in range(420):
		reference_sequence.append(reference._draw_fresh_identity())
		observed_sequence.append(observed._draw_fresh_identity())
	_check(reference_sequence == observed_sequence, "disabled selector preserves the exact 420-ball production sequence")

	var first := ThreatBiasLabScript.synthetic_sample(29001, 360, "moderate", "rotating")
	var repeat := ThreatBiasLabScript.synthetic_sample(29001, 360, "moderate", "rotating")
	var different := ThreatBiasLabScript.synthetic_sample(29002, 360, "moderate", "rotating")
	_check(first == repeat, "same paired seed and arm are deterministic")
	_check(first.sequence_hash != different.sequence_hash, "different source seeds retain diversity")
	_check(first.bag_violations == 0, "every complete adaptive run bag contains all four colors exactly once")
	_check(first.repeat_violations == 0, "adaptive order never immediately repeats a run color")
	_check(BalanceLab._sum_ints(first.ball_counts) == 360, "fresh adaptive ball counts are conserved")
	_check(BalanceLab._sum_ints(first.run_counts) == first.runs, "run-color counts are conserved")

	var baseline_none := ThreatBiasLabScript.synthetic_sample(29003, 400, "baseline", "no_threat")
	for arm in ["mild", "moderate", "strong"]:
		var adaptive_none := ThreatBiasLabScript.synthetic_sample(29003, 400, arm, "no_threat")
		_check(adaptive_none.sequence_hash == baseline_none.sequence_hash, "%s no-threat sequence is byte-for-byte baseline-equivalent" % arm)
	var baseline_rotating := ThreatBiasLabScript.synthetic_sample(29004, 400, "baseline", "rotating")
	for arm in ["mild", "moderate", "strong"]:
		var adaptive_rotating := ThreatBiasLabScript.synthetic_sample(29004, 400, arm, "rotating")
		_check(adaptive_rotating.run_lengths == baseline_rotating.run_lengths, "%s changes run-color order without changing the paired run-length sequence" % arm)

func _test_controlled_sampler() -> void:
	var rates := []
	for arm in ["baseline", "mild", "moderate", "strong"]:
		var chosen := 0
		for seed_value in range(30000, 30500):
			var sample := ThreatBiasLabScript.synthetic_sample(seed_value, 80, arm, "single_urgent")
			chosen += int(sample.selector.urgent_selected)
		rates.append(chosen)
	_check(rates[0] < rates[1] and rates[1] < rates[2] and rates[2] < rates[3], "urgent selection response increases monotonically across baseline/mild/moderate/strong")

	var controller = ThreatRunSelectorScript.new("strong", 7001)
	controller.set_threat_snapshot([2.0, INF, INF, INF])
	var choice := controller.choose([1, 2, 3], 0, 0.0, 3)
	_check([1, 2, 3].has(choice), "selector cannot choose an urgent color absent from the partial bag")
	controller.observe({"time": 0.0, "legal": [1, 2, 3], "previous": 0, "baseline_choice": 3, "chosen": choice})
	_check(controller.urgent_unavailable_count == 1, "urgent-but-exhausted bag state is recorded instead of bypassed")

	controller = ThreatRunSelectorScript.new("moderate", 7002)
	controller.set_threat_snapshot([5.0, 8.0, INF, INF])
	choice = controller.choose([0, 1, 2, 3], -1, 0.0, 3)
	_check([0, 1, 2, 3].has(choice), "multiple-threat weighted selection remains legal")
	_check(controller.urgency_for_ttd(5.0) > controller.urgency_for_ttd(8.0), "closer live danger has greater urgency")

	var no_threat_a = ThreatRunSelectorScript.new("strong", 11)
	var no_threat_b = ThreatRunSelectorScript.new("strong", 999999)
	no_threat_a.set_threat_snapshot([INF, INF, INF, INF])
	no_threat_b.set_threat_snapshot([INF, INF, INF, INF])
	_check(no_threat_a.choose([0, 1, 2], -1, 0.0, 2) == 2 and no_threat_b.choose([0, 1, 2], -1, 0.0, 2) == 2, "unrelated bias RNG streams cannot perturb no-threat baseline choice")

func _test_conservation_and_fixed_shot() -> void:
	var chain := ChainModel.new()
	var starter_count := chain.balls.size()
	chain.advance(3.0)
	_check(starter_count == ChainModel.DEFAULT_INITIAL_POPULATION, "fixed starter remains separate from adaptive fresh generation")
	_check(chain.total_fresh_generated == starter_count + BalanceLab._sum_ints(chain.fresh_identity_counts), "starter plus fresh generation accounting remains conserved")
	_check(chain.cache.is_empty() and chain.total_cache_returned == 0, "adaptive seam does not reintroduce FIFO cache returns")

	var moving := ChainModel.new()
	moving.set_test_state([TeamData.Identity.RED], 200.0)
	moving.speed = 240.0
	var pending := {"identity": TeamData.Identity.RED, "target_uid": int(moving.balls[0].uid), "shot_x": 199.0, "remaining": 0.20}
	var event := BalanceLab.advance_chain_with_fixed_shot(moving, pending, 0.20)
	_check(float(event.shot_x) == 199.0 and not bool(event.inserted), "threat experiment retains immutable fixed-X flight and genuine misses")
	_check(ChainModel.DEFAULT_SPEED == 102.0, "production conveyor speed remains 102 px/s")
	_check(ChainModel.FRESH_RUN_LENGTH_WEIGHTS == [20, 30, 18, 13, 9, 6, 4], "production run-length weights remain unchanged")
	_check(EnemyTypes.MAX_HP[EnemyTypes.Type.HOPPER] == 3 and EnemyTypes.MAX_HP[EnemyTypes.Type.HEAVY] == 6 and EnemyTypes.MAX_HP[EnemyTypes.Type.SICKLE_SNAKE] == 3 and EnemyTypes.MAX_HP[EnemyTypes.Type.HEALYZARD] == 3, "production enemy HP remains 3/6/3/3")

func _test_live_danger() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.enemies.clear()
	var before := BalanceLab.lane_time_to_danger(battlefield)
	_check(is_inf(before[0]), "empty live lane has no direct threat")
	battlefield.spawn_directed_enemy(0, EnemyTypes.Type.HOPPER, 1.6, -1, false)
	var active := BalanceLab.lane_time_to_danger(battlefield)
	_check(active[0] < INF and active[0] > 0.0, "selector input responds to current authoritative Battlefield enemy state")
	battlefield.lanes[0].combat_model.enemies.clear()
	battlefield.spawn_directed_enemy(0, EnemyTypes.Type.HEALYZARD, 4.0, -1, false)
	var healer_only := BalanceLab.lane_time_to_danger(battlefield)
	_check(is_inf(healer_only[0]), "stationary non-damaging Healyzard pulse is not treated as direct time-to-breach assistance demand")
	battlefield.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("P028B threat bias: PASS (%d checks)" % checks)
		quit(0)
		return
	for failure in failures:
		push_error("P028B: %s" % failure)
	push_error("P028B threat bias: FAIL (%d/%d)" % [failures.size(), checks])
	quit(1)
