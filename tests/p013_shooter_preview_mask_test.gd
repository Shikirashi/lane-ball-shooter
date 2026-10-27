extends SceneTree

const LayoutCalculator = preload("res://scripts/responsive_layout.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run() -> void:
	_test_offscreen_fresh_entry()
	_test_fifo_entry_and_bounds()
	await _test_live_preview_layers_and_input()
	_finish()

func _advance_in_steps(model: ChainModel, duration: float, step: float) -> void:
	var remaining := duration
	while remaining > 0.000001:
		var frame := minf(step, remaining)
		model.advance(frame)
		remaining -= frame

func _new_entry_model() -> ChainModel:
	var model := ChainModel.new()
	model.set_lane_width(900.0)
	# Reset after width assignment so the seed tail is aligned to this lane.
	model.reset_run()
	return model

func _test_offscreen_fresh_entry() -> void:
	var model := _new_entry_model()
	var initial_count := model.balls.size()
	var time_to_slot := (float(model.balls[-1].x) - (model.entry_spawn_x() - model.spacing)) / model.speed
	model.advance(time_to_slot)
	_check(model.balls.size() == initial_count + 1, "fresh feeder admits exactly one legal offscreen ball")
	var entrant: Dictionary = model.balls[-1]
	_check(float(entrant.x) >= model.lane_width + model.radius + ChainModel.ENTRY_MARGIN - 0.001, "fresh entrant starts completely beyond right clip edge")
	_check(model.offscreen_right_count() == 1 and model.balls.size() <= model.max_auto_population, "offscreen staging is live, authoritative and bounded")
	var uid := int(entrant.uid)
	var start_x := float(entrant.x)
	model.advance(0.03)
	var after_x := float(model.balls[model._ball_index_by_uid(uid)].x)
	_check(absf(after_x - (start_x - model.speed * 0.03)) < 0.001, "fresh entrant advances at normal 102 px/s while fully masked")
	_check(after_x - model.radius > model.lane_width, "fresh entrant remains completely clipped before crossing")
	model.advance(0.02)
	after_x = float(model.balls[model._ball_index_by_uid(uid)].x)
	_check(after_x - model.radius < model.lane_width and after_x + model.radius > model.lane_width, "entrant progressively intersects the right boundary rather than popping in whole")

	var positions: Array[float] = []
	for step in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0, 0.5]:
		var sample := _new_entry_model()
		_advance_in_steps(sample, 0.5, step)
		positions.append(float(sample.balls[-1].x))
	for index in range(1, positions.size()):
		_check(absf(positions[index] - positions[0]) < 0.002, "entry position is deterministic at sample %d including large delta" % index)

func _test_fifo_entry_and_bounds() -> void:
	var entrants: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	var model := ChainModel.new()
	var tail: Array[int] = [TeamData.Identity.YELLOW]
	model.set_test_state(tail, 100.0)
	model.add_test_segment(entrants, model.entry_spawn_x(), ChainModel.GapType.FEED)
	_check(model.identities().slice(-3) == entrants, "fresh entrant identities retain RED GREEN BLUE order")
	var first_return_index := model.balls.size() - 3
	var before := float(model.balls[first_return_index].x)
	_check(before >= model.entry_spawn_x() and model.segment_gaps.size() == 1 and int(model.segment_gaps[0].type) == ChainModel.GapType.FEED, "fresh batch uses typed offscreen FEED segment")
	model.advance(0.1)
	var after := float(model.balls[first_return_index].x)
	_check(absf(after - (before - model.speed * 0.1)) < 0.001, "fresh batch enters at normal speed before gravity contact")
	_check(model.offscreen_right_count() <= model.max_auto_population and model.invariant_violations == 0, "fresh entry remains bounded and overlap-free")

	var long_run := _new_entry_model()
	for unused in range(3600):
		long_run.advance(1.0 / 60.0)
	_check(long_run.active_population_count() <= long_run.max_auto_population and long_run.offscreen_right_count() <= 1 and long_run.offscreen_left_count() > 0, "one-minute stream bounds the active/right population while retaining left history")
	_check(long_run.total_fresh_generated > long_run.initial_population and long_run.invariant_violations == 0, "long stream replenishes indefinitely without geometry violations")

