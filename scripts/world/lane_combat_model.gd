class_name LaneCombatModel
extends RefCounted

const EnemyTypes = preload("res://scripts/world/enemy_types.gd")

signal enemy_spawned(enemy: Dictionary)
signal enemy_hit(enemy_uid: int, remaining_hp: int, impact_x: float)
signal enemy_killed(enemy_uid: int, impact_x: float)
signal enemy_neutralized(enemy_uid: int, impact_x: float, cause: StringName)
signal enemy_neutralized_detail(enemy: Dictionary, cause: StringName, impact_x: float)
signal healer_pulsed(event: Dictionary)
signal projectile_spawned(projectile: Dictionary)
signal defender_knocked_down(identity: int)
signal emergency_discharged(identity: int, cleared_count: int)
signal revival_progressed(identity: int, progress: int, required: int)
signal defender_revived(identity: int, repelled_count: int)
signal breached(identity: int, enemy_uid: int)
signal encounter_state_changed

enum DefenderState { ACTIVE, DOWN }

const DEFENDER_X := -5.9
const PROJECTILE_START_X := -5.25
const LEFT_BOUNDARY := -7.25
const RIGHT_BOUNDARY := 7.6
const PROJECTILE_RIGHT_BOUNDARY := 8.25
const DEFAULT_ENEMY_SPEED := 0.312
const DEFAULT_ENEMY_HP := 3
const DEFAULT_PROJECTILE_SPEED := 9.0
const DEFAULT_PROJECTILE_DAMAGE := 1
const DEFAULT_SPAWN_INTERVAL := 5.5
const DEFAULT_MAX_ENEMIES := 5
const DEFAULT_ENEMIES_PER_LANE := 8
const PROJECTILE_LIFETIME := 2.2
const BURST_INTERVAL := 0.14
const HIT_DISTANCE := 0.4
const DEFAULT_REVIVAL_REQUIRED := 2
const REVIVAL_REPEL_TRIGGER_DISTANCE := 0.4
const REVIVAL_SAFE_OFFSET := 1.15
const HISTORY_LIMIT := 128
const HOP_GROUND_DURATION := 0.55
const HOP_AIR_DURATION := 0.75
const HOP_CYCLE_DURATION := HOP_GROUND_DURATION + HOP_AIR_DURATION
const SNAKE_HIT_STUN_DURATION := 0.5
const HEALYZARD_PULSE_INTERVAL := 15.0

var team_identity := 0
var enemy_speed := DEFAULT_ENEMY_SPEED
var enemy_max_hp := DEFAULT_ENEMY_HP
var projectile_speed := DEFAULT_PROJECTILE_SPEED
var projectile_damage := DEFAULT_PROJECTILE_DAMAGE
var spawn_interval := DEFAULT_SPAWN_INTERVAL
var max_enemies := DEFAULT_MAX_ENEMIES
var enemy_spawn_budget := DEFAULT_ENEMIES_PER_LANE
var spawned_this_encounter := 0
var auto_spawn := true
var spawn_timer := DEFAULT_SPAWN_INTERVAL
var defender_state := DefenderState.ACTIVE
var emergency_available := true
var revival_progress := 0
var revival_required := DEFAULT_REVIVAL_REQUIRED
var game_over := false

var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var attack_history: Array[Dictionary] = []
var hit_history: Array[Dictionary] = []
var total_spawned := 0
var total_killed := 0
var total_emergency_cleared := 0
var total_breaches := 0

var _next_enemy_uid := 1
var _next_projectile_uid := 1
var _next_attack_uid := 1

func _init(identity_value := 0) -> void:
	team_identity = posmod(identity_value, TeamData.COUNT)

