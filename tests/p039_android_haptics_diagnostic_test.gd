extends SceneTree

const BootScript := preload("res://scripts/boot.gd")
const PreferencesScript := preload("res://scripts/input/control_preferences.gd")
const HapticsScript := preload("res://scripts/android_haptics.gd")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _result(identity: int) -> Dictionary:
	return {
		"identity": identity,
		"tier": 1,
		"fever": false,
		"group_size": 3,
		"combo_count": 1,
		"points": 100,
	}

func _run() -> void:
	_test_central_platform_gate()
	await _test_genuine_knockdown_route()
	await _test_diagnostic_ui_removed()
	_test_release_and_logging_contract()
	_test_renderer_evidence()
	_finish()

func _test_central_platform_gate() -> void:
	var pulses: Array[Dictionary] = []
	var requester := func(duration_ms: int, amplitude: float) -> void:
		pulses.append({"duration_ms": duration_ms, "amplitude": amplitude})
	_check(not HapticsScript.request(&"test_blocked", -1, false, requester), "non-Android gate blocks the centralized helper")
	_check(pulses.is_empty(), "desktop/Web gate never invokes the injected haptic requester")
	_check(HapticsScript.request(&"test_injected", -1, true, requester), "Android gate reaches the centralized request boundary")
	_check(pulses.size() == 1 and int(pulses[0].duration_ms) == 500 and is_equal_approx(float(pulses[0].amplitude), 1.0), "central helper requests exactly 500 ms at amplitude 1.0")

func _test_genuine_knockdown_route() -> void:
	var pulses: Array[Dictionary] = []
	var relay_identities: Array[int] = []
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.vibration_requester = func(duration_ms: int, amplitude: float) -> void:
		pulses.append({"duration_ms": duration_ms, "amplitude": amplitude})
	main.set_mobile_platform_override(1)
	root.add_child(main)
	await process_frame
	await process_frame
	var battlefield: Battlefield = main.get("_battlefield")
	battlefield.defender_knocked_down.connect(func(identity: int): relay_identities.append(identity))
	var lane := battlefield.get_lane(TeamData.Identity.RED).combat_model
	lane.clear_for_test()
	var enemy_uid := lane.spawn_enemy(1.0, 3, false)
	lane.call("_damage_enemy", enemy_uid, 1, 1.0)
	_check(pulses.is_empty(), "ordinary enemy damage never requests vibration")
	main.call("_on_enemy_death_started", TeamData.Identity.RED, enemy_uid, 1.0, &"projectile")
	main.call("_on_match_resolved", _result(TeamData.Identity.BLUE))
	_check(pulses.is_empty(), "enemy death and ordinary defender attack never request vibration")

	lane.call("_knock_down")
	_check(lane.defender_state == LaneCombatModel.DefenderState.DOWN, "authentic LaneCombatModel transition enters DOWN")
	_check(relay_identities == [TeamData.Identity.RED], "Battlefield relays the authentic down exactly once with lane identity")
	_check(pulses.size() == 1 and int(pulses[0].duration_ms) == 500 and is_equal_approx(float(pulses[0].amplitude), 1.0), "genuine down reaches the shared 500 ms native boundary once")
	lane.call("_knock_down")
	_check(pulses.size() == 1 and relay_identities.size() == 1, "remaining DOWN cannot repeat the relay or vibration")

	battlefield.handle_match(_result(TeamData.Identity.RED))
	var revival := battlefield.handle_match(_result(TeamData.Identity.RED))
	_check(bool(revival.get("revived", false)) and lane.defender_state == LaneCombatModel.DefenderState.ACTIVE, "two authentic matches revive the defender")
	lane.call("_knock_down")
	_check(relay_identities == [TeamData.Identity.RED, TeamData.Identity.RED] and pulses.size() == 2, "a genuine down after revival requests one new pulse")

	main.call("_pause_game")
	main.call("_resume_game")
	main.call("_restart_run")
	_check(pulses.size() == 2, "pause, resume and restart never add vibration")
	main.queue_free()
	await process_frame

