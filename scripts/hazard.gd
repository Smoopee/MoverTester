class_name Hazard
extends RefCounted
## A shock pylon or a flamethrower: a machine on a cell that counts down a turn at a time, at the end
## of each turn, and at 0 goes off, then starts its countdown over. A pylon shocks the cells around it,
## diagonals too; a flamethrower shoots a jet of flame the way it points (see Board.blast_cells). A
## mouse in the blast when it goes off is caught. Nothing can move onto the machine's cell, though
## jumps pass over it.

enum Kind { PYLON, FLAMER }

## Cells a flamethrower's jet reaches, if no wall, locked door, closed gate, crate or other machine
## stops it first. It passes over gaps and chasms.
const FLAME_REACH := 3
## Turns between going off, picked for each machine.
const PERIOD_MIN := 2
const PERIOD_MAX := 4
## Kind -> its name, for labels and the log.
const NAMES := {Kind.PYLON: "shock pylon", Kind.FLAMER: "flamethrower"}

var kind := Kind.PYLON
var cell := Vector2i.ZERO
## The way a flamethrower points. Pylons ignore it.
var dir: Card.Dir = Card.Dir.UP
## Turns between going off, and turns until it next goes off: at the end of the turn it shows 1.
var period := 3
var timer := 3


func _init(hazard_kind: Kind, at: Vector2i, facing: Card.Dir = Card.Dir.UP, turns := 3) -> void:
	kind = hazard_kind
	cell = at
	dir = facing
	period = turns
	timer = turns


func copy() -> Hazard:
	var other := Hazard.new(kind, cell, dir, period)
	other.timer = timer
	return other


## True when it goes off at the end of this turn.
func is_armed() -> bool:
	return timer == 1


## "shock pylon (3, 4) 2/3" or "flamethrower (5, 5) RIGHT 1/4", for the log and bug reports.
func label() -> String:
	var facing := " %s" % Card.NAMES[dir] if kind == Kind.FLAMER else ""
	return "%s %s%s %d/%d" % [NAMES[kind], cell, facing, timer, period]