func fire_attack(match_result: Dictionary) -> Dictionary:
	if game_over or defender_state != DefenderState.ACTIVE:
		return {}
	var locked_tier := clampi(int(match_result.get("tier", 1)), 1, 3)
	var projectile_count := 1
	var locked_damage := DEFAULT_PROJECTILE_DAMAGE
	var piercing := locked_tier >= 2
	var wide := locked_tier >= 3
	var attack := {
		"uid": _next_attack_uid,
		"identity": team_identity,
		"tier": locked_tier,
		"fever": bool(match_result.get("fever", false)),
		"group_size": int(match_result.get("group_size", 3)),
		"projectile_count": projectile_count,
		"projectile_damage": locked_damage,
		"piercing": piercing,
		"wide": wide,
		"origin_lane": int(match_result.get("origin_lane", team_identity)),
		"adjacent_lane": int(match_result.get("adjacent_lane", -1)),
		"target_lanes": match_result.get("target_lanes", [team_identity]).duplicate(),
	}
	_next_attack_uid += 1
	attack_history.append(attack.duplicate(true))
	_trim_history(attack_history)
	_spawn_projectile(int(attack.uid), 0.0, locked_damage, locked_tier, piercing, wide, false, {}, attack)
	return attack.duplicate(true)

func handle_match(match_result: Dictionary) -> Dictionary:
	if game_over or int(match_result.get("identity", -1)) != team_identity:
		return {"action": "ignored"}
	var breached_uid := _enemy_already_breached()
	if breached_uid >= 0:
		_trigger_breach(breached_uid)
		return {"action": "breach"}
	if defender_state == DefenderState.ACTIVE:
		var attack := fire_attack(match_result)
		return {"action": "attack", "attack": attack}

	revival_progress = mini(revival_progress + 1, revival_required)
	var completed := revival_progress >= revival_required
	revival_progressed.emit(team_identity, revival_progress, revival_required)
	if completed:
		defender_state = DefenderState.ACTIVE
		revival_progress = 0
		var repelled_count := _repel_nearby_enemies()
		defender_revived.emit(team_identity, repelled_count)
	return {"action": "revival", "revived": completed, "progress": revival_progress}

## Manual/test spawns count against the encounter quota by default. Tests that
## need an out-of-budget fixture may explicitly pass counts_toward_budget=false.
func spawn_enemy(x_position := RIGHT_BOUNDARY, hp_value := -1, counts_toward_budget := true, enemy_type := EnemyTypes.Type.HOPPER, spawn_id := -1) -> int:
	if enemies.size() >= max_enemies:
		return -1
	if counts_toward_budget and spawned_this_encounter >= enemy_spawn_budget:
		return -1
	var resolved_type := enemy_type if EnemyTypes.valid_type(enemy_type) else EnemyTypes.Type.HOPPER
	var canonical_hp := EnemyTypes.max_hp(resolved_type)
	var resolved_hp := canonical_hp if hp_value < 0 else clampi(hp_value, 1, canonical_hp)
	var enemy := {
		"uid": _next_enemy_uid,
		"spawn_id": spawn_id if spawn_id >= 0 else team_identity * 1000000 + _next_enemy_uid,
		"type": resolved_type,
		"origin_lane": team_identity,
		"lane_index": team_identity,
		"x": x_position,
		"hp": resolved_hp,
		"max_hp": canonical_hp,
		"speed": EnemyTypes.speed(resolved_type, enemy_speed),
		"hop_clock": fmod(float(_next_enemy_uid - 1) * 0.31 + float(team_identity) * 0.17, HOP_CYCLE_DURATION),
		"hop_airborne": false,
		"hop_progress": 0.0,
		"hit_flash": 0.0,
		"special_state": &"moving",
		"special_timer": 0.0,
		"preferred_lane": -1,
		"transfer_visual_z": 0.0,
		"frame_move_fraction": 1.0,
		"heal_timer": HEALYZARD_PULSE_INTERVAL,
	}
	_sync_enemy_motion_state(enemy)
	_next_enemy_uid += 1
	total_spawned += 1
	if counts_toward_budget:
		spawned_this_encounter += 1
	enemies.append(enemy)
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.x) < float(b.x))
	enemy_spawned.emit(enemy.duplicate(true))
	encounter_state_changed.emit()
	return int(enemy.uid)

