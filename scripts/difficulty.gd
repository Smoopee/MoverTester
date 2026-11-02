class_name Difficulty
extends RefCounted
## How hard each round of a run is. The first EASY_ROUNDS rounds are a small board with no
## obstacles; after that each round gets more traps and walls, the board grows after each boss
## round, and the other obstacles join one at a time: cats, glue, jump pads, mouse holes, conveyors,
## locked doors, creaky floorboards, switches, chasms, shock pylons, then flamethrowers. Every round
## has a turn limit, and running out of turns ends the run like being caught.

## Rounds at the start of a run with no traps or cats.
const EASY_ROUNDS := 2
## Cells along each side of the board in round 1. It grows by GRID_GROWTH after each boss round (every
## Boss.EVERY rounds), up to Board.MAX_GRID.
const START_GRID := 8
const GRID_GROWTH := 2
## Traps, and runs of wall (see Main._place_walls), for each cell of the board after the easy rounds,
## rounded down. They grow with the board, so they step up after each boss round.
const TRAPS_PER_CELL := 0.034
const WALLS_PER_CELL := 0.06
## The other obstacles join one at a time, on the rounds between boss rounds (a boss round adds no
## new kind), so a 21-round run (Run.GOAL_ROUNDS) meets the last of them in round 19.
## The first round with a cat. Another cat joins every ROUNDS_PER_CAT rounds, up to MAX_CATS.
const FIRST_CAT_ROUND := 4
const ROUNDS_PER_CAT := 5
const MAX_CATS := 5
## Glue pads: START_GLUE in FIRST_GLUE_ROUND, another every ROUNDS_PER_GLUE rounds, up to MAX_GLUE.
const FIRST_GLUE_ROUND := 5
const START_GLUE := 2
const ROUNDS_PER_GLUE := 3
const MAX_GLUE := 8
## Jump pads, the same way.
const FIRST_PAD_ROUND := 7
const START_PADS := 2
const ROUNDS_PER_PAD := 4
const MAX_PADS := 6
## Linked pairs of mouse holes, the same way.
const FIRST_HOLE_ROUND := 8
const START_HOLES := 1
const ROUNDS_PER_HOLE := 6
const MAX_HOLES := 3
## Conveyor belts (see Main._place_floor), the same way.
const FIRST_BELT_ROUND := 10
const START_BELTS := 1
const ROUNDS_PER_BELT := 4
const MAX_BELTS := 4
## Locked doors, each with a key (see Main._place_locks), the same way.
const FIRST_DOOR_ROUND := 11
const START_DOORS := 1
const ROUNDS_PER_DOOR := 5
const MAX_DOORS := 3
## Creaky floorboards, the same way.
const FIRST_FLOORBOARD_ROUND := 13
const START_FLOORBOARDS := 2
const ROUNDS_PER_FLOORBOARD := 3
const MAX_FLOORBOARDS := 8
## Switches (a pressure plate, its gate and a crate), the same way. At most Board.SWITCH_COLORS.
const FIRST_SWITCH_ROUND := 14
const START_SWITCHES := 1
const ROUNDS_PER_SWITCH := 5
const MAX_SWITCHES := 3
## Chasms, some with a bridge (see Main._place_chasms), the same way.
const FIRST_CHASM_ROUND := 16
const START_CHASMS := 2
const ROUNDS_PER_CHASM := 3
const MAX_CHASMS := 6
## Shock pylons (see Main._place_hazards), the same way.
const FIRST_PYLON_ROUND := 17
const START_PYLONS := 1
const ROUNDS_PER_PYLON := 3
const MAX_PYLONS := 4
## Flamethrowers, the same way.
const FIRST_FLAMER_ROUND := 19
const START_FLAMERS := 1
const ROUNDS_PER_FLAMER := 3
const MAX_FLAMERS := 4
## The turn limit gives a turn for every CELLS_PER_TURN cells from the mouse to the cheese, plus spare
## turns: START_SPARE_TURNS, one fewer every ROUNDS_PER_SPARE_TURN rounds, down to MIN_SPARE_TURNS.
const CELLS_PER_TURN := 2.5
const START_SPARE_TURNS := 4
const ROUNDS_PER_SPARE_TURN := 4
const MIN_SPARE_TURNS := 2


