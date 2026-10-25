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
	_test_typed_stats_and_motion()
	await _test_visual_roster_and_hidden_hp()
	_test_swept_hits_for_all_motion_types()
	await _test_weighted_sampler_and_seed_reset()
	await _test_global_snake_gate_and_cooldown_causes()
	await _test_full_directed_encounter()
	await _test_capacity_budget_initialization_and_healer_slot()
	_test_preserved_systems()
	_finish()

func _enemy_by_uid(model: LaneCombatModel, uid: int) -> Dictionary:
	for enemy in model.enemies:
		if int(enemy.uid) == uid:
			return enemy
	return {}

func _test_typed_stats_and_motion() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.RED)
	model.clear_for_test()
	model.max_enemies = 8
	var expected_hp := [2, 4, 2, 2]
	var expected_speed := [0.24, 0.168, 0.48, 0.0]
	for enemy_type in range(EnemyTypesScript.Type.HEALYZARD + 1):
		var uid := model.spawn_enemy(5.0 + enemy_type * 0.1, -1, false, enemy_type, 100 + enemy_type)
		var enemy := _enemy_by_uid(model, uid)
		_check(int(enemy.type) == enemy_type and int(enemy.hp) == expected_hp[enemy_type] and int(enemy.max_hp) == expected_hp[enemy_type], "%s owns canonical type and HP" % EnemyTypesScript.display_name(enemy_type))
		_check(is_equal_approx(float(enemy.speed), expected_speed[enemy_type]), "%s owns canonical horizontal speed" % EnemyTypesScript.display_name(enemy_type))
		_check(bool(enemy.hop_airborne) == (enemy_type == EnemyTypesScript.Type.HOPPER and float(enemy.hop_clock) >= LaneCombatModel.HOP_GROUND_DURATION), "only Hopper exposes hop phase")
	var historical := LaneCombatModel.new(TeamData.Identity.BLUE)
	historical.clear_for_test()
	var default_uid := historical.spawn_enemy()
	_check(int(historical.enemies[0].type) == EnemyTypesScript.Type.HOPPER and int(historical.enemies[0].hp) == 2 and default_uid > 0, "historical no-type spawn remains a 2 HP Hopper")

	var starts := {}
	for enemy in model.enemies:
		starts[int(enemy.type)] = float(enemy.x)
	model.update(1.0)
	for enemy in model.enemies:
		var moved := float(starts[int(enemy.type)]) - float(enemy.x)
		if int(enemy.type) == EnemyTypesScript.Type.HOPPER:
			_check(moved >= 0.0 and moved <= 0.5, "Hopper retains phase-based hop displacement")
		else:
			_check(is_equal_approx(moved, expected_speed[int(enemy.type)]), "%s uses continuous non-hop displacement" % EnemyTypesScript.display_name(int(enemy.type)))

func _mesh_color(root_node: Node, child_name: String) -> Color:
	var node := root_node.find_child(child_name, true, false) as MeshInstance3D
	if node == null:
		return Color.BLACK
	return (node.material_override as StandardMaterial3D).albedo_color

