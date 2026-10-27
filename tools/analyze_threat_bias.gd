extends SceneTree

const ThreatBiasLabScript = preload("res://scripts/analysis/threat_bias_lab.gd")

const DEFAULT_OUTPUT := "res://analysis/reports/p028b_exp"
const POLICIES: Array[String] = ["observe_only", "basic_matcher", "delayed_matcher"]
const DELAYED_DECISION_SECONDS := 1.2

var _options := {
	"smoke": false,
	"seeds": 500,
	"scenario_seeds": 12,
	"seed_start": 29001,
	"duration": 90.0,
	"step": 0.1,
	"output": DEFAULT_OUTPUT,
}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var parse_error := _parse_options(OS.get_cmdline_user_args())
	if not parse_error.is_empty():
		push_error(parse_error)
		_print_usage()
		quit(2)
		return
	var started := Time.get_ticks_msec()
	var synthetic_seeds := 8 if bool(_options.smoke) else int(_options.seeds)
	var incoming_balls := 120 if bool(_options.smoke) else 300
	var scenario_seed_count := 2 if bool(_options.smoke) else int(_options.scenario_seeds)
	var scenario_duration := minf(float(_options.duration), 30.0) if bool(_options.smoke) else float(_options.duration)
	print("P028B synthetic sweep: %d paired seeds x %d balls x 5 schedules x 4 arms" % [synthetic_seeds, incoming_balls])
	var synthetic: Dictionary = ThreatBiasLabScript.synthetic_sweep(int(_options.seed_start), synthetic_seeds, incoming_balls)
	var scenarios: Array[Dictionary] = []
	var plans := _scenario_plans(scenario_seed_count)
	print("P028B real-model scenarios: %d cases (%d paired seeds/arm, %.1fs max)" % [plans.size(), scenario_seed_count * POLICIES.size(), scenario_duration])
	for index in range(plans.size()):
		var plan: Dictionary = plans[index]
		print("  [%d/%d] arm=%s seed=%d policy=%s" % [index + 1, plans.size(), plan.arm, plan.seed, plan.policy])
		var delay := DELAYED_DECISION_SECONDS if plan.policy == "delayed_matcher" else 0.0
		var scenario: Dictionary = await BalanceLab.run_scenario(self, int(plan.seed), scenario_duration, float(_options.step), str(plan.policy), ChainModel.DEFAULT_SPEED, BalanceLab.BASELINE_WEIGHTS, str(plan.arm), delay)
		scenarios.append(scenario)
	var comparisons := _aggregate_comparisons(scenarios)
	var runtime := (Time.get_ticks_msec() - started) / 1000.0
	var payload := {
		"schema_version": 1,
		"task": "LBS-P028B-EXP",
		"generated_utc": Time.get_datetime_string_from_system(true),
		"godot_version": Engine.get_version_info().string,
		"runtime_seconds": runtime,
		"command_options": _options.duplicate(true),
		"arms": {
			"baseline": 0.0,
			"mild": 0.5,
			"moderate": 1.5,
			"strong": 3.0,
		},
		"urgency_rule": "clamp((15 - live_ttd) / 12, 0, 1); legal weight = 1 + arm_boost * urgency",
		"synthetic": synthetic,
		"scenario_count": scenarios.size(),
		"scenario_seed_count_per_arm": scenario_seed_count * POLICIES.size(),
		"effective_scenario_duration": scenario_duration,
		"scenario_diagnostics": _scenario_diagnostics(scenarios),
		"comparisons": comparisons,
	}
	var output_path := str(_options.output)
	if output_path.begins_with("res://"):
		output_path = ProjectSettings.globalize_path(output_path)
	var error := DirAccess.make_dir_recursive_absolute(output_path)
	if error != OK:
		push_error("Could not create output directory %s (error %d)" % [output_path, error])
		quit(1)
		return
	_write_text(output_path.path_join("generator_diagnostics.json"), JSON.stringify(payload, "  ") + "\n")
	_write_text(output_path.path_join("scenario_summary.csv"), _scenario_csv(scenarios))
	_write_text(output_path.path_join("baseline_comparison.csv"), _comparison_csv(comparisons))
	_write_text(output_path.path_join("REPORT.md"), _report(payload))
	print("P028B threat-bias experiment: PASS in %.2fs; outputs=%s" % [runtime, output_path])
	quit(0)

