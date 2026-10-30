class_name Board
extends Control
## The grid, the mouse, the cheese and the mouse traps, all drawn in code.

const GRID := 20
const CELL := 30
const STEP_TIME := 0.25
const SLIDE_CELL_TIME := 0.05
const JUMP_TIME := 0.4
const HOP_HEIGHT := 14.0

const FLOOR_LIGHT := Color("e9dcc0")
const FLOOR_DARK := Color("ded0b1")
const BORDER := Color("6b5638")
const CHEESE := Color("f5c542")
const CHEESE_HOLE := Color("d9a520")
const FUR := Color("9a9a9e")
const FUR_DARK := Color("7d7d82")
const PINK := Color("f2a6b3")
const TRAP_WOOD := Color("d9a066")
const TRAP_GRAIN := Color("c08850")
const TRAP_WOOD_EDGE := Color("8a5a2b")
const STEEL := Color("dfe3ea")
const STEEL_EDGE := Color("4a4e55")
const SHADOW := Color(0, 0, 0, 0.2)

## When false, moves finish instantly instead of tweening (used by the headless balance sim).
var animate := true
var mouse_cell := Vector2i.ZERO
var cheese_cell := Vector2i.ZERO
## Cells with a mouse trap. Moving onto one loses the round; jumping over one is safe.
var traps: Array[Vector2i] = []
var facing: Card.Dir = Card.Dir.UP
## Mouse position in cell units; tweened between cells so the move is animated.
var mouse_pos := Vector2.ZERO:
	set(value):
		mouse_pos = value
		queue_redraw()
## How far the mouse is off the floor, in pixels, while jumping.
var hop := 0.0:
	set(value):
		hop = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(GRID * CELL, GRID * CELL)


func place(mouse: Vector2i, cheese: Vector2i, trap_cells: Array[Vector2i] = []) -> void:
	mouse_cell = mouse
	cheese_cell = cheese
	traps = trap_cells
	facing = Card.Dir.UP
	mouse_pos = Vector2(mouse)


## Moves the mouse one cell (bumping off walls, or coming in on the opposite side if wrap is set).
## Returns true if the move ends the round (see _finish).
func step(dir: Card.Dir, wrap := false) -> bool:
	facing = dir
	var offset: Vector2i = Card.OFFSETS[dir]
	var target := mouse_cell + offset
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	if _in_bounds(target):
		mouse_cell = target
		tween.tween_property(self, "mouse_pos", Vector2(target), STEP_TIME)
	elif wrap:
		target = Vector2i(posmod(target.x, GRID), posmod(target.y, GRID))
		mouse_cell = target
		tween.tween_property(self, "mouse_pos", mouse_pos + Vector2(offset) * 0.5, STEP_TIME / 2)
		tween.tween_callback(func() -> void: mouse_pos = Vector2(target) - Vector2(offset) * 0.5)
		tween.tween_property(self, "mouse_pos", Vector2(target), STEP_TIME / 2)
	else:
		var bump := Vector2(mouse_cell) + Vector2(offset) * 0.25
		tween.tween_property(self, "mouse_pos", bump, STEP_TIME / 2)
		tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), STEP_TIME / 2)
	return await _finish(tween)


## Moves the mouse in a straight line until it hits a wall, a trap or the cheese.
func slide(dir: Card.Dir) -> bool:
	var offset: Vector2i = Card.OFFSETS[dir]
	if not _in_bounds(mouse_cell + offset):
		return await step(dir)
	facing = dir
	var cells := 0
	while _in_bounds(mouse_cell + offset) and mouse_cell != cheese_cell and not is_caught():
		mouse_cell += offset
		cells += 1
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), SLIDE_CELL_TIME * cells + STEP_TIME)
	return await _finish(tween)


## Hops the mouse by offset, passing over the cells in between. Lands as far as the walls allow.
func jump(offset: Vector2i, dir: Card.Dir) -> bool:
	facing = dir
	mouse_cell = (mouse_cell + offset).clamp(Vector2i.ZERO, Vector2i(GRID - 1, GRID - 1))
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), JUMP_TIME)
	tween.tween_method(func(t: float) -> void: hop = sin(t * PI) * HOP_HEIGHT, 0.0, 1.0, JUMP_TIME)
	return await _finish(tween)


