extends SceneTree

const EnemyTypesScript = preload("res://scripts/world/enemy_types.gd")

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	await _test_live_scene_and_responsive_framing()
	await _test_baked_roster_motion_and_effects()
	_test_committed_renderer_captures()
	_finish()


func _test_live_scene_and_responsive_framing() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check(main.find_children("*", "Node3D", true, false).is_empty(), "live gameplay instantiates no Node3D content")
	_check(main.find_children("*", "Camera3D", true, false).is_empty(), "live gameplay instantiates no Camera3D")
	_check(main.find_children("*", "SubViewport", true, false).is_empty(), "live gameplay instantiates no hidden 3D viewport")
	var battlefield: Battlefield = main.get("_battlefield")
	_check(battlefield != null and battlefield.lanes.size() == TeamData.COUNT, "live battlefield owns four 2D lane controls")
	for viewport_size in [Vector2(960.0, 540.0), Vector2(1280.0, 720.0), Vector2(1600.0, 720.0), Vector2(2400.0, 1080.0)]:
		main.call("_apply_layout", viewport_size, Rect2(Vector2.ZERO, viewport_size))
		var layout: Dictionary = ResponsiveLayout.calculate(viewport_size)
		_check(battlefield.position.is_equal_approx(layout.battlefield_rect.position) and battlefield.size.is_equal_approx(layout.battlefield_rect.size), "%s applies the battlefield rectangle without raster scaling" % viewport_size)
		var expected_height := battlefield.size.y / 4.0
		for lane_index in range(battlefield.lanes.size()):
			var lane: LaneActor = battlefield.lanes[lane_index]
			_check(absf(lane.position.y - expected_height * lane_index) < 0.01 and absf(lane.size.y - expected_height) < 0.01, "%s lane %d fills one responsive row" % [viewport_size, lane_index])
			var left := lane.world_x_to_local(LaneCombatModel.LEFT_BOUNDARY)
			var right := lane.world_x_to_local(LaneCombatModel.PROJECTILE_RIGHT_BOUNDARY)
			_check(absf(left / lane.size.x - 0.055) < 0.001 and absf(right / lane.size.x - 0.945) < 0.001, "%s lane %d keeps 5.5%% side margins" % [viewport_size, lane_index])
			_check(lane.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s lane %d cannot intercept established firing controls" % [viewport_size, lane_index])
			var defender: Sprite2D = lane.get("_defender_sprite")
			var defender_name := TeamData.display_name(lane_index).to_lower()
			_check(defender.texture == load("res://assets/sprites/baked/defender_%s.png" % defender_name), "%s lane %d uses its P034A defender sprite" % [viewport_size, lane_index])
	_check(battlefield.position.y <= (main.get("_chain_view") as BallChainView).position.y + (main.get("_chain_view") as BallChainView).size.y + 2.01, "top lane reaches the conveyor")
	var final_layout: Dictionary = ResponsiveLayout.calculate(Vector2(2400.0, 1080.0))
	_check(battlefield.position.y + battlefield.size.y <= float(final_layout.shooter_y) - 53.0, "bottom lane remains above the shooter controls")
	var cutout_safe := Rect2(96.0, 24.0, 2208.0, 1032.0)
	main.call("_apply_layout", Vector2(2400.0, 1080.0), cutout_safe)
	_check(cutout_safe.encloses(Rect2(battlefield.position, battlefield.size)), "cutout-safe layout contains the complete 2D battlefield")
	_check(battlefield.position.y >= (main.get("_chain_view") as BallChainView).position.y + (main.get("_chain_view") as BallChainView).size.y, "cutout-safe conveyor and top lane do not overlap")
	main.queue_free()
	await process_frame


func _test_baked_roster_motion_and_effects() -> void:
	var lane := LaneActor.new()
	lane.setup(TeamData.Identity.YELLOW, 2)
	root.add_child(lane)
	await process_frame
	lane.set_process(false)
	lane.configure_layout(Vector2(1280.0, 120.0))
	lane.combat_model.clear_for_test()
	lane.combat_model.max_enemies = 8
	var names := ["enemy_hopper", "enemy_heavy", "enemy_sickle_snake", "enemy_healyzard"]
	var uids: Array[int] = []
	for enemy_type in range(names.size()):
		uids.append(lane.combat_model.spawn_enemy(1.0 + enemy_type, -1, false, enemy_type, 3400 + enemy_type))
	lane.call("_sync_visuals")
	for enemy_type in range(names.size()):
		var visual: Dictionary = lane.get("_enemy_visuals")[uids[enemy_type]]
		var sprite: Sprite2D = visual.sprite
		_check(sprite.texture == load("res://assets/sprites/baked/%s.png" % names[enemy_type]), "%s live actor uses its P034A transparent sprite" % names[enemy_type])
		_check(sprite.texture.get_image().get_pixel(0, 0).a == 0.0, "%s live sprite preserves transparent corners" % names[enemy_type])
	var hopper_before := (lane.get("_enemy_visuals")[uids[0]].root as Node2D).position
	lane.combat_model.enemies[0].hop_airborne = true
	lane.combat_model.enemies[0].hop_progress = 0.5
	lane.call("_sync_visuals")
	var hopper_after := (lane.get("_enemy_visuals")[uids[0]].root as Node2D).position
	_check(hopper_after.y < hopper_before.y, "Hopper's authoritative hop phase drives vertical 2D motion")
	var healer_visual: Dictionary = lane.get("_enemy_visuals")[uids[3]]
	lane.call("_on_healer_pulsed", {"healer_uid": uids[3]})
	_check((healer_visual.aura as Sprite2D).visible, "Healyzard healing pulse displays its 2D radial aura")

	var projectile := {"uid": 9001, "wide": true, "piercing": true, "adjacent_lane": 3, "x": -3.0, "launch_delay": 0.0}
	lane.combat_model.projectiles.append(projectile)
	lane.call("_sync_visuals")
	var projectile_visual: Dictionary = lane.get("_projectile_visuals")[9001]
	var polygon: PackedVector2Array = (projectile_visual.shape as Polygon2D).polygon
	_check(polygon.size() == 4 and absf(polygon[2].y - polygon[1].y) > lane.size.y, "tier-3 wide projectile visibly spans its selected adjacent lane")

	var death_uid := uids[1]
	lane.combat_model.call("_damage_enemy", death_uid, 12, 2.0)
	_check(lane.get("_death_effects").size() == 1, "enemy kill transfers the actual 2D actor into death animation")
	lane.call("_update_death_effects", 0.7)
	var death: Dictionary = lane.get("_death_effects")[0]
	_check(absf((death.root as Node2D).rotation) > 1.2 and (death.sprite as Sprite2D).modulate.a < 1.0, "2D enemy falls sideways and fades after combat removal")
	_check(lane.find_children("*", "Node3D", true, false).is_empty(), "effects and projectiles remain entirely 2D")
	lane.queue_free()
	await process_frame


func _test_committed_renderer_captures() -> void:
	for fixture in [{"path": "res://assets/previews/p034b_gameplay_1280x720.png", "size": Vector2i(1280, 720)}, {"path": "res://assets/previews/p034b_gameplay_1600x720.png", "size": Vector2i(1600, 720)}]:
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(fixture.path))
		_check(error == OK and image.get_size() == fixture.size, "%s is a real renderer capture at its required resolution" % fixture.path)
		if error == OK:
			var sample_colors := {}
			for y in range(0, image.get_height(), 24):
				for x in range(0, image.get_width(), 24):
					sample_colors[image.get_pixel(x, y).to_html()] = true
			_check(sample_colors.size() > 80, "%s contains nontrivial rendered gameplay rather than a blank frame" % fixture.path)


func _finish() -> void:
	if _failures.is_empty():
		print("P034B live 2D battlefield: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P034B live 2D battlefield: " + failure)
	print("P034B live 2D battlefield: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