func _test_live_preview_layers_and_input() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var shooter: ShooterView = main.get("_shooter_view")
	var magazine: MagazineState = main.get("_magazine")
	var swap_view: MagazineView = main.get("_magazine_view")
	var chain: BallChainView = main.get("_chain_view")
	for viewport_size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]:
		var inset := 24.0 if viewport_size.x > 1000.0 else 0.0
		var safe := Rect2(inset, 12.0, viewport_size.x - inset * 2.0, viewport_size.y - 24.0)
		main.call("_apply_layout", viewport_size, safe)
		for edge_x in [shooter.track_left, shooter.track_right]:
			shooter.move_to(edge_x)
			var loaded_center := shooter.loaded_ball_center()
			var next_center := shooter.next_ball_center()
			_check(absf(loaded_center.x - shooter.shooter_x) < 0.001 and is_equal_approx(next_center.y, loaded_center.y) and absf(next_center.x - loaded_center.x) >= 30.0, "%s next preview stays beside loaded ball on its horizontal row at edge %.0f" % [viewport_size, edge_x])
			_check(safe.has_point(loaded_center + Vector2(signf(edge_x - safe.get_center().x) * 20.0, 0.0)) and safe.has_point(next_center + Vector2(signf(next_center.x - loaded_center.x) * 10.0, 0.0)), "%s both ammunition balls remain in safe area at edge %.0f" % [viewport_size, edge_x])
		var layout: Dictionary = LayoutCalculator.calculate(viewport_size, safe)
		_check(layout.magazine_rect.size == Vector2(56.0, 56.0) and layout.hud_rect.encloses(layout.magazine_rect), "%s swap is compact and safe" % viewport_size)
		_check(not layout.playfield_rect.intersects(layout.magazine_rect), "%s circular swap does not obstruct full-width playfield" % viewport_size)

	var old_loaded := magazine.loaded_identity
	var old_next := magazine.next_identity
	main.call("_swap")
	_check(shooter.loaded_identity == old_next and shooter.next_identity == old_loaded, "swap instantly synchronizes shooter loaded and next identities")
	main.set("_cooldown_remaining", 0.0)
	main.call("_shoot")
	_check(shooter.loaded_identity == magazine.loaded_identity and shooter.next_identity == magazine.next_identity and shooter.get("_shots").size() == 1, "fire immediately advances both shooter ammunition visuals")
	_check(swap_view.get("_swap_rect").size.x >= 56.0 and swap_view.get("_swap_rect").size.y >= 56.0, "circular swap touch target is at least 56x56")

	_check(not chain.clip_contents and chain.conveyor_mask.clip_contents and not chain.conveyor_balls.clip_contents and not chain.settling_overlay.clip_contents, "only established conveyor parent owns a clipping mask")
	_check(chain.conveyor_mask.position == chain.conveyor_window_rect().position and chain.conveyor_mask.size == chain.conveyor_window_rect().size, "mask bounds exactly match visual conveyor window")
	var chain_model: ChainModel = main.get("_chain_model")
	var state: Array[int] = [TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.YELLOW]
	chain_model.set_test_state(state, 300.0)
	chain_model.try_insert_shot(TeamData.Identity.GREEN, float(chain_model.balls[1].x) + 1.0)
	var settling_uid := int(chain_model.pending_insertions[0].uid)
	_check(chain.settling_overlay.rendered_uids() == [settling_uid] and not chain.conveyor_balls.rendered_uids().has(settling_uid), "new insertion has one unmasked owner and no clipped duplicate")
	chain_model.advance(0.049)
	_check(chain.settling_overlay.rendered_uids() == [settling_uid] and not chain.conveyor_balls.rendered_uids().has(settling_uid), "49ms insertion remains exclusively unmasked")
	chain_model.advance(0.001)
	_check(chain.settling_overlay.rendered_uids().is_empty() and chain.conveyor_balls.rendered_uids().has(settling_uid), "50ms handoff becomes exclusively clipped without disappearance")

	chain_model.try_insert_shot(TeamData.Identity.GREEN, float(chain_model.balls[0].x))
	_check(not chain.settling_overlay.rendered_uids().is_empty(), "restart fixture owns a pending unmasked visual")
	main.call("_on_game_over_requested", TeamData.Identity.RED)
	_check(not chain.settling_overlay.visible, "game over hides pending unmasked handoffs instead of leaving ghosts")
	main.call("_restart_run")
	_check(chain_model.pending_insertions.is_empty() and chain.settling_overlay.rendered_uids().is_empty() and chain.settling_overlay.visible, "restart clears all pending visual handoffs and restores the overlay")
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P013 shooter preview/mask: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P013 shooter preview/mask: " + failure)
	print("P013 shooter preview/mask: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
