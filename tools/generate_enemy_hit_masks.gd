extends SceneTree

const SOURCE_DIR := "res://assets/sprites/baked"
const OUTPUT_DIR := "res://assets/sprites/hit_masks"
const ENEMY_ASSETS := ["enemy_hopper", "enemy_heavy", "enemy_sickle_snake", "enemy_healyzard"]
const MASK_RED := Color(1.0, 0.0, 0.0, 1.0)

func _initialize() -> void:
	var output_absolute := ProjectSettings.globalize_path(OUTPUT_DIR)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(output_absolute)
	if mkdir_error != OK:
		push_error("P033R could not create %s (error %d)" % [output_absolute, mkdir_error])
		quit(1)
		return
	for asset_name in ENEMY_ASSETS:
		var source := Image.new()
		var source_path := "%s/%s.png" % [SOURCE_DIR, asset_name]
		if source.load(ProjectSettings.globalize_path(source_path)) != OK or source.is_empty():
			push_error("P033R could not load %s" % source_path)
			quit(1)
			return
		source.convert(Image.FORMAT_RGBA8)
		var mask := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
		for y in range(source.get_height()):
			for x in range(source.get_width()):
				mask.set_pixel(x, y, Color(MASK_RED, source.get_pixel(x, y).a))
		var mask_path := "%s/%s_hit.png" % [OUTPUT_DIR, asset_name]
		var save_error := mask.save_png(ProjectSettings.globalize_path(mask_path))
		if save_error != OK:
			push_error("P033R could not save %s (error %d)" % [mask_path, save_error])
			quit(1)
			return
	print("P033R hit masks: wrote %d exact-alpha red silhouettes to %s" % [ENEMY_ASSETS.size(), OUTPUT_DIR])
	quit(0)