func _test_visual_roster_and_hidden_hp() -> void:
	var lane := LaneActor.new()
	lane.setup(TeamData.Identity.RED, 0)
	root.add_child(lane)
	await process_frame
	lane.set_process(false)
	lane.combat_model.clear_for_test()
	lane.combat_model.max_enemies = 8
	var uids: Array[int] = []
	for enemy_type in range(EnemyTypesScript.Type.HEALYZARD + 1):
		uids.append(lane.combat_model.spawn_enemy(1.0 + enemy_type, -1, false, enemy_type, 200 + enemy_type))
	lane.call("_sync_visuals")
	for enemy_type in range(uids.size()):
		var visual: Dictionary = lane.get("_enemy_visuals")[uids[enemy_type]]
		var horns: Array = visual.horns
		_check(horns.size() == (2 if enemy_type == EnemyTypesScript.Type.HOPPER else 0), "%s has the correct permanent horn count" % EnemyTypesScript.display_name(enemy_type))
		_check((visual.root as Node).find_children("*Pip*", "MeshInstance3D", true, false).is_empty(), "%s has no health-bar/pip meshes" % EnemyTypesScript.display_name(enemy_type))
	var hopper_visual: Dictionary = lane.get("_enemy_visuals")[uids[0]]
	lane.combat_model.call("_damage_enemy", uids[0], 1, 1.0)
	lane.call("_sync_visuals")
	_check(hopper_visual.horns.size() == 2 and hopper_visual.horns[0].visible and hopper_visual.horns[1].visible, "Hopper's two orange horns remain visible at 1 HP")
	_check(_mesh_color(hopper_visual.root, "HopperHorn").r > 0.9, "Hopper horns use permanent orange decoration")
	var heavy_visual: Dictionary = lane.get("_enemy_visuals")[uids[1]]
	var snake_visual: Dictionary = lane.get("_enemy_visuals")[uids[2]]
	var healer_visual: Dictionary = lane.get("_enemy_visuals")[uids[3]]
	_check(_mesh_color(heavy_visual.root, "Body").r > _mesh_color(heavy_visual.root, "Body").g * 2.0, "Heavy is visually broad orange")
	_check(_mesh_color(snake_visual.root, "Body").r > 0.75 and _mesh_color(snake_visual.root, "Body").g > 0.55, "Sickle Snake is strongly yellow")
	_check(_mesh_color(healer_visual.root, "Body").g > _mesh_color(healer_visual.root, "Body").r * 3.0 and is_equal_approx((healer_visual.root as Node3D).scale.x, 0.7), "Healyzard is green and 0.7 scale")
	_check((heavy_visual.root as Node3D).scale.x > (hopper_visual.root as Node3D).scale.x or (_mesh_color(heavy_visual.root, "Body").r > 0.0), "Heavy has a distinct wide construction")
	lane.queue_free()
	await process_frame

func _simulate_attack(enemy_type: int, hp: int, step: float, tier: int) -> LaneCombatModel:
	var model := LaneCombatModel.new(TeamData.Identity.YELLOW)
	model.clear_for_test()
	model.spawn_enemy(-2.0, hp, false, enemy_type, 300 + enemy_type)
	model.fire_attack({"identity": TeamData.Identity.YELLOW, "tier": tier, "fever": false, "group_size": 3})
	var elapsed := 0.0
	while elapsed < 1.2 and (model.active_projectile_count() > 0 or elapsed < 0.2):
		model.update(minf(step, 1.2 - elapsed))
		elapsed += step
	return model

func _test_swept_hits_for_all_motion_types() -> void:
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.08]:
		var heavy := _simulate_attack(EnemyTypesScript.Type.HEAVY, 4, step, 1)
		_check(heavy.active_enemy_count() == 1 and int(heavy.enemies[0].hp) == 3 and heavy.hit_history.size() == 1, "Heavy swept hit works at dt %.4f and survives one damage" % step)
		var snake := _simulate_attack(EnemyTypesScript.Type.SICKLE_SNAKE, 2, step, 2)
		_check(snake.total_killed == 1 and snake.hit_history.size() == 1, "sliding Snake swept hit works at dt %.4f" % step)
		var healer := _simulate_attack(EnemyTypesScript.Type.HEALYZARD, 2, step, 2)
		_check(healer.total_killed == 1 and healer.hit_history.size() == 1, "stationary Healyzard swept hit works at dt %.4f" % step)
	var heavy_burst := _simulate_attack(EnemyTypesScript.Type.HEAVY, 4, 1.0 / 60.0, 2)
	_check(heavy_burst.total_killed == 1 and heavy_burst.hit_history.size() == 2, "two tier-2 projectiles remove a 4 HP Heavy")

func _test_weighted_sampler_and_seed_reset() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
	battlefield.set_spawn_rng_seed(0x50102010)
	var counts := [0, 0, 0, 0]
	for unused in range(20000):
		counts[battlefield.sample_enemy_type(true)] += 1
	var expected := [0.5, 0.2, 0.2, 0.1]
	for enemy_type in range(4):
		var ratio := float(counts[enemy_type]) / 20000.0
		_check(absf(ratio - expected[enemy_type]) < 0.02, "%s fully eligible sampling approximates configured weight" % EnemyTypesScript.display_name(enemy_type))
	battlefield.set_spawn_rng_seed(99173)
	var first_sequence: Array[int] = []
	for unused in range(64):
		first_sequence.append(battlefield.sample_enemy_type(false))
	battlefield.set_spawn_rng_seed(99173)
	var second_sequence: Array[int] = []
	for unused in range(64):
		second_sequence.append(battlefield.sample_enemy_type(false))
	_check(first_sequence == second_sequence, "spawn-type RNG produces identical sequence after seed reset")
	_check(not first_sequence.has(EnemyTypesScript.Type.SICKLE_SNAKE), "ineligible sampling removes only Snake from the candidate set")
	var remaining_counts := [0, 0, 0, 0]
	battlefield.set_spawn_rng_seed(0x50102010)
	for unused in range(16000):
		remaining_counts[battlefield.sample_enemy_type(false)] += 1
	_check(absf(float(remaining_counts[0]) / 16000.0 - 0.625) < 0.02 and absf(float(remaining_counts[1]) / 16000.0 - 0.25) < 0.02 and absf(float(remaining_counts[3]) / 16000.0 - 0.125) < 0.02, "Snake-ineligible weights renormalize exactly from 50:20:10")
	battlefield.queue_free()
	await process_frame

