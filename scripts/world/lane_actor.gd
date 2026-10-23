class_name LaneActor
extends Node3D

var team_identity := 0
var lane_index := 0
var combat_model: LaneCombatModel

var _defender_root: Node3D
var _muzzle_flash: MeshInstance3D
var _enemy_visuals := {}
var _projectile_visuals := {}
var _death_effects: Array[Dictionary] = []
var _attack_feedback := 0.0

func setup(identity: int, index: int) -> void:
	team_identity = posmod(identity, TeamData.COUNT)
	lane_index = index
	combat_model = LaneCombatModel.new(team_identity)

func _ready() -> void:
	if combat_model == null:
		combat_model = LaneCombatModel.new(team_identity)
	_build_lane()
	_build_defender()
	combat_model.enemy_killed.connect(_on_enemy_killed)
	combat_model.spawn_timer = 2.8 + lane_index * 1.15
	combat_model.spawn_enemy(3.6 + lane_index * 0.55)
	_sync_visuals()

func _process(delta: float) -> void:
	combat_model.update(delta)
	_update_defender_feedback(delta)
	_update_death_effects(delta)
	_sync_visuals()

func fire_for_match(result: Dictionary) -> Dictionary:
	if int(result.get("identity", -1)) != team_identity:
		return {}
	_attack_feedback = 0.3
	return combat_model.fire_attack(result)

func _build_lane() -> void:
	var team_color := TeamData.color(team_identity)
	var floor := PrimitiveFactory.box(Vector3(16.8, 0.12, 1.45), Color(0.1, 0.13, 0.18))
	floor.position.y = -0.1
	add_child(floor)
	var stripe := PrimitiveFactory.box(Vector3(16.8, 0.025, 0.08), team_color.darkened(0.08))
	stripe.position = Vector3(0.0, -0.025, -0.61)
	add_child(stripe)
	var team_marker := PrimitiveFactory.cylinder(0.38, 0.38, 0.035, team_color, 20)
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
	body.position.y = 0.42
	_defender_root.add_child(body)
	var head := PrimitiveFactory.sphere(0.31, 0.62, color_value.lightened(0.08))
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

func _sync_visuals() -> void:
	var live_enemy_ids := {}
	for enemy in combat_model.enemies:
		var uid := int(enemy.uid)
		live_enemy_ids[uid] = true
		if not _enemy_visuals.has(uid):
			_enemy_visuals[uid] = _create_enemy_visual(uid, int(enemy.max_hp))
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

func _create_enemy_visual(uid: int, max_hp: int) -> Dictionary:
	var shadow := PrimitiveFactory.cylinder(0.37, 0.37, 0.025, Color(0.015, 0.02, 0.03, 0.58), 20)
	shadow.name = "EnemyShadow_%d" % uid
	shadow.position.y = 0.01
	add_child(shadow)

	var root := Node3D.new()
	root.name = "Enemy_%d" % uid
	add_child(root)
	var body := PrimitiveFactory.sphere(0.4, 0.8, Color(0.23, 0.25, 0.31))
	body.position.y = 0.35
	root.add_child(body)
	var helmet := PrimitiveFactory.cylinder(0.34, 0.43, 0.4, Color(0.12, 0.14, 0.19), 8)
	helmet.position.y = 0.72
	root.add_child(helmet)
	for side in [-1.0, 1.0]:
		var eye := PrimitiveFactory.sphere(0.045, 0.09, Color(1.0, 0.44, 0.24))
		eye.position = Vector3(side * 0.13, 0.7, 0.34)
		root.add_child(eye)
	var pips: Array[MeshInstance3D] = []
	for hp_index in range(max_hp):
		var pip := PrimitiveFactory.box(Vector3(0.16, 0.07, 0.08), Color(1.0, 0.34, 0.24))
		pip.position = Vector3((hp_index - (max_hp - 1) * 0.5) * 0.2, 1.08, 0.0)
		root.add_child(pip)
		pips.append(pip)
	return {"root": root, "shadow": shadow, "pips": pips}

func _update_enemy_visual(visual: Dictionary, enemy: Dictionary) -> void:
	var root: Node3D = visual.root
	var shadow: MeshInstance3D = visual.shadow
	var hop_phase := fmod(float(enemy.hop_clock), PI)
	var hop_height := sin(hop_phase) * 0.52
	var landing_amount := pow(absf(cos(hop_phase)), 10.0)
	var hit_amount := clampf(float(enemy.hit_flash) / 0.16, 0.0, 1.0)
	root.position = Vector3(float(enemy.x), 0.29 + hop_height, 0.0)
	root.scale = Vector3(1.0 + landing_amount * 0.12 + hit_amount * 0.16, 1.0 - landing_amount * 0.16 - hit_amount * 0.08, 1.0 + landing_amount * 0.12 + hit_amount * 0.16)
	shadow.position.x = float(enemy.x)
	shadow.scale = Vector3(1.0 - hop_height * 0.35, 1.0, 1.0 - hop_height * 0.35)
	var pips: Array = visual.pips
	for index in range(pips.size()):
		pips[index].visible = index < int(enemy.hp)

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
	var amount := clampf(_attack_feedback / 0.3, 0.0, 1.0)
	var lunge := sin(amount * PI) * 0.28
	_defender_root.position.x = LaneCombatModel.DEFENDER_X + lunge
	_defender_root.rotation_degrees.z = -lunge * 9.0
	_muzzle_flash.visible = amount > 0.12
	_muzzle_flash.scale = Vector3.ONE * (0.55 + amount * 0.9)

func _on_enemy_killed(_enemy_uid: int, impact_x: float) -> void:
	var effect := Node3D.new()
	effect.name = "EnemyDefeatBurst"
	effect.position = Vector3(impact_x, 0.62, 0.0)
	for direction in [-1.0, 0.0, 1.0]:
		var spark := PrimitiveFactory.sphere(0.09, 0.18, Color(1.0, 0.42, 0.18))
		spark.position = Vector3(direction * 0.18, absf(direction) * 0.12, direction * 0.08)
		effect.add_child(spark)
	add_child(effect)
	_death_effects.append({"node": effect, "age": 0.0})

func _update_death_effects(delta: float) -> void:
	for index in range(_death_effects.size() - 1, -1, -1):
		var effect := _death_effects[index]
		effect.age = float(effect.age) + delta
		var node: Node3D = effect.node
		node.position.y += delta * 0.8
		node.scale = Vector3.ONE * maxf(0.0, 1.0 - float(effect.age) / 0.32)
		if float(effect.age) >= 0.32:
			node.queue_free()
			_death_effects.remove_at(index)
		else:
			_death_effects[index] = effect

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
