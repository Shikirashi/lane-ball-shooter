extends SceneTree

const EnemyTypesScript = preload("res://scripts/world/enemy_types.gd")
const RouterScript = preload("res://scripts/input/touch_control_router.gd")
const PreferencesScript = preload("res://scripts/input/control_preferences.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)

func _run() -> void:
	_test_hp_and_healing()
	_test_touch_router()
	_test_preferences()
	await _test_live_layout_input_ui_and_flash()
	_test_renderer_evidence()
	_finish()

func _test_hp_and_healing() -> void:
	var expected := [3, 6, 3, 3]
	_check(LaneCombatModel.DEFAULT_ENEMY_HP == 3, "fallback HP follows the 3-HP Hopper")
	for type in range(4):
		var model := LaneCombatModel.new(type)
		model.clear_for_test()
		model.spawn_enemy(4.0, -1, false, type, 3300 + type)
		_check(int(model.enemies[0].hp) == expected[type] and int(model.enemies[0].max_hp) == expected[type], "%s spawns at P033 full HP" % EnemyTypesScript.display_name(type))
	var healer_model := LaneCombatModel.new(TeamData.Identity.GREEN)
	healer_model.clear_for_test()
	healer_model.spawn_enemy(6.5, -1, false, EnemyTypesScript.Type.HEALYZARD, 3310)
	var hopper := healer_model.spawn_enemy(4.0, 2, false, EnemyTypesScript.Type.HOPPER, 3311)
	var heavy := healer_model.spawn_enemy(4.5, 5, false, EnemyTypesScript.Type.HEAVY, 3312)
	healer_model.update(15.0)
	var health := {}
	for enemy in healer_model.enemies:
		health[int(enemy.uid)] = [int(enemy.hp), int(enemy.max_hp)]
	_check(health[hopper] == [3, 3] and health[heavy] == [6, 6], "Healyzard +1 pulse caps at new canonical maxima")

func _test_touch_router() -> void:
	var router := RouterScript.new()
	var safe := Rect2(100.0, 20.0, 1200.0, 680.0)
	router.configure(RouterScript.Mode.CLASSIC, RouterScript.Handedness.RIGHT, safe)
	_check(float(router.press(7, Vector2(430.0, 80.0)).aim_absolute) == 430.0, "classic primary aims absolutely from conveyor/top area")
	_check(bool(router.press(9, Vector2(900.0, 600.0)).swap), "classic second finger swaps once on down")
	_check(router.press(9, Vector2(900.0, 600.0)).is_empty(), "held/repeated second-finger down cannot duplicate swap")
	_check(router.press(10, Vector2(700.0, 400.0)).is_empty() and router.role_for(10) == &"ignored", "extra classic fingers are ignored while secondary is held")
	_check(router.release(9, Vector2(900.0, 600.0)).is_empty(), "classic swap finger release never shoots")
	_check(bool(router.release(7, Vector2(510.0, 690.0)).shoot), "classic primary release fires exactly once")
	_check(router.release(7, Vector2.ZERO).is_empty(), "duplicate classic release is ignored")
	router.press(12, Vector2(300.0, 300.0))
	_check(router.release(12, Vector2(300.0, 300.0), true).is_empty(), "classic canceled touch never fires")

	router.configure(RouterScript.Mode.SIDE, RouterScript.Handedness.RIGHT, safe)
	var right_track := Vector2(1220.0, 300.0)
	_check(router.press(1, right_track).is_empty(), "right-handed side trackpad down does not teleport or shoot")
	var drag := router.drag(1, right_track + Vector2(-75.0, 0.0), Vector2(-75.0, 0.0))
	_check(float(drag.aim_relative) == -75.0 and router.role_for(1) == &"side_aim", "side trackpad applies 1:1 relative drag")
	_check(router.drag(1, Vector2(200.0, 300.0), Vector2(-945.0, 0.0)).has("aim_relative"), "trackpad retains role after crossing regions")
	_check(router.release(1, Vector2(200.0, 300.0)).is_empty(), "side trackpad release does not fire")
	_check(bool(router.press(2, Vector2(180.0, 100.0)).swap), "right-handed action upper-left swaps")
	_check(bool(router.press(3, Vector2(180.0, 600.0)).shoot), "independent action lower-left shoots on down")
	router.configure(RouterScript.Mode.SIDE, RouterScript.Handedness.LEFT, safe)
	_check(router.press(4, Vector2(180.0, 300.0)).is_empty() and router.role_for(4) == &"side_aim", "left-handed mode mirrors aim to left quarter")
	_check(bool(router.press(5, Vector2(1220.0, 100.0)).swap), "left-handed mode mirrors actions to right quarter")

func _test_preferences() -> void:
	var path := "/tmp/lbs-p033-controls-%d.cfg" % Time.get_ticks_usec()
	var saved := PreferencesScript.new(path)
	saved.mode = RouterScript.Mode.SIDE
	saved.handedness = RouterScript.Handedness.LEFT
	_check(saved.save_settings() == OK, "control settings save through ConfigFile")
	var loaded := PreferencesScript.new(path)
	loaded.load_settings()
	_check(loaded.mode == RouterScript.Mode.SIDE and loaded.handedness == RouterScript.Handedness.LEFT, "control settings persist mode and handedness")
	var corrupt := ConfigFile.new()
	corrupt.set_value("controls", "mode", 99)
	corrupt.set_value("controls", "handedness", "broken")
	corrupt.save(path)
	loaded.load_settings()
	_check(loaded.mode == RouterScript.Mode.CLASSIC and loaded.handedness == RouterScript.Handedness.RIGHT, "corrupt settings recover safe Classic/right defaults")
	DirAccess.remove_absolute(path)

func _test_live_layout_input_ui_and_flash() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var size := Vector2(1280.0, 720.0)
	main.call("_apply_layout", size, Rect2(Vector2.ZERO, size))
	var layout := ResponsiveLayout.calculate(size)
	var shooter: ShooterView = main.get("_shooter_view")
	_check(float(layout.shooter_y) <= 585.0 and layout.thumb_strip_rect.size.y >= 90.0, "1280x720 shooter is raised with a useful thumb strip")
	shooter.move_to(shooter.track_left)
	_check(is_equal_approx(shooter.loaded_ball_center().y, shooter.next_ball_center().y), "loaded and next ammunition share one horizontal row")
	_check(Rect2(Vector2.ZERO, size).has_point(shooter.loaded_ball_center()) and Rect2(Vector2.ZERO, size).has_point(shooter.next_ball_center()), "both ammunition balls stay visible at left edge")
	shooter.move_to(shooter.track_right)
	_check(shooter.next_ball_center().x < shooter.loaded_ball_center().x, "next-ball preview flips left near right edge")
	main.set_mobile_platform_override(1)
	_check(not (main.get("_magazine_view") as MagazineView).visible, "Android injection hides legacy swap button")
	main.set_mobile_platform_override(0)
	_check((main.get("_magazine_view") as MagazineView).visible, "desktop injection preserves legacy swap button")
	var settings: ControlSettingsView = main.get("_settings_view")
	_check(settings.gear_button.mouse_filter == Control.MOUSE_FILTER_STOP and settings.panel.mouse_filter == Control.MOUSE_FILTER_STOP, "settings UI has input priority over gameplay")
	settings.call("_open")
	_check(settings.is_open() and int(main.get("_active_touch_id")) == -1, "opening modal cancels active gestures without a shot")
	settings.call("_close")

	var lane: LaneActor = (main.get("_battlefield") as Battlefield).lanes[0]
	lane.set_process(false)
	lane.combat_model.clear_for_test()
	var first := lane.combat_model.spawn_enemy(1.0, -1, false, EnemyTypesScript.Type.HOPPER, 3391)
	var second := lane.combat_model.spawn_enemy(2.0, -1, false, EnemyTypesScript.Type.HEALYZARD, 3392)
	lane.call("_sync_visuals")
	lane.combat_model.call("_damage_enemy", first, 1, 1.0)
	lane.call("_sync_visuals")
	var first_visual: Dictionary = lane.get("_enemy_visuals")[first]
	var second_visual: Dictionary = lane.get("_enemy_visuals")[second]
	var first_overlay := first_visual.hit_overlay as Sprite2D
	var second_overlay := second_visual.hit_overlay as Sprite2D
	_check((first_visual.sprite as Sprite2D).material == null and (second_visual.sprite as Sprite2D).material == null, "original enemy sprites remain shader-free and unmodified")
	_check(first_overlay.visible and first_overlay.modulate.a > 0.99 and not second_overlay.visible, "damage shows only the victim's solid-red silhouette overlay")
	var overlay_instance_id := first_overlay.get_instance_id()
	lane.combat_model.call("_damage_enemy", first, 1, 1.0)
	lane.call("_sync_visuals")
	_check(first_overlay.get_instance_id() == overlay_instance_id and first_overlay.modulate.a > 0.99, "repeat damage refreshes the existing overlay without allocation")
	lane.combat_model.call("_damage_enemy", first, 1, 1.0)
	_check(lane.get("_death_effects").size() == 1 and first_overlay.visible and first_overlay.modulate.a > 0.99, "lethal victim enters corpse animation with its vivid-red silhouette")
	lane.call("_update_death_effects", 0.17)
	_check(not first_overlay.visible and first_overlay.modulate.a < 0.01, "corpse overlay hides before existing fall/fade completes")
	main.call("_restart_run")
	_check((main.get("_battlefield") as Battlefield).lanes.all(func(item: LaneActor) -> bool: return item.get("_death_effects").is_empty()), "restart clears all flash/corpse state")
	_check(main.find_children("*", "Node3D", true, false).is_empty(), "P033 keeps live gameplay fully 2D")
	main.queue_free()
	await process_frame

func _test_renderer_evidence() -> void:
	for fixture in [{"path": "res://assets/previews/p033_controls_hit_flash_1280x720.png", "size": Vector2i(1280, 720)}, {"path": "res://assets/previews/p033_controls_settings_1600x720.png", "size": Vector2i(1600, 720)}]:
		var image := Image.new()
		var result := image.load(ProjectSettings.globalize_path(str(fixture.path)))
		_check(result == OK and image.get_size() == fixture.size, "%s is a required real-renderer P033 screenshot" % fixture.path)
		if result == OK:
			var colors := {}
			for y in range(0, image.get_height(), 20):
				for x in range(0, image.get_width(), 20):
					colors[image.get_pixel(x, y).to_html()] = true
			_check(colors.size() > 90, "%s contains nontrivial rendered gameplay" % fixture.path)

func _finish() -> void:
	if _failures.is_empty():
		print("P033 controls and enemy HP: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P033 controls and enemy HP: " + failure)
	print("P033 controls and enemy HP: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
