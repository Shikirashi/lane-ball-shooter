extends Node

const SHOOT_COOLDOWN := 0.4
const LayoutCalculator = preload("res://scripts/responsive_layout.gd")
const SfxManagerScript = preload("res://scripts/audio/sfx_manager.gd")

var _background: ColorRect
var _battlefield_container: SubViewportContainer
var _battlefield_viewport: SubViewport
var _battlefield: Battlefield
var _chain_view: BallChainView
var _shooter_view: ShooterView
var _magazine_view: MagazineView
var _hud_view: HudView
var _game_over_overlay: GameOverOverlay
var _sfx: Node
var _magazine := MagazineState.new()
var _chain_model := ChainModel.new()
var _progression := MatchProgression.new()
var _cooldown_remaining := 0.0
var _active_touch_id := -1
var _touch_started_in_playfield := false
var _playfield_rect := Rect2()
var _safe_rect := Rect2()
var _game_over := false
var _progression_chain_time := 0.0
var _processing_chain := false

func _ready() -> void:
	_build_scene()
	_magazine.changed.connect(_on_magazine_changed)
	_magazine_view.swap_requested.connect(_swap)
	_shooter_view.shot_reached_lane.connect(_on_shot_reached_lane)
	_chain_model.match_completed.connect(_on_chain_match_completed)
	_progression.state_changed.connect(_on_progression_state_changed)
	_progression.match_resolved.connect(_on_match_resolved)
	_battlefield.game_over_requested.connect(_on_game_over_requested)
	_battlefield.defender_knocked_down.connect(_on_defender_knocked_down)
	_battlefield.defender_revived.connect(_on_defender_revived)
	_game_over_overlay.restart_requested.connect(_restart_run)
	get_viewport().size_changed.connect(_layout)
	_on_magazine_changed(_magazine.loaded_identity, _magazine.next_identity)
	_progression.publish_state()
	_layout()

func _process(delta: float) -> void:
	if _game_over:
		return
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	_progression_chain_time = _chain_model.simulation_time
	_processing_chain = true
	_chain_model.advance(delta)
	_sync_progression_to_chain_time()
	_processing_chain = false

func _unhandled_input(event: InputEvent) -> void:
	if _game_over:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			_restart_run()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_shooter_view.move_to(event.position.x)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _playfield_rect.has_point(event.position):
			_shooter_view.move_to(event.position.x)
			_shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_swap()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_swap()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F3:
			_chain_view.toggle_debug()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_M:
			_sfx.toggle_mute()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _active_touch_id:
		_shooter_view.move_to(event.position.x)
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_touch_ownership()

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _active_touch_id == -1 and _playfield_rect.has_point(event.position):
			_active_touch_id = event.index
			_touch_started_in_playfield = true
			_shooter_view.move_to(event.position.x)
	else:
		if event.index == _active_touch_id:
			_shooter_view.move_to(event.position.x)
			if _touch_started_in_playfield and not event.canceled:
				_shoot()
			_clear_touch_ownership()
	get_viewport().set_input_as_handled()

func _clear_touch_ownership() -> void:
	_active_touch_id = -1
	_touch_started_in_playfield = false

func _shoot() -> void:
	if _game_over or _cooldown_remaining > 0.0:
		return
	var fired_identity := _magazine.consume_loaded()
	_shooter_view.launch(fired_identity)
	_sfx.play_cue("shoot")
	_cooldown_remaining = SHOOT_COOLDOWN

func _swap() -> void:
	if _game_over:
		return
	_magazine.swap()
	_sfx.play_cue("swap")

func _on_magazine_changed(loaded: int, next_value: int) -> void:
	_shooter_view.set_ammunition(loaded, next_value)

func _on_shot_reached_lane(identity: int, screen_x: float) -> void:
	if _chain_model.try_insert_shot(identity, screen_x - _chain_view.position.x):
		_sfx.play_cue("insert")

func _on_chain_match_completed(identity: int, group_size: int) -> void:
	if _processing_chain:
		_sync_progression_to_chain_time()
	_sfx.play_cue("match")
	_progression.register_match(identity, group_size)

func _sync_progression_to_chain_time() -> void:
	var elapsed := maxf(0.0, _chain_model.simulation_time - _progression_chain_time)
	if elapsed > 0.0:
		_progression.update(elapsed)
	_progression_chain_time = _chain_model.simulation_time

func _on_progression_state_changed(score: int, combo_count: int, tier: int, fever_active: bool, window_ratio: float) -> void:
	_hud_view.set_progress(score, combo_count, tier, fever_active, window_ratio)

func _on_match_resolved(result: Dictionary) -> void:
	_chain_view.show_progression_feedback(result)
	var outcome := _battlefield.handle_match(result)
	if str(outcome.get("action", "")) == "attack":
		var attack: Dictionary = outcome.get("attack", {})
		_sfx.play_cue("attack", int(attack.get("tier", 1)))

