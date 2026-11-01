class_name Board
extends Control
## The grid, the walls, doors and gates, the chasms, the floor tiles, the mouse, the cheese, the mouse traps, the
## crumbs, keys and crates, the shock pylons and flamethrowers, and the cats, all drawn in code.

## The mouse picked up the crumb on this cell.
signal crumb_collected(cell: Vector2i)
## The mouse opened the chest on this cell.
signal chest_opened(cell: Vector2i)
## The mouse picked up the key on this cell.
signal key_collected(cell: Vector2i)
## The mouse used a key on the locked door on this edge (a key into doors).
signal door_unlocked(edge: Vector3i)
## A cell was left-clicked, side being the edge of the cell nearest the click. The F2 dev menu uses
## it to edit the board.
signal cell_clicked(cell: Vector2i, side: Card.Dir)

## Cells along each side of the biggest board. Early rounds use a smaller one (see Difficulty.grid).
const MAX_GRID := 20
## Cell size the board is drawn in, before it's scaled to SIZE. Smaller boards are drawn zoomed in,
## up to MAX_ZOOM times the biggest board's cells.
const CELL := 30
## Width and height of the board area in pixels, whatever the grid size. It leaves room above the
## board for the title and boss rule, and below it for the status line.
const SIZE := 528.0
const MAX_ZOOM := 2.0
const STEP_TIME := 0.25
const SLIDE_CELL_TIME := 0.05
const JUMP_TIME := 0.4
const HOP_HEIGHT := 14.0
## Time a conveyor takes to carry the mouse a cell, and the mouse spends down a mouse hole.
const CONVEYOR_TIME := 0.18
const HOLE_TIME := 0.3

const FLOOR_LIGHT := Color("e9dcc0")
const FLOOR_DARK := Color("ded0b1")
const BORDER := Color("6b5638")
const WALL_WIDTH := 5.0
const GLUE := Color("dbe7ee")
const GLUE_EDGE := Color("86a1b2")
const BELT := Color("4f535a")
const BELT_EDGE := Color("2f3236")
const BELT_ARROW := Color("c8ced6")
const HOLE := Color("1e1712")
const HOLE_RIM := Color("8a6a45")
## Colors of the rings that show which mouse holes are linked, by pair.
const HOLE_PAIRS: Array[Color] = [Color("4fc3b0"), Color("c792ff"), Color("ff8fa3")]
const PLANK := Color("c69a63")
const PLANK_DARK := Color("8f6638")
const GAP := Color("2a211a")
## A chasm's pit, the cliff face under its rim, and the rocky rim along the floor.
const CHASM := Color("16110d")
const CHASM_CLIFF := Color("3d3026")
const CHASM_RIM := Color("8f7a5c")
const ROPE := Color("d8c39a")
## A shock pylon's and a flamethrower's metal, the pylon's coil and sparks, and the flame.
const MACHINE := Color("6f7782")
const MACHINE_EDGE := Color("2f343b")
const COIL := Color("c98a3d")
const SPARK := Color("4fc8f0")
const SPARK_CORE := Color("f4fdff")
const FLAME := Color("ff7a1f")
const FLAME_CORE := Color("ffd84a")
const FUEL_TANK := Color("b8402e")
## How a machine's blast cells are shaded: faintly while it counts down, strongly on the turn it goes
## off.
const BLAST_IDLE_ALPHA := 0.08
const BLAST_ARMED_ALPHA := 0.3
## A machine's countdown badge on the turn it goes off.
const ARMED := Color("e8412c")
const BLAST_TIME := 0.5
const DOOR := Color("a0522d")
const DOOR_EDGE := Color("5c2e14")
const DOOR_WIDTH := 7.0
const KEY := Color("f2c94c")
const KEY_EDGE := Color("8a6a12")
const CRATE := Color("c08a52")
const CRATE_EDGE := Color("6b4423")
const PAD := Color("f08c2e")
const PAD_EDGE := Color("9c4f0f")
## Colors of the switches, by index into plates: each plate and the gates it opens.
const SWITCH_COLORS: Array[Color] = [Color("d9483b"), Color("3a74d0"), Color("2e9457")]
## How faded an open gate is drawn.
const OPEN_GATE_ALPHA := 0.35
## Walls are drawn faded while the mouse is squeezing through them.
const SQUEEZE_ALPHA := 0.35
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
const CHEST_GOLD := Color("ffd23f")
## How much bigger the Alley King is drawn than a cat.
const KING_SCALE := 1.3
const CHEESE_STEP_TIME := 0.2
const PREVIEW_LINE := Color(0.2, 0.45, 0.85, 0.85)
const PREVIEW_CHEESE := Color("3fa34d")
const PREVIEW_CAUGHT := Color("d23c2c")
## Marks a jump in the trail where the mouse goes from one cell to another without crossing the cells
## between: out of a mouse hole, or in on the far side with WRAP.
const TRAIL_BREAK := Vector2i(-1, -1)

## How a previewed turn ends (see show_preview).
enum PreviewEnd { MOVED, CHEESE, CAUGHT, STUCK, RANDOM }

## When false, moves finish instantly instead of tweening (used by the headless balance sim).
var animate := true
## Dev menu cheat: when true, traps and cats can't catch the mouse.
var invincible := false
## Set while the run has CRUMB MAGNET: the mouse also picks up crumbs on the cells next to it
## (up, down, left, right, not through a wall) wherever a move ends.
var magnet := false
## Set while the run has the WARP skill: every step off an edge comes in on the opposite side, as
## step's wrap does for a WRAP slot.
var warp := false
## Cells along each side of the board this round. Set it before placing anything.
var grid := MAX_GRID:
	set(value):
		grid = value
		var zoom := minf(float(MAX_GRID) / grid, MAX_ZOOM) * SIZE / (MAX_GRID * CELL)
		var origin := Vector2.ONE * (SIZE - grid * CELL * zoom) / 2.0
		_view = Transform2D(0.0, Vector2.ONE * zoom, 0.0, origin)
		queue_redraw()
var mouse_cell := Vector2i.ZERO:
	set(value):
		mouse_cell = value
		if recording and (trail.is_empty() or trail[-1] != value):
			trail.append(value)
## While true, every cell the mouse moves to is added to trail, with TRAIL_BREAK before a hole or a
## wrap. Main's preview plays the turn on a copy of the board that records.
var recording := false
var trail: Array[Vector2i] = []
var cheese_cell := Vector2i.ZERO
## Cheese position in cell units; tweened between cells when RUNAWAY CHEESE moves it.
var cheese_pos := Vector2.ZERO:
	set(value):
		cheese_pos = value
		queue_redraw()
## Wall segments on cell edges inside the board: Vector3i(x, y, 0) is the wall on the right of cell
## (x, y), Vector3i(x, y, 1) the wall below it (see wall_between). Nothing moves through a wall, and
## jumps stop short of one, except while the mouse is squeezing.
var walls: Dictionary[Vector3i, bool] = {}
## Set by the SQUEEZE consumable for a turn: the mouse passes through walls. Cats and the cheese don't.
var squeeze := false:
	set(value):
		squeeze = value
		queue_redraw()
