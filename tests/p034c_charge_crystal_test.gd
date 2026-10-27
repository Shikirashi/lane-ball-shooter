extends SceneTree

const ASSET_DIR := "res://assets/sprites/baked"
const PREVIEW_FIXTURES := [
	{"path": "res://assets/previews/p034c_crystal_states_1280x720.png", "size": Vector2i(1280, 720)},
	{"path": "res://assets/previews/p034c_crystal_shatter_1600x720.png", "size": Vector2i(1600, 720)},
]

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	await _test_source_and_authentic_rebake()
	await _test_four_team_crystals_and_responsive_layout()
	await _test_authoritative_one_time_shatter_and_restart()
	await _test_live_main_remains_2d_and_cutout_safe()
	_test_renderer_evidence()
	_finish()


func _test_source_and_authentic_rebake() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/world/actor_visual_factory.gd")
	_check(source.find("ChargeOrb") < 0 and source.find("charge_orb") < 0, "procedural 3D source no longer defines or returns ChargeOrb")
	var parent := Node3D.new()
	root.add_child(parent)
	for identity in range(TeamData.COUNT):
		var visual := ActorVisualFactory.create_defender_visual(parent, identity)
		_check(not visual.has("charge_orb"), "team %d source dictionary has no legacy charge mesh" % identity)
		_check((visual.root as Node3D).find_children("ChargeOrb", "MeshInstance3D", true, false).is_empty(), "team %d source hierarchy has no legacy charge mesh" % identity)
	parent.queue_free()
	await process_frame
	var metadata = JSON.parse_string(FileAccess.get_file_as_string("%s/pivots.json" % ASSET_DIR))
	_check(metadata is Dictionary, "rebaked pivot metadata parses")
	for name in ["defender_red", "defender_blue", "defender_yellow", "defender_green"]:
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path("%s/%s.png" % [ASSET_DIR, name]))
		_check(error == OK and image.get_size() == Vector2i(512, 512), "%s is a genuine 512x512 rebake" % name)
		if error != OK:
			continue
		var old_orb_alpha := 0
		for y in range(175, 265):
			for x in range(82, 157):
				if image.get_pixel(x, y).a > 0.01:
					old_orb_alpha += 1
		_check(old_orb_alpha == 0, "%s has genuine transparency throughout the former isolated orb region" % name)
		_check(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(511, 511).a == 0.0, "%s retains transparent corners" % name)
		var bounds: Array = metadata.actors[name].alpha_bounds
		_check(int(bounds[0]) >= 150 and int(bounds[2]) < 310, "%s alpha bounds shrink to the orb-free defender silhouette" % name)


func _new_lane(identity: int, row_size := Vector2(1280.0, 112.0)) -> LaneActor:
	var lane := LaneActor.new()
	lane.setup(identity, identity)
	root.add_child(lane)
	lane.set_process(false)
	lane.configure_layout(row_size)
	return lane


func _test_four_team_crystals_and_responsive_layout() -> void:
	for identity in range(TeamData.COUNT):
		var lane := _new_lane(identity)
		await process_frame
		var crystal := lane.get("_charge_crystal") as Node2D
		var defender := lane.get("_defender_sprite") as Sprite2D
		var dark := crystal.get_node("CrystalFacetDark") as Polygon2D
		_check(crystal.visible and crystal.get_child_count() == 5, "team %d starts with one complete faceted crystal" % identity)
		_check(crystal.z_index < defender.z_index, "team %d crystal is layered behind the defender sprite" % identity)
		_check(crystal.position.x < (lane.get("_defender_root") as Node2D).position.x and crystal.position.y < float(lane.get("_baseline_y")), "team %d crystal sits rear-left and raised")
		_check(dark.color == TeamData.color(identity).darkened(0.16), "team %d crystal derives from its authoritative lane color" % identity)
		_check(crystal.find_children("*", "Control", true, false).is_empty() and lane.mouse_filter == Control.MOUSE_FILTER_IGNORE, "team %d crystal cannot intercept mouse or touch input" % identity)
		for row_size in [Vector2(960.0, 82.0), Vector2(2400.0, 220.0)]:
			lane.configure_layout(row_size)
			crystal = lane.get("_charge_crystal") as Node2D
			_check(crystal.position.x > 0.0 and crystal.position.x < row_size.x and crystal.position.y > 0.0 and crystal.position.y < row_size.y, "team %d crystal remains inside responsive row %s" % [identity, row_size])
			_check(float(lane.get("_charge_crystal_radius")) >= 8.0 and float(lane.get("_charge_crystal_radius")) <= 18.0, "team %d crystal scale stays readable and bounded at %s" % [identity, row_size])
		lane.queue_free()
		await process_frame


