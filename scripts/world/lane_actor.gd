class_name LaneActor
extends Node3D

const LEFT_EDGE := -7.6
const RIGHT_EDGE := 7.6

var team_identity := 0
var lane_index := 0
var logical_enemy_x := RIGHT_EDGE
var _hop_clock := 0.0
var _enemy_model: Node3D
var _enemy_shadow: MeshInstance3D

func setup(identity: int, index: int) -> void:
	team_identity = identity
	lane_index = index

func _ready() -> void:
	_build_lane()
	_build_defender()
	_build_enemy()
	logical_enemy_x = RIGHT_EDGE - lane_index * 0.55
	_hop_clock = lane_index * 0.63

func _process(delta: float) -> void:
	logical_enemy_x -= 0.72 * delta
	if logical_enemy_x < LEFT_EDGE + 0.9:
		logical_enemy_x = RIGHT_EDGE
	_hop_clock += delta * 3.25
	var hop_phase := fmod(_hop_clock, PI)
	var hop_height := sin(hop_phase) * 0.52
	var landing_amount := pow(absf(cos(hop_phase)), 10.0)
	_enemy_model.position = Vector3(logical_enemy_x, 0.29 + hop_height, 0.0)
	_enemy_model.scale = Vector3(1.0 + landing_amount * 0.12, 1.0 - landing_amount * 0.16, 1.0 + landing_amount * 0.12)
	_enemy_shadow.position.x = logical_enemy_x
	_enemy_shadow.scale = Vector3(1.0 - hop_height * 0.35, 1.0, 1.0 - hop_height * 0.35)

func _build_lane() -> void:
	var team_color := TeamData.color(team_identity)
	var floor := PrimitiveFactory.box(Vector3(16.8, 0.12, 1.45), Color(0.1, 0.13, 0.18))
	floor.position.y = -0.1
	add_child(floor)
	var stripe := PrimitiveFactory.box(Vector3(16.8, 0.025, 0.08), team_color.darkened(0.08))
	stripe.position = Vector3(0.0, -0.025, -0.61)
	add_child(stripe)
	var team_marker := PrimitiveFactory.cylinder(0.38, 0.38, 0.035, team_color, 20)
	team_marker.position = Vector3(-7.05, 0.03, 0.0)
	add_child(team_marker)
	_add_team_glyph(team_marker, team_identity)

func _build_defender() -> void:
	var root := Node3D.new()
	root.name = "Defender_%s" % TeamData.display_name(team_identity)
	root.position = Vector3(-5.9, 0.0, 0.0)
	add_child(root)
	var color_value := TeamData.color(team_identity)
	var body := PrimitiveFactory.cylinder(0.32, 0.43, 0.75, color_value)
	body.position.y = 0.42
	root.add_child(body)
	var head := PrimitiveFactory.sphere(0.31, 0.62, color_value.lightened(0.08))
	head.position.y = 1.0
	root.add_child(head)
	var visor := PrimitiveFactory.box(Vector3(0.3, 0.12, 0.11), Color(0.06, 0.08, 0.12))
	visor.position = Vector3(0.0, 1.03, 0.28)
	root.add_child(visor)
	var staff := PrimitiveFactory.cylinder(0.055, 0.055, 1.0, Color(0.75, 0.79, 0.85), 8)
	staff.position = Vector3(0.48, 0.51, 0.0)
	root.add_child(staff)

func _build_enemy() -> void:
	_enemy_shadow = PrimitiveFactory.cylinder(0.37, 0.37, 0.025, Color(0.015, 0.02, 0.03, 0.58), 20)
	_enemy_shadow.name = "GroundShadow"
	_enemy_shadow.position = Vector3(logical_enemy_x, 0.01, 0.0)
	add_child(_enemy_shadow)

	_enemy_model = Node3D.new()
	_enemy_model.name = "HoppingEnemy"
	add_child(_enemy_model)
	var body := PrimitiveFactory.sphere(0.4, 0.8, Color(0.23, 0.25, 0.31))
	body.position.y = 0.35
	_enemy_model.add_child(body)
	var helmet := PrimitiveFactory.cylinder(0.34, 0.43, 0.4, Color(0.12, 0.14, 0.19), 8)
	helmet.position.y = 0.72
	_enemy_model.add_child(helmet)
	for side in [-1.0, 1.0]:
		var eye := PrimitiveFactory.sphere(0.045, 0.09, Color(1.0, 0.44, 0.24))
		eye.position = Vector3(side * 0.13, 0.7, 0.34)
		_enemy_model.add_child(eye)

func _add_team_glyph(parent: Node3D, identity: int) -> void:
	var glyph: MeshInstance3D
	match identity:
		TeamData.Identity.RED:
			glyph = PrimitiveFactory.sphere(0.13, 0.1, Color(0.06, 0.07, 0.1))
		TeamData.Identity.BLUE:
			glyph = PrimitiveFactory.box(Vector3(0.23, 0.08, 0.23), Color(0.06, 0.07, 0.1))
		TeamData.Identity.YELLOW:
			glyph = PrimitiveFactory.cylinder(0.0, 0.17, 0.08, Color(0.06, 0.07, 0.1), 3)
		_:
			glyph = PrimitiveFactory.box(Vector3(0.2, 0.08, 0.2), Color(0.06, 0.07, 0.1))
			glyph.rotation_degrees.y = 45.0
	glyph.position.y = 0.04
	parent.add_child(glyph)

