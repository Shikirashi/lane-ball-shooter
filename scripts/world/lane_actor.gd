class_name LaneActor
extends Control

const EnemyTypes = preload("res://scripts/world/enemy_types.gd")
const ActorVisualFactory = preload("res://scripts/world/actor_visual_factory.gd")

signal enemy_death_started(identity: int, enemy_uid: int, impact_x: float, cause: StringName)

const STATE_EFFECT_DURATION := 0.45
const DEATH_EFFECT_DURATION := 1.0
const DEATH_FALL_DURATION := 0.5
const HEALING_AURA_DURATION := 0.85
const MASTER_SIZE := Vector2(512.0, 512.0)
const ASSET_DIR := "res://assets/sprites/baked"
const ENEMY_ASSETS := ["enemy_hopper", "enemy_heavy", "enemy_sickle_snake", "enemy_healyzard"]
const DEFENDER_ASSETS := ["defender_red", "defender_blue", "defender_yellow", "defender_green"]

static var _pivot_metadata := {}

var team_identity := 0
var lane_index := 0
var combat_model: LaneCombatModel
var external_spawn_control := false

var _side_margin_ratio := ResponsiveLayout.BATTLEFIELD_SIDE_MARGIN_RATIO
var _baseline_y := 72.0
var _actor_scale := 0.24
var _defender_root: Node2D
var _defender_sprite: Sprite2D
var _spent_charge_cover: Polygon2D
var _status_label: Label
var _enemy_visuals := {}
var _projectile_visuals := {}
var _death_effects: Array[Dictionary] = []
var _death_uids := {}
var _state_effects: Array[Dictionary] = []
var _attack_feedback := 0.0
var _revive_feedback := 0.0
var _last_status_key := ""
var _visual_time := 0.0


func setup(identity: int, index: int, director_controls_spawns := false) -> void:
	team_identity = posmod(identity, TeamData.COUNT)
	lane_index = index
	external_spawn_control = director_controls_spawns
	combat_model = LaneCombatModel.new(team_identity)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if combat_model == null:
		combat_model = LaneCombatModel.new(team_identity)
	_load_pivot_metadata()
	_build_defender()
	combat_model.enemy_neutralized_detail.connect(_on_enemy_neutralized_detail)
	combat_model.healer_pulsed.connect(_on_healer_pulsed)
	combat_model.defender_knocked_down.connect(_on_defender_knocked_down)
	combat_model.emergency_discharged.connect(_on_emergency_discharged)
	combat_model.defender_revived.connect(_on_defender_revived)
	if external_spawn_control:
		combat_model.clear_for_test()
	else:
		combat_model.reset_run(3.6 + lane_index * 0.55, 2.8 + lane_index * 1.15)
	configure_layout(size if size.y > 1.0 else Vector2(960.0, 90.0), _side_margin_ratio)
	_sync_visuals()
	_update_status_visual()


func _process(delta: float) -> void:
	_visual_time += maxf(delta, 0.0)
	_update_healing_auras(delta)
	combat_model.update(delta)
	_update_defender_feedback(delta)
	_update_death_effects(delta)
	_update_state_effects(delta)
	_sync_visuals()
	_update_status_visual()
	queue_redraw()


func configure_layout(layout_size: Vector2, side_margin_ratio := ResponsiveLayout.BATTLEFIELD_SIDE_MARGIN_RATIO) -> void:
	size = layout_size.max(Vector2.ONE)
	_side_margin_ratio = clampf(side_margin_ratio, 0.04, 0.07)
	_baseline_y = size.y * 0.82
	_actor_scale = clampf(size.y / 380.0, 0.14, 0.42)
	if is_instance_valid(_defender_root):
		_update_defender_feedback(0.0)
	if is_instance_valid(_status_label):
		_status_label.position = Vector2(world_x_to_local(-4.8), maxf(1.0, size.y * 0.02))
		_status_label.size = Vector2(maxf(190.0, size.x * 0.28), maxf(22.0, size.y * 0.25))
		_status_label.add_theme_font_size_override("font_size", clampi(roundi(size.y * 0.105), 10, 17))
	for visual in _enemy_visuals.values():
		_configure_enemy_scale(visual)
	for uid in _projectile_visuals:
		_configure_projectile_shape(_projectile_visuals[uid])
	_sync_visuals()
	queue_redraw()


