class_name LaneActor
extends Node3D

const EnemyTypes = preload("res://scripts/world/enemy_types.gd")

signal enemy_death_started(identity: int, enemy_uid: int, impact_x: float, cause: StringName)

const STATE_EFFECT_DURATION := 0.45
const DEATH_EFFECT_DURATION := 1.0
const DEATH_FALL_DURATION := 0.5
const EMERGENCY_WAVE_EXPANSION := 38.0
const REVIVAL_FLASH_EXPANSION := 3.0

var team_identity := 0
var lane_index := 0
var combat_model: LaneCombatModel
var external_spawn_control := false

var _defender_root: Node3D
var _muzzle_flash: MeshInstance3D
var _charge_orb: MeshInstance3D
var _status_label: Label3D
var _enemy_visuals := {}
var _projectile_visuals := {}
var _death_effects: Array[Dictionary] = []
var _death_uids := {}
var _state_effects: Array[Dictionary] = []
var _attack_feedback := 0.0
var _revive_feedback := 0.0
var _last_status_key := ""

func setup(identity: int, index: int, director_controls_spawns := false) -> void:
	team_identity = posmod(identity, TeamData.COUNT)
	lane_index = index
	external_spawn_control = director_controls_spawns
	combat_model = LaneCombatModel.new(team_identity)

func _ready() -> void:
	if combat_model == null:
		combat_model = LaneCombatModel.new(team_identity)
	_build_lane()
	_build_defender()
	combat_model.enemy_neutralized_detail.connect(_on_enemy_neutralized_detail)
	combat_model.defender_knocked_down.connect(_on_defender_knocked_down)
	combat_model.emergency_discharged.connect(_on_emergency_discharged)
	combat_model.defender_revived.connect(_on_defender_revived)
	if external_spawn_control:
		combat_model.clear_for_test()
	else:
		combat_model.reset_run(3.6 + lane_index * 0.55, 2.8 + lane_index * 1.15)
	_sync_visuals()
	_update_status_visual()

func _process(delta: float) -> void:
	combat_model.update(delta)
	_update_defender_feedback(delta)
	_update_death_effects(delta)
	_update_state_effects(delta)
	_sync_visuals()
	_update_status_visual()

func fire_for_match(result: Dictionary) -> Dictionary:
	if int(result.get("identity", -1)) != team_identity:
		return {}
	_attack_feedback = 0.3
	return combat_model.fire_attack(result)

func handle_match(result: Dictionary) -> Dictionary:
	if int(result.get("identity", -1)) != team_identity:
		return {"action": "ignored"}
	var outcome := combat_model.handle_match(result)
	if str(outcome.get("action", "")) == "attack":
		_attack_feedback = 0.3
	_update_status_visual()
	return outcome

func show_tier3_clear_wave() -> void:
	var wave := PrimitiveFactory.box(Vector3(16.2, 0.05, 1.18), TeamData.color(team_identity).lightened(0.38))
	wave.name = "Tier3ClearWave"
	wave.position = Vector3(0.0, 0.1, 0.0)
	add_child(wave)
	_state_effects.append({"node": wave, "age": 0.0, "kind": "tier3"})

func enemy_hop_height(enemy: Dictionary) -> float:
	if not bool(enemy.get("hop_airborne", false)):
		return 0.0
	return sin(float(enemy.get("hop_progress", 0.0)) * PI) * 0.52

func reset_run(spawn_initial := true) -> void:
	for effect in _death_effects:
		for key in ["root", "shadow", "burst"]:
			var death_node: Node = effect.get(key)
			if is_instance_valid(death_node):
				death_node.queue_free()
	for effect in _state_effects:
		var state_node: Node = effect.node
		state_node.queue_free()
	_death_effects.clear()
	_death_uids.clear()
	_state_effects.clear()
	_attack_feedback = 0.0
	_revive_feedback = 0.0
	if spawn_initial:
		combat_model.reset_run(3.6 + lane_index * 0.55, 2.8 + lane_index * 1.15)
	else:
		combat_model.clear_for_test()
	_sync_visuals()
	_last_status_key = ""
	_update_status_visual()

