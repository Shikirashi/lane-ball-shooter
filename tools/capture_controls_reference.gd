extends SceneTree

const EnemyTypesScript := preload("res://scripts/world/enemy_types.gd")
const OUTPUT := "res://assets/ui/controls_gameplay_reference.png"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	main.call("_apply_layout", Vector2(1280, 720), Rect2(Vector2.ZERO, Vector2(1280, 720)))
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
		battlefield.spawn_directed_enemy(lane_index, types[lane_index], 1.3 + lane_index, -1, true)
		lane.call("_sync_visuals")
	(main.get("_shooter_view") as ShooterView).move_to(640.0)
	main.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var result := image.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("P037 controls reference: %s" % ("PASS" if result == OK else "FAIL"))
	quit(0 if result == OK else 1)
