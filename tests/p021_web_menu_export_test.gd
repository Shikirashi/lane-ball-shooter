extends SceneTree

const BootScript := preload("res://scripts/boot.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	await _test_web_menu_lifecycle()
	await _test_yes_direct_fullscreen_order()
	await _test_no_and_duplicate_guard()
	await _test_native_gate()
	await _test_responsive_layout_and_focus()
	_test_export_configuration()
	_finish()

func _new_boot(forced_web: int, trace: Array = []) -> Node:
	var boot := BootScript.new()
	boot.forced_web_mode = forced_web
	boot.fullscreen_requester = func() -> void: trace.append("fullscreen")
	boot.gameplay_starter = func() -> void: trace.append("game")
	root.add_child(boot)
	return boot

func _test_web_menu_lifecycle() -> void:
	var trace: Array = []
	var boot := _new_boot(1, trace)
	await process_frame
	var menu: Control = boot.get("_menu_root")
	var start: Button = boot.get("_start_button")
	var dialog: ColorRect = boot.get("_dialog_layer")
	_check(menu != null and menu.visible, "forced Web boot displays a menu")
	_check((boot.get("_title") as Label).text == "LANE BALL SHOOTER" and start.text == "START GAME", "menu exposes exact title and START GAME copy")
	_check(start.has_focus(), "START GAME owns initial keyboard focus")
	_check(trace.is_empty() and int(boot.gameplay_start_count) == 0, "gameplay remains uninstantiated and uninitialized before selection")
	_check(not dialog.visible, "fullscreen dialog is initially hidden")
	start.pressed.emit()
	_check(dialog.visible and start.disabled, "START GAME opens one modal and cannot open duplicates")
	_check((boot.get("_prompt") as Label).text == "Play in fullscreen?", "dialog uses exact fullscreen prompt")
	_check((boot.get("_yes_button") as Button).text == "YES" and (boot.get("_no_button") as Button).text == "NO", "dialog exposes exact YES and NO labels")
	_check(trace.is_empty() and int(boot.gameplay_start_count) == 0, "opening the prompt still does not start gameplay")
	start.pressed.emit()
	_check(trace.is_empty(), "disabled/repeated START does not click through or start gameplay")
	boot.queue_free()
	await process_frame

func _test_yes_direct_fullscreen_order() -> void:
	var trace: Array = []
	var boot := _new_boot(1, trace)
	await process_frame
	(boot.get("_start_button") as Button).pressed.emit()
	(boot.get("_yes_button") as Button).pressed.emit()
	_check(trace == ["fullscreen", "game"], "YES requests fullscreen synchronously before starting gameplay")
	_check(int(boot.fullscreen_request_count) == 1 and int(boot.gameplay_start_count) == 1, "YES requests fullscreen and starts exactly once")
	(boot.get("_yes_button") as Button).pressed.emit()
	(boot.get("_no_button") as Button).pressed.emit()
	_check(trace == ["fullscreen", "game"], "locked choice rejects duplicate YES/NO starts")
	_check(not (boot.get("_menu_root") as Control).visible, "menu is hidden before gameplay handoff")
	boot.queue_free()
	await process_frame

func _test_no_and_duplicate_guard() -> void:
	var trace: Array = []
	var boot := _new_boot(1, trace)
	await process_frame
	(boot.get("_start_button") as Button).pressed.emit()
	(boot.get("_no_button") as Button).pressed.emit()
	_check(trace == ["game"], "NO starts in-page gameplay without a fullscreen request")
	_check(int(boot.fullscreen_request_count) == 0 and int(boot.gameplay_start_count) == 1, "NO records exactly one game start and zero fullscreen calls")
	boot.call("_start_game_once")
	_check(trace == ["game"], "game-start guard prevents duplicate scene creation")
	boot.queue_free()
	await process_frame

func _test_native_gate() -> void:
	_check(BootScript.platform_uses_menu(true, false), "Web feature selects the browser menu")
	_check(not BootScript.platform_uses_menu(false, false), "desktop bypasses the browser menu")
	_check(not BootScript.platform_uses_menu(false, true), "native Android bypasses the browser menu")
	_check(not BootScript.platform_uses_menu(true, true), "Android identity takes precedence over Web in defensive mixed-feature input")
	var trace: Array = []
	var boot := _new_boot(0, trace)
	await process_frame
	_check(trace == ["game"] and boot.get("_menu_root") == null, "native boot immediately starts legacy Main without constructing menu/game underneath")
	boot.queue_free()
	await process_frame

func _test_responsive_layout_and_focus() -> void:
	var boot := _new_boot(1)
	await process_frame
	var sizes := [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080), Vector2(640, 360)]
	for size in sizes:
		var safe := Rect2(Vector2(20.0, 10.0), size - Vector2(40.0, 20.0))
		boot.call("_apply_layout", size, safe)
		var start: Button = boot.get("_start_button")
		var dialog: PanelContainer = boot.get("_dialog_panel")
		_check(safe.encloses(Rect2(start.position, start.size)), "%s START GAME remains in safe landscape bounds" % size)
		_check(safe.encloses(Rect2(dialog.position, dialog.size)), "%s modal remains readable in safe landscape bounds" % size)
		_check(start.size.y >= 60.0 and (boot.get("_yes_button") as Button).custom_minimum_size.y >= 60.0, "%s controls retain finger-friendly height" % size)
	var start_button: Button = boot.get("_start_button")
	var yes_button: Button = boot.get("_yes_button")
	var no_button: Button = boot.get("_no_button")
	_check(start_button.focus_mode == Control.FOCUS_ALL and yes_button.focus_mode == Control.FOCUS_ALL and no_button.focus_mode == Control.FOCUS_ALL, "START/YES/NO accept keyboard focus for Enter or Space")
	start_button.pressed.emit()
	_check(yes_button.has_focus(), "fullscreen dialog moves keyboard focus to YES")
	boot.call("_layout")
	_check(int(boot.gameplay_start_count) == 0, "resize/fullscreen-style relayout does not start or restart gameplay")
	boot.queue_free()
	await process_frame

func _test_export_configuration() -> void:
	var preset := FileAccess.get_file_as_string("res://export_presets.cfg")
	var project := FileAccess.get_file_as_string("res://project.godot")
	var build_script := FileAccess.get_file_as_string("res://scripts/build_web.sh")
	_check(preset.contains("name=\"Web\"") and preset.contains("export_path=\"exports/web/index.html\""), "Web preset targets the documented static index path")
	_check(preset.contains("variant/thread_support=false"), "Web preset remains single-threaded")
	_check(preset.contains("progressive_web_app/enabled=false") and preset.contains("exclude_filter=\"exports/**\""), "Web preset disables PWA and excludes recursive build artifacts")
	_check(project.contains("run/main_scene=\"res://scenes/boot.tscn\""), "project starts through the platform-gated bootstrap")
	_check(project.contains("renderer/rendering_method=\"gl_compatibility\""), "project retains the Compatibility renderer")
	_check(build_script.contains("--export-release \"Web\"") and build_script.contains("lane-ball-shooter-web.zip"), "repeatable helper performs release export and root-level ZIP packaging")

func _finish() -> void:
	if _failures.is_empty():
		print("P021 Web menu/export: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P021: " + failure)
	push_error("P021 Web menu/export: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
