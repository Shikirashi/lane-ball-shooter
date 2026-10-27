class_name ThreatBiasLab
extends RefCounted

const ThreatRunSelectorScript = preload("res://scripts/analysis/threat_run_selector.gd")

const ARMS: Array[String] = ["baseline", "mild", "moderate", "strong"]
const SCHEDULES: Array[String] = ["no_threat", "single_urgent", "rotating", "multiple_urgent", "urgent_exhausted"]

static func synthetic_sweep(seed_start: int, seed_count: int, incoming_balls: int) -> Dictionary:
	var aggregates := {}
	var baseline_no_threat_hashes := {}
	for schedule in SCHEDULES:
		for arm in ARMS:
			aggregates[_key(schedule, arm)] = _empty_aggregate(schedule, arm)
	for seed_value in range(seed_start, seed_start + seed_count):
		for schedule in SCHEDULES:
			var baseline_sample := synthetic_sample(seed_value, incoming_balls, "baseline", schedule)
			_accumulate(aggregates[_key(schedule, "baseline")], baseline_sample)
			if schedule == "no_threat":
				baseline_no_threat_hashes[seed_value] = baseline_sample.sequence_hash
			for arm in ["mild", "moderate", "strong"]:
				var sample := synthetic_sample(seed_value, incoming_balls, arm, schedule)
				if schedule == "no_threat" and sample.sequence_hash == baseline_no_threat_hashes[seed_value]:
					aggregates[_key(schedule, arm)].no_threat_exact_matches += 1
				_accumulate(aggregates[_key(schedule, arm)], sample)
	var rows: Array[Dictionary] = []
	for schedule in SCHEDULES:
		for arm in ARMS:
			rows.append(_finish_aggregate(aggregates[_key(schedule, arm)]))
	return {
		"seed_start": seed_start,
		"seed_count": seed_count,
		"incoming_balls_per_seed": incoming_balls,
		"schedules": SCHEDULES.duplicate(),
		"arms": ARMS.duplicate(),
		"rows": rows,
	}

static func synthetic_sample(seed_value: int, incoming_balls: int, arm: String, schedule: String) -> Dictionary:
	var tuple := BalanceLab.seed_tuple(seed_value)
	var chain := ChainModel.new()
	chain.set_fresh_seed(int(tuple.chain))
	var controller = ThreatRunSelectorScript.new(arm, int(tuple.threat_bias), int(tuple.chain))
	var selector_callback := Callable()
	if arm != "baseline":
		selector_callback = Callable(controller, "choose")
	var length_callback := Callable()
	if arm != "baseline":
		length_callback = Callable(controller, "choose_paired_run_length")
	chain.set_analysis_fresh_run_callbacks(selector_callback, Callable(controller, "observe"), length_callback)
	var sequence: Array[int] = []
	var run_lengths: Array[int] = []
	var run_index := 0
	for unused in range(maxi(incoming_balls, 0)):
		var begins_run := chain._fresh_run_remaining <= 0
		if begins_run:
			controller.set_threat_snapshot(_fixture_threat(schedule, seed_value, run_index, chain))
			run_index += 1
		sequence.append(chain._draw_fresh_identity())
		if begins_run:
			run_lengths.append(chain._fresh_run_remaining + 1)
	var run_colors: Array[int] = []
	for event in controller.selection_events:
		run_colors.append(int(event.chosen))
	var ball_metrics := BalanceLab.sequence_metrics(sequence)
	var run_metrics := BalanceLab.sequence_metrics(run_colors)
	return {
		"seed": seed_value,
		"arm": arm,
		"schedule": schedule,
		"sequence_hash": hash(sequence),
		"balls": sequence.size(),
		"runs": run_colors.size(),
		"ball_counts": BalanceLab._counts(sequence),
		"run_counts": BalanceLab._counts(run_colors),
		"run_lengths": run_lengths,
		"ball_droughts": ball_metrics.drought_balls,
		"run_droughts": run_metrics.drought_balls,
		"window_spreads": ball_metrics.window_max_spread,
		"bag_violations": _bag_violations(run_colors),
		"repeat_violations": _repeat_violations(run_colors),
		"selector": controller.summary(),
	}

static func _fixture_threat(schedule: String, seed_value: int, run_index: int, chain: ChainModel) -> Array[float]:
	var ttd: Array[float] = [INF, INF, INF, INF]
	match schedule:
		"single_urgent":
			ttd[seed_value % TeamData.COUNT] = 4.0
		"rotating":
			ttd[(seed_value + run_index / 2) % TeamData.COUNT] = 3.0 + float(run_index % 3)
		"multiple_urgent":
			var first := (seed_value + run_index) % TeamData.COUNT
			ttd[first] = 5.0
			ttd[(first + 1) % TeamData.COUNT] = 9.0
		"urgent_exhausted":
			# The preceding run color has already left the current bag and is also
			# illegal as an immediate repeat when a new bag opens.
			var absent := chain._previous_fresh_run_identity
			if absent < 0:
				absent = seed_value % TeamData.COUNT
			ttd[absent] = 2.0
	return ttd