func world_x_to_local(x_value: float) -> float:
	var left := size.x * _side_margin_ratio
	var right := size.x * (1.0 - _side_margin_ratio)
	var ratio := inverse_lerp(LaneCombatModel.LEFT_BOUNDARY, LaneCombatModel.PROJECTILE_RIGHT_BOUNDARY, x_value)
	return lerpf(left, right, ratio)


func local_to_world_x(local_x: float) -> float:
	var left := size.x * _side_margin_ratio
	var right := size.x * (1.0 - _side_margin_ratio)
	return lerpf(LaneCombatModel.LEFT_BOUNDARY, LaneCombatModel.PROJECTILE_RIGHT_BOUNDARY, inverse_lerp(left, right, local_x))


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
	_state_effects.append({"age": 0.0, "kind": "tier3", "world_x": 0.0})
	queue_redraw()


func enemy_hop_height(enemy: Dictionary) -> float:
	if not bool(enemy.get("hop_airborne", false)):
		return 0.0
	return sin(float(enemy.get("hop_progress", 0.0)) * PI) * 0.52


func reset_run(spawn_initial := true) -> void:
	for visual in _enemy_visuals.values():
		_free_visual_nodes(visual)
	for visual in _projectile_visuals.values():
		var projectile_node: Node = visual.get("root")
		if is_instance_valid(projectile_node):
			projectile_node.queue_free()
	for effect in _death_effects:
		_free_visual_nodes(effect)
	_enemy_visuals.clear()
	_projectile_visuals.clear()
	_death_effects.clear()
	_death_uids.clear()
	_state_effects.clear()
	_attack_feedback = 0.0
	_revive_feedback = 0.0
	_visual_time = 0.0
	if spawn_initial:
		combat_model.reset_run(3.6 + lane_index * 0.55, 2.8 + lane_index * 1.15)
	else:
		combat_model.clear_for_test()
	_sync_visuals()
	_last_status_key = ""
	_update_status_visual()
	queue_redraw()


func _draw() -> void:
	var panel := Rect2(0.0, 1.0, size.x, maxf(1.0, size.y - 2.0))
	var lane_color := TeamData.color(team_identity)
	draw_rect(panel, Color(0.055 + lane_index * 0.006, 0.075, 0.115, 0.98), true)
	draw_rect(Rect2(0.0, _baseline_y + 3.0, size.x, maxf(2.0, size.y - _baseline_y - 3.0)), Color(0.085, 0.11, 0.16, 0.98), true)
	draw_line(Vector2(size.x * _side_margin_ratio, _baseline_y + 2.0), Vector2(size.x * (1.0 - _side_margin_ratio), _baseline_y + 2.0), lane_color.darkened(0.08), maxf(2.0, size.y * 0.035))
	draw_line(Vector2(0.0, 0.5), Vector2(size.x, 0.5), Color(0.21, 0.27, 0.38, 0.72), 1.0)
	var marker_center := Vector2(world_x_to_local(LaneCombatModel.LEFT_BOUNDARY + 0.18), _baseline_y - size.y * 0.20)
	draw_circle(marker_center, clampf(size.y * 0.12, 7.0, 15.0), Color(lane_color, 0.92))
	TeamData.draw_symbol(self, team_identity, marker_center, clampf(size.y * 0.12, 7.0, 15.0), Color(0.05, 0.065, 0.095, 0.9))
	_draw_state_effects()
	_draw_death_bursts()
	if _attack_feedback > 0.0 and combat_model.defender_state == LaneCombatModel.DefenderState.ACTIVE:
		var amount := clampf(_attack_feedback / 0.3, 0.0, 1.0)
		var muzzle := _defender_root.position + Vector2(size.y * 0.35, -size.y * 0.22)
		draw_circle(muzzle, size.y * (0.035 + amount * 0.055), Color(1.0, 0.9, 0.45, amount))