func _test_diagnostic_ui_removed() -> void:
	var pulses: Array[Dictionary] = []
	var boot := BootScript.new()
	var preferences_path := "/tmp/lbs-p039-boot-%d.cfg" % Time.get_ticks_usec()
	boot.set("_preferences", PreferencesScript.new(preferences_path))
	boot.forced_android_mode = 1
	boot.forced_web_mode = 0
	boot.gameplay_starter = func(): pass
	root.add_child(boot)
	await process_frame
	(boot.get("_controls_button") as Button).pressed.emit()
	var guide: ControlGuideView = boot.get("_control_guide")
	_check(guide.visible, "Android MAIN MENU controls remain accessible")
	_check(guide.find_child("TestVibration", true, false) == null and guide.find_child("VibrationRequestStatus", true, false) == null and guide.find_child("HapticDiagnostic", true, false) == null, "main-menu guide has no obsolete haptic diagnostic UI")
	guide.select_mode(TouchControlRouter.Mode.SIDE)
	guide.select_handedness(TouchControlRouter.Handedness.LEFT)
	guide.close_button.pressed.emit()
	_check(pulses.is_empty(), "main-menu Controls choices and BACK never vibrate")
	boot.queue_free()
	await process_frame
	DirAccess.remove_absolute(preferences_path)

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	var main_preferences_path := "/tmp/lbs-p039-main-%d.cfg" % Time.get_ticks_usec()
	main.set("_preferences", PreferencesScript.new(main_preferences_path))
	main.vibration_requester = func(duration_ms: int, amplitude: float) -> void:
		pulses.append({"duration_ms": duration_ms, "amplitude": amplitude})
	main.set_mobile_platform_override(1)
	root.add_child(main)
	await process_frame
	await process_frame
	var pause: PauseMenuView = main.get("_pause_view")
	main.call("_pause_game")
	pause.call("_open_controls")
	_check(paused and pause.guide.visible, "PAUSE controls remain accessible while simulation is frozen")
	_check(pause.guide.find_child("TestVibration", true, false) == null and pause.guide.find_child("VibrationRequestStatus", true, false) == null and pause.guide.find_child("HapticDiagnostic", true, false) == null, "pause guide has no obsolete haptic diagnostic UI")
	pause.guide.select_mode(TouchControlRouter.Mode.SIDE)
	pause.guide.close_button.pressed.emit()
	_check(pulses.is_empty(), "pause Controls choices and BACK never vibrate")
	main.call("_resume_game")
	main.queue_free()
	await process_frame
	paused = false
	DirAccess.remove_absolute(main_preferences_path)

func _test_release_and_logging_contract() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(presets.count("version/code=5") == 2, "both Android presets use internal version code 5")
	_check(presets.count("version/name=\"0.2.0\"") == 2, "both Android presets retain displayed version 0.2.0")
	_check(presets.count("permissions/vibrate=true") == 2, "both Android presets retain VIBRATE permission")
	var haptics_source := FileAccess.get_file_as_string("res://scripts/android_haptics.gd")
	_check(haptics_source.contains("Input.vibrate_handheld(DURATION_MS, AMPLITUDE)"), "one central helper owns the real Godot native vibration call")
	_check(haptics_source.contains("duration_ms=%d") and haptics_source.contains("android_gate=%s") and haptics_source.contains("route=%s"), "native request emits concise diagnostic route logging")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_source.contains("defender_down lane=%d") and main_source.contains("_battlefield.defender_knocked_down.connect(_on_defender_knocked_down)"), "genuine down logs lane identity at the authoritative Battlefield relay")
	var boot_source := FileAccess.get_file_as_string("res://scripts/boot.gd")
	var pause_source := FileAccess.get_file_as_string("res://scripts/ui/pause_menu_view.gd")
	var guide_source := FileAccess.get_file_as_string("res://scripts/ui/control_guide_view.gd")
	_check(not boot_source.contains("controls_test") and not main_source.contains("controls_test") and not pause_source.contains("test_vibration") and not guide_source.contains("TEST VIBRATION"), "obsolete diagnostic wiring is removed while defender-down logging remains")

func _test_renderer_evidence() -> void:
	for fixture in [
		["res://assets/previews/p039_main_controls_1280x720.png", Vector2i(1280, 720)],
		["res://assets/previews/p039_pause_controls_1600x720.png", Vector2i(1600, 720)],
		["res://assets/previews/p039_controls_narrow_safe_1280x720.png", Vector2i(1280, 720)],
	]:
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(str(fixture[0])))
		_check(error == OK and image.get_size() == fixture[1], "%s is committed genuine-renderer P039 evidence" % fixture[0])

func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("P039 Android haptics diagnostic: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P039: " + failure)
	push_error("P039 Android haptics diagnostic: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
