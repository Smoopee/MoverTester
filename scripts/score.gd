class_name Score
extends RefCounted
## The round's score, separate from crumbs (which are money). Each turn adds up points for what the
## mouse does (cells moved, crumbs and chests picked up, rides on holes, belts and pads), times the
## turn's mult, which starts at 1 and grows from score trinkets and skills and from spare turns on the turn that
## reaches the cheese. Each round has a target (target()): meeting it pays bonus crumbs, and missing it
## in a boss round ends the run.

## Points for each cell the mouse walks, slides or jumps, each crumb and chest it picks up, and each
## hole, conveyor cell or jump pad it rides.
const CELL_POINTS := 1
const CRUMB_POINTS := 5
const CHEST_POINTS := 10
const RIDE_POINTS := 2
## Mult each turn left over adds on the turn that reaches the cheese.
const SPARE_TURN_MULT := 1
## The target in round 1, growing by TARGET_GROWTH a round. A boss round's is BOSS_TARGET times that.
const START_TARGET := 20
const TARGET_GROWTH := 1.15
const BOSS_TARGET := 1.25
## Meeting the target pays TARGET_CRUMBS times the score over the target (3 at the target, 6 at twice
## it), rounded down, up to MAX_TARGET_CRUMBS.
const TARGET_CRUMBS := 3
const MAX_TARGET_CRUMBS := 9
## Score trinkets (Items.Trinket).
const BUTTER_PAT_POINTS := 2
const RIDE_TICKET_MULT := 2
## Score skills (Items.Skill).
const HARD_HEAD_MULT := 1
const SHOW_OFF_MULT := 1
const DAREDEVIL_TIMES := 2
## Mult a card with the SHINY stamp adds when it plays.
const SHINY_MULT := 2
const COLOR := Color("8fd3ff")


## The score a round needs.
static func target(round_number: int, boss: bool) -> int:
	var base := START_TARGET * pow(TARGET_GROWTH, round_number - 1)
	return roundi(base * (BOSS_TARGET if boss else 1.0))


## Crumbs a won round's score pays: none short of the target.
static func crumbs(score: int, goal: int) -> int:
	if score < goal:
		return 0
	return mini(floori(TARGET_CRUMBS * float(score) / goal), MAX_TARGET_CRUMBS)