func _build_defender() -> void:
	_defender_root = Node2D.new()
	_defender_root.name = "Defender_%s" % TeamData.display_name(team_identity)
	add_child(_defender_root)
	_defender_sprite = _make_actor_sprite(DEFENDER_ASSETS[team_identity])
	_defender_sprite.name = "DefenderSprite_%s" % TeamData.display_name(team_identity)
	_defender_root.add_child(_defender_sprite)
	_spent_charge_cover = _ellipse_polygon(Vector2(31.0, 31.0), Color(0.12, 0.135, 0.17, 0.99), 24)
	_spent_charge_cover.name = "SpentChargeCover"
	# Kept as an optional authored-orb mask. The shipped spent state dims the
	# complete baked defender as well, so the yellow orb cannot read as charged
	# after rotations such as knockdown.
	_spent_charge_cover.position = Vector2(-130.0, -197.0)
	_spent_charge_cover.z_index = 3
	_defender_root.add_child(_spent_charge_cover)
	_status_label = Label.new()
	_status_label.name = "LaneStatus"
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_label.modulate = TeamData.color(team_identity).lightened(0.2)
	add_child(_status_label)


func _sync_visuals() -> void:
	var live_enemy_ids := {}
	for enemy in combat_model.enemies:
		var uid := int(enemy.uid)
		live_enemy_ids[uid] = true
		if _enemy_visuals.has(uid) and int(_enemy_visuals[uid].get("type", EnemyTypes.Type.HOPPER)) != int(enemy.get("type", EnemyTypes.Type.HOPPER)):
			_free_enemy_visual(uid)
		if not _enemy_visuals.has(uid):
			_enemy_visuals[uid] = _create_enemy_visual(uid, int(enemy.get("type", EnemyTypes.Type.HOPPER)))
		_update_enemy_visual(_enemy_visuals[uid], enemy)
	for uid in _enemy_visuals.keys().duplicate():
		if not live_enemy_ids.has(uid):
			_free_enemy_visual(uid)

	var live_projectile_ids := {}
	for projectile in combat_model.projectiles:
		if bool(projectile.get("collision_proxy", false)):
			continue
		var uid := int(projectile.uid)
		live_projectile_ids[uid] = true
		if not _projectile_visuals.has(uid):
			_projectile_visuals[uid] = _create_projectile_visual(uid, projectile)
		var visual: Dictionary = _projectile_visuals[uid]
		var root_node: Node2D = visual.root
		root_node.visible = float(projectile.launch_delay) <= 0.0
		root_node.position = Vector2(world_x_to_local(float(projectile.x)), _baseline_y - size.y * 0.28)
		visual.projectile = projectile.duplicate(true)
		_projectile_visuals[uid] = visual
	for uid in _projectile_visuals.keys().duplicate():
		if not live_projectile_ids.has(uid):
			var projectile_node: Node = _projectile_visuals[uid].root
			projectile_node.queue_free()
			_projectile_visuals.erase(uid)


