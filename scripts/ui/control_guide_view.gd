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
var annotations: Control
var classic_swap_label: Label
var classic_shoot_label: Label
var close_button: Button
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
	panel.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.BACKGROUND, UiPalette.WHITE, 2, 8))
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2.ZERO
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	title_label = Label.new()
	title_label.text = "CONTROLS"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", UiPalette.TEXT)
	column.add_child(title_label)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 18)
	column.add_child(modes)
	classic_button = _choice_button("CLASSIC")
	side_button = _choice_button("SIDE")
	classic_button.pressed.connect(func(): select_mode(TouchControlRouter.Mode.CLASSIC))
	side_button.pressed.connect(func(): select_mode(TouchControlRouter.Mode.SIDE))
	modes.add_child(classic_button)
	modes.add_child(side_button)
	var preview_frame := PanelContainer.new()
	preview_frame.name = "PreviewFrame"
	preview_frame.custom_minimum_size = Vector2(720.0, 360.0)
	preview_frame.add_theme_stylebox_override("panel", UiPalette.panel_style(UiPalette.PANEL, UiPalette.BORDER, 1, 2))
	column.add_child(preview_frame)
	var preview_stack := Control.new()
	preview_stack.custom_minimum_size = Vector2(720.0, 360.0)
	preview_frame.add_child(preview_stack)
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
	annotations.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview_stack.add_child(annotations)
	classic_swap_label = _annotation_label("TAP WITH ANOTHER FINGER TO SWAP")
	classic_shoot_label = _annotation_label("RELEASE FINGERS TO SHOOT")
	preview_stack.add_child(classic_swap_label)
	preview_stack.add_child(classic_shoot_label)
	var hands := HBoxContainer.new()
	hands.name = "Handedness"
	hands.alignment = BoxContainer.ALIGNMENT_CENTER
	hands.add_theme_constant_override("separation", 12)
	column.add_child(hands)
	right_button = _small_button("RIGHT")
	left_button = _small_button("LEFT")
	right_button.pressed.connect(func(): select_handedness(TouchControlRouter.Handedness.RIGHT))
	left_button.pressed.connect(func(): select_handedness(TouchControlRouter.Handedness.LEFT))
	hands.add_child(right_button)
	hands.add_child(left_button)
	close_button = _small_button("BACK")
	close_button.pressed.connect(func(): close_requested.emit())
	column.add_child(close_button)
	resized.connect(_layout)
	_layout()

func _choice_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(180.0, 54.0)
	button.add_theme_font_size_override("font_size", 20)
	return button

func _small_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(126.0, 46.0)
	UiPalette.apply_button(button)
	return button

func _annotation_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
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
	right_button.visible = mode == TouchControlRouter.Mode.SIDE
	left_button.visible = mode == TouchControlRouter.Mode.SIDE
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
	var margin := 18.0
	var bounds := _safe_rect if _safe_rect.size.x > 0.0 and _safe_rect.size.y > 0.0 else Rect2(Vector2.ZERO, size)
	panel.size = Vector2(minf(900.0, bounds.size.x - margin * 2.0), minf(680.0, bounds.size.y - margin * 2.0))
	panel.position = bounds.position + (bounds.size - panel.size) * 0.5
	var preview_height := clampf(panel.size.y - 200.0, 220.0, 430.0)
	var frame := panel.find_child("PreviewFrame", true, false) as Control
	frame.custom_minimum_size = Vector2(0.0, preview_height)
	_layout_annotations()

func _layout_annotations() -> void:
	if not is_instance_valid(classic_swap_label):
		return
	var container_size := preview.size
	var texture_size := Vector2(preview.texture.get_size()) if preview.texture != null else container_size
	var scale_value := minf(container_size.x / texture_size.x, container_size.y / texture_size.y)
	var content_size := texture_size * scale_value
	var content_position := (container_size - content_size) * 0.5
	annotations.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	annotations.position = content_position
	annotations.size = content_size
	classic_swap_label.position = content_position + Vector2(content_size.x * 0.05, content_size.y * 0.22)
	classic_swap_label.size = Vector2(content_size.x * 0.42, 32.0)
	classic_shoot_label.position = content_position + Vector2(content_size.x * 0.48, content_size.y * 0.80)
	classic_shoot_label.size = Vector2(content_size.x * 0.47, 32.0)

func side_regions() -> Dictionary:
	return GuideAnnotations.side_regions(Rect2(Vector2.ZERO, annotations.size), handedness)


class GuideAnnotations extends Control:
	var mode := TouchControlRouter.Mode.CLASSIC
	var handedness := TouchControlRouter.Handedness.RIGHT

	static func side_regions(rect: Rect2, hand: int) -> Dictionary:
		var quarter := rect.size.x * 0.25
		var action_x := rect.position.x if hand == TouchControlRouter.Handedness.RIGHT else rect.end.x - quarter
		var slide_x := rect.end.x - quarter if hand == TouchControlRouter.Handedness.RIGHT else rect.position.x
		return {
			"swap": Rect2(action_x, rect.position.y, quarter, rect.size.y * 0.5),
			"shoot": Rect2(action_x, rect.position.y + rect.size.y * 0.5, quarter, rect.size.y * 0.5),
			"slide": Rect2(slide_x, rect.position.y, quarter, rect.size.y),
		}

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
