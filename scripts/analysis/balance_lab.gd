class_name BalanceLab
extends RefCounted

const EnemyTypes = preload("res://scripts/world/enemy_types.gd")
const ThreatRunSelectorScript = preload("res://scripts/analysis/threat_run_selector.gd")

const BASELINE_WEIGHTS: Array[int] = [20, 30, 18, 13, 9, 6, 4]
const EXPERIMENTAL_WEIGHTS: Array[int] = [12, 30, 40, 10, 5, 2, 1]
const SPEEDS: Array[float] = [102.0, 120.0, 140.0, 160.0]
const WINDOW_SIZES: Array[int] = [25, 50, 100]
const URGENCY_THRESHOLDS: Array[float] = [5.0, 10.0, 15.0, 20.0]
const SHOT_COOLDOWN := 0.4
const SHOT_FLIGHT_TIME := 0.20
const MATCH_GEOMETRY_FACTOR := 1.25

static func seed_tuple(seed_value: int) -> Dictionary:
	var base := maxi(seed_value, 1)
	return {
		"source": base,
		"chain": base * 7919 + 17,
		"magazine": base * 6151 + 29,
		"spawn": base * 3571 + 43,
		"attack": base * 2377 + 59,
		"snake": base * 1877 + 71,
		"threat_bias": base * 1237 + 97,
	}

static func sample_generator(seed_value: int, incoming_count: int, weights: Array[int] = BASELINE_WEIGHTS) -> Dictionary:
	var tuple := seed_tuple(seed_value)
	var chain := ChainModel.new()
	chain.set_fresh_seed(int(tuple.chain))
	if not chain.set_analysis_fresh_run_length_weights(weights):
		return {"error": "invalid run weights", "seed": seed_value}
	var sequence: Array[int] = []
	var fresh_ball_counts_by_run_length := [0, 0, 0, 0, 0, 0, 0]
	var active_run_length := 0
	for unused in range(maxi(incoming_count, 0)):
		var begins_run := chain._fresh_run_remaining <= 0
		sequence.append(chain._draw_fresh_identity())
		if begins_run:
			active_run_length = chain._fresh_run_remaining + 1
		fresh_ball_counts_by_run_length[active_run_length - 1] += 1
	var metrics := sequence_metrics(sequence)
	return {
		"seed": seed_value,
		"seed_tuple": tuple,
		"incoming_balls": sequence.size(),
		"starting_preset_counts": _counts(ChainModel.SEED_PATTERN),
		"fresh_counts": chain.fresh_identity_counts.duplicate(),
		"fresh_percent": _percentages(chain.fresh_identity_counts, sequence.size()),
		"run_color_counts": _run_color_counts(sequence),
		"run_length_counts": chain.fresh_run_length_counts.duplicate(),
		"fresh_ball_counts_by_run_length": fresh_ball_counts_by_run_length,
		"runs": chain.fresh_runs_generated,
		"longest_run": chain.longest_fresh_run,
		"drought_balls": metrics.drought_balls,
		"window_max_spread": metrics.window_max_spread,
		"window_worst_color_deficit": metrics.window_worst_color_deficit,
		"sequence_hash": hash(sequence),
	}