## Cells with a mouse trap. Moving onto one loses the round; jumping over one is safe.
var traps: Array[Vector2i] = []
## Glue pads. A move that ends on one, or a slide that reaches one, sticks the mouse there: it moves
## no more this turn (see stuck).
var glue: Array[Vector2i] = []
## Conveyor cells and the way each one runs. A move that ends on one carries the mouse a cell that
## way, and on along the belt if that's another conveyor.
var conveyors: Dictionary[Vector2i, Card.Dir] = {}
## Mouse holes in linked pairs: holes[0] with holes[1], holes[2] with holes[3], and so on. A move
## that ends on one pops the mouse out of the other.
var holes: Array[Vector2i] = []
## Creaky floorboards. Once the mouse walks, slides or jumps off one, it breaks into a gap in broken.
var floorboards: Array[Vector2i] = []
## Gaps where floorboards broke. Nothing can move onto one, though jumps can pass over it.
var broken: Array[Vector2i] = []
## Chasm cells, laid in runs a cell wide. Like a gap, nothing can move onto one, though jumps pass over
## it, so LEAP gets across.
var chasms: Array[Vector2i] = []
## Bridges across the chasms: cells in a chasm's run that can be walked on like plain floor.
var bridges: Array[Vector2i] = []
## Shock pylons and flamethrowers. Each counts down at the end of every turn and goes off at 0 (see
## fire_hazards). Nothing can move onto one's cell, though jumps pass over it.
var hazards: Array[Hazard] = []
## The pylon or flamethrower whose blast caught the mouse, if one did.
var blasted_by: Hazard = null
## Jump pads and the hop each one gives: a move that ends on one jumps the mouse by that offset, a
## straight line of 2 or more cells, over whatever is in between (see jump_landing).
var pads: Dictionary[Vector2i, Vector2i] = {}
## Locked doors on cell edges, keyed like walls. A door is a wall until the mouse walks or slides into
## it holding a key, which uses up the key and opens the door for the rest of the round.
var doors: Dictionary[Vector3i, bool] = {}
## Cells with a key. Walking or sliding over one picks it up, like a crumb.
var keys: Array[Vector2i] = []
## Keys the mouse is carrying this round.
var keys_held := 0
## Pressure plates. plates[i] opens the gates whose value in gates is i.
var plates: Array[Vector2i] = []
## Gates on cell edges, keyed like walls, and the plate in plates that opens each one. A gate is a wall
## except while a crate or the mouse is on its plate (see is_pressed).
var gates: Dictionary[Vector3i, int] = {}
## Crates. The mouse pushes one a cell by walking into it, onto plain floor or a plate (see
## _crate_can_enter). Slides stop short of a crate and jumps don't land on one.
var crates: Array[Vector2i] = []
## True once the mouse is stuck in glue this turn. Main clears it at the start of each turn.
var stuck := false
## Cells with a crumb for the shop. Walking or sliding over one picks it up; jumping over one doesn't.
var crumbs: Array[Vector2i] = []
## Cells with a chest (Main._open_chest), opened the same way as a crumb is picked up.
var chests: Array[Vector2i] = []
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
## The machines going off, and how far through their blast they are, 0 to 1 (see fire_hazards).
var _blasting: Array[Hazard] = []
var _blast := 0.0:
	set(value):
		_blast = value
		queue_redraw()
## True while the cats walk, so their old paths aren't drawn.
var _cats_walking := false
## The crate in crates being pushed, and how far it's drawn from its cell while it slides there.
var _pushed := -1
var _push_shift := Vector2.ZERO:
	set(value):
		_push_shift = value
		queue_redraw()
## The previewed way the mouse goes this turn, as a trail, and how it ends (see show_preview).
var _preview: Array[Vector2i] = []
var _preview_end := PreviewEnd.MOVED
## Maps the grid, drawn with CELL-sized cells, onto the board area: zoomed in and centered when the
## grid is small.
var _view := Transform2D.IDENTITY


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)


## With king set, the first cat is the Alley King, a bigger cat that hunts the mouse. The glue,
## conveyors, holes, floorboards, jump pads, doors, keys, switches, pylons and flamethrowers are set
## before this (Main._place_floor, Main._place_locks, Main._place_hazards) and left as they are.
func place(mouse: Vector2i, cheese: Vector2i, trap_cells: Array[Vector2i] = [],
		crumb_cells: Array[Vector2i] = [], cat_cells: Array[Vector2i] = [], king := false,
		wall_set: Dictionary[Vector3i, bool] = {}) -> void:
	mouse_cell = mouse
	cheese_cell = cheese
	cheese_pos = Vector2(cheese)
	traps = trap_cells
	walls = wall_set
	squeeze = false
	stuck = false
	keys_held = 0
	_pushed = -1
	blasted_by = null
	_blasting.clear()
	_blast = 0.0
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


## Makes this board a copy of other, cats included, for Main's preview to play a turn on.
func copy_from(other: Board) -> void:
	grid = other.grid
	mouse_cell = other.mouse_cell
	cheese_cell = other.cheese_cell
	walls = other.walls.duplicate()
	squeeze = other.squeeze
	traps = other.traps.duplicate()
	glue = other.glue.duplicate()
	conveyors = other.conveyors.duplicate()
	holes = other.holes.duplicate()
	floorboards = other.floorboards.duplicate()
	broken = other.broken.duplicate()
	chasms = other.chasms.duplicate()
	bridges = other.bridges.duplicate()
	pads = other.pads.duplicate()
	doors = other.doors.duplicate()
	keys = other.keys.duplicate()
	keys_held = other.keys_held
	plates = other.plates.duplicate()
	gates = other.gates.duplicate()
	crates = other.crates.duplicate()
	hazards.clear()
	for hazard in other.hazards:
		hazards.append(hazard.copy())
	blasted_by = other.blasted_by
	stuck = other.stuck
	crumbs = other.crumbs.duplicate()
	chests = other.chests.duplicate()
	magnet = other.magnet
	warp = other.warp
	invincible = other.invincible
	facing = other.facing
	cats.clear()
	for cat in other.cats:
		cats.append(cat.copy())


## Draws trail (from Board.trail) as the way the mouse goes this turn, ending in a mark for how it
## ends. An empty trail hides the preview.
func show_preview(trail_cells: Array[Vector2i], end: PreviewEnd) -> void:
	_preview = trail_cells
	_preview_end = end
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		var at := _view.affine_inverse() * click.position / CELL
		var cell := Vector2i(at.floor())
		if not _in_bounds(cell):
			return
		var inside := at - Vector2(cell)
		var gaps := {Card.Dir.UP: inside.y, Card.Dir.DOWN: 1.0 - inside.y, Card.Dir.LEFT: inside.x,
			Card.Dir.RIGHT: 1.0 - inside.x}
		var side: Card.Dir = Card.Dir.UP
		for dir: Card.Dir in gaps:
			if gaps[dir] < gaps[side]:
				side = dir
		cell_clicked.emit(cell, side)


func remove_trap(cell: Vector2i) -> void:
	traps.erase(cell)
	queue_redraw()


## True when the cell has a glue pad, a conveyor, a mouse hole, a floorboard, a gap, a jump pad, a
## chasm, a bridge, a shock pylon or a flamethrower.
func has_tile(cell: Vector2i) -> bool:
	return cell in glue or conveyors.has(cell) or cell in holes or cell in floorboards or cell in broken \
		or pads.has(cell) or cell in chasms or cell in bridges or hazard_at(cell) != null


## True when nothing can move onto the cell, though jumps pass over it: a gap, a chasm, a shock pylon
## or a flamethrower.
func is_blocked(cell: Vector2i) -> bool:
	return cell in broken or cell in chasms or hazard_at(cell) != null


