extends SceneTree

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _result(identity: int, tier: int) -> Dictionary:
	return {"identity": identity, "tier": tier, "fever": tier >= 3, "group_size": 3, "combo_count": tier, "points": 100}

func _set_hop_clock(model: LaneCombatModel, index: int, clock: float) -> void:
	var enemy := model.enemies[index]
	enemy.hop_clock = clock
	enemy.hop_airborne = clock >= LaneCombatModel.HOP_GROUND_DURATION
	enemy.hop_progress = clampf((clock - LaneCombatModel.HOP_GROUND_DURATION) / LaneCombatModel.HOP_AIR_DURATION, 0.0, 1.0) if bool(enemy.hop_airborne) else 0.0
	model.enemies[index] = enemy

func _run() -> void:
	_test_speed_and_infinite_feed()
	_test_fifo_feed_and_physical_adjacency()
	_test_projectile_damage_locking()
	await _test_tier_three_routing()
	await _test_down_defender_tier_three_precedence()
	_test_hop_translation_and_subdivision()
	await _test_hop_visual_collision_and_survival_order()
	_finish()

func _test_speed_and_infinite_feed() -> void:
	_check(is_equal_approx(ChainModel.DEFAULT_SPEED, 102.0), "P016 triples default conveyor speed to 102 px/s")
	for delta in [0.016, 0.1, 1.0]:
		var motion := ChainModel.new()
		var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.BLUE]
		motion.set_test_state(identities, 600.0)
		var before := float(motion.balls[0].x)
		motion.advance(delta)
		_check(is_equal_approx(float(motion.balls[0].x), before - motion.speed * delta), "conveyor motion is delta-based at %.3fs" % delta)

	var stream := ChainModel.new()
	var minimum_live := stream.balls.size()
	var maximum_live := stream.balls.size()
	for unused in range(2200):
		stream.advance(0.1)
		minimum_live = mini(minimum_live, stream.balls.size())
		maximum_live = maxi(maximum_live, stream.balls.size())
	_check(stream.total_fresh_generated > 100, "fresh feeder generates more than 100 lifetime balls without matches")
	_check(minimum_live > 0 and not stream.balls.is_empty(), "continuous train never becomes permanently empty")
	_check(maximum_live <= stream.max_auto_population, "continuous feeder live population remains capped")
	_check(stream.cache.size() > 0, "legitimate left exits remain represented in linear FIFO storage")

func _test_fifo_feed_and_physical_adjacency() -> void:
	var feeder := ChainModel.new()
	var rollover: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW]
	feeder.set_test_state(rollover, -190.0)
	feeder.continuous_feed_enabled = true
	feeder.advance(0.0)
	_check(feeder.total_exited == 3 and feeder.total_cache_returned == 1 and feeder.cache.slice(0, 2) == [TeamData.Identity.GREEN, TeamData.Identity.BLUE], "rollover records RED, GREEN, BLUE and immediately admits the FIFO front")
	_check(feeder.pending_cache_returns == feeder.cache.size(), "all rollover colors are automatically eligible while the right edge has no slot")
	var returned: Array[int] = [TeamData.Identity.RED]
	var returned_count := feeder.total_cache_returned
	for unused in range(45):
		feeder.advance(0.1)
		if feeder.total_cache_returned > returned_count:
			returned.append(int(feeder.balls[-1].identity))
			returned_count = feeder.total_cache_returned
	_check(feeder.pending_cache_returns == feeder.cache.size(), "automatic eligibility counter tracks the exact remaining FIFO queue")
	_check(returned.slice(0, 3) == [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE], "automatic FIFO returns retain RED, GREEN, BLUE visual order")
	var generated_before := feeder.total_fresh_generated
	for unused in range(50):
		feeder.advance(0.1)
	_check(feeder.total_fresh_generated > generated_before, "fresh generation continues after cached returns")
	_check(feeder.balls.size() <= feeder.max_auto_population, "return integration does not create offscreen-right backlog")

	var separated := ChainModel.new()
	var red_pair: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED]
	separated.set_test_state(red_pair, 100.0)
	var isolated_red: Array[int] = [TeamData.Identity.RED]
	separated.add_test_segment(isolated_red, 500.0)
	separated.try_insert_shot(TeamData.Identity.RED, 510.0)
	_check(separated.total_match_events == 0, "same colors across a physical gap do not match")

