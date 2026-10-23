class_name LaneCombatModel
extends RefCounted

signal enemy_spawned(enemy: Dictionary)
signal enemy_hit(enemy_uid: int, remaining_hp: int, impact_x: float)
signal enemy_killed(enemy_uid: int, impact_x: float)
signal enemy_recycled(enemy_uid: int)
signal projectile_spawned(projectile: Dictionary)

const DEFENDER_X := -5.9
const PROJECTILE_START_X := -5.25
const LEFT_BOUNDARY := -7.25
const RIGHT_BOUNDARY := 7.6
const PROJECTILE_RIGHT_BOUNDARY := 8.25
const DEFAULT_ENEMY_SPEED := 0.48
const DEFAULT_ENEMY_HP := 2
const DEFAULT_PROJECTILE_SPEED := 9.0
const DEFAULT_PROJECTILE_DAMAGE := 1
const DEFAULT_SPAWN_INTERVAL := 5.5
const DEFAULT_MAX_ENEMIES := 5
const PROJECTILE_LIFETIME := 2.2
const BURST_INTERVAL := 0.14
const HIT_DISTANCE := 0.4

var team_identity := 0
var enemy_speed := DEFAULT_ENEMY_SPEED
var enemy_max_hp := DEFAULT_ENEMY_HP
var projectile_speed := DEFAULT_PROJECTILE_SPEED
var projectile_damage := DEFAULT_PROJECTILE_DAMAGE
var spawn_interval := DEFAULT_SPAWN_INTERVAL
var max_enemies := DEFAULT_MAX_ENEMIES
var auto_spawn := true
var spawn_timer := DEFAULT_SPAWN_INTERVAL

var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var attack_history: Array[Dictionary] = []
var hit_history: Array[Dictionary] = []
var total_spawned := 0
var total_killed := 0
var total_recycled := 0

var _next_enemy_uid := 1
var _next_projectile_uid := 1
var _next_attack_uid := 1

func _init(identity_value := 0) -> void:
	team_identity = posmod(identity_value, TeamData.COUNT)

func fire_attack(match_result: Dictionary) -> Dictionary:
	var locked_tier := clampi(int(match_result.get("tier", 1)), 1, 3)
	var projectile_count := locked_tier
	var attack := {
		"uid": _next_attack_uid,
		"identity": team_identity,
		"tier": locked_tier,
		"fever": bool(match_result.get("fever", false)),
		"group_size": int(match_result.get("group_size", 3)),
		"projectile_count": projectile_count,
	}
	_next_attack_uid += 1
	attack_history.append(attack.duplicate(true))
	for burst_index in range(projectile_count):
		_spawn_projectile(int(attack.uid), burst_index * BURST_INTERVAL)
	return attack.duplicate(true)

func spawn_enemy(x_position := RIGHT_BOUNDARY, hp_value := -1) -> int:
	if enemies.size() >= max_enemies:
		return -1
	var resolved_hp := enemy_max_hp if hp_value < 0 else maxi(1, hp_value)
	var enemy := {
		"uid": _next_enemy_uid,
		"x": x_position,
		"hp": resolved_hp,
		"max_hp": resolved_hp,
		"hop_clock": float(_next_enemy_uid) * 0.71 + float(team_identity) * 0.43,
		"hit_flash": 0.0,
	}
	_next_enemy_uid += 1
	total_spawned += 1
	enemies.append(enemy)
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.x) < float(b.x))
	enemy_spawned.emit(enemy.duplicate(true))
	return int(enemy.uid)

func update(delta: float) -> void:
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
	total_killed = 0
	total_recycled = 0
	spawn_timer = spawn_interval

func active_enemy_count() -> int:
	return enemies.size()

func active_projectile_count() -> int:
	return projectiles.size()

func _spawn_projectile(attack_uid: int, launch_delay: float) -> void:
	var projectile := {
		"uid": _next_projectile_uid,
		"attack_uid": attack_uid,
		"x": PROJECTILE_START_X,
		"damage": projectile_damage,
		"age": 0.0,
		"launch_delay": launch_delay,
	}
	_next_projectile_uid += 1
	projectiles.append(projectile)
	projectile_spawned.emit(projectile.duplicate(true))

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
		var hit := _first_swept_hit(projectile_start, active_start, active_delta, enemy_starts)
		if not hit.is_empty():
			var impact_time := float(hit.time)
			var impact_x := projectile_start + projectile_speed * impact_time
			_damage_enemy(int(hit.enemy_uid), int(projectile.damage), impact_x)
			continue

		projectile.x = projectile_start + projectile_speed * active_delta
		projectile.age = float(projectile.age) + active_delta
		if float(projectile.x) <= PROJECTILE_RIGHT_BOUNDARY and float(projectile.age) <= PROJECTILE_LIFETIME:
			survivors.append(projectile)
	projectiles = survivors

func _first_swept_hit(projectile_x: float, active_start: float, active_delta: float, enemy_starts: Dictionary) -> Dictionary:
	var best_time := INF
	var best_uid := -1
	var closing_speed := projectile_speed + enemy_speed
	for enemy in enemies:
		var uid := int(enemy.uid)
		var enemy_x_at_start := float(enemy_starts[uid]) - enemy_speed * active_start
		var relative_start := enemy_x_at_start - projectile_x
		if relative_start < -HIT_DISTANCE:
			continue
		var relative_end := relative_start - closing_speed * active_delta
		if relative_end > HIT_DISTANCE:
			continue
		var contact_time := clampf((relative_start - HIT_DISTANCE) / closing_speed, 0.0, active_delta)
		if contact_time < best_time:
			best_time = contact_time
			best_uid = uid
	if best_uid < 0:
		return {}
	return {"enemy_uid": best_uid, "time": best_time}

func _damage_enemy(enemy_uid: int, damage: int, impact_x: float) -> void:
	for index in range(enemies.size()):
		if int(enemies[index].uid) != enemy_uid:
			continue
		var enemy := enemies[index]
		enemy.hp = int(enemy.hp) - damage
		enemy.hit_flash = 0.16
		hit_history.append({"enemy_uid": enemy_uid, "damage": damage, "impact_x": impact_x, "remaining_hp": maxi(0, int(enemy.hp))})
		if int(enemy.hp) <= 0:
			enemies.remove_at(index)
			total_killed += 1
			enemy_killed.emit(enemy_uid, impact_x)
		else:
			enemies[index] = enemy
			enemy_hit.emit(enemy_uid, int(enemy.hp), impact_x)
		return

func _update_enemies(delta: float) -> void:
	for index in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[index]
		enemy.x = float(enemy.x) - enemy_speed * delta
		enemy.hop_clock = float(enemy.hop_clock) + delta * 3.25
		enemy.hit_flash = maxf(0.0, float(enemy.hit_flash) - delta)
		if float(enemy.x) <= LEFT_BOUNDARY:
			var recycled_uid := int(enemy.uid)
			enemies.remove_at(index)
			total_recycled += 1
			enemy_recycled.emit(recycled_uid)
		else:
			enemies[index] = enemy

func _update_spawning(delta: float) -> void:
	if not auto_spawn:
		return
	spawn_timer -= delta
	while spawn_timer <= 0.0:
		if enemies.size() < max_enemies:
			spawn_enemy()
		spawn_timer += maxf(spawn_interval, 0.1)
