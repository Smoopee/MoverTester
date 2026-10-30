class_name Difficulty
extends RefCounted
## How hard each round of a run is. The first EASY_ROUNDS rounds are a small board with no traps or
## cats; after that the board grows and gets more traps and cats each round. Every round has a turn
## limit, and running out of turns ends the run like being caught.

## Rounds at the start of a run with no traps or cats.
const EASY_ROUNDS := 2
## Cells along each side of the board in round 1. It grows by GRID_GROWTH a round, up to Board.MAX_GRID.
const START_GRID := 8
const GRID_GROWTH := 1
## Traps added each round after the easy rounds, up to MAX_TRAPS.
const TRAPS_PER_ROUND := 1
const MAX_TRAPS := 20
## The first round with a cat. Another cat joins every ROUNDS_PER_CAT rounds, up to MAX_CATS.
const FIRST_CAT_ROUND := 4
const ROUNDS_PER_CAT := 4
const MAX_CATS := 5
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


## Roaming cats, not counting the Alley King.
static func cats(round_number: int) -> int:
	if round_number < FIRST_CAT_ROUND:
		return 0
	return mini(1 + floori((round_number - FIRST_CAT_ROUND) / float(ROUNDS_PER_CAT)), MAX_CATS)


## Turns to reach cheese that starts distance cells from the mouse.
static func turn_limit(round_number: int, distance: int) -> int:
	var spare := maxi(START_SPARE_TURNS - floori((round_number - 1) / float(ROUNDS_PER_SPARE_TURN)),
		MIN_SPARE_TURNS)
	return ceili(distance / CELLS_PER_TURN) + spare


## "12x12 board, 3 traps, 1 cat", for labels.
static func describe(round_number: int) -> String:
	var size := grid(round_number)
	var trap_count := traps(round_number)
	var cat_count := cats(round_number)
	return "%dx%d board, %d trap%s, %d cat%s" % [size, size, trap_count, "" if trap_count == 1 else "s",
		cat_count, "" if cat_count == 1 else "s"]
