class_name Boss
extends RefCounted
## Boss rounds: every EVERY rounds, a round with a rule that makes it harder. The shop before one says
## which boss is next. Beating a boss pays WIN_CRUMBS, gives a free trinket and makes later rounds
## harder (more traps and cats).

enum Kind { ALLEY_KING, RUNAWAY_CHEESE, KITCHEN_LIGHT }

## Every this many rounds is a boss round.
const EVERY := 3
## Crumbs for reaching the cheese in a boss round, in place of the usual win reward.
const WIN_CRUMBS := 10
## Trinkets offered for free after a boss, of which the player takes one.
const FREE_TRINKETS := 3
## Traps added to every round for each boss beaten.
const TRAPS_PER_BOSS := 1
## A cat is added to every round for each this many bosses beaten, up to MAX_EXTRA_CATS.
const BOSSES_PER_CAT := 2
const MAX_EXTRA_CATS := 3
## Cells the Alley King walks each turn.
const KING_STEPS := 4
## Cells the cheese runs each turn in RUNAWAY CHEESE.
const CHEESE_STEPS := 1
## Turns to reach the cheese in KITCHEN LIGHT.
const KITCHEN_LIGHT_TURNS := 8
const COLOR := Color("e0584a")
## Name and description of each boss.
const INFO := {
	Kind.ALLEY_KING: ["THE ALLEY KING", "A big cat hunts the mouse, walking %d cells a turn toward it." % KING_STEPS],
	Kind.RUNAWAY_CHEESE: ["RUNAWAY CHEESE", "The cheese runs %d cell a turn away from the mouse." % CHEESE_STEPS],
	Kind.KITCHEN_LIGHT: ["KITCHEN LIGHT",
		"Reach the cheese within %d turns, or the light comes on and the run is over." % KITCHEN_LIGHT_TURNS],
}


static func is_boss_round(round_number: int) -> bool:
	return round_number % EVERY == 0


## A random boss, other than the one given.
static func roll(other := -1) -> Kind:
	var pool: Array = Kind.values()
	pool.erase(other)
	return pool.pick_random()


## "THE ALLEY KING: A big cat hunts ...", for labels.
static func describe(kind: Kind) -> String:
	return "%s: %s" % INFO[kind]
