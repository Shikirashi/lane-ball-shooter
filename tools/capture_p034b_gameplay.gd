extends SceneTree

const CAPTURES := [
	{"size": Vector2i(1280, 720), "path": "res://assets/previews/p034b_gameplay_1280x720.png"},
	{"size": Vector2i(1600, 720), "path": "res://assets/previews/p034b_gameplay_1600x720.png"},
]
const EnemyTypes = preload("res://scripts/world/enemy_types.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://assets/previews")
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("P034B capture could not create %s" % output_dir)
		quit(1)
		return
	for definition in CAPTURES:
		if not await _capture(definition.size, str(definition.path)):
			quit(1)
			return
	print("P034B gameplay capture: wrote %d real-renderer screenshots" % CAPTURES.size())
	quit(0)


func _capture(capture_size: Vector2i, output_path: String) -> bool:
	var capture_viewport := SubViewport.new()
	capture_viewport.name = "P034BGameplayCapture"
	capture_viewport.size = capture_size
	capture_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(capture_viewport)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	capture_viewport.add_child(main)
	await process_frame
	await process_frame
	main.call("_apply_layout", Vector2(capture_size), Rect2(Vector2.ZERO, Vector2(capture_size)))
	_stage_review_fixture(main)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := capture_viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != capture_size:
		push_error("P034B capture returned invalid image for %s" % capture_size)
		capture_viewport.queue_free()
		await process_frame
		return false
	image.convert(Image.FORMAT_RGBA8)
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	capture_viewport.queue_free()
	await process_frame
	if error != OK:
		push_error("P034B capture could not save %s (error %d)" % [output_path, error])
		return false
	return true


func _stage_review_fixture(main: Node) -> void:
	var battlefield: Battlefield = main.get("_battlefield")
	battlefield.set_process(false)
	battlefield.set_attack_rng_seed(3402)
	battlefield.set_spawn_rng_seed(3403)
	battlefield.call("_reset_spawn_director", false)
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
		lane.set("_visual_time", 0.72 + lane.lane_index * 0.19)

	var fixtures := [
		[[EnemyTypes.Type.HOPPER, -0.4], [EnemyTypes.Type.HEAVY, 4.5]],
		[[EnemyTypes.Type.SICKLE_SNAKE, 2.0], [EnemyTypes.Type.HOPPER, 5.4]],
		[[EnemyTypes.Type.HEAVY, 1.2], [EnemyTypes.Type.HEALYZARD, 6.7]],
		[[EnemyTypes.Type.HOPPER, 0.4], [EnemyTypes.Type.HEALYZARD, 6.2]],
	]
	var healer_uids := []
	for lane_index in range(fixtures.size()):
		for fixture in fixtures[lane_index]:
			var uid := battlefield.spawn_directed_enemy(lane_index, int(fixture[0]), float(fixture[1]), -1, true)
			if int(fixture[0]) == EnemyTypes.Type.HEALYZARD:
				healer_uids.append([lane_index, uid])
		var model := battlefield.lanes[lane_index].combat_model
		for enemy_index in range(model.enemies.size()):
			var enemy: Dictionary = model.enemies[enemy_index]
			if int(enemy.type) == EnemyTypes.Type.HOPPER:
				enemy.hop_airborne = true
				enemy.hop_progress = 0.35 + lane_index * 0.11
			model.enemies[enemy_index] = enemy
		battlefield.lanes[lane_index].call("_sync_visuals")

	var attack_lane: LaneActor = battlefield.lanes[TeamData.Identity.RED]
	attack_lane.handle_match({"identity": TeamData.Identity.RED, "tier": 2, "fever": false, "group_size": 4})
	attack_lane.set("_attack_feedback", 0.21)
	attack_lane.call("_sync_visuals")
	var tier3_lane: LaneActor = battlefield.lanes[TeamData.Identity.BLUE]
	tier3_lane.show_tier3_clear_wave()
	for healer_entry in healer_uids:
		battlefield.lanes[int(healer_entry[0])].call("_on_healer_pulsed", {"healer_uid": int(healer_entry[1])})
	var down_lane: LaneActor = battlefield.lanes[TeamData.Identity.GREEN]
	down_lane.combat_model.defender_state = LaneCombatModel.DefenderState.DOWN
	down_lane.combat_model.revival_progress = 1
	down_lane.combat_model.emergency_available = false
	down_lane.set("_last_status_key", "")
	down_lane.call("_update_status_visual")
	down_lane.call("_update_defender_feedback", 0.0)
