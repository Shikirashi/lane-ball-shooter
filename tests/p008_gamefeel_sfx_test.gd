extends SceneTree

const LayoutCalculator = preload("res://scripts/responsive_layout.gd")
const SfxManagerScript = preload("res://scripts/audio/sfx_manager.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _result(identity: int, tier := 1) -> Dictionary:
	return {"identity": identity, "tier": tier, "fever": tier >= 3, "group_size": 3, "combo_count": tier, "points": 100}

func _set_hop_clock(model: LaneCombatModel, clock: float) -> void:
	var enemy := model.enemies[0]
	enemy.hop_clock = clock
	enemy.hop_airborne = clock >= LaneCombatModel.HOP_GROUND_DURATION
	enemy.hop_progress = clampf((clock - LaneCombatModel.HOP_GROUND_DURATION) / LaneCombatModel.HOP_AIR_DURATION, 0.0, 1.0) if bool(enemy.hop_airborne) else 0.0
	model.enemies[0] = enemy

func _run() -> void:
	await _test_shot_travel_all_layouts()
	_test_enemy_half_speed()
	_test_weighted_generator()
	_test_player_triggered_matching()
	await _test_sfx_synthesis_and_voice_bounds()
	await _test_semantic_sfx_routing()
	_finish()

func _test_shot_travel_all_layouts() -> void:
	_check(is_equal_approx(ShooterView.SHOT_TRAVEL_TIME, 0.20), "shot travel target is exactly 0.20 seconds")
	for viewport_size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]:
		var layout := LayoutCalculator.calculate(viewport_size, Rect2(Vector2.ZERO, viewport_size))
		var shooter := ShooterView.new()
		root.add_child(shooter)
		shooter.configure_layout(layout.shooter_y, layout.track_left, layout.track_right, layout.shot_ceiling)
		var launch_x: float = (float(layout.track_left) + float(layout.track_right)) * 0.5
		shooter.move_to(launch_x)
		var arrivals: Array[Dictionary] = []
		shooter.shot_reached_lane.connect(func(identity: int, impact_x: float) -> void:
			arrivals.append({"identity": identity, "x": impact_x})
		)
		shooter.launch(TeamData.Identity.YELLOW)
		shooter._process(0.10)
		_check(arrivals.is_empty() and shooter.get("_shots").size() == 1, "%s shot remains visible at 0.10s" % viewport_size)
		shooter.move_to(float(layout.track_right))
		shooter._process(0.099)
		_check(arrivals.is_empty(), "%s shot does not arrive before 0.20s" % viewport_size)
		shooter._process(0.0011)
		_check(arrivals.size() == 1 and int(arrivals[0].identity) == TeamData.Identity.YELLOW, "%s shot arrives exactly once around 0.20s" % viewport_size)
		_check(is_equal_approx(float(arrivals[0].x), launch_x), "%s moving shooter does not steer launched shot" % viewport_size)
		shooter._process(0.5)
		_check(arrivals.size() == 1 and shooter.get("_shots").is_empty(), "%s completed shot cannot emit twice" % viewport_size)
		shooter.queue_free()
		await process_frame

	var large_step := ShooterView.new()
	root.add_child(large_step)
	large_step.configure_layout(680.0, 40.0, 1200.0, 120.0)
	var events := {"count": 0}
	large_step.shot_reached_lane.connect(func(_identity: int, _x: float) -> void: events.count += 1)
	large_step.launch(TeamData.Identity.RED)
	large_step._process(0.5)
	large_step._process(0.5)
	_check(int(events.count) == 1 and large_step.get("_shots").is_empty(), "large delta crosses lane once and consumes shot")
	large_step.queue_free()
	await process_frame

	var resized := ShooterView.new()
	root.add_child(resized)
	resized.configure_layout(680.0, 40.0, 1200.0, 120.0)
	var resize_events := {"count": 0}
	resized.shot_reached_lane.connect(func(_identity: int, _x: float) -> void: resize_events.count += 1)
	resized.launch(TeamData.Identity.BLUE)
	resized._process(0.1)
	resized.configure_layout(500.0, 30.0, 900.0, 80.0)
	resized._process(0.1)
	_check(int(resize_events.count) == 1 and resized.get("_shots").is_empty(), "resize during flight preserves one sensible 0.20s termination")
	resized.queue_free()
	await process_frame

