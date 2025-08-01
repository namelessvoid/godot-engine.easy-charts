extends Label
class_name FunctionTypeLabel

var type: int
var marker: int
var color: Color
var indicator_visible: bool:
	get:
		return indicator_visible
	set(value):
		indicator_visible = value
		queue_redraw()

func _draw() -> void:
	if !indicator_visible:
		return

	var center: Vector2 = get_rect().get_center()

	match self.type:
		Function.Type.LINE:
			draw_line(
				Vector2(get_rect().position.x, center.y),
				Vector2(get_rect().end.x, center.y),
				color, 3
			)
		Function.Type.AREA:
			var color_light: Color = color
			color_light.a = 0.3
			draw_rect(
				Rect2(
					Vector2(get_rect().position.x, center.y),
					Vector2(get_rect().end.x, get_rect().end.y / 2)
				),
				color_light,
				3
			)
			draw_line(
				Vector2(get_rect().position.x, center.y),
				Vector2(get_rect().end.x, center.y),
				color,
				3
			)
		Function.Type.PIE:
			draw_rect(
				Rect2(center - (Vector2.ONE * 3), (Vector2.ONE * 3 * 2)),
				color,
				1.0
			)
		Function.Type.BAR:
			draw_rect(
				Rect2(
					Vector2(get_rect().position),
					Vector2(get_rect().end.x, get_rect().end.y)
				),
				color,
				3
			)
		Function.Type.SCATTER, _:
			pass
	match self.marker:
		Function.Marker.NONE:
			pass
		Function.Marker.SQUARE:
			draw_rect(
				Rect2(center - (Vector2.ONE * 3), (Vector2.ONE * 3 * 2)), 
				color, 1.0
			)
		Function.Marker.TRIANGLE:
			draw_colored_polygon(
				PackedVector2Array([
					center + (Vector2.UP * 3 * 1.3),
					center + (Vector2.ONE * 3 * 1.3),
					center - (Vector2(1, -1) * 3 * 1.3)
				]), color, [], null
			)
		Function.Marker.CROSS:
			draw_line(
				center - (Vector2.ONE * 3),
				center + (Vector2.ONE * 3),
				color, 3, true
			)
			draw_line(
				center + (Vector2(1, -1) * 3),
				center + (Vector2(-1, 1) * 3),
				color, 3 / 2, true
			)
		Function.Marker.CIRCLE, _:
			draw_circle(center, 3, color)