static func generator_sweep(seed_start: int, seed_count: int, incoming_count: int, weights: Array[int] = BASELINE_WEIGHTS) -> Dictionary:
	var samples: Array[Dictionary] = []
	var total_counts := [0, 0, 0, 0]
	var total_run_colors := [0, 0, 0, 0]
	var total_lengths := [0, 0, 0, 0, 0, 0, 0]
	var total_balls_by_length := [0, 0, 0, 0, 0, 0, 0]
	var droughts: Array = [[], [], [], []]
	var max_spreads := {"25": [], "50": [], "100": []}
	var worst_sample: Dictionary = {}
	var worst_drought := -1
	for offset in range(maxi(seed_count, 0)):
		var sample := sample_generator(seed_start + offset, incoming_count, weights)
		samples.append(sample)
		for identity in range(TeamData.COUNT):
			total_counts[identity] += int(sample.fresh_counts[identity])
			total_run_colors[identity] += int(sample.run_color_counts[identity])
			var drought := int(sample.drought_balls[identity])
			droughts[identity].append(drought)
			if drought > worst_drought:
				worst_drought = drought
				worst_sample = {"seed": int(sample.seed), "identity": identity, "drought_balls": drought}
		for index in range(7):
			total_lengths[index] += int(sample.run_length_counts[index])
			total_balls_by_length[index] += int(sample.fresh_ball_counts_by_run_length[index])
		for window in WINDOW_SIZES:
			max_spreads[str(window)].append(int(sample.window_max_spread[str(window)]))
	var total_balls := incoming_count * seed_count
	var total_runs := _sum_ints(total_lengths)
	var drought_summary: Array[Dictionary] = []
	for identity in range(TeamData.COUNT):
		drought_summary.append({
			"identity": identity,
			"name": TeamData.display_name(identity),
			"p50": percentile(droughts[identity], 0.50),
			"p95": percentile(droughts[identity], 0.95),
			"worst": _max_value(droughts[identity]),
		})
	return {
		"seed_start": seed_start,
		"seed_count": seed_count,
		"incoming_per_seed": incoming_count,
		"weights": weights.duplicate(),
		"starting_preset_counts": _counts(ChainModel.SEED_PATTERN),
		"fresh_counts": total_counts,
		"fresh_percent": _percentages(total_counts, total_balls),
		"run_color_counts": total_run_colors,
		"run_color_percent": _percentages(total_run_colors, maxi(total_runs, 1)),
		"run_length_counts": total_lengths,
		"run_length_percent_of_runs": _percentages(total_lengths, maxi(total_runs, 1)),
		"fresh_ball_counts_by_run_length": total_balls_by_length,
		"run_length_percent_of_balls": _percentages(total_balls_by_length, maxi(total_balls, 1)),
		"drought_summary": drought_summary,
		"window_spread_summary": _window_summary(max_spreads),
		"worst_drought_sample": worst_sample,
		"seed_samples": samples.map(func(sample: Dictionary): return {
			"seed": sample.seed,
			"sequence_hash": sample.sequence_hash,
			"fresh_counts": sample.fresh_counts,
			"run_color_counts": sample.run_color_counts,
			"run_length_counts": sample.run_length_counts,
			"fresh_ball_counts_by_run_length": sample.fresh_ball_counts_by_run_length,
			"drought_balls": sample.drought_balls,
			"window_max_spread": sample.window_max_spread,
			"window_worst_color_deficit": sample.window_worst_color_deficit,
		}),
	}

static func sequence_metrics(sequence: Array[int]) -> Dictionary:
	var droughts := [0, 0, 0, 0]
	var current := [0, 0, 0, 0]
	for identity in sequence:
		for color in range(TeamData.COUNT):
			if int(identity) == color:
				current[color] = 0
			else:
				current[color] += 1
				droughts[color] = maxi(droughts[color], current[color])
	var spreads := {}
	var deficits := {}
	for window in WINDOW_SIZES:
		var max_spread := 0
		var worst_deficit := [0, 0, 0, 0]
		if sequence.size() >= window:
			var counts := _counts(sequence.slice(0, window))
			for start in range(sequence.size() - window + 1):
				if start > 0:
					counts[int(sequence[start - 1])] -= 1
					counts[int(sequence[start + window - 1])] += 1
				var minimum := int(counts.min())
				var maximum := int(counts.max())
				max_spread = maxi(max_spread, maximum - minimum)
				for color in range(TeamData.COUNT):
					worst_deficit[color] = maxi(worst_deficit[color], int(round(window / 4.0)) - int(counts[color]))
		spreads[str(window)] = max_spread
		deficits[str(window)] = worst_deficit
	return {"drought_balls": droughts, "window_max_spread": spreads, "window_worst_color_deficit": deficits}