func _on_defender_knocked_down(_identity: int) -> void:
	_sfx.play_cue("knockdown")

func _on_defender_revived(_identity: int) -> void:
	_sfx.play_cue("revive")

func _on_game_over_requested(_identity: int) -> void:
	if _game_over:
		return
	_game_over = true
	_sfx.set_gameplay_enabled(false)
	_clear_touch_ownership()
	_shooter_view.set_simulation_paused(true)
	_chain_view.set_settling_visuals_visible(false)
	_game_over_overlay.show_game_over(_progression.score)

func _restart_run() -> void:
	_game_over = false
	_sfx.reset_run()
	_cooldown_remaining = 0.0
	_clear_touch_ownership()
	_shooter_view.reset_run()
	_chain_view.reset_feedback()
	_chain_model.reset_run()
	_progression_chain_time = _chain_model.simulation_time
	_processing_chain = false
	_progression.reset_run()
	_magazine.reset_run()
	_battlefield.reset_run()
	_game_over_overlay.hide_for_restart()

func _build_scene() -> void:
	_sfx = SfxManagerScript.new()
	_sfx.name = "SFX"
	add_child(_sfx)
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color(0.025, 0.035, 0.065)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_battlefield_container = SubViewportContainer.new()
	_battlefield_container.name = "BattlefieldRegion"
	_battlefield_container.stretch = true
	_battlefield_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_battlefield_container)
	_battlefield_viewport = SubViewport.new()
	_battlefield_viewport.name = "BattlefieldViewport"
	_battlefield_viewport.handle_input_locally = false
	_battlefield_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_battlefield_viewport.msaa_3d = Viewport.MSAA_2X
	_battlefield_container.add_child(_battlefield_viewport)
	_battlefield = Battlefield.new()
	_battlefield.name = "Battlefield"
	_battlefield_viewport.add_child(_battlefield)

	_chain_view = BallChainView.new()
	_chain_view.name = "BallChain"
	add_child(_chain_view)
	_chain_view.set_model(_chain_model)
	_shooter_view = ShooterView.new()
	_shooter_view.name = "Shooter"
	add_child(_shooter_view)
	_magazine_view = MagazineView.new()
	_magazine_view.name = "Magazine"
	add_child(_magazine_view)
	_hud_view = HudView.new()
	_hud_view.name = "HUD"
	add_child(_hud_view)
	_game_over_overlay = GameOverOverlay.new()
	_game_over_overlay.name = "GameOverOverlay"
	add_child(_game_over_overlay)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return
	_apply_layout(viewport_size, _resolve_safe_rect(viewport_size))

func _apply_layout(viewport_size: Vector2, safe_rect: Rect2) -> void:
	var layout: Dictionary = LayoutCalculator.calculate(viewport_size, safe_rect)
	_safe_rect = layout.safe_rect
	_background.position = Vector2.ZERO
	_background.size = viewport_size

	_hud_view.position = layout.hud_rect.position
	_hud_view.size = layout.hud_rect.size
	_game_over_overlay.position = Vector2.ZERO
	_game_over_overlay.size = viewport_size
	_game_over_overlay.set_content_rect(_safe_rect)
	_chain_view.position = layout.chain_rect.position
	_chain_view.size = layout.chain_rect.size
	_chain_model.set_lane_width(_chain_view.size.x)
	_battlefield_container.position = layout.battlefield_rect.position
	_battlefield_container.size = layout.battlefield_rect.size
	_battlefield_container.stretch_shrink = maxi(1, ceili(maxf(
		_battlefield_container.size.x / LayoutCalculator.MAX_3D_WIDTH,
		_battlefield_container.size.y / LayoutCalculator.MAX_3D_HEIGHT
	)))
	_battlefield.configure_viewport_aspect(_battlefield_container.size.x / maxf(_battlefield_container.size.y, 1.0))

	_magazine_view.position = layout.magazine_rect.position
	_magazine_view.size = layout.magazine_rect.size
	_shooter_view.position = Vector2.ZERO
	_shooter_view.size = viewport_size
	_shooter_view.configure_layout(layout.shooter_y, layout.track_left, layout.track_right, layout.shot_ceiling)
	_playfield_rect = layout.playfield_rect

func _resolve_safe_rect(viewport_size: Vector2) -> Rect2:
	var fallback := Rect2(Vector2.ZERO, viewport_size)
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return fallback
	var display_safe := DisplayServer.get_display_safe_area()
	if display_safe.size.x <= 0 or display_safe.size.y <= 0:
		return fallback
	var window_position := DisplayServer.window_get_position()
	var relative_safe := Rect2(Vector2(display_safe.position - window_position), Vector2(display_safe.size))
	relative_safe = relative_safe.intersection(Rect2(Vector2.ZERO, window_size))
	if relative_safe.size.x < window_size.x * 0.5 or relative_safe.size.y < window_size.y * 0.5:
		return fallback
	var scale := viewport_size / window_size
	return Rect2(relative_safe.position * scale, relative_safe.size * scale)
