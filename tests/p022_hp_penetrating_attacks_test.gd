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

func _result(identity: int, tier: int) -> Dictionary:
	return {"identity": identity, "tier": tier, "fever": tier >= 3, "group_size": 3}

func _run() -> void:
	_test_canonical_hp_and_fixture_caps()
	_test_tier_one_first_contact_only()
	_test_tier_two_penetration_and_rate_safety()
	await _test_tier_three_wide_routing_and_deduplication()
	_test_healing_and_emergency()
	_finish()

func _test_canonical_hp_and_fixture_caps() -> void:
	var expected := [6, 12, 6, 6]
	_check(LaneCombatModel.DEFAULT_ENEMY_HP == 6, "generic default enemy HP is canonical Hopper 6")
	for enemy_type in range(EnemyTypesScript.Type.size()):
		_check(EnemyTypesScript.max_hp(enemy_type) == expected[enemy_type], "%s canonical max HP is %d" % [EnemyTypesScript.display_name(enemy_type), expected[enemy_type]])
		var model := LaneCombatModel.new(enemy_type)
		model.clear_for_test()
		var uid := model.spawn_enemy(1.0, -1, false, enemy_type, 2200 + enemy_type)
		var enemy: Dictionary = model.enemies[0]
		_check(uid >= 0 and int(enemy.hp) == expected[enemy_type] and int(enemy.max_hp) == expected[enemy_type], "%s spawns at full canonical HP" % EnemyTypesScript.display_name(enemy_type))
		var damaged := LaneCombatModel.new(enemy_type)
		damaged.clear_for_test()
		damaged.spawn_enemy(1.0, 1, false, enemy_type, 2300 + enemy_type)
		_check(int(damaged.enemies[0].hp) == 1 and int(damaged.enemies[0].max_hp) == expected[enemy_type], "explicit %s fixture HP does not lower canonical max" % EnemyTypesScript.display_name(enemy_type))

func _test_tier_one_first_contact_only() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.RED)
	model.clear_for_test()
	var first := model.spawn_enemy(-2.0, -1, false, EnemyTypesScript.Type.HOPPER, 2401)
	var second := model.spawn_enemy(0.0, -1, false, EnemyTypesScript.Type.HOPPER, 2402)
	var attack := model.fire_attack(_result(TeamData.Identity.RED, 1))
	model.update(1.0)
	_check(int(attack.projectile_count) == 1 and not bool(attack.piercing), "tier 1 launches one ordinary non-piercing projectile")
	_check(model.active_projectile_count() == 0 and model.hit_history.size() == 1, "tier 1 despawns on its first physical contact")
	_check(int(model.enemies[0].uid) == first and int(model.enemies[0].hp) == 5, "tier 1 damages the first full Hopper by exactly 1")
	_check(int(model.enemies[1].uid) == second and int(model.enemies[1].hp) == 6, "tier 1 leaves every enemy behind the first untouched")

	var lethal_first := LaneCombatModel.new(TeamData.Identity.RED)
	lethal_first.clear_for_test()
	lethal_first.spawn_enemy(-2.0, 1, false, EnemyTypesScript.Type.HOPPER, 2411)
	lethal_first.spawn_enemy(0.0, -1, false, EnemyTypesScript.Type.HOPPER, 2412)
	lethal_first.fire_attack(_result(TeamData.Identity.RED, 1))
	lethal_first.update(1.0)
	_check(lethal_first.total_killed == 1 and lethal_first.active_enemy_count() == 1 and int(lethal_first.enemies[0].hp) == 6, "a lethal first contact still cannot pass damage to the second enemy")

