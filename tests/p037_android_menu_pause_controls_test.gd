extends SceneTree

const BootScript := preload("res://scripts/boot.gd")
const PreferencesScript := preload("res://scripts/input/control_preferences.gd")
const PREVIEWS := [
	["res://assets/previews/p037_android_main_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p037_classic_guide_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p037_side_right_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p037_side_left_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p037_pause_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p037_android_main_wide_1600x720.png", Vector2i(1600, 720)],
]

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	_test_platform_routes()
	await _test_android_boot_and_guide()
	await _test_pause_freeze_and_flows()
	_test_reference_and_startup_colors()
	_finish()

func _test_platform_routes() -> void:
	_check(BootScript.platform_uses_android_menu(true), "Android routes to native main menu")
	_check(not BootScript.platform_uses_android_menu(false), "desktop does not route to native menu")
	_check(BootScript.platform_uses_menu(true, false), "Web-only identity keeps fullscreen menu")
	_check(not BootScript.platform_uses_menu(true, true), "Android never receives Web fullscreen prompt")

func _test_android_boot_and_guide() -> void:
	var starts: Array[String] = []
	var boot := BootScript.new()
	var preferences_path := "/tmp/lbs-p037-boot-%d.cfg" % Time.get_ticks_usec()
	boot.set("_preferences", PreferencesScript.new(preferences_path))
	boot.forced_android_mode = 1
	boot.forced_web_mode = 0
	boot.gameplay_starter = func(): starts.append("game")
	root.add_child(boot)
	await process_frame
	_check(boot.get("_menu_root").name == "AndroidMainMenu", "Android starts at genuine native menu")
	_check(boot.get("_play_button").text == "PLAY" and boot.get("_controls_button").text == "CONTROLS", "native menu exposes PLAY and CONTROLS")
	_check(int(boot.gameplay_start_count) == 0 and starts.is_empty(), "native menu constructs no gameplay before PLAY")
	(boot.get("_controls_button") as Button).pressed.emit()
	var guide: ControlGuideView = boot.get("_control_guide")
	_check(guide.visible and guide.preview.texture != null, "CONTROLS opens reusable real-screenshot guide")
	_check(guide.classic_swap_label.text.to_lower() == "tap with another finger to swap" and guide.classic_shoot_label.text.to_lower() == "release fingers to shoot", "Classic guide has exact two-finger instructions")
	_check(guide.annotations.mode == TouchControlRouter.Mode.CLASSIC and guide.classic_swap_label.visible, "Classic guide shows two-finger annotation state")
	var selected := guide.classic_button.get_theme_stylebox("normal") as StyleBoxFlat
	_check(selected != null and selected.border_color == UiPalette.WHITE and selected.corner_radius_top_left >= 12, "selected scheme is raised rounded white-bordered card")
	_check(guide.side_button.get_theme_stylebox("normal") is StyleBoxEmpty, "unselected scheme is plain text without card")
	guide.select_mode(TouchControlRouter.Mode.SIDE)
	guide.select_handedness(TouchControlRouter.Handedness.RIGHT)
	var right_regions := guide.side_regions()
	_check(right_regions.swap.position.x < right_regions.slide.position.x and is_equal_approx(right_regions.swap.size.y, right_regions.shoot.size.y), "right-hand Side guide puts SWAP/SHOOT left and SLIDE right")
	guide.select_handedness(TouchControlRouter.Handedness.LEFT)
	var left_regions := guide.side_regions()
	_check(left_regions.slide.position.x < left_regions.swap.position.x, "left-hand Side guide mirrors all action regions")
	var reloaded_preferences := PreferencesScript.new(preferences_path)
	reloaded_preferences.load_settings()
	_check(reloaded_preferences.mode == TouchControlRouter.Mode.SIDE and reloaded_preferences.handedness == TouchControlRouter.Handedness.LEFT, "control choices persist and reload before gameplay")
	guide.close_requested.emit()
	_check(not guide.visible, "Back closes native control guide")
	(boot.get("_play_button") as Button).pressed.emit()
	(boot.get("_play_button") as Button).pressed.emit()
	_check(starts == ["game"] and int(boot.gameplay_start_count) == 1, "PLAY starts gameplay exactly once")
	boot.queue_free()
	await process_frame
	DirAccess.remove_absolute(preferences_path)

