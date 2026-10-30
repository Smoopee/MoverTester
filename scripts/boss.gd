class_name Boss
extends RefCounted
## Boss rounds: every EVERY rounds, a round with a rule that makes it harder. The shop before one says
## which boss is next. Beating a boss pays WIN_CRUMBS and gives a free trinket.

enum Kind { ALLEY_KING, RUNAWAY_CHEESE, KITCHEN_LIGHT }

## Every this many rounds is a boss round.
const EVERY := 3
## Crumbs for reaching the cheese in a boss round, in place of the usual win reward.
const WIN_CRUMBS := 10
## Trinkets offered for free after a boss, of which the player takes one.
const FREE_TRINKETS := 3
## Cells the Alley King walks each turn. It joins the round's usual cats.
const KING_STEPS := 4
## Cells the cheese runs each turn in RUNAWAY CHEESE, and the extra turns that round gets to catch it.
const CHEESE_STEPS := 1
const RUNAWAY_CHEESE_EXTRA_TURNS := 3
## Turns KITCHEN LIGHT takes off the round's turn limit, which it won't cut below KITCHEN_LIGHT_MIN_TURNS.
const KITCHEN_LIGHT_TURNS_CUT := 2
const KITCHEN_LIGHT_MIN_TURNS := 3
const COLOR := Color("e0584a")
## Name and description of each boss.
const INFO := {
	Kind.ALLEY_KING: ["THE ALLEY KING", "A big cat hunts the mouse, walking %d cells a turn toward it." % KING_STEPS],
	Kind.RUNAWAY_CHEESE: ["RUNAWAY CHEESE",
		"The cheese runs %d cell a turn away from the mouse. " % CHEESE_STEPS
			+ "You get %d extra turns to catch it." % RUNAWAY_CHEESE_EXTRA_TURNS],
	Kind.KITCHEN_LIGHT: ["KITCHEN LIGHT",
		"The light comes on early: %d fewer turns to reach the cheese." % KITCHEN_LIGHT_TURNS_CUT],
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
