extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "main scene loads")
	if packed == null:
		_finish()
		return

	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var lanes := main.find_children("*", "LaneActor", true, false)
	var cameras := main.find_children("*", "Camera3D", true, false)
	_check(lanes.size() == 4, "battlefield contains four LaneActor nodes")
	_check(cameras.is_empty(), "live battlefield contains no 3D camera")
	_check(main.find_children("*", "Node3D", true, false).is_empty(), "live main contains no active 3D nodes")
	_check(main.find_children("*", "SubViewport", true, false).is_empty(), "live main contains no hidden render viewport")

	var shooter: ShooterView = main.get("_shooter_view")
	var magazine_view: MagazineView = main.get("_magazine_view")
	var magazine: MagazineState = main.get("_magazine")
	_check(shooter != null and magazine_view != null, "2D shooter and magazine exist")
	_check(shooter.loaded_identity == magazine.loaded_identity, "shooter starts synchronized with magazine")

	var original_loaded := magazine.loaded_identity
	var original_next := magazine.next_identity
	main.call("_swap")
	_check(magazine.loaded_identity == original_next and magazine.next_identity == original_loaded, "swap exchanges loaded and next")
	_check(shooter.loaded_identity == magazine.loaded_identity, "swap updates shooter identity")
	_check(shooter.loaded_identity == magazine.loaded_identity and shooter.next_identity == magazine.next_identity, "swap updates shooter loaded and next display")

	main.call("_shoot")
	_check(shooter.get("_shots").size() == 1, "shoot launches one visible projectile")
	_check(shooter.loaded_identity == magazine.loaded_identity, "shoot advances and synchronizes loaded identity")
	main.call("_shoot")
	_check(shooter.get("_shots").size() == 1, "cooldown rejects an immediate second shot")

	var battlefield_region: Battlefield = main.get("_battlefield")
	var chain: BallChainView = main.get("_chain_view")
	_check(battlefield_region.position.y >= chain.position.y + chain.size.y, "2D battlefield starts below the top chain")
	_check(magazine_view.position.y + magazine_view.size.y <= chain.position.y, "compact magazine stays in HUD above the chain")
	_check(shooter.track_right >= chain.position.x + chain.size.x - 25.0, "shooter reaches the rightmost chain target")
	_finish()

func _finish() -> void:
	if _failures.is_empty():
		print("P001 headless smoke: PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("P001 headless smoke: " + failure)
	quit(1)
