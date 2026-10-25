class_name Battlefield
extends Node3D

signal game_over_requested(identity: int)
signal defender_knocked_down(identity: int)
signal defender_revived(identity: int)

var lanes: Array[LaneActor] = []
var attack_history: Array[Dictionary] = []
var game_over := false
var _camera: Camera3D
var _attack_rng := RandomNumberGenerator.new()
var _attack_rng_seed := 0

func _ready() -> void:
	if _attack_rng_seed == 0:
		_attack_rng_seed = Time.get_ticks_usec()
	_attack_rng.seed = _attack_rng_seed
	_build_environment()
	_build_camera()
	for lane_index in range(TeamData.COUNT):
		var lane := LaneActor.new()
		lane.name = "Lane%d" % (lane_index + 1)
		lane.setup(lane_index, lane_index)
		lane.position.z = -3.0 + lane_index * 2.0
		add_child(lane)
		lanes.append(lane)
		lane.combat_model.breached.connect(_on_lane_breached)
		lane.combat_model.defender_knocked_down.connect(_on_defender_knocked_down)
		lane.combat_model.defender_revived.connect(_on_defender_revived)

func fire_for_match(result: Dictionary) -> Dictionary:
	var outcome := handle_match(result)
	if str(outcome.get("action", "")) == "attack":
		return outcome.get("attack", {})
	return {}

func handle_match(result: Dictionary) -> Dictionary:
	if game_over:
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
	attack_history.clear()
	_attack_rng.seed = _attack_rng_seed
	for lane in lanes:
		lane.reset_run()

func set_attack_rng_seed(seed_value: int) -> void:
	_attack_rng_seed = seed_value if seed_value != 0 else 1
	_attack_rng.seed = _attack_rng_seed

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
	if game_over:
		return
	game_over = true
	for lane in lanes:
		lane.combat_model.set_game_over(true)
	game_over_requested.emit(identity)

func _on_defender_knocked_down(identity: int) -> void:
	defender_knocked_down.emit(identity)

func _on_defender_revived(identity: int, _repelled_count: int) -> void:
	defender_revived.emit(identity)

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