## True when the mouse is on a trap cell.
func is_caught() -> bool:
	return mouse_cell in traps


## Waits for a move's tween, or skips it when not animating. Returns true if the round is over:
## the mouse is on the cheese or caught in a trap.
func _finish(tween: Tween) -> bool:
	if animate:
		await tween.finished
	else:
		tween.kill()
		mouse_pos = Vector2(mouse_cell)
		hop = 0.0
	return mouse_cell == cheese_cell or is_caught()


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID and cell.y < GRID


func _draw() -> void:
	for y in GRID:
		for x in GRID:
			var color := FLOOR_LIGHT if (x + y) % 2 == 0 else FLOOR_DARK
			draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), color)
	draw_rect(Rect2(0, 0, GRID * CELL, GRID * CELL), BORDER, false, 3.0)
	_draw_cheese(_cell_center(Vector2(cheese_cell)))
	# Once the mouse has landed on a trap, that trap has snapped shut.
	var snapped := is_caught() and mouse_pos == Vector2(mouse_cell)
	for trap in traps:
		_draw_trap(_cell_center(Vector2(trap)), snapped and trap == mouse_cell)
	var center := _cell_center(mouse_pos)
	if hop > 0.0:
		draw_colored_polygon(_ellipse(center + Vector2(0, 6), Vector2(9, 4)), SHADOW)
	_draw_mouse(center - Vector2(0, hop))
	if snapped:
		var bar := PackedVector2Array([Vector2(-6, -1), Vector2(-6, 9), Vector2(6, 9), Vector2(6, -1)])
		_draw_steel(_offset(bar, center), 2.5)


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


## Draws a top-down snap trap: a wooden block with a steel bar cocked back over the top half and a
## cheese bait pedal on the bottom half. A snapped trap leaves out the bar and bait, which the caller
## draws over the mouse instead.
func _draw_trap(center: Vector2, snapped: bool) -> void:
	var base := Rect2(center - Vector2(8, 13), Vector2(16, 26))
	draw_rect(Rect2(base.position + Vector2(1.5, 2), base.size), SHADOW)
	draw_rect(base, TRAP_WOOD)
	for x in [-4.5, 0.5, 4.5]:
		draw_line(center + Vector2(x, -11), center + Vector2(x, 11), TRAP_GRAIN, 1.0)
	draw_rect(base, TRAP_WOOD_EDGE, false, 1.5)
	# The hinge: a rod across the middle with a coiled spring at each end.
	draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), STEEL_EDGE, 2.0)
	for side in [-1, 1]:
		draw_circle(center + Vector2(5.5 * side, 0), 2.2, STEEL)
		draw_circle(center + Vector2(5.5 * side, 0), 2.2, STEEL_EDGE, false, 1.0, true)
	if snapped:
		return
	var pedal := Rect2(center + Vector2(-3.5, 4), Vector2(7, 6))
	draw_rect(pedal, CHEESE)
	draw_rect(pedal, CHEESE_HOLE, false, 1.0)
	draw_circle(center + Vector2(1, 7.5), 1.0, CHEESE_HOLE)
	_draw_steel(_offset(PackedVector2Array([Vector2(0, -10), Vector2(0, 5)]), center), 1.0)
	var bar := PackedVector2Array([Vector2(-5.5, 0), Vector2(-5.5, -10), Vector2(5.5, -10), Vector2(5.5, 0)])
	_draw_steel(_offset(bar, center), 1.5)


## Draws a shiny steel wire with a dark outline so it stands out on wood and fur.
func _draw_steel(points: PackedVector2Array, width: float) -> void:
	draw_polyline(points, STEEL_EDGE, width + 2.0, true)
	draw_polyline(points, STEEL, width, true)


func _offset(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + by)
	return result


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