func update(delta: float) -> void:
	if game_over:
		return
	var already_breached_uid := _enemy_already_breached()
	if already_breached_uid >= 0:
		_trigger_breach(already_breached_uid)
		return
	var step := maxf(delta, 0.0)
	var enemy_starts := {}
	for enemy in enemies:
		enemy_starts[int(enemy.uid)] = float(enemy.x)
	_update_projectiles(step, enemy_starts)
	_update_enemies(step)
	_update_spawning(step)

func clear_for_test() -> void:
	auto_spawn = false
	enemies.clear()
	projectiles.clear()
	attack_history.clear()
	hit_history.clear()
	total_spawned = 0
	spawned_this_encounter = 0
	total_killed = 0
	total_emergency_cleared = 0
	total_breaches = 0
	spawn_timer = spawn_interval
	defender_state = DefenderState.ACTIVE
	emergency_available = true
	revival_progress = 0
	game_over = false
	_next_enemy_uid = 1
	_next_projectile_uid = 1
	_next_attack_uid = 1

func reset_run(initial_enemy_x := NAN, initial_spawn_delay := DEFAULT_SPAWN_INTERVAL) -> void:
	clear_for_test()
	auto_spawn = true
	spawn_timer = initial_spawn_delay
	if not is_nan(initial_enemy_x):
		spawn_enemy(initial_enemy_x)

func set_game_over(value: bool) -> void:
	game_over = value

func set_enemy_spawn_budget(value: int) -> void:
	enemy_spawn_budget = maxi(0, value)
	spawned_this_encounter = mini(spawned_this_encounter, enemy_spawn_budget)
	encounter_state_changed.emit()

func remaining_to_spawn() -> int:
	return maxi(0, enemy_spawn_budget - spawned_this_encounter)

func encounter_spawn_complete() -> bool:
	return spawned_this_encounter >= enemy_spawn_budget

func total_neutralized() -> int:
	return total_killed + total_emergency_cleared

func encounter_cleared() -> bool:
	return encounter_spawn_complete() and enemies.is_empty()

func active_enemy_count() -> int:
	return enemies.size()

func active_projectile_count() -> int:
	return projectiles.size()

func _spawn_projectile(attack_uid: int, launch_delay: float, locked_damage: int, locked_tier: int, piercing := false, wide := false, collision_proxy := false, shared_hit_spawn_ids := {}, attack_metadata := {}) -> Dictionary:
	var projectile := {
		"uid": _next_projectile_uid,
		"attack_uid": attack_uid,
		"x": PROJECTILE_START_X,
		"damage": locked_damage,
		"tier": locked_tier,
		"age": 0.0,
		"launch_delay": launch_delay,
		"piercing": piercing,
		"wide": wide,
		"collision_proxy": collision_proxy,
		"hit_spawn_ids": shared_hit_spawn_ids,
		"origin_lane": int(attack_metadata.get("origin_lane", team_identity)),
		"adjacent_lane": int(attack_metadata.get("adjacent_lane", -1)),
		"target_lanes": attack_metadata.get("target_lanes", [team_identity]).duplicate(),
	}
	_next_projectile_uid += 1
	projectiles.append(projectile)
	projectile_spawned.emit(projectile.duplicate(true))
	return projectile

func spawn_wide_projectile_proxy(source_projectile: Dictionary) -> Dictionary:
	if source_projectile.is_empty():
		return {}
	return _spawn_projectile(
		int(source_projectile.get("attack_uid", -1)),
		float(source_projectile.get("launch_delay", 0.0)),
		int(source_projectile.get("damage", DEFAULT_PROJECTILE_DAMAGE)),
		int(source_projectile.get("tier", 3)),
		true,
		true,
		true,
		source_projectile.get("hit_spawn_ids", {}),
		source_projectile
	)