## The shock pylon or flamethrower on the cell, if any.
func hazard_at(cell: Vector2i) -> Hazard:
	for hazard in hazards:
		if hazard.cell == cell:
			return hazard
	return null


## Takes the floor tiles, chasms, bridges, doors, gates, keys, plates, crates, pylons and flamethrowers
## off the board, for laying out a new round.
func clear_layout() -> void:
	glue = []
	conveyors = {}
	holes = []
	floorboards = []
	broken = []
	chasms = []
	bridges = []
	pads = {}
	doors = {}
	keys = []
	plates = []
	gates = {}
	crates = []
	hazards = []
	keys_held = 0


## True when the cell has a key, a pressure plate or a crate.
func has_item(cell: Vector2i) -> bool:
	return cell in keys or cell in plates or cell in crates


## Takes any glue pad, conveyor, mouse hole, floorboard, gap, jump pad, chasm, bridge, shock pylon or
## flamethrower off the cell. Used by the dev menu.
func clear_tile(cell: Vector2i) -> void:
	glue.erase(cell)
	conveyors.erase(cell)
	holes.erase(cell)
	floorboards.erase(cell)
	broken.erase(cell)
	pads.erase(cell)
	chasms.erase(cell)
	bridges.erase(cell)
	hazards.erase(hazard_at(cell))
	plan_cats()


## Takes the plate at index off the board, with the gates it opens. Later plates move down one, gates
## and all. Used by the dev menu.
func remove_plate(index: int) -> void:
	plates.remove_at(index)
	for edge: Vector3i in gates.keys():
		if gates[edge] == index:
			gates.erase(edge)
		elif gates[edge] > index:
			gates[edge] -= 1
	plan_cats()


## True when a crate or the mouse is on the plate at index in plates, which holds its gates open.
func is_pressed(plate: int) -> bool:
	return plate < plates.size() and (plates[plate] in crates or plates[plate] == mouse_cell)


## The wall on the edge between two neighboring cells, as a key into walls.
static func wall_between(a: Vector2i, b: Vector2i) -> Vector3i:
	return Vector3i(mini(a.x, b.x), mini(a.y, b.y), 0 if a.y == b.y else 1)


## True when a wall stands between the two neighboring cells.
func has_wall(a: Vector2i, b: Vector2i) -> bool:
	return walls.has(wall_between(a, b))


## True when a wall, a locked door or a closed gate stands between the two neighboring cells.
func is_barrier(a: Vector2i, b: Vector2i) -> bool:
	var edge := wall_between(a, b)
	return walls.has(edge) or doors.has(edge) or gates.has(edge) and not is_pressed(gates[edge])


## Takes any wall, locked door or gate off the edge between the neighboring cells. Used by the dev menu.
func clear_edge(a: Vector2i, b: Vector2i) -> void:
	var edge := wall_between(a, b)
	walls.erase(edge)
	doors.erase(edge)
	gates.erase(edge)
	plan_cats()


## Where the mouse lands stepping from cell in dir: the next cell, or cell itself when the edge, a wall
## or a crate that can't be pushed is in the way. A locked door is no bar with a key in hand.
func step_target(cell: Vector2i, dir: Card.Dir) -> Vector2i:
	var next: Vector2i = cell + Card.OFFSETS[dir]
	if next in crates:
		return next if _mouse_can_reach(cell, next) and _crate_can_enter(next, next + Card.OFFSETS[dir]) else cell
	return next if _mouse_can_step(cell, next, true) else cell


## Steps from start to each cell it can reach, going around walls (or through them, with
## through_walls) and traps. Cells it can't reach are left out.
func distances_from(start: Vector2i, through_walls := false) -> Dictionary[Vector2i, int]:
	var distances: Dictionary[Vector2i, int] = {start: 0}
	var queue: Array[Vector2i] = [start]
	var i := 0
	while i < queue.size():
		var cell := queue[i]
		i += 1
		for offset: Vector2i in Card.OFFSETS.values():
			var next := cell + offset
			if not distances.has(next) and _can_step(cell, next, through_walls) and next not in traps:
				distances[next] = distances[cell] + 1
				queue.append(next)
	return distances


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


## Counts every shock pylon and flamethrower down a turn. Those that reach 0 go off, catching the mouse
## if it's in the blast (see blast_cells), then start their countdown over. Returns true if the mouse
## was caught, and then that blast stays drawn over it.
func fire_hazards() -> bool:
	_blasting.clear()
	for hazard in hazards:
		hazard.timer -= 1
		if hazard.timer <= 0:
			_blasting.append(hazard)
	if _blasting.is_empty():
		queue_redraw()
		return false
	for hazard in _blasting:
		if blasted_by == null and not invincible and mouse_cell in blast_cells(hazard):
			blasted_by = hazard
	var tween := create_tween()
	tween.tween_property(self, "_blast", 1.0, BLAST_TIME).from(0.0)
	if animate:
		await tween.finished
	else:
		tween.kill()
	for hazard in _blasting:
		hazard.timer = hazard.period
	if blasted_by:
		# Held at its brightest.
		_blasting.assign([blasted_by])
		_blast = 0.5
	else:
		_blasting.clear()
		_blast = 0.0
	return blasted_by != null


## The cells a machine's blast reaches: the eight around a shock pylon, walls or not, or a
## flamethrower's jet of up to Hazard.FLAME_REACH cells the way it points, stopped by the board's edge,
## a wall, a locked door, a closed gate, a crate or another machine. The jet passes over gaps and
## chasms.
func blast_cells(hazard: Hazard) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if hazard.kind == Hazard.Kind.PYLON:
		for y in range(-1, 2):
			for x in range(-1, 2):
				var cell := hazard.cell + Vector2i(x, y)
				if cell != hazard.cell and _in_bounds(cell):
					cells.append(cell)
		return cells
	var at := hazard.cell
	for i in Hazard.FLAME_REACH:
		var next: Vector2i = at + Card.OFFSETS[hazard.dir]
		if not _can_cross(at, next) or next in crates or hazard_at(next) != null:
			break
		cells.append(next)
		at = next
	return cells


## True when a machine that goes off at the end of this turn would catch a mouse on the cell.
func in_blast(cell: Vector2i) -> bool:
	return hazards.any(func(hazard: Hazard) -> bool: return hazard.is_armed() and cell in blast_cells(hazard))


## Runs the cheese up to steps cells, each one farther from the mouse, never onto a trap, a crumb, a
## chest, a key, a crate, a cat or a cat's path. A cornered cheese stays put.
func move_cheese(steps: int) -> void:
	var start := cheese_cell
	for i in steps:
		var best := cheese_cell
		for dir: Card.Dir in Card.Dir.values():
			var next: Vector2i = cheese_cell + Card.OFFSETS[dir]
			if not _can_step(cheese_cell, next) or next == mouse_cell or next in crumbs or next in chests \
					or next in keys or next in crates or is_deadly(next):
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