func _test_projectile_damage_locking() -> void:
	var tier_one := LaneCombatModel.new(TeamData.Identity.RED)
	tier_one.clear_for_test()
	tier_one.spawn_enemy(-2.0, 2)
	tier_one.fire_attack(_result(TeamData.Identity.RED, 1))
	tier_one.projectile_damage = 99
	tier_one.update(1.0)
	_check(tier_one.active_enemy_count() == 1 and int(tier_one.enemies[0].hp) == 1, "tier-1 projectile locks one damage and leaves default enemy at 1 HP")
	tier_one.projectile_damage = 1
	tier_one.fire_attack(_result(TeamData.Identity.RED, 1))
	tier_one.update(1.0)
	_check(tier_one.active_enemy_count() == 0, "second tier-1 hit kills default 2-HP enemy")

	var tier_two := LaneCombatModel.new(TeamData.Identity.BLUE)
	tier_two.clear_for_test()
	var first := tier_two.spawn_enemy(-2.0, 2)
	var second := tier_two.spawn_enemy(0.0, 2)
	tier_two.fire_attack(_result(TeamData.Identity.BLUE, 2))
	_check(int(tier_two.projectiles[0].damage) == 2 and int(tier_two.projectiles[1].damage) == 2, "each tier-2 projectile locks two damage")
	tier_two.projectile_damage = 1
	tier_two.update(1.0)
	_check(tier_two.total_killed == 2 and tier_two.active_enemy_count() == 0, "tier-2 burst kills two spaced default enemies")
	_check([int(tier_two.hit_history[0].enemy_uid), int(tier_two.hit_history[1].enemy_uid)] == [first, second], "tier-2 projectiles preserve first-target ordering")

func _spawn_one_per_lane(battlefield: Battlefield) -> void:
	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()
		lane.combat_model.spawn_enemy(1.0, 2)

func _test_tier_three_routing() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	_spawn_one_per_lane(battlefield)
	var charges: Array[bool] = []
	for lane in battlefield.lanes:
		charges.append(lane.combat_model.emergency_available)
	var edge_top: Dictionary = battlefield.handle_match(_result(0, 3)).get("attack", {})
	_check(int(edge_top.adjacent_lane) == 1 and int(edge_top.killed_count) == 2, "lane 0 tier-3 clears lanes 0 and 1")
	_check(battlefield.get_lane(2).combat_model.active_enemy_count() == 1 and battlefield.get_lane(3).combat_model.active_enemy_count() == 1, "top-edge clear preserves uninvolved lanes")
	_check(battlefield.get_lane(0).combat_model.active_projectile_count() == 0, "tier-3 clear creates no ordinary projectiles")
	for index in range(battlefield.lanes.size()):
		_check(battlefield.lanes[index].combat_model.emergency_available == charges[index], "tier-3 clear does not consume lane %d emergency charge" % index)

	_spawn_one_per_lane(battlefield)
	var edge_bottom: Dictionary = battlefield.handle_match(_result(3, 3)).get("attack", {})
	_check(int(edge_bottom.adjacent_lane) == 2 and int(edge_bottom.killed_count) == 2, "lane 3 tier-3 clears lanes 3 and 2")

	for origin in [1, 2]:
		var chosen := {}
		for seed_value in range(1, 24):
			_spawn_one_per_lane(battlefield)
			battlefield.set_attack_rng_seed(seed_value)
			var outcome := battlefield.handle_match(_result(origin, 3))
			chosen[int(outcome.attack.adjacent_lane)] = true
		_check(chosen.has(origin - 1) and chosen.has(origin + 1), "inner lane %d can choose either physical neighbor" % origin)

	_spawn_one_per_lane(battlefield)
	battlefield.get_lane(0).combat_model.enemies.clear()
	var empty_outcome := battlefield.handle_match(_result(0, 3))
	_check(int(empty_outcome.attack.killed_count) == 1, "tier-3 empty origin is a safe no-op while neighbor still clears")
	battlefield.get_lane(0).combat_model.spawn_enemy(2.0, 2)
	_check(battlefield.get_lane(0).combat_model.active_enemy_count() == 1, "tier-3 does not affect future spawns")
	_check(battlefield.attack_history.size() <= LaneCombatModel.HISTORY_LIMIT and battlefield.attack_history[-1].has("origin_lane"), "bounded attack history records tier-3 lane metadata")
	battlefield.queue_free()

func _test_down_defender_tier_three_precedence() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()
	var origin := battlefield.get_lane(1).combat_model
	var neighbor := battlefield.get_lane(0).combat_model
	origin.defender_state = LaneCombatModel.DefenderState.DOWN
	origin.emergency_available = false
	origin.spawn_enemy(1.0, 2)
	neighbor.spawn_enemy(1.0, 2)
	var first := battlefield.handle_match(_result(1, 3))
	_check(str(first.action) == "revival" and origin.revival_progress == 1, "down origin receives one revival point instead of tier-3 clear")
	_check(origin.active_enemy_count() == 1 and neighbor.active_enemy_count() == 1, "first down-origin tier-3 match clears no lanes")
	var second := battlefield.handle_match(_result(1, 3))
	_check(bool(second.revived) and origin.defender_state == LaneCombatModel.DefenderState.ACTIVE, "second tier-3 match revives without attacking")
	_check(origin.active_enemy_count() == 1 and neighbor.active_enemy_count() == 1 and not origin.emergency_available, "revival preserves enemies and spent emergency state")
	battlefield.set_attack_rng_seed(3)
	var active := battlefield.handle_match(_result(1, 3))
	_check(str(active.action) == "attack" and int(active.attack.killed_count) >= 1, "active post-revival tier-3 clear works")
	battlefield.queue_free()