func _create_enemy_visual(uid: int, enemy_type: int) -> Dictionary:
	var root_node := Node2D.new()
	root_node.name = "%s_%d" % [EnemyTypes.display_name(enemy_type).replace(" ", ""), uid]
	root_node.z_index = 4
	add_child(root_node)
	var sprite := _make_actor_sprite(ENEMY_ASSETS[enemy_type])
	sprite.name = "ActorSprite"
	root_node.add_child(sprite)
	var shadow := _ellipse_polygon(Vector2.ONE, Color(0.01, 0.018, 0.03, 0.52), 24)
	shadow.name = "EnemyShadow_%d" % uid
	shadow.z_index = 2
	add_child(shadow)
	var aura: Sprite2D
	if enemy_type == EnemyTypes.Type.HEALYZARD:
		aura = Sprite2D.new()
		aura.name = "HealingAura"
		aura.texture = healing_aura_texture()
		aura.visible = false
		aura.z_index = -1
		root_node.add_child(aura)
	var visual := {"root": root_node, "sprite": sprite, "shadow": shadow, "aura": aura, "aura_age": -1.0, "type": enemy_type, "base_scale": _actor_scale}
	_configure_enemy_scale(visual)
	return visual


func _configure_enemy_scale(visual: Dictionary) -> void:
	visual.base_scale = _actor_scale
	var root_node: Node2D = visual.root
	root_node.scale = Vector2.ONE * _actor_scale
	var aura := visual.get("aura") as Sprite2D
	if aura != null:
		aura.scale = Vector2.ONE * 5.0


func _update_enemy_visual(visual: Dictionary, enemy: Dictionary) -> void:
	var root_node: Node2D = visual.root
	var sprite: Sprite2D = visual.sprite
	var shadow: Polygon2D = visual.shadow
	var enemy_type := int(enemy.get("type", EnemyTypes.Type.HOPPER))
	var hop_progress := float(enemy.get("hop_progress", 0.0))
	var hop_ratio := sin(hop_progress * PI) if bool(enemy.get("hop_airborne", false)) else 0.0
	var transfer_rows := float(enemy.get("transfer_visual_z", 0.0)) * 0.5
	var transfer_y := transfer_rows * size.y
	var landing_amount := (0.16 if not bool(enemy.get("hop_airborne", false)) else pow(absf(cos(hop_progress * PI)), 10.0)) if EnemyTypes.uses_hop(enemy_type) else 0.0
	var hit_amount := clampf(float(enemy.get("hit_flash", 0.0)) / 0.16, 0.0, 1.0)
	var idle := _visual_time + float(int(enemy.get("spawn_id", 0)) % 17) * 0.17
	var base_scale := float(visual.base_scale)
	var scale_value := Vector2.ONE
	if enemy_type == EnemyTypes.Type.HOPPER:
		scale_value = Vector2(1.0 + landing_amount * 0.22 + hit_amount * 0.15, 1.0 - landing_amount * 0.18 - hit_amount * 0.08)
	elif enemy_type == EnemyTypes.Type.HEAVY:
		scale_value = Vector2(1.05 + sin(idle * 2.0) * 0.025, 0.98 - sin(idle * 2.0) * 0.018)
	elif enemy_type == EnemyTypes.Type.SICKLE_SNAKE:
		scale_value = Vector2(0.98 + sin(idle * 5.0) * 0.035, 1.02 - sin(idle * 5.0) * 0.025)
		root_node.rotation = sin(idle * 5.0) * 0.035
	else:
		scale_value = Vector2.ONE * (1.0 + sin(idle * 2.6) * 0.025)
	root_node.scale = Vector2(base_scale * scale_value.x, base_scale * scale_value.y)
	root_node.position = Vector2(world_x_to_local(float(enemy.x)), _baseline_y - hop_ratio * size.y * 0.30 + transfer_y)
	shadow.position = Vector2(world_x_to_local(float(enemy.x)), _baseline_y + transfer_y)
	var width_multiplier := 1.28 if enemy_type == EnemyTypes.Type.HEAVY else (0.72 if enemy_type == EnemyTypes.Type.HEALYZARD else 1.0)
	shadow.scale = Vector2(size.y * 0.19 * width_multiplier * (1.0 - hop_ratio * 0.25), size.y * 0.045 * (1.0 - hop_ratio * 0.2))
	sprite.modulate = Color(1.0, 1.0 - hit_amount * 0.38, 1.0 - hit_amount * 0.38, 1.0)