## Moves the mouse one cell (bumping off walls and the edge, or coming in on the opposite side of
## an edge if wrap or warp is set), pushing a crate there on a cell and opening a locked door with a
## key. Returns true if the move ends the round (see _finish).
func step(dir: Card.Dir, wrap := false) -> bool:
	facing = dir
	var start := mouse_cell
	var offset: Vector2i = Card.OFFSETS[dir]
	var target := mouse_cell + offset
	var wrapped := Vector2i(posmod(target.x, grid), posmod(target.y, grid))
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	var crate := crates.find(target)
	if crate != -1 and _mouse_can_reach(mouse_cell, target) and _crate_can_enter(target, target + offset):
		crates[crate] = target + offset
		_pushed = crate
		_push_shift = -Vector2(offset)
		BugReport.note("  Pushed the crate at %s to %s" % [target, crates[crate]])
	if _mouse_can_step(mouse_cell, target, true):
		_unlock(mouse_cell, target)
		mouse_cell = target
		tween.tween_property(self, "mouse_pos", Vector2(target), STEP_TIME)
		if _pushed != -1:
			tween.parallel().tween_property(self, "_push_shift", Vector2.ZERO, STEP_TIME)
	elif (wrap or warp) and not _in_bounds(target) and not is_blocked(wrapped) and wrapped not in crates:
		target = wrapped
		_trail_break()
		mouse_cell = target
		tween.tween_property(self, "mouse_pos", mouse_pos + Vector2(offset) * 0.5, STEP_TIME / 2)
		tween.tween_callback(func() -> void: mouse_pos = Vector2(target) - Vector2(offset) * 0.5)
		tween.tween_property(self, "mouse_pos", Vector2(target), STEP_TIME / 2)
	else:
		var bump := Vector2(mouse_cell) + Vector2(offset) * 0.25
		tween.tween_property(self, "mouse_pos", bump, STEP_TIME / 2)
		tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), STEP_TIME / 2)
	return await _finish(tween, start)


## Moves the mouse in a straight line until it hits a wall, a gap, a crate, a trap, a cat's path, glue
## or the cheese. With a key in hand it opens a locked door on the way. Sliding into a crate right next
## to the mouse pushes it a cell, like a step.
func slide(dir: Card.Dir) -> bool:
	var offset: Vector2i = Card.OFFSETS[dir]
	if not _mouse_can_step(mouse_cell, mouse_cell + offset, true):
		return await step(dir)
	facing = dir
	var start := mouse_cell
	var passed: Array[Vector2i] = []
	while _mouse_can_step(mouse_cell, mouse_cell + offset, true) and mouse_cell != cheese_cell and not is_caught() \
			and (passed.is_empty() or mouse_cell not in glue):
		_unlock(mouse_cell, mouse_cell + offset)
		mouse_cell += offset
		passed.append(mouse_cell)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), SLIDE_CELL_TIME * passed.size() + STEP_TIME)
	return await _finish(tween, start, passed)


## Hops the mouse by offset, passing over the cells in between. Lands as far as the edge and the walls
## allow (see jump_landing).
func jump(offset: Vector2i, dir: Card.Dir) -> bool:
	facing = dir
	var start := mouse_cell
	mouse_cell = jump_landing(mouse_cell, offset)
	return await _finish(_hop_tween(), start)


## Tweens the mouse to its cell in a hop.
func _hop_tween() -> Tween:
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), JUMP_TIME)
	tween.tween_method(func(t: float) -> void: hop = sin(t * PI) * HOP_HEIGHT, 0.0, 1.0, JUMP_TIME)
	return tween


## Where a jump by offset from a cell lands. A straight jump stops at the first wall, locked door or
## closed gate, and short of a gap, a chasm or a crate it would land on, though it can pass over them. A diagonal
## one (a cell each way) gets around the corner if either way around it is clear of walls, and
## otherwise goes as far as it can along one axis.
func jump_landing(from: Vector2i, offset: Vector2i) -> Vector2i:
	var target := (from + offset).clamp(Vector2i.ZERO, Vector2i(grid - 1, grid - 1))
	var x_step := Vector2i(signi(target.x - from.x), 0)
	var y_step := Vector2i(0, signi(target.y - from.y))
	if x_step != Vector2i.ZERO and y_step != Vector2i.ZERO:
		if not is_blocked(target) and target not in crates:
			for first: Vector2i in [x_step, y_step]:
				var corner := from + first
				if _can_cross(from, corner, squeeze) and _can_cross(corner, target, squeeze):
					return target
		for first: Vector2i in [x_step, y_step]:
			if _mouse_can_step(from, from + first):
				return from + first
		return from
	var step := x_step + y_step
	var at := from
	while at != target and _can_cross(at, at + step, squeeze):
		at += step
	while at != from and (is_blocked(at) or at in crates):
		at -= step
	return at


## True when the mouse is caught, in a trap, by a cat, or in a pylon's or flamethrower's blast.
func is_caught() -> bool:
	return is_trapped() or caught_by_cat() or is_blasted()


## True when a shock pylon or a flamethrower caught the mouse.
func is_blasted() -> bool:
	return blasted_by != null


## True when the mouse is on a trap cell.
func is_trapped() -> bool:
	return mouse_cell in traps and not invincible


## True when the mouse is on a cat or its path.
func caught_by_cat() -> bool:
	return _cat_at(mouse_cell) != null and not invincible


## True when moving onto the cell would catch the mouse: a trap, a cat or a cat's path.
func is_deadly(cell: Vector2i) -> bool:
	return cell in traps or _cat_at(cell) != null


## Ends a move that started on start: waits for its tween, breaks the floorboards it left, picks up
## crumbs on the cells passed and the cell landed on, then lets holes and conveyors carry the mouse on
## (see _ride). Returns true if the round is over: the mouse is on the cheese or caught in a trap or
## by a cat, which then pounces on it.
func _finish(tween: Tween, start: Vector2i, passed: Array[Vector2i] = []) -> bool:
	await _settle(tween)
	passed.append(mouse_cell)
	for cell: Vector2i in [start] + passed:
		if cell != mouse_cell and cell in floorboards:
			floorboards.erase(cell)
			broken.append(cell)
			BugReport.note("  Floorboard at %s broke" % cell)
	if await _arrive(passed):
		return true
	return await _ride()


## Waits for a tween, or skips to its end when not animating.
func _settle(tween: Tween) -> void:
	if animate:
		await tween.finished
	else:
		tween.kill()
		mouse_pos = Vector2(mouse_cell)
		hop = 0.0
		_push_shift = Vector2.ZERO
	_pushed = -1


