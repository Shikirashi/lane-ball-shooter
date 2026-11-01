extends SceneTree

const EnemyTypesScript := preload("res://scripts/world/enemy_types.gd")
const TrailScript := preload("res://tools/lbs_photo_projectile_trail.gd")

const CAPTURE_SIZE := Vector2i(1600, 900)
const OUTPUT_DIR := "res://docs/portfolio/review/lbs_photo_001"
const ORIGINAL_CANDIDATES := [
	{
		"name": "ball_battalion_photo_001_a.png",
		"shot_identity": TeamData.Identity.RED,
		"next_identity": TeamData.Identity.BLUE,
		"shooter_ratio": 0.46,
		"flight_ratio": 0.50,
		"enemy_shift": 0.0,
		"score": 7350,
	},
	{
		"name": "ball_battalion_photo_001_b.png",
		"shot_identity": TeamData.Identity.BLUE,
		"next_identity": TeamData.Identity.YELLOW,
		"shooter_ratio": 0.58,
		"flight_ratio": 0.56,
		"enemy_shift": 0.42,
		"score": 8620,
	},
	{
		"name": "ball_battalion_photo_001_c.png",
		"shot_identity": TeamData.Identity.GREEN,
		"next_identity": TeamData.Identity.RED,
		"shooter_ratio": 0.39,
		"flight_ratio": 0.44,
		"enemy_shift": -0.36,
		"score": 9140,
	},
]
const SECOND_PASS_CANDIDATES := [
	{
		"name": "ball_battalion_photo_001_c_large_clean_01.png",
		"shot_identity": TeamData.Identity.GREEN,
		"next_identity": TeamData.Identity.RED,
		"shooter_ratio": 0.39,
		"flight_ratio": 0.44,
		"enemy_shift": -0.36,
		"score": 9140,
		"photo_projectile_radius": 24.0,
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_DIR)
	if DirAccess.make_dir_recursive_absolute(absolute_output) != OK:
		push_error("LBS-PHOTO-001 could not create %s" % absolute_output)
		quit(1)
		return
	var candidates := ORIGINAL_CANDIDATES if OS.get_cmdline_user_args().has("--originals") else SECOND_PASS_CANDIDATES
	for candidate in candidates:
		if not await _capture_candidate(candidate):
			quit(1)
			return
	print("LBS-PHOTO-001 capture: wrote %d deterministic real-renderer screenshots at %s" % [candidates.size(), CAPTURE_SIZE])
	quit(0)


func _capture_candidate(candidate: Dictionary) -> bool:
	var viewport := SubViewport.new()
	viewport.name = "LbsPhoto001Capture"
	viewport.size = CAPTURE_SIZE
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	viewport.add_child(main)
	await process_frame
	await process_frame
	main.call("_apply_layout", Vector2(CAPTURE_SIZE), Rect2(Vector2.ZERO, Vector2(CAPTURE_SIZE)))
	_stage_frozen_game(main, candidate)
	main.process_mode = Node.PROCESS_MODE_DISABLED

	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var output_path := "%s/%s" % [OUTPUT_DIR, str(candidate.name)]
	if image == null or image.is_empty() or image.get_size() != CAPTURE_SIZE:
		push_error("LBS-PHOTO-001 returned an invalid image for %s" % output_path)
		viewport.queue_free()
		await process_frame
		return false
	image.convert(Image.FORMAT_RGBA8)
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	viewport.queue_free()
	await process_frame
	if error != OK:
		push_error("LBS-PHOTO-001 could not save %s (error %d)" % [output_path, error])
		return false
	return true


func _stage_frozen_game(main: Node, candidate: Dictionary) -> void:
	(main.get("_sfx") as SfxManager).muted = true

	var chain_model: ChainModel = main.get("_chain_model")
	chain_model.set_test_state(_conveyor_fixture(), 72.0)
	var chain_view: BallChainView = main.get("_chain_view")
	chain_view.set_process(false)
	chain_view.queue_redraw()

	var battlefield: Battlefield = main.get("_battlefield")
	battlefield.set_process(false)
	battlefield.set_attack_rng_seed(1001)
	battlefield.set_spawn_rng_seed(1002)
	battlefield.call("_reset_spawn_director", false)
	var enemy_shift := float(candidate.enemy_shift)
	var fixtures := [
		[[EnemyTypesScript.Type.HOPPER, 1.0 + enemy_shift], [EnemyTypesScript.Type.HEAVY, 5.4]],
		[[EnemyTypesScript.Type.SICKLE_SNAKE, 2.5 - enemy_shift], [EnemyTypesScript.Type.HOPPER, 6.2]],
		[[EnemyTypesScript.Type.HEAVY, 1.8 + enemy_shift], [EnemyTypesScript.Type.HEALYZARD, 7.0]],
		[[EnemyTypesScript.Type.HOPPER, 2.9 - enemy_shift], [EnemyTypesScript.Type.HEALYZARD, 6.5]],
	]
	for lane_index in range(TeamData.COUNT):
		var lane: LaneActor = battlefield.lanes[lane_index]
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
		lane.set("_visual_time", 0.58 + lane_index * 0.17)
		for fixture in fixtures[lane_index]:
			battlefield.spawn_directed_enemy(lane_index, int(fixture[0]), float(fixture[1]), -1, true)
		for enemy_index in range(lane.combat_model.enemies.size()):
			var enemy: Dictionary = lane.combat_model.enemies[enemy_index]
			if int(enemy.type) == EnemyTypesScript.Type.HOPPER:
				enemy.hop_airborne = true
				enemy.hop_progress = 0.32 + lane_index * 0.09
			lane.combat_model.enemies[enemy_index] = enemy
		lane.call("_sync_visuals")
		lane.set("_last_status_key", "")
		lane.call("_update_status_visual")

	var safe_rect: Rect2 = main.get("_safe_rect")
	var shooter: ShooterView = main.get("_shooter_view")
	var shooter_x := lerpf(safe_rect.position.x + 100.0, safe_rect.end.x - 100.0, float(candidate.shooter_ratio))
	var shot_identity := int(candidate.shot_identity)
	shooter.move_to(shooter_x)
	shooter.set_ammunition(shot_identity, int(candidate.next_identity))
	var start := Vector2(shooter.shooter_x, shooter.shooter_y - 42.0)
	var flight_ratio := float(candidate.flight_ratio)
	var projectile_position := Vector2(start.x, lerpf(start.y, shooter.shot_ceiling, flight_ratio))
	shooter.set("_shots", [{
		"position": projectile_position,
		"start": start,
		"target_y": shooter.shot_ceiling,
		"elapsed": ShooterView.SHOT_TRAVEL_TIME * flight_ratio,
		"identity": shot_identity,
	}])
	shooter.set_simulation_paused(true)
	shooter.set_process(false)
	shooter.queue_redraw()

	var trail: LbsPhotoProjectileTrail = TrailScript.new()
	trail.name = "CaptureOnlyStaticProjectileTrail"
	trail.size = Vector2(CAPTURE_SIZE)
	main.add_child(trail)
	var photo_radius := float(candidate.get("photo_projectile_radius", 0.0))
	main.move_child(trail, shooter.get_index() + (1 if photo_radius > 0.0 else 0))
	trail.configure(shot_identity, projectile_position, 64.0, photo_radius)

	(main.get("_hud_view") as HudView).set_progress(int(candidate.score), 3, 3, false, 0.72)
	main.call("_on_encounter_progress_changed", 12, 32, 20)


func _conveyor_fixture() -> Array[int]:
	return [
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.BLUE,
		TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
		TeamData.Identity.GREEN, TeamData.Identity.GREEN, TeamData.Identity.GREEN,
		TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.BLUE, TeamData.Identity.BLUE,
		TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW,
		TeamData.Identity.GREEN, TeamData.Identity.GREEN,
		TeamData.Identity.RED, TeamData.Identity.RED,
		TeamData.Identity.BLUE, TeamData.Identity.BLUE,
		TeamData.Identity.YELLOW,
	]
