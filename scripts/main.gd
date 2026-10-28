extends Node

const SHOOT_COOLDOWN := 0.4
const VICTORY_PRESENTATION_DELAY := 3.0
const LayoutCalculator = preload("res://scripts/responsive_layout.gd")
const SfxManagerScript = preload("res://scripts/audio/sfx_manager.gd")
const TouchRouterScript = preload("res://scripts/input/touch_control_router.gd")
const PreferencesScript = preload("res://scripts/input/control_preferences.gd")
const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu_view.gd")
const AndroidHapticsScript = preload("res://scripts/android_haptics.gd")
# Live Web playtest: use the same eligible-threat-only mild sampler tested by P028B-EXPR.
const ThreatRunSelectorScript = preload("res://scripts/analysis/threat_run_selector.gd")
const BalanceLabScript = preload("res://scripts/analysis/balance_lab.gd")
const THREAT_BIAS_PLAYTEST_ARM := "mild"
const THREAT_BIAS_SEED_XOR := 0x6B5EED

var _background: ColorRect
var _battlefield: Battlefield
var _chain_view: BallChainView
var _shooter_view: ShooterView
var _magazine_view: MagazineView
var _hud_view: HudView
var _game_over_overlay: GameOverOverlay
var _settings_view: ControlSettingsView
var _pause_view: PauseMenuView
var _sfx: Node
var _magazine := MagazineState.new()
var _chain_model := ChainModel.new()
var _threat_bias: ThreatRunSelector
var _progression := MatchProgression.new()
var _cooldown_remaining := 0.0
var _active_touch_id := -1 # Compatibility mirror of the router's primary ID.
var _touch_started_in_playfield := false
var _touch_router := TouchRouterScript.new()
var _preferences := PreferencesScript.new()
var _mobile_platform_override := -1
var _playfield_rect := Rect2()
var _safe_rect := Rect2()
var _game_over := false
var _victory := false
var _victory_pending := false
var _victory_delay_remaining := 0.0
var _progression_chain_time := 0.0
var _processing_chain := false
var _paused := false
var main_menu_requester: Callable
var vibration_requester: Callable

func _ready() -> void:
	_build_scene()
	_configure_threat_bias_playtest()
	_preferences.load_settings()
	_touch_router.configure(_preferences.mode, _preferences.handedness, get_viewport().get_visible_rect())
	_magazine.changed.connect(_on_magazine_changed)
	_magazine_view.swap_requested.connect(_swap)
	_shooter_view.shot_reached_lane.connect(_on_shot_reached_lane)
	_chain_model.match_completed.connect(_on_chain_match_completed)
	_progression.state_changed.connect(_on_progression_state_changed)
	_progression.match_resolved.connect(_on_match_resolved)
	_battlefield.game_over_requested.connect(_on_game_over_requested)
	_battlefield.encounter_cleared.connect(_on_encounter_cleared)
	_battlefield.encounter_progress_changed.connect(_on_encounter_progress_changed)
	_battlefield.defender_knocked_down.connect(_on_defender_knocked_down)
	_battlefield.defender_revived.connect(_on_defender_revived)
	_battlefield.enemy_death_started.connect(_on_enemy_death_started)
	_game_over_overlay.restart_requested.connect(_restart_run)
	_settings_view.choices_changed.connect(_on_control_choices_changed)
	_settings_view.visibility_changed_by_user.connect(_on_settings_visibility_changed)
	_pause_view.pause_requested.connect(_pause_game)
	_pause_view.resume_requested.connect(_resume_game)
	_pause_view.restart_confirmed.connect(_restart_from_pause)
	_pause_view.main_menu_confirmed.connect(_return_to_main_menu)
	_pause_view.choices_changed.connect(_on_control_choices_changed)
	_pause_view.test_vibration_requested.connect(_on_test_vibration_requested)
	_settings_view.set_choices(_preferences.mode, _preferences.handedness)
	get_viewport().size_changed.connect(_layout)
	_on_magazine_changed(_magazine.loaded_identity, _magazine.next_identity)
	_progression.publish_state()
	_on_encounter_progress_changed(_battlefield.encounter_neutralized(), _battlefield.encounter_total(), _battlefield.encounter_remaining())
	_layout()

func _process(delta: float) -> void:
	if _victory_pending:
		_victory_delay_remaining = maxf(0.0, _victory_delay_remaining - maxf(delta, 0.0))
		if _victory_delay_remaining <= 0.000001:
			_finish_victory_presentation()
		return
	if _game_over:
		return
	_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	_progression_chain_time = _chain_model.simulation_time
	# Snapshot CURRENT live battlefield before the feeder advances; no future
	# enemies, offscreen color lookahead or retroactive run selection.
	_threat_bias.set_threat_snapshot(BalanceLabScript.lane_time_to_danger(_battlefield))
	_processing_chain = true
	_chain_model.advance(delta)
	_sync_progression_to_chain_time()
	_processing_chain = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK) and _is_mobile_platform() and not _game_over:
		if _paused:
			_resume_game()
		else:
			_pause_game()
		get_viewport().set_input_as_handled()
		return
	if _paused:
		return
	if _game_over:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
			_restart_run()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_shooter_view.move_to(event.position.x)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
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
	elif event is InputEventScreenDrag:
		_apply_touch_action(_touch_router.drag(event.index, event.position, event.relative))
		_active_touch_id = _touch_router.primary_id
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_touch_ownership()

