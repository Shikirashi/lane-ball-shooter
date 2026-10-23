class_name TeamData
extends RefCounted

enum Identity { RED, BLUE, YELLOW, GREEN }

const COUNT := 4
const NAMES: Array[String] = ["RED", "BLUE", "YELLOW", "GREEN"]
const SYMBOL_NAMES: Array[String] = ["DOT", "SQUARE", "TRIANGLE", "DIAMOND"]
const COLORS: Array[Color] = [
	Color("ef5b5b"),
	Color("55a7ff"),
	Color("f3cf4b"),
	Color("58d68d"),
]

static func color(identity: int) -> Color:
	return COLORS[posmod(identity, COUNT)]

static func display_name(identity: int) -> String:
	return NAMES[posmod(identity, COUNT)]

static func symbol_name(identity: int) -> String:
	return SYMBOL_NAMES[posmod(identity, COUNT)]

static func draw_symbol(canvas: CanvasItem, identity: int, center: Vector2, radius: float, tint: Color = Color.WHITE) -> void:
	match posmod(identity, COUNT):
		Identity.RED:
			canvas.draw_circle(center, radius * 0.34, tint)
		Identity.BLUE:
			var half := radius * 0.38
			canvas.draw_rect(Rect2(center - Vector2.ONE * half, Vector2.ONE * half * 2.0), tint, true)
		Identity.YELLOW:
			var points := PackedVector2Array([
				center + Vector2(0.0, -radius * 0.48),
				center + Vector2(radius * 0.45, radius * 0.38),
				center + Vector2(-radius * 0.45, radius * 0.38),
			])
			canvas.draw_colored_polygon(points, tint)
		Identity.GREEN:
			var points := PackedVector2Array([
				center + Vector2(0.0, -radius * 0.48),
				center + Vector2(radius * 0.42, 0.0),
				center + Vector2(0.0, radius * 0.48),
				center + Vector2(-radius * 0.42, 0.0),
			])
			canvas.draw_colored_polygon(points, tint)

