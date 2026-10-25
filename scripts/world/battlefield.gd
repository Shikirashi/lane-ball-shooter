class_name Battlefield
extends Node3D

const EnemyTypes = preload("res://scripts/world/enemy_types.gd")

signal game_over_requested(identity: int)
signal encounter_cleared
signal encounter_progress_changed(neutralized: int, total: int, remaining: int)
signal defender_knocked_down(identity: int)
signal defender_revived(identity: int)
signal enemy_death_started(identity: int, enemy_uid: int, impact_x: float, cause: StringName)

const SNAKE_DEATH_COOLDOWN := 15.0
const HEALYZARD_REAR_X := LaneCombatModel.RIGHT_BOUNDARY - 0.9
const HEALYZARD_SLOT_SPACING := 0.82

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

func _ready() -> void:
	if _attack_rng_seed == 0:
		_attack_rng_seed = Time.get_ticks_usec()
	_attack_rng.seed = _attack_rng_seed
	_spawn_rng.seed = _spawn_rng_seed
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
		lane.enemy_death_started.connect(_on_enemy_death_started)
	_reset_spawn_director(true)
	_publish_encounter_progress()

func _process(delta: float) -> void:
	_update_spawn_director(maxf(delta, 0.0))
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

