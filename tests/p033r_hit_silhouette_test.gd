extends SceneTree

const EnemyTypesScript = preload("res://scripts/world/enemy_types.gd")
const ASSETS := ["enemy_hopper", "enemy_heavy", "enemy_sickle_snake", "enemy_healyzard"]

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failures.append(message)

func _run() -> void:
	_test_exact_mask_pixels()
	await _test_live_overlay_alignment_and_healing()
	await _test_snake_transfer_and_emergency()
	_test_renderer_evidence()
	_finish()

func _test_exact_mask_pixels() -> void:
	var lane_source := FileAccess.get_file_as_string("res://scripts/world/lane_actor.gd")
	_check(lane_source.find("HIT_FLASH_SHADER") < 0 and lane_source.find("ShaderMaterial") < 0, "runtime contains no legacy or replacement hit shader")
	for asset_name in ASSETS:
		var source := Image.new()
		var mask := Image.new()
		var source_error := source.load(ProjectSettings.globalize_path("res://assets/sprites/baked/%s.png" % asset_name))
		var mask_error := mask.load(ProjectSettings.globalize_path("res://assets/sprites/hit_masks/%s_hit.png" % asset_name))
		_check(source_error == OK and mask_error == OK and source.get_size() == Vector2i(512, 512) and mask.get_size() == source.get_size(), "%s source and mask are matching 512x512 RGBA images" % asset_name)
		if source_error != OK or mask_error != OK or source.get_size() != mask.get_size():
			continue
		source.convert(Image.FORMAT_RGBA8)
		mask.convert(Image.FORMAT_RGBA8)
		var alpha_mismatches := 0
		var color_mismatches := 0
		var visible_pixels := 0
		for y in range(512):
			for x in range(512):
				var source_pixel := source.get_pixel(x, y)
				var mask_pixel := mask.get_pixel(x, y)
				if source_pixel.a != mask_pixel.a:
					alpha_mismatches += 1
				if mask_pixel.a > 0.0:
					visible_pixels += 1
					if mask_pixel.r != 1.0 or mask_pixel.g != 0.0 or mask_pixel.b != 0.0:
						color_mismatches += 1
		_check(alpha_mismatches == 0, "%s mask preserves all 262144 source alpha bytes exactly" % asset_name)
		_check(visible_pixels > 1000 and color_mismatches == 0, "%s every visible mask pixel is exact solid red" % asset_name)

func _new_lane(identity := TeamData.Identity.RED) -> LaneActor:
	var lane := LaneActor.new()
	lane.setup(identity, identity)
	root.add_child(lane)
	lane.set_process(false)
	lane.combat_model.clear_for_test()
	lane.combat_model.max_enemies = 8
	return lane

func _test_live_overlay_alignment_and_healing() -> void:
	var lane := _new_lane(TeamData.Identity.GREEN)
	await process_frame
	var uids: Array[int] = []
	for enemy_type in range(4):
		uids.append(lane.combat_model.spawn_enemy(1.0 + enemy_type, -1, false, enemy_type, 3600 + enemy_type))
	lane.call("_sync_visuals")
	for enemy_type in range(4):
		var visual: Dictionary = lane.get("_enemy_visuals")[uids[enemy_type]]
		var sprite := visual.sprite as Sprite2D
		var overlay := visual.hit_overlay as Sprite2D
		_check(sprite.material == null and overlay.material == null, "%s base and overlay use no shader material" % ASSETS[enemy_type])
		_check(overlay.get_parent() == sprite.get_parent() and overlay.offset == sprite.offset and overlay.centered == sprite.centered and overlay.texture_filter == sprite.texture_filter and overlay.z_index == sprite.z_index + 1, "%s overlay exactly shares base pivot/filter/parent transforms" % ASSETS[enemy_type])
		_check((overlay.texture as Texture2D).get_size() == (sprite.texture as Texture2D).get_size() and not overlay.visible and overlay.modulate.a == 0.0, "%s overlay starts aligned and fully invisible" % ASSETS[enemy_type])

	var hopper_overlay := lane.get("_enemy_visuals")[uids[0]].hit_overlay as Sprite2D
	var overlay_id := hopper_overlay.get_instance_id()
	lane.combat_model.call("_damage_enemy", uids[0], 1, 1.0)
	lane.call("_sync_visuals")
	_check(hopper_overlay.visible and hopper_overlay.modulate.a == 1.0, "real nonlethal damage starts opaque red overlay")
	lane.combat_model.update(0.08)
	lane.call("_sync_visuals")
	_check(hopper_overlay.visible and absf(hopper_overlay.modulate.a - 0.5) < 0.001, "live overlay follows the authoritative 0.16-second linear fade")
	lane.combat_model.call("_damage_enemy", uids[0], 1, 1.0)
	lane.call("_sync_visuals")
	_check(hopper_overlay.get_instance_id() == overlay_id and hopper_overlay.modulate.a == 1.0, "repeat hit refreshes one cached overlay node/texture")

	var healer_uid := uids[3]
	var healer_overlay := lane.get("_enemy_visuals")[healer_uid].hit_overlay as Sprite2D
	var heavy_overlay := lane.get("_enemy_visuals")[uids[1]].hit_overlay as Sprite2D
	for index in range(lane.combat_model.enemies.size()):
		if int(lane.combat_model.enemies[index].uid) == uids[1]:
			lane.combat_model.enemies[index].hp = 5
		if int(lane.combat_model.enemies[index].uid) == healer_uid:
			lane.combat_model.enemies[index].heal_timer = 0.001
	lane.combat_model.update(0.001)
	lane.call("_sync_visuals")
	_check(not healer_overlay.visible and not heavy_overlay.visible, "Healyzard healing changes HP without inventing a damage overlay")

	for index in range(lane.combat_model.enemies.size()):
		if int(lane.combat_model.enemies[index].uid) == uids[0]:
			lane.combat_model.enemies[index].hp = 1
	lane.combat_model.call("_damage_enemy", uids[0], 1, 1.0)
	_check(lane.get("_death_effects").size() == 1 and hopper_overlay.visible and hopper_overlay.modulate.a == 1.0, "lethal damage transfers the same full-red overlay into corpse animation")
	lane.call("_update_death_effects", 0.08)
	_check(absf(hopper_overlay.modulate.a - 0.5) < 0.001, "lethal overlay fades halfway at 0.08 seconds")
	lane.call("_update_death_effects", 0.081)
	_check(not hopper_overlay.visible and hopper_overlay.modulate.a == 0.0, "lethal overlay is hidden after 0.16 seconds while corpse remains")
	lane.reset_run(false)
	_check(lane.get("_enemy_visuals").is_empty() and lane.get("_death_effects").is_empty(), "restart leaves no stale silhouette or corpse nodes")
	lane.queue_free()
	await process_frame