## Picks up any crumbs, keys and chests on the cells (and, with the magnet, crumbs next to the mouse),
## and lets a cat on the mouse's cell pounce. Returns true if the round is over.
func _arrive(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if cell in keys:
			keys.erase(cell)
			keys_held += 1
			queue_redraw()
			key_collected.emit(cell)
		if cell in crumbs:
			crumbs.erase(cell)
			queue_redraw()
			crumb_collected.emit(cell)
		if cell in chests:
			chests.erase(cell)
			queue_redraw()
			chest_opened.emit(cell)
	if magnet:
		for offset: Vector2i in Card.OFFSETS.values():
			var cell := mouse_cell + offset
			if cell in crumbs and _mouse_can_step(mouse_cell, cell):
				crumbs.erase(cell)
				queue_redraw()
				BugReport.note("  CRUMB MAGNET pulled in the crumb at %s" % cell)
				crumb_collected.emit(cell)
	var cat := _cat_at(mouse_cell)
	if cat and not invincible:
		await _pounce(cat)
	return mouse_cell == cheese_cell or is_caught()


## Carries the mouse on from where a move ended: out of the linked hole when it's on a mouse hole,
## a cell along the belt when it's on a conveyor, a hop away when it's on a jump pad, until it rests on
## another cell. Then glue there sticks it for the rest of the turn. Returns true if the round is over.
func _ride() -> bool:
	var popped_out := false
	# A loop of conveyors would carry the mouse round forever.
	for i in grid * grid:
		var exit := _hole_exit(mouse_cell)
		var tween: Tween
		if exit != mouse_cell and not popped_out:
			BugReport.note("  Down the mouse hole at %s, out at %s" % [mouse_cell, exit])
			_trail_break()
			mouse_cell = exit
			popped_out = true
			tween = create_tween()
			tween.tween_interval(HOLE_TIME)
			tween.tween_callback(func() -> void: mouse_pos = Vector2(exit))
		elif conveyors.has(mouse_cell) and _mouse_can_step(mouse_cell, mouse_cell + Card.OFFSETS[conveyors[mouse_cell]]):
			mouse_cell += Card.OFFSETS[conveyors[mouse_cell]]
			popped_out = false
			tween = create_tween()
			tween.tween_property(self, "mouse_pos", Vector2(mouse_cell), CONVEYOR_TIME)
		elif pads.has(mouse_cell) and jump_landing(mouse_cell, pads[mouse_cell]) != mouse_cell:
			var pad := mouse_cell
			facing = Card.OFFSETS.find_key(pads[pad].sign()) as Card.Dir
			mouse_cell = jump_landing(pad, pads[pad])
			BugReport.note("  Jump pad at %s threw the mouse to %s" % [pad, mouse_cell])
			popped_out = false
			tween = _hop_tween()
		else:
			break
		await _settle(tween)
		if await _arrive([mouse_cell]):
			return true
	stuck = mouse_cell in glue
	if stuck:
		BugReport.note("  Stuck in glue at %s" % mouse_cell)
	return false


func _trail_break() -> void:
	if recording:
		trail.append(TRAIL_BREAK)


## The other end of the mouse hole on the cell, or the cell itself when it isn't a linked hole.
func _hole_exit(cell: Vector2i) -> Vector2i:
	var index := holes.find(cell)
	if index == -1 or (index ^ 1) >= holes.size():
		return cell
	return holes[index ^ 1]


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


## Gives each cat a new path, on the board, off the traps, crates, cheese, mouse and other cats and not
## through walls, doors or gates (even open ones, which can shut before the cat walks). Hunters head
## for the mouse, around the walls and traps.
func plan_cats() -> void:
	var to_mouse := distances_from(mouse_cell)
	var distance := func(cell: Vector2i) -> int: return to_mouse.get(cell, grid * grid)
	for cat in cats:
		cat.plan(func(from: Vector2i, cell: Vector2i) -> bool:
			return not _can_step(from, cell) or gates.has(wall_between(from, cell)) or cell in traps \
				or cell in crates or cell == cheese_cell or cell == mouse_cell \
				or cats.any(func(other: Cat) -> bool: return other != cat and other.cell == cell), distance)
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
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid and cell.y < grid


## True when something can move from a cell onto its neighbor: it's on the board, not a gap or a
## chasm, and no wall, locked door or closed gate is in the way unless through_walls.
func _can_step(from: Vector2i, to: Vector2i, through_walls := false) -> bool:
	return _can_cross(from, to, through_walls) and not is_blocked(to)


## Like _can_step, but a gap or a chasm is fine: for jumps passing over the cell.
func _can_cross(from: Vector2i, to: Vector2i, through_walls := false) -> bool:
	return _in_bounds(to) and (through_walls or not is_barrier(from, to))


## True when the mouse can move from a cell onto its neighbor: not onto a crate, and through walls only
## while squeezing. With keyed, a locked door is no bar while the mouse holds a key (see _unlock).
func _mouse_can_step(from: Vector2i, to: Vector2i, keyed := false) -> bool:
	return to not in crates and _mouse_can_reach(from, to, keyed)


## Like _mouse_can_step, keyed, but a crate on the cell is fine: for pushing it.
func _mouse_can_reach(from: Vector2i, to: Vector2i, keyed := true) -> bool:
	return _can_step(from, to, squeeze) or keyed and keys_held > 0 and not is_blocked(to) and _in_bounds(to) \
		and doors.has(wall_between(from, to))


## True when a crate can be pushed from a cell onto its neighbor: plain floor or a plate, with no wall,
## door or closed gate in the way, and no trap, crumb, chest, key, other crate, cheese, floor tile or
## cat (or cat's path) on it.
func _crate_can_enter(from: Vector2i, to: Vector2i) -> bool:
	return _can_step(from, to) and not has_tile(to) and to not in traps and to not in crumbs \
		and to not in chests and to not in keys and to not in crates and to != cheese_cell and _cat_at(to) == null


## Uses up one of the mouse's keys on the locked door between the cells, if there is one, opening it
## for the rest of the round. A squeezing mouse goes through without one.
func _unlock(from: Vector2i, to: Vector2i) -> void:
	var edge := wall_between(from, to)
	if squeeze or not doors.has(edge):
		return
	doors.erase(edge)
	keys_held -= 1
	BugReport.note("  Unlocked the door between %s and %s (%d keys left)" % [from, to, keys_held])
	queue_redraw()
	door_unlocked.emit(edge)


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _draw() -> void:
	draw_set_transform_matrix(_view)
	for y in grid:
		for x in grid:
			var color := FLOOR_LIGHT if (x + y) % 2 == 0 else FLOOR_DARK
			draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), color)
	draw_rect(Rect2(0, 0, grid * CELL, grid * CELL), BORDER, false, 3.0)
	_draw_floor()
	if not _cats_walking:
		for cat in cats:
			_draw_cat_path(cat)
	for hazard in hazards:
		_draw_blast_zone(hazard)
	_draw_walls()
	_draw_locks()
	_draw_cheese(_cell_center(cheese_pos))
	for crumb in crumbs:
		_draw_crumb(_cell_center(Vector2(crumb)))
	for key in keys:
		_draw_key(_cell_center(Vector2(key)))
	for chest in chests:
		_draw_chest(_cell_center(Vector2(chest)))
	# Once the mouse has landed on a trap, that trap has snapped shut.
	var snapped := is_trapped() and mouse_pos == Vector2(mouse_cell)
	for trap in traps:
		_draw_trap(_cell_center(Vector2(trap)), snapped and trap == mouse_cell)
	for i in crates.size():
		_draw_crate(_cell_center(Vector2(crates[i]) + (_push_shift if i == _pushed else Vector2.ZERO)))
	for hazard in hazards:
		if hazard.kind == Hazard.Kind.PYLON:
			_draw_pylon(hazard)
		else:
			_draw_flamer(hazard)
	_draw_preview_trail()
	var center := _cell_center(mouse_pos)
	if hop > 0.0:
		draw_colored_polygon(_ellipse(center + Vector2(0, 6), Vector2(9, 4)), SHADOW)
	_draw_mouse(center - Vector2(0, hop))
	if snapped:
		var bar := PackedVector2Array([Vector2(-6, -1), Vector2(-6, 9), Vector2(6, 9), Vector2(6, -1)])
		_draw_steel(_offset(bar, center), 2.5)
	for cat in cats:
		_draw_cat(_cell_center(cat.pos), cat.facing, cat.hunter)
	for hazard in _blasting:
		_draw_blast(hazard)
	_draw_preview_end()


func _cell_center(cell: Vector2) -> Vector2:
	return (cell + Vector2(0.5, 0.5)) * CELL


