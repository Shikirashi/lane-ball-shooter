extends Node

const MainScene := preload("res://scenes/main.tscn")
const LayoutCalculator := preload("res://scripts/responsive_layout.gd")
const UiPaletteScript := preload("res://scripts/ui/ui_palette.gd")
const PreferencesScript := preload("res://scripts/input/control_preferences.gd")
const ControlGuideScript := preload("res://scripts/ui/control_guide_view.gd")

const TITLE_TEXT := "LANE BALL SHOOTER"
const START_TEXT := "START GAME"
const FULLSCREEN_PROMPT := "Play in fullscreen?"

# Test hooks are assigned before this node enters the tree. -1 uses real platform
# detection; 0/1 force the native/Web lifecycle without spoofing OS features.
var forced_web_mode := -1
var forced_android_mode := -1
var fullscreen_requester: Callable
var gameplay_starter: Callable

var gameplay_start_count := 0
var fullscreen_request_count := 0

var _menu_root: Control
var _background: ColorRect
var _title: Label
var _start_button: Button
var _dialog_layer: ColorRect
var _dialog_panel: PanelContainer
var _prompt: Label
var _yes_button: Button
var _no_button: Button
var _choice_locked := false
var _native_menu := false
var _play_button: Button
var _controls_button: Button
var _control_guide: ControlGuideView
var _preferences := PreferencesScript.new()

func _ready() -> void:
	if should_show_android_menu():
		_build_native_menu()
		get_viewport().size_changed.connect(_layout)
		_layout()
	elif should_show_web_menu():
		_build_menu()
		get_viewport().size_changed.connect(_layout)
		_layout()
	else:
		_start_game_once(true)

static func platform_uses_menu(web_feature: bool, android_feature: bool) -> bool:
	return web_feature and not android_feature

static func platform_uses_android_menu(android_feature: bool) -> bool:
	return android_feature

func should_show_android_menu() -> bool:
	if forced_android_mode >= 0:
		return forced_android_mode == 1
	return platform_uses_android_menu(OS.has_feature("android"))

func should_show_web_menu() -> bool:
	if forced_web_mode >= 0:
		return forced_web_mode == 1
	if "--web-menu-preview" in OS.get_cmdline_user_args():
		return true
	return platform_uses_menu(OS.has_feature("web"), OS.has_feature("android"))

func _build_native_menu() -> void:
	_native_menu = true
	_preferences.load_settings()
	_menu_root = Control.new()
	_menu_root.name = "AndroidMainMenu"
	_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu_root)
	_background = ColorRect.new()
	_background.name = "DarkBackdrop"
	_background.color = UiPaletteScript.BACKGROUND
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(_background)
	_title = Label.new()
	_title.name = "Title"
	_title.text = TITLE_TEXT
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiPaletteScript.TEXT)
	_menu_root.add_child(_title)
	_play_button = _make_button("PLAY", "Play")
	_controls_button = _make_button("CONTROLS", "Controls")
	_play_button.pressed.connect(func(): _start_game_once())
	_controls_button.pressed.connect(_open_native_controls)
	_menu_root.add_child(_play_button)
	_menu_root.add_child(_controls_button)
	_control_guide = ControlGuideScript.new()
	_control_guide.name = "AndroidControlGuide"
	_control_guide.visible = false
	_control_guide.choices_changed.connect(_on_native_choices_changed)
	_control_guide.close_requested.connect(_close_native_controls)
	_menu_root.add_child(_control_guide)
	_play_button.grab_focus()

func _open_native_controls() -> void:
	_control_guide.configure(_preferences.mode, _preferences.handedness)
	_control_guide.visible = true
	_control_guide.close_button.grab_focus()

func _close_native_controls() -> void:
	_control_guide.visible = false
	_controls_button.grab_focus()

func _on_native_choices_changed(mode: int, handedness: int) -> void:
	_preferences.mode = mode
	_preferences.handedness = handedness
	_preferences.save_settings()

func _unhandled_input(event: InputEvent) -> void:
	if not _native_menu or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event is InputEventKey and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK) and _control_guide.visible:
		_close_native_controls()
		get_viewport().set_input_as_handled()

func _build_menu() -> void:
	_menu_root = Control.new()
	_menu_root.name = "WebMainMenu"
	_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu_root)

	_background = ColorRect.new()
	_background.name = "DarkBackdrop"
	_background.color = UiPaletteScript.BACKGROUND
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(_background)

	_title = Label.new()
	_title.name = "Title"
	_title.text = TITLE_TEXT
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", UiPaletteScript.TEXT)
	_menu_root.add_child(_title)

	_start_button = _make_button(START_TEXT, "StartGame")
	_start_button.pressed.connect(_on_start_pressed)
	_menu_root.add_child(_start_button)

	_dialog_layer = ColorRect.new()
	_dialog_layer.name = "FullscreenDialogLayer"
	_dialog_layer.color = UiPaletteScript.OVERLAY
	_dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialog_layer.visible = false
	_menu_root.add_child(_dialog_layer)

	_dialog_panel = PanelContainer.new()
	_dialog_panel.name = "FullscreenDialog"
	_dialog_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := UiPaletteScript.panel_style(UiPaletteScript.PANEL, UiPaletteScript.WHITE, 2, 4)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 24.0
	panel_style.content_margin_bottom = 24.0
	_dialog_panel.add_theme_stylebox_override("panel", panel_style)
	_dialog_layer.add_child(_dialog_panel)

	var dialog_column := VBoxContainer.new()
	dialog_column.name = "DialogContent"
	dialog_column.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_column.add_theme_constant_override("separation", 20)
	_dialog_panel.add_child(dialog_column)

	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.text = FULLSCREEN_PROMPT
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_color_override("font_color", UiPaletteScript.TEXT)
	dialog_column.add_child(_prompt)

	var choices := HBoxContainer.new()
	choices.name = "Choices"
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 18)
	dialog_column.add_child(choices)

	_yes_button = _make_button("YES", "Yes")
	_no_button = _make_button("NO", "No")
	_yes_button.custom_minimum_size = Vector2(132.0, 64.0)
	_no_button.custom_minimum_size = Vector2(132.0, 64.0)
	_yes_button.pressed.connect(_on_yes_pressed)
	_no_button.pressed.connect(_on_no_pressed)
	choices.add_child(_yes_button)
	choices.add_child(_no_button)
	_start_button.grab_focus()

