extends SceneTree

const LayoutCalculator = preload("res://scripts/responsive_layout.gd")
const STRESS_SEED := 0x5011CAFE
const STRESS_OPERATIONS := 2400

var _failures: Array[String] = []
var _checks := 0
var _stress_accepted := 0
var _stress_matches := 0
var _stress_fresh := 0
var _stress_cache_activity := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _invariants_hold(model: ChainModel) -> bool:
	if model.segment_gaps.size() != maxi(0, model.segments.size() - 1):
		return false
	var seen := {}
	var flat_index := 0
	for segment_index in range(model.segments.size()):
		var segment: Dictionary = model.segments[segment_index]
		var members: Array = segment.members
		if members.is_empty():
			return false
		for local_index in range(members.size()):
			if flat_index >= model.balls.size():
				return false
			var ball: Dictionary = model.balls[flat_index]
			var expected_x := float(segment.anchor_x) + local_index * model.spacing
			var uid := int(members[local_index].uid)
			if seen.has(uid) or int(ball.uid) != uid or absf(float(ball.x) - expected_x) > 0.001 or absf(float(ball.display_x) - expected_x) > 0.001:
				return false
			seen[uid] = true
			if flat_index > 0:
				var logical_gap := float(ball.x) - float(model.balls[flat_index - 1].x)
				var display_gap := float(ball.display_x) - float(model.balls[flat_index - 1].display_x)
				if logical_gap < model.radius * 2.0 - 0.01 or display_gap < model.radius * 2.0 - 0.01:
					return false
			flat_index += 1
		if segment_index + 1 < model.segments.size():
			var next_segment: Dictionary = model.segments[segment_index + 1]
			var end_x := float(segment.anchor_x) + (members.size() - 1) * model.spacing
			if float(next_segment.anchor_x) - end_x < model.spacing - 0.01:
				return false
	return flat_index == model.balls.size() and model.invariant_violations == 0

func _advance_checked(model: ChainModel, duration: float, quantum := 1.0 / 120.0, label := "step") -> void:
	var remaining := duration
	while remaining > 0.000001:
		var step := minf(remaining, quantum)
		model.advance(step)
		_check(_invariants_hold(model), "%s maintains segment/logical/render invariants at t=%.6f" % [label, model.simulation_time])
		remaining -= step

func _run() -> void:
	_test_segment_authority_and_theatrical_sequence()
	_test_concurrent_gaps_fifo_and_restart()
	_test_seeded_long_stress()
	await _test_layout_palette_and_live_routing()
	_finish()

func _test_segment_authority_and_theatrical_sequence() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.RED, TeamData.Identity.RED]
	model.set_test_state(identities, 100.0)
	var original_uids: Array[int] = []
	for ball in model.balls:
		original_uids.append(int(ball.uid))
	_check(model.segments.size() == 1 and _invariants_hold(model), "test chain starts as one authoritative rigid segment")
	_check(model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[3].display_x) + 4.0), "yellow shot contacts authoritative rendered position")
	_check(model.segments.size() == 1 and model.balls.size() == 7 and _invariants_hold(model), "insertion expands one rigid segment without visual/logical overlap")
	var inserted_uid := int(model.pending_insertions[0].uid)
	_check(not original_uids.has(inserted_uid), "inserted member receives one unique stable UID")
	_advance_checked(model, 0.049, 0.007, "49ms settle")
	_check(model.event_log.is_empty() and model.balls.size() == 7, "49ms retains the full yellow triple")
	_advance_checked(model, 0.001, 0.001, "50ms boundary")
	_check(model.event_log.size() == 1 and int(model.event_log[0].identity) == TeamData.Identity.YELLOW and int(model.event_log[0].size) == 3, "50ms emits one yellow size-3 match")
	_check(model.segments.size() == 2 and model.segment_gaps.size() == 1 and int(model.segment_gaps[0].type) == ChainModel.GapType.CAUSAL, "middle clear splits into two segments with one typed causal edge")
	var left_members: Array = model.segments[0].members
	var left_uids := [int(left_members[0].uid), int(left_members[1].uid)]
	var left_before := [float(model.balls[0].x), float(model.balls[1].x)]
	_advance_checked(model, 0.02, 0.01, "initial rollback")
	var left_after := [float(model.balls[0].x), float(model.balls[1].x)]
	_check(left_after[0] > left_before[0] and absf((left_after[0] - left_before[0]) - (left_after[1] - left_before[1])) < 0.001, "front segment reverses right as one rigid unit")
	_check([int(model.balls[0].uid), int(model.balls[1].uid)] == left_uids, "rigid rollback preserves front UID order")
	while model.event_log.size() < 2 and model.simulation_time < 2.0:
		_advance_checked(model, 1.0 / 120.0, 1.0 / 120.0, "contact approach")
	_check(model.event_log.size() == 2 and int(model.event_log[1].identity) == TeamData.Identity.RED and int(model.event_log[1].size) == 4, "physical reconnection emits one later red size-4 cascade")
	_check(float(model.event_log[1].time) > float(model.event_log[0].time), "cascade timestamp follows initial match timestamp")

