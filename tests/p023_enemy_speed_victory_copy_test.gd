extends SceneTree

const EnemyTypesScript := preload("res://scripts/world/enemy_types.gd")
const MainScript := preload("res://scripts/main.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	_test_canonical_speeds_and_displacement()
	_test_hop_timing_and_stationary_healer()
	await _test_snake_stun_transfer_timing()
	_test_faster_swept_collisions_and_terminals()
	await _test_victory_and_defeat_copy()
	_finish()

func _enemy(model: LaneCombatModel, uid: int) -> Dictionary:
	for candidate in model.enemies:
		if int(candidate.uid) == uid:
			return candidate
	return {}

func _test_canonical_speeds_and_displacement() -> void:
	_check(is_equal_approx(LaneCombatModel.DEFAULT_ENEMY_SPEED, 0.312), "single authoritative base speed is exactly 0.312")
	var expected := [0.312, 0.2184, 0.624, 0.0]
	var old := [0.24, 0.168, 0.48, 0.0]
	var model := LaneCombatModel.new(TeamData.Identity.RED)
	model.clear_for_test()
	model.max_enemies = 8
	var starts := {}
	for enemy_type in range(4):
		var uid := model.spawn_enemy(5.0 + enemy_type, -1, false, enemy_type, 2300 + enemy_type)
		var spawned := _enemy(model, uid)
		starts[enemy_type] = float(spawned.x)
		_check(is_equal_approx(float(spawned.speed), expected[enemy_type]), "%s speed is exact" % EnemyTypesScript.display_name(enemy_type))
		_check(is_equal_approx(float(spawned.speed), LaneCombatModel.DEFAULT_ENEMY_SPEED * float(EnemyTypesScript.SPEED_MULTIPLIERS[enemy_type])), "%s still derives from the canonical multiplier" % EnemyTypesScript.display_name(enemy_type))
		if enemy_type < EnemyTypesScript.Type.HEALYZARD:
			_check(is_equal_approx(float(spawned.speed), old[enemy_type] * 1.30), "%s speed is current baseline multiplied by 1.30" % EnemyTypesScript.display_name(enemy_type))
	# Put Hopper at the beginning of a whole hop cycle; slide types use one second.
	var hopper_uid := int(model.enemies[0].uid)
	var hopper := _enemy(model, hopper_uid)
	hopper.hop_clock = 0.0
	model.enemies[0] = hopper
	model.update(LaneCombatModel.HOP_CYCLE_DURATION)
	var hopper_distance := float(starts[EnemyTypesScript.Type.HOPPER]) - float(_enemy(model, hopper_uid).x)
	_check(is_equal_approx(hopper_distance, 0.24 * LaneCombatModel.HOP_CYCLE_DURATION * 1.30), "whole Hopper cycle displacement is exactly 1.30x its former value")
	for enemy_type in [EnemyTypesScript.Type.HEAVY, EnemyTypesScript.Type.SICKLE_SNAKE]:
		var moved := float(starts[enemy_type]) - float(model.enemies[enemy_type].x)
		_check(is_equal_approx(moved, expected[enemy_type] * LaneCombatModel.HOP_CYCLE_DURATION), "%s fixed-dt displacement follows its new speed" % EnemyTypesScript.display_name(enemy_type))

func _test_hop_timing_and_stationary_healer() -> void:
	_check(is_equal_approx(LaneCombatModel.HOP_GROUND_DURATION, 0.55) and is_equal_approx(LaneCombatModel.HOP_AIR_DURATION, 0.75) and is_equal_approx(LaneCombatModel.HOP_CYCLE_DURATION, 1.30), "0.55s ground and 0.75s air timing is unchanged")
	var hopper := LaneCombatModel.new(TeamData.Identity.BLUE)
	hopper.clear_for_test()
	var hopper_uid := hopper.spawn_enemy(5.0, -1, false, EnemyTypesScript.Type.HOPPER)
	var record := _enemy(hopper, hopper_uid)
	record.hop_clock = 0.0
	hopper.enemies[0] = record
	hopper.update(0.549)
	_check(is_equal_approx(float(hopper.enemies[0].x), 5.0) and not bool(hopper.enemies[0].hop_airborne), "Hopper remains stationary through grounded interval")
	hopper.update(0.001)
	_check(bool(hopper.enemies[0].hop_airborne) and is_equal_approx(float(hopper.enemies[0].x), 5.0), "Hopper enters air at 0.55s without shortening its animation")
	hopper.update(0.75)
	_check(not bool(hopper.enemies[0].hop_airborne) and is_equal_approx(float(hopper.enemies[0].hop_clock), 0.0), "Hopper completes the unchanged 1.30s cycle")

	var healer := LaneCombatModel.new(TeamData.Identity.GREEN)
	healer.clear_for_test()
	healer.spawn_enemy(6.7, -1, false, EnemyTypesScript.Type.HEALYZARD)
	healer.update(45.0)
	_check(is_equal_approx(float(healer.enemies[0].x), 6.7) and is_equal_approx(float(healer.enemies[0].speed), 0.0), "Healyzard remains stationary across several heal intervals")

func _step_battlefield(battlefield: Battlefield, delta: float) -> void:
	battlefield.call("_process", delta)
	for lane in battlefield.lanes:
		lane.call("_process", delta)

func _test_snake_stun_transfer_timing() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
	battlefield.call("_reset_spawn_director", false)
	for lane_index in range(4):
		battlefield.get("_spawn_timers")[lane_index] = 999.0
	var uid := battlefield.spawn_directed_enemy(0, EnemyTypesScript.Type.SICKLE_SNAKE, 3.0)
	var spawn_id := int(battlefield.lanes[0].combat_model.enemies[0].spawn_id)
	battlefield.lanes[0].combat_model.call("_damage_enemy", uid, 1, 3.0)
	_step_battlefield(battlefield, 0.499)
	var location: Dictionary = battlefield.call("_find_enemy_by_spawn_id", spawn_id)
	_check(int(location.lane_index) == 0 and is_equal_approx(float(location.enemy.x), 3.0), "faster Snake still remains stopped through 0.499s")
	_step_battlefield(battlefield, 0.001)
	location = battlefield.call("_find_enemy_by_spawn_id", spawn_id)
	_check(int(location.lane_index) == 1 and StringName(location.enemy.special_state) == &"transferring", "Snake still starts adjacent transfer at exactly 0.5s")
	_step_battlefield(battlefield, Battlefield.SNAKE_TRANSFER_DURATION)
	location = battlefield.call("_find_enemy_by_spawn_id", spawn_id)
	_check(StringName(location.enemy.special_state) == &"moving" and is_equal_approx(float(location.enemy.x), 3.0), "0.3s transfer duration remains movement-free")
	_step_battlefield(battlefield, 0.25)
	location = battlefield.call("_find_enemy_by_spawn_id", spawn_id)
	_check(absf(float(location.enemy.x) - 2.844) < 0.001, "Snake resumes at new 0.624-unit/s speed after transfer")
	battlefield.queue_free()
	await process_frame

func _test_faster_swept_collisions_and_terminals() -> void:
	for step in [1.0 / 30.0, 0.08]:
		for enemy_type in [EnemyTypesScript.Type.HOPPER, EnemyTypesScript.Type.HEAVY, EnemyTypesScript.Type.SICKLE_SNAKE]:
			var model := LaneCombatModel.new(TeamData.Identity.YELLOW)
			model.clear_for_test()
			model.spawn_enemy(-2.0, 1, false, enemy_type)
			model.fire_attack({"identity": TeamData.Identity.YELLOW, "tier": 1, "fever": false, "group_size": 3})
			var elapsed := 0.0
			while elapsed < 1.0 and model.active_enemy_count() > 0:
				model.update(step)
				elapsed += step
			_check(model.total_killed == 1 and model.hit_history.size() == 1, "%s swept collision does not tunnel at dt %.4f" % [EnemyTypesScript.display_name(enemy_type), step])

	var contact := LaneCombatModel.new(TeamData.Identity.RED)
	contact.clear_for_test()
	contact.spawn_enemy(LaneCombatModel.DEFENDER_X + 0.02, -1, false, EnemyTypesScript.Type.HEAVY)
	contact.update(0.2)
	_check(contact.defender_state == LaneCombatModel.DefenderState.DOWN and contact.total_emergency_cleared == 1, "faster sliding contact still knocks down defender and triggers emergency")
	var breach := LaneCombatModel.new(TeamData.Identity.BLUE)
	breach.clear_for_test()
	breach.emergency_available = false
	breach.spawn_enemy(LaneCombatModel.LEFT_BOUNDARY - 0.01, -1, false, EnemyTypesScript.Type.SICKLE_SNAKE)
	breach.update(0.0)
	_check(breach.game_over and breach.total_breaches == 1, "faster moving enemy still triggers immediate boundary breach")

func _test_victory_and_defeat_copy() -> void:
	var overlay := GameOverOverlay.new()
	root.add_child(overlay)
	await process_frame
	overlay.show_wave_cleared(1234)
	_check(overlay.visible and overlay.victory and overlay.title_text() == "WAVE CLEARED", "victory overlay keeps exact title")
	_check(overlay.subtitle_text() == "All enemies neutralized", "victory overlay uses exact simplified subtitle")
	_check(overlay.final_score == 1234 and (overlay.get("_restart_button") as Button).text == "RESTART  [R]", "victory keeps score and restart copy")
	overlay.show_game_over(4321)
	_check(not overlay.victory and overlay.title_text() == "GAME OVER" and overlay.subtitle_text() == "The lane was breached", "defeat title and breach subtitle remain unchanged")
	overlay.queue_free()
	await process_frame

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set_process(false)
	var live_overlay: GameOverOverlay = main.get("_game_over_overlay")
	main.call("_on_encounter_cleared")
	main.call("_process", MainScript.VICTORY_PRESENTATION_DELAY - 0.001)
	_check(not live_overlay.visible and bool(main.get("_victory_pending")), "simplified subtitle remains hidden throughout first 2.999s")
	main.call("_process", 0.001)
	_check(live_overlay.visible and live_overlay.subtitle_text() == "All enemies neutralized", "exact subtitle appears at unchanged 3.0s victory boundary")
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P023 enemy speed/victory copy: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P023: " + failure)
	push_error("P023 enemy speed/victory copy: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