func _build_lane() -> void:
	var team_color := TeamData.color(team_identity)
	var floor := PrimitiveFactory.box(Vector3(16.8, 0.12, 1.45), Color(0.1, 0.13, 0.18))
	floor.name = "LaneFloor"
	floor.position.y = -0.1
	add_child(floor)
	var stripe := PrimitiveFactory.box(Vector3(16.8, 0.025, 0.08), team_color.darkened(0.08))
	stripe.name = "TeamStripe_%s" % TeamData.display_name(team_identity)
	stripe.position = Vector3(0.0, -0.025, -0.61)
	add_child(stripe)
	var team_marker := PrimitiveFactory.cylinder(0.38, 0.38, 0.035, team_color, 20)
	team_marker.name = "TeamMarker_%s" % TeamData.display_name(team_identity)
	team_marker.position = Vector3(-7.05, 0.03, 0.0)
	add_child(team_marker)
	_add_team_glyph(team_marker, team_identity)

func _build_defender() -> void:
	_defender_root = Node3D.new()
	_defender_root.name = "Defender_%s" % TeamData.display_name(team_identity)
	_defender_root.position = Vector3(LaneCombatModel.DEFENDER_X, 0.0, 0.0)
	add_child(_defender_root)
	var color_value := TeamData.color(team_identity)
	var body := PrimitiveFactory.cylinder(0.32, 0.43, 0.75, color_value)
	body.name = "DefenderBody_%s" % TeamData.display_name(team_identity)
	body.position.y = 0.42
	_defender_root.add_child(body)
	var head := PrimitiveFactory.sphere(0.31, 0.62, color_value.lightened(0.08))
	head.name = "DefenderHead_%s" % TeamData.display_name(team_identity)
	head.position.y = 1.0
	_defender_root.add_child(head)
	var visor := PrimitiveFactory.box(Vector3(0.3, 0.12, 0.11), Color(0.06, 0.08, 0.12))
	visor.position = Vector3(0.0, 1.03, 0.28)
	_defender_root.add_child(visor)
	var launcher := PrimitiveFactory.cylinder(0.075, 0.075, 0.9, Color(0.75, 0.79, 0.85), 8)
	launcher.rotation_degrees.z = 90.0
	launcher.position = Vector3(0.43, 0.64, 0.0)
	_defender_root.add_child(launcher)
	_muzzle_flash = PrimitiveFactory.sphere(0.13, 0.26, color_value.lightened(0.35))
	_muzzle_flash.position = Vector3(0.92, 0.64, 0.0)
	_muzzle_flash.visible = false
	_defender_root.add_child(_muzzle_flash)

	_charge_orb = PrimitiveFactory.sphere(0.13, 0.26, Color(1.0, 0.74, 0.18))
	_charge_orb.position = Vector3(-0.58, 0.82, 0.0)
	_defender_root.add_child(_charge_orb)
	_status_label = Label3D.new()
	_status_label.name = "LaneStatus"
	_status_label.position = Vector3(-4.65, 1.34, 0.0)
	_status_label.font_size = 28
	_status_label.outline_size = 6
	_status_label.modulate = TeamData.color(team_identity).lightened(0.2)
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	add_child(_status_label)

func _sync_visuals() -> void:
	var live_enemy_ids := {}
	for enemy in combat_model.enemies:
		var uid := int(enemy.uid)
		live_enemy_ids[uid] = true
		if not _enemy_visuals.has(uid):
			_enemy_visuals[uid] = _create_enemy_visual(uid, int(enemy.get("type", EnemyTypes.Type.HOPPER)))
		_update_enemy_visual(_enemy_visuals[uid], enemy)
	for uid in _enemy_visuals.keys().duplicate():
		if not live_enemy_ids.has(uid):
			_free_enemy_visual(uid)

	var live_projectile_ids := {}
	for projectile in combat_model.projectiles:
		var uid := int(projectile.uid)
		live_projectile_ids[uid] = true
		if not _projectile_visuals.has(uid):
			_projectile_visuals[uid] = _create_projectile_visual(uid)
		var visual: MeshInstance3D = _projectile_visuals[uid]
		visual.visible = float(projectile.launch_delay) <= 0.0
		visual.position = Vector3(float(projectile.x), 0.68, 0.0)
	for uid in _projectile_visuals.keys().duplicate():
		if not live_projectile_ids.has(uid):
			var projectile_visual: Node = _projectile_visuals[uid]
			projectile_visual.queue_free()
			_projectile_visuals.erase(uid)