func _make_button(text_value: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(280.0, 68.0)
	button.add_theme_font_size_override("font_size", 23)
	UiPaletteScript.apply_button(button)
	return button

func _on_start_pressed() -> void:
	if _choice_locked or _dialog_layer.visible:
		return
	_dialog_layer.visible = true
	_start_button.disabled = true
	_yes_button.grab_focus()

func _on_yes_pressed() -> void:
	if _choice_locked:
		return
	_choice_locked = true
	_yes_button.disabled = true
	_no_button.disabled = true
	_request_fullscreen_now()
	_start_game_once()

func _on_no_pressed() -> void:
	if _choice_locked:
		return
	_choice_locked = true
	_yes_button.disabled = true
	_no_button.disabled = true
	_start_game_once()

# This synchronous call is deliberately made directly by _on_yes_pressed before
# scene transition. Web user activation would be lost after an await/defer/timer.
func _request_fullscreen_now() -> void:
	fullscreen_request_count += 1
	if fullscreen_requester.is_valid():
		fullscreen_requester.call()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _start_game_once(defer_scene_transition := false) -> void:
	if gameplay_start_count > 0:
		return
	gameplay_start_count = 1
	if _menu_root != null:
		_menu_root.visible = false
	if gameplay_starter.is_valid():
		gameplay_starter.call()
		return
	if defer_scene_transition:
		get_tree().call_deferred("change_scene_to_packed", MainScene)
	else:
		get_tree().change_scene_to_packed(MainScene)

func _layout() -> void:
	if _menu_root == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return
	_apply_layout(viewport_size, _resolve_safe_rect(viewport_size))

func _apply_layout(viewport_size: Vector2, requested_safe_rect := Rect2()) -> void:
	var safe_rect: Rect2 = LayoutCalculator.calculate(viewport_size, requested_safe_rect).safe_rect
	_menu_root.position = Vector2.ZERO
	_menu_root.size = viewport_size
	_background.position = Vector2.ZERO
	_background.size = viewport_size
	if _native_menu:
		var native_title_width := minf(800.0, safe_rect.size.x - 40.0)
		_title.position = Vector2(safe_rect.get_center().x - native_title_width * 0.5, safe_rect.position.y + safe_rect.size.y * 0.18)
		_title.size = Vector2(native_title_width, 100.0)
		_title.add_theme_font_size_override("font_size", roundi(clampf(safe_rect.size.y * 0.075, 34.0, 58.0)))
		var button_size := Vector2(clampf(safe_rect.size.x * 0.28, 260.0, 380.0), 64.0)
		_play_button.size = button_size
		_controls_button.size = button_size
		_play_button.position = Vector2(safe_rect.get_center().x - button_size.x * 0.5, safe_rect.position.y + safe_rect.size.y * 0.49)
		_controls_button.position = _play_button.position + Vector2(0.0, 78.0)
		_control_guide.position = Vector2.ZERO
		_control_guide.size = viewport_size
		_control_guide.configure_safe_rect(safe_rect)
		return
	_dialog_layer.position = Vector2.ZERO
	_dialog_layer.size = viewport_size

	var title_width := minf(760.0, safe_rect.size.x - 32.0)
	var title_height := clampf(safe_rect.size.y * 0.16, 64.0, 126.0)
	_title.position = Vector2(safe_rect.get_center().x - title_width * 0.5, safe_rect.position.y + safe_rect.size.y * 0.22)
	_title.size = Vector2(title_width, title_height)
	_title.add_theme_font_size_override("font_size", roundi(clampf(safe_rect.size.y * 0.075, 30.0, 64.0)))
	_start_button.size = Vector2(clampf(safe_rect.size.x * 0.32, 260.0, 380.0), clampf(safe_rect.size.y * 0.105, 60.0, 78.0))
	_start_button.position = Vector2(safe_rect.get_center().x - _start_button.size.x * 0.5, safe_rect.position.y + safe_rect.size.y * 0.58)

	_dialog_panel.size = Vector2(minf(480.0, safe_rect.size.x - 32.0), minf(230.0, safe_rect.size.y - 24.0))
	_dialog_panel.position = safe_rect.get_center() - _dialog_panel.size * 0.5

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