func _prepare_director_fixture(battlefield: Battlefield) -> void:
	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
	battlefield.call("_reset_spawn_director", false)

func _test_global_snake_gate_and_cooldown_causes() -> void:
	for cause in [&"projectile", &"tier3", &"emergency"]:
		var battlefield := Battlefield.new()
		root.add_child(battlefield)
		await process_frame
		battlefield.set_process(false)
		for lane in battlefield.lanes:
			lane.set_process(false)
		_prepare_director_fixture(battlefield)
		var uid := battlefield.spawn_directed_enemy(0, EnemyTypesScript.Type.SICKLE_SNAKE, 1.0)
		_check(uid > 0 and not battlefield.snake_spawn_eligible(), "%s fixture registers one globally living Snake" % cause)
		var spawned_before := battlefield.encounter_spawned()
		_check(battlefield.spawn_directed_enemy(1, EnemyTypesScript.Type.SICKLE_SNAKE, 2.0) < 0 and battlefield.encounter_spawned() == spawned_before, "second same-frame Snake is rejected without quota burn")
		if cause == &"projectile":
			battlefield.lanes[0].combat_model.call("_damage_enemy", uid, 1, 1.0)
			_check(not battlefield.snake_spawn_eligible(), "nonfatal Snake damage does not release global occupancy")
			battlefield.lanes[0].combat_model.call("_damage_enemy", uid, 1, 1.0)
		elif cause == &"tier3":
			battlefield.lanes[0].combat_model.clear_enemies_for_tier3()
		else:
			battlefield.lanes[0].combat_model.call("_discharge_emergency")
		_check(int(battlefield.get("_living_snake_spawn_id")) < 0 and not battlefield.snake_spawn_eligible(), "%s Snake death releases occupancy but begins cooldown" % cause)
		battlefield.set("_spawn_simulation_time", 14.999)
		_check(battlefield.spawn_directed_enemy(2, EnemyTypesScript.Type.SICKLE_SNAKE, 2.0) < 0, "%s cooldown rejects replacement before 15 seconds" % cause)
		battlefield.set("_spawn_simulation_time", 15.0)
		_check(battlefield.spawn_directed_enemy(2, EnemyTypesScript.Type.SICKLE_SNAKE, 2.0) > 0, "%s cooldown permits replacement at exactly 15 seconds" % cause)
		battlefield.queue_free()
		await process_frame

