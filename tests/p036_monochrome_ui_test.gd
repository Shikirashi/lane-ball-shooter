extends SceneTree

const BootScript := preload("res://scripts/boot.gd")
const TEAM_COLORS := [Color("ef5b5b"), Color("3677e8"), Color("f3cf4b"), Color("37c45a")]
const PREVIEWS := [
	["res://assets/previews/p036_gameplay_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p036_gameplay_1600x720.png", Vector2i(1600, 720)],
	["res://assets/previews/p036_web_start_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p036_web_fullscreen_prompt_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p036_settings_1600x720.png", Vector2i(1600, 720)],
	["res://assets/previews/p036_wave_cleared_1280x720.png", Vector2i(1280, 720)],
	["res://assets/previews/p036_game_over_1280x720.png", Vector2i(1280, 720)],
]

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	_test_palette_and_semantics()
	await _test_live_surfaces()
	await _test_web_flow()
	_test_source_scope_and_renderer_evidence()
	_finish()

func _test_palette_and_semantics() -> void:
	_check(TeamData.COLORS == TEAM_COLORS, "authoritative four-team color map remains unchanged")
	var neutrals := [UiPalette.BACKGROUND, UiPalette.PANEL, UiPalette.SURFACE, UiPalette.SURFACE_RAISED, UiPalette.SEPARATOR, UiPalette.BORDER, UiPalette.TEXT, UiPalette.TEXT_SECONDARY, UiPalette.TEXT_DISABLED, UiPalette.WHITE, UiPalette.BLACK]
	for color in neutrals:
		_check(is_equal_approx(color.r, color.g) and is_equal_approx(color.g, color.b), "neutral palette entry %s has equal RGB channels" % color)
	_check(UiPalette.BACKGROUND.to_html(false) == "050505" and UiPalette.TEXT.to_html(false) == "f4f4f4", "palette anchors are the approved near-black and off-white")
	_check(_contrast(UiPalette.TEXT, UiPalette.BACKGROUND) >= 7.0 and _contrast(UiPalette.TEXT_SECONDARY, UiPalette.BACKGROUND) >= 4.5, "primary and secondary text exceed accessible contrast on the field")
	_check(not _is_gray(UiPalette.FEVER) and not _is_gray(UiPalette.COMBO), "FEVER and COMBO retain intentional warm semantic accents")

func _test_live_surfaces() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check((main.get("_background") as ColorRect).color == UiPalette.BACKGROUND, "live Main field uses palette black")
	var hud: HudView = main.get("_hud_view")
	var hud_style: StyleBoxFlat = hud.call("_panel_style")
	_check(_is_gray(hud_style.bg_color) and _is_gray(hud_style.border_color), "HUD neutral panel and border are grayscale")
	hud.set_progress(300, 4, 3, true, 0.8)
	hud_style = hud.call("_panel_style")
	_check(hud_style.border_color == UiPalette.FEVER, "active FEVER remains a meaningful accent")
	var chain_style: StyleBoxFlat = (main.get("_chain_view") as BallChainView).call("_panel_style")
	_check(chain_style.bg_color == UiPalette.PANEL and chain_style.border_color == UiPalette.BORDER, "conveyor frame uses shared neutral surfaces")
	var settings: ControlSettingsView = main.get("_settings_view")
	settings.call("_open")
	_check(settings.is_open() and settings.panel.visible and not settings.gear_button.visible, "control settings opens without changing interaction behavior")
	settings.call("_select_mode", TouchControlRouter.Mode.SIDE)
	_check(settings.side_button.disabled and not settings.classic_button.disabled, "selected control mode remains explicit")
	var selected: StyleBoxFlat = settings.side_button.get_theme_stylebox("disabled")
	_check(selected.border_color == UiPalette.WHITE and _is_gray(selected.bg_color), "selected settings choice has a crisp white neutral border")
	var overlay: GameOverOverlay = main.get("_game_over_overlay")
	_check(overlay.z_index == GameOverOverlay.TERMINAL_Z_INDEX and overlay.z_index == 200, "terminal overlay remains absolute z=200")
	overlay.show_game_over(100)
	_check(overlay.visible and overlay.get_node("RestartButton").get_theme_stylebox("normal").border_color == UiPalette.BORDER, "end screen is visible with a neutral Restart control")
	main.queue_free()
	await process_frame

func _test_web_flow() -> void:
	var trace: Array[String] = []
	var boot := BootScript.new()
	boot.forced_web_mode = 1
	boot.fullscreen_requester = func() -> void: trace.append("fullscreen")
	boot.gameplay_starter = func() -> void: trace.append("game")
	root.add_child(boot)
	await process_frame
	_check((boot.get("_background") as ColorRect).color == UiPalette.BACKGROUND, "Web entry uses the same black palette")
	var start: Button = boot.get("_start_button")
	var normal: StyleBoxFlat = start.get_theme_stylebox("normal")
	_check(_is_gray(normal.bg_color) and normal.border_color == UiPalette.BORDER, "Web START GAME button has no blue/purple chrome")
	start.pressed.emit()
	var panel_style: StyleBoxFlat = (boot.get("_dialog_panel") as PanelContainer).get_theme_stylebox("panel")
	_check(panel_style.bg_color == UiPalette.PANEL and panel_style.border_color == UiPalette.WHITE, "fullscreen prompt uses black and white modal styling")
	(boot.get("_yes_button") as Button).pressed.emit()
	(boot.get("_no_button") as Button).pressed.emit()
	_check(trace == ["fullscreen", "game"] and int(boot.gameplay_start_count) == 1, "Web YES path requests fullscreen and starts exactly once")
	boot.queue_free()
	await process_frame

func _test_source_scope_and_renderer_evidence() -> void:
	var targeted := ["scripts/boot.gd", "scripts/main.gd", "scripts/ui/hud_view.gd", "scripts/ui/ball_chain_view.gd", "scripts/ui/magazine_view.gd", "scripts/ui/shooter_view.gd", "scripts/ui/control_settings_view.gd", "scripts/ui/game_over_overlay.gd"]
	var forbidden := ["0.10, 0.30, 0.51", "0.045, 0.065, 0.115", "0.025, 0.035, 0.065", "0.19, 0.26, 0.4", "0.32, 0.4, 0.55"]
	for path in targeted:
		var source := FileAccess.get_file_as_string("res://" + path)
		for token in forbidden:
			_check(not source.contains(token), "%s contains no legacy blue/purple token %s" % [path, token])
	for fixture in PREVIEWS:
		var image := Image.new()
		var result := image.load(ProjectSettings.globalize_path(str(fixture[0])))
		_check(result == OK and image.get_size() == fixture[1], "%s is committed genuine renderer evidence" % fixture[0])

func _relative_luminance(color: Color) -> float:
	var channels := [color.r, color.g, color.b]
	for index in range(channels.size()):
		channels[index] = channels[index] / 12.92 if channels[index] <= 0.04045 else pow((channels[index] + 0.055) / 1.055, 2.4)
	return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722

func _contrast(a: Color, b: Color) -> float:
	var first := _relative_luminance(a)
	var second := _relative_luminance(b)
	return (maxf(first, second) + 0.05) / (minf(first, second) + 0.05)

func _is_gray(color: Color) -> bool:
	return is_equal_approx(color.r, color.g) and is_equal_approx(color.g, color.b)

func _finish() -> void:
	if _failures.is_empty():
		print("P036 monochrome UI: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P036: " + failure)
	push_error("P036 monochrome UI: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