func _test_enemy_half_speed() -> void:
	_check(is_equal_approx(LaneCombatModel.DEFAULT_ENEMY_SPEED, 0.24), "enemy average speed is exactly 0.24 units/s")
	var grounded := LaneCombatModel.new(TeamData.Identity.RED)
	grounded.clear_for_test()
	grounded.spawn_enemy(5.0, 2)
	_set_hop_clock(grounded, 0.1)
	grounded.update(0.2)
	_check(is_equal_approx(float(grounded.enemies[0].x), 5.0), "grounded enemy has zero horizontal drift")
	grounded.update(0.4)
	_check(float(grounded.enemies[0].x) < 5.0, "airborne enemy moves left")

	var cycle := LaneCombatModel.new(TeamData.Identity.BLUE)
	cycle.clear_for_test()
	cycle.spawn_enemy(6.0, 2)
	_set_hop_clock(cycle, 0.0)
	var duration := LaneCombatModel.HOP_CYCLE_DURATION * 8.0
	cycle.update(duration)
	_check(is_equal_approx((6.0 - float(cycle.enemies[0].x)) / duration, 0.24), "complete hop cycles average 0.24 units/s")

	var one_step := LaneCombatModel.new(TeamData.Identity.GREEN)
	var split_step := LaneCombatModel.new(TeamData.Identity.GREEN)
	for model in [one_step, split_step]:
		model.clear_for_test()
		model.spawn_enemy(5.0, 2)
		_set_hop_clock(model, 0.2)
	one_step.update(5.7)
	for unused in range(57):
		split_step.update(0.1)
	_check(is_equal_approx(float(one_step.enemies[0].x), float(split_step.enemies[0].x)), "half-speed hop is subdivision independent")

	var collision := LaneCombatModel.new(TeamData.Identity.YELLOW)
	collision.clear_for_test()
	collision.spawn_enemy(1.0, 1)
	_set_hop_clock(collision, LaneCombatModel.HOP_GROUND_DURATION + 0.2)
	collision.fire_attack(_result(TeamData.Identity.YELLOW))
	collision.update(2.0)
	_check(collision.total_killed == 1, "piecewise swept projectile still hits half-speed hopper")

	var emergency := LaneCombatModel.new(TeamData.Identity.RED)
	emergency.clear_for_test()
	emergency.spawn_enemy(LaneCombatModel.DEFENDER_X + 0.2, 2)
	_set_hop_clock(emergency, LaneCombatModel.HOP_GROUND_DURATION)
	emergency.update(2.0)
	_check(emergency.defender_state == LaneCombatModel.DefenderState.DOWN and emergency.enemies.is_empty(), "half-speed hop crossing resolves emergency before breach")

	var breach := LaneCombatModel.new(TeamData.Identity.BLUE)
	breach.clear_for_test()
	breach.defender_state = LaneCombatModel.DefenderState.DOWN
	breach.emergency_available = false
	breach.spawn_enemy(LaneCombatModel.LEFT_BOUNDARY + 0.1, 2)
	_set_hop_clock(breach, LaneCombatModel.HOP_GROUND_DURATION)
	breach.update(1.0)
	_check(breach.game_over, "half-speed living hop still triggers terminal breach")

func _draw_sequence(seed_value: int, count: int) -> Array[int]:
	var model := ChainModel.new()
	model.set_fresh_seed(seed_value)
	var result: Array[int] = []
	for unused in range(count):
		result.append(model._draw_fresh_identity())
	return result

