class_name Battlefield
extends Node3D

const EnemyTypes = preload("res://scripts/world/enemy_types.gd")

signal game_over_requested(identity: int)
signal encounter_cleared
signal encounter_progress_changed(neutralized: int, total: int, remaining: int)
signal defender_knocked_down(identity: int)
signal defender_revived(identity: int)
signal enemy_death_started(identity: int, enemy_uid: int, impact_x: float, cause: StringName)
signal healer_pulsed(event: Dictionary)

const SNAKE_DEATH_COOLDOWN := 15.0
const HEALYZARD_REAR_X := LaneCombatModel.RIGHT_BOUNDARY - 0.9
const HEALYZARD_SLOT_SPACING := 0.82
const SNAKE_TRANSFER_DURATION := 0.3

var lanes: Array[LaneActor] = []
var attack_history: Array[Dictionary] = []
var game_over := false
var victory := false
var _camera: Camera3D
var _attack_rng := RandomNumberGenerator.new()
var _attack_rng_seed := 0
var _spawn_rng := RandomNumberGenerator.new()
var _spawn_rng_seed := 0x19E019
var _spawn_timers: Array[float] = []
var _spawn_simulation_time := 0.0
var _next_global_spawn_id := 1
var _living_snake_spawn_id := -1
var _snake_cooldown_until := 0.0
var _neutralized_spawn_ids := {}
var _snake_direction_rng := RandomNumberGenerator.new()
var _snake_direction_rng_seed := 0x20A020

func _ready() -> void:
	if _attack_rng_seed == 0:
		_attack_rng_seed = Time.get_ticks_usec()
	_attack_rng.seed = _attack_rng_seed
	_spawn_rng.seed = _spawn_rng_seed
	_snake_direction_rng.seed = _snake_direction_rng_seed
	_build_environment()
	_build_camera()
	for lane_index in range(TeamData.COUNT):
		var lane := LaneActor.new()
		lane.name = "Lane%d" % (lane_index + 1)
		lane.setup(lane_index, lane_index, true)
		lane.position.z = -3.0 + lane_index * 2.0
		add_child(lane)
		lanes.append(lane)
		lane.combat_model.breached.connect(_on_lane_breached)
		lane.combat_model.defender_knocked_down.connect(_on_defender_knocked_down)
		lane.combat_model.defender_revived.connect(_on_defender_revived)
		lane.combat_model.encounter_state_changed.connect(_on_encounter_state_changed)
		lane.combat_model.enemy_neutralized_detail.connect(_on_enemy_neutralized_detail.bind(lane_index))
		lane.combat_model.healer_pulsed.connect(_on_healer_pulsed)
		lane.enemy_death_started.connect(_on_enemy_death_started)
	_reset_spawn_director(true)
	_publish_encounter_progress()

func _process(delta: float) -> void:
	_update_spawn_director(maxf(delta, 0.0))
	_update_snake_special(maxf(delta, 0.0))
	_evaluate_terminal_state()

func fire_for_match(result: Dictionary) -> Dictionary:
	var outcome := handle_match(result)
	if str(outcome.get("action", "")) == "attack":
		return outcome.get("attack", {})
	return {}

func handle_match(result: Dictionary) -> Dictionary:
	if game_over or victory:
		return {"action": "ignored"}
	for lane in lanes:
		if lane.combat_model.check_terminal_breach():
			return {"action": "breach"}
	var identity := int(result.get("identity", -1))
	if identity < 0 or identity >= lanes.size():
		return {"action": "ignored"}
	var locked_result := result.duplicate(true)
	var outcome := lanes[identity].handle_match(locked_result)
	if str(outcome.get("action", "")) == "attack":
		var attack: Dictionary = outcome.get("attack", {})
		if not attack.is_empty():
			if int(attack.get("tier", 1)) >= 3:
				attack = _resolve_tier3_attack(identity, attack)
				outcome.attack = attack
			attack_history.append(attack.duplicate(true))
			while attack_history.size() > LaneCombatModel.HISTORY_LIMIT:
				attack_history.pop_front()
	return outcome