func _free_enemy_visual(uid: int) -> void:
	var visual: Dictionary = _enemy_visuals[uid]
	_free_visual_nodes(visual)
	_enemy_visuals.erase(uid)


func _free_visual_nodes(visual: Dictionary) -> void:
	for key in ["root", "shadow"]:
		var visual_node: Node = visual.get(key)
		if is_instance_valid(visual_node):
			visual_node.queue_free()


func take_enemy_visual(uid: int) -> Dictionary:
	if not _enemy_visuals.has(uid):
		return {}
	var visual: Dictionary = _enemy_visuals[uid]
	_enemy_visuals.erase(uid)
	return visual


func adopt_enemy_visual(uid: int, visual: Dictionary) -> void:
	if visual.is_empty():
		return
	var root_node: Node2D = visual.root
	var shadow_node: Node2D = visual.shadow
	root_node.reparent(self, false)
	shadow_node.reparent(self, false)
	root_node.name = "%s_%d" % [EnemyTypes.display_name(int(visual.type)).replace(" ", ""), uid]
	shadow_node.name = "EnemyShadow_%d" % uid
	_configure_enemy_scale(visual)
	_enemy_visuals[uid] = visual


static func healing_aura_texture() -> ImageTexture:
	return ActorVisualFactory.healing_aura_texture()


func _on_healer_pulsed(event: Dictionary) -> void:
	var healer_uid := int(event.get("healer_uid", -1))
	if not _enemy_visuals.has(healer_uid):
		return
	var visual: Dictionary = _enemy_visuals[healer_uid]
	var aura := visual.get("aura") as Sprite2D
	if aura == null:
		return
	visual.aura_age = 0.0
	aura.visible = true
	aura.scale = Vector2.ONE * 5.0
	aura.modulate = Color(1.0, 0.88, 0.18, 0.8)
	_enemy_visuals[healer_uid] = visual


func _update_healing_auras(delta: float) -> void:
	for uid in _enemy_visuals.keys():
		var visual: Dictionary = _enemy_visuals[uid]
		var aura := visual.get("aura") as Sprite2D
		if aura == null or float(visual.get("aura_age", -1.0)) < 0.0:
			continue
		visual.aura_age = float(visual.aura_age) + delta
		var ratio := clampf(float(visual.aura_age) / HEALING_AURA_DURATION, 0.0, 1.0)
		aura.scale = Vector2.ONE * lerpf(5.0, 7.2, ratio)
		aura.modulate = Color(1.0, 0.88, 0.18, (1.0 - ratio) * 0.8)
		if ratio >= 1.0:
			aura.visible = false
			visual.aura_age = -1.0
		_enemy_visuals[uid] = visual


func _create_projectile_visual(uid: int, projectile := {}) -> Dictionary:
	var root_node := Node2D.new()
	root_node.name = "Projectile_%d" % uid
	root_node.z_index = 8
	add_child(root_node)
	var visual := {"root": root_node, "shape": null, "projectile": projectile.duplicate(true)}
	_projectile_visuals[uid] = visual
	_configure_projectile_shape(visual)
	return visual


func _configure_projectile_shape(visual: Dictionary) -> void:
	var root_node: Node2D = visual.root
	for child in root_node.get_children():
		child.queue_free()
	var projectile: Dictionary = visual.projectile
	var color_value := TeamData.color(team_identity).lightened(0.2)
	var shape: Polygon2D
	if bool(projectile.get("wide", false)):
		var direction := signf(float(int(projectile.get("adjacent_lane", lane_index)) - lane_index))
		var near_y := -size.y * 0.22
		var far_y := direction * size.y + size.y * 0.22
		shape = Polygon2D.new()
		shape.polygon = PackedVector2Array([Vector2(-18.0, near_y), Vector2(18.0, near_y), Vector2(18.0, far_y), Vector2(-18.0, far_y)])
		shape.color = Color(color_value, 0.68)
	elif bool(projectile.get("piercing", false)):
		shape = _ellipse_polygon(Vector2(size.y * 0.14, size.y * 0.075), color_value, 20)
	else:
		shape = _ellipse_polygon(Vector2(size.y * 0.075, size.y * 0.075), color_value, 18)
	shape.name = "ProjectileShape"
	root_node.add_child(shape)
	visual.shape = shape


