extends SceneTree

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _result(identity: int, tier := 1, group_size := 3) -> Dictionary:
	return {"identity": identity, "tier": tier, "fever": tier >= 3, "group_size": group_size, "combo_count": tier, "points": 100}

func _run() -> void:
	_test_first_contact_and_emergency_ordering()
	_test_revival_and_second_contact()
	await _test_match_routing_and_cascades()
	_test_revival_repel_and_breach_precedence()
	await _test_game_over_freeze_and_restart()
	_finish()

func _test_first_contact_and_emergency_ordering() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.RED)
	model.clear_for_test()
	var events := {"knockdowns": 0, "discharges": 0, "cleared": 0}
	model.defender_knocked_down.connect(func(_identity: int) -> void: events.knockdowns += 1)
	model.emergency_discharged.connect(func(_identity: int, count: int) -> void:
		events.discharges += 1
		events.cleared = count
	)
	model.spawn_enemy(LaneCombatModel.DEFENDER_X + 0.05, 2)
	model.spawn_enemy(2.0, 2)
	model.spawn_enemy(4.0, 2)
	var contact_enemy := model.enemies[0]
	contact_enemy.hop_clock = LaneCombatModel.HOP_GROUND_DURATION
	model.enemies[0] = contact_enemy
	model.update(0.2)
	_check(model.defender_state == LaneCombatModel.DefenderState.DOWN, "first contact knocks active defender down")
	_check(not model.emergency_available, "first contact consumes exactly one emergency charge")
	_check(model.enemies.is_empty() and int(events.cleared) == 3, "emergency clears every alive enemy in its lane")
	_check(int(events.knockdowns) == 1 and int(events.discharges) == 1, "first contact emits one knockdown and one discharge")
	_check(not model.game_over, "first emergency contact is not a breach loss")

	var large_delta := LaneCombatModel.new(TeamData.Identity.BLUE)
	large_delta.clear_for_test()
	large_delta.spawn_enemy(LaneCombatModel.DEFENDER_X + 1.0, 2)
	large_delta.spawn_enemy(LaneCombatModel.DEFENDER_X + 2.0, 2)
	large_delta.update(20.0)
	_check(large_delta.defender_state == LaneCombatModel.DefenderState.DOWN and large_delta.enemies.is_empty(), "large delta resolves defender contact then full discharge")
	_check(not large_delta.game_over and large_delta.total_breaches == 0, "first emergency cannot be bypassed by same-frame boundary crossing")

func _test_revival_and_second_contact() -> void:
	var model := LaneCombatModel.new(TeamData.Identity.GREEN)
	model.clear_for_test()
	model.spawn_enemy(LaneCombatModel.DEFENDER_X + 0.01, 2)
	var first_contact := model.enemies[0]
	first_contact.hop_clock = LaneCombatModel.HOP_GROUND_DURATION
	model.enemies[0] = first_contact
	model.update(0.1)
	_check(model.defender_state == LaneCombatModel.DefenderState.DOWN and not model.emergency_available, "setup spends charge and downs defender")
	var first := model.handle_match(_result(TeamData.Identity.GREEN, 3))
	_check(str(first.action) == "revival" and not bool(first.revived), "first same-color match contributes revival instead of attack")
	_check(model.revival_progress == 1 and model.projectiles.is_empty(), "revival 1/2 launches no projectiles")
	var second := model.handle_match(_result(TeamData.Identity.GREEN, 3))
	_check(bool(second.revived) and model.defender_state == LaneCombatModel.DefenderState.ACTIVE, "second separate same-color match revives defender")
	_check(model.revival_progress == 0 and model.projectiles.is_empty(), "finishing revival resets progress and still does not attack")
	_check(not model.emergency_available, "revival never restores emergency charge")
	var attack := model.handle_match(_result(TeamData.Identity.GREEN, 3))
	_check(str(attack.action) == "attack" and model.active_projectile_count() == 0, "post-revival tier-3 attack creates no conventional burst")

	model.projectiles.clear()
	model.spawn_enemy(LaneCombatModel.DEFENDER_X + 0.01, 2)
	var later_contact := model.enemies[0]
	later_contact.hop_clock = LaneCombatModel.HOP_GROUND_DURATION
	model.enemies[0] = later_contact
	model.update(0.1)
	_check(model.defender_state == LaneCombatModel.DefenderState.DOWN, "later contact knocks revived defender down again")
	_check(model.active_enemy_count() == 1 and model.total_emergency_cleared == 1, "spent charge does not clear later contact enemy")