func get_lane(identity: int) -> LaneActor:
	if identity < 0 or identity >= lanes.size():
		return null
	return lanes[identity]

func reset_run() -> void:
	game_over = false
	victory = false
	attack_history.clear()
	_attack_rng.seed = _attack_rng_seed
	for lane in lanes:
		lane.reset_run(false)
	_reset_spawn_director(true)
	for lane in lanes:
		lane.call("_sync_visuals")
	_publish_encounter_progress()

func set_attack_rng_seed(seed_value: int) -> void:
	_attack_rng_seed = seed_value if seed_value != 0 else 1
	_attack_rng.seed = _attack_rng_seed

func set_spawn_rng_seed(seed_value: int) -> void:
	_spawn_rng_seed = seed_value if seed_value != 0 else 1
	_spawn_rng.seed = _spawn_rng_seed

func set_snake_direction_rng_seed(seed_value: int) -> void:
	_snake_direction_rng_seed = seed_value if seed_value != 0 else 1
	_snake_direction_rng.seed = _snake_direction_rng_seed

func choose_snake_preferred_lane(origin_lane: int) -> int:
	match origin_lane:
		0:
			return 1
		3:
			return 2
		1:
			return 0 if _snake_direction_rng.randi_range(0, 1) == 0 else 2
		2:
			return 1 if _snake_direction_rng.randi_range(0, 1) == 0 else 3
	return -1

func sample_enemy_type(snake_eligible: bool) -> int:
	var weighted_types: Array[int] = [EnemyTypes.Type.HOPPER, EnemyTypes.Type.HEAVY, EnemyTypes.Type.HEALYZARD]
	if snake_eligible:
		weighted_types.insert(2, EnemyTypes.Type.SICKLE_SNAKE)
	var total_weight := 0
	for enemy_type in weighted_types:
		total_weight += int(EnemyTypes.BASE_WEIGHTS[enemy_type])
	var roll := _spawn_rng.randi_range(1, total_weight)
	for enemy_type in weighted_types:
		roll -= int(EnemyTypes.BASE_WEIGHTS[enemy_type])
		if roll <= 0:
			return enemy_type
	return EnemyTypes.Type.HEALYZARD

func snake_spawn_eligible() -> bool:
	return _living_snake_spawn_id < 0 and _spawn_simulation_time + 0.000001 >= _snake_cooldown_until

func spawn_directed_enemy(lane_index: int, forced_type := -1, x_position := NAN, hp_value := -1, counts_toward_budget := true) -> int:
	if lane_index < 0 or lane_index >= lanes.size() or game_over or victory:
		return -1
	var model := lanes[lane_index].combat_model
	if model.active_enemy_count() >= model.max_enemies:
		return -1
	if counts_toward_budget and model.encounter_spawn_complete():
		return -1
	var enemy_type := forced_type
	if enemy_type < 0:
		enemy_type = sample_enemy_type(snake_spawn_eligible())
	if not EnemyTypes.valid_type(enemy_type):
		return -1
	if enemy_type == EnemyTypes.Type.SICKLE_SNAKE and not snake_spawn_eligible():
		return -1
	var resolved_x := x_position
	if is_nan(resolved_x):
		resolved_x = _healyzard_spawn_x(model) if enemy_type == EnemyTypes.Type.HEALYZARD else LaneCombatModel.RIGHT_BOUNDARY
	var spawn_id := _next_global_spawn_id
	var uid := model.spawn_enemy(resolved_x, hp_value, counts_toward_budget, enemy_type, spawn_id)
	if uid < 0:
		return -1
	_next_global_spawn_id += 1
	if enemy_type == EnemyTypes.Type.SICKLE_SNAKE:
		_living_snake_spawn_id = spawn_id
	return uid

func _healyzard_spawn_x(model: LaneCombatModel) -> float:
	var occupied := 0
	for enemy in model.enemies:
		if int(enemy.get("type", EnemyTypes.Type.HOPPER)) == EnemyTypes.Type.HEALYZARD:
			occupied += 1
	return HEALYZARD_REAR_X - occupied * HEALYZARD_SLOT_SPACING