func _test_tier_two_penetration_and_rate_safety() -> void:
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.08]:
		var model := LaneCombatModel.new(TeamData.Identity.BLUE)
		model.clear_for_test()
		for index in range(3):
			model.spawn_enemy(-2.0 + index * 1.4, -1, false, EnemyTypesScript.Type.HOPPER, 2500 + index)
		var attack := model.fire_attack(_result(TeamData.Identity.BLUE, 2))
		var elapsed := 0.0
		while elapsed < 1.6:
			model.update(step)
			elapsed += step
		_check(int(attack.projectile_count) == 1 and bool(attack.piercing) and not bool(attack.wide), "tier 2 is one lane-local penetrating projectile at dt %.4f" % step)
		_check(model.hit_history.size() == 3, "tier 2 hits all three collinear enemies once at dt %.4f" % step)
		_check(model.enemies.all(func(enemy: Dictionary) -> bool: return int(enemy.hp) == 5), "tier 2 deals exactly 1 damage per encountered enemy at dt %.4f" % step)
		_check(model.active_projectile_count() == 0, "tier 2 continues through impacts and expires normally at dt %.4f" % step)

	var passed := LaneCombatModel.new(TeamData.Identity.BLUE)
	passed.clear_for_test()
	passed.fire_attack(_result(TeamData.Identity.BLUE, 2))
	passed.update(1.0)
	passed.spawn_enemy(-2.0, -1, false, EnemyTypesScript.Type.HOPPER, 2599)
	passed.update(1.0)
	_check(passed.hit_history.is_empty() and int(passed.enemies[0].hp) == 6, "an enemy spawned behind a projectile after it passed receives no retroactive damage")

func _new_battlefield(seed: int) -> Battlefield:
	var battlefield := Battlefield.new()
	battlefield.set_attack_rng_seed(seed)
	root.add_child(battlefield)
	return battlefield

func _prepare_battlefield(battlefield: Battlefield) -> void:
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.clear_for_test()
	battlefield.call("_reset_spawn_director", false)

func _advance_projectiles(battlefield: Battlefield, duration: float, step := 1.0 / 60.0) -> void:
	var elapsed := 0.0
	while elapsed < duration - 0.000001:
		var slice := minf(step, duration - elapsed)
		for lane in battlefield.lanes:
			lane.combat_model.update(slice)
		battlefield.call("_update_snake_special", slice)
		elapsed += slice

