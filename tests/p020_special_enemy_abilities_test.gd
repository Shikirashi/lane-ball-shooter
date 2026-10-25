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
	await _test_snake_stun_transfer_frame_rates()
	await _test_direction_capacity_identity_and_death()
	_test_healyzard_timers_targets_and_caps()
	await _test_healing_aura_texture_and_lifecycle()
	await _test_transfer_then_heal_current_lane()
	_test_preserved_conveyor()
	_finish()

func _new_battlefield(seed := 2020) -> Battlefield:
	var battlefield := Battlefield.new()
	battlefield.set_spawn_rng_seed(seed)
	battlefield.set_snake_direction_rng_seed(seed + 1)
	root.add_child(battlefield)
	return battlefield

func _prepare_fixture(battlefield: Battlefield) -> void:
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
	battlefield.call("_reset_spawn_director", false)
	for index in range(4):
		battlefield.get("_spawn_timers")[index] = 999.0

func _step(battlefield: Battlefield, delta: float) -> void:
	battlefield.call("_process", delta)
	for lane in battlefield.lanes:
		lane.call("_process", delta)

func _location(battlefield: Battlefield, spawn_id: int) -> Dictionary:
	return battlefield.call("_find_enemy_by_spawn_id", spawn_id)

func _advance_exact(battlefield: Battlefield, duration: float, step: float) -> void:
	var elapsed := 0.0
	while elapsed < duration - 0.0000001:
		var slice := minf(step, duration - elapsed)
		_step(battlefield, slice)
		elapsed += slice

func _test_snake_stun_transfer_frame_rates() -> void:
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.08]:
		var battlefield := _new_battlefield(3000 + int(step * 10000.0))
		await process_frame
		_prepare_fixture(battlefield)
		var uid := battlefield.spawn_directed_enemy(0, EnemyTypesScript.Type.SICKLE_SNAKE, 2.0)
		var snake: Dictionary = battlefield.lanes[0].combat_model.enemies[0]
		var spawn_id := int(snake.spawn_id)
		battlefield.lanes[0].call("_sync_visuals")
		battlefield.lanes[0].combat_model.call("_damage_enemy", uid, 1, 2.0)
		var hit_x := float(_location(battlefield, spawn_id).enemy.x)
		_check(StringName(_location(battlefield, spawn_id).enemy.special_state) == &"stunned" and int(_location(battlefield, spawn_id).enemy.hp) == 1, "nonfatal Snake hit immediately enters one stun at dt %.4f" % step)
		_advance_exact(battlefield, 0.499, step)
		_check(int(_location(battlefield, spawn_id).lane_index) == 0 and is_equal_approx(float(_location(battlefield, spawn_id).enemy.x), hit_x), "Snake remains stopped in origin through 0.499s at dt %.4f" % step)
		_step(battlefield, 0.001)
		var transferring := _location(battlefield, spawn_id)
		_check(int(transferring.lane_index) == 1 and StringName(transferring.enemy.special_state) == &"transferring", "edge Snake begins exactly one adjacent transfer at 0.5s")
		_check(int(transferring.enemy.spawn_id) == spawn_id and int(transferring.enemy.hp) == 1 and is_equal_approx(float(transferring.enemy.x), hit_x), "transfer preserves global identity, HP and logical X")
		var transition_uid := int(transferring.enemy.uid)
		var visual: Dictionary = battlefield.lanes[1].get("_enemy_visuals")[transition_uid]
		_check(absf((visual.root as Node3D).position.z) > 0.1, "transferred body starts visibly between lane Z positions")
		_advance_exact(battlefield, Battlefield.SNAKE_TRANSFER_DURATION, step)
		var arrived := _location(battlefield, spawn_id)
		_check(int(arrived.lane_index) == 1 and StringName(arrived.enemy.special_state) == &"moving" and absf(float(arrived.enemy.transfer_visual_z)) < 0.001, "Snake completes smooth transfer in %.2fs" % Battlefield.SNAKE_TRANSFER_DURATION)
		var arrived_x := float(arrived.enemy.x)
		_step(battlefield, 0.25)
		_check(absf(float(_location(battlefield, spawn_id).enemy.x) - (arrived_x - 0.156)) < 0.001, "Snake resumes 0.624-unit/s slide only after transfer")
		_check(battlefield.lanes[0].combat_model.spawned_this_encounter == 1 and battlefield.lanes[1].combat_model.spawned_this_encounter == 0 and battlefield.encounter_live() == 1, "transfer consumes no destination quota and never duplicates live count")
		battlefield.queue_free()
		await process_frame

func _fill_lane(battlefield: Battlefield, lane_index: int, count: int) -> void:
	for index in range(count):
		battlefield.spawn_directed_enemy(lane_index, EnemyTypesScript.Type.HOPPER, 4.0 + index * 0.25, -1, false)

