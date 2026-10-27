class_name ActorVisualFactory
extends RefCounted

const EnemyTypes = preload("res://scripts/world/enemy_types.gd")

const HEALING_AURA_TEXTURE_SIZE := 64

static var _shared_healing_aura_texture: ImageTexture


static func create_defender_visual(parent: Node3D, identity: int) -> Dictionary:
	var resolved_identity := posmod(identity, TeamData.COUNT)
	var root := Node3D.new()
	root.name = "Defender_%s" % TeamData.display_name(resolved_identity)
	parent.add_child(root)
	var color_value := TeamData.color(resolved_identity)
	var body := PrimitiveFactory.cylinder(0.32, 0.43, 0.75, color_value)
	body.name = "DefenderBody_%s" % TeamData.display_name(resolved_identity)
	body.position.y = 0.42
	root.add_child(body)
	var head := PrimitiveFactory.sphere(0.31, 0.62, color_value.lightened(0.08))
	head.name = "DefenderHead_%s" % TeamData.display_name(resolved_identity)
	head.position.y = 1.0
	root.add_child(head)
	var visor := PrimitiveFactory.box(Vector3(0.3, 0.12, 0.11), Color(0.06, 0.08, 0.12))
	visor.name = "Visor"
	visor.position = Vector3(0.0, 1.03, 0.28)
	root.add_child(visor)
	var launcher := PrimitiveFactory.cylinder(0.075, 0.075, 0.9, Color(0.75, 0.79, 0.85), 8)
	launcher.name = "Launcher"
	launcher.rotation_degrees.z = 90.0
	launcher.position = Vector3(0.43, 0.64, 0.0)
	root.add_child(launcher)
	var muzzle_flash := PrimitiveFactory.sphere(0.13, 0.26, color_value.lightened(0.35))
	muzzle_flash.name = "MuzzleFlash"
	muzzle_flash.position = Vector3(0.92, 0.64, 0.0)
	muzzle_flash.visible = false
	root.add_child(muzzle_flash)
	var charge_orb := PrimitiveFactory.sphere(0.13, 0.26, Color(1.0, 0.74, 0.18))
	charge_orb.name = "ChargeOrb"
	charge_orb.position = Vector3(-0.58, 0.82, 0.0)
	root.add_child(charge_orb)
	return {"root": root, "muzzle_flash": muzzle_flash, "charge_orb": charge_orb}


