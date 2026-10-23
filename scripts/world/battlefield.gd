class_name Battlefield
extends Node3D

var lanes: Array[LaneActor] = []
var attack_history: Array[Dictionary] = []

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

func fire_for_match(result: Dictionary) -> Dictionary:
	var identity := int(result.get("identity", -1))
	if identity < 0 or identity >= lanes.size():
		return {}
	var locked_result := result.duplicate(true)
	var attack := lanes[identity].fire_for_match(locked_result)
	if not attack.is_empty():
		attack_history.append(attack.duplicate(true))
	return attack

func get_lane(identity: int) -> LaneActor:
	if identity < 0 or identity >= lanes.size():
		return null
	return lanes[identity]

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