func _test_direction_capacity_identity_and_death() -> void:
	var sampler := _new_battlefield(4100)
	await process_frame
	sampler.set_process(false)
	sampler.set_snake_direction_rng_seed(8181)
	_check(sampler.choose_snake_preferred_lane(0) == 1 and sampler.choose_snake_preferred_lane(3) == 2, "edge lanes transfer inward without wrapping")
	var mid_counts := {0: 0, 2: 0}
	for unused in range(2000):
		var target := sampler.choose_snake_preferred_lane(1)
		mid_counts[target] = int(mid_counts.get(target, 0)) + 1
	_check(mid_counts.keys().size() == 2 and absf(float(mid_counts[0]) / 2000.0 - 0.5) < 0.04, "seeded middle-lane direction is uniform across its two adjacent lanes")
	sampler.queue_free()
	await process_frame

	var fallback := _new_battlefield(4200)
	await process_frame
	_prepare_fixture(fallback)
	_fill_lane(fallback, 0, 5)
	fallback.spawn_directed_enemy(2, EnemyTypesScript.Type.HOPPER, 4.5, -1, false)
	var snake_uid := fallback.spawn_directed_enemy(1, EnemyTypesScript.Type.SICKLE_SNAKE, 2.5)
	var spawn_id := int(fallback.lanes[1].combat_model.enemies[-1].spawn_id)
	var snake: Dictionary = _location(fallback, spawn_id).enemy
	snake.hp = 1
	snake.special_state = &"waiting"
	snake.preferred_lane = 0
	fallback.call("_set_enemy_at_location", _location(fallback, spawn_id), snake)
	fallback.call("_update_snake_special", 0.0)
	_check(int(_location(fallback, spawn_id).lane_index) == 2, "full preferred middle neighbor falls back to the other adjacent lane")
	_check(fallback.lanes[0].combat_model.active_enemy_count() == 5 and fallback.lanes[2].combat_model.active_enemy_count() == 2, "capacity fallback never overfills or duplicates")
	var remapped_uid := int(_location(fallback, spawn_id).enemy.uid)
	_check(remapped_uid != snake_uid and int(_location(fallback, spawn_id).enemy.spawn_id) == spawn_id, "destination remaps collision-safe local UID while preserving immutable spawn ID")
	var death_events := {"count": 0}
	fallback.enemy_death_started.connect(func(_identity: int, _uid: int, _x: float, _cause: StringName) -> void: death_events.count += 1)
	fallback.lanes[2].combat_model.call("_damage_enemy", remapped_uid, 1, 2.5)
	_check(_location(fallback, spawn_id).is_empty() and int(fallback.get("_living_snake_spawn_id")) < 0, "fatal hit during transfer cancels motion and removes exactly one Snake")
	_check(int(death_events.count) == 1 and fallback.lanes[2].get("_death_effects").size() == 1, "fatal transfer hit creates exactly one destination death cue/corpse")
	_check(not fallback.snake_spawn_eligible(), "transferring Snake death starts the unchanged 15-second cooldown")
	fallback.queue_free()
	await process_frame

	var stalled := _new_battlefield(4300)
	await process_frame
	_prepare_fixture(stalled)
	_fill_lane(stalled, 0, 5)
	_fill_lane(stalled, 2, 5)
	stalled.spawn_directed_enemy(1, EnemyTypesScript.Type.SICKLE_SNAKE, 3.0)
	spawn_id = int(stalled.lanes[1].combat_model.enemies[0].spawn_id)
	snake = _location(stalled, spawn_id).enemy
	snake.special_state = &"waiting"
	snake.preferred_lane = 0
	stalled.call("_set_enemy_at_location", _location(stalled, spawn_id), snake)
	stalled.call("_update_snake_special", 0.5)
	_check(int(_location(stalled, spawn_id).lane_index) == 1 and StringName(_location(stalled, spawn_id).enemy.special_state) == &"waiting", "Snake stalls in origin when both adjacent lanes are full")
	stalled.lanes[2].combat_model.clear_enemies_for_tier3()
	stalled.call("_update_snake_special", 0.0)
	_check(int(_location(stalled, spawn_id).lane_index) == 2, "stalled Snake transfers once an adjacent lane gains capacity")
	stalled.lanes[2].combat_model.call("_discharge_emergency")
	_check(_location(stalled, spawn_id).is_empty() and not stalled.snake_spawn_eligible(), "emergency in authoritative destination kills transferred Snake and starts cooldown")
	stalled.queue_free()
	await process_frame

	var tier_clear := _new_battlefield(4400)
	await process_frame
	_prepare_fixture(tier_clear)
	tier_clear.spawn_directed_enemy(3, EnemyTypesScript.Type.SICKLE_SNAKE, 3.5)
	spawn_id = int(tier_clear.lanes[3].combat_model.enemies[0].spawn_id)
	snake = _location(tier_clear, spawn_id).enemy
	snake.special_state = &"waiting"
	snake.preferred_lane = 2
	tier_clear.call("_set_enemy_at_location", _location(tier_clear, spawn_id), snake)
	tier_clear.call("_update_snake_special", 0.0)
	_check(int(_location(tier_clear, spawn_id).lane_index) == 2, "bottom-edge Snake transfers only to adjacent lane 2")
	tier_clear.lanes[2].combat_model.clear_enemies_for_tier3()
	_check(_location(tier_clear, spawn_id).is_empty() and not tier_clear.snake_spawn_eligible(), "tier-3 clear in authoritative destination kills transferred Snake and starts cooldown")
	tier_clear.queue_free()
	await process_frame

