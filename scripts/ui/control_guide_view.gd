class_name ControlGuideView
extends Control

signal choices_changed(mode: int, handedness: int)
signal close_requested

const REFERENCE_PATH := "res://assets/ui/controls_gameplay_reference.png"

var mode := TouchControlRouter.Mode.CLASSIC
var handedness := TouchControlRouter.Handedness.RIGHT
var title_label: Label
var classic_button: Button
var side_button: Button
var right_button: Button
var left_button: Button
var preview: TextureRect
var preview_stack: Control
var annotations: Control
var classic_swap_label: Label
var classic_shoot_label: Label
var close_button: Button
var content_row: HBoxContainer
var preview_frame: PanelContainer
var options_column: VBoxContainer
var handedness_row: HBoxContainer
var _safe_rect := Rect2()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_sync()

func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = UiPalette.OVERLAY
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.name = "GuidePanel"
	var panel_style := UiPalette.panel_style(UiPalette.BACKGROUND, UiPalette.WHITE, 2, 8)
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2.ZERO

	content_row = HBoxContainer.new()
	content_row.name = "TwoColumnLayout"
	content_row.add_theme_constant_override("separation", 24)
	panel.add_child(content_row)
	preview_frame = PanelContainer.new()
	preview_frame.name = "PreviewFrame"
	preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.PANEL, UiPalette.BORDER, 1, 2))
	content_row.add_child(preview_frame)
	preview_stack = Control.new()
	preview_stack.name = "PreviewStack"
	preview_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_frame.add_child(preview_stack)
	preview_stack.resized.connect(_layout_annotations)
	preview = TextureRect.new()
	preview.name = "GameplayReference"
	preview.texture = load(REFERENCE_PATH)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_stack.add_child(preview)
	annotations = GuideAnnotations.new()
	annotations.name = "GuideAnnotations"
	annotations.mouse_filter = Control.MOUSE_FILTER_IGNORE
	annotations.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_stack.add_child(annotations)
	classic_swap_label = _annotation_label("TAP WITH ANOTHER FINGER TO SWAP")
	classic_shoot_label = _annotation_label("RELEASE FINGERS TO SHOOT")
	preview_stack.add_child(classic_swap_label)
	preview_stack.add_child(classic_shoot_label)

	options_column = VBoxContainer.new()
	options_column.name = "OptionsColumn"
	options_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_column.add_theme_constant_override("separation", 12)
	content_row.add_child(options_column)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "CONTROLS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size.y = 42.0
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", UiPalette.TEXT)
	options_column.add_child(title_label)
	var modes := HBoxContainer.new()
	modes.name = "SchemeChoices"
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 12)
	options_column.add_child(modes)
	classic_button = _choice_button("CLASSIC")
	side_button = _choice_button("SIDE")
	classic_button.pressed.connect(func(): select_mode(TouchControlRouter.Mode.CLASSIC))
	side_button.pressed.connect(func(): select_mode(TouchControlRouter.Mode.SIDE))
	modes.add_child(classic_button)
	modes.add_child(side_button)
	handedness_row = HBoxContainer.new()
	handedness_row.name = "Handedness"
	handedness_row.alignment = BoxContainer.ALIGNMENT_CENTER
	handedness_row.add_theme_constant_override("separation", 12)
	options_column.add_child(handedness_row)
	right_button = _small_button("RIGHT")
	left_button = _small_button("LEFT")
	right_button.pressed.connect(func(): select_handedness(TouchControlRouter.Handedness.RIGHT))
	left_button.pressed.connect(func(): select_handedness(TouchControlRouter.Handedness.LEFT))
	handedness_row.add_child(right_button)
	handedness_row.add_child(left_button)
	var spacer := Control.new()
	spacer.name = "OptionsSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_column.add_child(spacer)
	close_button = _small_button("BACK")
	close_button.name = "Back"
	close_button.pressed.connect(func(): close_requested.emit())
	options_column.add_child(close_button)
	resized.connect(_layout)
	_layout()

