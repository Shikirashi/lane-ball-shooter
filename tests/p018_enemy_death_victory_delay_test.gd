extends SceneTree

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	await _test_single_death_actor_after_logical_freeze()
	await _test_all_neutralization_routes_and_audio()
	await _test_delayed_victory_freeze_restart_and_defeat()
	_test_preserved_balance_and_chain_invariants()
	_finish()

func _first_mesh_alpha(node: Node) -> float:
	var mesh := node as MeshInstance3D
	if mesh == null:
		mesh = node.find_child("*", true, false) as MeshInstance3D
	if mesh == null:
		return -1.0
	var material := mesh.material_override as StandardMaterial3D
	return -1.0 if material == null else material.albedo_color.a

func _test_single_death_actor_after_logical_freeze() -> void:
	var lane := LaneActor.new()
	lane.setup(TeamData.Identity.RED, 0)
	root.add_child(lane)
	await process_frame
	lane.set_process(false)
	var model := lane.combat_model
	model.clear_for_test()
	var uid := model.spawn_enemy(1.75, 2)
	lane.call("_sync_visuals")
	var old_root: Node3D = lane.get("_enemy_visuals")[uid].root
	model.call("_damage_enemy", uid, 2, 1.75)
	_check(model.active_enemy_count() == 0 and model.total_killed == 1, "ordinary projectile kill removes logical enemy immediately")
	_check(not lane.get("_enemy_visuals").has(uid) and lane.get("_death_effects").size() == 1, "ordinary kill transfers the existing live visual into one death actor")
	var death: Dictionary = lane.get("_death_effects")[0]
	_check(death.root == old_root and is_instance_valid(death.burst), "death actor owns the actual enemy body plus explosion")
	_check((death.burst as Node).get_child_count() == 9, "small explosion contains one core and eight lightweight sparks")
	model.set_game_over(true)
	lane.call("_process", 0.7)
	death = lane.get("_death_effects")[0]
	_check(absf(absf((death.root as Node3D).rotation.z) - PI * 0.47) < 0.08, "frozen combat still lets enemy body fall approximately horizontal")
	_check(_first_mesh_alpha(death.root) > 0.0 and _first_mesh_alpha(death.root) < 1.0, "fallen body fades with per-instance transparent materials")
	lane.call("_process", 0.31)
	_check(lane.get("_death_effects").is_empty(), "body, shadow and sparks fully clean within one second")
	lane.queue_free()
	await process_frame

func _test_all_neutralization_routes_and_audio() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set_process(false)
	var battlefield: Battlefield = main.get("_battlefield")
	var sfx: SfxManager = main.get("_sfx")
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
	var events: Array[Dictionary] = []
	battlefield.enemy_death_started.connect(func(identity: int, uid: int, x: float, cause: StringName) -> void:
		events.append({"identity": identity, "uid": uid, "x": x, "cause": cause})
	)

	var red := battlefield.lanes[TeamData.Identity.RED].combat_model
	var projectile_uid := red.spawn_enemy(1.25, 2)
	battlefield.lanes[TeamData.Identity.RED].call("_sync_visuals")
	red.call("_damage_enemy", projectile_uid, 2, 1.25)
	_check(events.size() == 1 and events[0].cause == &"projectile", "normal kill routes one audited projectile death event")
	_check(int(sfx.play_counts.enemy_death) == 1, "normal kill requests and plays one distinct death cue")

	var blue := battlefield.lanes[TeamData.Identity.BLUE].combat_model
	for x in [2.0, 3.0]:
		red.spawn_enemy(x - 0.25, 1)
		blue.spawn_enemy(x, 1)
	var tier3_before := events.size()
	var attack_outcome := battlefield.handle_match({"identity": TeamData.Identity.RED, "tier": 3, "fever": false, "group_size": 3})
	red.update(1.2)
	blue.update(1.2)
	_check(events.size() - tier3_before == 4, "tier-3 wide projectile schedules one death actor/cue for each physically hit 1-HP victim")
	_check(str(attack_outcome.action) == "attack" and attack_outcome.attack.target_lanes == [0, 1], "edge-lane tier-3 uses the real matched-plus-adjacent routing")
	for index in range(tier3_before, events.size()):
		_check(events[index].cause == &"tier3", "tier-3 victim records an unambiguous cause")
	_check(red.total_killed == 3 and blue.total_killed == 2, "tier-3 projectile victims retain killed accounting semantics alongside the earlier projectile kill")

	var green := battlefield.lanes[TeamData.Identity.GREEN].combat_model
	for x in [1.0, 2.0, 3.0]:
		green.spawn_enemy(x, 2)
	var emergency_before := events.size()
	green.call("_discharge_emergency")
	_check(events.size() - emergency_before == 3, "emergency clear schedules one death actor/cue event for every victim")
	for index in range(emergency_before, events.size()):
		_check(events[index].cause == &"emergency", "emergency victim records an unambiguous cause")
	_check(green.total_emergency_cleared == 3 and green.total_killed == 0, "emergency accounting remains distinct from ordinary kills")
	_check(int(sfx.play_counts.enemy_death) == events.size() and int(sfx.request_counts.enemy_death) == events.size(), "all removal paths route exactly one bounded-pool death sound per UID")
	_check(sfx.clip_duration("enemy_death") >= 0.25 and sfx.clip_duration("enemy_death") <= 0.45, "enemy death PCM has the requested short duration")
	_check(sfx.clip_peak("enemy_death") > 0.02 and sfx.clip_peak("enemy_death") <= SfxManager.MAX_PCM_AMPLITUDE + 0.001, "enemy death PCM is audible and peak bounded")
	var plays_before_mute := int(sfx.play_counts.enemy_death)
	sfx.toggle_mute()
	sfx.play_cue("enemy_death")
	_check(int(sfx.request_counts.enemy_death) == events.size() + 1 and int(sfx.play_counts.enemy_death) == plays_before_mute, "mute audits but does not play enemy death cue")
	main.queue_free()
	await process_frame

