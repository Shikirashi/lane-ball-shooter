extends SceneTree

const BootScript := preload("res://scripts/boot.gd")
const EnemyTypesScript := preload("res://scripts/world/enemy_types.gd")
const CAPTURES := [
	{"size": Vector2i(1280, 720), "path": "res://assets/previews/p036_gameplay_1280x720.png", "kind": "game"},
	{"size": Vector2i(1600, 720), "path": "res://assets/previews/p036_gameplay_1600x720.png", "kind": "game"},
	{"size": Vector2i(1280, 720), "path": "res://assets/previews/p036_web_start_1280x720.png", "kind": "boot"},
	{"size": Vector2i(1280, 720), "path": "res://assets/previews/p036_web_fullscreen_prompt_1280x720.png", "kind": "prompt"},
	{"size": Vector2i(1600, 720), "path": "res://assets/previews/p036_settings_1600x720.png", "kind": "settings"},
	{"size": Vector2i(1280, 720), "path": "res://assets/previews/p036_wave_cleared_1280x720.png", "kind": "victory"},
	{"size": Vector2i(1280, 720), "path": "res://assets/previews/p036_game_over_1280x720.png", "kind": "defeat"},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output := ProjectSettings.globalize_path("res://assets/previews")
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("P036 capture cannot create preview directory")
		quit(1)
		return
	for definition in CAPTURES:
		if not await _capture(definition):
			quit(1)
			return
	print("P036 capture: wrote %d genuine Compatibility-renderer screenshots" % CAPTURES.size())
	quit(0)

func _capture(definition: Dictionary) -> bool:
	var capture_size: Vector2i = definition.size
	var viewport := SubViewport.new()
	viewport.size = capture_size
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var kind := str(definition.kind)
	if kind == "boot" or kind == "prompt":
		var boot := BootScript.new()
		boot.forced_web_mode = 1
		boot.gameplay_starter = func() -> void: pass
		viewport.add_child(boot)
		await process_frame
		boot.call("_apply_layout", Vector2(capture_size), Rect2(Vector2.ZERO, Vector2(capture_size)))
		if kind == "prompt":
			(boot.get("_start_button") as Button).pressed.emit()
		boot.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
		viewport.add_child(main)
		await process_frame
		await process_frame
		main.call("_apply_layout", Vector2(capture_size), Rect2(Vector2.ZERO, Vector2(capture_size)))
		_stage_fixture(main)
		if kind == "settings":
			(main.get("_settings_view") as ControlSettingsView).call("_open")
		elif kind == "victory":
			(main.get("_game_over_overlay") as GameOverOverlay).show_wave_cleared(18420)
		elif kind == "defeat":
			(main.get("_game_over_overlay") as GameOverOverlay).show_game_over(7350)
		main.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != capture_size:
		push_error("P036 capture returned invalid image for %s" % definition.path)
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
	for lane_index in range(TeamData.COUNT):
		var lane: LaneActor = battlefield.lanes[lane_index]
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
		battlefield.spawn_directed_enemy(lane_index, types[lane_index], 1.3 + lane_index * 1.05, -1, true)
		lane.call("_sync_visuals")
		lane.set("_last_status_key", "")
		lane.call("_update_status_visual")
	(main.get("_shooter_view") as ShooterView).move_to(float(main.get("_safe_rect").get_center().x))
	(main.get("_hud_view") as HudView).set_progress(7350, 3, 3, false, 0.68)