func _test_concurrent_gaps_fifo_and_restart() -> void:
	var model := ChainModel.new()
	var identities: Array[int] = [TeamData.Identity.RED, TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.BLUE, TeamData.Identity.GREEN, TeamData.Identity.GREEN, TeamData.Identity.YELLOW, TeamData.Identity.YELLOW, TeamData.Identity.RED, TeamData.Identity.RED]
	var cached: Array[int] = [TeamData.Identity.RED, TeamData.Identity.GREEN, TeamData.Identity.BLUE]
	model.set_test_state(identities, 100.0, cached)
	model.try_insert_shot(TeamData.Identity.BLUE, float(model.balls[3].display_x) + 4.0)
	model.try_insert_shot(TeamData.Identity.YELLOW, float(model.balls[7].display_x) + 4.0)
	_check(model.pending_insertions.size() == 2 and _invariants_hold(model), "two same-window insertions remain legal and independent")
	_advance_checked(model, 0.05, 1.0 / 120.0, "concurrent settle")
	_check(model.total_match_events == 2 and model.rollback_gaps.size() == 2, "two settled clears create two nonconflicting motors")
	var moving_uid := int(model.rollback_gaps[0].left_uid)
	var moving_index := model._ball_index_by_uid(moving_uid)
	_check(moving_index >= 0 and model.try_insert_shot(TeamData.Identity.GREEN, float(model.balls[moving_index].display_x) + 2.0), "shot can insert at a moving rollback endpoint")
	_advance_checked(model, 2.0, 1.0 / 120.0, "multiple gap closure")
	_check(model.rollback_gaps.is_empty() and _invariants_hold(model), "multiple motors and rollback-time insertion terminate without overlap")
	model.return_cached(3)
	_check(model.identities().slice(-3) == cached, "FIFO return colors retain exact order through segment admission")
	_advance_checked(model, 8.0, 1.0 / 30.0, "FIFO catchup")
	_check(_invariants_hold(model) and model.segment_gaps.is_empty(), "feed segment physically reconnects without passive match or overlap")

	var restart := ChainModel.new()
	restart.set_test_state(identities, 100.0)
	restart.try_insert_shot(TeamData.Identity.BLUE, float(restart.balls[3].display_x) + 4.0)
	_advance_checked(restart, 0.05, 0.01, "restart setup")
	_check(not restart.rollback_gaps.is_empty(), "restart setup has active segment motor")
	restart.reset_run()
	_check(restart.pending_insertions.is_empty() and restart.rollback_gaps.is_empty() and restart.segment_gaps.is_empty() and restart.segments.size() == 1, "restart clears all transient segment/gap/event state")
	_check(_invariants_hold(restart), "restarted seed satisfies all invariants")

func _test_seeded_long_stress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STRESS_SEED
	var model := ChainModel.new()
	model.set_fresh_seed(STRESS_SEED)
	model.lane_width = 1252.0
	var accepted := 0
	var frame_steps := [1.0 / 120.0, 1.0 / 60.0, 1.0 / 30.0, 0.08]
	for operation in range(STRESS_OPERATIONS):
		if model.balls.is_empty():
			model.advance(0.0)
		if not model.balls.is_empty():
			var target_index := rng.randi_range(0, model.balls.size() - 1)
			var target: Dictionary = model.balls[target_index]
			if model.try_insert_shot(int(target.identity), float(target.display_x) + (2.0 if operation % 2 == 0 else -2.0)):
				accepted += 1
			if operation % 19 == 0 and model.balls.size() > 3:
				var second_index := rng.randi_range(0, model.balls.size() - 1)
				var second: Dictionary = model.balls[second_index]
				if model.try_insert_shot(int(second.identity), float(second.display_x) + 1.0):
					accepted += 1
		var duration: float = frame_steps[operation % frame_steps.size()]
		_advance_checked(model, duration, minf(duration, 1.0 / 120.0), "seed %08X op %d" % [STRESS_SEED, operation])
		if operation % 37 == 0:
			_advance_checked(model, 0.21, 1.0 / 120.0, "seeded long delta %d" % operation)
		if operation % 101 == 0 and not model.cache.is_empty():
			model.return_cached(mini(3, model.cache.size()))
		_check(model.balls.size() <= model.max_auto_population + 8, "stress live population remains bounded at operation %d" % operation)
	_advance_checked(model, 45.0, 1.0 / 30.0, "seeded rollover tail")
	_check(accepted >= STRESS_OPERATIONS, "fixed seed accepts thousands of physical insertions (%d)" % accepted)
	_check(model.total_match_events > 500, "fixed seed produces hundreds of real staged matches (%d)" % model.total_match_events)
	_check(model.total_fresh_generated > model.initial_population and model.cache.size() + model.total_cache_returned > 0, "stress exercises perpetual feed and left FIFO rollover")
	_check(model.invariant_violations == 0 and _invariants_hold(model), "fixed seed completes with zero recorded invariant violations")
	_check(model.max_concurrent_events <= 4, "event processing stays bounded per substep (%d max)" % model.max_concurrent_events)
	_stress_accepted = accepted
	_stress_matches = model.total_match_events
	_stress_fresh = model.total_fresh_generated
	_stress_cache_activity = model.cache.size() + model.total_cache_returned