static func create_enemy_visual(parent: Node3D, uid: int, enemy_type: int, include_shadow := true) -> Dictionary:
	var resolved_type := enemy_type if EnemyTypes.valid_type(enemy_type) else EnemyTypes.Type.HOPPER
	var shadow: MeshInstance3D
	if include_shadow:
		var shadow_radius := 0.47 if resolved_type == EnemyTypes.Type.HEAVY else (0.3 if resolved_type == EnemyTypes.Type.HEALYZARD else 0.37)
		shadow = PrimitiveFactory.cylinder(shadow_radius, shadow_radius, 0.025, Color(0.015, 0.02, 0.03, 0.58), 20)
		shadow.name = "EnemyShadow_%d" % uid
		shadow.position.y = 0.01
		parent.add_child(shadow)

	var root := Node3D.new()
	root.name = "%s_%d" % [EnemyTypes.display_name(resolved_type).replace(" ", ""), uid]
	parent.add_child(root)
	var aura: Sprite3D
	if resolved_type == EnemyTypes.Type.HEALYZARD:
		aura = Sprite3D.new()
		aura.name = "HealingAura"
		aura.texture = healing_aura_texture()
		aura.pixel_size = 0.026
		aura.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		aura.shaded = false
		aura.no_depth_test = false
		aura.position = Vector3(0.0, 0.55, -0.24)
		aura.modulate = Color(1.0, 0.88, 0.18, 0.0)
		aura.visible = false
		root.add_child(aura)
	var body_color := Color(0.23, 0.25, 0.31)
	var helmet_color := Color(0.12, 0.14, 0.19)
	var eye_color := Color(1.0, 0.44, 0.24)
	var body_radius := 0.4
	var body_height := 0.8
	var body_y := 0.35
	var helmet_top := 0.34
	var helmet_bottom := 0.43
	var helmet_height := 0.4
	var helmet_y := 0.72
	var eye_y := 0.7
	var eye_x := 0.13
	var base_scale := Vector3.ONE
	match resolved_type:
		EnemyTypes.Type.HEAVY:
			body_color = Color(0.72, 0.27, 0.08)
			helmet_color = Color(0.34, 0.12, 0.045)
			eye_color = Color(0.98, 0.9, 0.58)
			body_radius = 0.52
			helmet_top = 0.46
			helmet_bottom = 0.56
			eye_x = 0.18
		EnemyTypes.Type.SICKLE_SNAKE:
			body_color = Color(0.9, 0.69, 0.08)
			helmet_color = Color(0.47, 0.34, 0.035)
			eye_color = Color(0.09, 0.12, 0.17)
			body_radius = 0.34
			body_height = 1.18
			body_y = 0.52
			helmet_top = 0.28
			helmet_bottom = 0.37
			helmet_y = 1.03
			eye_y = 1.0
		EnemyTypes.Type.HEALYZARD:
			body_color = Color(0.12, 0.63, 0.25)
			helmet_color = Color(0.055, 0.3, 0.12)
			eye_color = Color(0.8, 0.95, 1.0)
			base_scale = Vector3.ONE * 0.7
	var body := PrimitiveFactory.sphere(body_radius, body_height, body_color)
	body.name = "Body"
	body.position.y = body_y
	root.add_child(body)
	var helmet := PrimitiveFactory.cylinder(helmet_top, helmet_bottom, helmet_height, helmet_color, 8)
	helmet.name = "Helmet"
	helmet.position.y = helmet_y
	root.add_child(helmet)
	for side in [-1.0, 1.0]:
		var eye := PrimitiveFactory.sphere(0.045, 0.09, eye_color)
		eye.name = "Eye"
		eye.position = Vector3(side * eye_x, eye_y, 0.34)
		root.add_child(eye)
	var horns: Array[MeshInstance3D] = []
	if resolved_type == EnemyTypes.Type.HOPPER:
		for side in [-1.0, 1.0]:
			var horn := PrimitiveFactory.box(Vector3(0.16, 0.12, 0.12), Color(1.0, 0.34, 0.08))
			horn.name = "HopperHorn"
			horn.position = Vector3(side * 0.14, 1.04, 0.0)
			root.add_child(horn)
			horns.append(horn)
	root.scale = base_scale
	return {"root": root, "shadow": shadow, "horns": horns, "type": resolved_type, "base_scale": base_scale, "aura": aura, "aura_age": -1.0}


static func healing_aura_texture() -> ImageTexture:
	if _shared_healing_aura_texture != null:
		return _shared_healing_aura_texture
	var image := Image.create(HEALING_AURA_TEXTURE_SIZE, HEALING_AURA_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(HEALING_AURA_TEXTURE_SIZE - 1, HEALING_AURA_TEXTURE_SIZE - 1) * 0.5
	var radius := float(HEALING_AURA_TEXTURE_SIZE - 1) * 0.5
	for y in range(HEALING_AURA_TEXTURE_SIZE):
		for x in range(HEALING_AURA_TEXTURE_SIZE):
			var distance_ratio := Vector2(x, y).distance_to(center) / radius
			var alpha := pow(clampf(1.0 - distance_ratio, 0.0, 1.0), 1.7) * 0.72
			image.set_pixel(x, y, Color(1.0, 0.84, 0.12, alpha))
	_shared_healing_aura_texture = ImageTexture.create_from_image(image)
	return _shared_healing_aura_texture
