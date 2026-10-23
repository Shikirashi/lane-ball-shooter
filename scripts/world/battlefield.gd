class_name Battlefield
extends Node3D

signal game_over_requested(identity: int)

var lanes: Array[LaneActor] = []
var attack_history: Array[Dictionary] = []
var game_over := false

func _ready() -> void:
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

func fire_for_match(result: Dictionary) -> Dictionary:
	var outcome := handle_match(result)
	if str(outcome.get("action", "")) == "attack":
		return outcome.get("attack", {})
	return {}

func handle_match(result: Dictionary) -> Dictionary:
	if game_over:
		return {"action": "ignored"}
	var identity := int(result.get("identity", -1))
	if identity < 0 or identity >= lanes.size():
		return {"action": "ignored"}
	var locked_result := result.duplicate(true)
	var outcome := lanes[identity].handle_match(locked_result)
	if str(outcome.get("action", "")) == "attack":
		var attack: Dictionary = outcome.get("attack", {})
		if not attack.is_empty():
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
	for lane in lanes:
		lane.reset_run()

func _on_lane_breached(identity: int, _enemy_uid: int) -> void:
	if game_over:
		return
	game_over = true
	for lane in lanes:
		lane.combat_model.set_game_over(true)
	game_over_requested.emit(identity)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.06, 0.09)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.65, 0.78)
	environment.ambient_light_energy = 0.78
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-54.0, -28.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)

func _build_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "OrthographicCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.5
	camera.position = Vector3(0.0, 9.6, 10.8)
	camera.look_at_from_position(camera.position, Vector3(0.0, 0.0, 0.0))
	camera.current = true
	add_child(camera)