func _update_projectiles(delta: float, enemy_starts: Dictionary) -> void:
	var survivors: Array[Dictionary] = []
	for projectile in projectiles:
		var delay_before := float(projectile.launch_delay)
		var active_start := minf(delay_before, delta)
		var active_delta := maxf(0.0, delta - active_start)
		projectile.launch_delay = maxf(0.0, delay_before - delta)
		if active_delta <= 0.0:
			survivors.append(projectile)
			continue

		var projectile_start := float(projectile.x)
		var hit_spawn_ids: Dictionary = projectile.get("hit_spawn_ids", {})
		var hits := _swept_hits(projectile_start, active_start, active_delta, enemy_starts, hit_spawn_ids)
		if not hits.is_empty():
			if not bool(projectile.get("piercing", false)):
				var first_hit: Dictionary = hits[0]
				var first_impact_x := projectile_start + projectile_speed * float(first_hit.time)
				_damage_enemy(int(first_hit.enemy_uid), int(projectile.damage), first_impact_x, &"projectile", int(projectile.attack_uid), int(projectile.tier))
				continue
			for hit in hits:
				var spawn_id := int(hit.spawn_id)
				if hit_spawn_ids.has(spawn_id):
					continue
				hit_spawn_ids[spawn_id] = true
				var impact_x := projectile_start + projectile_speed * float(hit.time)
				var cause := &"tier3" if int(projectile.tier) >= 3 else &"projectile"
				_damage_enemy(int(hit.enemy_uid), int(projectile.damage), impact_x, cause, int(projectile.attack_uid), int(projectile.tier))
			projectile.hit_spawn_ids = hit_spawn_ids

		projectile.x = projectile_start + projectile_speed * active_delta
		projectile.age = float(projectile.age) + active_delta
		if float(projectile.x) <= PROJECTILE_RIGHT_BOUNDARY and float(projectile.age) <= PROJECTILE_LIFETIME:
			survivors.append(projectile)
	projectiles = survivors

func _first_swept_hit(projectile_x: float, active_start: float, active_delta: float, enemy_starts: Dictionary) -> Dictionary:
	var hits := _swept_hits(projectile_x, active_start, active_delta, enemy_starts)
	return {} if hits.is_empty() else hits[0]

func _swept_hits(projectile_x: float, active_start: float, active_delta: float, enemy_starts: Dictionary, excluded_spawn_ids := {}) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for enemy in enemies:
		var uid := int(enemy.uid)
		var spawn_id := int(enemy.get("spawn_id", team_identity * 1000000 + uid))
		if excluded_spawn_ids.has(spawn_id) or not enemy_starts.has(uid):
			continue
		if not EnemyTypes.uses_hop(int(enemy.get("type", EnemyTypes.Type.HOPPER))):
			var slide_speed := float(enemy.get("speed", enemy_speed))
			if int(enemy.get("type", EnemyTypes.Type.HOPPER)) == EnemyTypes.Type.SICKLE_SNAKE:
				slide_speed *= float(enemy.get("frame_move_fraction", 1.0)) if StringName(enemy.get("special_state", &"moving")) == &"moving" else 0.0
			var slide_enemy_x := float(enemy_starts[uid]) - slide_speed * active_start
			var relative_start := slide_enemy_x - projectile_x
			var closing_speed := projectile_speed + slide_speed
			var relative_end := relative_start - closing_speed * active_delta
			if relative_start >= -HIT_DISTANCE and relative_end <= HIT_DISTANCE:
				var contact_time := clampf((relative_start - HIT_DISTANCE) / maxf(closing_speed, 0.0001), 0.0, active_delta)
				hits.append({"enemy_uid": uid, "spawn_id": spawn_id, "time": contact_time})
			continue
		var clock_at_active_start := float(enemy.hop_clock) + active_start
		var hopper_speed := float(enemy.get("speed", enemy_speed))
		var enemy_x := float(enemy_starts[uid]) - _hop_displacement(float(enemy.hop_clock), active_start, hopper_speed)
		var elapsed := 0.0
		while elapsed < active_delta - 0.000001:
			var phase := fmod(clock_at_active_start + elapsed, HOP_CYCLE_DURATION)
			var airborne := phase >= HOP_GROUND_DURATION
			var phase_end := HOP_CYCLE_DURATION if airborne else HOP_GROUND_DURATION
			var segment_duration := minf(active_delta - elapsed, phase_end - phase)
			if segment_duration <= 0.000001:
				segment_duration = minf(active_delta - elapsed, 0.000001)
			var enemy_velocity := -_hop_air_speed(hopper_speed) if airborne else 0.0
			var projectile_at_segment := projectile_x + projectile_speed * elapsed
			var relative_start := enemy_x - projectile_at_segment
			var closing_speed := projectile_speed - enemy_velocity
			var relative_end := relative_start - closing_speed * segment_duration
			if relative_start >= -HIT_DISTANCE and relative_end <= HIT_DISTANCE:
				var contact_in_segment := clampf((relative_start - HIT_DISTANCE) / closing_speed, 0.0, segment_duration)
				var contact_time := elapsed + contact_in_segment
				hits.append({"enemy_uid": uid, "spawn_id": spawn_id, "time": contact_time})
				break
			enemy_x += enemy_velocity * segment_duration
			elapsed += segment_duration
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.time), float(b.time)):
			return float(a.time) < float(b.time)
		return int(a.spawn_id) < int(b.spawn_id)
	)
	return hits