func _test_layout_palette_and_live_routing() -> void:
	_check([TeamData.Identity.RED, TeamData.Identity.BLUE, TeamData.Identity.YELLOW, TeamData.Identity.GREEN] == [0, 1, 2, 3], "team identity order remains RED BLUE YELLOW GREEN")
	var blue := TeamData.color(TeamData.Identity.BLUE)
	var green := TeamData.color(TeamData.Identity.GREEN)
	var rgb_distance := Vector3(blue.r - green.r, blue.g - green.g, blue.b - green.b).length()
	var hue_distance := absf(blue.h - green.h)
	hue_distance = minf(hue_distance, 1.0 - hue_distance)
	_check(rgb_distance > 0.45 and hue_distance > 0.18, "BLUE and GREEN canonical palette has strong RGB and hue separation")
	for viewport_size in [Vector2(960, 540), Vector2(1280, 720), Vector2(1600, 720), Vector2(2400, 1080)]:
		var layout: Dictionary = LayoutCalculator.calculate(viewport_size)
		_check(float(layout.track_left) <= layout.chain_rect.position.x + 25.0 and float(layout.track_right) >= layout.chain_rect.end.x - 25.0, "%s track covers both edge targets" % viewport_size)
		_check(layout.hud_rect.encloses(layout.magazine_rect) and layout.magazine_rect.size.y >= 56.0, "%s compact magazine is safe, nonblocking and finger-sized" % viewport_size)
		_check(not layout.playfield_rect.intersects(layout.magazine_rect), "%s magazine does not steal firing-path touches" % viewport_size)

	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.call("_apply_layout", Vector2(960, 540), Rect2(Vector2.ZERO, Vector2(960, 540)))
	var shooter: ShooterView = main.get("_shooter_view")
	var chain_view: BallChainView = main.get("_chain_view")
	var magazine_view: MagazineView = main.get("_magazine_view")
	_check(absf((shooter.track_left - chain_view.position.x) - 24.0) < 0.01 and absf((shooter.track_right - chain_view.position.x) - (chain_view.size.x - 24.0)) < 0.01, "live shooter/chain coordinate mapping reaches both physical edges")
	_check(magazine_view.get("_swap_rect").size == Vector2(64.0, 56.0), "live swap control retains 64x56 touch target")
	var battlefield: Battlefield = main.get("_battlefield")
	for identity in range(TeamData.COUNT):
		var lane: LaneActor = battlefield.get_lane(identity)
		var stripe: MeshInstance3D = lane.get_node("TeamStripe_%s" % TeamData.display_name(identity))
		var body: MeshInstance3D = lane.get_node("Defender_%s/DefenderBody_%s" % [TeamData.display_name(identity), TeamData.display_name(identity)])
		var stripe_material := stripe.material_override as StandardMaterial3D
		var body_material := body.material_override as StandardMaterial3D
		_check(body_material.albedo_color == TeamData.color(identity), "lane %d defender body derives from canonical team color" % identity)
		_check(stripe_material.albedo_color == TeamData.color(identity).darkened(0.08), "lane %d stripe derives from canonical team color" % identity)
	main.queue_free()
	await process_frame

func _finish() -> void:
	if _failures.is_empty():
		print("P011 segment chain stress: PASS (%d checks, seed %08X, %d operations, %d insertions, %d matches, %d fresh, %d cache activity)" % [_checks, STRESS_SEED, STRESS_OPERATIONS, _stress_accepted, _stress_matches, _stress_fresh, _stress_cache_activity])
		quit(0)
		return
	for failure in _failures:
		push_error("P011 segment chain stress: " + failure)
	print("P011 segment chain stress: FAIL (%d failures / %d checks, seed %08X)" % [_failures.size(), _checks, STRESS_SEED])
	quit(1)
