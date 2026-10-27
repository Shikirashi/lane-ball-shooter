extends Node2D

const ASSET_DIR := "res://assets/sprites/baked"
const ACTOR_NAMES := [
	"enemy_hopper", "enemy_heavy", "enemy_sickle_snake", "enemy_healyzard",
	"defender_red", "defender_blue", "defender_yellow", "defender_green",
]
const DISPLAY_NAMES := [
	"HOPPER", "HEAVY", "SICKLE SNAKE", "HEALYZARD",
	"RED DEFENDER", "BLUE DEFENDER", "YELLOW DEFENDER", "GREEN DEFENDER",
]

var _sprites: Array[Sprite2D] = []
var _time := 0.0


func _ready() -> void:
	_build_preview()
	queue_redraw()
	if OS.get_cmdline_user_args().has("--p034a-smoke"):
		get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(0))


func _process(delta: float) -> void:
	_time += delta
	if _sprites.size() != 8:
		return
	var bounce := maxf(0.0, sin(_time * 3.0))
	_sprites[0].position.y = 151.0 - bounce * 30.0
	_sprites[0].scale = Vector2(0.29 + bounce * 0.025, 0.29 - bounce * 0.02)
	var heavy_squash := (sin(_time * 2.2) + 1.0) * 0.5
	_sprites[1].scale = Vector2(0.28 + heavy_squash * 0.045, 0.28 - heavy_squash * 0.025)
	_sprites[2].rotation = sin(_time * 4.0) * 0.08
	_sprites[2].scale = Vector2(0.27 - sin(_time * 4.0) * 0.018, 0.27 + sin(_time * 4.0) * 0.025)
	var pulse := sin(_time * 3.4) * 0.018
	_sprites[3].scale = Vector2.ONE * (0.30 + pulse)
	for index in range(4, 8):
		var phase := _time * 2.4 + float(index - 4) * 0.5
		_sprites[index].rotation = -0.05 - maxf(0.0, sin(phase)) * 0.16
		_sprites[index].scale = Vector2(0.29 + maxf(0.0, cos(phase)) * 0.018, 0.29 - maxf(0.0, cos(phase)) * 0.018)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("111827"))
	for lane in range(4):
		var y := 151.0 + lane * 142.0
		draw_rect(Rect2(38.0, y - 7.0, 1204.0, 14.0), Color("222b3a"))
		draw_rect(Rect2(38.0, y + 7.0, 1204.0, 2.0), TeamData.color(lane).darkened(0.12))


func _build_preview() -> void:
	var metadata_text := FileAccess.get_file_as_string("%s/pivots.json" % ASSET_DIR)
	var metadata = JSON.parse_string(metadata_text)
	if not metadata is Dictionary:
		push_error("P034A preview could not read pivot metadata")
		return
	var title := Label.new()
	title.text = "P034A — BAKED 3D ACTORS / 2D MOTION STUDY"
	title.position = Vector2(36.0, 18.0)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	for lane in range(4):
		_add_actor(ACTOR_NAMES[lane], Vector2(1000.0, 151.0 + lane * 142.0), metadata)
	for lane in range(4):
		_add_actor(ACTOR_NAMES[4 + lane], Vector2(210.0, 151.0 + lane * 142.0), metadata)
	for lane in range(4):
		_add_label(DISPLAY_NAMES[4 + lane], Vector2(42.0, 95.0 + lane * 142.0), TeamData.color(lane).lightened(0.18))
		_add_label(DISPLAY_NAMES[lane], Vector2(1040.0, 95.0 + lane * 142.0), Color("f4f0df"))


func _add_actor(actor_name: String, ground_position: Vector2, metadata: Dictionary) -> void:
	var texture := load("%s/%s.png" % [ASSET_DIR, actor_name]) as Texture2D
	if texture == null:
		push_error("P034A preview missing %s" % actor_name)
		return
	var actor_data: Dictionary = metadata.actors.get(actor_name, {})
	var pivot: Array = actor_data.get("pivot", [256, 440])
	var sprite := Sprite2D.new()
	sprite.name = actor_name.to_pascal_case()
	sprite.texture = texture
	sprite.position = ground_position
	sprite.offset = Vector2(256.0 - float(pivot[0]), 256.0 - float(pivot[1]))
	sprite.scale = Vector2.ONE * 0.29
	add_child(sprite)
	_sprites.append(sprite)


func _add_label(text_value: String, position_value: Vector2, color_value: Color) -> void:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.modulate = color_value
	label.add_theme_font_size_override("font_size", 17)
	add_child(label)