func _damage_enemy(enemy_uid: int, damage: int, impact_x: float, cause := &"projectile", attack_uid := -1, tier := 1) -> void:
	for index in range(enemies.size()):
		if int(enemies[index].uid) != enemy_uid:
			continue
		var enemy := enemies[index]
		enemy.hp = int(enemy.hp) - damage
		enemy.hit_flash = 0.16
		hit_history.append({"enemy_uid": enemy_uid, "spawn_id": int(enemy.get("spawn_id", enemy_uid)), "damage": damage, "impact_x": impact_x, "remaining_hp": maxi(0, int(enemy.hp)), "attack_uid": attack_uid, "tier": tier})
		_trim_history(hit_history)
		if int(enemy.hp) <= 0:
			enemies.remove_at(index)
			total_killed += 1
			enemy_neutralized_detail.emit(enemy.duplicate(true), cause, impact_x)
			enemy_neutralized.emit(enemy_uid, impact_x, cause)
			enemy_killed.emit(enemy_uid, impact_x)
			encounter_state_changed.emit()
		else:
			if int(enemy.get("type", EnemyTypes.Type.HOPPER)) == EnemyTypes.Type.SICKLE_SNAKE and StringName(enemy.get("special_state", &"moving")) == &"moving":
				enemy.special_state = &"stunned"
				enemy.special_timer = SNAKE_HIT_STUN_DURATION
				enemy.preferred_lane = -1
				enemy.frame_move_fraction = 0.0
			enemies[index] = enemy
			enemy_hit.emit(enemy_uid, int(enemy.hp), impact_x)
		return

func _update_enemies(delta: float) -> void:
	var previous_positions := {}
	for enemy in enemies:
		previous_positions[int(enemy.uid)] = float(enemy.x)
	_update_healyzards(delta)
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if EnemyTypes.uses_hop(int(enemy.get("type", EnemyTypes.Type.HOPPER))):
			enemy.x = float(enemy.x) - _hop_displacement(float(enemy.hop_clock), delta, float(enemy.get("speed", enemy_speed)))
			enemy.hop_clock = fmod(float(enemy.hop_clock) + delta, HOP_CYCLE_DURATION)
		else:
			var move_fraction := 1.0
			if int(enemy.get("type", EnemyTypes.Type.HOPPER)) == EnemyTypes.Type.SICKLE_SNAKE:
				move_fraction = float(enemy.get("frame_move_fraction", 1.0)) if StringName(enemy.get("special_state", &"moving")) == &"moving" else 0.0
				enemy.frame_move_fraction = 1.0
			enemy.x = float(enemy.x) - float(enemy.get("speed", 0.0)) * delta * move_fraction
		_sync_enemy_motion_state(enemy)
		enemy.hit_flash = maxf(0.0, float(enemy.hit_flash) - delta)
		enemies[index] = enemy

	if defender_state == DefenderState.ACTIVE:
		var contact_uid := _first_defender_contact(previous_positions)
		if contact_uid >= 0:
			_knock_down()
			if emergency_available:
				_discharge_emergency()
				return

	var breached_uid := _first_new_breach(previous_positions)
	if breached_uid >= 0:
		_trigger_breach(breached_uid)

