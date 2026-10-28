extends SceneTree

const PreferencesScript := preload("res://scripts/input/control_preferences.gd")

const LAYOUTS := [
	{"viewport": Vector2(1280, 720), "safe": Rect2(Vector2.ZERO, Vector2(1280, 720)), "label": "1280x720"},
	{"viewport": Vector2(1600, 720), "safe": Rect2(Vector2.ZERO, Vector2(1600, 720)), "label": "1600x720"},
	{"viewport": Vector2(2340, 1080), "safe": Rect2(Vector2(36, 24), Vector2(2268, 1032)), "label": "2340x1080"},
	{"viewport": Vector2(1280, 720), "safe": Rect2(Vector2(150, 24), Vector2(980, 672)), "label": "notch safe"},
	{"viewport": Vector2(960, 540), "safe": Rect2(Vector2.ZERO, Vector2(960, 540)), "label": "960x540 compact"},
]

const PREVIEWS := [
	["res://assets/previews/p040_main_classic_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p040_main_side_right_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p040_main_side_left_wide_1600x720.png", Vector2i(1600, 720)],
	["res://assets/previews/p040_main_classic_narrow_safe_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p040_pause_side_right_1280x720.png", Vector2i(1280, 720)],
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
	_test_removed_diagnostic_contract()
	await _test_layout_matrix()
	await _test_persistence_and_back()
	_test_renderer_evidence()
	_finish()

func _test_removed_diagnostic_contract() -> void:
	for path in ["res://scripts/ui/control_guide_view.gd", "res://scripts/ui/pause_menu_view.gd", "res://scripts/boot.gd", "res://scripts/main.gd"]:
		var source := FileAccess.get_file_as_string(path)
		_check(not source.contains("TEST VIBRATION") and not source.contains("test_vibration_requested") and not source.contains("VibrationRequestStatus") and not source.contains("HapticDiagnostic"), "%s has no obsolete vibration diagnostic wiring" % path)
	var haptics := FileAccess.get_file_as_string("res://scripts/android_haptics.gd")
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(haptics.contains("DURATION_MS := 500") and haptics.contains("AMPLITUDE := 1.0") and haptics.contains("Input.vibrate_handheld(DURATION_MS, AMPLITUDE)"), "authentic defender-down haptic remains 500 ms at amplitude 1.0")
	_check(presets.count("permissions/vibrate=true") == 2 and presets.count("version/code=5") == 2 and presets.count("version/name=\"0.2.0\"") == 2, "Android presets retain VIBRATE and name 0.2.0 while advancing to code5")

func _test_layout_matrix() -> void:
	for definition in LAYOUTS:
		for selected_mode in [TouchControlRouter.Mode.CLASSIC, TouchControlRouter.Mode.SIDE]:
			var guide := ControlGuideView.new()
			guide.position = Vector2.ZERO
			guide.size = definition.viewport
			root.add_child(guide)
			guide.configure_safe_rect(definition.safe)
			guide.configure(selected_mode, TouchControlRouter.Handedness.RIGHT)
			await process_frame
			await process_frame
			var label := "%s %s" % [definition.label, "Classic" if selected_mode == TouchControlRouter.Mode.CLASSIC else "Side"]
			var panel := guide.get_node("GuidePanel") as PanelContainer
			var panel_rect := panel.get_global_rect()
			_check(definition.safe.encloses(panel_rect), "%s panel stays inside actual safe rect" % label)
			var preview_rect := guide.preview_frame.get_global_rect()
			var options_rect := guide.options_column.get_global_rect()
			_check(preview_rect.end.x <= options_rect.position.x + 0.5 and not preview_rect.intersects(options_rect), "%s keeps preview left of nonoverlapping options" % label)
			_check(panel_rect.encloses(preview_rect) and panel_rect.encloses(options_rect), "%s keeps both columns inside GuidePanel" % label)
			_check(guide.title_label.visible and guide.title_label.text == "CONTROLS" and panel_rect.encloses(guide.title_label.get_global_rect()), "%s keeps title visible and unobstructed" % label)
			var visible_buttons: Array[Button] = [guide.classic_button, guide.side_button, guide.close_button]
			if selected_mode == TouchControlRouter.Mode.SIDE:
				visible_buttons.append(guide.right_button)
				visible_buttons.append(guide.left_button)
			for button in visible_buttons:
				var rect := button.get_global_rect()
				_check(rect.size.y >= 63.0 and rect.size.x >= 119.0, "%s %s actual target is at least 64x120 (got %.1fx%.1f)" % [label, button.text, rect.size.x, rect.size.y])
				_check(panel_rect.encloses(rect), "%s %s target stays inside panel" % [label, button.text])
			_check(not guide.classic_button.get_global_rect().intersects(guide.side_button.get_global_rect()), "%s scheme hit targets are separate" % label)
			_check(guide.preview.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "%s screenshot preserves aspect ratio" % label)
			var annotation_ratio := guide.annotations.size.x / maxf(guide.annotations.size.y, 1.0)
			_check(absf(annotation_ratio - (16.0 / 9.0)) < 0.02, "%s annotation canvas follows undistorted 16:9 screenshot" % label)
			if selected_mode == TouchControlRouter.Mode.CLASSIC:
				_check(guide.classic_swap_label.visible and guide.classic_shoot_label.visible and guide.classic_swap_label.text == "TAP WITH ANOTHER FINGER TO SWAP" and guide.classic_shoot_label.text == "RELEASE FINGERS TO SHOOT", "%s keeps exact Classic instructions" % label)
			else:
				var right_regions := guide.side_regions()
				guide.select_handedness(TouchControlRouter.Handedness.LEFT)
				var left_regions := guide.side_regions()
				_check(right_regions.swap.position.x < right_regions.slide.position.x and left_regions.slide.position.x < left_regions.swap.position.x, "%s mirrors Side SWAP/SHOOT and SLIDE regions" % label)
			var selected := guide.classic_button if selected_mode == TouchControlRouter.Mode.CLASSIC else guide.side_button
			var unselected := guide.side_button if selected_mode == TouchControlRouter.Mode.CLASSIC else guide.classic_button
			_check(selected.get_theme_stylebox("normal") is StyleBoxFlat and unselected.get_theme_stylebox("normal") is StyleBoxEmpty, "%s keeps raised selected and plain-text unselected scheme" % label)
			guide.queue_free()
			await process_frame

func _test_persistence_and_back() -> void:
	var path := "/tmp/lbs-p040-preferences-%d.cfg" % Time.get_ticks_usec()
	var preferences := PreferencesScript.new(path)
	preferences.mode = TouchControlRouter.Mode.SIDE
	preferences.handedness = TouchControlRouter.Handedness.LEFT
	preferences.save_settings()
	var restored := PreferencesScript.new(path)
	restored.load_settings()
	_check(restored.mode == TouchControlRouter.Mode.SIDE and restored.handedness == TouchControlRouter.Handedness.LEFT, "Side/Left preferences still persist")
	var pause := PauseMenuView.new()
	pause.size = Vector2(1280, 720)
	root.add_child(pause)
	await process_frame
	pause.configure_layout(Rect2(Vector2.ZERO, Vector2(1280, 720)), Vector2(1280, 720))
	pause.show_paused(restored.mode, restored.handedness)
	pause.call("_open_controls")
	_check(pause.guide.visible and pause.handle_back() and pause.menu_panel.visible and not pause.guide.visible, "Android Back closes guide and returns to paused menu")
	pause.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)

func _test_renderer_evidence() -> void:
	for fixture in PREVIEWS:
		var image := Image.new()
		_check(image.load(ProjectSettings.globalize_path(str(fixture[0]))) == OK and image.get_size() == fixture[1], "%s is genuine P040 renderer evidence" % fixture[0])

func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("P040 Android touch Controls layout: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P040: " + failure)
	push_error("P040 Android touch Controls layout: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