static func run_scenario(tree: SceneTree, seed_value: int, duration: float, step: float, policy: String, speed: float = ChainModel.DEFAULT_SPEED, weights: Array[int] = BASELINE_WEIGHTS, generator_arm := "baseline", decision_delay := 0.0) -> Dictionary:
	var tuple := seed_tuple(seed_value)
	var chain := ChainModel.new()
	chain.speed = speed
	chain.set_fresh_seed(int(tuple.chain))
	chain.set_analysis_fresh_run_length_weights(weights)
	var threat_selector = ThreatRunSelectorScript.new(generator_arm, int(tuple.threat_bias), int(tuple.chain))
	threat_selector.chain_model = chain
	var selector_callback := Callable()
	if generator_arm != "baseline":
		selector_callback = Callable(threat_selector, "choose")
	var length_callback := Callable()
	if generator_arm != "baseline":
		length_callback = Callable(threat_selector, "choose_paired_run_length")
	chain.set_analysis_fresh_run_callbacks(selector_callback, Callable(threat_selector, "observe"), length_callback)
	chain.reset_run()
	var magazine := MagazineState.new(int(tuple.magazine))
	var progression := MatchProgression.new()
	var battlefield := Battlefield.new()
	tree.root.add_child(battlefield)
	await tree.process_frame
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
	battlefield.set_spawn_rng_seed(int(tuple.spawn))
	battlefield.set_attack_rng_seed(int(tuple.attack))
	battlefield.set_snake_direction_rng_seed(int(tuple.snake))
	battlefield.reset_run()
	for lane in battlefield.lanes:
		lane.set_process(false)

	var counts := {
		"shots": 0, "shot_arrivals": 0, "shot_misses": 0, "insertions": 0, "nonmatched_insertions": 0,
		"original_target_contacts": 0, "original_targets_gone": 0, "off_target_insertions": 0,
		"swaps": 0, "matches": 0, "damage_hits": 0, "kills": 0,
		"healer_pulses": 0, "emergency_clears": 0, "knockdowns": 0, "revivals": 0, "breaches": 0,
	}
	battlefield.healer_pulsed.connect(func(_event: Dictionary): counts.healer_pulses += 1)
	battlefield.defender_knocked_down.connect(func(_identity: int): counts.knockdowns += 1)
	battlefield.defender_revived.connect(func(_identity: int): counts.revivals += 1)
	for lane in battlefield.lanes:
		lane.combat_model.enemy_hit.connect(func(_uid: int, _hp: int, _x: float): counts.damage_hits += 1)
		lane.combat_model.enemy_killed.connect(func(_uid: int, _x: float): counts.kills += 1)
		lane.combat_model.emergency_discharged.connect(func(_identity: int, cleared: int): counts.emergency_clears += cleared)
	var fired_counts := [0, 0, 0, 0]
	var match_counts := [0, 0, 0, 0]
	var visible_integral := [0.0, 0.0, 0.0, 0.0]
	var left_clipped_integral := [0.0, 0.0, 0.0, 0.0]
	var right_clipped_integral := [0.0, 0.0, 0.0, 0.0]
	var visible_absent := [0.0, 0.0, 0.0, 0.0]
	var visible_absent_longest := [0.0, 0.0, 0.0, 0.0]
	var match_absent := [0.0, 0.0, 0.0, 0.0]
	var match_absent_longest := [0.0, 0.0, 0.0, 0.0]
	var ammo_integral := [0.0, 0.0, 0.0, 0.0]
	var loaded_integral := [0.0, 0.0, 0.0, 0.0]
	var next_integral := [0.0, 0.0, 0.0, 0.0]
	var usable_integral := [0.0, 0.0, 0.0, 0.0]
	var pair_integral := [0.0, 0.0, 0.0, 0.0]
	var group3_integral := [0.0, 0.0, 0.0, 0.0]
	var entering_counts := [0, 0, 0, 0]
	var threat_time := {"5": [0.0, 0.0, 0.0, 0.0], "10": [0.0, 0.0, 0.0, 0.0], "15": [0.0, 0.0, 0.0, 0.0], "20": [0.0, 0.0, 0.0, 0.0]}
	var starved_time := [0.0, 0.0, 0.0, 0.0]
	var starved_current := [0.0, 0.0, 0.0, 0.0]
	var starved_longest := [0.0, 0.0, 0.0, 0.0]
	var starvation_reasons := {"chain": 0.0, "ammo": 0.0, "timing": 0.0}
	var seen_spawn_ids := {}
	var spawn_type_counts := [0, 0, 0, 0]
	var previous_right := {}
	for ball in chain.balls:
		if float(ball.x) - chain.radius > chain.lane_width:
			previous_right[int(ball.uid)] = true
	var pending_shot: Dictionary = {}
	var insertion_checks: Array[Dictionary] = []
	var cooldown := 0.0
	var elapsed := 0.0
	var processed_matches := 0
	var last_shot_time := -INF
	var minimum_shot_interval := INF
	var minimum_flight_time := INF
	var maximum_flight_time := 0.0
	var decision_clock := decision_delay
	var run_event_cursor := 0
	var pending_run_lags: Array[Dictionary] = []
	var response_lags := {
		"visible": [[], [], [], []],
		"pair": [[], [], [], []],
		"match": [[], [], [], []],
	}
	while elapsed < duration - 0.000001 and not battlefield.game_over and not battlefield.victory:
		var dt := minf(step, duration - elapsed)
		cooldown = maxf(0.0, cooldown - dt)
		decision_clock += dt
		# This is the actual live Battlefield state from the immediately preceding
		# model step. A new run created during this chain advance sees <= one outer
		# step (normally 0.1s) of causal snapshot lag and no future spawn state.
		threat_selector.set_threat_snapshot(lane_time_to_danger(battlefield))
		var shot_event := advance_chain_with_fixed_shot(chain, pending_shot, dt)
		while run_event_cursor < threat_selector.selection_events.size():
			var selection: Dictionary = threat_selector.selection_events[run_event_cursor]
			pending_run_lags.append({
				"identity": int(selection.chosen),
				"selected_at": float(selection.time),
				"first_uid": int(selection.first_uid),
				"visible_done": false,
				"pair_done": false,
				"match_done": false,
			})
			run_event_cursor += 1
		if bool(shot_event.arrived):
			counts.shot_arrivals += 1
			minimum_flight_time = minf(minimum_flight_time, float(shot_event.flight_time))
			maximum_flight_time = maxf(maximum_flight_time, float(shot_event.flight_time))
			if bool(shot_event.target_gone):
				counts.original_targets_gone += 1
			elif bool(shot_event.original_target_contact):
				counts.original_target_contacts += 1
			if bool(shot_event.inserted):
				counts.insertions += 1
				if not bool(shot_event.original_target_contact):
					counts.off_target_insertions += 1
				insertion_checks.append({"settle_at": float(shot_event.impact_time) + ChainModel.INSERT_SETTLE_TIME + 0.001, "match_count": int(shot_event.match_count_before)})
			else:
				counts.shot_misses += 1
		var pending_checks: Array[Dictionary] = []
		for check in insertion_checks:
			if chain.simulation_time + 0.000001 >= float(check.settle_at):
				if chain.event_log.size() <= int(check.match_count):
					counts.nonmatched_insertions += 1
			else:
				pending_checks.append(check)
		insertion_checks = pending_checks
		while processed_matches < chain.event_log.size():
			var match_event: Dictionary = chain.event_log[processed_matches]
			var result := progression.register_match(int(match_event.identity), int(match_event.size))
			if not result.is_empty():
				battlefield.handle_match(result)
				match_counts[int(match_event.identity)] += 1
				counts.matches += 1
				for pending in pending_run_lags:
					if not bool(pending.match_done) and int(pending.identity) == int(match_event.identity):
						response_lags.match[int(pending.identity)].append(maxf(0.0, chain.simulation_time - float(pending.selected_at)))
						pending.match_done = true
			processed_matches += 1
		progression.update(dt)
		battlefield.call("_update_spawn_director", dt)
		battlefield.call("_update_snake_special", dt)
		for lane in battlefield.lanes:
			lane.combat_model.update(dt)
		battlefield.call("_evaluate_terminal_state")

		var opportunities := match_opportunities(chain)
		var group_counts := visible_group_counts(chain)
		var visible_counts := [0, 0, 0, 0]
		var left_counts := [0, 0, 0, 0]
		var right_counts := [0, 0, 0, 0]
		var current_right := {}
		for ball in chain.balls:
			var x := float(ball.x)
			var identity := int(ball.identity)
			if x + chain.radius >= 0.0 and x - chain.radius <= chain.lane_width:
				visible_counts[identity] += 1
				if previous_right.has(int(ball.uid)):
					entering_counts[identity] += 1
			elif x + chain.radius < 0.0:
				left_counts[identity] += 1
			elif x - chain.radius > chain.lane_width:
				right_counts[identity] += 1
				current_right[int(ball.uid)] = true
		previous_right = current_right
		for pending in pending_run_lags:
			var lag_identity := int(pending.identity)
			var first_uid := int(pending.first_uid)
			if not bool(pending.visible_done) and _uid_is_visible(chain, first_uid):
				response_lags.visible[lag_identity].append(maxf(0.0, chain.simulation_time - float(pending.selected_at)))
				pending.visible_done = true
			if not bool(pending.pair_done) and _uid_has_visible_pair(chain, first_uid):
				response_lags.pair[lag_identity].append(maxf(0.0, chain.simulation_time - float(pending.selected_at)))
				pending.pair_done = true
		var ttd := lane_time_to_danger(battlefield)
		for identity in range(TeamData.COUNT):
			visible_integral[identity] += visible_counts[identity] * dt
			left_clipped_integral[identity] += left_counts[identity] * dt
			right_clipped_integral[identity] += right_counts[identity] * dt
			pair_integral[identity] += int(group_counts.pairs[identity]) * dt
			group3_integral[identity] += int(group_counts.groups3[identity]) * dt
			if visible_counts[identity] == 0:
				visible_absent[identity] += dt
				visible_absent_longest[identity] = maxf(visible_absent_longest[identity], visible_absent[identity])
			else:
				visible_absent[identity] = 0.0
			if opportunities[identity].is_empty():
				match_absent[identity] += dt
				match_absent_longest[identity] = maxf(match_absent_longest[identity], match_absent[identity])
			else:
				match_absent[identity] = 0.0
			if magazine.loaded_identity == identity or magazine.next_identity == identity:
				ammo_integral[identity] += dt
			if magazine.loaded_identity == identity:
				loaded_integral[identity] += dt
			if magazine.next_identity == identity:
				next_integral[identity] += dt
			for threshold in URGENCY_THRESHOLDS:
				if float(ttd[identity]) <= threshold:
					threat_time[str(int(threshold))][identity] += dt
			var threatened := float(ttd[identity]) <= 10.0
			var has_pair := not opportunities[identity].is_empty()
			var has_ammo := magazine.loaded_identity == identity or magazine.next_identity == identity
			var launch_opportunity := has_pair and has_ammo and cooldown <= 0.000001 and pending_shot.is_empty()
			if launch_opportunity:
				usable_integral[identity] += dt
			if threatened and not launch_opportunity:
				starved_time[identity] += dt
				starved_current[identity] += dt
				starved_longest[identity] = maxf(starved_longest[identity], starved_current[identity])
				if not has_pair:
					starvation_reasons.chain += dt
				elif not has_ammo:
					starvation_reasons.ammo += dt
				else:
					starvation_reasons.timing += dt
			else:
				starved_current[identity] = 0.0

		for lane in battlefield.lanes:
			for enemy in lane.combat_model.enemies:
				var spawn_id := int(enemy.get("spawn_id", -1))
				if spawn_id >= 0 and not seen_spawn_ids.has(spawn_id):
					seen_spawn_ids[spawn_id] = true
					spawn_type_counts[int(enemy.get("type", EnemyTypes.Type.HOPPER))] += 1
		var total_breaches := 0
		for lane in battlefield.lanes:
			total_breaches += lane.combat_model.total_breaches
		counts.breaches = total_breaches

		if policy != "observe_only" and cooldown <= 0.000001 and pending_shot.is_empty() and decision_clock + 0.000001 >= decision_delay:
			var action := choose_action(policy, magazine, opportunities, ttd)
			if not action.is_empty():
				if bool(action.swap):
					magazine.swap()
					counts.swaps += 1
				var fired := magazine.consume_loaded()
				fired_counts[fired] += 1
				counts.shots += 1
				if last_shot_time > -INF:
					minimum_shot_interval = minf(minimum_shot_interval, chain.simulation_time - last_shot_time)
				last_shot_time = chain.simulation_time
				pending_shot = {
					"identity": fired,
					"target_uid": int(action.target_uid),
					"shot_x": clampf(float(action.aim_x), 0.0, chain.lane_width),
					"remaining": SHOT_FLIGHT_TIME,
					"launched_at": chain.simulation_time,
				}
				cooldown = SHOT_COOLDOWN
				decision_clock = 0.0
		elapsed += dt

	var outcome := "victory" if battlefield.victory else ("defeat" if battlefield.game_over else "timeout")
	var result := {
		"seed": seed_value,
		"seed_tuple": tuple,
		"policy": policy,
		"generator_arm": generator_arm,
		"decision_delay": decision_delay,
		"speed": speed,
		"weights": weights.duplicate(),
		"duration_requested": duration,
		"duration_simulated": elapsed,
		"step": step,
		"minimum_shot_interval": 0.0 if is_inf(minimum_shot_interval) else minimum_shot_interval,
		"minimum_flight_time": 0.0 if is_inf(minimum_flight_time) else minimum_flight_time,
		"maximum_flight_time": maximum_flight_time,
		"outcome": outcome,
		"starting_preset_counts": _counts(ChainModel.SEED_PATTERN),
		"fresh_counts": chain.fresh_identity_counts.duplicate(),
		"fresh_generated": _sum_ints(chain.fresh_identity_counts),
		"run_length_counts": chain.fresh_run_length_counts.duplicate(),
		"visible_mean": _divide_floats(visible_integral, maxf(elapsed, 0.000001)),
		"left_clipped_mean": _divide_floats(left_clipped_integral, maxf(elapsed, 0.000001)),
		"right_clipped_mean": _divide_floats(right_clipped_integral, maxf(elapsed, 0.000001)),
		"visible_absent_longest_s": visible_absent_longest,
		"visible_adjacent_pair_mean": _divide_floats(pair_integral, maxf(elapsed, 0.000001)),
		"visible_preexisting_group3_fraction": _divide_floats(group3_integral, maxf(elapsed, 0.000001)),
		"match_opportunity_absent_longest_s": match_absent_longest,
		"ammo_available_fraction": _divide_floats(ammo_integral, maxf(elapsed, 0.000001)),
		"loaded_fraction": _divide_floats(loaded_integral, maxf(elapsed, 0.000001)),
		"next_fraction": _divide_floats(next_integral, maxf(elapsed, 0.000001)),
		"launch_opportunity_fraction": _divide_floats(usable_integral, maxf(elapsed, 0.000001)),
		"usable_response_fraction": _divide_floats(usable_integral, maxf(elapsed, 0.000001)),
		"entering_counts": entering_counts,
		"off_left_final": chain.offscreen_left_count(),
		"off_right_final": chain.offscreen_right_count(),
		"magazine_generated_counts": _counts(magazine.generated_history),
		"magazine_draw_count": magazine.draw_count,
		"fired_counts": fired_counts,
		"match_counts": match_counts,
		"threat_time_s": threat_time,
		"starved_threat_time_s": starved_time,
		"starved_threat_longest_s": starved_longest,
		"starvation_reasons_s": starvation_reasons,
		"threat_selector": threat_selector.summary(),
		"run_response_lags": _summarize_response_lags(response_lags, pending_run_lags),
		"spawn_type_counts": spawn_type_counts,
		"spawned": battlefield.encounter_spawned(),
		"live_enemies": battlefield.encounter_live(),
		"neutralized": battlefield.encounter_neutralized(),
		"score": progression.score,
		"counts": counts,
	}
	battlefield.queue_free()
	await tree.process_frame
	return result

