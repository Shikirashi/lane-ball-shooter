class_name ControlSettingsView
extends Control

signal choices_changed(mode: int, handedness: int)
signal visibility_changed_by_user(open: bool)

var gear_button: Button
var panel: PanelContainer
var classic_button: Button
var side_button: Button
var right_button: Button
var left_button: Button
var close_button: Button
var mode := TouchControlRouter.Mode.CLASSIC
var handedness := TouchControlRouter.Handedness.RIGHT

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	gear_button = Button.new()
	gear_button.name = "SettingsGear"
	gear_button.text = "⚙"
	gear_button.tooltip_text = "Control settings"
	gear_button.custom_minimum_size = Vector2(52.0, 52.0)
	gear_button.mouse_filter = Control.MOUSE_FILTER_STOP
	gear_button.add_theme_font_size_override("font_size", 24)
	UiPalette.apply_button(gear_button)
	gear_button.pressed.connect(_open)
	add_child(gear_button)
	panel = PanelContainer.new()
	panel.name = "ControlSettingsPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	panel.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.PANEL, UiPalette.WHITE, 2, 4))
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "TOUCH CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UiPalette.TEXT)
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)
	var mode_row := HBoxContainer.new()
	column.add_child(mode_row)
	classic_button = _button("CLASSIC")
	side_button = _button("SIDE")
	mode_row.add_child(classic_button)
	mode_row.add_child(side_button)
	classic_button.pressed.connect(func(): _select_mode(TouchControlRouter.Mode.CLASSIC))
	side_button.pressed.connect(func(): _select_mode(TouchControlRouter.Mode.SIDE))
	var hand_row := HBoxContainer.new()
	column.add_child(hand_row)
	right_button = _button("RIGHT-HANDED")
	left_button = _button("LEFT-HANDED")
	hand_row.add_child(right_button)
	hand_row.add_child(left_button)
	right_button.pressed.connect(func(): _select_hand(TouchControlRouter.Handedness.RIGHT))
	left_button.pressed.connect(func(): _select_hand(TouchControlRouter.Handedness.LEFT))
	close_button = _button("CLOSE")
	close_button.pressed.connect(_close)
	column.add_child(close_button)
	_sync_buttons()

func _button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(122.0, 48.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	UiPalette.apply_button(button)
	return button

func configure_layout(safe_rect: Rect2, viewport_size := Vector2.ZERO) -> void:
	position = Vector2.ZERO
	size = viewport_size if viewport_size.x > 0.0 and viewport_size.y > 0.0 else safe_rect.end
	gear_button.position = Vector2(safe_rect.end.x - 116.0, safe_rect.position.y + 7.0)
	gear_button.size = Vector2(52.0, 52.0)
	panel.size = Vector2(minf(330.0, safe_rect.size.x - 24.0), minf(240.0, safe_rect.size.y - 24.0))
	panel.position = safe_rect.get_center() - panel.size * 0.5

func set_choices(mode_value: int, handedness_value: int) -> void:
	mode = mode_value
	handedness = handedness_value
	_sync_buttons()

func is_open() -> bool:
	return panel != null and panel.visible

func _open() -> void:
	panel.visible = true
	gear_button.visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed_by_user.emit(true)
	close_button.grab_focus()

func _close() -> void:
	panel.visible = false
	gear_button.visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visibility_changed_by_user.emit(false)

func _select_mode(value: int) -> void:
	mode = value
	_sync_buttons()
	choices_changed.emit(mode, handedness)

func _select_hand(value: int) -> void:
	handedness = value
	_sync_buttons()
	choices_changed.emit(mode, handedness)

func _sync_buttons() -> void:
	if classic_button == null:
		return
	classic_button.disabled = mode == TouchControlRouter.Mode.CLASSIC
	side_button.disabled = mode == TouchControlRouter.Mode.SIDE
	right_button.disabled = handedness == TouchControlRouter.Handedness.RIGHT
	left_button.disabled = handedness == TouchControlRouter.Handedness.LEFT
	UiPalette.apply_button(classic_button, classic_button.disabled)
	UiPalette.apply_button(side_button, side_button.disabled)
	UiPalette.apply_button(right_button, right_button.disabled)
	UiPalette.apply_button(left_button, left_button.disabled)
	UiPalette.apply_button(close_button)