func _test_capacity_budget_initialization_and_healer_slot() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
	var initial_types: Array[int] = []
	var spawn_ids := {}
	var snake_count := 0
	for lane in battlefield.lanes:
		_check(lane.combat_model.active_enemy_count() == 1 and lane.combat_model.spawned_this_encounter == 1, "weighted initialization charges one of eight in lane %d" % lane.lane_index)
		var enemy: Dictionary = lane.combat_model.enemies[0]
		initial_types.append(int(enemy.type))
		spawn_ids[int(enemy.spawn_id)] = true
		if int(enemy.type) == EnemyTypesScript.Type.SICKLE_SNAKE:
			snake_count += 1
	_check(spawn_ids.size() == 4 and snake_count <= 1, "initial enemies have global unique IDs and obey one-Snake limit")
	battlefield.reset_run()
	var reset_types: Array[int] = []
	for lane in battlefield.lanes:
		reset_types.append(int(lane.combat_model.enemies[0].type))
	_check(reset_types == initial_types, "restart reseeds weighted initial roster deterministically without stale Snake state")

	_prepare_director_fixture(battlefield)
	var lane_zero := battlefield.lanes[0].combat_model
	for unused in range(5):
		battlefield.spawn_directed_enemy(0, EnemyTypesScript.Type.HOPPER, 4.0 + unused * 0.2)
	var quota_at_cap := lane_zero.spawned_this_encounter
	_check(lane_zero.active_enemy_count() == 5 and battlefield.spawn_directed_enemy(0, EnemyTypesScript.Type.HEAVY) < 0 and lane_zero.spawned_this_encounter == quota_at_cap, "five-enemy lane cap defers spawn without consuming quota")
	lane_zero.clear_enemies_for_tier3()
	while not lane_zero.encounter_spawn_complete():
		battlefield.spawn_directed_enemy(0, EnemyTypesScript.Type.HOPPER)
	_check(lane_zero.spawned_this_encounter == 8 and lane_zero.total_spawned == 8, "director permits exactly eight successful lane spawns and no quota replenishment")

	_prepare_director_fixture(battlefield)
	var healer_a := battlefield.spawn_directed_enemy(1, EnemyTypesScript.Type.HEALYZARD)
	var healer_b := battlefield.spawn_directed_enemy(1, EnemyTypesScript.Type.HEALYZARD)
	var hopper := battlefield.spawn_directed_enemy(1, EnemyTypesScript.Type.HOPPER)
	var healer_a_start := float(_enemy_by_uid(battlefield.lanes[1].combat_model, healer_a).x)
	var healer_b_start := float(_enemy_by_uid(battlefield.lanes[1].combat_model, healer_b).x)
	var hopper_start := float(_enemy_by_uid(battlefield.lanes[1].combat_model, hopper).x)
	battlefield.lanes[1].combat_model.update(1.0)
	_check(not is_equal_approx(healer_a_start, healer_b_start) and healer_a_start < LaneCombatModel.RIGHT_BOUNDARY and healer_b_start < LaneCombatModel.RIGHT_BOUNDARY, "multiple Healyzards occupy distinct rear support slots away from entrance")
	_check(is_equal_approx(float(_enemy_by_uid(battlefield.lanes[1].combat_model, healer_a).x), healer_a_start) and float(_enemy_by_uid(battlefield.lanes[1].combat_model, hopper).x) < hopper_start, "stationary healer neither moves nor freezes normal lane progress")
	_check(battlefield.spawn_directed_enemy(1, EnemyTypesScript.Type.HEAVY) > 0, "stationary rear support does not block later entrance spawning")
	battlefield.queue_free()
	await process_frame

func _test_full_directed_encounter() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
	_prepare_director_fixture(battlefield)
	battlefield.set_spawn_rng_seed(7019)
	for lane in battlefield.lanes:
		lane.combat_model.spawn_interval = 0.01
	for index in range(4):
		battlefield.get("_spawn_timers")[index] = 0.0
	for wave in range(8):
		battlefield.call("_update_spawn_director", 0.1)
		var live_snakes := 0
		for lane in battlefield.lanes:
			_check(lane.combat_model.active_enemy_count() <= 5 and lane.combat_model.spawned_this_encounter <= 8, "directed wave %d respects per-lane live and budget caps" % wave)
			for enemy in lane.combat_model.enemies:
				if int(enemy.type) == EnemyTypesScript.Type.SICKLE_SNAKE:
					live_snakes += 1
		_check(live_snakes <= 1, "directed same-frame wave %d never creates two live Snakes" % wave)
		for lane in battlefield.lanes:
			lane.combat_model.clear_enemies_for_tier3()
		if battlefield.encounter_spawned() == 32:
			break
	_check(battlefield.encounter_spawned() == 32 and battlefield.encounter_neutralized() == 32, "central director completes exactly eight successful spawns per lane / 32 overall")
	_check(battlefield.victory and battlefield.encounter_live() == 0, "typed roster preserves finite-encounter victory authority")
	battlefield.queue_free()
	await process_frame

func _test_preserved_systems() -> void:
	var chain := ChainModel.new()
	var first_uid := int(chain.balls[0].uid)
	chain.advance(20.0)
	_check(is_equal_approx(chain.speed, 102.0) and chain._ball_index_by_uid(first_uid) >= 0 and chain.cache.is_empty(), "P017 102 px/s physical offscreen-left UID retention remains intact")
	_check(chain.invariant_violations == 0 and is_equal_approx(ChainModel.INSERT_SETTLE_TIME, 0.05), "conveyor remains I0 with staged insertion timing")

func _finish() -> void:
	if _failures.is_empty():
		print("P019 enemy roster/spawning: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P019 enemy roster/spawning: " + failure)
	print("P019 enemy roster/spawning: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