func _test_weighted_generator() -> void:
	_check(ChainModel.FRESH_RUN_LENGTH_WEIGHTS == [20, 30, 18, 13, 9, 6, 4], "fresh run weights match approved 1-7 distribution")
	var sequence := _draw_sequence(0x8008, 1200)
	_check(sequence == _draw_sequence(0x8008, 1200), "weighted fresh generator is reproducible by seed")
	var duplicate_pairs := 0
	var longest := 1
	var current := 1
	var colors := {}
	for index in range(sequence.size()):
		colors[sequence[index]] = true
		if index > 0 and sequence[index] == sequence[index - 1]:
			duplicate_pairs += 1
			current += 1
			longest = maxi(longest, current)
		elif index > 0:
			current = 1
	_check(duplicate_pairs > 500, "weighted stream produces frequent consecutive duplicate pairs")
	_check(longest >= 7, "known deterministic stream demonstrates a run of at least seven")
	_check(colors.size() == TeamData.COUNT, "all four fresh colors remain represented")

	var stats := ChainModel.new()
	stats.set_fresh_seed(0x8008)
	for unused in range(1200):
		stats._draw_fresh_identity()
	_check(stats.fresh_run_length_counts[3] > 0 and stats.fresh_run_length_counts[6] > 0, "run counters demonstrate lengths four and seven")
	_check(stats.fresh_runs_generated > 0 and stats.longest_fresh_run == 7, "fresh generator exposes bounded statistical counters")
	var minimum_count: int = stats.fresh_identity_counts.min()
	var maximum_count: int = stats.fresh_identity_counts.max()
	_check(maximum_count - minimum_count < 100, "run-color bag keeps long-run color representation balanced")
	var reset_generator := ChainModel.new()
	reset_generator.set_fresh_seed(0x8800)
	var before_reset: Array[int] = []
	for unused in range(40):
		before_reset.append(reset_generator._draw_fresh_identity())
	reset_generator.reset_run()
	var after_reset: Array[int] = []
	for unused in range(40):
		after_reset.append(reset_generator._draw_fresh_identity())
	_check(after_reset == before_reset, "restart resets weighted run generator and counters deterministically")

	var stream := ChainModel.new()
	var max_live := stream.balls.size()
	for unused in range(1400):
		stream.advance(0.1)
		max_live = maxi(max_live, stream.balls.size())
	_check(stream.total_fresh_generated > 100 and max_live <= stream.max_auto_population, "weighted feeder remains infinite and live-population bounded")

func _test_player_triggered_matching() -> void:
	var seeded := ChainModel.new()
	var seeded_before := seeded.identities()
	seeded.advance(4.0)
	_check(seeded.total_match_events == 0 and seeded.identities().slice(0, 4) == seeded_before.slice(0, 4), "seeded long groups move without passive clearing")

	var seven: Array[int] = []
	for unused in range(7):
		seven.append(TeamData.Identity.GREEN)
	var passive := ChainModel.new()
	passive.set_test_state(seven, 200.0)
	passive.advance(1.0)
	_check(passive.identities() == seven and passive.total_match_events == 0, "seven touching GREEN balls remain until player insertion")
	passive.try_insert_shot(TeamData.Identity.RED, float(passive.balls[3].display_x) + 4.0)
	_check(passive.total_match_events == 0 and passive.balls.size() == 8, "wrong-color insertion does not clear pre-existing seven group")

	var matching := ChainModel.new()
	matching.set_test_state(seven, 200.0)
	matching.try_insert_shot(TeamData.Identity.GREEN, float(matching.balls[3].display_x) + 4.0)
	_check(matching.total_match_events == 1 and matching.last_match_size == 8, "matching insertion clears seven-plus-shot as one eight-ball event")

	var unrelated_state := seven.duplicate()
	unrelated_state.append(TeamData.Identity.RED)
	unrelated_state.append(TeamData.Identity.RED)
	var unrelated := ChainModel.new()
	unrelated.set_test_state(unrelated_state, 100.0)
	unrelated.try_insert_shot(TeamData.Identity.RED, float(unrelated.balls[-1].display_x) + 4.0)
	_check(unrelated.total_match_events == 1 and unrelated.last_match_identity == TeamData.Identity.RED, "shot clears only its corresponding group")
	_check(unrelated.identities().slice(0, 7) == seven, "unrelated passive seven group survives another group match")

	var cached: Array[int] = seven.duplicate()
	var cache_merge := ChainModel.new()
	var blue: Array[int] = [TeamData.Identity.BLUE]
	cache_merge.set_test_state(blue, 100.0, cached)
	cache_merge.return_cached(7)
	cache_merge.advance(20.0)
	_check(cache_merge.total_match_events == 0, "cache return and gap closure never passively clear a long run")

func _test_sfx_synthesis_and_voice_bounds() -> void:
	var sfx := SfxManagerScript.new()
	root.add_child(sfx)
	await process_frame
	_check(sfx.get("_voices").size() == SfxManagerScript.VOICE_COUNT, "SFX manager creates bounded ten-voice pool")
	for cue in SfxManagerScript.CUE_NAMES:
		var variants := [1, 2, 3] if cue == "attack" else [1]
		for variant in variants:
			var duration := sfx.clip_duration(cue, variant)
			var peak := sfx.clip_peak(cue, variant)
			_check(duration >= 0.045 and duration <= 0.35, "%s clip duration is short and bounded" % sfx._clip_key(cue, variant))
			_check(peak > 0.02 and peak <= SfxManagerScript.MAX_PCM_AMPLITUDE + 0.001, "%s PCM has gentle nonzero amplitude" % sfx._clip_key(cue, variant))
	for index in range(50):
		sfx.play_cue(SfxManagerScript.CUE_NAMES[index % SfxManagerScript.CUE_NAMES.size()], (index % 3) + 1)
	_check(sfx.active_voice_count() <= SfxManagerScript.VOICE_COUNT, "simultaneous cue flood cannot exceed voice pool")
	sfx.stop_all()
	sfx.queue_free()
	await process_frame

