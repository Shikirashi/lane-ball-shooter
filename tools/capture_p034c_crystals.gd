extends SceneTree

const EnemyTypes = preload("res://scripts/world/enemy_types.gd")
const CAPTURES := [
	{"size": Vector2i(1280, 720), "path": "res://assets/previews/p034c_crystal_states_1280x720.png", "shatter": false},
	{"size": Vector2i(1600, 720), "path": "res://assets/previews/p034c_crystal_shatter_1600x720.png", "shatter": true},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://assets/previews")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("P034C capture could not create %s" % output_dir)
		quit(1)
		return
	for definition in CAPTURES:
		if not await _capture(definition):
			quit(1)
			return
	print("P034C crystal capture: wrote %d real-renderer screenshots" % CAPTURES.size())
	quit(0)


func _capture(definition: Dictionary) -> bool:
	var capture_size: Vector2i = definition.size
	var viewport := SubViewport.new()
	viewport.name = "P034CCrystalCapture"
	viewport.size = capture_size
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	main.call("_apply_layout", Vector2(capture_size), Rect2(Vector2.ZERO, Vector2(capture_size)))
	_stage_fixture(main, bool(definition.shatter))
	main.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != capture_size:
		push_error("P034C capture returned invalid image for %s" % capture_size)
		viewport.queue_free()
		await process_frame
		return false
	image.convert(Image.FORMAT_RGBA8)
	var error := image.save_png(ProjectSettings.globalize_path(str(definition.path)))
	viewport.queue_free()
	await process_frame
	if error != OK:
		push_error("P034C capture could not save %s (error %d)" % [definition.path, error])
		return false
	return true


func _stage_fixture(main: Node, show_shatter: bool) -> void:
	var battlefield: Battlefield = main.get("_battlefield")
	(main.get("_sfx") as SfxManager).muted = true
	battlefield.set_process(false)
	battlefield.call("_reset_spawn_director", false)
	var types := [EnemyTypes.Type.HOPPER, EnemyTypes.Type.HEAVY, EnemyTypes.Type.SICKLE_SNAKE, EnemyTypes.Type.HEALYZARD]
	for lane_index in range(battlefield.lanes.size()):
		var lane: LaneActor = battlefield.lanes[lane_index]
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
		battlefield.spawn_directed_enemy(lane_index, types[lane_index], 2.5 + lane_index * 0.9, -1, true)
		lane.set("_visual_time", 0.58 + lane_index * 0.21)
		lane.call("_sync_visuals")
		lane.set("_last_status_key", "")
		lane.call("_update_status_visual")

	# GREEN demonstrates a spent one-use charge while retaining the original,
	# full-color defender art. Direct state setup deliberately creates no shards.
	var spent_lane: LaneActor = battlefield.lanes[TeamData.Identity.GREEN]
	spent_lane.combat_model.emergency_available = false
	spent_lane.combat_model.defender_state = LaneCombatModel.DefenderState.DOWN
	spent_lane.combat_model.revival_progress = 1
	spent_lane.set("_last_status_key", "")
	spent_lane.call("_update_status_visual")
	spent_lane.call("_update_defender_feedback", 0.0)

	if show_shatter:
		# This uses the authoritative model method and real connected signal.
		var shatter_lane: LaneActor = battlefield.lanes[TeamData.Identity.YELLOW]
		shatter_lane.combat_model.call("_discharge_emergency")
		shatter_lane.call("_update_charge_shards", 0.16)
		shatter_lane.set("_last_status_key", "")
		shatter_lane.call("_update_status_visual")
