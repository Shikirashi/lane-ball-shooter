extends SceneTree

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
	await _test_authoritative_knockdown_haptic()
	_test_release_contract()
	_finish()

func _test_authoritative_knockdown_haptic() -> void:
	var pulses: Array[Dictionary] = []
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.vibration_requester = func(duration_ms: int, amplitude: float) -> void:
		pulses.append({"duration_ms": duration_ms, "amplitude": amplitude})
	main.set_mobile_platform_override(1)
	root.add_child(main)
	await process_frame
	await process_frame
	_check(pulses.is_empty(), "starting an Android run never vibrates")

	var battlefield: Battlefield = main.get("_battlefield")
	var lane := battlefield.get_lane(TeamData.Identity.RED).combat_model
	lane.clear_for_test()
	var enemy_uid := lane.spawn_enemy(0.0, 3, false)
	lane.call("_damage_enemy", enemy_uid, 1, 0.0)
	_check(int(lane.enemies[0].hp) == 2, "ordinary enemy damage fixture applies authoritative damage")
	main.call("_on_match_resolved", _result(TeamData.Identity.BLUE))
	main.call("_on_enemy_death_started", TeamData.Identity.RED, 99, 0.0, &"projectile")
	_check(pulses.is_empty(), "ordinary attack and enemy death events never vibrate")

	var emergency_before := lane.emergency_available
	lane.call("_knock_down")
	_check(lane.defender_state == LaneCombatModel.DefenderState.DOWN, "authoritative lane transition still downs the defender")
	_check(lane.revival_progress == 0 and lane.emergency_available == emergency_before, "haptic observer does not mutate defender gameplay state")
	_check(pulses.size() == 1, "one authoritative defender-down transition requests one pulse")
	_check(int(pulses[0].duration_ms) == 160 and is_equal_approx(float(pulses[0].amplitude), 0.7), "knockdown pulse uses the approved 160 ms and 0.7 amplitude")
	lane.call("_knock_down")
	_check(pulses.size() == 1, "duplicate down-state requests emit no second haptic")

	main.call("_pause_game")
	main.call("_resume_game")
	main.call("_restart_run")
	_check(pulses.size() == 1, "pause, resume and restart add no haptic pulse")

	main.set_mobile_platform_override(0)
	_check(not bool(main.call("_request_defender_knockdown_vibration")) and pulses.size() == 1, "desktop/Web gating suppresses vibration intent")
	main.set_mobile_platform_override(1)
	var restarted_lane := battlefield.get_lane(TeamData.Identity.BLUE).combat_model
	restarted_lane.call("_knock_down")
	_check(pulses.size() == 2, "a fresh defender-down transition after restart may vibrate again")
	main.queue_free()
	await process_frame

func _test_release_contract() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(presets.count("version/code=3") == 2, "both Android presets use internal version code 3")
	_check(presets.count("version/name=\"0.2.0\"") == 2, "both Android presets retain user-facing version 0.2.0")
	_check(presets.count("permissions/vibrate=true") == 2, "both Android presets request the VIBRATE normal permission")
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(source.contains("Input.vibrate_handheld(DEFENDER_KNOCKDOWN_VIBRATION_MS"), "Android runtime uses Godot handheld vibration API")
	_check(source.contains("_battlefield.defender_knocked_down.connect(_on_defender_knocked_down)"), "haptic remains wired to the authoritative Battlefield down signal")

func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("P038 defender knockdown haptics: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P038: " + failure)
	push_error("P038 defender knockdown haptics: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