func _reset_spawn_director(spawn_initial: bool) -> void:
	_spawn_rng.seed = _spawn_rng_seed
	_snake_direction_rng.seed = _snake_direction_rng_seed
	_spawn_simulation_time = 0.0
	_next_global_spawn_id = 1
	_living_snake_spawn_id = -1
	_snake_cooldown_until = 0.0
	_neutralized_spawn_ids.clear()
	_spawn_timers.clear()
	for lane_index in range(lanes.size()):
		_spawn_timers.append(2.8 + lane_index * 1.15)
		lanes[lane_index].combat_model.auto_spawn = false
		if spawn_initial:
			var initial_type := sample_enemy_type(snake_spawn_eligible())
			var initial_x := NAN if initial_type == EnemyTypes.Type.HEALYZARD else 3.6 + lane_index * 0.55
			spawn_directed_enemy(lane_index, initial_type, initial_x)

func _update_spawn_director(delta: float) -> void:
	if game_over or victory or lanes.size() != TeamData.COUNT:
		return
	_spawn_simulation_time += delta
	for lane_index in range(lanes.size()):
		var model := lanes[lane_index].combat_model
		if model.encounter_spawn_complete():
			continue
		_spawn_timers[lane_index] -= delta
		while _spawn_timers[lane_index] <= 0.0 and not model.encounter_spawn_complete():
			if model.active_enemy_count() >= model.max_enemies:
				break
			if spawn_directed_enemy(lane_index) < 0:
				break
			_spawn_timers[lane_index] += maxf(model.spawn_interval, 0.1)

func _update_snake_special(delta: float) -> void:
	if game_over or victory or _living_snake_spawn_id < 0:
		return
	var location := _find_enemy_by_spawn_id(_living_snake_spawn_id)
	if location.is_empty():
		return
	var enemy: Dictionary = location.enemy
	var state := StringName(enemy.get("special_state", &"moving"))
	if state == &"moving":
		enemy.frame_move_fraction = 1.0
		_set_enemy_at_location(location, enemy)
		return
	var remaining_delta := delta
	if state == &"stunned":
		var stun_remaining := float(enemy.get("special_timer", LaneCombatModel.SNAKE_HIT_STUN_DURATION))
		if remaining_delta < stun_remaining - 0.000001:
			enemy.special_timer = stun_remaining - remaining_delta
			enemy.frame_move_fraction = 0.0
			_set_enemy_at_location(location, enemy)
			return
		remaining_delta = maxf(0.0, remaining_delta - stun_remaining)
		enemy.special_timer = 0.0
		enemy.special_state = &"waiting"
		if int(enemy.get("preferred_lane", -1)) < 0:
			enemy.preferred_lane = choose_snake_preferred_lane(int(location.lane_index))
		enemy.frame_move_fraction = 0.0
		_set_enemy_at_location(location, enemy)
		state = &"waiting"
	if state == &"waiting":
		location = _begin_snake_transfer(location)
		if location.is_empty():
			return
		enemy = location.enemy
		state = &"transferring"
	if state == &"transferring":
		var transfer_remaining := float(enemy.get("special_timer", SNAKE_TRANSFER_DURATION))
		if remaining_delta < transfer_remaining - 0.000001:
			enemy.special_timer = transfer_remaining - remaining_delta
			enemy.transfer_visual_z = float(enemy.get("transfer_start_z", 0.0)) * (float(enemy.special_timer) / SNAKE_TRANSFER_DURATION)
			enemy.frame_move_fraction = 0.0
			_set_enemy_at_location(location, enemy)
			return
		var movement_time := maxf(0.0, remaining_delta - transfer_remaining)
		enemy.special_timer = 0.0
		enemy.special_state = &"moving"
		enemy.transfer_visual_z = 0.0
		enemy.frame_move_fraction = movement_time / delta if delta > 0.0 else 0.0
		_set_enemy_at_location(location, enemy)

