class_name Difficulty
extends RefCounted
## How hard each round of a run is. The first EASY_ROUNDS rounds are a small board with no
## obstacles; after that the board grows and gets more traps and walls each round, and the other
## obstacles join one at a time: cats, glue, mouse holes, conveyors, then creaky floorboards. Every
## round has a turn limit, and running out of turns ends the run like being caught.

## Rounds at the start of a run with no traps or cats.
const EASY_ROUNDS := 2
## Cells along each side of the board in round 1. It grows by GRID_GROWTH a round, up to Board.MAX_GRID.
const START_GRID := 8
const GRID_GROWTH := 1
## Traps added each round after the easy rounds, up to MAX_TRAPS.
const TRAPS_PER_ROUND := 1
const MAX_TRAPS := 20
## Runs of wall (see Main._place_walls) added each round after the easy rounds, up to MAX_WALLS.
const WALLS_PER_ROUND := 2
const MAX_WALLS := 24
## The first round with a cat. Another cat joins every ROUNDS_PER_CAT rounds, up to MAX_CATS.
const FIRST_CAT_ROUND := 4
const ROUNDS_PER_CAT := 4
const MAX_CATS := 5
## Glue pads: START_GLUE in FIRST_GLUE_ROUND, another every ROUNDS_PER_GLUE rounds, up to MAX_GLUE.
const FIRST_GLUE_ROUND := 5
const START_GLUE := 2
const ROUNDS_PER_GLUE := 2
const MAX_GLUE := 8
## Linked pairs of mouse holes, the same way.
const FIRST_HOLE_ROUND := 7
const START_HOLES := 1
const ROUNDS_PER_HOLE := 5
const MAX_HOLES := 3
## Conveyor belts (see Main._place_floor), the same way.
const FIRST_BELT_ROUND := 8
const START_BELTS := 1
const ROUNDS_PER_BELT := 3
const MAX_BELTS := 4
## Creaky floorboards, the same way.
const FIRST_FLOORBOARD_ROUND := 10
const START_FLOORBOARDS := 2
const ROUNDS_PER_FLOORBOARD := 2
const MAX_FLOORBOARDS := 8
## The turn limit gives a turn for every CELLS_PER_TURN cells from the mouse to the cheese, plus spare
## turns: START_SPARE_TURNS, one fewer every ROUNDS_PER_SPARE_TURN rounds, down to MIN_SPARE_TURNS.
const CELLS_PER_TURN := 2.5
const START_SPARE_TURNS := 4
const ROUNDS_PER_SPARE_TURN := 4
const MIN_SPARE_TURNS := 2


## Cells along each side of the board.
static func grid(round_number: int) -> int:
	return mini(START_GRID + (round_number - 1) * GRID_GROWTH, Board.MAX_GRID)


static func traps(round_number: int) -> int:
	return clampi((round_number - EASY_ROUNDS) * TRAPS_PER_ROUND, 0, MAX_TRAPS)


## Runs of wall.
static func walls(round_number: int) -> int:
	return clampi((round_number - EASY_ROUNDS) * WALLS_PER_ROUND, 0, MAX_WALLS)


## Roaming cats, not counting the Alley King.
static func cats(round_number: int) -> int:
	return _ramp(round_number, FIRST_CAT_ROUND, 1, ROUNDS_PER_CAT, MAX_CATS)


static func glue(round_number: int) -> int:
	return _ramp(round_number, FIRST_GLUE_ROUND, START_GLUE, ROUNDS_PER_GLUE, MAX_GLUE)


## Linked pairs of mouse holes.
static func holes(round_number: int) -> int:
	return _ramp(round_number, FIRST_HOLE_ROUND, START_HOLES, ROUNDS_PER_HOLE, MAX_HOLES)


## Conveyor belts.
static func belts(round_number: int) -> int:
	return _ramp(round_number, FIRST_BELT_ROUND, START_BELTS, ROUNDS_PER_BELT, MAX_BELTS)


static func floorboards(round_number: int) -> int:
	return _ramp(round_number, FIRST_FLOORBOARD_ROUND, START_FLOORBOARDS, ROUNDS_PER_FLOORBOARD,
		MAX_FLOORBOARDS)


## Turns to reach cheese that starts distance steps from the mouse, around the walls and traps.
static func turn_limit(round_number: int, distance: int) -> int:
	var spare := maxi(START_SPARE_TURNS - floori((round_number - 1) / float(ROUNDS_PER_SPARE_TURN)),
		MIN_SPARE_TURNS)
	return ceili(distance / CELLS_PER_TURN) + spare


## "12x12 board, 3 traps, 6 walls, 1 cat, 2 glue", for labels. Leaves out what the round doesn't have.
static func describe(round_number: int) -> String:
	var size := grid(round_number)
	var parts := PackedStringArray(["%dx%d board" % [size, size]])
	for part: Array in [[traps(round_number), "trap"], [walls(round_number), "wall"],
			[cats(round_number), "cat"], [glue(round_number), "glue"],
			[holes(round_number), "hole pair"], [belts(round_number), "conveyor"],
			[floorboards(round_number), "floorboard"]]:
		var count: int = part[0]
		if count > 0:
			var noun: String = part[1]
			parts.append("%d %s%s" % [count, noun, "" if count == 1 or noun == "glue" else "s"])
	return ", ".join(parts)


## count from the first round, then one more every rounds_per_more rounds, up to most. 0 before first.
static func _ramp(round_number: int, first: int, count: int, rounds_per_more: int, most: int) -> int:
	if round_number < first:
		return 0
	return mini(count + floori((round_number - first) / float(rounds_per_more)), most)