static func _uid_is_visible(chain: ChainModel, uid: int) -> bool:
	var index := chain._ball_index_by_uid(uid)
	if index < 0:
		return false
	var x := float(chain.balls[index].x)
	return x + chain.radius >= 0.0 and x - chain.radius <= chain.lane_width

static func _uid_has_visible_pair(chain: ChainModel, uid: int) -> bool:
	var index := chain._ball_index_by_uid(uid)
	if index < 0 or chain.is_settling(uid):
		return false
	var ball: Dictionary = chain.balls[index]
	var x := float(ball.x)
	if x + chain.radius < 0.0 or x - chain.radius > chain.lane_width:
		return false
	for other in chain.balls:
		if int(other.uid) == uid or int(other.identity) != int(ball.identity) or chain.is_settling(int(other.uid)):
			continue
		var other_x := float(other.x)
		if other_x + chain.radius < 0.0 or other_x - chain.radius > chain.lane_width:
			continue
		if absf(other_x - x) <= chain.spacing * MATCH_GEOMETRY_FACTOR:
			return true
	return false

static func _summarize_response_lags(values: Dictionary, pending: Array[Dictionary]) -> Dictionary:
	var result := {}
	for metric in ["visible", "pair", "match"]:
		var per_color: Array = values[metric]
		var summaries: Array[Dictionary] = []
		for identity in range(TeamData.COUNT):
			var samples: Array = per_color[identity]
			summaries.append({
				"count": samples.size(),
				"mean_s": _mean(samples),
				"p50_s": percentile(samples, 0.50),
				"p95_s": percentile(samples, 0.95),
				"worst_s": _max_value(samples),
			})
		result[metric] = summaries
	var unresolved := {"visible": [0, 0, 0, 0], "pair": [0, 0, 0, 0], "match": [0, 0, 0, 0]}
	for item in pending:
		var identity := int(item.identity)
		for metric in ["visible", "pair", "match"]:
			if not bool(item[metric + "_done"]):
				unresolved[metric][identity] += 1
	result.unresolved = unresolved
	return result