func _find_by_type(model: LaneCombatModel, enemy_type: int, occurrence := 0) -> Dictionary:
	var seen := 0
	for enemy in model.enemies:
		if int(enemy.type) == enemy_type:
			if seen == occurrence:
				return enemy
			seen += 1
	return {}

func _test_healyzard_timers_targets_and_caps() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.GREEN)
	model.clear_for_test()
	model.max_enemies = 8
	var healer_a := model.spawn_enemy(6.7, -1, false, EnemyTypesScript.Type.HEALYZARD, 500)
	var hopper := model.spawn_enemy(5.0, -1, false, EnemyTypesScript.Type.HOPPER, 501)
	var heavy := model.spawn_enemy(5.5, -1, false, EnemyTypesScript.Type.HEAVY, 502)
	var snake := model.spawn_enemy(6.0, -1, false, EnemyTypesScript.Type.SICKLE_SNAKE, 503)
	model.call("_damage_enemy", hopper, 1, 5.0)
	model.call("_damage_enemy", heavy, 2, 5.5)
	model.call("_damage_enemy", snake, 1, 6.0)
	var pulses: Array[Dictionary] = []
	model.healer_pulsed.connect(func(event: Dictionary) -> void: pulses.append(event.duplicate(true)))
	model.update(14.999)
	_check(pulses.is_empty(), "Healyzard does not pulse before its exact 15-second boundary")
	model.update(0.001)
	_check(pulses.size() == 1 and int(pulses[0].healer_uid) == healer_a and int(pulses[0].lane_index) == TeamData.Identity.GREEN, "first healer emits one typed lane pulse at 15.000 seconds")
	_check(int(pulses[0].restored_hp) == 3 and pulses[0].targeted_spawn_ids.size() == 3, "pulse targets every other non-Healyzard and reports total restored HP")
	_check(int(_find_by_type(model, EnemyTypesScript.Type.HOPPER).hp) == 2 and int(_find_by_type(model, EnemyTypesScript.Type.HEAVY).hp) == 3 and int(_find_by_type(model, EnemyTypesScript.Type.SICKLE_SNAKE).hp) == 2, "pulse restores exactly one HP capped by each target maximum")

	var healer_b := model.spawn_enemy(5.8, -1, false, EnemyTypesScript.Type.HEALYZARD, 504)
	model.update(7.5)
	_check(pulses.size() == 1, "second healer owns an independent timer from its later spawn")
	model.call("_damage_enemy", heavy, 1, 5.0)
	model.update(7.5)
	_check(pulses.size() == 3, "at 30 seconds healer A's second pulse and healer B's first pulse remain independent")
	_check(int(_find_by_type(model, EnemyTypesScript.Type.HEALYZARD, 0).hp) == 2 and int(_find_by_type(model, EnemyTypesScript.Type.HEALYZARD, 1).hp) == 2, "healers never heal themselves or other Healyzards")
	_check(int(_find_by_type(model, EnemyTypesScript.Type.HEAVY).hp) <= int(_find_by_type(model, EnemyTypesScript.Type.HEAVY).max_hp), "repeated pulses never exceed target max HP")
	var pulse_count := pulses.size()
	model.set_game_over(true)
	model.update(60.0)
	_check(pulses.size() == pulse_count, "terminal combat freeze prevents deferred/postmortem healing")
	model.clear_for_test()
	_check(model.enemies.is_empty(), "restart clears every independent healer timer with its enemy")

	var zero_restore := LaneCombatModel.new(TeamData.Identity.BLUE)
	zero_restore.clear_for_test()
	zero_restore.spawn_enemy(6.7, -1, false, EnemyTypesScript.Type.HEALYZARD, 600)
	zero_restore.spawn_enemy(5.0, -1, false, EnemyTypesScript.Type.HOPPER, 601)
	var zero_events: Array[Dictionary] = []
	zero_restore.healer_pulsed.connect(func(event: Dictionary) -> void: zero_events.append(event))
	zero_restore.update(15.0)
	_check(zero_events.size() == 1 and int(zero_events[0].restored_hp) == 0 and zero_events[0].targeted_spawn_ids == [601], "full-HP targets still produce an accurate zero-restoration pulse event")

