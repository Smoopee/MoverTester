class_name PileButton
extends Button
## A pile beside the hand, drawn as a stack of cards with its count: the draw pile face down with a
## cheese on its back, the discard pile under a skull. Pressing it opens the PileViewer.

enum Kind { DRAW, DISCARD }

## Size of the cards in the stack. Each card under the top one shows STACK_OFFSET lower and to the right.
const CARD := Vector2(56, 78)
const STACK_OFFSET := 3.0
## Cards drawn in the stack at most, however many are in the pile.
const MAX_LAYERS := 3
const BACK_COLOR := Color("8a3b2e")
const DISCARD_BG := Color("3a3230")
const CREAM := Color("f4ecd8")
const CHEESE := Color("f2c94c")
const BONE := Color("e8dcc8")
const BADGE := Color("2a2420")

@export var kind := Kind.DRAW
var count := 0:
	set(value):
		count = value
		queue_redraw()


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = CARD + Vector2.ONE * STACK_OFFSET * (MAX_LAYERS - 1) + Vector2(6, 8)


func _draw() -> void:
	var alpha := 0.45 if disabled else 1.0
	var lit := is_hovered() and not disabled
	var draw := kind == Kind.DRAW
	var bg := BACK_COLOR if draw else DISCARD_BG
	var border := CREAM if draw else Main.DISCARD_COLOR
	if lit:
		bg = bg.lightened(0.12)
	var top := Rect2(Vector2((size.x - CARD.x - STACK_OFFSET * (MAX_LAYERS - 1)) / 2, 2), CARD)
	var layers := mini(count, MAX_LAYERS)
	if layers == 0:
		_draw_card(top, Color(bg, 0.0), Color(border, 0.2 * alpha))
	for i in range(layers - 1, -1, -1):
		_draw_card(Rect2(top.position + Vector2.ONE * STACK_OFFSET * i, CARD), Color(bg, alpha),
				Color(border, alpha * (1.0 if i == 0 else 0.6)))
	if layers > 0:
		if draw:
			_draw_back(top, alpha)
		else:
			_draw_skull(top.get_center() + Vector2(0, -4), alpha)
		var badge := top.end - Vector2(6, 6)
		draw_circle(badge, 11, Color(BADGE, alpha))
		draw_circle(badge, 11, Color(border, alpha), false, 1.5)
		draw_string(get_theme_default_font(), badge + Vector2(-11, 5), str(count),
				HORIZONTAL_ALIGNMENT_CENTER, 22, 13, Color(CREAM, alpha))


func _draw_card(rect: Rect2, bg: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.draw(get_canvas_item(), rect)


## The draw pile's card back: an inner frame and a wedge of cheese.
func _draw_back(rect: Rect2, alpha: float) -> void:
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = Color(CREAM, 0.35 * alpha)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(4)
	frame.draw(get_canvas_item(), rect.grow(-6))
	var c := rect.get_center() + Vector2(0, -4)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-15, 8), c + Vector2(15, 8), c + Vector2(15, -10)]),
			Color(CHEESE, alpha))
	var hole := Color(CHEESE.darkened(0.3), alpha)
	draw_circle(c + Vector2(7, 3), 3, hole)
	draw_circle(c + Vector2(11, -4), 2, hole)
	draw_circle(c + Vector2(0, 5), 2, hole)


func _draw_skull(c: Vector2, alpha: float) -> void:
	var bone := Color(BONE, alpha)
	var dark := Color(DISCARD_BG, alpha)
	draw_circle(c + Vector2(0, -4), 13, bone)
	draw_rect(Rect2(c + Vector2(-8, 3), Vector2(16, 10)), bone)
	draw_circle(c + Vector2(-5, -4), 4, dark)
	draw_circle(c + Vector2(5, -4), 4, dark)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, 1), c + Vector2(-2, 5), c + Vector2(2, 5)]), dark)
	for x in [-4, 0, 4]:
		draw_line(c + Vector2(x, 8), c + Vector2(x, 13), dark, 1.5)