static func advance_chain_with_fixed_shot(chain: ChainModel, pending_shot: Dictionary, delta: float) -> Dictionary:
	var result := {
		"arrived": false,
		"inserted": false,
		"shot_x": float(pending_shot.get("shot_x", NAN)),
		"target_gone": false,
		"original_target_contact": false,
		"target_drift": NAN,
		"impact_time": -1.0,
		"flight_time": 0.0,
		"match_count_before": chain.event_log.size(),
	}
	var step := maxf(delta, 0.0)
	if pending_shot.is_empty():
		chain.advance(step)
		return result
	var remaining := maxf(float(pending_shot.get("remaining", SHOT_FLIGHT_TIME)), 0.0)
	if remaining > step + 0.000001:
		chain.advance(step)
		pending_shot.remaining = remaining - step
		return result
	var before_impact := minf(remaining, step)
	chain.advance(before_impact)
	var shot_x := float(pending_shot.shot_x)
	var target_index := chain._ball_index_by_uid(int(pending_shot.get("target_uid", -1)))
	result.arrived = true
	result.shot_x = shot_x
	result.impact_time = chain.simulation_time
	result.flight_time = chain.simulation_time - float(pending_shot.get("launched_at", chain.simulation_time - SHOT_FLIGHT_TIME))
	result.match_count_before = chain.event_log.size()
	result.target_gone = target_index < 0
	if target_index >= 0:
		var target: Dictionary = chain.balls[target_index]
		result.target_drift = float(target.display_x) - shot_x
		result.original_target_contact = absf(float(result.target_drift)) <= chain.radius + ChainModel.DEFAULT_SHOT_RADIUS
	# Collision is exclusively the immutable launch axis against current chain
	# geometry. target_uid is diagnostics-only and never influences this call.
	result.inserted = chain.try_insert_shot(int(pending_shot.identity), shot_x)
	pending_shot.clear()
	var after_impact := maxf(0.0, step - before_impact)
	if after_impact > 0.000001:
		chain.advance(after_impact)
	return result