func _test_authoritative_one_time_shatter_and_restart() -> void:
	var lane := _new_lane(TeamData.Identity.BLUE)
	await process_frame
	var crystal := lane.get("_charge_crystal") as Node2D
	var sprite := lane.get("_defender_sprite") as Sprite2D
	lane.combat_model.clear_for_test()
	lane.set("_last_status_key", "")
	lane.call("_update_status_visual")
	_check(crystal.visible and lane.get("_charge_shards").is_empty(), "fresh authoritative charge displays one intact crystal")
	lane.combat_model.call("_discharge_emergency")
	_check(not lane.combat_model.emergency_available and not crystal.visible, "authoritative discharge immediately consumes and hides the intact crystal")
	_check(lane.get("_charge_shards").size() == LaneActor.CHARGE_SHARD_COUNT and int(lane.get("_charge_shatter_count")) == 1, "authoritative discharge emits one seven-shard burst")
	lane.combat_model.call("_discharge_emergency")
	_check(lane.get("_charge_shards").size() == LaneActor.CHARGE_SHARD_COUNT and int(lane.get("_charge_shatter_count")) == 1, "spent charge cannot emit a duplicate shatter")
	lane.call("_update_charge_shards", 0.24)
	_check(lane.get("_charge_shards").size() == LaneActor.CHARGE_SHARD_COUNT and float((lane.get("_charge_shards")[0].node as Polygon2D).modulate.a) < 1.0, "shards visibly move, spin and fade during bounded lifetime")
	lane.call("_update_charge_shards", 0.29)
	_check(lane.get("_charge_shards").is_empty(), "all crystal shards disappear after 0.52 seconds")
	_check(sprite.self_modulate == Color.WHITE, "spent charge never dims or recolors the defender sprite")

	lane.combat_model.call("_knock_down")
	lane.handle_match({"identity": TeamData.Identity.BLUE, "tier": 1, "fever": false, "group_size": 3})
	lane.handle_match({"identity": TeamData.Identity.BLUE, "tier": 1, "fever": false, "group_size": 3})
	_check(lane.combat_model.defender_state == LaneCombatModel.DefenderState.ACTIVE and not lane.combat_model.emergency_available, "revival preserves spent one-use emergency state")
	_check(not crystal.visible and lane.get("_charge_shards").is_empty(), "revival does not recreate a spent crystal or shards")

	lane.reset_run(false)
	_check(lane.combat_model.emergency_available and crystal.visible, "run restart restores the intact crystal with the model charge")
	_check(lane.get("_charge_shards").is_empty() and int(lane.get("_charge_shatter_count")) == 0, "restart clears all shatter state")

	lane.combat_model.emergency_available = false
	lane.set("_last_status_key", "")
	lane.call("_update_status_visual")
	_check(not crystal.visible and lane.get("_charge_shards").is_empty(), "forced/loaded spent state hides crystal without inventing a shatter")
	_check(sprite.self_modulate == Color.WHITE, "forced spent state also preserves full-color defender art")
	lane.queue_free()
	await process_frame


func _test_live_main_remains_2d_and_cutout_safe() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var safe := Rect2(96.0, 24.0, 2208.0, 1032.0)
	main.call("_apply_layout", Vector2(2400.0, 1080.0), safe)
	var battlefield: Battlefield = main.get("_battlefield")
	_check(main.find_children("*", "Node3D", true, false).is_empty() and main.find_children("*", "SubViewport", true, false).is_empty(), "normal gameplay remains genuinely 2D with no hidden capture viewport")
	_check(safe.encloses(Rect2(battlefield.position, battlefield.size)), "cutout-safe rectangle contains the complete live battlefield")
	for lane in battlefield.lanes:
		var crystal := lane.get("_charge_crystal") as Node2D
		_check(crystal.visible and crystal.position.x > 0.0 and crystal.position.x < lane.size.x, "cutout-safe lane %d keeps intact crystal visible inside its row" % lane.lane_index)
	main.queue_free()
	await process_frame


func _test_renderer_evidence() -> void:
	for fixture in PREVIEW_FIXTURES:
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(str(fixture.path)))
		_check(error == OK and image.get_size() == fixture.size, "%s is the required real-renderer screenshot" % fixture.path)
		if error != OK:
			continue
		var colors := {}
		for y in range(0, image.get_height(), 20):
			for x in range(0, image.get_width(), 20):
				colors[image.get_pixel(x, y).to_html()] = true
		_check(colors.size() > 90, "%s contains nontrivial rendered gameplay pixels" % fixture.path)


func _finish() -> void:
	if _failures.is_empty():
		print("P034C charge crystal: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P034C charge crystal: " + failure)
	print("P034C charge crystal: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