func _update_defender_feedback(delta: float) -> void:
	_attack_feedback = maxf(0.0, _attack_feedback - delta)
	_revive_feedback = maxf(0.0, _revive_feedback - delta)
	if not is_instance_valid(_defender_root):
		return
	var base_position := Vector2(world_x_to_local(LaneCombatModel.DEFENDER_X), _baseline_y)
	if combat_model.defender_state == LaneCombatModel.DefenderState.DOWN:
		_defender_root.position = base_position + Vector2(size.y * 0.11, -size.y * 0.18)
		_defender_root.rotation = deg_to_rad(78.0)
		_defender_root.scale = Vector2(_actor_scale, _actor_scale * 0.82)
		return
	var amount := clampf(_attack_feedback / 0.3, 0.0, 1.0)
	var lunge := sin(amount * PI) * size.y * 0.16
	var revive_amount := clampf(_revive_feedback / 0.5, 0.0, 1.0)
	_defender_root.position = base_position + Vector2(lunge, -sin(revive_amount * PI) * size.y * 0.12)
	_defender_root.rotation = deg_to_rad(-sin(amount * PI) * 8.0)
	var pulse := 1.0 + sin(revive_amount * PI) * 0.16
	_defender_root.scale = Vector2.ONE * (_actor_scale * pulse)


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
	_spent_charge_cover.visible = false
	_defender_sprite.self_modulate = Color.WHITE if combat_model.emergency_available else Color(0.42, 0.46, 0.52, 0.72)


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
		visual.root.position = Vector2(world_x_to_local(impact_x), _baseline_y)
		visual.shadow.position = Vector2(world_x_to_local(impact_x), _baseline_y)
	var aura := visual.get("aura") as Sprite2D
	if aura != null:
		aura.visible = false
	_death_effects.append({
		"uid": enemy_uid,
		"root": visual.root,
		"sprite": visual.sprite,
		"shadow": visual.shadow,
		"age": 0.0,
		"start_position": visual.root.position,
		"fall_sign": -1.0 if enemy_uid % 2 == 0 else 1.0,
		"burst_position": Vector2(world_x_to_local(impact_x), _baseline_y - size.y * 0.30),
		"burst": true,
	})
	enemy_death_started.emit(team_identity, enemy_uid, impact_x, cause)
	queue_redraw()


func _update_death_effects(delta: float) -> void:
	for index in range(_death_effects.size() - 1, -1, -1):
		var effect := _death_effects[index]
		effect.age = float(effect.age) + delta
		var age := float(effect.age)
		var root_node: Node2D = effect.root
		var sprite: Sprite2D = effect.sprite
		var shadow: Polygon2D = effect.shadow
		var fall_ratio := clampf(age / DEATH_FALL_DURATION, 0.0, 1.0)
		var eased_fall := 1.0 - pow(1.0 - fall_ratio, 3.0)
		var start_position: Vector2 = effect.start_position
		root_node.rotation = float(effect.fall_sign) * (PI * 0.47) * eased_fall
		root_node.position = start_position + Vector2(float(effect.fall_sign) * size.y * 0.12 * eased_fall, size.y * 0.08 * eased_fall)
		shadow.position.x = root_node.position.x
		shadow.scale.x *= 1.0 + delta * 0.35
		var fade := 1.0 - clampf((age - 0.52) / (DEATH_EFFECT_DURATION - 0.52), 0.0, 1.0)
		sprite.modulate.a = fade
		shadow.modulate.a = fade
		if age >= DEATH_EFFECT_DURATION:
			root_node.queue_free()
			shadow.queue_free()
			_death_effects.remove_at(index)
		else:
			_death_effects[index] = effect
	queue_redraw()