## Cells along each side of the board.
static func grid(round_number: int) -> int:
	var boss_rounds_passed := floori((round_number - 1) / float(Boss.EVERY))
	return mini(START_GRID + boss_rounds_passed * GRID_GROWTH, Board.MAX_GRID)


static func traps(round_number: int) -> int:
	return _per_cell(round_number, TRAPS_PER_CELL)


## Runs of wall.
static func walls(round_number: int) -> int:
	return _per_cell(round_number, WALLS_PER_CELL)


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


static func pads(round_number: int) -> int:
	return _ramp(round_number, FIRST_PAD_ROUND, START_PADS, ROUNDS_PER_PAD, MAX_PADS)


## Locked doors, each with its key.
static func doors(round_number: int) -> int:
	return _ramp(round_number, FIRST_DOOR_ROUND, START_DOORS, ROUNDS_PER_DOOR, MAX_DOORS)


## Switches: a pressure plate, its gate and a crate each.
static func switches(round_number: int) -> int:
	return _ramp(round_number, FIRST_SWITCH_ROUND, START_SWITCHES, ROUNDS_PER_SWITCH, MAX_SWITCHES)


## Chasms, each a run of cells that may have a bridge.
static func chasms(round_number: int) -> int:
	return _ramp(round_number, FIRST_CHASM_ROUND, START_CHASMS, ROUNDS_PER_CHASM, MAX_CHASMS)


## Shock pylons, each shocking the cells around it every few turns.
static func pylons(round_number: int) -> int:
	return _ramp(round_number, FIRST_PYLON_ROUND, START_PYLONS, ROUNDS_PER_PYLON, MAX_PYLONS)


## Flamethrowers, each shooting a jet of flame every few turns.
static func flamers(round_number: int) -> int:
	return _ramp(round_number, FIRST_FLAMER_ROUND, START_FLAMERS, ROUNDS_PER_FLAMER, MAX_FLAMERS)


## Turns to reach cheese that starts distance steps from the mouse, around the walls and traps.
static func turn_limit(round_number: int, distance: int) -> int:
	var spare := maxi(START_SPARE_TURNS - floori((round_number - 1) / float(ROUNDS_PER_SPARE_TURN)),
		MIN_SPARE_TURNS)
	return ceili(distance / CELLS_PER_TURN) + spare


## "12x12 board, 3 traps, 6 walls, 1 cat, 2 glue", for labels. Leaves out what the round doesn't have.
static func describe(round_number: int) -> String:
	var size := grid(round_number)
	var parts := PackedStringArray(["%dx%d board" % [size, size]])
	for part: Array in [[traps(round_number), "trap", "traps"], [walls(round_number), "wall", "walls"],
			[cats(round_number), "cat", "cats"], [glue(round_number), "glue", "glue"],
			[pads(round_number), "jump pad", "jump pads"], [holes(round_number), "hole pair", "hole pairs"],
			[belts(round_number), "conveyor", "conveyors"], [doors(round_number), "locked door", "locked doors"],
			[floorboards(round_number), "floorboard", "floorboards"],
			[switches(round_number), "switch", "switches"], [chasms(round_number), "chasm", "chasms"],
			[pylons(round_number), "shock pylon", "shock pylons"],
			[flamers(round_number), "flamethrower", "flamethrowers"]]:
		var count: int = part[0]
		if count > 0:
			parts.append("%d %s" % [count, part[1] if count == 1 else part[2]])
	return ", ".join(parts)


## per_cell for each cell of the round's board, rounded down. 0 in the easy rounds.
static func _per_cell(round_number: int, per_cell: float) -> int:
	if round_number <= EASY_ROUNDS:
		return 0
	var size := grid(round_number)
	return floori(size * size * per_cell)


## count from the first round, then one more every rounds_per_more rounds, up to most. 0 before first.
static func _ramp(round_number: int, first: int, count: int, rounds_per_more: int, most: int) -> int:
	if round_number < first:
		return 0
	return mini(count + floori((round_number - first) / float(rounds_per_more)), most)