func _test_match_routing_and_cascades() -> void:
	var red := LaneCombatModel.new(TeamData.Identity.RED)
	red.clear_for_test()
	red.defender_state = LaneCombatModel.DefenderState.DOWN
	red.emergency_available = false
	var other := red.handle_match(_result(TeamData.Identity.BLUE, 2, 5))
	_check(str(other.action) == "ignored" and red.revival_progress == 0, "other-color match cannot revive down lane")
	red.handle_match(_result(TeamData.Identity.RED, 2, 7))
	_check(red.revival_progress == 1, "one large same-color group grants only one revival point")
	red.handle_match(_result(TeamData.Identity.RED, 3, 3))
	_check(red.defender_state == LaneCombatModel.DefenderState.ACTIVE, "second cascade-style event completes revival")

	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	for lane in battlefield.lanes:
		lane.combat_model.clear_for_test()
	var down_lane := battlefield.get_lane(TeamData.Identity.RED).combat_model
	down_lane.defender_state = LaneCombatModel.DefenderState.DOWN
	down_lane.emergency_available = false
	var blue_lane := battlefield.get_lane(TeamData.Identity.BLUE).combat_model
	battlefield.handle_match(_result(TeamData.Identity.BLUE, 2))
	_check(blue_lane.active_projectile_count() == 2, "other-color match still attacks its active lane")
	_check(down_lane.revival_progress == 0, "active other lane attack leaves down lane unchanged")
	battlefield.queue_free()

func _test_revival_repel_and_breach_precedence() -> void:
	var repel := LaneCombatModel.new(TeamData.Identity.YELLOW)
	repel.clear_for_test()
	repel.defender_state = LaneCombatModel.DefenderState.DOWN
	repel.emergency_available = false
	repel.revival_progress = 1
	repel.spawn_enemy(LaneCombatModel.DEFENDER_X - 0.25, 2)
	repel.spawn_enemy(LaneCombatModel.DEFENDER_X + 0.2, 2)
	var hp_before: Array[int] = [int(repel.enemies[0].hp), int(repel.enemies[1].hp)]
	repel.handle_match(_result(TeamData.Identity.YELLOW))
	_check(repel.defender_state == LaneCombatModel.DefenderState.ACTIVE, "finishing match revives before repel")
	_check(repel.active_enemy_count() == 2 and [int(repel.enemies[0].hp), int(repel.enemies[1].hp)] == hp_before, "revival repel is nonlethal")
	for enemy in repel.enemies:
		_check(float(enemy.x) >= LaneCombatModel.DEFENDER_X + LaneCombatModel.REVIVAL_SAFE_OFFSET, "revival moves nearby/passed enemy ahead of defender")

	var breached := LaneCombatModel.new(TeamData.Identity.YELLOW)
	breached.clear_for_test()
	breached.defender_state = LaneCombatModel.DefenderState.DOWN
	breached.emergency_available = false
	breached.revival_progress = 1
	breached.spawn_enemy(LaneCombatModel.LEFT_BOUNDARY - 0.01, 2)
	var breach_events := {"count": 0}
	breached.breached.connect(func(_identity: int, _uid: int) -> void: breach_events.count += 1)
	var outcome := breached.handle_match(_result(TeamData.Identity.YELLOW))
	_check(str(outcome.action) == "breach" and breached.game_over, "already-breached enemy takes precedence over revival")
	_check(breached.defender_state == LaneCombatModel.DefenderState.DOWN and breached.revival_progress == 1, "terminal breach cannot be reversed by match")
	breached.update(1.0)
	_check(int(breach_events.count) == 1 and breached.total_breaches == 1, "terminal breach emits exactly once")

