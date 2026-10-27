extends SceneTree

const EnemyTypesScript = preload("res://scripts/world/enemy_types.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _run() -> void:
	_test_original_chain_defaults()
	await _test_live_mild_generator()
	if failures.is_empty():
		print("P028B mild live playtest: PASS (%d checks)" % checks)
		quit(0)
		return
	for failure in failures:
		push_error("P028B mild live playtest: " + failure)
	print("P028B mild live playtest: FAIL (%d failures / %d checks)" % [failures.size(), checks])
	quit(1)

func _test_original_chain_defaults() -> void:
	var control := ChainModel.new()
	_check(control.speed == 102.0, "conveyor speed remains 102 px/s")
	_check(control.fresh_run_length_weights == [20, 30, 18, 13, 9, 6, 4], "shipped run-length weights remain unchanged")
	_check(not control.analysis_fresh_run_selector.is_valid(), "standalone ChainModel retains the unbiased default")
	_check(not control.analysis_fresh_run_length_selector.is_valid(), "standalone ChainModel requires explicit opt-in")

func _test_live_mild_generator() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.set_process(false)
	var chain: ChainModel = main.get("_chain_model")
	var battlefield: Battlefield = main.get("_battlefield")
	var selector: ThreatRunSelector = main.get("_threat_bias")
	_check(selector != null and selector.arm == "mild" and is_equal_approx(selector.boost, 0.5), "running game actually installs the mild 50% selector")
	_check(chain.analysis_fresh_run_selector.is_valid(), "running game installs real run-choice callback")
	_check(chain.analysis_fresh_run_selector.get_object() == selector, "callback belongs to live playtest selector")
	_check(chain.analysis_fresh_run_length_selector.is_valid(), "experimental shadow generator preserves baseline length sequence")
	_check(chain.speed == 102.0 and chain.fresh_run_length_weights == [20, 30, 18, 13, 9, 6, 4], "mild playtest leaves speed and length weights unchanged")

	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.enemies.clear()
	main.call("_process", 0.1)
	_check(is_inf(selector.threat_snapshot[0]), "without enemies the live snapshot shows no urgency")
	_check(selector.choose([0, 1, 2, 3], -1, 0.0, 2) == 2, "no-threat run keeps the baseline color")

	# Direct current state, not future spawn information or a guessed color.
	battlefield.spawn_directed_enemy(TeamData.Identity.RED, EnemyTypesScript.Type.HOPPER, 1.6, -1, false)
	main.call("_process", 0.1)
	_check(selector.threat_snapshot[TeamData.Identity.RED] < 15.0, "live enemy near RED defender activates urgency in that lane")
	_check(is_inf(selector.threat_snapshot[TeamData.Identity.BLUE]), "safe BLUE lane remains unthreatened")
	_check(selector.urgency_for_ttd(selector.threat_snapshot[TeamData.Identity.RED]) > 0.0, "live urgency activates tested sampler")
	_check(selector.choose([1, 2, 3], 0, 0.0, 2) == 2, "exhausted threatened RED never reshuffles unrelated legal colors")

	var before_restart: ThreatRunSelector = selector
	main.call("_restart_run")
	var refreshed: ThreatRunSelector = main.get("_threat_bias")
	_check(refreshed != before_restart, "restart creates a fresh independent bias RNG and run history")
	_check(refreshed.arm == "mild" and refreshed.selection_count == 0, "restart preserves mild mode but clears run selection history")
	_check(chain.analysis_fresh_run_selector.get_object() == refreshed, "restart reattaches callbacks to the fresh selector")
	_check(chain.speed == 102.0, "restart does not change physical conveyor speed")

	main.queue_free()
	await process_frame
