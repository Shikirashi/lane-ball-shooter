class_name ResponsiveLayout
extends RefCounted

const EDGE_PADDING_MIN := 10.0
const EDGE_PADDING_MAX := 18.0
const MAX_3D_WIDTH := 1600.0
const MAX_3D_HEIGHT := 720.0

static func calculate(viewport_size: Vector2, requested_safe_rect := Rect2()) -> Dictionary:
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size.max(Vector2.ONE))
	var safe_rect := requested_safe_rect.intersection(viewport_rect)
	if safe_rect.size.x < 480.0 or safe_rect.size.y < 300.0:
		safe_rect = viewport_rect

	var edge_padding := clampf(safe_rect.size.y * 0.019, EDGE_PADDING_MIN, EDGE_PADDING_MAX)
	var hud_height := clampf(safe_rect.size.y * 0.10, 62.0, 78.0)
	var chain_height := clampf(safe_rect.size.y * 0.13, 76.0, 104.0)
	var bottom_height := clampf(safe_rect.size.y * 0.18, 112.0, 148.0)
	var content_left := safe_rect.position.x + edge_padding
	var content_right := safe_rect.end.x - edge_padding
	var content_width := maxf(1.0, content_right - content_left)
	var center_top := safe_rect.position.y + hud_height + chain_height + 8.0
	var center_bottom := safe_rect.end.y - bottom_height
	var center_height := maxf(1.0, center_bottom - center_top)

	var magazine_size := Vector2(56.0, 56.0)
	var magazine_rect := Rect2(
		Vector2(content_right - magazine_size.x, safe_rect.position.y + 4.0),
		magazine_size
	)
	var track_left := content_left + 24.0
	var track_right := content_right - 24.0
	var chain_lane_center := safe_rect.position.y + hud_height + 10.0 + maxf(56.0, chain_height - 14.0) * 0.5

	return {
		"viewport_rect": viewport_rect,
		"safe_rect": safe_rect,
		"hud_rect": Rect2(safe_rect.position, Vector2(safe_rect.size.x, hud_height)),
		"chain_rect": Rect2(Vector2(content_left, safe_rect.position.y + hud_height), Vector2(content_width, chain_height)),
		"battlefield_rect": Rect2(Vector2(content_left, center_top), Vector2(content_width, center_height)),
		"magazine_rect": magazine_rect,
		"playfield_rect": Rect2(Vector2(content_left, center_top), Vector2(content_width, safe_rect.end.y - center_top)),
		"shooter_y": safe_rect.end.y - maxf(48.0, edge_padding + 30.0),
		"track_left": track_left,
		"track_right": track_right,
		"shot_ceiling": chain_lane_center,
	}

static func bounded_render_size(container_size: Vector2) -> Vector2i:
	var source := container_size.max(Vector2.ONE)
	var scale := minf(1.0, minf(MAX_3D_WIDTH / source.x, MAX_3D_HEIGHT / source.y))
	return Vector2i(maxi(1, roundi(source.x * scale)), maxi(1, roundi(source.y * scale)))