func _test_game_over_freeze_and_restart() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var battlefield: Battlefield = main.get("_battlefield")
	var chain: ChainModel = main.get("_chain_model")
	var progression: MatchProgression = main.get("_progression")
	var magazine: MagazineState = main.get("_magazine")
	var shooter: ShooterView = main.get("_shooter_view")
	var overlay: GameOverOverlay = main.get("_game_over_overlay")
	for lane in battlefield.lanes:
		_check(lane.combat_model.defender_state == LaneCombatModel.DefenderState.ACTIVE, "lane %d starts ACTIVE" % lane.team_identity)
		_check(lane.combat_model.emergency_available and lane.combat_model.revival_progress == 0, "lane %d starts with charge and zero revival" % lane.team_identity)
	var initial_chain := chain.identities()
	var red_lane := battlefield.get_lane(TeamData.Identity.RED).combat_model
	red_lane.clear_for_test()
	red_lane.spawn_enemy(LaneCombatModel.DEFENDER_X + 0.01, 2)
	red_lane.spawn_enemy(2.0, 2)
	var red_contact := red_lane.enemies[0]
	red_contact.hop_clock = LaneCombatModel.HOP_GROUND_DURATION
	red_lane.enemies[0] = red_contact
	red_lane.update(0.1)
	_check(progression.score == 0 and chain.identities() == initial_chain, "emergency contact changes neither score nor top chain")
	_check(battlefield.get_lane(TeamData.Identity.BLUE).combat_model.defender_state == LaneCombatModel.DefenderState.ACTIVE, "RED emergency leaves other lane defender unchanged")
	_check(battlefield.get_lane(TeamData.Identity.BLUE).combat_model.active_enemy_count() == 1, "RED emergency leaves other lane enemies unchanged")

	var rollover: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW]
	chain.set_test_state(rollover, -190.0)
	chain.advance(0.0)
	_check(not bool(main.get("_game_over")), "top-ball FIFO rollover never causes game over")
	_check(not chain.cache.is_empty(), "rollover still enters FIFO cache during survival play")

	progression.register_match(TeamData.Identity.RED, 3)
	main.set("_cooldown_remaining", 0.0)
	main.call("_shoot")
	var score_before_breach := progression.score
	var chain_x_before := float(chain.balls[0].x)
	var draws_before_breach := magazine.draw_count
	var breach_lane := battlefield.get_lane(TeamData.Identity.BLUE).combat_model
	breach_lane.clear_for_test()
	breach_lane.defender_state = LaneCombatModel.DefenderState.DOWN
	breach_lane.emergency_available = false
	breach_lane.spawn_enemy(LaneCombatModel.LEFT_BOUNDARY + 0.01, 2)
	var breach_enemy := breach_lane.enemies[0]
	breach_enemy.hop_clock = LaneCombatModel.HOP_GROUND_DURATION
	breach_lane.enemies[0] = breach_enemy
	breach_lane.update(0.1)
	_check(bool(main.get("_game_over")) and battlefield.game_over, "alive boundary crossing triggers global game over")
	_check(overlay.visible and overlay.final_score == score_before_breach, "game-over overlay preserves final score")
	_check(shooter.simulation_paused, "game over freezes pending shooter projectiles")
	main.call("_process", 1.0)
	main.call("_shoot")
	main.call("_swap")
	_check(is_equal_approx(float(chain.balls[0].x), chain_x_before), "game over freezes ball-chain motion")
	_check(progression.score == score_before_breach and magazine.draw_count == draws_before_breach, "game over blocks progression and magazine input")

	main.call("_restart_run")
	_check(not bool(main.get("_game_over")) and not overlay.visible and not shooter.simulation_paused, "restart hides overlay and resumes clean run")
	_check(progression.score == 0 and progression.combo_count == 0 and not progression.fever_active, "restart clears score/combo/fever")
	_check(chain.cache.is_empty() and chain.balls.size() == chain.initial_population, "restart resets chain and FIFO cache")
	_check(magazine.draw_count == 2 and shooter.get("_shots").is_empty(), "restart resets shuffle bag and pending 2D shots")
	for lane in battlefield.lanes:
		_check(lane.combat_model.defender_state == LaneCombatModel.DefenderState.ACTIVE, "restart lane %d is ACTIVE" % lane.team_identity)
		_check(lane.combat_model.emergency_available and lane.combat_model.revival_progress == 0, "restart lane %d restores one charge" % lane.team_identity)
		_check(lane.combat_model.active_enemy_count() == 1 and lane.combat_model.active_projectile_count() == 0, "restart lane %d has fresh enemy and no stale shots" % lane.team_identity)
	progression.register_match(TeamData.Identity.GREEN, 3)
	_check(battlefield.get_lane(TeamData.Identity.GREEN).combat_model.attack_history.size() == 1, "restart retains one live match-routing connection")
	main.queue_free()

func _finish() -> void:
	if _failures.is_empty():
		print("P005 survival loop: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P005 survival loop: " + failure)
	print("P005 survival loop: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