func _test_semantic_sfx_routing() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var sfx = main.get("_sfx")
	var shooter: ShooterView = main.get("_shooter_view")
	var chain: ChainModel = main.get("_chain_model")
	var battlefield: Battlefield = main.get("_battlefield")
	var magazine: MagazineState = main.get("_magazine")

	var draws_before := magazine.draw_count
	main.call("_shoot")
	main.call("_shoot")
	_check(int(sfx.play_counts.shoot) == 1 and magazine.draw_count == draws_before + 1, "accepted shot sounds once while cooldown blocks duplicate")
	shooter._process(ShooterView.SHOT_TRAVEL_TIME)
	_check(int(sfx.play_counts.insert) == 0, "missed shot has shoot cue but no insertion cue")

	main.set("_cooldown_remaining", 0.0)
	var one_blue: Array[int] = [TeamData.Identity.BLUE]
	chain.set_test_state(one_blue, 100.0)
	main.call("_on_shot_reached_lane", TeamData.Identity.RED, float(main.get("_chain_view").position.x) + 100.0)
	_check(int(sfx.play_counts.insert) == 1 and int(sfx.play_counts.match) == 0, "successful nonmatching insertion plays insert only")

	main.call("_swap")
	_check(int(sfx.play_counts.swap) == 1, "actual swap plays exactly one cue")

	var red_pair: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED]
	chain.set_test_state(red_pair, 200.0)
	main.call("_on_shot_reached_lane", TeamData.Identity.RED, float(main.get("_chain_view").position.x) + 204.0)
	_check(int(sfx.play_counts.insert) == 2 and int(sfx.play_counts.match) == 1, "successful clear plays one insert and one match cue")
	_check(int(sfx.play_counts.attack) == 1, "active defender match plays one attack cue")
	main.call("_on_match_resolved", _result(TeamData.Identity.BLUE, 3))
	_check(int(sfx.play_counts.attack) == 2, "tier-3 two-lane clear emits one global attack cue")

	var red_lane := battlefield.get_lane(TeamData.Identity.RED).combat_model
	red_lane.clear_for_test()
	red_lane.call("_knock_down")
	_check(int(sfx.play_counts.knockdown) == 1, "defender DOWN signal plays one knockdown cue")
	var attack_before := int(sfx.play_counts.attack)
	red_lane.handle_match(_result(TeamData.Identity.RED, 3))
	_check(int(sfx.play_counts.revive) == 0 and int(sfx.play_counts.attack) == attack_before, "revival 1/2 plays neither revive nor attack cue")
	red_lane.handle_match(_result(TeamData.Identity.RED, 3))
	_check(int(sfx.play_counts.revive) == 1 and int(sfx.play_counts.attack) == attack_before, "second revival match plays revive but no attack cue")

	main.call("_on_game_over_requested", TeamData.Identity.RED)
	var play_total := 0
	for cue in SfxManagerScript.CUE_NAMES:
		play_total += int(sfx.play_counts[cue])
	sfx.play_cue("shoot")
	var after_game_over := 0
	for cue in SfxManagerScript.CUE_NAMES:
		after_game_over += int(sfx.play_counts[cue])
	_check(after_game_over == play_total, "game over blocks new audio playback")

	main.call("_restart_run")
	sfx.toggle_mute()
	sfx.play_cue("swap")
	_check(int(sfx.play_counts.swap) == 0, "mute preserves events without playing cues")
	sfx.toggle_mute()
	var restarted_lane := battlefield.get_lane(TeamData.Identity.BLUE).combat_model
	restarted_lane.call("_knock_down")
	_check(int(sfx.play_counts.knockdown) == 1, "restart does not duplicate semantic signal connections")
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P008 gamefeel and SFX: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P008 gamefeel and SFX: " + failure)
	print("P008 gamefeel and SFX: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
