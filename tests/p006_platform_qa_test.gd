extends SceneTree

const LayoutCalculator = preload("res://scripts/responsive_layout.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	_test_layout_calculator()
	await _test_live_layout_and_input()
	_test_entity_bounds()
	_finish()

func _test_layout_calculator() -> void:
	var sizes := [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]
	for size in sizes:
		var layout: Dictionary = LayoutCalculator.calculate(size)
		var safe: Rect2 = layout.safe_rect
		_check(safe.encloses(layout.hud_rect), "%s HUD remains in safe region" % size)
		_check(safe.encloses(layout.chain_rect), "%s chain remains in safe region" % size)
		_check(safe.encloses(layout.battlefield_rect), "%s battlefield remains in safe region" % size)
		_check(safe.encloses(layout.magazine_rect), "%s magazine remains in safe region" % size)
		_check(layout.chain_rect.end.y <= layout.battlefield_rect.position.y, "%s chain and battlefield do not overlap" % size)
		_check(layout.battlefield_rect.end.y <= layout.magazine_rect.position.y, "%s battlefield and magazine do not overlap" % size)
		_check(float(layout.track_right) < layout.magazine_rect.position.x, "%s shooter track stops before magazine" % size)
		var render_size := LayoutCalculator.bounded_render_size(layout.battlefield_rect.size)
		_check(render_size.x <= int(LayoutCalculator.MAX_3D_WIDTH) and render_size.y <= int(LayoutCalculator.MAX_3D_HEIGHT), "%s 3D render resolution is bounded" % size)

	var cutout_safe := Rect2(96.0, 24.0, 2208.0, 1032.0)
	var cutout_layout: Dictionary = LayoutCalculator.calculate(Vector2(2400, 1080), cutout_safe)
	_check(cutout_layout.safe_rect == cutout_safe, "valid mobile cutout safe rectangle is preserved")
	_check(cutout_safe.encloses(cutout_layout.magazine_rect) and cutout_safe.encloses(cutout_layout.hud_rect), "critical controls stay inside mobile cutout safe rectangle")

func _test_live_layout_and_input() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var safe := Rect2(72.0, 18.0, 1456.0, 684.0)
	main.call("_apply_layout", Vector2(1600, 720), safe)
	var chain: BallChainView = main.get("_chain_view")
	var battlefield_region: SubViewportContainer = main.get("_battlefield_container")
	var magazine_view: MagazineView = main.get("_magazine_view")
	var shooter: ShooterView = main.get("_shooter_view")
	var magazine: MagazineState = main.get("_magazine")
	var overlay: GameOverOverlay = main.get("_game_over_overlay")
	var playfield: Rect2 = main.get("_playfield_rect")
	_check(safe.encloses(Rect2(chain.position, chain.size)), "live chain uses injected safe rectangle")
	_check(safe.encloses(Rect2(magazine_view.position, magazine_view.size)), "live magazine uses injected safe rectangle")
	_check(battlefield_region.stretch_shrink >= 1, "live 3D viewport uses a positive render shrink")
	_check(shooter.track_left >= safe.position.x and shooter.track_right < magazine_view.position.x, "live shooter track remains usable and clear of swap UI")
	_check(magazine_view.get("_swap_rect").size.x >= 44.0 and magazine_view.get("_swap_rect").size.y >= 44.0, "swap touch target is at least 44 logical pixels")
	var restart_button: Button = overlay.get("_restart_button")
	_check(safe.encloses(Rect2(restart_button.position, restart_button.size)), "restart button stays in safe rectangle")

	shooter.reset_run()
	main.set("_cooldown_remaining", 0.0)
	var touch_x := playfield.position.x + 120.0
	var touch_y := playfield.position.y + 50.0
	await _dispatch_touch(3, Vector2(touch_x, touch_y), true)
	await _dispatch_drag(3, Vector2(touch_x + 80.0, touch_y + 20.0))
	await _dispatch_touch(3, Vector2(touch_x + 80.0, touch_y + 20.0), false)
	_check(shooter.get("_shots").size() == 1, "playfield touch drag and release fires exactly once")
	await _dispatch_touch(3, Vector2(touch_x + 80.0, touch_y + 20.0), false)
	_check(shooter.get("_shots").size() == 1, "duplicate touch release cannot fire twice")

	shooter.reset_run()
	main.set("_cooldown_remaining", 0.0)
	await _dispatch_touch(4, Vector2(safe.position.x + 20.0, safe.position.y + 10.0), true)
	await _dispatch_drag(4, Vector2(touch_x, touch_y))
	await _dispatch_touch(4, Vector2(touch_x, touch_y), false)
	_check(shooter.get("_shots").is_empty(), "touch beginning outside playfield never fires after dragging inside")

	await _dispatch_touch(5, Vector2(touch_x, touch_y), true)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 5
	canceled.position = Vector2(touch_x, touch_y)
	canceled.pressed = false
	canceled.canceled = true
	root.push_input(canceled, true)
	await process_frame
	_check(shooter.get("_shots").is_empty() and int(main.get("_active_touch_id")) == -1, "canceled touch clears ownership without firing")

	var loaded_before := magazine.loaded_identity
	var next_before := magazine.next_identity
	var swap_touch := InputEventScreenTouch.new()
	swap_touch.index = 8
	swap_touch.position = magazine_view.get("_swap_rect").get_center()
	swap_touch.pressed = true
	magazine_view.call("_gui_input", swap_touch)
	_check(magazine.loaded_identity == next_before and magazine.next_identity == loaded_before, "swap touch changes magazine only")
	_check(shooter.get("_shots").is_empty() and int(main.get("_active_touch_id")) == -1, "swap touch creates no shot or playfield ownership")

	shooter.reset_run()
	main.set("_cooldown_remaining", 0.0)
	await _dispatch_touch(10, Vector2(touch_x, touch_y), true)
	await _dispatch_touch(11, Vector2(touch_x + 30.0, touch_y), true)
	await _dispatch_touch(11, Vector2(touch_x + 30.0, touch_y), false)
	_check(shooter.get("_shots").is_empty() and int(main.get("_active_touch_id")) == 10, "second finger cannot steal or release the active touch")
	await _dispatch_touch(10, Vector2(touch_x, touch_y), false)
	_check(shooter.get("_shots").size() == 1, "owned finger still fires once after unrelated second touch")

	shooter.reset_run()
	main.set("_cooldown_remaining", 0.0)
	await _dispatch_mouse_button(MOUSE_BUTTON_LEFT, Vector2(safe.position.x + 10.0, safe.position.y + 10.0))
	_check(shooter.get("_shots").is_empty(), "left mouse click outside playfield cannot fire")
	await _dispatch_mouse_button(MOUSE_BUTTON_LEFT, Vector2(touch_x, touch_y))
	_check(shooter.get("_shots").size() == 1, "left mouse click in playfield fires once")
	shooter.reset_run()
	main.set("_cooldown_remaining", 0.0)
	loaded_before = magazine.loaded_identity
	next_before = magazine.next_identity
	await _dispatch_mouse_button(MOUSE_BUTTON_RIGHT, Vector2(touch_x, touch_y))
	_check(magazine.loaded_identity == next_before and magazine.next_identity == loaded_before, "right mouse click swaps anywhere in playfield")
	_check(shooter.get("_shots").is_empty(), "right mouse swap never fires")

	main.call("_on_game_over_requested", TeamData.Identity.RED)
	await _dispatch_touch(9, Vector2(touch_x, touch_y), true)
	await _dispatch_touch(9, Vector2(touch_x, touch_y), false)
	_check(shooter.get("_shots").is_empty(), "game over blocks touch shooting")
	main.call("_restart_run")
	await _dispatch_touch(9, Vector2(touch_x, touch_y), false)
	_check(shooter.get("_shots").is_empty() and int(main.get("_active_touch_id")) == -1, "release after restart cannot become a stale shot")

	for repeat in range(4):
		main.call("_restart_run")
		await process_frame
	var battlefield: Battlefield = main.get("_battlefield")
	for lane in battlefield.lanes:
		_check(lane.get("_enemy_visuals").size() == lane.combat_model.active_enemy_count(), "restart lane %d has no stale enemy visuals" % lane.team_identity)
		_check(lane.get("_projectile_visuals").size() == 0 and lane.get("_state_effects").is_empty(), "restart lane %d clears projectiles and state effects" % lane.team_identity)
	main.queue_free()
	await process_frame

func _dispatch_touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame

func _dispatch_drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	event.relative = Vector2(80.0, 20.0)
	root.push_input(event, true)
	await process_frame

func _dispatch_mouse_button(button: MouseButton, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.pressed = true
	root.push_input(event, true)
	await process_frame

func _test_entity_bounds() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.BLUE)
	model.clear_for_test()
	model.auto_spawn = true
	model.enemy_speed = 0.0
	model.spawn_interval = 0.1
	model.max_enemies = 5
	for step in range(200):
		model.update(0.1)
	_check(model.active_enemy_count() == model.max_enemies, "steady-state enemy population respects configured cap")
	for attack in range(180):
		model.fire_attack({"tier": 3, "group_size": 3, "fever": true})
	_check(model.attack_history.size() == LaneCombatModel.HISTORY_LIMIT, "attack diagnostics remain history-bounded")
	for step in range(30):
		model.update(0.1)
	_check(model.active_projectile_count() == 0, "expired offscreen projectiles are cleaned up")
	_check(model.hit_history.size() <= LaneCombatModel.HISTORY_LIMIT, "hit diagnostics remain history-bounded")

func _finish() -> void:
	if _failures.is_empty():
		print("P006 platform QA: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P006 platform QA: " + failure)
	print("P006 platform QA: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