func _test_hop_translation_and_subdivision() -> void:
	var grounded := LaneCombatModel.new(TeamData.Identity.RED)
	grounded.clear_for_test()
	grounded.spawn_enemy(4.0, 2)
	_set_hop_clock(grounded, 0, 0.1)
	var ground_x := float(grounded.enemies[0].x)
	grounded.update(0.2)
	_check(is_equal_approx(float(grounded.enemies[0].x), ground_x), "enemy logical X is stationary throughout grounded dwell")
	grounded.update(0.4)
	_check(float(grounded.enemies[0].x) < ground_x, "enemy logical X decreases after airborne lift-off")

	var cycle := LaneCombatModel.new(TeamData.Identity.BLUE)
	cycle.clear_for_test()
	cycle.spawn_enemy(5.0, 2)
	_set_hop_clock(cycle, 0, 0.0)
	cycle.update(LaneCombatModel.HOP_CYCLE_DURATION * 10.0)
	var average := (5.0 - float(cycle.enemies[0].x)) / (LaneCombatModel.HOP_CYCLE_DURATION * 10.0)
	_check(is_equal_approx(average, LaneCombatModel.DEFAULT_ENEMY_SPEED), "complete hop cycles match configured average speed")

	var one_step := LaneCombatModel.new(TeamData.Identity.GREEN)
	var split_step := LaneCombatModel.new(TeamData.Identity.GREEN)
	one_step.clear_for_test()
	split_step.clear_for_test()
	one_step.spawn_enemy(5.0, 2)
	split_step.spawn_enemy(5.0, 2)
	_set_hop_clock(one_step, 0, 0.2)
	_set_hop_clock(split_step, 0, 0.2)
	one_step.update(5.7)
	for unused in range(57):
		split_step.update(0.1)
	_check(is_equal_approx(float(one_step.enemies[0].x), float(split_step.enemies[0].x)), "hop displacement is stable across large and subdivided steps")

func _test_hop_visual_collision_and_survival_order() -> void:
	var actor := LaneActor.new()
	actor.setup(TeamData.Identity.RED, 0)
	root.add_child(actor)
	await process_frame
	var sample := {"hop_airborne": false, "hop_progress": 0.0}
	_check(is_zero_approx(actor.enemy_hop_height(sample)), "enemy visual height is zero during ground dwell")
	sample.hop_airborne = true
	sample.hop_progress = 0.5
	_check(actor.enemy_hop_height(sample) > 0.5, "enemy visual height is positive during airborne phase")
	actor.queue_free()

	for airborne in [false, true]:
		var collision := LaneCombatModel.new(TeamData.Identity.YELLOW)
		collision.clear_for_test()
		collision.spawn_enemy(1.0, 1)
		_set_hop_clock(collision, 0, LaneCombatModel.HOP_GROUND_DURATION + 0.2 if airborne else 0.1)
		collision.fire_attack(_result(TeamData.Identity.YELLOW, 1))
		collision.update(2.0)
		_check(collision.total_killed == 1, "large-delta swept projectile hits %s target" % ("airborne" if airborne else "grounded"))

	var emergency := LaneCombatModel.new(TeamData.Identity.RED)
	emergency.clear_for_test()
	emergency.spawn_enemy(LaneCombatModel.DEFENDER_X + 0.5, 2)
	_set_hop_clock(emergency, 0, LaneCombatModel.HOP_GROUND_DURATION)
	emergency.update(3.0)
	_check(emergency.defender_state == LaneCombatModel.DefenderState.DOWN and emergency.enemies.is_empty(), "hop crossing resolves knockdown and emergency before breach")
	_check(not emergency.game_over and not emergency.emergency_available, "same-hop emergency crossing does not cause game over")

	var breach := LaneCombatModel.new(TeamData.Identity.BLUE)
	breach.clear_for_test()
	breach.defender_state = LaneCombatModel.DefenderState.DOWN
	breach.emergency_available = false
	breach.spawn_enemy(LaneCombatModel.LEFT_BOUNDARY + 0.2, 2)
	_set_hop_clock(breach, 0, LaneCombatModel.HOP_GROUND_DURATION)
	breach.update(1.0)
	_check(breach.game_over and breach.total_breaches == 1, "later living hop across left boundary causes one terminal breach")

func _finish() -> void:
	if _failures.is_empty():
		print("P007 playtest revision: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P007 playtest revision: " + failure)
	print("P007 playtest revision: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
