extends SceneTree

const DEFAULT_OUTPUT := "res://analysis/reports/p028a"

var _options := {
	"smoke": false,
	"seeds": 500,
	"seed_start": 28001,
	"duration": 120.0,
	"step": 0.1,
	"output": DEFAULT_OUTPUT,
	"policy": "all",
	"scenario": "all",
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
	var generator_seeds: int = 8 if bool(_options.smoke) else int(_options.seeds)
	var incoming_per_seed := 120 if bool(_options.smoke) else 300
	var scenario_duration: float = minf(float(_options.duration), 30.0) if bool(_options.smoke) else float(_options.duration)
	print("P028A generator sweeps: %d paired seeds x %d incoming balls" % [generator_seeds, incoming_per_seed])
	var baseline := BalanceLab.generator_sweep(int(_options.seed_start), generator_seeds, incoming_per_seed, BalanceLab.BASELINE_WEIGHTS)
	var experimental := BalanceLab.generator_sweep(int(_options.seed_start), generator_seeds, incoming_per_seed, BalanceLab.EXPERIMENTAL_WEIGHTS)
	var scenarios: Array[Dictionary] = []
	var plans := _scenario_plans(bool(_options.smoke))
	print("P028A physical/combat scenarios: %d cases, %.1fs max, %.3fs outer step" % [plans.size(), scenario_duration, float(_options.step)])
	for index in range(plans.size()):
		var plan: Dictionary = plans[index]
		print("  [%d/%d] seed=%d policy=%s speed=%d weights=%s" % [index + 1, plans.size(), int(plan.seed), str(plan.policy), int(plan.speed), str(plan.weights_label)])
		var scenario: Dictionary = await BalanceLab.run_scenario(self, int(plan.seed), scenario_duration, float(_options.step), str(plan.policy), float(plan.speed), plan.weights)
		scenario.weights_label = plan.weights_label
		scenario.series = plan.series
		scenarios.append(scenario)
	var comparison := _aggregate_comparisons(scenarios)
	var elapsed_seconds := (Time.get_ticks_msec() - started) / 1000.0
	var payload := {
		"schema_version": 2,
		"task": "LBS-P028AR",
		"generated_utc": Time.get_datetime_string_from_system(true),
		"godot_version": Engine.get_version_info().string,
		"command_options": _options.duplicate(true),
		"runtime_seconds": elapsed_seconds,
		"metric_definitions": {
			"fresh_counts": "Weighted-run generator output only; excludes the fixed 12-ball starter preset.",
			"visible_mean": "Time-weighted mean circles intersecting [0,lane_width]; off-left/right history is unavailable.",
			"match_opportunity": "A visible adjacent same-color pair within 1.25 spacing: a launch-time proxy, not a guaranteed hit or match.",
			"shot_trajectory": "The bot freezes current target X at launch; after exactly 0.20s of chain movement, actual try_insert_shot collision runs only at that immutable X.",
			"ammo_available_fraction": "Fraction of simulated time the color is loaded or next; it does not imply chain geometry.",
			"starved_threat": "Enemy estimated <=10s from defender while pair+ammo+ready timing are not all simultaneously available.",
		},
		"generator": {"baseline": baseline, "experimental_run_weights": experimental},
		"scenarios": scenarios,
		"comparison": comparison,
	}
	var output_path := str(_options.output)
	if output_path.begins_with("res://"):
		output_path = ProjectSettings.globalize_path(output_path)
	var error := DirAccess.make_dir_recursive_absolute(output_path)
	if error != OK:
		push_error("Could not create output directory %s (error %d)" % [output_path, error])
		quit(1)
		return
	_write_text(output_path.path_join("baseline.json"), JSON.stringify(payload, "  ") + "\n")
	_write_text(output_path.path_join("scenario_summary.csv"), _scenario_csv(scenarios))
	_write_text(output_path.path_join("comparison.csv"), _comparison_csv(comparison))
	_write_text(output_path.path_join("REPORT.md"), _report(payload))
	print("P028A balance lab: PASS in %.2fs; outputs=%s" % [elapsed_seconds, output_path])
	quit(0)

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
		if not arg in ["--seeds", "--seed-start", "--duration", "--step", "--output", "--policy", "--scenario"]:
			return "Unknown option: %s" % arg
		if index + 1 >= args.size():
			return "Missing value for %s" % arg
		var value := args[index + 1]
		match arg:
			"--seeds": _options.seeds = int(value)
			"--seed-start": _options.seed_start = int(value)
			"--duration": _options.duration = float(value)
			"--step": _options.step = float(value)
			"--output": _options.output = value
			"--policy": _options.policy = value
			"--scenario": _options.scenario = value
		index += 2
	if int(_options.seeds) <= 0 or float(_options.duration) <= 0.0 or float(_options.step) <= 0.0 or float(_options.step) > 0.5:
		return "Seeds/duration/step must be positive and step must be <=0.5s"
	if not str(_options.policy) in ["all", "observe_only", "basic_matcher", "threat_priority"]:
		return "Policy must be all, observe_only, basic_matcher, or threat_priority"
	if not str(_options.scenario) in ["all", "baseline", "comparison"]:
		return "Scenario must be all, baseline, or comparison"
	return ""

func _scenario_plans(smoke: bool) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	var requested_policy := str(_options.policy)
	var requested_scenario := str(_options.scenario)
	if smoke:
		var policies := ["observe_only", "basic_matcher", "threat_priority"] if requested_policy == "all" else [requested_policy]
		for index in range(mini(3, policies.size())):
			plans.append(_plan(int(_options.seed_start) + index, str(policies[index]), 102.0, BalanceLab.BASELINE_WEIGHTS, "baseline", "smoke"))
		return plans
	if requested_scenario in ["all", "baseline"]:
		var policies := ["observe_only", "basic_matcher", "threat_priority"] if requested_policy == "all" else [requested_policy]
		for policy in policies:
			for offset in range(3):
				plans.append(_plan(int(_options.seed_start) + offset, str(policy), 102.0, BalanceLab.BASELINE_WEIGHTS, "baseline", "policy_baseline"))
	if requested_scenario in ["all", "comparison"]:
		var policy := "basic_matcher" if requested_policy == "all" else requested_policy
		for speed in BalanceLab.SPEEDS:
			for weights_case in [{"label": "baseline", "weights": BalanceLab.BASELINE_WEIGHTS}, {"label": "experimental", "weights": BalanceLab.EXPERIMENTAL_WEIGHTS}]:
				for offset in range(2):
					plans.append(_plan(int(_options.seed_start) + 100 + offset, policy, speed, weights_case.weights, weights_case.label, "speed_weights"))
	return plans

func _plan(seed_value: int, policy: String, speed: float, weights: Array[int], label: String, series: String) -> Dictionary:
	return {"seed": seed_value, "policy": policy, "speed": speed, "weights": weights.duplicate(), "weights_label": label, "series": series}

func _aggregate_comparisons(scenarios: Array[Dictionary]) -> Array[Dictionary]:
	var groups := {}
	for scenario in scenarios:
		var key := "%s|%s|%d|%s" % [str(scenario.series), str(scenario.weights_label), int(scenario.speed), str(scenario.policy)]
		if not groups.has(key):
			groups[key] = {"series": scenario.series, "weights_label": scenario.weights_label, "speed": scenario.speed, "policy": scenario.policy, "samples": []}
		groups[key].samples.append(scenario)
	var rows: Array[Dictionary] = []
	for key in groups:
		var group: Dictionary = groups[key]
		var samples: Array = group.samples
		var outcomes := {"victory": 0, "defeat": 0, "timeout": 0}
		var visible_green := 0.0
		var absent_green := 0.0
		var starved_green := 0.0
		var shots := 0
		var arrivals := 0
		var insertions := 0
		var misses := 0
		var nonmatches := 0
		var original_contacts := 0
		var off_target_insertions := 0
		var matches := 0
		var neutralized := 0
		for sample in samples:
			outcomes[str(sample.outcome)] += 1
			visible_green += float(sample.visible_mean[TeamData.Identity.GREEN])
			absent_green += float(sample.match_opportunity_absent_longest_s[TeamData.Identity.GREEN])
			starved_green += float(sample.starved_threat_time_s[TeamData.Identity.GREEN])
			shots += int(sample.counts.shots)
			arrivals += int(sample.counts.shot_arrivals)
			insertions += int(sample.counts.insertions)
			misses += int(sample.counts.shot_misses)
			nonmatches += int(sample.counts.nonmatched_insertions)
			original_contacts += int(sample.counts.original_target_contacts)
			off_target_insertions += int(sample.counts.off_target_insertions)
			matches += int(sample.counts.matches)
			neutralized += int(sample.neutralized)
		rows.append({
			"series": group.series,
			"weights_label": group.weights_label,
			"speed": group.speed,
			"policy": group.policy,
			"scenario_count": samples.size(),
			"victories": outcomes.victory,
			"defeats": outcomes.defeat,
			"timeouts": outcomes.timeout,
			"mean_visible_green": visible_green / samples.size(),
			"mean_longest_green_match_drought_s": absent_green / samples.size(),
			"mean_green_starved_threat_s": starved_green / samples.size(),
			"shots": shots,
			"arrivals": arrivals,
			"insertions": insertions,
			"misses": misses,
			"hit_rate": 100.0 * insertions / maxf(arrivals, 1.0),
			"nonmatched_insertions": nonmatches,
			"original_target_contacts": original_contacts,
			"off_target_insertions": off_target_insertions,
			"matches": matches,
			"neutralized": neutralized,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary):
		var ka := "%s|%s|%03d|%s" % [a.series, a.weights_label, int(a.speed), a.policy]
		var kb := "%s|%s|%03d|%s" % [b.series, b.weights_label, int(b.speed), b.policy]
		return ka < kb
	)
	return rows

func _scenario_csv(scenarios: Array[Dictionary]) -> String:
	var headers := ["seed", "series", "policy", "speed", "weights", "duration_s", "outcome", "fresh_red", "fresh_blue", "fresh_yellow", "fresh_green", "visible_red", "visible_blue", "visible_yellow", "visible_green", "match_drought_red_s", "match_drought_blue_s", "match_drought_yellow_s", "match_drought_green_s", "ammo_red", "ammo_blue", "ammo_yellow", "ammo_green", "fired_red", "fired_blue", "fired_yellow", "fired_green", "matches_red", "matches_blue", "matches_yellow", "matches_green", "starved_red_s", "starved_blue_s", "starved_yellow_s", "starved_green_s", "shots", "arrivals", "insertions", "misses", "original_target_contacts", "off_target_insertions", "nonmatches", "min_shot_interval_s", "min_flight_s", "max_flight_s", "swaps", "damage_hits", "kills", "healer_pulses", "knockdowns", "revivals", "breaches", "spawned", "neutralized", "score"]
	var lines := [",".join(headers)]
	for s in scenarios:
		var values: Array = [s.seed, s.series, s.policy, s.speed, s.weights_label, s.duration_simulated, s.outcome]
		values.append_array(s.fresh_counts)
		values.append_array(s.visible_mean)
		values.append_array(s.match_opportunity_absent_longest_s)
		values.append_array(s.ammo_available_fraction)
		values.append_array(s.fired_counts)
		values.append_array(s.match_counts)
		values.append_array(s.starved_threat_time_s)
		values.append_array([s.counts.shots, s.counts.shot_arrivals, s.counts.insertions, s.counts.shot_misses, s.counts.original_target_contacts, s.counts.off_target_insertions, s.counts.nonmatched_insertions, s.minimum_shot_interval, s.minimum_flight_time, s.maximum_flight_time, s.counts.swaps, s.counts.damage_hits, s.counts.kills, s.counts.healer_pulses, s.counts.knockdowns, s.counts.revivals, s.counts.breaches, s.spawned, s.neutralized, s.score])
		lines.append(_csv_row(values))
	return "\n".join(lines) + "\n"

func _comparison_csv(rows: Array[Dictionary]) -> String:
	var headers := ["series", "weights", "speed", "policy", "scenarios", "victories", "defeats", "timeouts", "mean_visible_green", "mean_longest_green_match_drought_s", "mean_green_starved_threat_s", "shots", "arrivals", "insertions", "misses", "hit_rate_percent", "nonmatched_insertions", "original_target_contacts", "off_target_insertions", "matches", "neutralized"]
	var lines := [",".join(headers)]
	for row in rows:
		lines.append(_csv_row([row.series, row.weights_label, row.speed, row.policy, row.scenario_count, row.victories, row.defeats, row.timeouts, row.mean_visible_green, row.mean_longest_green_match_drought_s, row.mean_green_starved_threat_s, row.shots, row.arrivals, row.insertions, row.misses, row.hit_rate, row.nonmatched_insertions, row.original_target_contacts, row.off_target_insertions, row.matches, row.neutralized]))
	return "\n".join(lines) + "\n"

func _report(payload: Dictionary) -> String:
	var baseline: Dictionary = payload.generator.baseline
	var experimental: Dictionary = payload.generator.experimental_run_weights
	var scenarios: Array = payload.scenarios
	var worst: Dictionary = {}
	var worst_value := -1.0
	for scenario in scenarios:
		if str(scenario.policy) == "observe_only":
			continue
		for identity in range(TeamData.COUNT):
			var value := float(scenario.starved_threat_longest_s[identity])
			if value > worst_value:
				worst_value = value
				worst = {"seed": scenario.seed, "policy": scenario.policy, "speed": scenario.speed, "weights": scenario.weights_label, "identity": identity, "seconds": value, "reasons": scenario.starvation_reasons_s, "ammo": scenario.ammo_available_fraction[identity], "match_drought": scenario.match_opportunity_absent_longest_s[identity]}
	var green_delta := float(baseline.fresh_percent[TeamData.Identity.GREEN]) - 25.0
	var generation_finding := "GREEN is not structurally underweighted" if absf(green_delta) < 0.5 else "GREEN differs enough from 25% in this bounded sweep to merit another larger sweep"
	var report := "# LBS-P028AR corrected deterministic balancing laboratory\n\n"
	report += "Generated by Godot `%s` in %.2f seconds. P028AR removes the original lab's impossible target-UID homing: every bot shot now keeps one immutable launch X for its complete 0.20-second flight. This is an **analysis-only** artifact; no production speed, colors, spawning, HP, controls, or weights were changed.\n\n" % [payload.godot_version, payload.runtime_seconds]
	report += "## Reproduction and provenance\n\n"
	report += "```bash\n./scripts/analyze_balance.sh --seeds %d --seed-start %d --duration %.1f --step %.3f --output analysis/reports/p028a\n```\n\n" % [baseline.seed_count, baseline.seed_start, float(payload.command_options.duration), float(payload.command_options.step)]
	report += "The generator sweep uses paired source seeds `%d..%d`, %d fresh balls per seed (%d total per weight set). Each source seed expands through the documented `seed_tuple` into independent chain, magazine, spawn, attack and Snake seeds. The scenario table contains %d bounded real-model cases.\n\n" % [baseline.seed_start, baseline.seed_start + baseline.seed_count - 1, baseline.incoming_per_seed, baseline.seed_count * baseline.incoming_per_seed, scenarios.size()]
	report += "## Definitions and fidelity\n\n"
	report += "- **Starter** is the fixed 12-ball `SEED_PATTERN`, reported separately from weighted fresh generation.\n- **Visible** means a physical ball circle intersects `[0, lane_width]`; retained off-left history and clipped right feed do not count as available.\n- **Launch opportunity** is a visible, physically adjacent same-color pair plus loaded/next ammo and a ready 0.4-second cooldown. It is a proxy, **not a guaranteed hit or match**.\n- At firing, both matcher policies store the selected left ball's current X minus one pixel, clamped to `[0, lane_width]`. That X never changes. The chain advances precisely to the 0.20-second arrival boundary before the real `try_insert_shot()` collision; a reporting `target_uid` cannot affect collision. No predictive lead is used. Gravity, speed, another ball crossing the axis or target removal may cause a miss or off-target insertion.\n- Only actual `match_completed` events feed real `MatchProgression` and `Battlefield.handle_match`; pre-existing triples never auto-pop. **Threat starvation** measures an enemy estimated within 10 s of its defender while a launch opportunity is missing.\n- Hopper time-to-danger uses its authoritative average movement speed; Snake stun/transfer delay is included; stationary Healyzards have no direct arrival time. This remains an estimate.\n\n"
	report += "## Fresh color generation\n\n| Color | Balls | Ball percent | Run-color percent | Drought p50 | Drought p95 | Worst |\n|---|---:|---:|---:|---:|---:|---:|\n"
	for identity in range(TeamData.COUNT):
		var d: Dictionary = baseline.drought_summary[identity]
		report += "| %s | %d | %.3f%% | %.3f%% | %.0f | %.0f | %.0f |\n" % [TeamData.display_name(identity), int(baseline.fresh_counts[identity]), float(baseline.fresh_percent[identity]), float(baseline.run_color_percent[identity]), float(d.p50), float(d.p95), float(d.worst)]
	report += "\nFixed starter counts are `%s`; they are not included above. %s (GREEN delta from equal share: %+.3f percentage points). The color-of-runs bag is balanced by construction, while variable run lengths create bounded ball-count variance in short windows.\n\n" % [str(baseline.starting_preset_counts), generation_finding, green_delta]
	report += "### Rolling-window maximum spread (most common minus least common color)\n\n| Window | p50 | p95 | Worst |\n|---:|---:|---:|---:|\n"
	for window in BalanceLab.WINDOW_SIZES:
		var summary: Dictionary = baseline.window_spread_summary[str(window)]
		report += "| %d | %.0f | %.0f | %.0f |\n" % [window, float(summary.p50), float(summary.p95), float(summary.worst)]
	report += "\n## Run-length experiment\n\n| Length | Baseline % runs | Baseline % balls | Experimental % runs | Experimental % balls |\n|---:|---:|---:|---:|---:|\n"
	for index in range(7):
		report += "| %d | %.2f%% | %.2f%% | %.2f%% | %.2f%% |\n" % [index + 1, float(baseline.run_length_percent_of_runs[index]), float(baseline.run_length_percent_of_balls[index]), float(experimental.run_length_percent_of_runs[index]), float(experimental.run_length_percent_of_balls[index])]
	report += "\nA length-7 run's share of **runs** and **balls** is intentionally shown separately: long runs occupy disproportionately more conveyor space. The exploratory distribution makes length 3 common and 5/7 rare, but it remains test-only.\n\n"
	report += "## Physical chain, fixed-X shots, ammo and combat scenarios\n\n| Series | Weights | Speed | Policy | N | W/L/T | Hit rate | Misses | Nonmatch inserts | GREEN pair drought | Matches | Neutralized |\n|---|---|---:|---|---:|---|---:|---:|---:|---:|---:|---:|\n"
	for row in payload.comparison:
		report += "| %s | %s | %.0f | %s | %d | %d/%d/%d | %.1f%% | %d | %d | %.2fs | %d | %d |\n" % [row.series, row.weights_label, float(row.speed), row.policy, row.scenario_count, row.victories, row.defeats, row.timeouts, float(row.hit_rate), row.misses, row.nonmatched_insertions, float(row.mean_longest_green_match_drought_s), row.matches, row.neutralized]
	var color_summary := _policy_color_summary(scenarios, "policy_baseline", "basic_matcher")
	report += "\n### Baseline basic-matcher availability by color (three paired policy seeds)\n\n| Color | Mean visible | Pair-drought p50 | Pair-drought p95/worst | Mean loaded-or-next | Mean threatened-starved |\n|---|---:|---:|---:|---:|---:|\n"
	for identity in range(TeamData.COUNT):
		var color: Dictionary = color_summary[identity]
		report += "| %s | %.2f | %.2fs | %.2fs | %.1f%% | %.2fs |\n" % [TeamData.display_name(identity), color.mean_visible, color.drought_p50, color.drought_p95, 100.0 * color.mean_ammo, color.mean_starved]
	report += "\n`observe_only` deliberately never fires and is expected to lose; its 0% hit rate means no arrivals, not failed aim. `basic_matcher` chooses loaded before next and swaps only when next has a visible pair. `threat_priority` uses the same legal actions but prefers the loaded/next color with lowest estimated time-to-danger. Both freeze current X at launch. JSON/CSV distinguish original-target contact from another current ball legitimately crossing the fixed axis. These deterministic policies are measurement instruments, not human-skill models.\n\n"
	report += "## Worked worst threatened-lane trace\n\nSeed `%d`, `%s`, speed %.0f, `%s` weights: %s lane remained non-usable for %.2fs at worst. Aggregate attribution in that run was chain geometry `%.2fs`, ammo `%.2fs`, cooldown/flight timing `%.2fs`; that lane's loaded-or-next availability was %.1f%% and its longest adjacent-pair drought was %.2fs. This trace identifies the causal bottleneck without claiming the bot made human-optimal choices.\n\n" % [worst.seed, worst.policy, float(worst.speed), worst.weights, TeamData.display_name(int(worst.identity)), float(worst.seconds), float(worst.reasons.chain), float(worst.reasons.ammo), float(worst.reasons.timing), 100.0 * float(worst.ammo), float(worst.match_drought)]
	report += "## Findings and P028B recommendations\n\n"
	report += "1. **GREEN generation:** %s. The 500-seed generator figures are unchanged by P028AR, but generation equality does not prove visible or human-usable equality. Pair availability is only a launch proxy and corrected shots can miss.\n" % generation_finding
	report += "2. **Long runs:** use the run-vs-ball shares above. A small run percentage can still dominate generated balls and perceived clusters. The experimental weights are the cleanest P028B candidate because they target cluster shape without color favoritism.\n"
	report += "3. **Speed:** in the paired two-seed baseline set, GREEN pair drought fell from 11.45s at 102 to 10.95s at 120 and 9.45s at 140, but fixed-X hit rate also fell from 88.5% to 87.0% and 82.8%. All 2/2 cases still won at every speed, demonstrating that this bot remains too strong and the sample too small—not that acceleration is safe. Faster motion tightens human touch timing, so no live speed increase is recommended from these data alone.\n"
	report += "4. **P028B experiment:** exploratory weights at 102 reduced paired GREEN pair drought from 11.45s to 8.75s but also reduced hit rate from 88.5% to 82.1%; only two combat seeds were used. Human phone A/B should precede any run-weight or speed decision. If threat starvation remains color-specific after controlling geometry and ammo, separately test a soft recent-ball deficit cap without guaranteed rescue colors.\n\n"
	report += "## Limitations\n\nThe lab uses authentic models but not `Main`'s rendered input/SFX loop. Fixed-X timing and collision now match the playable rule, but the bot selects exact pair centers instantly at decision samples; it has no finger error, perception delay, touch occlusion, predictive lead, multi-shot setup search or strategic emergency timing. An insertion may legitimately hit a different ball crossing the axis, and not every insertion matches. Time-to-danger approximates Hopper hopping by average speed and treats Healyzard as pressure through healing rather than a direct breach clock. All matcher scenarios still won, confirming bot win rate cannot establish human difficulty. Scenario sensitivity cells contain only two seeds, so tails are descriptive rather than population estimates. Android device playtesting remains required.\n\nMachine-readable details: schema v2 `baseline.json`, `scenario_summary.csv`, and `comparison.csv`.\n"
	return report

func _policy_color_summary(scenarios: Array, series: String, policy: String) -> Array[Dictionary]:
	var selected: Array = scenarios.filter(func(item: Dictionary): return str(item.series) == series and str(item.policy) == policy)
	if selected.is_empty():
		selected = scenarios.filter(func(item: Dictionary): return str(item.policy) == policy)
	var result: Array[Dictionary] = []
	for identity in range(TeamData.COUNT):
		var visible := 0.0
		var ammo := 0.0
		var starved := 0.0
		var droughts: Array = []
		for sample in selected:
			visible += float(sample.visible_mean[identity])
			ammo += float(sample.ammo_available_fraction[identity])
			starved += float(sample.starved_threat_time_s[identity])
			droughts.append(float(sample.match_opportunity_absent_longest_s[identity]))
		var count := maxf(selected.size(), 1.0)
		result.append({"mean_visible": visible / count, "drought_p50": BalanceLab.percentile(droughts, 0.50), "drought_p95": BalanceLab.percentile(droughts, 0.95), "mean_ammo": ammo / count, "mean_starved": starved / count})
	return result

func _csv_row(values: Array) -> String:
	var fields: PackedStringArray = []
	for value in values:
		var field := str(value)
		if field.contains(",") or field.contains("\"") or field.contains("\n"):
			field = "\"%s\"" % field.replace("\"", "\"\"")
		fields.append(field)
	return ",".join(fields)

func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % path)
		quit(1)
		return
	file.store_string(content)

func _print_usage() -> void:
	print("Usage: ./scripts/analyze_balance.sh [--smoke] [--seeds N] [--seed-start N] [--duration S] [--step S] [--output PATH] [--policy all|observe_only|basic_matcher|threat_priority] [--scenario all|baseline|comparison]")
