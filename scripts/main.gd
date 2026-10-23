extends Node

const SHOOT_COOLDOWN := 0.4

var _background: ColorRect
var _battlefield_container: SubViewportContainer
var _battlefield_viewport: SubViewport
var _chain_view: BallChainView
var _shooter_view: ShooterView
var _magazine_view: MagazineView
var _hud_view: HudView
var _magazine := MagazineState.new()
var _chain_model := ChainModel.new()
var _progression := MatchProgression.new()
var _cooldown_remaining := 0.0
var _active_touch_id := -1
var _touch_started_in_playfield := false
var _playfield_rect := Rect2()

func _ready() -> void:
	_build_scene()
	_magazine.changed.connect(_on_magazine_changed)
	_magazine_view.swap_requested.connect(_swap)
	_shooter_view.shot_reached_lane.connect(_on_shot_reached_lane)
	_chain_model.match_completed.connect(_on_chain_match_completed)
	_progression.state_changed.connect(_on_progression_state_changed)
	_progression.match_resolved.connect(_on_match_resolved)
	get_viewport().size_changed.connect(_layout)
	_on_magazine_changed(_magazine.loaded_identity, _magazine.next_identity)
	_progression.publish_state()
	_layout()

func _process(delta: float) -> void:
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	_chain_model.advance(delta)
	_progression.update(delta)

func _unhandled_input(event: InputEvent) -> void:
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
	elif event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag and event.index == _active_touch_id:
		_shooter_view.move_to(event.position.x)
		get_viewport().set_input_as_handled()

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _active_touch_id == -1 and _playfield_rect.has_point(event.position):
			_active_touch_id = event.index
			_touch_started_in_playfield = true
			_shooter_view.move_to(event.position.x)
	else:
		if event.index == _active_touch_id:
			_shooter_view.move_to(event.position.x)
			if _touch_started_in_playfield:
				_shoot()
			_active_touch_id = -1
			_touch_started_in_playfield = false
	get_viewport().set_input_as_handled()

func _shoot() -> void:
	if _cooldown_remaining > 0.0:
		return
	var fired_identity := _magazine.consume_loaded()
	_shooter_view.launch(fired_identity)
	_cooldown_remaining = SHOOT_COOLDOWN

func _swap() -> void:
	_magazine.swap()

func _on_magazine_changed(loaded: int, next_value: int) -> void:
	_shooter_view.set_loaded(loaded)
	_magazine_view.set_identities(loaded, next_value)

func _on_shot_reached_lane(identity: int, screen_x: float) -> void:
	_chain_model.try_insert_shot(identity, screen_x - _chain_view.position.x)

func _on_chain_match_completed(identity: int, group_size: int) -> void:
	_progression.register_match(identity, group_size)

func _on_progression_state_changed(score: int, combo_count: int, tier: int, fever_active: bool, window_ratio: float) -> void:
	_hud_view.set_progress(score, combo_count, tier, fever_active, window_ratio)

func _on_match_resolved(result: Dictionary) -> void:
	_chain_view.show_progression_feedback(result)

func _build_scene() -> void:
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
	_battlefield_viewport.add_child(Battlefield.new())

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

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return
	_background.position = Vector2.ZERO
	_background.size = viewport_size

	var hud_height := clampf(viewport_size.y * 0.065, 38.0, 48.0)
	var chain_height := clampf(viewport_size.y * 0.13, 76.0, 104.0)
	var bottom_height := clampf(viewport_size.y * 0.22, 136.0, 178.0)
	var center_top := hud_height + chain_height + 8.0
	var center_bottom := viewport_size.y - bottom_height
	var center_height := maxf(225.0, center_bottom - center_top)

	_hud_view.position = Vector2.ZERO
	_hud_view.size = Vector2(viewport_size.x, hud_height)
	_chain_view.position = Vector2(14.0, hud_height)
	_chain_view.size = Vector2(viewport_size.x - 28.0, chain_height)
	_chain_model.set_lane_width(_chain_view.size.x)
	_battlefield_container.position = Vector2(14.0, center_top)
	_battlefield_container.size = Vector2(viewport_size.x - 28.0, center_height)

	var magazine_size := Vector2(clampf(viewport_size.x * 0.25, 280.0, 340.0), clampf(bottom_height - 24.0, 112.0, 142.0))
	_magazine_view.position = Vector2(viewport_size.x - magazine_size.x - 18.0, center_bottom + 12.0)
	_magazine_view.size = magazine_size
	_shooter_view.position = Vector2.ZERO
	_shooter_view.size = viewport_size
	var track_right := _magazine_view.position.x - 24.0
	var chain_lane_center := hud_height + 10.0 + maxf(56.0, chain_height - 14.0) * 0.5
	_shooter_view.configure_layout(viewport_size.y - 48.0, 44.0, track_right, chain_lane_center)
	_playfield_rect = Rect2(Vector2(0.0, center_top), Vector2(viewport_size.x, viewport_size.y - center_top))
