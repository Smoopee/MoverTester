class_name Board
extends Control
## The grid, the mouse, the cheese, the mouse traps, the crumbs and the cats, all drawn in code.

## The mouse picked up the crumb on this cell.
signal crumb_collected(cell: Vector2i)
## A cell was left-clicked. The F2 dev menu uses it to edit the board.
signal cell_clicked(cell: Vector2i)

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
const CAT_FUR := Color("e8913a")
const CAT_STRIPE := Color("b8621c")
const CAT_EYE := Color("8fd14f")
const CAT_PATH := Color(0.85, 0.25, 0.15, 0.2)
const CAT_PATH_LINE := Color(0.75, 0.2, 0.1, 0.75)
const CAT_STEP_TIME := 0.2
const KING_FUR := Color("5a5560")
const KING_STRIPE := Color("2f2c33")
const CROWN := Color("f5c542")
## How much bigger the Alley King is drawn than a cat.
const KING_SCALE := 1.3
const CHEESE_STEP_TIME := 0.2

## When false, moves finish instantly instead of tweening (used by the headless balance sim).
var animate := true
## Dev menu cheat: when true, traps and cats can't catch the mouse.
var invincible := false
var mouse_cell := Vector2i.ZERO
var cheese_cell := Vector2i.ZERO
## Cheese position in cell units; tweened between cells when RUNAWAY CHEESE moves it.
var cheese_pos := Vector2.ZERO:
	set(value):
		cheese_pos = value
		queue_redraw()
## Cells with a mouse trap. Moving onto one loses the round; jumping over one is safe.
var traps: Array[Vector2i] = []
## Cells with a crumb for the shop. Walking or sliding over one picks it up; jumping over one doesn't.
var crumbs: Array[Vector2i] = []
## Cats roaming the board. Moving onto a cat or its path loses the round; jumping over one is safe.
var cats: Array[Cat] = []
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
## True while the cats walk, so their old paths aren't drawn.
var _cats_walking := false


func _ready() -> void:
	custom_minimum_size = Vector2(GRID * CELL, GRID * CELL)


## With king set, the first cat is the Alley King, a bigger cat that hunts the mouse.
func place(mouse: Vector2i, cheese: Vector2i, trap_cells: Array[Vector2i] = [],
		crumb_cells: Array[Vector2i] = [], cat_cells: Array[Vector2i] = [], king := false) -> void:
	mouse_cell = mouse
	cheese_cell = cheese
	cheese_pos = Vector2(cheese)
	traps = trap_cells
	crumbs = crumb_cells
	cats.clear()
	for cell in cat_cells:
		cats.append(Cat.new(cell))
	if king and not cats.is_empty():
		cats[0].hunter = true
		cats[0].steps = Boss.KING_STEPS
	plan_cats()
	facing = Card.Dir.UP
	mouse_pos = Vector2(mouse)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var cell := Vector2i((click.position / CELL).floor())
		if _in_bounds(cell):
			cell_clicked.emit(cell)


func remove_trap(cell: Vector2i) -> void:
	traps.erase(cell)
	queue_redraw()


## Walks every cat along its path at once, then plans their next paths. Paths stay off the mouse's
## cell, so this never catches the mouse.
func move_cats() -> void:
	var routes: Array[Array] = []
	for cat in cats:
		var route: Array[Vector2i] = [cat.cell]
		route.append_array(cat.path)
		routes.append(route)
	_cats_walking = true
	var longest := 0
	for route in routes:
		longest = maxi(longest, route.size() - 1)
	var tween := create_tween()
	tween.tween_method(_walk_cats.bind(routes), 0.0, float(longest), CAT_STEP_TIME * maxi(longest, 1))
	if animate:
		await tween.finished
	else:
		tween.kill()
	_cats_walking = false
	for cat in cats:
		if cat.path:
			cat.cell = cat.path.back()
		cat.pos = Vector2(cat.cell)
	plan_cats()
	queue_redraw()


## Runs the cheese up to steps cells, each one farther from the mouse, never onto a trap, a crumb, a
## cat or a cat's path. A cornered cheese stays put.
func move_cheese(steps: int) -> void:
	var start := cheese_cell
	for i in steps:
		var best := cheese_cell
		for dir: Card.Dir in Card.Dir.values():
			var next: Vector2i = cheese_cell + Card.OFFSETS[dir]
			if not _in_bounds(next) or next == mouse_cell or next in crumbs or is_deadly(next):
				continue
			if _distance(next, mouse_cell) > _distance(best, mouse_cell):
				best = next
		if best == cheese_cell:
			break
		cheese_cell = best
	if cheese_cell == start:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "cheese_pos", Vector2(cheese_cell), CHEESE_STEP_TIME * _distance(start, cheese_cell))
	if animate:
		await tween.finished
	else:
		tween.kill()
		cheese_pos = Vector2(cheese_cell)


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


