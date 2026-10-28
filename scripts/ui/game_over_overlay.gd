class_name GameOverOverlay
extends Control

signal restart_requested

# All terminal UI must draw ABOVE lane sprites, enemy/projectile effects,
# charge crystals and the settings layer (z_index=100), so the full-screen
# dimmer actually dims everything underneath and the button is unobstructed.
const TERMINAL_Z_INDEX := 200

var final_score := 0
var victory := false
var _restart_button: Button
var _content_rect := Rect2()

func _ready() -> void:
	z_as_relative = false
	z_index = TERMINAL_Z_INDEX
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_restart_button = Button.new()
	_restart_button.name = "RestartButton"
	_restart_button.text = "RESTART  [R]"
	_restart_button.custom_minimum_size = Vector2(220.0, 54.0)
	UiPalette.apply_button(_restart_button)
	_restart_button.pressed.connect(_on_restart_pressed)
	add_child(_restart_button)
	resized.connect(_layout_button)
	_layout_button()

func show_game_over(score_value: int) -> void:
	final_score = score_value
	victory = false
	visible = true
	queue_redraw()
	_restart_button.grab_focus()

func show_wave_cleared(score_value: int) -> void:
	final_score = score_value
	victory = true
	visible = true
	queue_redraw()
	_restart_button.grab_focus()

func hide_for_restart() -> void:
	visible = false
	final_score = 0
	victory = false
	_restart_button.release_focus()
	queue_redraw()

func set_content_rect(value: Rect2) -> void:
	_content_rect = value
	_layout_button()
	queue_redraw()

func title_text() -> String:
	return "WAVE CLEARED" if victory else "GAME OVER"

func subtitle_text() -> String:
	return "All enemies neutralized" if victory else "The lane was breached"

func _layout_button() -> void:
	if _restart_button == null:
		return
	var content := _content_rect if _content_rect.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	_restart_button.position = content.get_center() + Vector2(-110.0, 58.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiPalette.OVERLAY, true)
	var content := _content_rect if _content_rect.size.x > 0.0 else Rect2(Vector2.ZERO, size)
	var center_x := content.get_center().x
	var center_y := content.get_center().y
	var title := title_text()
	var title_color := UiPalette.SUCCESS if victory else UiPalette.FAILURE
	var subtitle := subtitle_text()
	draw_string(ThemeDB.fallback_font, Vector2(center_x - 220.0, center_y - 45.0), title, HORIZONTAL_ALIGNMENT_CENTER, 440.0, 46, title_color)
	draw_string(ThemeDB.fallback_font, Vector2(center_x - 180.0, center_y + 6.0), "FINAL SCORE  %06d" % final_score, HORIZONTAL_ALIGNMENT_CENTER, 360.0, 22, UiPalette.TEXT)
	draw_string(ThemeDB.fallback_font, Vector2(center_x - 180.0, center_y + 34.0), subtitle, HORIZONTAL_ALIGNMENT_CENTER, 360.0, 15, UiPalette.TEXT_SECONDARY)

func _on_restart_pressed() -> void:
	restart_requested.emit()