func _test_tier_three_wide_routing_and_deduplication() -> void:
	var battlefield := _new_battlefield(2203)
	await process_frame
	_prepare_battlefield(battlefield)
	battlefield.set_attack_rng_seed(0x2203)
	var adjacent_counts := {0: 0, 2: 0}
	for unused in range(2000):
		var choice := int(battlefield.call("_choose_adjacent_lane", 1))
		adjacent_counts[choice] = int(adjacent_counts.get(choice, 0)) + 1
	_check(adjacent_counts.keys().size() == 2 and absf(float(adjacent_counts[0]) / 2000.0 - 0.5) < 0.04, "seeded middle-lane wide target selection is unbiased across both adjacent lanes")
	battlefield.set_attack_rng_seed(2203)
	for lane_index in range(4):
		battlefield.spawn_directed_enemy(lane_index, EnemyTypesScript.Type.HEAVY, -1.0, -1, false)
	var outcome := battlefield.handle_match(_result(1, 3))
	var attack: Dictionary = outcome.attack
	var adjacent := int(attack.adjacent_lane)
	_advance_projectiles(battlefield, 1.2)
	_check(int(attack.projectile_count) == 1 and bool(attack.wide) and bool(attack.piercing), "tier 3 launches one wide penetrating attack")
	_check(adjacent in [0, 2] and attack.target_lanes == [1, adjacent], "middle-lane tier 3 fixes one valid adjacent target for its lifetime")
	for lane_index in range(4):
		var expected_hp := 11 if lane_index in [1, adjacent] else 12
		_check(int(battlefield.lanes[lane_index].combat_model.enemies[0].hp) == expected_hp, "tier 3 deals 1 only in intended lane %d" % lane_index)
	_check(battlefield.encounter_neutralized() == 0, "tier 3 wounds full-health enemies without incrementing neutralized counters")
	battlefield.queue_free()
	await process_frame

	var edge := _new_battlefield(2204)
	await process_frame
	_prepare_battlefield(edge)
	edge.spawn_directed_enemy(0, EnemyTypesScript.Type.HOPPER, -1.0, -1, false)
	edge.spawn_directed_enemy(1, EnemyTypesScript.Type.HOPPER, -1.0, -1, false)
	var edge_attack: Dictionary = edge.handle_match(_result(0, 3)).attack
	_advance_projectiles(edge, 1.2, 0.08)
	_check(int(edge_attack.adjacent_lane) == 1 and edge.lanes[0].combat_model.hit_history.size() == 1 and edge.lanes[1].combat_model.hit_history.size() == 1, "edge-lane tier 3 targets its only neighbor with large-delta sweeps")
	edge.queue_free()
	await process_frame

	var dedup := _new_battlefield(2205)
	await process_frame
	_prepare_battlefield(dedup)
	dedup.spawn_directed_enemy(1, EnemyTypesScript.Type.SICKLE_SNAKE, -2.0, -1, false)
	var snake_spawn_id := int(dedup.lanes[1].combat_model.enemies[0].spawn_id)
	dedup.set_attack_rng_seed(1)
	var dedup_attack: Dictionary = dedup.handle_match(_result(1, 3)).attack
	var target_lane := int(dedup_attack.adjacent_lane)
	var origin_projectile: Dictionary = dedup.lanes[1].combat_model.projectiles[0]
	var shared_hits: Dictionary = origin_projectile.hit_spawn_ids
	_advance_projectiles(dedup, 0.5)
	var location: Dictionary = dedup.call("_find_enemy_by_spawn_id", snake_spawn_id)
	_check(not location.is_empty() and int(location.enemy.hp) == 5 and shared_hits.has(snake_spawn_id), "wide projectile records the Snake's immutable spawn ID after one hit")
	if not location.is_empty():
		var snake: Dictionary = location.enemy
		var old_uid := int(snake.uid)
		var extracted := dedup.lanes[int(location.lane_index)].combat_model.extract_enemy_for_transfer(old_uid)
		if not extracted.is_empty():
			extracted.special_state = &"moving"
			dedup.lanes[target_lane].combat_model.accept_transferred_enemy(extracted)
	_advance_projectiles(dedup, 0.8)
	location = dedup.call("_find_enemy_by_spawn_id", snake_spawn_id)
	_check(not location.is_empty() and int(location.enemy.hp) == 5, "Snake remapped into the other targeted lane is not hit twice by the same wide attack")
	dedup.queue_free()
	await process_frame

func _test_healing_and_emergency() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.GREEN)
	model.clear_for_test()
	model.max_enemies = 6
	model.spawn_enemy(6.5, -1, false, EnemyTypesScript.Type.HEALYZARD, 2700)
	var hopper_uid := model.spawn_enemy(5.0, 4, false, EnemyTypesScript.Type.HOPPER, 2701)
	var heavy_uid := model.spawn_enemy(5.5, 10, false, EnemyTypesScript.Type.HEAVY, 2702)
	var snake_uid := model.spawn_enemy(6.0, 4, false, EnemyTypesScript.Type.SICKLE_SNAKE, 2703)
	model.update(15.0)
	var health := {}
	for enemy in model.enemies:
		health[int(enemy.uid)] = [int(enemy.hp), int(enemy.max_hp)]
	_check(health[hopper_uid] == [5, 6] and health[heavy_uid] == [11, 12] and health[snake_uid] == [5, 6], "Healyzard pulse remains +1 and respects the tripled canonical caps")
	model.call("_discharge_emergency")
	_check(model.enemies.is_empty() and model.total_emergency_cleared == 4 and model.total_killed == 0, "emergency remains an instant clear regardless of 6/12 HP")

func _finish() -> void:
	if _failures.is_empty():
		print("P022 HP and penetrating attacks: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P022 HP and penetrating attacks: " + failure)
	print("P022 HP and penetrating attacks: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
