extends SceneTree
# Narrow UI regression: per-lane status text must never render.
# Combat/revive/charge logic and the charge crystal remain unchanged.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _run() -> void:
	for identity in range(TeamData.COUNT):
		var lane := LaneActor.new()
		lane.setup(identity, identity, true)
		root.add_child(lane)
		lane.set_process(false)
		await process_frame

		var label := lane.get_node_or_null("LaneStatus") as Label
		_check(label != null, "team %d retains a compatibility status node" % identity)
		if label != null:
			_check(not label.visible, "team %d status text hidden during gameplay" % identity)

		var crystal := lane.get("_charge_crystal") as Node2D
		_check(crystal != null and crystal.visible, "team %d charge crystal still displays" % identity)
		lane.configure_layout(Vector2(1280, 120))
		lane.call("_update_status_visual")
		_check(label == null or not label.visible, "team %d status stays hidden after layout and sync" % identity)

		lane.combat_model.call("_knock_down")
		lane.call("_update_status_visual")
		_check(label == null or not label.visible, "team %d status stays hidden when knocked down" % identity)

		lane.reset_run(false)
		_check(label == null or not label.visible, "team %d status stays hidden after restart" % identity)
		lane.queue_free()
		await process_frame

	if not failures.is_empty():
		for message in failures:
			push_error(message)
		print("Defender status hidden: FAIL (%d failures, %d checks)" % [failures.size(), checks])
		quit(1)
		return
	print("Defender status hidden: PASS (%d checks)" % checks)
	quit(0)
