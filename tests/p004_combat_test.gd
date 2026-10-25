extends SceneTree

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _result(identity: int, tier: int, fever := false, group_size := 3) -> Dictionary:
	return {"identity": identity, "tier": tier, "fever": fever, "group_size": group_size, "combo_count": tier, "points": 100}

func _run() -> void:
	_test_tier_mapping_and_locking()
	_test_empty_lane_despawn()
	_test_damage_kill_and_sweep()
	_test_first_target_burst()
	_test_hop_independence_and_lane_isolation()
	_test_enemy_movement_spawning_and_boundary()
	await _test_scene_routing_and_genuine_clear()
	_finish()

func _test_tier_mapping_and_locking() -> void:
	for tier in range(1, 3):
		var model := LaneCombatModel.new(TeamData.Identity.RED)
		model.clear_for_test()
		var group_size := 7 if tier == 3 else 5
		var attack := model.fire_attack(_result(TeamData.Identity.RED, tier, tier == 3, group_size))
		_check(int(attack.projectile_count) == tier, "tier %d locks %d projectiles" % [tier, tier])
		_check(model.active_projectile_count() == tier, "tier %d creates complete delayed burst" % tier)
		_check(int(attack.group_size) == group_size, "large group metadata is retained without extra shots")
		if tier > 1:
			_check(float(model.projectiles[1].launch_delay) > float(model.projectiles[0].launch_delay), "burst projectiles have distinct launch times")
	var tier_three := LaneCombatModel.new(TeamData.Identity.RED)
	tier_three.clear_for_test()
	var clear_attack := tier_three.fire_attack(_result(TeamData.Identity.RED, 3, true, 7))
	_check(int(clear_attack.projectile_count) == 0 and tier_three.active_projectile_count() == 0, "tier 3 creates no conventional projectiles")
	_check(int(clear_attack.group_size) == 7, "tier-3 clear retains match metadata")

	var progression := MatchProgression.new()
	progression.register_match(TeamData.Identity.BLUE, 3)
	var tier_two := progression.register_match(TeamData.Identity.BLUE, 3)
	var locked := LaneCombatModel.new(TeamData.Identity.BLUE)
	locked.clear_for_test()
	locked.fire_attack(tier_two)
	progression.update(3.0)
	_check(progression.tier == 0, "global combo can expire after attack creation")
	_check(locked.attack_history.size() == 1 and int(locked.attack_history[0].tier) == 2, "queued attack retains match-time tier")
	_check(locked.active_projectile_count() == 2, "timeout does not cancel locked burst")

func _test_empty_lane_despawn() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.GREEN)
	model.clear_for_test()
	model.fire_attack(_result(TeamData.Identity.GREEN, 2, false, 7))
	_check(model.active_projectile_count() == 2, "empty lane still fires tier-2 burst")
	var start_x := float(model.projectiles[0].x)
	model.update(0.1)
	_check(float(model.projectiles[0].x) > start_x, "active 3D projectile advances toward world right")
	model.update(10.0)
	_check(model.active_projectile_count() == 0, "empty-lane projectiles despawn at bound/lifetime")
	_check(model.hit_history.is_empty(), "empty-lane burst fabricates no impacts")

func _test_damage_kill_and_sweep() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.RED)
	model.clear_for_test()
	var enemy_uid := model.spawn_enemy(-2.0, 2)
	model.fire_attack(_result(TeamData.Identity.RED, 1))
	model.update(1.0)
	_check(model.active_enemy_count() == 1 and int(model.enemies[0].hp) == 1, "first swept impact damages enemy once")
	_check(model.active_projectile_count() == 0 and model.hit_history.size() == 1, "projectile stops at first impact")
	model.fire_attack(_result(TeamData.Identity.RED, 1))
	model.update(1.0)
	_check(model.active_enemy_count() == 0 and model.total_killed == 1, "second impact removes zero-HP enemy once")
	_check(model.hit_history.size() == 2 and int(model.hit_history[-1].enemy_uid) == enemy_uid, "kill records one final hit on target")
	model.update(1.0)
	_check(model.total_killed == 1, "dead enemy cannot be killed twice")

func _test_first_target_burst() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.YELLOW)
	model.clear_for_test()
	var first_uid := model.spawn_enemy(-2.0, 1)
	var second_uid := model.spawn_enemy(0.0, 1)
	model.fire_attack(_result(TeamData.Identity.YELLOW, 2, false, 5))
	model.update(1.0)
	_check(model.total_killed == 2 and model.active_enemy_count() == 0, "tier-2 burst can kill two ordered one-HP enemies")
	_check(model.hit_history.size() == 2, "each projectile produces at most one hit")
	if model.hit_history.size() == 2:
		_check(int(model.hit_history[0].enemy_uid) == first_uid, "first projectile hits nearest enemy")
		_check(int(model.hit_history[1].enemy_uid) == second_uid, "remaining projectile reaches second enemy after first dies")