func _create_enemy_visual(uid: int, enemy_type: int) -> Dictionary:
	var resolved_type := enemy_type if EnemyTypes.valid_type(enemy_type) else EnemyTypes.Type.HOPPER
	var shadow_radius := 0.47 if resolved_type == EnemyTypes.Type.HEAVY else (0.3 if resolved_type == EnemyTypes.Type.HEALYZARD else 0.37)
	var shadow := PrimitiveFactory.cylinder(shadow_radius, shadow_radius, 0.025, Color(0.015, 0.02, 0.03, 0.58), 20)
	shadow.name = "EnemyShadow_%d" % uid
	shadow.position.y = 0.01
	add_child(shadow)

	var root := Node3D.new()
	root.name = "%s_%d" % [EnemyTypes.display_name(resolved_type).replace(" ", ""), uid]
	add_child(root)
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
	return {"root": root, "shadow": shadow, "horns": horns, "type": resolved_type, "base_scale": base_scale}

func _update_enemy_visual(visual: Dictionary, enemy: Dictionary) -> void:
	var root: Node3D = visual.root
	var shadow: MeshInstance3D = visual.shadow
	var hop_progress := float(enemy.get("hop_progress", 0.0))
	var hop_height := enemy_hop_height(enemy)
	var is_hopper := EnemyTypes.uses_hop(int(enemy.get("type", EnemyTypes.Type.HOPPER)))
	var landing_amount := (0.16 if not bool(enemy.get("hop_airborne", false)) else pow(absf(cos(hop_progress * PI)), 10.0)) if is_hopper else 0.0
	var hit_amount := clampf(float(enemy.hit_flash) / 0.16, 0.0, 1.0)
	root.position = Vector3(float(enemy.x), 0.29 + hop_height, 0.0)
	var base_scale: Vector3 = visual.base_scale
	root.scale = base_scale * Vector3(1.0 + landing_amount * 0.12 + hit_amount * 0.16, 1.0 - landing_amount * 0.16 - hit_amount * 0.08, 1.0 + landing_amount * 0.12 + hit_amount * 0.16)
	shadow.position.x = float(enemy.x)
	shadow.scale = Vector3(1.0 - hop_height * 0.35, 1.0, 1.0 - hop_height * 0.35)

func _free_enemy_visual(uid: int) -> void:
	var visual: Dictionary = _enemy_visuals[uid]
	var root: Node = visual.root
	var shadow: Node = visual.shadow
	root.queue_free()
	shadow.queue_free()
	_enemy_visuals.erase(uid)

func _create_projectile_visual(uid: int) -> MeshInstance3D:
	var color_value := TeamData.color(team_identity).lightened(0.2)
	var visual := PrimitiveFactory.sphere(0.12, 0.24, color_value)
	visual.name = "Projectile_%d" % uid
	add_child(visual)
	return visual

func _update_defender_feedback(delta: float) -> void:
	_attack_feedback = maxf(0.0, _attack_feedback - delta)
	_revive_feedback = maxf(0.0, _revive_feedback - delta)
	if combat_model.defender_state == LaneCombatModel.DefenderState.DOWN:
		_defender_root.position = Vector3(LaneCombatModel.DEFENDER_X, 0.12, 0.0)
		_defender_root.rotation_degrees.z = 78.0
		_defender_root.scale = Vector3(1.0, 0.82, 1.0)
		_muzzle_flash.visible = false
		return
	var amount := clampf(_attack_feedback / 0.3, 0.0, 1.0)
	var lunge := sin(amount * PI) * 0.28
	var revive_amount := clampf(_revive_feedback / 0.5, 0.0, 1.0)
	_defender_root.position = Vector3(LaneCombatModel.DEFENDER_X + lunge, sin(revive_amount * PI) * 0.18, 0.0)
	_defender_root.rotation_degrees.z = -lunge * 9.0
	_defender_root.scale = Vector3.ONE * (1.0 + sin(revive_amount * PI) * 0.16)
	_muzzle_flash.visible = amount > 0.12
	_muzzle_flash.scale = Vector3.ONE * (0.55 + amount * 0.9)