func _choice_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(150.0, 76.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	return button

func _small_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(140.0, 72.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 20)
	UiPalette.apply_button(button)
	return button

func _annotation_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", UiPalette.WHITE)
	label.add_theme_color_override("font_outline_color", UiPalette.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func configure(mode_value: int, handedness_value: int) -> void:
	mode = clampi(mode_value, TouchControlRouter.Mode.CLASSIC, TouchControlRouter.Mode.SIDE)
	handedness = clampi(handedness_value, TouchControlRouter.Handedness.RIGHT, TouchControlRouter.Handedness.LEFT)
	_sync()

func configure_safe_rect(value: Rect2) -> void:
	_safe_rect = value
	_layout()

func select_mode(value: int) -> void:
	mode = value
	_sync()
	choices_changed.emit(mode, handedness)

func select_handedness(value: int) -> void:
	handedness = value
	_sync()
	choices_changed.emit(mode, handedness)

func _sync() -> void:
	if classic_button == null:
		return
	_style_scheme(classic_button, mode == TouchControlRouter.Mode.CLASSIC)
	_style_scheme(side_button, mode == TouchControlRouter.Mode.SIDE)
	handedness_row.visible = mode == TouchControlRouter.Mode.SIDE
	UiPalette.apply_button(right_button, handedness == TouchControlRouter.Handedness.RIGHT)
	UiPalette.apply_button(left_button, handedness == TouchControlRouter.Handedness.LEFT)
	classic_swap_label.visible = mode == TouchControlRouter.Mode.CLASSIC
	classic_shoot_label.visible = mode == TouchControlRouter.Mode.CLASSIC
	annotations.set("mode", mode)
	annotations.set("handedness", handedness)
	annotations.queue_redraw()
	_layout_annotations()

func _style_scheme(button: Button, selected: bool) -> void:
	button.add_theme_color_override("font_color", UiPalette.TEXT)
	button.add_theme_color_override("font_hover_color", UiPalette.WHITE)
	button.add_theme_color_override("font_focus_color", UiPalette.WHITE)
	var empty := StyleBoxEmpty.new()
	if not selected:
		for state in ["normal", "pressed", "hover", "focus"]:
			button.add_theme_stylebox_override(state, empty)
		return
	var card := UiPalette.panel_style(UiPalette.SURFACE_RAISED, UiPalette.WHITE, 2, 14)
	card.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	card.shadow_size = 7
	card.shadow_offset = Vector2(0.0, 4.0)
	for state in ["normal", "pressed", "hover", "focus"]:
		button.add_theme_stylebox_override(state, card)

func _layout() -> void:
	if not is_instance_valid(title_label):
		return
	var panel := get_node("GuidePanel") as PanelContainer
	var margin := 12.0
	var bounds := _safe_rect if _safe_rect.size.x > 0.0 and _safe_rect.size.y > 0.0 else Rect2(Vector2.ZERO, size)
	panel.size = Vector2(maxf(0.0, minf(1400.0, bounds.size.x - margin * 2.0)), maxf(0.0, minf(900.0, bounds.size.y - margin * 2.0)))
	panel.position = bounds.position + (bounds.size - panel.size) * 0.5
	var inner_width := maxf(0.0, panel.size.x - 40.0)
	var options_width := clampf(inner_width * 0.40, 340.0, 520.0)
	preview_frame.custom_minimum_size = Vector2(280.0, 0.0)
	options_column.custom_minimum_size = Vector2(options_width, 0.0)
	_layout_annotations()

func _layout_annotations() -> void:
	if not is_instance_valid(classic_swap_label):
		return
	var container_size := preview.size
	var texture_size := Vector2(preview.texture.get_size()) if preview.texture != null else container_size
	if container_size.x <= 0.0 or container_size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var scale_value := minf(container_size.x / texture_size.x, container_size.y / texture_size.y)
	var content_size := texture_size * scale_value
	var content_position := (container_size - content_size) * 0.5
	annotations.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	annotations.position = content_position
	annotations.size = content_size
	classic_swap_label.position = content_position + Vector2(content_size.x * 0.02, content_size.y * 0.12)
	classic_swap_label.size = Vector2(content_size.x * 0.43, 48.0)
	classic_shoot_label.position = content_position + Vector2(content_size.x * 0.70, content_size.y * 0.62)
	classic_shoot_label.size = Vector2(content_size.x * 0.28, 52.0)

func side_regions() -> Dictionary:
	var region_size := annotations.size
	if region_size.x <= 0.0 or region_size.y <= 0.0:
		region_size = preview.size
	if region_size.x <= 0.0 or region_size.y <= 0.0:
		region_size = Vector2(720.0, 360.0)
	return GuideAnnotations.side_regions(Rect2(Vector2.ZERO, region_size), handedness)


class GuideAnnotations extends Control:
	var mode := TouchControlRouter.Mode.CLASSIC
	var handedness := TouchControlRouter.Handedness.RIGHT

	static func side_regions(rect: Rect2, hand: int) -> Dictionary:
		var quarter := rect.size.x * 0.25
		var action_x := rect.position.x if hand == TouchControlRouter.Handedness.RIGHT else rect.end.x - quarter
		var slide_x := rect.end.x - quarter if hand == TouchControlRouter.Handedness.RIGHT else rect.position.x
		return {"swap": Rect2(action_x, rect.position.y, quarter, rect.size.y * 0.5), "shoot": Rect2(action_x, rect.position.y + rect.size.y * 0.5, quarter, rect.size.y * 0.5), "slide": Rect2(slide_x, rect.position.y, quarter, rect.size.y)}

	func _draw() -> void:
		if mode == TouchControlRouter.Mode.SIDE:
			var regions := side_regions(Rect2(Vector2.ZERO, size), handedness)
			for key in ["swap", "shoot", "slide"]:
				var region: Rect2 = regions[key]
				draw_rect(region.grow(-5.0), Color(0.0, 0.0, 0.0, 0.24), true)
				draw_rect(region.grow(-5.0), UiPalette.WHITE, false, 3.0)
				draw_string(ThemeDB.fallback_font, region.get_center() + Vector2(-region.size.x * 0.28, 6.0), str(key).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, region.size.x * 0.56, 18, UiPalette.WHITE)
			return
		_draw_finger(Vector2(size.x * 0.34, size.y * 0.52), -0.18)
		_draw_finger(Vector2(size.x * 0.62, size.y * 0.83), 0.08)
		draw_line(Vector2(size.x * 0.27, size.y * 0.31), Vector2(size.x * 0.34, size.y * 0.46), UiPalette.WHITE, 2.0)
		draw_line(Vector2(size.x * 0.72, size.y * 0.80), Vector2(size.x * 0.64, size.y * 0.78), UiPalette.WHITE, 2.0)

	func _draw_finger(tip: Vector2, rotation_value: float) -> void:
		var transform_value := Transform2D(rotation_value, tip)
		var body := PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(17, 82), Vector2(-17, 82), Vector2(-13, 0)])
		var transformed := PackedVector2Array()
		for point in body:
			transformed.append(transform_value * point)
		draw_colored_polygon(transformed, Color(0.05, 0.05, 0.05, 0.88))
		draw_polyline(transformed, UiPalette.WHITE, 3.0, true)
		draw_arc(tip, 13.0, PI, TAU, 24, UiPalette.WHITE, 3.0)
		draw_arc(tip, 24.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.72), 2.0)