func _handle_touch(event: InputEventScreenTouch) -> void:
	var action := _touch_router.press(event.index, event.position) if event.pressed else _touch_router.release(event.index, event.position, event.canceled)
	_apply_touch_action(action)
	_active_touch_id = _touch_router.primary_id
	_touch_started_in_playfield = _active_touch_id >= 0
	get_viewport().set_input_as_handled()

func _apply_touch_action(action: Dictionary) -> void:
	if action.has("aim_absolute"):
		_shooter_view.move_to(float(action.aim_absolute))
	if action.has("aim_relative"):
		_shooter_view.move_to(_shooter_view.shooter_x + float(action.aim_relative))
	if bool(action.get("swap", false)):
		_swap()
	if bool(action.get("shoot", false)):
		_shoot()

func _clear_touch_ownership() -> void:
	_touch_router.cancel_all()
	_active_touch_id = -1
	_touch_started_in_playfield = false

func set_mobile_platform_override(value: int) -> void:
	_mobile_platform_override = value
	if _magazine_view != null:
		_magazine_view.visible = not _is_mobile_platform()
	if _settings_view != null:
		_settings_view.gear_button.visible = not _is_mobile_platform()
	if _pause_view != null:
		_pause_view.pause_button.visible = _is_mobile_platform() and not _game_over
		_pause_view.set_haptics_enabled(_is_mobile_platform())

func _is_mobile_platform() -> bool:
	if _mobile_platform_override >= 0:
		return _mobile_platform_override == 1
	return OS.has_feature("android")

func _on_control_choices_changed(mode: int, handedness: int) -> void:
	_preferences.mode = mode
	_preferences.handedness = handedness
	_preferences.save_settings()
	_touch_router.configure(mode, handedness, _safe_rect)
	_clear_touch_ownership()
	_pause_view.guide.configure(mode, handedness)

func _on_settings_visibility_changed(_open: bool) -> void:
	_clear_touch_ownership()

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
	if _game_over:
		return
	if _chain_model.try_insert_shot(identity, screen_x - _chain_view.position.x):
		_sfx.play_cue("insert")

func _on_chain_match_completed(identity: int, group_size: int) -> void:
	if _game_over:
		return
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
	if _game_over:
		return
	_chain_view.show_progression_feedback(result)
	var outcome := _battlefield.handle_match(result)
	if str(outcome.get("action", "")) == "attack":
		var attack: Dictionary = outcome.get("attack", {})
		_sfx.play_cue("attack", int(attack.get("tier", 1)))

func _on_defender_knocked_down(identity: int) -> void:
	_sfx.play_cue("knockdown")
	print("%s defender_down lane=%d android_gate=%s" % [AndroidHapticsScript.LOG_PREFIX, identity, str(_is_mobile_platform()).to_lower()])
	_request_defender_knockdown_vibration(identity)

func _request_defender_knockdown_vibration(identity := -1) -> bool:
	return AndroidHapticsScript.request(&"defender_down", identity, _is_mobile_platform(), vibration_requester)

func _on_test_vibration_requested() -> void:
	var requested := AndroidHapticsScript.request(&"controls_test", -1, _is_mobile_platform(), vibration_requester)
	_pause_view.show_vibration_request_sent(requested)

func _on_defender_revived(_identity: int) -> void:
	_sfx.play_cue("revive")

func _on_enemy_death_started(_identity: int, _enemy_uid: int, _impact_x: float, _cause: StringName) -> void:
	_sfx.play_cue("enemy_death")

func _on_game_over_requested(_identity: int) -> void:
	if _game_over:
		return
	_game_over = true
	_victory = false
	_victory_pending = false
	_victory_delay_remaining = 0.0
	_sfx.set_gameplay_enabled(false)
	_clear_touch_ownership()
	_shooter_view.set_simulation_paused(true)
	_chain_view.set_settling_visuals_visible(false)
	_game_over_overlay.show_game_over(_progression.score)
	_pause_view.pause_button.visible = false

func _on_encounter_cleared() -> void:
	if _game_over:
		return
	_game_over = true
	_victory = true
	_victory_pending = true
	_victory_delay_remaining = VICTORY_PRESENTATION_DELAY
	_clear_touch_ownership()
	_shooter_view.set_simulation_paused(true)
	_chain_view.set_settling_visuals_visible(false)
	_pause_view.pause_button.visible = false