func _update_status_visual() -> void:
	if _status_label == null:
		return
	var state_name := "ACTIVE" if combat_model.defender_state == LaneCombatModel.DefenderState.ACTIVE else "DOWN %d/%d" % [combat_model.revival_progress, combat_model.revival_required]
	var charge_name := "CHARGE" if combat_model.emergency_available else "SPENT"
	var status_key := "%s|%s" % [state_name, charge_name]
	if status_key == _last_status_key:
		return
	_last_status_key = status_key
	_status_label.text = "%s  %s  %s" % [TeamData.symbol_name(team_identity), state_name, charge_name]
	_status_label.modulate = TeamData.color(team_identity).lightened(0.25) if combat_model.defender_state == LaneCombatModel.DefenderState.ACTIVE else Color(0.72, 0.75, 0.82)
	_charge_orb.material_override = PrimitiveFactory.material(Color(1.0, 0.74, 0.18) if combat_model.emergency_available else Color(0.16, 0.17, 0.2))

func _on_enemy_neutralized_detail(enemy: Dictionary, cause: StringName, impact_x: float) -> void:
	var enemy_uid := int(enemy.uid)
	if _death_uids.has(enemy_uid):
		return
	_death_uids[enemy_uid] = true
	var visual: Dictionary
	if _enemy_visuals.has(enemy_uid):
		visual = _enemy_visuals[enemy_uid]
		_enemy_visuals.erase(enemy_uid)
	else:
		visual = _create_enemy_visual(enemy_uid, int(enemy.get("type", EnemyTypes.Type.HOPPER)))
		var fallback_root: Node3D = visual.root
		var fallback_shadow: Node3D = visual.shadow
		fallback_root.position = Vector3(impact_x, 0.29, 0.0)
		fallback_shadow.position.x = impact_x
	_prepare_fade_materials(visual.root)
	_prepare_fade_materials(visual.shadow)
	var burst := _create_death_burst(enemy_uid, impact_x)
	var root: Node3D = visual.root
	_death_effects.append({
		"uid": enemy_uid,
		"root": root,
		"shadow": visual.shadow,
		"burst": burst,
		"age": 0.0,
		"start_position": root.position,
		"fall_sign": -1.0 if enemy_uid % 2 == 0 else 1.0,
	})
	enemy_death_started.emit(team_identity, enemy_uid, impact_x, cause)

func _create_death_burst(enemy_uid: int, impact_x: float) -> Node3D:
	var burst := Node3D.new()
	burst.name = "EnemyDeathBurst_%d" % enemy_uid
	burst.position = Vector3(impact_x, 0.66, 0.0)
	var core := PrimitiveFactory.sphere(0.18, 0.36, Color(1.0, 0.62, 0.16, 0.9))
	core.name = "ExplosionCore"
	_prepare_fade_materials(core)
	burst.add_child(core)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var spark := PrimitiveFactory.sphere(0.055, 0.11, Color(1.0, 0.34 + 0.05 * (index % 3), 0.08, 0.95))
		spark.name = "Spark%d" % index
		spark.position = Vector3(cos(angle) * 0.16, sin(angle) * 0.14, sin(angle * 2.0) * 0.1)
		_prepare_fade_materials(spark)
		burst.add_child(spark)
	add_child(burst)
	return burst

func _prepare_fade_materials(node: Node) -> void:
	var meshes: Array[Node] = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for child in meshes:
		var mesh_instance := child as MeshInstance3D
		var material := mesh_instance.material_override as StandardMaterial3D
		if material == null:
			material = StandardMaterial3D.new()
		else:
			material = material.duplicate()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_instance.material_override = material

func _set_visual_alpha(node: Node, alpha: float) -> void:
	var meshes: Array[Node] = []
	if node is MeshInstance3D:
		meshes.append(node)
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	for child in meshes:
		var material := (child as MeshInstance3D).material_override as StandardMaterial3D
		if material != null:
			var color := material.albedo_color
			color.a = clampf(alpha, 0.0, 1.0)
			material.albedo_color = color