static func _empty_aggregate(schedule: String, arm: String) -> Dictionary:
	return {
		"schedule": schedule,
		"arm": arm,
		"seeds": 0,
		"balls": 0,
		"runs": 0,
		"ball_counts": [0, 0, 0, 0],
		"run_counts": [0, 0, 0, 0],
		"ball_drought_samples": [[], [], [], []],
		"run_drought_samples": [[], [], [], []],
		"window_spread_samples": {"25": [], "50": [], "100": []},
		"bag_violations": 0,
		"repeat_violations": 0,
		"world_active_threat": 0,
		"eligible_urgency_active": 0,
		"no_eligible_urgent": 0,
		"actual_interventions": 0,
		"ineligible_interventions": 0,
		"bias_rng_draws": 0,
		"urgent_unavailable": 0,
		"urgent_selected": 0,
		"no_threat_exact_matches": 0,
	}

static func _accumulate(aggregate: Dictionary, sample: Dictionary) -> void:
	aggregate.seeds += 1
	aggregate.balls += int(sample.balls)
	aggregate.runs += int(sample.runs)
	for identity in range(TeamData.COUNT):
		aggregate.ball_counts[identity] += int(sample.ball_counts[identity])
		aggregate.run_counts[identity] += int(sample.run_counts[identity])
		aggregate.ball_drought_samples[identity].append(int(sample.ball_droughts[identity]))
		aggregate.run_drought_samples[identity].append(int(sample.run_droughts[identity]))
	for window in BalanceLab.WINDOW_SIZES:
		aggregate.window_spread_samples[str(window)].append(int(sample.window_spreads[str(window)]))
	aggregate.bag_violations += int(sample.bag_violations)
	aggregate.repeat_violations += int(sample.repeat_violations)
	aggregate.world_active_threat += int(sample.selector.world_active_threat)
	aggregate.eligible_urgency_active += int(sample.selector.eligible_urgency_active)
	aggregate.no_eligible_urgent += int(sample.selector.no_eligible_urgent)
	aggregate.actual_interventions += int(sample.selector.actual_interventions)
	aggregate.ineligible_interventions += int(sample.selector.ineligible_interventions)
	aggregate.bias_rng_draws += int(sample.selector.bias_rng_draws)
	aggregate.urgent_unavailable += int(sample.selector.urgent_unavailable)
	aggregate.urgent_selected += int(sample.selector.urgent_selected)

static func _finish_aggregate(aggregate: Dictionary) -> Dictionary:
	var result := aggregate.duplicate(true)
	result.erase("ball_drought_samples")
	result.erase("run_drought_samples")
	result.erase("window_spread_samples")
	result.ball_drought = _per_color_summary(aggregate.ball_drought_samples)
	result.run_drought = _per_color_summary(aggregate.run_drought_samples)
	result.window_spread = {}
	for window in BalanceLab.WINDOW_SIZES:
		var values: Array = aggregate.window_spread_samples[str(window)]
		result.window_spread[str(window)] = {
			"p50": BalanceLab.percentile(values, 0.50),
			"p95": BalanceLab.percentile(values, 0.95),
			"worst": BalanceLab._max_value(values),
		}
	result.intervention_rate = float(aggregate.actual_interventions) / maxf(float(aggregate.eligible_urgency_active), 1.0)
	result.urgent_selection_rate = float(aggregate.urgent_selected) / maxf(float(aggregate.world_active_threat - aggregate.urgent_unavailable), 1.0)
	return result

static func _per_color_summary(samples: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for identity in range(TeamData.COUNT):
		var values: Array = samples[identity]
		result.append({
			"p50": BalanceLab.percentile(values, 0.50),
			"p95": BalanceLab.percentile(values, 0.95),
			"worst": BalanceLab._max_value(values),
		})
	return result

static func _bag_violations(run_colors: Array[int]) -> int:
	var violations := 0
	for start in range(0, run_colors.size() - 3, TeamData.COUNT):
		var counts := BalanceLab._counts(run_colors.slice(start, start + TeamData.COUNT))
		for count in counts:
			if count != 1:
				violations += 1
				break
	return violations

static func _repeat_violations(run_colors: Array[int]) -> int:
	var result := 0
	for index in range(1, run_colors.size()):
		if run_colors[index] == run_colors[index - 1]:
			result += 1
	return result

static func _key(schedule: String, arm: String) -> String:
	return "%s|%s" % [schedule, arm]
