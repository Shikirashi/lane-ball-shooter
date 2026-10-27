extends SceneTree

const ASSET_DIR := "res://assets/sprites/baked"
const ACTOR_NAMES := [
	"enemy_hopper", "enemy_heavy", "enemy_sickle_snake", "enemy_healyzard",
	"defender_red", "defender_blue", "defender_yellow", "defender_green",
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
	_test_assets_and_alpha()
	await _test_source_factory()
	await _test_preview_is_pure_2d()
	_finish()


func _test_assets_and_alpha() -> void:
	var metadata = JSON.parse_string(FileAccess.get_file_as_string("%s/pivots.json" % ASSET_DIR))
	_check(metadata is Dictionary, "pivot metadata parses")
	if not metadata is Dictionary:
		return
	var master_size: Array = metadata.get("master_size", [])
	_check(master_size.size() == 2 and int(master_size[0]) == 512 and int(master_size[1]) == 512, "all captures share the documented 512px master canvas")
	for actor_name in ACTOR_NAMES:
		var path := "%s/%s.png" % [ASSET_DIR, actor_name]
		_check(FileAccess.file_exists(path), "%s master exists" % actor_name)
		var image := Image.new()
		var image_error := image.load(ProjectSettings.globalize_path(path))
		if image_error != OK:
			image = null
		_check(image != null and not image.is_empty() and image.get_size() == Vector2i(512, 512), "%s is a readable 512x512 PNG" % actor_name)
		if image == null or image.is_empty():
			continue
		var transparent := 0
		var opaque := 0
		var colored := 0
		var edge_alpha := 0
		var transparent_rgb := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel := image.get_pixel(x, y)
				if pixel.a <= 0.001:
					transparent += 1
					if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.02:
						transparent_rgb += 1
				elif pixel.a >= 0.98:
					opaque += 1
					if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.08:
						colored += 1
				else:
					edge_alpha += 1
		_check(transparent > 150000 and opaque > 1000 and colored > 1000, "%s contains a nonempty colored silhouette on genuine transparency" % actor_name)
		_check(edge_alpha > 10, "%s contains anti-aliased alpha edges" % actor_name)
		_check(transparent_rgb < 32, "%s has no meaningful RGB fringe hidden in transparent pixels" % actor_name)
		for corner in [Vector2i.ZERO, Vector2i(511, 0), Vector2i(0, 511), Vector2i(511, 511)]:
			_check(image.get_pixelv(corner).a <= 0.001, "%s corner %s is transparent" % [actor_name, corner])
		var texture := load(path) as Texture2D
		var sprite := Sprite2D.new()
		sprite.texture = texture
		_check(sprite.texture != null and sprite.texture.get_size() == Vector2(512, 512), "%s loads into Sprite2D" % actor_name)
		sprite.free()
		var actor_data: Dictionary = metadata.actors.get(actor_name, {})
		var pivot: Array = actor_data.get("pivot", [])
		var bounds: Array = actor_data.get("alpha_bounds", [])
		_check(pivot.size() == 2 and bounds.size() == 4, "%s has explicit pivot and alpha bounds" % actor_name)
		if pivot.size() == 2 and bounds.size() == 4:
			_check(int(pivot[0]) == 256 and int(pivot[1]) == int(bounds[1]) + int(bounds[3]), "%s pivot is grounded consistently at alpha-bound bottom" % actor_name)
	var contact := Image.new()
	var contact_error := contact.load(ProjectSettings.globalize_path("%s/contact_sheet.png" % ASSET_DIR))
	if contact_error != OK:
		contact = null
	_check(contact != null and contact.get_size() == Vector2i(1088, 544), "contact sheet is a readable 4x2 checkerboard review image")


func _test_source_factory() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var hopper := ActorVisualFactory.create_enemy_visual(parent, 34, EnemyTypes.Type.HOPPER, false)
	_check((hopper.horns as Array).size() == 2, "shared baker/live factory preserves Hopper's two horns")
	var heavy := ActorVisualFactory.create_enemy_visual(parent, 35, EnemyTypes.Type.HEAVY, false)
	var snake := ActorVisualFactory.create_enemy_visual(parent, 36, EnemyTypes.Type.SICKLE_SNAKE, false)
	var healer := ActorVisualFactory.create_enemy_visual(parent, 37, EnemyTypes.Type.HEALYZARD, false)
	_check((heavy.root as Node3D).find_children("HopperHorn", "MeshInstance3D", true, false).is_empty(), "Heavy remains hornless")
	_check((snake.root as Node3D).find_children("HopperHorn", "MeshInstance3D", true, false).is_empty(), "Sickle Snake remains hornless")
	_check(is_equal_approx((healer.root as Node3D).scale.x, 0.7), "Healyzard retains source 0.7 scale")
	var defender := ActorVisualFactory.create_defender_visual(parent, TeamData.Identity.RED)
	_check(not defender.has("charge_orb") and (defender.root as Node3D).find_children("ChargeOrb", "MeshInstance3D", true, false).is_empty(), "defender source contains no legacy baked ChargeOrb")
	parent.queue_free()
	await process_frame


func _test_preview_is_pure_2d() -> void:
	var preview: Node = load("res://scenes/previews/p034a_sprite_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	_check(preview.find_children("*", "Sprite2D", true, false).size() == 8, "isolated preview wires all eight baked Sprite2D actors")
	_check(preview.find_children("*", "Node3D", true, false).is_empty(), "preview contains no live 3D actor rendering")
	_check(preview.find_children("*", "SubViewport", true, false).is_empty(), "preview contains no runtime capture viewport")
	_check(str(ProjectSettings.get_setting("run/main_scene")) != "res://scenes/previews/p034a_sprite_preview.tscn", "preview is isolated from normal startup")
	preview.queue_free()
	await process_frame


func _finish() -> void:
	if _failures.is_empty():
		print("P034A sprite baking: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P034A: " + failure)
	push_error("P034A sprite baking: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