func _update_death_effects(delta: float) -> void:
	for index in range(_death_effects.size() - 1, -1, -1):
		var effect := _death_effects[index]
		effect.age = float(effect.age) + delta
		var age := float(effect.age)
		var root: Node3D = effect.root
		var shadow: Node3D = effect.shadow
		var burst: Node3D = effect.burst
		var fall_ratio := clampf(age / DEATH_FALL_DURATION, 0.0, 1.0)
		var eased_fall := 1.0 - pow(1.0 - fall_ratio, 3.0)
		var start_position: Vector3 = effect.start_position
		root.rotation.z = float(effect.fall_sign) * (PI * 0.47) * eased_fall
		root.position = Vector3(start_position.x + float(effect.fall_sign) * 0.18 * eased_fall, lerpf(start_position.y, 0.42, eased_fall), start_position.z)
		shadow.position.x = root.position.x
		shadow.scale = Vector3(1.0 + eased_fall * 0.35, 1.0, 0.82)
		var fade := 1.0 - clampf((age - 0.52) / (DEATH_EFFECT_DURATION - 0.52), 0.0, 1.0)
		_set_visual_alpha(root, fade)
		_set_visual_alpha(shadow, fade * 0.58)
		var burst_ratio := clampf(age / 0.38, 0.0, 1.0)
		burst.scale = Vector3.ONE * (1.0 + burst_ratio * 2.2)
		_set_visual_alpha(burst, 1.0 - burst_ratio)
		if age >= DEATH_EFFECT_DURATION:
			root.queue_free()
			shadow.queue_free()
			burst.queue_free()
			_death_effects.remove_at(index)
		else:
			_death_effects[index] = effect

func _on_defender_knocked_down(_identity: int) -> void:
	_attack_feedback = 0.0
	_update_status_visual()

func _on_emergency_discharged(_identity: int, _cleared_count: int) -> void:
	var wave := PrimitiveFactory.cylinder(0.32, 0.32, 0.035, TeamData.color(team_identity).lightened(0.3), 24)
	wave.name = "EmergencyDischargeWave"
	wave.position = Vector3(LaneCombatModel.DEFENDER_X, 0.06, 0.0)
	add_child(wave)
	_state_effects.append({"node": wave, "age": 0.0, "kind": "discharge"})
	_update_status_visual()

func _on_defender_revived(_identity: int, _repelled_count: int) -> void:
	_revive_feedback = 0.5
	var flash := PrimitiveFactory.sphere(0.3, 0.6, TeamData.color(team_identity).lightened(0.35))
	flash.name = "RevivalFlash"
	flash.position = Vector3(LaneCombatModel.DEFENDER_X, 0.65, 0.0)
	add_child(flash)
	_state_effects.append({"node": flash, "age": 0.0, "kind": "revive"})
	_update_status_visual()

func _update_state_effects(delta: float) -> void:
	for index in range(_state_effects.size() - 1, -1, -1):
		var effect := _state_effects[index]
		effect.age = float(effect.age) + delta
		var node: Node3D = effect.node
		if str(effect.kind) == "discharge":
			node.scale = Vector3(1.0 + float(effect.age) * EMERGENCY_WAVE_EXPANSION, 1.0, 1.0 + float(effect.age) * 1.8)
		elif str(effect.kind) == "tier3":
			node.scale = Vector3(1.0, 1.0 + float(effect.age) * 5.0, 1.0)
		else:
			node.scale = Vector3.ONE * (1.0 + float(effect.age) * REVIVAL_FLASH_EXPANSION)
		if float(effect.age) >= STATE_EFFECT_DURATION:
			node.queue_free()
			_state_effects.remove_at(index)
		else:
			_state_effects[index] = effect

func _add_team_glyph(parent: Node3D, identity: int) -> void:
	var glyph: MeshInstance3D
	match identity:
		TeamData.Identity.RED:
			glyph = PrimitiveFactory.sphere(0.13, 0.1, Color(0.06, 0.07, 0.1))
		TeamData.Identity.BLUE:
			glyph = PrimitiveFactory.box(Vector3(0.23, 0.08, 0.23), Color(0.06, 0.07, 0.1))
		TeamData.Identity.YELLOW:
			glyph = PrimitiveFactory.cylinder(0.0, 0.17, 0.08, Color(0.06, 0.07, 0.1), 3)
		_:
			glyph = PrimitiveFactory.box(Vector3(0.2, 0.08, 0.2), Color(0.06, 0.07, 0.1))
			glyph.rotation_degrees.y = 45.0
	glyph.position.y = 0.04
	parent.add_child(glyph)
