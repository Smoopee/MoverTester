class_name Cat
extends RefCounted
## A cat roaming the board. Each turn it plans a short path, which the board shows, and walks it once
## the mouse has moved. A mouse that moves onto the cat or its path is caught.

## Cells a cat walks each turn.
const STEPS := 3
## Chance at each step that the cat turns aside even though the way ahead is clear.
const TURN_CHANCE := 0.25

var cell := Vector2i.ZERO
## Cells this cat walks each turn.
var steps := STEPS
## A hunter (the Alley King) walks toward plan()'s target instead of roaming, and stops next to it.
var hunter := false
## The way the cat last walked. The next path carries on from it.
var heading: Card.Dir = Card.Dir.UP
## The way the cat is drawn facing: the first step of its path, or the step it's walking.
var facing: Card.Dir = Card.Dir.UP
## This turn's cells to walk, in order, not counting the one the cat is on.
var path: Array[Vector2i] = []
## Position in cell units; moved between cells so the walk is animated.
var pos := Vector2.ZERO


func _init(start: Vector2i) -> void:
	cell = start
	pos = Vector2(start)
	heading = Card.Dir.values().pick_random()
	facing = heading


## True when the cell is the cat's or on its path.
func covers(at: Vector2i) -> bool:
	return at == cell or at in path


## Plans this turn's path: mostly straight ahead, sometimes turning, and back the way it came only
## when boxed in. blocked(cell) says which cells the cat can't walk onto. The path never crosses
## itself, and stops short if the cat runs out of room. A hunter instead takes the free step closest
## to target each time, and stops once it's next to it.
func plan(blocked: Callable, target := Vector2i.ZERO) -> void:
	path.clear()
	var at := cell
	var dir := heading
	for i in steps:
		var options: Array[Card.Dir] = []
		if hunter:
			if _distance(at, target) <= 1:
				break
			options.assign(Card.Dir.values())
			options.shuffle()
			options.sort_custom(func(a: Card.Dir, b: Card.Dir) -> bool:
				return _distance(at + Card.OFFSETS[a], target) < _distance(at + Card.OFFSETS[b], target))
		else:
			var sides: Array[Card.Dir] = [_turn(dir, 1), _turn(dir, -1)]
			sides.shuffle()
			if randf() < TURN_CHANCE:
				options.append_array(sides + [dir])
			else:
				options.append_array([dir] + sides)
			options.append(_turn(dir, 2))
		var moved := false
		for option in options:
			var next: Vector2i = at + Card.OFFSETS[option]
			if next != cell and next not in path and not blocked.call(next):
				path.append(next)
				at = next
				dir = option
				moved = true
				break
		if not moved:
			break
	heading = dir
	facing = Card.OFFSETS.find_key(path[0] - cell) as Card.Dir if path else heading


static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## The direction quarter_turns quarter turns clockwise from dir (negative for counterclockwise).
static func _turn(dir: Card.Dir, quarter_turns: int) -> Card.Dir:
	var offset: Vector2i = Card.OFFSETS[dir]
	for i in posmod(quarter_turns, 4):
		offset = Vector2i(-offset.y, offset.x)
	return Card.OFFSETS.find_key(offset) as Card.Dir
