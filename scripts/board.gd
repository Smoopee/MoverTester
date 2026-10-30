class_name Board
extends Control
## The grid, the mouse and the cheese, all drawn in code.

const GRID := 20
const CELL := 30
const STEP_TIME := 0.25

const FLOOR_LIGHT := Color("e9dcc0")
const FLOOR_DARK := Color("ded0b1")
const BORDER := Color("6b5638")
const CHEESE := Color("f5c542")
const CHEESE_HOLE := Color("d9a520")
const FUR := Color("9a9a9e")
const FUR_DARK := Color("7d7d82")
const PINK := Color("f2a6b3")

var mouse_cell := Vector2i.ZERO
var cheese_cell := Vector2i.ZERO
var facing: Card.Dir = Card.Dir.UP
## Mouse position in cell units; tweened between cells so the move is animated.
var mouse_pos := Vector2.ZERO:
	set(value):
		mouse_pos = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(GRID * CELL, GRID * CELL)


func place(mouse: Vector2i, cheese: Vector2i) -> void:
	mouse_cell = mouse
	cheese_cell = cheese
	facing = Card.Dir.UP
	mouse_pos = Vector2(mouse)


## Moves the mouse one cell (bumping off walls). Returns true if it is on the cheese.
func step(dir: Card.Dir) -> bool:
	facing = dir
	var offset: Vector2i = Card.OFFSETS[dir]
	var target := mouse_cell + offset
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	if _in_bounds(target):
		mouse_cell = target
		tween.tween_property(self, "mouse_pos", Vector2(target), STEP_TIME)
	else:
		var bump := Vector2(mouse_cell) + Vector2(offset) * 0.25
		tween.tween_property(self, "mouse_pos", bump, STEP_TIME / 2)
		tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), STEP_TIME / 2)
	await tween.finished
	return mouse_cell == cheese_cell


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID and cell.y < GRID


func _draw() -> void:
	for y in GRID:
		for x in GRID:
			var color := FLOOR_LIGHT if (x + y) % 2 == 0 else FLOOR_DARK
			draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), color)
	draw_rect(Rect2(0, 0, GRID * CELL, GRID * CELL), BORDER, false, 3.0)
	_draw_cheese(_cell_center(Vector2(cheese_cell)))
	_draw_mouse(_cell_center(mouse_pos))


func _cell_center(cell: Vector2) -> Vector2:
	return (cell + Vector2(0.5, 0.5)) * CELL


func _draw_cheese(center: Vector2) -> void:
	var wedge := PackedVector2Array([
		center + Vector2(-12, 9), center + Vector2(12, 9), center + Vector2(12, -9),
	])
	draw_colored_polygon(wedge, CHEESE)
	wedge.append(wedge[0])
	draw_polyline(wedge, CHEESE_HOLE, 1.5, true)
	draw_circle(center + Vector2(6, 4), 2.5, CHEESE_HOLE)
	draw_circle(center + Vector2(9, -3), 1.6, CHEESE_HOLE)
	draw_circle(center + Vector2(0, 6), 1.5, CHEESE_HOLE)


## Draws a top-down mouse facing up, rotated to the direction it last moved.
func _draw_mouse(center: Vector2) -> void:
	draw_set_transform(center, Card.ANGLES[facing])
	var tail := PackedVector2Array([Vector2(0, 11), Vector2(3, 15), Vector2(-1, 18), Vector2(2, 21)])
	draw_polyline(tail, PINK, 2.0, true)
	draw_colored_polygon(_ellipse(Vector2(0, 3), Vector2(7.5, 10)), FUR)
	for side in [-1, 1]:
		draw_circle(Vector2(5.5 * side, -6), 4.0, FUR_DARK)
		draw_circle(Vector2(5.5 * side, -6), 2.3, PINK)
	draw_colored_polygon(_ellipse(Vector2(0, -7), Vector2(5, 7)), FUR)
	draw_circle(Vector2(0, -14), 1.8, PINK)
	draw_circle(Vector2(-2.2, -9), 1.1, Color.BLACK)
	draw_circle(Vector2(2.2, -9), 1.1, Color.BLACK)
	draw_set_transform(Vector2.ZERO)


func _ellipse(center: Vector2, radii: Vector2, points := 20) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points:
		var angle := TAU * i / points
		result.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return result