func _find_enemy_by_spawn_id(spawn_id: int) -> Dictionary:
	for lane_index in range(lanes.size()):
		for enemy_index in range(lanes[lane_index].combat_model.enemies.size()):
			var enemy: Dictionary = lanes[lane_index].combat_model.enemies[enemy_index]
			if int(enemy.get("spawn_id", -1)) == spawn_id:
				return {"lane_index": lane_index, "enemy_index": enemy_index, "enemy": enemy}
	return {}

func _set_enemy_at_location(location: Dictionary, enemy: Dictionary) -> void:
	var model := lanes[int(location.lane_index)].combat_model
	var index := int(location.enemy_index)
	if index >= 0 and index < model.enemies.size() and int(model.enemies[index].get("spawn_id", -1)) == int(enemy.get("spawn_id", -2)):
		model.enemies[index] = enemy
		return
	for fallback_index in range(model.enemies.size()):
		if int(model.enemies[fallback_index].get("spawn_id", -1)) == int(enemy.get("spawn_id", -2)):
			model.enemies[fallback_index] = enemy
			return

func _begin_snake_transfer(location: Dictionary) -> Dictionary:
	var origin_index := int(location.lane_index)
	var enemy: Dictionary = location.enemy
	var preferred := int(enemy.get("preferred_lane", -1))
	var candidates: Array[int] = [preferred]
	if origin_index == 1:
		candidates.append(2 if preferred == 0 else 0)
	elif origin_index == 2:
		candidates.append(3 if preferred == 1 else 1)
	var destination_index := -1
	for candidate in candidates:
		if candidate >= 0 and candidate < lanes.size() and abs(candidate - origin_index) == 1 and lanes[candidate].combat_model.active_enemy_count() < lanes[candidate].combat_model.max_enemies:
			destination_index = candidate
			break
	if destination_index < 0:
		enemy.special_state = &"waiting"
		enemy.frame_move_fraction = 0.0
		_set_enemy_at_location(location, enemy)
		return {}
	var old_uid := int(enemy.uid)
	var visual := lanes[origin_index].take_enemy_visual(old_uid)
	var extracted := lanes[origin_index].combat_model.extract_enemy_for_transfer(old_uid)
	if extracted.is_empty():
		return {}
	extracted.special_state = &"transferring"
	extracted.special_timer = SNAKE_TRANSFER_DURATION
	extracted.preferred_lane = destination_index
	extracted.transfer_start_z = lanes[origin_index].position.z - lanes[destination_index].position.z
	extracted.transfer_visual_z = float(extracted.transfer_start_z)
	extracted.frame_move_fraction = 0.0
	var new_uid := lanes[destination_index].combat_model.accept_transferred_enemy(extracted)
	if new_uid < 0:
		extracted.special_state = &"waiting"
		extracted.special_timer = 0.0
		extracted.transfer_visual_z = 0.0
		var restored_uid := lanes[origin_index].combat_model.accept_transferred_enemy(extracted)
		if not visual.is_empty():
			lanes[origin_index].adopt_enemy_visual(restored_uid, visual)
		return {}
	if not visual.is_empty():
		lanes[destination_index].adopt_enemy_visual(new_uid, visual)
	var new_location := _find_enemy_by_spawn_id(int(extracted.spawn_id))
	return new_location

func encounter_total() -> int:
	var total := 0
	for lane in lanes:
		total += lane.combat_model.enemy_spawn_budget
	return total

func encounter_spawned() -> int:
	var total := 0
	for lane in lanes:
		total += lane.combat_model.spawned_this_encounter
	return total

func encounter_live() -> int:
	var total := 0
	for lane in lanes:
		total += lane.combat_model.active_enemy_count()
	return total

func encounter_neutralized() -> int:
	var total := 0
	for lane in lanes:
		total += lane.combat_model.total_neutralized()
	return total

func encounter_remaining() -> int:
	return maxi(0, encounter_total() - encounter_neutralized())

func _all_spawn_quotas_complete() -> bool:
	if lanes.size() != TeamData.COUNT:
		return false
	for lane in lanes:
		if not lane.combat_model.encounter_spawn_complete():
			return false
	return true