func _test_healing_aura_texture_and_lifecycle() -> void:
	var lane := LaneActor.new()
	lane.setup(TeamData.Identity.YELLOW, 2)
	root.add_child(lane)
	await process_frame
	lane.set_process(false)
	lane.combat_model.clear_for_test()
	var healer_uid := lane.combat_model.spawn_enemy(6.7, -1, false, EnemyTypesScript.Type.HEALYZARD, 700)
	var hopper_uid := lane.combat_model.spawn_enemy(5.0, -1, false, EnemyTypesScript.Type.HOPPER, 701)
	lane.call("_sync_visuals")
	var healer_visual: Dictionary = lane.get("_enemy_visuals")[healer_uid]
	var hopper_visual: Dictionary = lane.get("_enemy_visuals")[hopper_uid]
	var aura: Sprite3D = healer_visual.aura
	_check(aura != null and float(aura.position.z) < 0.0 and hopper_visual.aura == null, "only Healyzard owns a reusable aura positioned behind its body")
	var texture := LaneActor.healing_aura_texture()
	var same_texture := LaneActor.healing_aura_texture()
	var image := texture.get_image()
	var center_alpha := image.get_pixel(image.get_width() / 2, image.get_height() / 2).a
	var edge_alpha := image.get_pixel(0, image.get_height() / 2).a
	_check(texture == same_texture and center_alpha > 0.6 and edge_alpha < 0.02, "shared radial texture has bright center, transparent circumference and no per-pulse allocation")
	lane.combat_model.update(15.0)
	_check(aura.visible and aura.modulate.a > 0.7, "healing pulse reveals soft yellow aura even with no wounded target")
	lane.call("_update_healing_auras", 0.6)
	_check(aura.visible and aura.modulate.a > 0.0 and aura.scale.x > 1.0, "aura expands and fades during its short animation")
	lane.call("_update_healing_auras", 0.26)
	_check(not aura.visible and aura.modulate.a <= 0.001, "aura fades fully and reuses the same hidden node")
	lane.combat_model.call("_damage_enemy", healer_uid, 2, 6.7)
	_check(not aura.visible and lane.get("_death_effects").size() == 1, "healer death hides aura and retains normal P018 corpse/explosion")
	lane.queue_free()
	await process_frame

func _test_transfer_then_heal_current_lane() -> void:
	var battlefield := _new_battlefield(5100)
	await process_frame
	_prepare_fixture(battlefield)
	var healer_uid := battlefield.spawn_directed_enemy(1, EnemyTypesScript.Type.HEALYZARD, 6.7)
	var snake_uid := battlefield.spawn_directed_enemy(0, EnemyTypesScript.Type.SICKLE_SNAKE, 4.0)
	var spawn_id := int(battlefield.lanes[0].combat_model.enemies[0].spawn_id)
	battlefield.lanes[0].combat_model.call("_damage_enemy", snake_uid, 1, 4.0)
	var healer_location := _find_by_type(battlefield.lanes[1].combat_model, EnemyTypesScript.Type.HEALYZARD)
	healer_location.heal_timer = 0.5
	for index in range(battlefield.lanes[1].combat_model.enemies.size()):
		if int(battlefield.lanes[1].combat_model.enemies[index].uid) == healer_uid:
			battlefield.lanes[1].combat_model.enemies[index] = healer_location
	_advance_exact(battlefield, 0.5, 0.1)
	_check(int(_location(battlefield, spawn_id).lane_index) == 1, "Snake becomes authoritative in destination exactly when stun ends")
	battlefield.lanes[1].combat_model.update(0.001)
	_check(int(_location(battlefield, spawn_id).enemy.hp) == 2, "destination healer includes transferring Snake based on current lane at pulse instant")
	_check(battlefield.lanes[0].combat_model.total_spawned == 1 and battlefield.lanes[1].combat_model.total_spawned == 1, "healing and transfer preserve original spawn accounting")
	battlefield.queue_free()
	await process_frame

func _test_preserved_conveyor() -> void:
	var chain := ChainModel.new()
	var original_uid := int(chain.balls[0].uid)
	chain.advance(20.0)
	_check(is_equal_approx(chain.speed, 102.0) and chain._ball_index_by_uid(original_uid) >= 0 and chain.cache.is_empty(), "P017 102 px/s offscreen-left original UID remains physical")
	_check(chain.invariant_violations == 0 and is_equal_approx(ChainModel.INSERT_SETTLE_TIME, 0.05), "P020 leaves conveyor I0 and staged timing unchanged")

func _finish() -> void:
	if _failures.is_empty():
		print("P020 special enemy abilities: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P020 special enemy abilities: " + failure)
	print("P020 special enemy abilities: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