func _test_hop_independence_and_lane_isolation() -> void:
	var low_hop := LaneCombatModel.new(TeamData.Identity.RED)
	var high_hop := LaneCombatModel.new(TeamData.Identity.RED)
	low_hop.clear_for_test()
	high_hop.clear_for_test()
	low_hop.spawn_enemy(3.0, 1)
	high_hop.spawn_enemy(3.0, 1)
	var high_enemy := high_hop.enemies[0]
	high_enemy.hop_clock = LaneCombatModel.HOP_GROUND_DURATION + LaneCombatModel.HOP_AIR_DURATION * 0.5
	high_enemy.hop_airborne = true
	high_enemy.hop_progress = 0.5
	high_hop.enemies[0] = high_enemy
	low_hop.fire_attack(_result(TeamData.Identity.RED, 1))
	high_hop.fire_attack(_result(TeamData.Identity.RED, 1))
	low_hop.update(2.0)
	high_hop.update(2.0)
	_check(low_hop.total_killed == 1 and high_hop.total_killed == 1, "hop height never changes logical hit probability")
	_check(low_hop.hit_history.size() == 1, "large delta swept collision does not tunnel")

	var neighbor := LaneCombatModel.new(TeamData.Identity.BLUE)
	neighbor.clear_for_test()
	neighbor.spawn_enemy(-2.0, 1)
	low_hop.fire_attack(_result(TeamData.Identity.RED, 1))
	low_hop.update(1.0)
	neighbor.update(1.0)
	_check(neighbor.active_enemy_count() == 1 and int(neighbor.enemies[0].hp) == 1, "nearby lane enemy is unaffected by other-lane projectiles")

func _test_enemy_movement_spawning_and_boundary() -> void:
	var one_step := LaneCombatModel.new(TeamData.Identity.GREEN)
	var split_step := LaneCombatModel.new(TeamData.Identity.GREEN)
	one_step.clear_for_test()
	split_step.clear_for_test()
	one_step.spawn_enemy(4.0, 2)
	split_step.spawn_enemy(4.0, 2)
	one_step.update(1.0)
	split_step.update(0.4)
	split_step.update(0.6)
	_check(is_equal_approx(float(one_step.enemies[0].x), float(split_step.enemies[0].x)), "enemy logical movement is frame-rate independent")

	var spawning := LaneCombatModel.new(TeamData.Identity.BLUE)
	spawning.clear_for_test()
	spawning.auto_spawn = true
	spawning.spawn_interval = 0.25
	spawning.spawn_timer = 0.25
	spawning.max_enemies = 3
	spawning.update(1.0)
	_check(spawning.active_enemy_count() == 3 and spawning.total_spawned == 3, "tunable cadence spawns multiple enemies up to cap")
	spawning.update(2.0)
	_check(spawning.active_enemy_count() <= spawning.max_enemies, "spawn cadence remains bounded")

	var boundary := LaneCombatModel.new(TeamData.Identity.YELLOW)
	boundary.clear_for_test()
	boundary.defender_state = LaneCombatModel.DefenderState.DOWN
	boundary.emergency_available = false
	boundary.spawn_enemy(LaneCombatModel.LEFT_BOUNDARY + 0.01, 2)
	var boundary_enemy := boundary.enemies[0]
	boundary_enemy.hop_clock = LaneCombatModel.HOP_GROUND_DURATION
	boundary.enemies[0] = boundary_enemy
	boundary.update(0.1)
	_check(boundary.game_over and boundary.total_breaches == 1, "P005 boundary override emits terminal breach once")

func _test_scene_routing_and_genuine_clear() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var battlefield: Battlefield = main.get("_battlefield")
	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()

	battlefield.fire_for_match(_result(TeamData.Identity.RED, 1))
	_check(battlefield.get_lane(TeamData.Identity.RED).combat_model.active_projectile_count() == 1, "RED tier-1 result fires one RED-lane projectile")
	for identity in range(1, TeamData.COUNT):
		_check(battlefield.get_lane(identity).combat_model.active_projectile_count() == 0, "RED attack leaves lane %d unfired" % identity)

	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()
	var chain: ChainModel = main.get("_chain_model")
	var progression: MatchProgression = main.get("_progression")
	var identity := TeamData.Identity.YELLOW
	var pair: Array[int] = [identity, identity]
	var cached: Array[int] = [TeamData.Identity.BLUE]
	chain.set_test_state(pair, 400.0, cached)
	chain.try_insert_shot(identity, 468.0)
	chain.advance(ChainModel.INSERT_SETTLE_TIME)
	var yellow_combat := battlefield.get_lane(identity).combat_model
	_check(progression.combo_count == 1 and progression.last_result.identity == identity, "genuine clear reaches central progression")
	_check(yellow_combat.attack_history.size() == 1, "genuine clear routes one attack to matching defender")
	_check(yellow_combat.active_projectile_count() == 1, "genuine tier-1 clear creates one 3D projectile")
	for other_identity in range(TeamData.COUNT):
		if other_identity != identity:
			_check(battlefield.get_lane(other_identity).combat_model.attack_history.is_empty(), "genuine clear does not attack lane %d" % other_identity)
	main.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("P004 lane combat: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P004 lane combat: " + failure)
	print("P004 lane combat: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