func _update_healyzards(delta: float) -> void:
	for healer_index in range(enemies.size()):
		var healer := enemies[healer_index]
		if int(healer.get("type", EnemyTypes.Type.HOPPER)) != EnemyTypes.Type.HEALYZARD:
			continue
		healer.heal_timer = float(healer.get("heal_timer", HEALYZARD_PULSE_INTERVAL)) - delta
		while float(healer.heal_timer) <= 0.000001:
			_emit_healer_pulse(healer)
			healer.heal_timer = float(healer.heal_timer) + HEALYZARD_PULSE_INTERVAL
		enemies[healer_index] = healer

func _emit_healer_pulse(healer: Dictionary) -> void:
	var targeted_uids: Array[int] = []
	var targeted_spawn_ids: Array[int] = []
	var restored_by_target := {}
	var restored_total := 0
	for target_index in range(enemies.size()):
		var target := enemies[target_index]
		if int(target.uid) == int(healer.uid) or int(target.get("type", EnemyTypes.Type.HOPPER)) == EnemyTypes.Type.HEALYZARD:
			continue
		targeted_uids.append(int(target.uid))
		targeted_spawn_ids.append(int(target.get("spawn_id", target.uid)))
		var before := int(target.hp)
		target.hp = mini(int(target.max_hp), before + 1)
		var restored := int(target.hp) - before
		restored_by_target[int(target.get("spawn_id", target.uid))] = restored
		restored_total += restored
		enemies[target_index] = target
	healer_pulsed.emit({
		"healer_uid": int(healer.uid),
		"healer_spawn_id": int(healer.get("spawn_id", healer.uid)),
		"lane_index": team_identity,
		"targeted_uids": targeted_uids,
		"targeted_spawn_ids": targeted_spawn_ids,
		"restored_by_target": restored_by_target,
		"restored_hp": restored_total,
	})

func extract_enemy_for_transfer(enemy_uid: int) -> Dictionary:
	for index in range(enemies.size()):
		if int(enemies[index].uid) == enemy_uid:
			var enemy := enemies[index]
			enemies.remove_at(index)
			return enemy
	return {}

func accept_transferred_enemy(enemy: Dictionary) -> int:
	if enemy.is_empty() or enemies.size() >= max_enemies:
		return -1
	var accepted := enemy.duplicate(true)
	accepted.uid = _next_enemy_uid
	accepted.lane_index = team_identity
	_next_enemy_uid += 1
	enemies.append(accepted)
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.x) < float(b.x))
	return int(accepted.uid)

func _update_spawning(delta: float) -> void:
	if not auto_spawn or game_over or encounter_spawn_complete():
		return
	spawn_timer -= delta
	while spawn_timer <= 0.0 and not encounter_spawn_complete():
		if enemies.size() >= max_enemies:
			break
		if spawn_enemy() < 0:
			break
		spawn_timer += maxf(spawn_interval, 0.1)

func _first_defender_contact(previous_positions: Dictionary) -> int:
	var best_time := INF
	var best_uid := -1
	for enemy in enemies:
		var uid := int(enemy.uid)
		var previous_x := float(previous_positions[uid])
		var current_x := float(enemy.x)
		if previous_x <= DEFENDER_X:
			return uid
		if current_x <= DEFENDER_X:
			var crossing_time := (previous_x - DEFENDER_X) / maxf(previous_x - current_x, 0.0001)
			if crossing_time < best_time:
				best_time = crossing_time
				best_uid = uid
	return best_uid

func _first_new_breach(previous_positions: Dictionary) -> int:
	var best_time := INF
	var best_uid := -1
	for enemy in enemies:
		if float(enemy.x) > LEFT_BOUNDARY:
			continue
		var uid := int(enemy.uid)
		var previous_x := float(previous_positions[uid])
		var crossing_time := 0.0 if previous_x <= LEFT_BOUNDARY else (previous_x - LEFT_BOUNDARY) / maxf(previous_x - float(enemy.x), 0.0001)
		if crossing_time < best_time:
			best_time = crossing_time
			best_uid = uid
	return best_uid