func _evaluate_terminal_state() -> void:
	if game_over or victory or lanes.size() != TeamData.COUNT:
		return
	# Loss always wins a same-update race with the final neutralization.
	for lane in lanes:
		if lane.combat_model.check_terminal_breach():
			return
	if not _all_spawn_quotas_complete() or encounter_live() > 0:
		return
	victory = true
	for lane in lanes:
		lane.combat_model.set_game_over(true)
	_publish_encounter_progress()
	encounter_cleared.emit()

func _publish_encounter_progress() -> void:
	encounter_progress_changed.emit(encounter_neutralized(), encounter_total(), encounter_remaining())

func _on_encounter_state_changed() -> void:
	_publish_encounter_progress()
	_evaluate_terminal_state()

func _resolve_tier3_attack(origin_lane: int, attack: Dictionary) -> Dictionary:
	var neighbors: Array[int] = []
	if origin_lane > 0:
		neighbors.append(origin_lane - 1)
	if origin_lane + 1 < lanes.size():
		neighbors.append(origin_lane + 1)
	var adjacent_lane := neighbors[_attack_rng.randi_range(0, neighbors.size() - 1)]
	var origin_killed := lanes[origin_lane].combat_model.clear_enemies_for_tier3()
	var adjacent_killed := lanes[adjacent_lane].combat_model.clear_enemies_for_tier3()
	lanes[origin_lane].show_tier3_clear_wave()
	lanes[adjacent_lane].show_tier3_clear_wave()
	attack.origin_lane = origin_lane
	attack.adjacent_lane = adjacent_lane
	attack.target_lanes = [origin_lane, adjacent_lane]
	attack.killed_count = origin_killed + adjacent_killed
	attack.projectile_count = 0
	var origin_history := lanes[origin_lane].combat_model.attack_history
	if not origin_history.is_empty():
		origin_history[-1] = attack.duplicate(true)
	return attack

func configure_viewport_aspect(aspect: float) -> void:
	if _camera == null:
		return
	# Keep all four lanes vertically visible and prevent very wide mobile windows
	# from shrinking the battlefield into the middle of excessive empty space.
	_camera.size = clampf(31.0 / maxf(aspect, 1.0), 10.0, 11.5)

func _on_lane_breached(identity: int, _enemy_uid: int) -> void:
	if game_over or victory:
		return
	game_over = true
	for lane in lanes:
		lane.combat_model.set_game_over(true)
	game_over_requested.emit(identity)

func _on_defender_knocked_down(identity: int) -> void:
	defender_knocked_down.emit(identity)

func _on_defender_revived(identity: int, _repelled_count: int) -> void:
	defender_revived.emit(identity)

func _on_enemy_death_started(identity: int, enemy_uid: int, impact_x: float, cause: StringName) -> void:
	enemy_death_started.emit(identity, enemy_uid, impact_x, cause)

func _on_enemy_neutralized_detail(enemy: Dictionary, _cause: StringName, _impact_x: float, _lane_index: int) -> void:
	var spawn_id := int(enemy.get("spawn_id", -1))
	if spawn_id < 0 or _neutralized_spawn_ids.has(spawn_id):
		return
	_neutralized_spawn_ids[spawn_id] = true
	if int(enemy.get("type", EnemyTypes.Type.HOPPER)) == EnemyTypes.Type.SICKLE_SNAKE and spawn_id == _living_snake_spawn_id:
		_living_snake_spawn_id = -1
		_snake_cooldown_until = _spawn_simulation_time + SNAKE_DEATH_COOLDOWN

func _on_healer_pulsed(event: Dictionary) -> void:
	healer_pulsed.emit(event)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.06, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.74, 0.76)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-54.0, -28.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "OrthographicCamera"
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.size = 11.5
	_camera.position = Vector3(0.0, 9.6, 10.8)
	_camera.look_at_from_position(_camera.position, Vector3(0.0, 0.0, 0.0))
	_camera.current = true
	add_child(_camera)

