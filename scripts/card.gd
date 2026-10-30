class_name Card
extends Button
## A movement card. Click it to move it between the hand and the slots, or drag it.

signal card_dropped_on(card: Card)

enum Dir { UP, DOWN, LEFT, RIGHT }

const OFFSETS := {
	Dir.UP: Vector2i(0, -1),
	Dir.DOWN: Vector2i(0, 1),
	Dir.LEFT: Vector2i(-1, 0),
	Dir.RIGHT: Vector2i(1, 0),
}
## Rotation that turns something pointing up into something pointing in this direction.
const ANGLES := {
	Dir.UP: 0.0,
	Dir.DOWN: PI,
	Dir.LEFT: -PI / 2,
	Dir.RIGHT: PI / 2,
}
const NAMES := {
	Dir.UP: "UP",
	Dir.DOWN: "DOWN",
	Dir.LEFT: "LEFT",
	Dir.RIGHT: "RIGHT",
}
const COLORS := {
	Dir.UP: Color("3b7dd8"),
	Dir.DOWN: Color("d8823b"),
	Dir.LEFT: Color("3ba55c"),
	Dir.RIGHT: Color("9b4fd1"),
}
const CARD_SIZE := Vector2(80, 110)
const ARROW_POINTS: Array[Vector2] = [
	Vector2(0, -24), Vector2(18, -4), Vector2(6, -4), Vector2(6, 20),
	Vector2(-6, 20), Vector2(-6, -4), Vector2(-18, -4),
]

var dir: Dir = Dir.UP


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var color: Color = COLORS[dir]
	add_theme_stylebox_override("normal", _make_style(Color("f4ecd8"), color))
	add_theme_stylebox_override("hover", _make_style(Color("fffaf0"), color))
	add_theme_stylebox_override("pressed", _make_style(Color("e6dcc4"), color))
	add_theme_stylebox_override("disabled", _make_style(Color("f4ecd8"), color))


func _draw() -> void:
	var color: Color = COLORS[dir]
	draw_set_transform(Vector2(size.x / 2, size.y * 0.42), ANGLES[dir])
	draw_colored_polygon(PackedVector2Array(ARROW_POINTS), color)
	draw_set_transform(Vector2.ZERO)
	draw_string(get_theme_default_font(), Vector2(0, size.y - 12), NAMES[dir],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, color.darkened(0.25))


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled:
		return null
	var preview := Card.new()
	preview.dir = dir
	preview.position = -CARD_SIZE / 2
	preview.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	modulate.a = 0.4
	return self


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and data != self and not disabled


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped_on.emit(data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0


func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style