func _test_snake_transfer_and_emergency() -> void:
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	await process_frame
	battlefield.set_process(false)
	for lane in battlefield.lanes:
		lane.set_process(false)
		lane.combat_model.clear_for_test()
		lane.combat_model.set_enemy_spawn_budget(8)
	battlefield.call("_reset_spawn_director", false)
	var snake_uid := battlefield.spawn_directed_enemy(0, EnemyTypesScript.Type.SICKLE_SNAKE, 2.0, -1, false)
	var spawn_id := int(battlefield.lanes[0].combat_model.enemies[0].spawn_id)
	battlefield.lanes[0].call("_sync_visuals")
	var original_overlay := battlefield.lanes[0].get("_enemy_visuals")[snake_uid].hit_overlay as Sprite2D
	battlefield.lanes[0].combat_model.call("_damage_enemy", snake_uid, 1, 2.0)
	battlefield.lanes[0].call("_sync_visuals")
	var overlay_id := original_overlay.get_instance_id()
	battlefield.call("_update_snake_special", 0.5)
	var location: Dictionary = battlefield.call("_find_enemy_by_spawn_id", spawn_id)
	var transferred_visual: Dictionary = battlefield.lanes[int(location.lane_index)].get("_enemy_visuals")[int(location.enemy.uid)]
	_check(int(location.lane_index) == 1 and (transferred_visual.hit_overlay as Sprite2D).get_instance_id() == overlay_id, "Snake lane transfer reparents the exact overlay with its visual identity")

	var emergency_uid := battlefield.spawn_directed_enemy(2, EnemyTypesScript.Type.HEAVY, 2.0, -1, false)
	battlefield.lanes[2].call("_sync_visuals")
	var emergency_overlay := battlefield.lanes[2].get("_enemy_visuals")[emergency_uid].hit_overlay as Sprite2D
	battlefield.lanes[2].combat_model.call("_discharge_emergency")
	var emergency_effect: Dictionary = battlefield.lanes[2].get("_death_effects")[0]
	_check(emergency_effect.hit_overlay == emergency_overlay and not emergency_overlay.visible and float(emergency_effect.hit_flash_start) == 0.0, "emergency clear keeps an unhurt corpse overlay invisible")
	battlefield.queue_free()
	await process_frame

func _test_renderer_evidence() -> void:
	for fixture in [{"path": "res://assets/previews/p033_controls_hit_flash_1280x720.png", "size": Vector2i(1280, 720)}, {"path": "res://assets/previews/p033_controls_settings_1600x720.png", "size": Vector2i(1600, 720)}, {"path": "res://assets/previews/p033r_hit_overlay_comparison_1280x512.png", "size": Vector2i(1280, 512)}]:
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(str(fixture.path)))
		_check(error == OK and image.get_size() == fixture.size, "%s is real-renderer P033R evidence" % fixture.path)
		if error == OK:
			var vivid_red := 0
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					var pixel := image.get_pixel(x, y)
					if pixel.r > 0.95 and pixel.g < 0.05 and pixel.b < 0.05 and pixel.a > 0.9:
						vivid_red += 1
			_check(vivid_red > 100, "%s contains unmistakable rendered solid-red silhouette pixels" % fixture.path)

func _finish() -> void:
	if _failures.is_empty():
		print("P033R hit silhouette: PASS (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("P033R hit silhouette: " + failure)
	print("P033R hit silhouette: FAIL (%d failures / %d checks)" % [_failures.size(), _checks])
	quit(1)