## Draws the cells that change how the mouse moves: chasms and their bridges, floorboards and the gaps
## they leave, conveyors, mouse holes, glue, jump pads and pressure plates.
func _draw_floor() -> void:
	_draw_chasms()
	for i in plates.size():
		# A little bigger than a crate, so a pressed plate shows round the crate on it.
		var plate := Rect2(Vector2(plates[i]) * CELL, Vector2(CELL, CELL)).grow(-3)
		var color := SWITCH_COLORS[i % SWITCH_COLORS.size()]
		# A raised plate, or pushed flat and darker while something is on it.
		if is_pressed(i):
			draw_rect(plate, color.darkened(0.35))
		else:
			draw_rect(Rect2(plate.position + Vector2(1.5, 2), plate.size), SHADOW)
			draw_rect(plate, color.lightened(0.35))
			draw_rect(plate.grow(-4), color.lightened(0.15))
		draw_rect(plate, color.darkened(0.4), false, 1.5)
	for cell: Vector2i in pads:
		# A round pad with an arrowhead on its rim pointing the way it throws, and the cells it throws in
		# the middle.
		var center := _cell_center(Vector2(cell))
		var offset: Vector2i = pads[cell]
		draw_set_transform_matrix(_view * Transform2D(Card.ANGLES[Card.OFFSETS.find_key(offset.sign())], center))
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -8), Vector2(0, -14.5), Vector2(7, -8)]), PAD_EDGE)
		draw_set_transform_matrix(_view)
		draw_circle(center, 10.5, PAD_EDGE)
		draw_circle(center, 9.0, PAD)
		var font := ThemeDB.fallback_font
		var text := str(absi(offset.x + offset.y))
		var at := center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x / 2.0, 5)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for cell in floorboards:
		var plank := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)).grow(-2)
		draw_rect(plank, PLANK)
		draw_line(plank.get_center() - Vector2(0, plank.size.y / 2), plank.get_center() + Vector2(0, plank.size.y / 2),
			PLANK_DARK, 1.5)
		draw_rect(plank, PLANK_DARK, false, 1.5)
		for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_circle(plank.get_center() + (plank.size / 2 - Vector2(4, 4)) * corner, 1.2, PLANK_DARK)
		# A crack, so it reads as creaky.
		var crack := PackedVector2Array([Vector2(-8, -3), Vector2(-4, 1), Vector2(-6, 4), Vector2(-2, 8)])
		draw_polyline(_offset(crack, plank.get_center()), PLANK_DARK, 1.0, true)
	for cell in broken:
		var gap := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)).grow(-2)
		draw_rect(gap, GAP)
		# Splintered ends of the planks along the top and bottom.
		var top := gap.position
		draw_colored_polygon(PackedVector2Array([top, top + Vector2(gap.size.x, 0), top + Vector2(gap.size.x, 4),
			top + Vector2(gap.size.x * 0.7, 7), top + Vector2(gap.size.x * 0.45, 3), top + Vector2(gap.size.x * 0.2, 6),
			top + Vector2(0, 3)]), PLANK)
		var bottom := gap.end
		draw_colored_polygon(PackedVector2Array([bottom, bottom - Vector2(gap.size.x, 0),
			bottom - Vector2(gap.size.x, 5), bottom - Vector2(gap.size.x * 0.6, 2), bottom - Vector2(gap.size.x * 0.3, 6),
			bottom - Vector2(0, 3)]), PLANK)
	for cell: Vector2i in conveyors:
		var belt := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)).grow(-1)
		draw_rect(belt, BELT)
		draw_rect(belt, BELT_EDGE, false, 1.5)
		draw_set_transform_matrix(_view * Transform2D(Card.ANGLES[conveyors[cell]], _cell_center(Vector2(cell))))
		for y in [-5.0, 3.0]:
			draw_polyline(PackedVector2Array([Vector2(-6, y + 5), Vector2(0, y - 1), Vector2(6, y + 5)]),
				BELT_ARROW, 2.5, true)
		draw_set_transform_matrix(_view)
	for i in holes.size():
		var center := _cell_center(Vector2(holes[i]))
		draw_colored_polygon(_ellipse(center, Vector2(11, 9)), HOLE_RIM)
		draw_colored_polygon(_ellipse(center + Vector2(0, 1), Vector2(8, 6.5)), HOLE)
		if i ^ 1 < holes.size():
			var ring := _ellipse(center, Vector2(12, 10))
			ring.append(ring[0])
			draw_polyline(ring, HOLE_PAIRS[(i >> 1) % HOLE_PAIRS.size()], 2.0, true)
	for cell in glue:
		var center := _cell_center(Vector2(cell))
		for blob: Array in [[Vector2(-3, 1), Vector2(10, 8)], [Vector2(5, -3), Vector2(7, 6)], [Vector2(3, 6), Vector2(6, 4)]]:
			var shape := _ellipse(center + blob[0], blob[1])
			draw_colored_polygon(shape, GLUE)
			shape.append(shape[0])
			draw_polyline(shape, GLUE_EDGE, 1.0, true)
		# Fill over the outlines where the blobs overlap, so it reads as one puddle.
		for blob: Array in [[Vector2(-3, 1), Vector2(9, 7)], [Vector2(5, -3), Vector2(6, 5)], [Vector2(3, 6), Vector2(5, 3)]]:
			draw_colored_polygon(_ellipse(center + blob[0], blob[1]), GLUE)
		draw_circle(center + Vector2(-6, -2), 2.0, Color(1, 1, 1, 0.9))
		draw_circle(center + Vector2(6, -5), 1.2, Color(1, 1, 1, 0.9))


## Draws the chasms as one dark pit, with a rocky rim and a cliff face along each side that meets the
## floor, then the bridges over it: planks across the pit between two ropes.
func _draw_chasms() -> void:
	var pit := chasms + bridges
	for cell in pit:
		draw_rect(Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL)), CHASM)
	var half := CELL / 2.0
	var cliff := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, -8),
		Vector2(8, -10), Vector2(3, -7.5), Vector2(-3, -9.5), Vector2(-9, -7), Vector2(-half, -9)])
	var rim := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, -12),
		Vector2(9, -13), Vector2(4, -11), Vector2(-2, -13), Vector2(-8, -11.5), Vector2(-half, -12.5)])
	for cell in pit:
		for dir: Card.Dir in Card.Dir.values():
			var next: Vector2i = cell + Card.OFFSETS[dir]
			if next in pit or not _in_bounds(next):
				continue
			draw_set_transform_matrix(_view * Transform2D(Card.ANGLES[dir], _cell_center(Vector2(cell))))
			draw_colored_polygon(cliff, CHASM_CLIFF)
			draw_colored_polygon(rim, CHASM_RIM)
	for cell in bridges:
		# Drawn crossing up and down, and turned when the chasm runs up and down instead.
		var turned := cell + Vector2i.UP in pit or cell + Vector2i.DOWN in pit
		draw_set_transform_matrix(_view * Transform2D(PI / 2 if turned else 0.0, _cell_center(Vector2(cell))))
		# Planks with the pit showing between them.
		for y: float in [-11.0, -3.7, 3.7, 11.0]:
			var plank := Rect2(-11, y - 2.6, 22, 5.2)
			draw_rect(plank, PLANK)
			draw_rect(plank, PLANK_DARK, false, 1.0)
		for x: float in [-12.5, 12.5]:
			draw_line(Vector2(x, -half), Vector2(x, half), PLANK_DARK, 3.5)
			draw_line(Vector2(x, -half), Vector2(x, half), ROPE, 2.0)
			for y: float in [-half + 1.5, half - 1.5]:
				draw_circle(Vector2(x, y), 2.8, PLANK_DARK)
	draw_set_transform_matrix(_view)