## Moves the mouse in a straight line until it hits a wall, a trap, a cat's path or the cheese.
func slide(dir: Card.Dir) -> bool:
	var offset: Vector2i = Card.OFFSETS[dir]
	if not _in_bounds(mouse_cell + offset):
		return await step(dir)
	facing = dir
	var passed: Array[Vector2i] = []
	while _in_bounds(mouse_cell + offset) and mouse_cell != cheese_cell and not is_caught():
		mouse_cell += offset
		passed.append(mouse_cell)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), SLIDE_CELL_TIME * passed.size() + STEP_TIME)
	return await _finish(tween, passed)


## Hops the mouse by offset, passing over the cells in between. Lands as far as the walls allow.
func jump(offset: Vector2i, dir: Card.Dir) -> bool:
	facing = dir
	mouse_cell = (mouse_cell + offset).clamp(Vector2i.ZERO, Vector2i(GRID - 1, GRID - 1))
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), JUMP_TIME)
	tween.tween_method(func(t: float) -> void: hop = sin(t * PI) * HOP_HEIGHT, 0.0, 1.0, JUMP_TIME)
	return await _finish(tween)


## True when the mouse is caught, in a trap or by a cat.
func is_caught() -> bool:
	return is_trapped() or caught_by_cat()


## True when the mouse is on a trap cell.
func is_trapped() -> bool:
	return mouse_cell in traps and not invincible


## True when the mouse is on a cat or its path.
func caught_by_cat() -> bool:
	return _cat_at(mouse_cell) != null and not invincible


## True when moving onto the cell would catch the mouse: a trap, a cat or a cat's path.
func is_deadly(cell: Vector2i) -> bool:
	return cell in traps or _cat_at(cell) != null


## Waits for a move's tween, or skips it when not animating, then picks up any crumbs on the cells
## passed and the cell landed on. Returns true if the round is over: the mouse is on the cheese or
## caught in a trap or by a cat, which then pounces on it.
func _finish(tween: Tween, passed: Array[Vector2i] = []) -> bool:
	if animate:
		await tween.finished
	else:
		tween.kill()
		mouse_pos = Vector2(mouse_cell)
		hop = 0.0
	passed.append(mouse_cell)
	for cell in passed:
		if cell in crumbs:
			crumbs.erase(cell)
			queue_redraw()
			crumb_collected.emit(cell)
	var cat := _cat_at(mouse_cell)
	if cat and not invincible:
		await _pounce(cat)
	return mouse_cell == cheese_cell or is_caught()


## Moves the cat onto the mouse.
func _pounce(cat: Cat) -> void:
	var offset := mouse_cell - cat.cell
	if offset != Vector2i.ZERO:
		var axis := Vector2i(signi(offset.x), 0) if absi(offset.x) > absi(offset.y) else Vector2i(0, signi(offset.y))
		cat.facing = Card.OFFSETS.find_key(axis) as Card.Dir
	cat.cell = mouse_cell
	cat.path.clear()
	var tween := create_tween()
	tween.tween_method(func(at: Vector2) -> void:
		cat.pos = at
		queue_redraw(), cat.pos, Vector2(mouse_cell), JUMP_TIME)
	if animate:
		await tween.finished
	else:
		tween.kill()
		cat.pos = Vector2(mouse_cell)


## Gives each cat a new path, off the walls, traps, cheese, mouse and other cats. Hunters head for
## the mouse.
func plan_cats() -> void:
	for cat in cats:
		cat.plan(func(cell: Vector2i) -> bool:
			return not _in_bounds(cell) or cell in traps or cell == cheese_cell or cell == mouse_cell \
				or cats.any(func(other: Cat) -> bool: return other != cat and other.cell == cell), mouse_cell)
	queue_redraw()


## Places each cat t steps along its route: its cell followed by its path.
func _walk_cats(t: float, routes: Array[Array]) -> void:
	for i in cats.size():
		var route: Array = routes[i]
		var step := mini(floori(t), route.size() - 1)
		var next := mini(step + 1, route.size() - 1)
		var from: Vector2i = route[step]
		var to: Vector2i = route[next]
		cats[i].pos = Vector2(from).lerp(Vector2(to), t - step if next > step else 0.0)
		if to != from:
			cats[i].facing = Card.OFFSETS.find_key(to - from) as Card.Dir
	queue_redraw()


