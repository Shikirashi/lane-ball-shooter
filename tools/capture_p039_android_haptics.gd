extends SceneTree

const CAPTURES := [
	{
		"size": Vector2i(1280, 720),
		"safe": Rect2(Vector2.ZERO, Vector2(1280, 720)),
		"path": "res://assets/previews/p039_main_controls_1280x720.png",
		"kind": "main_controls",
	},
	{
		"size": Vector2i(1600, 720),
		"safe": Rect2(Vector2.ZERO, Vector2(1600, 720)),
		"path": "res://assets/previews/p039_pause_controls_1600x720.png",
		"kind": "pause_controls",
	},
	{
		"size": Vector2i(1280, 720),
		"safe": Rect2(Vector2(150, 24), Vector2(980, 672)),
		"path": "res://assets/previews/p039_controls_narrow_safe_1280x720.png",
		"kind": "main_controls",
	},
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/previews"))
	for definition in CAPTURES:
		if not await _capture(definition):
			quit(1)
			return
	print("P039 Android haptics capture: wrote %d real-renderer screenshots" % CAPTURES.size())
	quit(0)

func _capture(definition: Dictionary) -> bool:
	var viewport := SubViewport.new()
	viewport.size = definition.size
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var size_value := Vector2(definition.size)
	var safe_rect: Rect2 = definition.safe
	if definition.kind == "pause_controls":
		var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
		main.set_mobile_platform_override(1)
		viewport.add_child(main)
		await process_frame
		await process_frame
		main.call("_apply_layout", size_value, safe_rect)
		var pause: PauseMenuView = main.get("_pause_view")
		pause.show_paused(TouchControlRouter.Mode.CLASSIC, TouchControlRouter.Handedness.RIGHT)
		pause.call("_open_controls")
		main.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		var boot: Node = load("res://scripts/boot.gd").new()
		boot.forced_android_mode = 1
		boot.forced_web_mode = 0
		boot.gameplay_starter = func(): pass
		viewport.add_child(boot)
		await process_frame
		boot.call("_apply_layout", size_value, safe_rect)
		(boot.get("_controls_button") as Button).pressed.emit()
		(boot.get("_control_guide") as ControlGuideView).configure(TouchControlRouter.Mode.CLASSIC, TouchControlRouter.Handedness.RIGHT)
		boot.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty() or image.get_size() != definition.size:
		push_error("P039 invalid capture %s" % definition.path)
		return false
	image.convert(Image.FORMAT_RGBA8)
	var result := image.save_png(ProjectSettings.globalize_path(str(definition.path)))
	viewport.queue_free()
	await process_frame
	return result == OK