## Draws the previewed trail as a dashed line through the cells, with a small ring on each side of a
## break (a mouse hole or a wrap).
func _draw_preview_trail() -> void:
	for i in range(1, _preview.size()):
		var from := _preview[i - 1]
		var to := _preview[i]
		if to == TRAIL_BREAK:
			draw_arc(_cell_center(Vector2(from)), 6.0, 0.0, TAU, 16, PREVIEW_LINE, 2.0, true)
		elif from == TRAIL_BREAK:
			draw_arc(_cell_center(Vector2(to)), 6.0, 0.0, TAU, 16, PREVIEW_LINE, 2.0, true)
		else:
			draw_dashed_line(_cell_center(Vector2(from)), _cell_center(Vector2(to)), PREVIEW_LINE, 3.0, 5.0, true, true)


## Marks where the previewed turn ends: a ring where the mouse stops (green on the cheese, pale blue in
## glue), a red cross where it's caught, or a question mark before a GAMBLE slot's random move.
func _draw_preview_end() -> void:
	if _preview.is_empty():
		return
	var center := _cell_center(Vector2(_preview[-1]))
	match _preview_end:
		PreviewEnd.MOVED:
			draw_arc(center, 11.0, 0.0, TAU, 24, PREVIEW_LINE, 2.5, true)
		PreviewEnd.CHEESE:
			draw_arc(center, 14.0, 0.0, TAU, 24, PREVIEW_CHEESE, 3.5, true)
		PreviewEnd.STUCK:
			draw_arc(center, 12.0, 0.0, TAU, 24, GLUE_EDGE, 3.0, true)
		PreviewEnd.CAUGHT:
			for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
				draw_line(center - corner * 9.0, center + corner * 9.0, STEEL_EDGE, 6.0)
				draw_line(center - corner * 9.0, center + corner * 9.0, PREVIEW_CAUGHT, 3.5)
		PreviewEnd.RANDOM:
			var font := ThemeDB.fallback_font
			var at := center + Vector2(-6, -8)
			draw_string_outline(font, at, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.WHITE)
			draw_string(font, at, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PREVIEW_LINE)


## Draws each wall as a thick line along its cell edge, with a shadow and round ends so runs of walls
## join up. Faded while the mouse is squeezing.
func _draw_walls() -> void:
	var alpha := SQUEEZE_ALPHA if squeeze else 1.0
	for layer: Array in [[Vector2(1.5, 2), Color(SHADOW, SHADOW.a * alpha)], [Vector2.ZERO, Color(BORDER, alpha)]]:
		var shift: Vector2 = layer[0]
		var color: Color = layer[1]
		for wall: Vector3i in walls:
			var ends := _edge_ends(wall)
			draw_line(ends[0] + shift, ends[1] + shift, color, WALL_WIDTH)
			draw_circle(ends[0] + shift, WALL_WIDTH / 2.0, color)
			draw_circle(ends[1] + shift, WALL_WIDTH / 2.0, color)


## The two ends of a cell edge (a key into walls, doors or gates), in board pixels.
func _edge_ends(edge: Vector3i) -> PackedVector2Array:
	var end := Vector2(edge.x + 1, edge.y + 1) * CELL
	var start := Vector2(end.x, edge.y * CELL) if edge.z == 0 else Vector2(edge.x * CELL, end.y)
	return PackedVector2Array([start, end])


## Draws the locked doors, as a wooden plank along the edge with a gold keyhole, and the gates, as bars
## in their plate's color: solid while shut, faded while open. Faded too while the mouse is squeezing.
func _draw_locks() -> void:
	var alpha := SQUEEZE_ALPHA if squeeze else 1.0
	for door: Vector3i in doors:
		var ends := _edge_ends(door)
		draw_line(ends[0] + Vector2(1.5, 2), ends[1] + Vector2(1.5, 2), Color(SHADOW, SHADOW.a * alpha), DOOR_WIDTH)
		draw_line(ends[0], ends[1], Color(DOOR_EDGE, alpha), DOOR_WIDTH + 2.0)
		draw_line(ends[0], ends[1], Color(DOOR, alpha), DOOR_WIDTH)
		var middle := (ends[0] + ends[1]) / 2.0
		draw_circle(middle, 4.0, Color(KEY, alpha))
		draw_circle(middle, 4.0, Color(KEY_EDGE, alpha), false, 1.0, true)
		draw_circle(middle + Vector2(0, -0.8), 1.2, Color(DOOR_EDGE, alpha))
		draw_line(middle + Vector2(0, -0.5), middle + Vector2(0, 2), Color(DOOR_EDGE, alpha), 1.0)
	for gate: Vector3i in gates:
		var ends := _edge_ends(gate)
		var color := SWITCH_COLORS[gates[gate] % SWITCH_COLORS.size()]
		var open := is_pressed(gates[gate])
		color.a = (OPEN_GATE_ALPHA if open else 1.0) * alpha
		var along := (ends[1] - ends[0]) / 4.0
		var across := Vector2(along.y, -along.x).normalized() * 3.5
		if not open:
			draw_line(ends[0], ends[1], Color(SHADOW, SHADOW.a * alpha), WALL_WIDTH + 2.0)
		draw_line(ends[0], ends[1], color, 3.0)
		# Bars across the gate, and a post at each end.
		for i in range(1, 4):
			var at := ends[0] + along * i
			draw_line(at - across, at + across, color, 2.0)
		for end in ends:
			draw_circle(end, 3.0, color)


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


## Draws a gold key: a ring, a shaft and two teeth, tilted up to the right.
func _draw_key(center: Vector2) -> void:
	draw_set_transform_matrix(_view * Transform2D(-PI / 4, center))
	for layer: Array in [[KEY_EDGE, 2.0], [KEY, 0.0]]:
		var color: Color = layer[0]
		var grow: float = layer[1]
		draw_line(Vector2(-3, 0), Vector2(10, 0), color, 2.5 + grow)
		draw_line(Vector2(6, 0), Vector2(6, 4), color, 2.0 + grow)
		draw_line(Vector2(9, 0), Vector2(9, 3.5), color, 2.0 + grow)
		draw_circle(Vector2(-6, 0), 4.5 + grow / 2.0, color)
	draw_circle(Vector2(-6, 0), 1.8, KEY_EDGE)
	draw_set_transform_matrix(_view)


## Draws a wooden crate from above: a box of planks with a frame and a cross brace.
func _draw_crate(center: Vector2) -> void:
	var box := Rect2(center - Vector2(9.5, 9.5), Vector2(19, 19))
	draw_rect(Rect2(box.position + Vector2(1.5, 2), box.size), SHADOW)
	draw_rect(box, CRATE)
	draw_rect(box.grow(-3), CRATE_EDGE, false, 1.0)
	draw_line(box.position + Vector2(3, 3), box.end - Vector2(3, 3), CRATE_EDGE, 2.0)
	draw_rect(box, CRATE_EDGE, false, 2.0)


