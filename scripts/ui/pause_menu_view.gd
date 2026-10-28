class_name PauseMenuView
extends Control

signal resume_requested
signal controls_requested
signal choices_changed(mode: int, handedness: int)
signal restart_confirmed
signal main_menu_confirmed
signal pause_requested
signal test_vibration_requested

var pause_button: Button
var overlay: ColorRect
var menu_panel: PanelContainer
var confirm_panel: PanelContainer
var confirm_label: Label
var guide: ControlGuideView
var _confirm_action := &""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_as_relative = false
	z_index = 180
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "Ⅱ"
	pause_button.tooltip_text = "Pause"
	pause_button.custom_minimum_size = Vector2(52.0, 52.0)
	UiPalette.apply_button(pause_button)
	pause_button.pressed.connect(func(): pause_requested.emit())
	add_child(pause_button)
	overlay = ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.color = UiPalette.OVERLAY
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	menu_panel = _panel("PAUSED", ["RESUME", "CONTROLS", "RESTART", "MAIN MENU"])
	overlay.add_child(menu_panel)
	var buttons := menu_panel.find_children("*", "Button", true, false)
	(buttons[0] as Button).pressed.connect(func(): resume_requested.emit())
	(buttons[1] as Button).pressed.connect(_open_controls)
	(buttons[2] as Button).pressed.connect(func(): _show_confirm(&"restart"))
	(buttons[3] as Button).pressed.connect(func(): _show_confirm(&"main_menu"))
	confirm_panel = _panel("", ["CANCEL", "CONFIRM"])
	confirm_panel.visible = false
	overlay.add_child(confirm_panel)
	confirm_label = confirm_panel.find_child("Title", true, false)
	var confirm_buttons := confirm_panel.find_children("*", "Button", true, false)
	(confirm_buttons[0] as Button).pressed.connect(_cancel_confirm)
	(confirm_buttons[1] as Button).pressed.connect(_confirm)
	guide = ControlGuideView.new()
	guide.name = "PauseControlGuide"
	guide.visible = false
	guide.choices_changed.connect(func(mode: int, hand: int): choices_changed.emit(mode, hand))
	guide.close_requested.connect(_close_controls)
	guide.test_vibration_requested.connect(func(): test_vibration_requested.emit())
	overlay.add_child(guide)

func _panel(title_text: String, labels: Array[String]) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.PANEL, UiPalette.WHITE, 2, 8))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiPalette.TEXT)
	column.add_child(title)
	for label in labels:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(260.0, 54.0)
		UiPalette.apply_button(button)
		column.add_child(button)
	return panel

func configure_layout(safe_rect: Rect2, viewport_size: Vector2) -> void:
	position = Vector2.ZERO
	size = viewport_size
	pause_button.position = Vector2(safe_rect.end.x - 176.0, safe_rect.position.y + 7.0)
	pause_button.size = Vector2(52.0, 52.0)
	overlay.position = Vector2.ZERO
	overlay.size = viewport_size
	menu_panel.size = Vector2(340.0, 350.0)
	menu_panel.position = safe_rect.get_center() - menu_panel.size * 0.5
	confirm_panel.size = Vector2(430.0, 190.0)
	confirm_panel.position = safe_rect.get_center() - confirm_panel.size * 0.5
	guide.position = Vector2.ZERO
	guide.size = viewport_size
	guide.configure_safe_rect(safe_rect)

func show_paused(mode: int, hand: int) -> void:
	overlay.visible = true
	menu_panel.visible = true
	confirm_panel.visible = false
	guide.visible = false
	guide.configure(mode, hand)
	mouse_filter = Control.MOUSE_FILTER_STOP

func hide_paused() -> void:
	overlay.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_action = &""

func is_open() -> bool:
	return overlay.visible

func set_haptics_enabled(value: bool) -> void:
	if is_instance_valid(guide):
		guide.set_haptics_enabled(value)

func show_vibration_request_sent(requested: bool) -> void:
	if is_instance_valid(guide):
		guide.show_vibration_request_sent(requested)

func _open_controls() -> void:
	menu_panel.visible = false
	guide.visible = true
	controls_requested.emit()

func _close_controls() -> void:
	guide.visible = false
	menu_panel.visible = true

func _show_confirm(action: StringName) -> void:
	_confirm_action = action
	menu_panel.visible = false
	confirm_panel.visible = true
	confirm_label.text = "RESTART THIS RUN?" if action == &"restart" else "RETURN TO MAIN MENU?"

func _cancel_confirm() -> void:
	_confirm_action = &""
	confirm_panel.visible = false
	menu_panel.visible = true

func _confirm() -> void:
	var action := _confirm_action
	_cancel_confirm()
	if action == &"restart":
		restart_confirmed.emit()
	elif action == &"main_menu":
		main_menu_confirmed.emit()

func handle_back() -> bool:
	if not overlay.visible:
		return false
	if confirm_panel.visible:
		_cancel_confirm()
	elif guide.visible:
		_close_controls()
	else:
		resume_requested.emit()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		if handle_back():
			get_viewport().set_input_as_handled()
