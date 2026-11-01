extends SceneTree

const TrailScript := preload("res://tools/lbs_photo_projectile_trail.gd")

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	var capture_source := FileAccess.get_file_as_string("res://tools/capture_lbs_photo_001.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_check(not main_source.contains("LbsPhotoProjectileTrail") and not main_source.contains("PHOTO-001"), "production Main has no photo-fixture dependency")
	_check(not project_source.contains("capture_lbs_photo_001"), "project defaults do not enable capture mode")
	_check(capture_source.contains("main.process_mode = Node.PROCESS_MODE_DISABLED"), "capture disables the complete game tree")
	_check(capture_source.contains("battlefield.set_process(false)"), "capture disables battlefield progression")
	_check(capture_source.contains("chain_model.set_test_state"), "capture uses a deterministic static conveyor")
	_check(capture_source.contains("shooter.set_simulation_paused(true)"), "capture freezes the authentic ShooterView projectile")
	_check(capture_source.contains("ShooterView.SHOT_TRAVEL_TIME * flight_ratio"), "capture stages a real fixed point on the production flight path")
	_check(capture_source.contains("Vector2i(1600, 900)"), "capture uses native 16:9 1600x900 output")
	_check(capture_source.count("ball_battalion_photo_001_") == 3, "capture declares exactly three bounded candidates")

	var trail: LbsPhotoProjectileTrail = TrailScript.new()
	root.add_child(trail)
	trail.configure(TeamData.Identity.GREEN, Vector2(400.0, 300.0), 64.0)
	_check(trail.identity == TeamData.Identity.GREEN and trail.projectile_position == Vector2(400.0, 300.0), "capture-only trail retains staged identity and position")
	_check(is_equal_approx(trail.trail_length, 64.0) and not trail.is_processing(), "capture-only trail is static and locally bounded")
	trail.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("LBS-PHOTO-001 capture isolation: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("LBS-PHOTO-001: " + failure)
	push_error("LBS-PHOTO-001 capture isolation: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
