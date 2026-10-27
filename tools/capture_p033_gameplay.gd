extends SceneTree

const EnemyTypesScript = preload("res://scripts/world/enemy_types.gd")
const CAPTURES := [
	{"size": Vector2i(1280, 720), "path": "res://assets/previews/p033_controls_hit_flash_1280x720.png", "settings": false, "comparison": false},
	{"size": Vector2i(1600, 720), "path": "res://assets/previews/p033_controls_settings_1600x720.png", "settings": true, "comparison": false},
	{"size": Vector2i(1280, 512), "path": "res://assets/previews/p033r_hit_overlay_comparison_1280x512.png", "settings": false, "comparison": true},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://assets/previews")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("P033 capture cannot create preview directory")
		quit(1)
		return
	for definition in CAPTURES:
		if not await _capture(definition):
			quit(1)
			return
	print("P033 capture: wrote %d real-renderer screenshots" % CAPTURES.size())
	quit(0)

func _capture(definition: Dictionary) -> bool:
	var capture_size: Vector2i = definition.size
	var viewport := SubViewport.new()
	viewport.size = capture_size
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	if bool(definition.comparison):
		_build_comparison(viewport, Vector2(capture_size))
	else:
		var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		await process_frame
		await process_frame
		main.call("_apply_layout", Vector2(capture_size), Rect2(Vector2.ZERO, Vector2(capture_size)))
		_stage_fixture(main)
		if bool(definition.settings):
			(main.get("_settings_view") as ControlSettingsView).call("_open")
		main.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != capture_size:
		push_error("P033 capture returned invalid image at %s" % capture_size)
		return false
	image.convert(Image.FORMAT_RGBA8)
	var result := image.save_png(ProjectSettings.globalize_path(str(definition.path)))
	viewport.queue_free()
	await process_frame
	return result == OK

func _stage_fixture(main: Node) -> void:
	(main.get("_sfx") as SfxManager).muted = true
	var battlefield: Battlefield = main.get("_battlefield")
	battlefield.set_process(false)
	battlefield.call("_reset_spawn_director", false)
	var types := [EnemyTypesScript.Type.HOPPER, EnemyTypesScript.Type.HEAVY, EnemyTypesScript.Type.SICKLE_SNAKE, EnemyTypesScript.Type.HEALYZARD]
	for lane_index in range(4):
		var lane: LaneActor = battlefield.lanes[lane_index]
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
		var uid := battlefield.spawn_directed_enemy(lane_index, types[lane_index], 1.2 + lane_index * 1.15, -1, true)
		lane.call("_sync_visuals")
		if lane_index == TeamData.Identity.BLUE:
			lane.combat_model.call("_damage_enemy", uid, 1, 2.35)
			lane.call("_sync_visuals")
		lane.set("_last_status_key", "")
		lane.call("_update_status_visual")
	var shooter: ShooterView = main.get("_shooter_view")
	shooter.move_to(float(main.get("_safe_rect").get_center().x))

func _build_comparison(viewport: SubViewport, capture_size: Vector2) -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.035, 0.065)
	background.size = capture_size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(background)
	var lane := LaneActor.new()
	lane.setup(TeamData.Identity.BLUE, 1)
	lane.position = Vector2(20.0, 62.0)
	lane.size = Vector2(capture_size.x - 40.0, capture_size.y - 92.0)
	viewport.add_child(lane)
	lane.set_process(false)
	lane.combat_model.clear_for_test()
	lane.combat_model.max_enemies = 4
	lane.configure_layout(lane.size)
	var unhit_uid := lane.combat_model.spawn_enemy(0.0, -1, false, EnemyTypesScript.Type.HEAVY, 40331)
	var hit_uid := lane.combat_model.spawn_enemy(4.2, -1, false, EnemyTypesScript.Type.HEAVY, 40332)
	lane.call("_sync_visuals")
	lane.combat_model.call("_damage_enemy", hit_uid, 1, 4.2)
	lane.call("_sync_visuals")
	var source_sprite: Sprite2D = lane.call("_make_actor_sprite", "enemy_heavy")
	source_sprite.name = "DirectSourcePNG"
	source_sprite.position = Vector2(lane.world_x_to_local(-4.2), float(lane.get("_baseline_y")))
	source_sprite.scale = Vector2.ONE * float(lane.get("_actor_scale"))
	source_sprite.z_index = 20
	lane.add_child(source_sprite)
	var headings := ["DIRECT SOURCE PNG", "LIVE UNHIT (IDENTICAL)", "LIVE HIT OVERLAY"]
	var world_positions := [-4.2, 0.0, 4.2]
	for index in range(headings.size()):
		var label := Label.new()
		label.text = headings[index]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.position = Vector2(lane.world_x_to_local(world_positions[index]) - 135.0, 20.0)
		label.size = Vector2(270.0, 36.0)
		label.z_index = 30
		lane.add_child(label)
	# Assert fixture construction early so a missing runtime visual cannot silently
	# produce misleading evidence.
	if not lane.get("_enemy_visuals").has(unhit_uid) or not lane.get("_enemy_visuals").has(hit_uid):
		push_error("P033R comparison fixture failed to create both live Heavy actors")