func _complete_one_per_lane_encounter(main: Node) -> LaneActor:
	var battlefield: Battlefield = main.get("_battlefield")
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(1)
		lane.combat_model.spawn_enemy(2.0 + lane.lane_index * 0.2, 1)
		lane.call("_sync_visuals")
	for index in range(3):
		battlefield.lanes[index].combat_model.clear_enemies_for_tier3()
	var final_lane: LaneActor = battlefield.lanes[3]
	final_lane.combat_model.call("_damage_enemy", int(final_lane.combat_model.enemies[0].uid), 1, float(final_lane.combat_model.enemies[0].x))
	return final_lane

func _test_delayed_victory_freeze_restart_and_defeat() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.set_process(false)
	var battlefield: Battlefield = main.get("_battlefield")
	var chain: ChainModel = main.get("_chain_model")
	var overlay: GameOverOverlay = main.get("_game_over_overlay")
	var shooter: ShooterView = main.get("_shooter_view")
	var sfx: SfxManager = main.get("_sfx")
	var wins := {"count": 0}
	battlefield.encounter_cleared.connect(func() -> void: wins.count += 1)
	var final_lane := _complete_one_per_lane_encounter(main)
	_check(battlefield.victory and int(wins.count) == 1, "final neutralization emits exactly one immediate authoritative victory")
	_check(bool(main.get("_game_over")) and bool(main.get("_victory")) and bool(main.get("_victory_pending")), "Main locks normal gameplay immediately during victory presentation")
	_check(not overlay.visible and shooter.simulation_paused and sfx.gameplay_enabled, "t=0 hides WAVE CLEARED, freezes shots and leaves final death audio alive")
	var frozen_x := float(chain.balls[0].x)
	main.call("_shoot")
	main.call("_swap")
	main.call("_process", 1.0)
	_check(not overlay.visible and absf(float(chain.balls[0].x) - frozen_x) < 0.001, "t=1.0 keeps overlay hidden and chain frozen")
	final_lane.call("_process", 1.01)
	_check(final_lane.get("_death_effects").is_empty(), "terminal combat lock does not freeze final death cleanup")
	main.call("_process", 1.9)
	_check(not overlay.visible and absf(float(main.get("_victory_delay_remaining")) - 0.1) < 0.001, "t=2.9 keeps WAVE CLEARED hidden")
	main.call("_process", 0.1)
	_check(overlay.visible and overlay.victory and not bool(main.get("_victory_pending")), "t=3.0 reveals WAVE CLEARED exactly once")
	_check(overlay.final_score == main.get("_progression").score and not sfx.gameplay_enabled, "delayed overlay preserves final score and safely closes gameplay audio")
	battlefield.call("_evaluate_terminal_state")
	_check(int(wins.count) == 1, "reentrant terminal evaluation cannot duplicate victory")

	main.call("_restart_run")
	_check(not bool(main.get("_game_over")) and not bool(main.get("_victory_pending")) and not overlay.visible, "restart after victory clears overlay and countdown")
	main.call("_on_encounter_cleared")
	main.call("_process", 1.0)
	main.call("_restart_run")
	main.call("_process", 5.0)
	_check(not overlay.visible and not bool(main.get("_victory_pending")), "restart during pending interval cancels stale delayed overlay")

	main.call("_on_game_over_requested", TeamData.Identity.RED)
	_check(overlay.visible and not overlay.victory and not bool(main.get("_victory_pending")), "GAME OVER remains immediate and never starts victory delay")
	main.queue_free()
	await process_frame

func _test_preserved_balance_and_chain_invariants() -> void:
	var chain := ChainModel.new()
	_check(is_equal_approx(chain.speed, 102.0), "P018 preserves 102 px/s conveyor speed")
	_check(is_equal_approx(ShooterView.SHOT_TRAVEL_TIME, 0.2) and is_equal_approx(ChainModel.INSERT_SETTLE_TIME, 0.05), "P018 preserves shot and settling timings")
	var original_uid := int(chain.balls[0].uid)
	chain.advance(20.0)
	_check(chain._ball_index_by_uid(original_uid) >= 0 and chain.cache.is_empty(), "P017 offscreen-left member keeps its UID without right-side recycling")
	_check(chain.invariant_violations == 0, "authoritative segment chain remains at invariant I0")

func _finish() -> void:
	if _failures.is_empty():
		print("P018 enemy death/victory delay: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P018 enemy death/victory delay: " + failure)
	print("P018 enemy death/victory delay: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