## Draws a small treasure chest from the front: a wooden box with a rounded lid, iron bands and a
## gold lock.
func _draw_chest(center: Vector2) -> void:
	var box := Rect2(center + Vector2(-10, -3), Vector2(20, 12))
	draw_rect(Rect2(box.position + Vector2(1.5, 2), box.size), SHADOW)
	draw_colored_polygon(_ellipse(center + Vector2(0, -3), Vector2(10, 6)), TRAP_WOOD)
	draw_rect(box, TRAP_WOOD)
	draw_line(center + Vector2(-10, -3), center + Vector2(10, -3), TRAP_WOOD_EDGE, 1.5)
	for x in [-6.5, 6.5]:
		draw_line(center + Vector2(x, -8), center + Vector2(x, 9), STEEL_EDGE, 2.0)
	draw_rect(box, TRAP_WOOD_EDGE, false, 1.5)
	draw_rect(Rect2(center + Vector2(-2.5, -4.5), Vector2(5, 6)), CHEST_GOLD)
	draw_rect(Rect2(center + Vector2(-2.5, -4.5), Vector2(5, 6)), TRAP_WOOD_EDGE, false, 1.0)


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


## Shades the cells a machine's blast reaches: faintly while it counts down, and strongly, outlined,
## on the turn it goes off.
func _draw_blast_zone(hazard: Hazard) -> void:
	var color := SPARK if hazard.kind == Hazard.Kind.PYLON else FLAME
	var armed := hazard.is_armed()
	for cell in blast_cells(hazard):
		var rect := Rect2(Vector2(cell) * CELL, Vector2(CELL, CELL))
		draw_rect(rect, Color(color, BLAST_ARMED_ALPHA if armed else BLAST_IDLE_ALPHA))
		if armed:
			draw_rect(rect.grow(-1.5), Color(color.darkened(0.3), 0.7), false, 1.5)


## Draws a machine's countdown in a round badge: dark while it counts down, red from the turn it goes
## off.
func _draw_countdown(center: Vector2, hazard: Hazard) -> void:
	draw_circle(center, 7.0, ARMED if hazard.timer <= 1 else MACHINE_EDGE)
	draw_circle(center, 7.0, Color.WHITE, false, 1.0, true)
	var font := ThemeDB.fallback_font
	var text := str(hazard.timer)
	var at := center + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x / 2.0, 4.5)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


## Draws a shock pylon from above: a metal base with a copper coil and four contacts that light up on
## the turn it goes off, and its countdown in the middle.
func _draw_pylon(hazard: Hazard) -> void:
	var center := _cell_center(Vector2(hazard.cell))
	var base := PackedVector2Array()
	for i in 6:
		base.append(center + Vector2.from_angle(TAU * i / 6.0 + PI / 6) * 13.0)
	draw_colored_polygon(_offset(base, Vector2(1.5, 2)), SHADOW)
	draw_colored_polygon(base, MACHINE)
	base.append(base[0])
	draw_polyline(base, MACHINE_EDGE, 1.5, true)
	draw_arc(center, 10.0, 0.0, TAU, 24, COIL, 2.5, true)
	draw_arc(center, 7.5, 0.0, TAU, 24, COIL.darkened(0.3), 1.5, true)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		draw_circle(center + corner * 7.5, 1.6, SPARK if hazard.is_armed() else MACHINE_EDGE)
	_draw_countdown(center, hazard)


## Draws a flamethrower from above: a fuel canister with a nozzle pointing the way it fires, its tip
## lit on the turn it goes off, and its countdown on the canister.
func _draw_flamer(hazard: Hazard) -> void:
	var center := _cell_center(Vector2(hazard.cell))
	var along := Vector2(Card.OFFSETS[hazard.dir])
	draw_rect(Rect2(center - Vector2(10, 10) + Vector2(1.5, 2), Vector2(20, 20)), SHADOW)
	draw_set_transform_matrix(_view * Transform2D(Card.ANGLES[hazard.dir], center))
	var tank := Rect2(-10, -5, 20, 18)
	draw_rect(tank, FUEL_TANK)
	for y: float in [-2.0, 10.0]:
		draw_line(Vector2(-10, y), Vector2(10, y), MACHINE, 2.0)
	draw_rect(tank, MACHINE_EDGE, false, 1.5)
	draw_rect(Rect2(-3.5, -14, 7, 9), MACHINE_EDGE)
	draw_rect(Rect2(-2.5, -13, 5, 8), MACHINE)
	draw_rect(Rect2(-5, -15.5, 10, 3.5), FLAME if hazard.is_armed() else MACHINE_EDGE)
	draw_set_transform_matrix(_view)
	_draw_countdown(center - along * 4.0, hazard)


## Draws a machine going off, brightest halfway through the blast: sparks arcing from a pylon to each
## cell around it, or a jet of flame along a flamethrower's cells.
func _draw_blast(hazard: Hazard) -> void:
	var strength := sin(_blast * PI)
	if strength <= 0.0:
		return
	var center := _cell_center(Vector2(hazard.cell))
	var cells := blast_cells(hazard)
	if hazard.kind == Hazard.Kind.PYLON:
		draw_circle(center, CELL * 1.5, Color(SPARK, 0.25 * strength))
		for i in cells.size():
			var to := _cell_center(Vector2(cells[i]))
			var across := (to - center).normalized().orthogonal()
			var bolt := PackedVector2Array([center])
			for j in range(1, 4):
				# A zigzag that shifts as the blast goes on, so the sparks crackle.
				var wobble := sin(i * 7.3 + j * 3.1 + _blast * 25.0) * 4.0
				bolt.append(center.lerp(to, j / 4.0) + across * wobble)
			bolt.append(to)
			draw_polyline(bolt, Color(SPARK, strength), 3.5, true)
			draw_polyline(bolt, Color(SPARK_CORE, strength), 1.5, true)
		return
	if cells.is_empty():
		return
	var along := Vector2(Card.OFFSETS[hazard.dir])
	var across := along.orthogonal()
	var start := center + along * 15.0
	var tip := _cell_center(Vector2(cells[-1])) + along * CELL * 0.4
	var length := start.distance_to(tip)
	for layer: Array in [[FLAME, 11.0], [FLAME_CORE, 5.5]]:
		var color: Color = layer[0]
		var width: float = layer[1]
		var side := PackedVector2Array([start + across * width * 0.4])
		var other_side := PackedVector2Array([start - across * width * 0.4])
		for j in range(1, 6):
			var t := j / 5.0
			# Widest two thirds of the way along, and flickering.
			var half := width * (0.4 + 0.6 * sin(t * PI * 0.8)) * (1.0 + sin(j * 2.7 + _blast * 30.0) * 0.2)
			side.append(start + along * length * t + across * half)
			other_side.append(start + along * length * t - across * half)
		other_side.reverse()
		side.append(tip)
		side.append_array(other_side)
		draw_colored_polygon(side, Color(color, strength))


## Draws a top-down mouse facing up, rotated to the direction it last moved.
func _draw_mouse(center: Vector2) -> void:
	draw_set_transform_matrix(_view * Transform2D(Card.ANGLES[facing], center))
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
	draw_set_transform_matrix(_view)


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
	draw_set_transform_matrix(_view * Transform2D(Card.ANGLES[cat_facing],
		Vector2.ONE * (KING_SCALE if king else 1.0), 0.0, center))
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
	draw_set_transform_matrix(_view)


func _ellipse(center: Vector2, radii: Vector2, points := 20) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points:
		var angle := TAU * i / points
		result.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return result