func _enemy_already_breached() -> int:
	for enemy in enemies:
		if float(enemy.x) <= LEFT_BOUNDARY:
			return int(enemy.uid)
	return -1

func _knock_down() -> void:
	if defender_state == DefenderState.DOWN:
		return
	defender_state = DefenderState.DOWN
	revival_progress = 0
	defender_knocked_down.emit(team_identity)

func _discharge_emergency() -> void:
	if not emergency_available:
		return
	emergency_available = false
	var victims := enemies.duplicate(true)
	var cleared_count := victims.size()
	total_emergency_cleared += cleared_count
	enemies.clear()
	for enemy in victims:
		enemy_neutralized_detail.emit(enemy.duplicate(true), &"emergency", float(enemy.x))
		enemy_neutralized.emit(int(enemy.uid), float(enemy.x), &"emergency")
	emergency_discharged.emit(team_identity, cleared_count)
	encounter_state_changed.emit()

func _repel_nearby_enemies() -> int:
	var safe_x := DEFENDER_X + REVIVAL_SAFE_OFFSET
	var repelled := 0
	for index in range(enemies.size()):
		var enemy := enemies[index]
		if float(enemy.x) <= DEFENDER_X + REVIVAL_REPEL_TRIGGER_DISTANCE:
			enemy.x = safe_x + repelled * 0.3
			enemies[index] = enemy
			repelled += 1
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.x) < float(b.x))
	return repelled

func _trigger_breach(enemy_uid: int) -> void:
	if game_over:
		return
	game_over = true
	total_breaches += 1
	breached.emit(team_identity, enemy_uid)
	encounter_state_changed.emit()

func clear_enemies_for_tier3() -> int:
	if game_over or _enemy_already_breached() >= 0:
		return 0
	var victims := enemies.duplicate(true)
	enemies.clear()
	for enemy in victims:
		total_killed += 1
		enemy_neutralized_detail.emit(enemy.duplicate(true), &"tier3", float(enemy.x))
		enemy_neutralized.emit(int(enemy.uid), float(enemy.x), &"tier3")
		enemy_killed.emit(int(enemy.uid), float(enemy.x))
	if not victims.is_empty():
		encounter_state_changed.emit()
	return victims.size()

func check_terminal_breach() -> bool:
	var enemy_uid := _enemy_already_breached()
	if enemy_uid < 0:
		return false
	_trigger_breach(enemy_uid)
	return true

func _hop_air_speed(average_speed := -1.0) -> float:
	var resolved_speed := enemy_speed if average_speed < 0.0 else average_speed
	return resolved_speed * HOP_CYCLE_DURATION / HOP_AIR_DURATION

func _hop_displacement(start_clock: float, duration: float, average_speed := -1.0) -> float:
	var remaining := maxf(duration, 0.0)
	var clock := fmod(start_clock, HOP_CYCLE_DURATION)
	var distance := 0.0
	while remaining > 0.000001:
		var airborne := clock >= HOP_GROUND_DURATION
		var phase_end := HOP_CYCLE_DURATION if airborne else HOP_GROUND_DURATION
		var segment := minf(remaining, phase_end - clock)
		if segment <= 0.000001:
			clock = 0.0
			continue
		if airborne:
			distance += _hop_air_speed(average_speed) * segment
		remaining -= segment
		clock += segment
		if clock >= HOP_CYCLE_DURATION - 0.000001:
			clock = 0.0
	return distance

func _sync_enemy_motion_state(enemy: Dictionary) -> void:
	if not EnemyTypes.uses_hop(int(enemy.get("type", EnemyTypes.Type.HOPPER))):
		enemy.hop_airborne = false
		enemy.hop_progress = 0.0
		return
	var phase := fmod(float(enemy.hop_clock), HOP_CYCLE_DURATION)
	enemy.hop_airborne = phase >= HOP_GROUND_DURATION
	enemy.hop_progress = clampf((phase - HOP_GROUND_DURATION) / HOP_AIR_DURATION, 0.0, 1.0) if bool(enemy.hop_airborne) else 0.0

func _trim_history(history: Array[Dictionary]) -> void:
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