func _test_pause_freeze_and_flows() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var preferences_path := "/tmp/lbs-p037-main-%d.cfg" % Time.get_ticks_usec()
	main.set("_preferences", PreferencesScript.new(preferences_path))
	var menu_returns: Array[String] = []
	main.main_menu_requester = func(): menu_returns.append("menu")
	main.set_mobile_platform_override(1)
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_apply_layout", Vector2(1280, 720), Rect2(Vector2(28, 12), Vector2(1224, 696)))
	var pause: PauseMenuView = main.get("_pause_view")
	_check(pause.pause_button.visible and not (main.get("_settings_view") as ControlSettingsView).gear_button.visible, "Android exposes pause without duplicate gear")
	var chain_time := float((main.get("_chain_model") as ChainModel).simulation_time)
	var enemy_x := float(((main.get("_battlefield") as Battlefield).lanes[0].combat_model.enemies[0]).x)
	var shooter: ShooterView = main.get("_shooter_view")
	shooter.launch(TeamData.Identity.RED)
	var shot_y := float(shooter.get("_shots")[0].position.y)
	(main.get("_touch_router") as TouchControlRouter).press(91, Vector2(500, 600))
	main.call("_pause_game")
	_check(paused and bool(main.get("_paused")) and pause.is_open(), "pause freezes tree and opens responsive overlay")
	_check((main.get("_touch_router") as TouchControlRouter).primary_id == -1, "opening pause cancels active touch ownership")
	for ignored in range(4):
		await process_frame
	_check(is_equal_approx(float((main.get("_chain_model") as ChainModel).simulation_time), chain_time), "paused conveyor/fever clock does not advance")
	_check(is_equal_approx(float(((main.get("_battlefield") as Battlefield).lanes[0].combat_model.enemies[0]).x), enemy_x), "paused enemies and director do not advance")
	_check(is_equal_approx(float(shooter.get("_shots")[0].position.y), shot_y), "paused projectile does not travel")
	pause.call("_open_controls")
	_check(pause.guide.visible and not pause.menu_panel.visible, "pause CONTROLS reuses illustrated selector")
	pause.guide.select_mode(TouchControlRouter.Mode.SIDE)
	_check(int(main.get("_preferences").mode) == TouchControlRouter.Mode.SIDE and int(main.get("_touch_router").mode) == TouchControlRouter.Mode.SIDE, "paused selector immediately updates shared preferences/router")
	pause.handle_back()
	_check(pause.menu_panel.visible, "Back from controls returns to pause menu")
	main.call("_resume_game")
	_check(not paused and not bool(main.get("_paused")) and not pause.is_open(), "RESUME restores same run")
	_check((main.get("_touch_router") as TouchControlRouter).primary_id == -1 and (main.get("_touch_router") as TouchControlRouter).release(91, Vector2(500, 600)).is_empty(), "resume cannot leak closing touch into a shot")
	main.call("_pause_game")
	pause.call("_show_confirm", &"restart")
	_check(pause.confirm_panel.visible and pause.confirm_label.text.contains("RESTART"), "RESTART requires explicit confirmation")
	pause.call("_cancel_confirm")
	_check(pause.menu_panel.visible and bool(main.get("_paused")), "cancel preserves paused run")
	var progression: MatchProgression = main.get("_progression")
	progression.score = 777
	pause.call("_show_confirm", &"restart")
	pause.call("_confirm")
	_check(not bool(main.get("_paused")) and int(main.get("_progression").score) == 0, "confirmed RESTART resets the run and resumes simulation")
	main.call("_pause_game")
	pause.call("_show_confirm", &"main_menu")
	pause.call("_confirm")
	_check(menu_returns == ["menu"] and not paused, "confirmed MAIN MENU unpauses and requests native menu once")
	var overlay: GameOverOverlay = main.get("_game_over_overlay")
	_check(overlay.z_index > pause.z_index and overlay.z_index == 200, "terminal UI stays above Android pause layer")
	for viewport_size in [Vector2(1280, 720), Vector2(1600, 720)]:
		var safe := Rect2(Vector2(35, 12), viewport_size - Vector2(70, 24))
		main.call("_apply_layout", viewport_size, safe)
		_check(safe.encloses(Rect2(pause.pause_button.position, pause.pause_button.size)), "%s pause button remains in safe area" % viewport_size)
	var narrow_safe := Rect2(Vector2(150, 24), Vector2(980, 672))
	main.call("_apply_layout", Vector2(1280, 720), narrow_safe)
	var guide_panel := pause.guide.get_node("GuidePanel") as PanelContainer
	_check(narrow_safe.encloses(Rect2(guide_panel.position, guide_panel.size)), "control guide remains inside a narrow Android safe area")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(preferences_path)

func _test_reference_and_startup_colors() -> void:
	var image := Image.new()
	var path := ProjectSettings.globalize_path("res://assets/ui/controls_gameplay_reference.png")
	_check(image.load(path) == OK and image.get_size() == Vector2i(1280, 720), "control guide uses committed 1280x720 Godot gameplay capture")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(project.contains("default_clear_color=Color(0.0196, 0.0196, 0.0196, 1)"), "engine startup clear is neutral P036 black")
	_check(presets.contains("background_color=Color(0.0196, 0.0196, 0.0196, 1)"), "Web fallback background is neutral")
	_check(presets.contains("version/code=4") and presets.contains("version/name=\"0.2.0\""), "P039 keeps user-facing Android 0.2.0 while advancing internal code")
	for fixture in PREVIEWS:
		var preview_image := Image.new()
		_check(preview_image.load(ProjectSettings.globalize_path(str(fixture[0]))) == OK and preview_image.get_size() == fixture[1], "%s is required real-renderer P037 evidence" % fixture[0])

func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("P037 Android menu/pause/controls: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P037: " + failure)
	push_error("P037 Android menu/pause/controls: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
