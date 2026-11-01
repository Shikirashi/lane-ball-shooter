class_name LbsPhotoProjectileTrail
extends Control

var identity := TeamData.Identity.RED
var projectile_position := Vector2.ZERO
var trail_length := 64.0
var photo_projectile_radius := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func configure(value: int, position_value: Vector2, length_value := 64.0, radius_value := 0.0) -> void:
	identity = posmod(value, TeamData.COUNT)
	projectile_position = position_value
	trail_length = clampf(length_value, 36.0, 88.0)
	photo_projectile_radius = clampf(radius_value, 0.0, 28.0)
	queue_redraw()


func _draw() -> void:
	var color := TeamData.color(identity)
	# The projectile travels upward, so every capture-only afterimage remains
	# narrowly localized below the authentic ShooterView ball.
	draw_line(
		projectile_position + Vector2(0.0, 11.0),
		projectile_position + Vector2(0.0, trail_length),
		Color(color, 0.12),
		5.0,
		true
	)
	var offsets := [18.0, 34.0, 51.0]
	var radii := [8.5, 6.5, 4.0]
	var alphas := [0.28, 0.16, 0.08]
	for index in range(offsets.size()):
		var ratio: float = float(offsets[index]) / 64.0
		draw_circle(
			projectile_position + Vector2(0.0, trail_length * ratio),
			radii[index],
			Color(color, alphas[index])
		)
	if photo_projectile_radius > 0.0:
		# Second-pass photo overlay only: cover the authentic frozen 12px shot at
		# the exact same center without touching ShooterView's runtime radius.
		draw_circle(projectile_position + Vector2(2.0, 4.0), photo_projectile_radius + 1.0, Color(0.0, 0.0, 0.0, 0.38))
		draw_circle(projectile_position, photo_projectile_radius, color)
		TeamData.draw_symbol(
			self,
			identity,
			projectile_position,
			photo_projectile_radius,
			Color(0.04, 0.04, 0.04, 0.9)
		)