## The cat whose cell or path is on the cell, if any.
func _cat_at(cell: Vector2i) -> Cat:
	for cat in cats:
		if cat.covers(cell):
			return cat
	return null


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GRID and cell.y < GRID


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _draw() -> void:
	for y in GRID:
		for x in GRID:
			var color := FLOOR_LIGHT if (x + y) % 2 == 0 else FLOOR_DARK
			draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), color)
	draw_rect(Rect2(0, 0, GRID * CELL, GRID * CELL), BORDER, false, 3.0)
	if not _cats_walking:
		for cat in cats:
			_draw_cat_path(cat)
	_draw_cheese(_cell_center(cheese_pos))
	for crumb in crumbs:
		_draw_crumb(_cell_center(Vector2(crumb)))
	# Once the mouse has landed on a trap, that trap has snapped shut.
	var snapped := is_trapped() and mouse_pos == Vector2(mouse_cell)
	for trap in traps:
		_draw_trap(_cell_center(Vector2(trap)), snapped and trap == mouse_cell)
	var center := _cell_center(mouse_pos)
	if hop > 0.0:
		draw_colored_polygon(_ellipse(center + Vector2(0, 6), Vector2(9, 4)), SHADOW)
	_draw_mouse(center - Vector2(0, hop))
	if snapped:
		var bar := PackedVector2Array([Vector2(-6, -1), Vector2(-6, 9), Vector2(6, 9), Vector2(6, -1)])
		_draw_steel(_offset(bar, center), 2.5)
	for cat in cats:
		_draw_cat(_cell_center(cat.pos), cat.facing, cat.hunter)


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


## Draws a few loose bits of cheese.
func _draw_crumb(center: Vector2) -> void:
	for bit: Array in [[Vector2(-4, 2), 3.2], [Vector2(3, -2), 2.6], [Vector2(2, 5), 2.0]]:
		draw_circle(center + bit[0], bit[1], CHEESE)
		draw_circle(center + bit[0], bit[1], CHEESE_HOLE, false, 1.0, true)


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


## Shades the cells a cat will walk this turn and draws an arrow along them.
func _draw_cat_path(cat: Cat) -> void:
	if cat.path.is_empty():
		return
	var line := PackedVector2Array([_cell_center(Vector2(cat.cell))])
	for cell in cat.path:
		draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), CAT_PATH)
		line.append(_cell_center(Vector2(cell)))
	# Stop the line short of the last cell's center so the arrowhead ends there.
	var tip := line[-1]
	var dir := (tip - line[-2]).normalized()
	line[-1] = tip - dir * 6.0
	draw_polyline(line, CAT_PATH_LINE, 2.0, true)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		tip, tip - dir * 8.0 + side * 5.0, tip - dir * 8.0 - side * 5.0,
	]), CAT_PATH_LINE)


## Draws a top-down orange tabby facing up, rotated to the way it's facing. The Alley King is a
## bigger, darker cat with a crown.
func _draw_cat(center: Vector2, cat_facing: Card.Dir, king := false) -> void:
	var fur := KING_FUR if king else CAT_FUR
	var stripe := KING_STRIPE if king else CAT_STRIPE
	draw_set_transform(center, Card.ANGLES[cat_facing], Vector2.ONE * (KING_SCALE if king else 1.0))
	draw_colored_polygon(_ellipse(Vector2(1.5, 5), Vector2(9, 11)), SHADOW)
	var tail := PackedVector2Array([Vector2(0, 11), Vector2(5, 14), Vector2(5, 18), Vector2(1, 21)])
	draw_polyline(tail, stripe, 4.0, true)
	var body := _ellipse(Vector2(0, 4), Vector2(8, 10))
	draw_colored_polygon(body, fur)
	body.append(body[0])
	draw_polyline(body, stripe, 1.0, true)
	for y in [1.0, 5.0, 9.0]:
		draw_line(Vector2(-3.5, y), Vector2(3.5, y), stripe, 2.0)
	for side in [-1, 1]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(2 * side, -13), Vector2(7.5 * side, -18), Vector2(7 * side, -9),
		]), stripe)
		draw_colored_polygon(PackedVector2Array([
			Vector2(4 * side, -13), Vector2(6.5 * side, -15.5), Vector2(6 * side, -11),
		]), PINK)
	draw_circle(Vector2(0, -8), 7.0, fur)
	draw_circle(Vector2(0, -8), 7.0, stripe, false, 1.0, true)
	draw_line(Vector2(0, -5), Vector2(0, -2), stripe, 1.5)
	for side in [-1, 1]:
		draw_circle(Vector2(2.8 * side, -10), 1.7, CAT_EYE)
		draw_circle(Vector2(2.8 * side, -10), 0.8, Color.BLACK)
	draw_circle(Vector2(0, -14), 1.3, PINK)
	if king:
		# On top of the head behind the eyes, points forward.
		var crown := PackedVector2Array([Vector2(-4.5, -1), Vector2(-4.5, -7.5), Vector2(-2.2, -4.5),
			Vector2(0, -8), Vector2(2.2, -4.5), Vector2(4.5, -7.5), Vector2(4.5, -1)])
		draw_colored_polygon(crown, CROWN)
		crown.append(crown[0])
		draw_polyline(crown, CHEESE_HOLE, 1.0, true)
	draw_set_transform(Vector2.ZERO)


func _ellipse(center: Vector2, radii: Vector2, points := 20) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points:
		var angle := TAU * i / points
		result.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return result