static func match_opportunities(chain: ChainModel) -> Array[Array]:
	var result: Array[Array] = [[], [], [], []]
	var visible: Array[Dictionary] = []
	for ball in chain.balls:
		var x := float(ball.x)
		if x + chain.radius >= 0.0 and x - chain.radius <= chain.lane_width and not chain.is_settling(int(ball.uid)):
			visible.append(ball)
	visible.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.x) < float(b.x))
	for index in range(visible.size() - 1):
		var left: Dictionary = visible[index]
		var right: Dictionary = visible[index + 1]
		if int(left.identity) != int(right.identity):
			continue
		if float(right.x) - float(left.x) > chain.spacing * MATCH_GEOMETRY_FACTOR:
			continue
		result[int(left.identity)].append({"target_uid": int(left.uid), "left_x": float(left.x), "right_x": float(right.x)})
	return result

static func visible_group_counts(chain: ChainModel) -> Dictionary:
	var pairs := [0, 0, 0, 0]
	var groups2 := [0, 0, 0, 0]
	var groups3 := [0, 0, 0, 0]
	var visible: Array[Dictionary] = []
	for ball in chain.balls:
		var x := float(ball.x)
		if x + chain.radius >= 0.0 and x - chain.radius <= chain.lane_width and not chain.is_settling(int(ball.uid)):
			visible.append(ball)
	visible.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.x) < float(b.x))
	var index := 0
	while index < visible.size():
		var identity := int(visible[index].identity)
		var length := 1
		while index + length < visible.size():
			var previous: Dictionary = visible[index + length - 1]
			var candidate: Dictionary = visible[index + length]
			if int(candidate.identity) != identity or float(candidate.x) - float(previous.x) > chain.spacing * MATCH_GEOMETRY_FACTOR:
				break
			length += 1
		pairs[identity] += maxi(0, length - 1)
		if length >= 2:
			groups2[identity] += 1
		if length >= 3:
			groups3[identity] += 1
		index += length
	return {"pairs": pairs, "groups2": groups2, "groups3": groups3}