func _on_defender_knocked_down(_identity: int) -> void:
	_attack_feedback = 0.0
	_update_status_visual()


func _on_emergency_discharged(_identity: int, _cleared_count: int) -> void:
	_state_effects.append({"age": 0.0, "kind": "discharge", "world_x": LaneCombatModel.DEFENDER_X})
	_update_status_visual()
	queue_redraw()


func _on_defender_revived(_identity: int, _repelled_count: int) -> void:
	_revive_feedback = 0.5
	_state_effects.append({"age": 0.0, "kind": "revive", "world_x": LaneCombatModel.DEFENDER_X})
	_update_status_visual()
	queue_redraw()


func _update_state_effects(delta: float) -> void:
	for index in range(_state_effects.size() - 1, -1, -1):
		_state_effects[index].age = float(_state_effects[index].age) + delta
		if float(_state_effects[index].age) >= STATE_EFFECT_DURATION:
			_state_effects.remove_at(index)
	queue_redraw()


func _draw_state_effects() -> void:
	for effect in _state_effects:
		var ratio := clampf(float(effect.age) / STATE_EFFECT_DURATION, 0.0, 1.0)
		var effect_color := Color(TeamData.color(team_identity).lightened(0.35), (1.0 - ratio) * 0.75)
		if str(effect.kind) == "tier3":
			draw_rect(Rect2(0.0, size.y * 0.18, size.x, size.y * 0.58), effect_color, false, maxf(2.0, size.y * 0.04))
		else:
			var center := Vector2(world_x_to_local(float(effect.world_x)), _baseline_y - size.y * 0.25)
			var radius := size.y * (0.14 + ratio * (1.25 if str(effect.kind) == "discharge" else 0.55))
			draw_arc(center, radius, 0.0, TAU, 40, effect_color, maxf(2.0, size.y * 0.035))


func _draw_death_bursts() -> void:
	for effect in _death_effects:
		var ratio := clampf(float(effect.age) / 0.38, 0.0, 1.0)
		if ratio >= 1.0:
			continue
		var center: Vector2 = effect.burst_position
		var alpha := (1.0 - ratio) * 0.95
		draw_circle(center, size.y * (0.08 + ratio * 0.18), Color(1.0, 0.6, 0.14, alpha))
		for spark_index in range(8):
			var angle := TAU * float(spark_index) / 8.0
			var distance := size.y * (0.08 + ratio * 0.32)
			draw_circle(center + Vector2(cos(angle), sin(angle)) * distance, maxf(1.5, size.y * 0.028 * (1.0 - ratio)), Color(1.0, 0.32 + 0.05 * (spark_index % 3), 0.06, alpha))


func _make_actor_sprite(asset_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	var path := "%s/%s.png" % [ASSET_DIR, asset_name]
	sprite.texture = load(path) as Texture2D
	var actor_data: Dictionary = _pivot_metadata.get("actors", {}).get(asset_name, {})
	var pivot: Array = actor_data.get("pivot", [256, 419])
	sprite.offset = MASTER_SIZE * 0.5 - Vector2(float(pivot[0]), float(pivot[1]))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.z_index = 2
	return sprite


static func _load_pivot_metadata() -> void:
	if not _pivot_metadata.is_empty():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("%s/pivots.json" % ASSET_DIR))
	if parsed is Dictionary:
		_pivot_metadata = parsed


static func _ellipse_polygon(radius: Vector2, color_value: Color, points := 24) -> Polygon2D:
	var polygon := Polygon2D.new()
	var vertices := PackedVector2Array()
	for index in range(points):
		var angle := TAU * float(index) / float(points)
		vertices.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	polygon.polygon = vertices
	polygon.color = color_value
	return polygon