func _finish_victory_presentation() -> void:
	if not _victory_pending or not _victory:
		return
	_victory_pending = false
	_victory_delay_remaining = 0.0
	_sfx.set_gameplay_enabled(false)
	_game_over_overlay.show_wave_cleared(_progression.score)

func _on_encounter_progress_changed(neutralized: int, total: int, remaining: int) -> void:
	_hud_view.set_enemy_progress(neutralized, total, remaining)

func _configure_threat_bias_playtest() -> void:
	# Independent deterministic RNG plus the baseline shadow-run sampler retain
	# the exact experimental mild rule and original run-length sequence. Normal
	# four-color bag legality/no-immediate-repeat remains ChainModel-owned.
	var chain_seed := _chain_model.fresh_seed
	_threat_bias = ThreatRunSelectorScript.new(
		THREAT_BIAS_PLAYTEST_ARM, chain_seed ^ THREAT_BIAS_SEED_XOR, chain_seed
	)
	_threat_bias.chain_model = _chain_model
	_chain_model.set_analysis_fresh_run_callbacks(
		Callable(_threat_bias, "choose"),
		Callable(_threat_bias, "observe"),
		Callable(_threat_bias, "choose_paired_run_length")
	)

func _restart_run() -> void:
	_game_over = false
	_victory = false
	_victory_pending = false
	_victory_delay_remaining = 0.0
	_sfx.reset_run()
	_cooldown_remaining = 0.0
	_clear_touch_ownership()
	_shooter_view.reset_run()
	_chain_view.reset_feedback()
	_configure_threat_bias_playtest()
	_chain_model.reset_run()
	_progression_chain_time = _chain_model.simulation_time
	_processing_chain = false
	_progression.reset_run()
	_magazine.reset_run()
	_battlefield.reset_run()
	_game_over_overlay.hide_for_restart()
	_pause_view.pause_button.visible = _is_mobile_platform()

func _pause_game() -> void:
	if _paused or _game_over or not _is_mobile_platform():
		return
	_clear_touch_ownership()
	_paused = true
	_pause_view.show_paused(_preferences.mode, _preferences.handedness)
	get_tree().paused = true

func _resume_game() -> void:
	if not _paused:
		return
	_clear_touch_ownership()
	get_tree().paused = false
	_paused = false
	_pause_view.hide_paused()
	_clear_touch_ownership()

func _restart_from_pause() -> void:
	get_tree().paused = false
	_paused = false
	_pause_view.hide_paused()
	_restart_run()

func _return_to_main_menu() -> void:
	get_tree().paused = false
	_paused = false
	_clear_touch_ownership()
	if main_menu_requester.is_valid():
		main_menu_requester.call()
		return
	get_tree().change_scene_to_file("res://scenes/boot.tscn")

func _build_scene() -> void:
	_sfx = SfxManagerScript.new()
	_sfx.name = "SFX"
	add_child(_sfx)
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = UiPaletteScript.BACKGROUND
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_battlefield = Battlefield.new()
	_battlefield.name = "Battlefield"
	_battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_battlefield)

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
	_magazine_view.visible = not _is_mobile_platform()
	_hud_view = HudView.new()
	_hud_view.name = "HUD"
	add_child(_hud_view)
	_settings_view = ControlSettingsView.new()
	_settings_view.name = "ControlSettings"
	add_child(_settings_view)
	_pause_view = PauseMenuScript.new()
	_pause_view.name = "PauseMenu"
	add_child(_pause_view)
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
	_settings_view.configure_layout(_safe_rect, viewport_size)
	_settings_view.gear_button.visible = not _is_mobile_platform() and not _settings_view.is_open()
	_pause_view.configure_layout(_safe_rect, viewport_size)
	_pause_view.pause_button.visible = _is_mobile_platform() and not _game_over
	_pause_view.set_haptics_enabled(_is_mobile_platform())
	_game_over_overlay.position = Vector2.ZERO
	_game_over_overlay.size = viewport_size
	_game_over_overlay.set_content_rect(_safe_rect)
	_chain_view.position = layout.chain_rect.position
	_chain_view.size = layout.chain_rect.size
	_chain_model.set_lane_width(_chain_view.size.x)
	_battlefield.position = layout.battlefield_rect.position
	_battlefield.size = layout.battlefield_rect.size
	_battlefield.configure_layout(layout.battlefield_rect.size)

	_magazine_view.position = layout.magazine_rect.position
	_magazine_view.size = layout.magazine_rect.size
	_shooter_view.position = Vector2.ZERO
	_shooter_view.size = viewport_size
	_shooter_view.configure_layout(layout.shooter_y, layout.track_left, layout.track_right, layout.shot_ceiling, _safe_rect.position.x, _safe_rect.end.x)
	_playfield_rect = layout.playfield_rect
	_touch_router.safe_rect = _safe_rect

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