static func choose_action(policy: String, magazine: MagazineState, opportunities: Array[Array], time_to_danger: Array[float]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for identity in [magazine.loaded_identity, magazine.next_identity]:
		if opportunities[identity].is_empty():
			continue
		candidates.append({
			"identity": identity,
			"target_uid": int(opportunities[identity][0].target_uid),
			"aim_x": float(opportunities[identity][0].left_x) - 1.0,
			"swap": identity != magazine.loaded_identity,
			"urgency": float(time_to_danger[identity]),
		})
	if candidates.is_empty():
		return {}
	if policy == "threat_priority":
		candidates.sort_custom(func(a: Dictionary, b: Dictionary):
			if not is_equal_approx(float(a.urgency), float(b.urgency)):
				return float(a.urgency) < float(b.urgency)
			return int(a.identity) < int(b.identity)
		)
	return candidates[0]

static func lane_time_to_danger(battlefield: Battlefield) -> Array[float]:
	var result: Array[float] = [INF, INF, INF, INF]
	for lane_index in range(battlefield.lanes.size()):
		for enemy in battlefield.lanes[lane_index].combat_model.enemies:
			var enemy_type := int(enemy.get("type", EnemyTypes.Type.HOPPER))
			if enemy_type == EnemyTypes.Type.HEALYZARD:
				continue
			var speed := float(enemy.get("speed", 0.0))
			if enemy_type == EnemyTypes.Type.SICKLE_SNAKE and StringName(enemy.get("special_state", &"moving")) != &"moving":
				var delay := float(enemy.get("special_timer", 0.0))
				if speed > 0.0:
					result[lane_index] = minf(result[lane_index], delay + maxf(0.0, float(enemy.x) - LaneCombatModel.DEFENDER_X) / speed)
				continue
			if speed > 0.0:
				result[lane_index] = minf(result[lane_index], maxf(0.0, float(enemy.x) - LaneCombatModel.DEFENDER_X) / speed)
	return result

static func percentile(values: Array, ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(ceili(clampf(ratio, 0.0, 1.0) * sorted.size()) - 1, 0, sorted.size() - 1)
	return float(sorted[index])

static func _counts(sequence: Array) -> Array[int]:
	var result: Array[int] = [0, 0, 0, 0]
	for identity in sequence:
		if int(identity) >= 0 and int(identity) < TeamData.COUNT:
			result[int(identity)] += 1
	return result

static func _run_color_counts(sequence: Array[int]) -> Array[int]:
	var result: Array[int] = [0, 0, 0, 0]
	var previous := -1
	for identity in sequence:
		if identity != previous:
			result[identity] += 1
			previous = identity
	return result

static func _percentages(values: Array, total: int) -> Array[float]:
	var result: Array[float] = []
	for value in values:
		result.append(100.0 * float(value) / maxf(float(total), 1.0))
	return result

static func _window_summary(spreads: Dictionary) -> Dictionary:
	var result := {}
	for key in spreads:
		result[key] = {"p50": percentile(spreads[key], 0.50), "p95": percentile(spreads[key], 0.95), "worst": _max_value(spreads[key])}
	return result

static func _sum_ints(values: Array) -> int:
	var result := 0
	for value in values:
		result += int(value)
	return result

static func _max_value(values: Array) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, float(value))
	return result

static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return total / values.size()

static func _divide_floats(values: Array, divisor: float) -> Array[float]:
	var result: Array[float] = []
	for value in values:
		result.append(float(value) / divisor)
	return result