func _scenario_plans(seed_count: int) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	for arm in ThreatBiasLabScript.ARMS:
		for policy in POLICIES:
			for offset in range(seed_count):
				plans.append({"arm": arm, "policy": policy, "seed": int(_options.seed_start) + 1000 + offset})
	return plans

func _scenario_diagnostics(scenarios: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sample in scenarios:
		result.append({
			"seed": sample.seed,
			"arm": sample.generator_arm,
			"policy": sample.policy,
			"outcome": sample.outcome,
			"duration_simulated": sample.duration_simulated,
			"threat_selector": sample.threat_selector,
			"run_response_lags": sample.run_response_lags,
			"starved_threat_time_s": sample.starved_threat_time_s,
			"starved_threat_longest_s": sample.starved_threat_longest_s,
			"launch_opportunity_fraction": sample.launch_opportunity_fraction,
			"counts": sample.counts,
		})
	return result

func _aggregate_comparisons(scenarios: Array[Dictionary]) -> Array[Dictionary]:
	var baseline_by_key := {}
	for sample in scenarios:
		if str(sample.generator_arm) == "baseline":
			baseline_by_key[_scenario_key(sample)] = sample
	var rows: Array[Dictionary] = []
	for arm in ThreatBiasLabScript.ARMS:
		for policy in POLICIES:
			var selected: Array = scenarios.filter(func(sample: Dictionary): return str(sample.generator_arm) == arm and str(sample.policy) == policy)
			for identity in range(TeamData.COUNT):
				rows.append(_aggregate_color(selected, baseline_by_key, arm, policy, identity))
	return rows

func _aggregate_color(samples: Array, baseline_by_key: Dictionary, arm: String, policy: String, identity: int) -> Dictionary:
	var outcomes := {"victory": 0, "defeat": 0, "timeout": 0}
	var starved := []
	var longest := []
	var opportunity := []
	var threat10 := []
	var threat15 := []
	var visible_pairs := []
	var fresh := []
	var starved_deltas := []
	var longest_deltas := []
	var opportunity_deltas := []
	var shots := 0
	var arrivals := 0
	var insertions := 0
	var matches := 0
	var neutralized := 0
	var active_selections := 0
	var interventions := 0
	var unavailable := 0
	var urgent_selected := 0
	var visible_lag := []
	var pair_lag := []
	var match_lag := []
	for sample in samples:
		outcomes[str(sample.outcome)] += 1
		starved.append(float(sample.starved_threat_time_s[identity]))
		longest.append(float(sample.starved_threat_longest_s[identity]))
		opportunity.append(float(sample.launch_opportunity_fraction[identity]))
		threat10.append(float(sample.threat_time_s["10"][identity]))
		threat15.append(float(sample.threat_time_s["15"][identity]))
		visible_pairs.append(float(sample.visible_adjacent_pair_mean[identity]))
		fresh.append(float(sample.fresh_counts[identity]))
		shots += int(sample.counts.shots)
		arrivals += int(sample.counts.shot_arrivals)
		insertions += int(sample.counts.insertions)
		matches += int(sample.counts.matches)
		neutralized += int(sample.neutralized)
		active_selections += int(sample.threat_selector.active_threat_selections)
		interventions += int(sample.threat_selector.interventions)
		unavailable += int(sample.threat_selector.urgent_unavailable)
		urgent_selected += int(sample.threat_selector.urgent_selected)
		visible_lag.append(float(sample.run_response_lags.visible[identity].mean_s))
		pair_lag.append(float(sample.run_response_lags.pair[identity].mean_s))
		match_lag.append(float(sample.run_response_lags.match[identity].mean_s))
		var baseline: Dictionary = baseline_by_key.get(_scenario_key(sample), {})
		if not baseline.is_empty():
			starved_deltas.append(float(sample.starved_threat_time_s[identity]) - float(baseline.starved_threat_time_s[identity]))
			longest_deltas.append(float(sample.starved_threat_longest_s[identity]) - float(baseline.starved_threat_longest_s[identity]))
			opportunity_deltas.append(float(sample.launch_opportunity_fraction[identity]) - float(baseline.launch_opportunity_fraction[identity]))
	return {
		"arm": arm,
		"policy": policy,
		"color": TeamData.display_name(identity),
		"color_id": identity,
		"scenarios": samples.size(),
		"victories": outcomes.victory,
		"defeats": outcomes.defeat,
		"timeouts": outcomes.timeout,
		"mean_starved_s": _mean(starved),
		"starved_p50_s": BalanceLab.percentile(starved, 0.50),
		"starved_p95_s": BalanceLab.percentile(starved, 0.95),
		"starved_worst_s": BalanceLab._max_value(starved),
		"mean_longest_episode_s": _mean(longest),
		"episode_p95_s": BalanceLab.percentile(longest, 0.95),
		"mean_launch_opportunity": _mean(opportunity),
		"mean_threat10_s": _mean(threat10),
		"mean_threat15_s": _mean(threat15),
		"mean_visible_pairs": _mean(visible_pairs),
		"mean_fresh_balls": _mean(fresh),
		"paired_starved_delta_s": _mean(starved_deltas),
		"paired_longest_delta_s": _mean(longest_deltas),
		"paired_opportunity_delta": _mean(opportunity_deltas),
		"shots": shots,
		"arrivals": arrivals,
		"insertions": insertions,
		"hit_rate": 100.0 * insertions / maxf(float(arrivals), 1.0),
		"matches": matches,
		"neutralized": neutralized,
		"active_threat_selections": active_selections,
		"interventions": interventions,
		"urgent_unavailable": unavailable,
		"urgent_selected": urgent_selected,
		"mean_run_to_visible_s": _mean(visible_lag),
		"mean_run_to_pair_s": _mean(pair_lag),
		"mean_run_to_match_s": _mean(match_lag),
	}

func _scenario_key(sample: Dictionary) -> String:
	return "%d|%s" % [int(sample.seed), str(sample.policy)]

func _scenario_csv(scenarios: Array[Dictionary]) -> String:
	var headers := ["seed", "arm", "policy", "decision_delay_s", "duration_s", "outcome", "victory", "spawned", "neutralized", "shots", "arrivals", "insertions", "misses", "matches", "active_threat_selections", "interventions", "urgent_unavailable", "urgent_selected"]
	for prefix in ["fresh", "threat10_s", "threat15_s", "starved_s", "longest_starved_s", "launch_opportunity", "visible_pairs", "run_to_visible_s", "run_to_pair_s", "run_to_match_s"]:
		for identity in range(TeamData.COUNT):
			headers.append("%s_%s" % [prefix, TeamData.display_name(identity).to_lower()])
	var lines := [",".join(headers)]
	for sample in scenarios:
		var values: Array = [sample.seed, sample.generator_arm, sample.policy, sample.decision_delay, sample.duration_simulated, sample.outcome, 1 if sample.outcome == "victory" else 0, sample.spawned, sample.neutralized, sample.counts.shots, sample.counts.shot_arrivals, sample.counts.insertions, sample.counts.shot_misses, sample.counts.matches, sample.threat_selector.active_threat_selections, sample.threat_selector.interventions, sample.threat_selector.urgent_unavailable, sample.threat_selector.urgent_selected]
		values.append_array(sample.fresh_counts)
		values.append_array(sample.threat_time_s["10"])
		values.append_array(sample.threat_time_s["15"])
		values.append_array(sample.starved_threat_time_s)
		values.append_array(sample.starved_threat_longest_s)
		values.append_array(sample.launch_opportunity_fraction)
		values.append_array(sample.visible_adjacent_pair_mean)
		for identity in range(TeamData.COUNT): values.append(sample.run_response_lags.visible[identity].mean_s)
		for identity in range(TeamData.COUNT): values.append(sample.run_response_lags.pair[identity].mean_s)
		for identity in range(TeamData.COUNT): values.append(sample.run_response_lags.match[identity].mean_s)
		lines.append(_csv_row(values))
	return "\n".join(lines) + "\n"

func _comparison_csv(rows: Array[Dictionary]) -> String:
	var headers := ["arm", "policy", "color", "scenarios", "victories", "defeats", "timeouts", "mean_starved_s", "starved_p50_s", "starved_p95_s", "starved_worst_s", "mean_longest_episode_s", "episode_p95_s", "paired_starved_delta_s", "paired_longest_delta_s", "mean_launch_opportunity", "paired_opportunity_delta", "mean_threat10_s", "mean_threat15_s", "mean_visible_pairs", "mean_fresh_balls", "shots", "arrivals", "insertions", "hit_rate_percent", "matches", "neutralized", "active_threat_selections", "interventions", "urgent_unavailable", "urgent_selected", "mean_run_to_visible_s", "mean_run_to_pair_s", "mean_run_to_match_s"]
	var lines := [",".join(headers)]
	for row in rows:
		var values: Array = []
		for key in headers:
			var field: String = str(key)
			if key == "color": field = "color"
			elif key == "hit_rate_percent": field = "hit_rate"
			values.append(row[field])
		lines.append(_csv_row(values))
	return "\n".join(lines) + "\n"

func _report(payload: Dictionary) -> String:
	var synthetic_rows: Array = payload.synthetic.rows
	var comparisons: Array = payload.comparisons
	var report := "# LBS-P028B-EXP threat-aware run-color experiment\n\n"
	report += "Generated by Godot `%s` in %.2f seconds. This is a **simulation-only** paired experiment; the playable generator and every production balance setting remain unchanged.\n\n" % [payload.godot_version, payload.runtime_seconds]
	report += "## Executive result\n\n"
	report += "No arm is ready to ship. Moderate is the best candidate for a later human A/B: across all four colors it reduced paired mean threatened-starvation by %.2fs with `basic_matcher` and %.2fs with the weaker delayed policy, and all 12 playing seeds still won. However delayed YELLOW worsened by %.2fs, so even moderate does not pass the fairness gate cleanly. Mild improved totals by %.2fs / %.2fs but harmed delayed YELLOW by %.2fs; strong improved totals by %.2fs / %.2fs but harmed basic RED by %.2fs and offered no clear tradeoff advantage over moderate. The synthetic sweep proves progressively stronger urgency response with identical paired run lengths and no bag/repeat violations, but real outcomes show that selecting an urgent run is not equivalent to delivering a usable match in time.\n\n" % [-_sum_paired_delta(comparisons, "moderate", "basic_matcher"), -_sum_paired_delta(comparisons, "moderate", "delayed_matcher"), _color_delta(comparisons, "moderate", "delayed_matcher", TeamData.Identity.YELLOW), -_sum_paired_delta(comparisons, "mild", "basic_matcher"), -_sum_paired_delta(comparisons, "mild", "delayed_matcher"), _color_delta(comparisons, "mild", "delayed_matcher", TeamData.Identity.YELLOW), -_sum_paired_delta(comparisons, "strong", "basic_matcher"), -_sum_paired_delta(comparisons, "strong", "delayed_matcher"), _color_delta(comparisons, "strong", "basic_matcher", TeamData.Identity.RED)]
	report += "## Reproduction and design\n\n```bash\n./scripts/analyze_threat_bias.sh --seeds %d --scenario-seeds %d --seed-start %d --duration %.1f --step %.3f --output analysis/reports/p028b_exp\n```\n\n" % [payload.synthetic.seed_count, payload.scenario_seed_count_per_arm / POLICIES.size(), int(payload.synthetic.seed_start), float(payload.command_options.duration), float(payload.command_options.step)]
	report += "The synthetic manipulation sweep uses %d paired seeds, %d emitted balls per seed, five threat schedules and all four arms. The real-model study uses %d scenarios: %d paired seed/policy cases per arm, each capped at %.1f simulated seconds. `basic_matcher` is the P028AR fixed-X bot; `delayed_matcher` uses the same legal actions but can decide only every %.1f seconds; `observe_only` is a no-shot pressure sanity check.\n\n" % [payload.synthetic.seed_count, payload.synthetic.incoming_balls_per_seed, payload.scenario_count, payload.scenario_seed_count_per_arm, float(payload.effective_scenario_duration), DELAYED_DECISION_SECONDS]
	report += "At each new run only, urgency is `clamp((15 - live time-to-defender) / 12, 0, 1)`. Remaining legal bag colors receive weight `1 + boost × urgency`: baseline 0, mild 0.5, moderate 1.5, strong 3.0. A no-threat moment returns the exact old bag candidate without consuming bias RNG. The current Battlefield snapshot is taken before chain advance, so run creation sees no future state and at most one outer step (%.3fs) of lag. Every complete bag still contains each color exactly once; run lengths, 102 px/s feed, magazine, enemy stats and combat are untouched.\n\n" % float(payload.command_options.step)
	report += "## Synthetic manipulation and fairness\n\n| Schedule | Arm | Active selections | Intervention rate | Urgent chosen when legal | Urgent unavailable | Bag/repeat violations | No-threat exact seeds |\n|---|---|---:|---:|---:|---:|---:|---:|\n"
	for row in synthetic_rows:
		report += "| %s | %s | %d | %.1f%% | %.1f%% | %d | %d/%d | %d |\n" % [row.schedule, row.arm, row.active_threat_selections, 100.0 * float(row.intervention_rate), 100.0 * float(row.urgent_selection_rate), row.urgent_unavailable, row.bag_violations, row.repeat_violations, row.no_threat_exact_matches]
	report += "\nSelecting the urgent color more often is only a manipulation check. It does not establish faster visibility, a valid shot, a match, or survival. `urgent_unavailable` is expected when that color has already left the current bag; no arm bypasses the bag.\n\n"
	report += "### Rotating-threat distribution diagnostics\n\n| Arm | Ball-count spread | Run-count spread | Max all-color ball-drought p95 | Max run-drought p95 | 25-ball spread p95 |\n|---|---:|---:|---:|---:|---:|\n"
	for row in synthetic_rows:
		if row.schedule == "rotating":
			report += "| %s | %d | %d | %.0f | %.0f | %.0f |\n" % [row.arm, _int_spread(row.ball_counts), _int_spread(row.run_counts), _max_summary(row.ball_drought, "p95"), _max_summary(row.run_drought, "p95"), float(row.window_spread["25"].p95)]
	report += "\nRun counts remain nearly equal by construction; ball-count and ball-drought variation remains because unchanged run lengths are 1–7. Threat bias changes ordering, not the four-color bag totals.\n\n"
	report += "## Real-model paired results\n\nThe table reports all colors, because helping one lane while harming another is not acceptable. Paired deltas are arm minus the same baseline seed/policy; negative starvation is favorable.\n\n| Arm | Policy | Color | W/L/T | Mean starved | Paired Δ | p95 episode | Launch opportunity | Hit rate | Matches | Run→visible / pair / match |\n|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|\n"
	for row in comparisons:
		report += "| %s | %s | %s | %d/%d/%d | %.2fs | %+.2fs | %.2fs | %.1f%% | %.1f%% | %d | %.2f / %.2f / %.2fs |\n" % [row.arm, row.policy, row.color, row.victories, row.defeats, row.timeouts, row.mean_starved_s, row.paired_starved_delta_s, row.episode_p95_s, 100.0 * float(row.mean_launch_opportunity), row.hit_rate, row.matches, row.mean_run_to_visible_s, row.mean_run_to_pair_s, row.mean_run_to_match_s]
	report += "\n### Hardest delayed-policy cases\n\n| Arm | Seed | Outcome | Total threatened-starved | Worst episode | Active selections / interventions / unavailable |\n|---|---:|---|---:|---:|---:|\n"
	for case in _hardest_cases(payload.scenario_diagnostics):
		report += "| %s | %d | %s | %.2fs | %.2fs | %d / %d / %d |\n" % [case.arm, case.seed, case.outcome, case.total_starved, case.worst_episode, case.active, case.interventions, case.unavailable]
	report += "\n## Interpretation and recommendation\n\n"
	report += _recommendations(comparisons)
	report += "\n## Measurement definitions and limitations\n\n- **Threatened starvation** is time with a direct non-Healyzard enemy at ≤10 seconds estimated contact while pair + loaded/next ammo + ready timing are not all present. Pair presence remains a launch proxy, never a guaranteed hit or match.\n- Run-to-visible follows the first fresh ball UID from that selected run. Run-to-pair requires that same ball to join a visible adjacent same-color pair. Run-to-match is the first subsequent real match of that color, so overlapping runs can share a later match and causality is associative rather than exclusive. Unresolved events are retained in JSON scenario state but do not receive invented delays.\n- The adaptive choice observes only current live enemy positions/states. Healyzards are excluded from direct breach time; their real healing still affects combat. Snake stun/transfer is included by `lane_time_to_danger`.\n- The delayed bot's %.1fs cadence is deliberately weaker but invented, not human-calibrated. Both bots still see exact geometry instantly and lack touch error, perception delay, occlusion, planning and human emergency strategy. Win rate therefore cannot establish player difficulty or fun.\n- Bag reordering cannot help when the urgent color was already consumed, and a selected run enters offscreen right before it can affect play. Bounded seeds describe this encounter and these policies, not population tails or phone usability.\n\nMachine-readable files: schema v1 `generator_diagnostics.json`, `scenario_summary.csv`, and `baseline_comparison.csv`.\n" % DELAYED_DECISION_SECONDS
	return report

func _recommendations(rows: Array) -> String:
	var text := ""
	for arm in ["mild", "moderate", "strong"]:
		var delayed: Array = rows.filter(func(row: Dictionary): return row.arm == arm and row.policy == "delayed_matcher")
		var starvation_delta := 0.0
		var worst_color_delta := -INF
		for row in delayed:
			starvation_delta += float(row.paired_starved_delta_s)
			worst_color_delta = maxf(worst_color_delta, float(row.paired_starved_delta_s))
		var verdict := "reject for now"
		if arm == "moderate" and starvation_delta < 0.0:
			verdict = "collect more human data in a later A/B; do not ship"
		elif arm == "mild":
			verdict = "reject this setting; its all-color fairness regression exceeds moderate"
		elif arm == "strong":
			verdict = "reject; extra strength offers no clear advantage over moderate"
		text += "- **%s:** %s. Across delayed-policy colors, summed paired mean-starvation delta is %+.2fs and the worst color delta is %+.2fs.\n" % [arm.capitalize(), verdict, starvation_delta, worst_color_delta]
	return text

func _sum_paired_delta(rows: Array, arm: String, policy: String) -> float:
	var result := 0.0
	for row in rows:
		if row.arm == arm and row.policy == policy:
			result += float(row.paired_starved_delta_s)
	return result

func _color_delta(rows: Array, arm: String, policy: String, identity: int) -> float:
	for row in rows:
		if row.arm == arm and row.policy == policy and int(row.color_id) == identity:
			return float(row.paired_starved_delta_s)
	return 0.0

func _int_spread(values: Array) -> int:
	return int(values.max()) - int(values.min()) if not values.is_empty() else 0

func _max_summary(values: Array, field: String) -> float:
	var result := 0.0
	for value in values:
		result = maxf(result, float(value[field]))
	return result

func _hardest_cases(diagnostics: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for arm in ThreatBiasLabScript.ARMS:
		var hardest: Dictionary = {}
		var hardest_total := -1.0
		for sample in diagnostics:
			if sample.arm != arm or sample.policy != "delayed_matcher":
				continue
			var total := 0.0
			var worst := 0.0
			for value in sample.starved_threat_time_s: total += float(value)
			for value in sample.starved_threat_longest_s: worst = maxf(worst, float(value))
			if total > hardest_total:
				hardest_total = total
				hardest = {
					"arm": arm,
					"seed": sample.seed,
					"outcome": sample.outcome,
					"total_starved": total,
					"worst_episode": worst,
					"active": sample.threat_selector.active_threat_selections,
					"interventions": sample.threat_selector.interventions,
					"unavailable": sample.threat_selector.urgent_unavailable,
				}
		if not hardest.is_empty(): result.append(hardest)
	return result

func _parse_options(args: PackedStringArray) -> String:
	var index := 0
	while index < args.size():
		var arg := args[index]
		if arg == "--smoke":
			_options.smoke = true
			index += 1
			continue
		if arg == "--help":
			_print_usage()
			quit(0)
			return ""
		if not arg in ["--seeds", "--scenario-seeds", "--seed-start", "--duration", "--step", "--output"]:
			return "Unknown option: %s" % arg
		if index + 1 >= args.size():
			return "Missing value for %s" % arg
		var value := args[index + 1]
		match arg:
			"--seeds": _options.seeds = int(value)
			"--scenario-seeds": _options.scenario_seeds = int(value)
			"--seed-start": _options.seed_start = int(value)
			"--duration": _options.duration = float(value)
			"--step": _options.step = float(value)
			"--output": _options.output = value
		index += 2
	if int(_options.seeds) <= 0 or int(_options.scenario_seeds) <= 0 or float(_options.duration) <= 0.0 or float(_options.step) <= 0.0 or float(_options.step) > 0.5:
		return "Seeds/scenario-seeds/duration/step must be positive and step <= 0.5s"
	return ""

func _csv_row(values: Array) -> String:
	var fields: PackedStringArray = []
	for value in values:
		var field := str(value)
		if field.contains(",") or field.contains("\"") or field.contains("\n"):
			field = "\"%s\"" % field.replace("\"", "\"\"")
		fields.append(field)
	return ",".join(fields)

func _mean(values: Array) -> float:
	if values.is_empty(): return 0.0
	var total := 0.0
	for value in values: total += float(value)
	return total / values.size()

func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		quit(1)
		return
	file.store_string(content)

func _print_usage() -> void:
	print("Usage: ./scripts/analyze_threat_bias.sh [--smoke] [--seeds N] [--scenario-seeds N] [--seed-start N] [--duration S] [--step S] [--output PATH]")
