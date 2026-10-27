extends SceneTree

const ActorVisualFactory = preload("res://scripts/world/actor_visual_factory.gd")
const EnemyTypes = preload("res://scripts/world/enemy_types.gd")

const MASTER_SIZE := Vector2i(512, 512)
const CAMERA_POSITION := Vector3(0.0, 4.8, 5.4)
const CAMERA_TARGET := Vector3(0.0, 0.62, 0.0)
const CAMERA_SIZE := 2.25
const OUTPUT_DIR := "res://assets/sprites/baked"
const CONTACT_COLUMNS := 4
const CONTACT_CELL := Vector2i(272, 272)
const ACTORS := [
	{"name": "enemy_hopper", "kind": "enemy", "value": EnemyTypes.Type.HOPPER},
	{"name": "enemy_heavy", "kind": "enemy", "value": EnemyTypes.Type.HEAVY},
	{"name": "enemy_sickle_snake", "kind": "enemy", "value": EnemyTypes.Type.SICKLE_SNAKE},
	{"name": "enemy_healyzard", "kind": "enemy", "value": EnemyTypes.Type.HEALYZARD},
	{"name": "defender_red", "kind": "defender", "value": TeamData.Identity.RED},
	{"name": "defender_blue", "kind": "defender", "value": TeamData.Identity.BLUE},
	{"name": "defender_yellow", "kind": "defender", "value": TeamData.Identity.YELLOW},
	{"name": "defender_green", "kind": "defender", "value": TeamData.Identity.GREEN},
]

var _viewport: SubViewport
var _stage: Node3D
var _actor: Node3D


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	if mkdir_error != OK:
		_fail("Could not create %s (error %d)" % [output_absolute, mkdir_error])
		return
	_build_capture_viewport()
	var metadata := {
		"format_version": 1,
		"master_size": [MASTER_SIZE.x, MASTER_SIZE.y],
		"camera": {
			"projection": "orthogonal",
			"position": [CAMERA_POSITION.x, CAMERA_POSITION.y, CAMERA_POSITION.z],
			"target": [CAMERA_TARGET.x, CAMERA_TARGET.y, CAMERA_TARGET.z],
			"size": CAMERA_SIZE,
		},
		"actors": {},
	}
	for definition in ACTORS:
		var image := await _capture_actor(definition)
		if image == null:
			return
		var asset_path := "%s/%s.png" % [OUTPUT_DIR, definition.name]
		var save_error := image.save_png(ProjectSettings.globalize_path(asset_path))
		if save_error != OK:
			_fail("Could not save %s (error %d)" % [asset_path, save_error])
			return
		var bounds := _alpha_bounds(image)
		metadata.actors[definition.name] = {
			"path": asset_path,
			"alpha_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"pivot": [MASTER_SIZE.x / 2, bounds.end.y],
		}
	var metadata_file := FileAccess.open("%s/pivots.json" % OUTPUT_DIR, FileAccess.WRITE)
	if metadata_file == null:
		_fail("Could not write pivot metadata")
		return
	metadata_file.store_string(JSON.stringify(metadata, "\t") + "\n")
	metadata_file.close()
	var contact_error := _write_contact_sheet()
	if contact_error != OK:
		_fail("Could not save contact sheet (error %d)" % contact_error)
		return
	print("P034A sprite bake: wrote 8 RGBA masters, pivots.json, and contact_sheet.png to %s" % OUTPUT_DIR)
	quit(0)


func _build_capture_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "TransparentActorCapture"
	_viewport.size = MASTER_SIZE
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)

	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.74, 0.74, 0.76)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	_stage.add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-54.0, -28.0, 0.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	_stage.add_child(light)

	var camera := Camera3D.new()
	camera.name = "OrthographicCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = CAMERA_SIZE
	camera.look_at_from_position(CAMERA_POSITION, CAMERA_TARGET)
	camera.current = true
	_stage.add_child(camera)


func _capture_actor(definition: Dictionary) -> Image:
	if is_instance_valid(_actor):
		_actor.queue_free()
		await process_frame
	if definition.kind == "enemy":
		var visual := ActorVisualFactory.create_enemy_visual(_stage, 1, int(definition.value), false)
		_actor = visual.root
		# This is the same grounded center used by LaneActor._update_enemy_visual().
		_actor.position.y = 0.29
	else:
		var visual := ActorVisualFactory.create_defender_visual(_stage, int(definition.value))
		_actor = visual.root
	_actor.name = str(definition.name)
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Renderer returned an empty image for %s" % definition.name)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _alpha_bounds(image: Image) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				minimum.x = mini(minimum.x, x)
				minimum.y = mini(minimum.y, y)
				maximum.x = maxi(maximum.x, x)
				maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _write_contact_sheet() -> Error:
	var rows := ceili(float(ACTORS.size()) / CONTACT_COLUMNS)
	var sheet_size := Vector2i(CONTACT_COLUMNS * CONTACT_CELL.x, rows * CONTACT_CELL.y)
	var sheet := Image.create(sheet_size.x, sheet_size.y, false, Image.FORMAT_RGBA8)
	var checker_size := 16
	for y in range(sheet_size.y):
		for x in range(sheet_size.x):
			var light_square := (int(x / checker_size) + int(y / checker_size)) % 2 == 0
			sheet.set_pixel(x, y, Color("d8dbe2") if light_square else Color("aeb4c0"))
	for index in range(ACTORS.size()):
		var definition: Dictionary = ACTORS[index]
		var source := Image.new()
		var source_path := "%s/%s.png" % [OUTPUT_DIR, definition.name]
		if source.load(ProjectSettings.globalize_path(source_path)) != OK or source.is_empty():
			return ERR_FILE_CORRUPT
		var fitted := source.duplicate()
		fitted.resize(240, 240, Image.INTERPOLATE_LANCZOS)
		var cell_origin := Vector2i((index % CONTACT_COLUMNS) * CONTACT_CELL.x, int(index / CONTACT_COLUMNS) * CONTACT_CELL.y)
		var destination: Vector2i = cell_origin + (CONTACT_CELL - fitted.get_size()) / 2
		sheet.blend_rect(fitted, Rect2i(Vector2i.ZERO, fitted.get_size()), destination)
		var marker := TeamData.color(index - 4) if index >= 4 else Color(0.12, 0.14, 0.19)
		for marker_y in range(8):
			for marker_x in range(CONTACT_CELL.x):
				sheet.set_pixel(cell_origin.x + marker_x, cell_origin.y + marker_y, marker)
	return sheet.save_png(ProjectSettings.globalize_path("%s/contact_sheet.png" % OUTPUT_DIR))


func _fail(message: String) -> void:
	push_error("P034A sprite bake: %s" % message)
	quit(1)
