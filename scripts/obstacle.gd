class_name Obstacle
extends RefCounted
## The kinds of board obstacle, sorted into groups by how they get in the mouse's way.

enum Kind { TRAP, GLUE, FLOORBOARD, WALL, CHASM, CAT, PYLON, FLAMER, JUMP_PAD, HOLE, CONVEYOR, DOOR,
	SWITCH }
enum Group { TILE_DENIAL, STRUCTURE_DENIAL, MULTI_TILE_DENIAL, MOVEMENT, PUZZLE }

const NAMES := {
	Kind.TRAP: "Mouse trap",
	Kind.GLUE: "Glue",
	Kind.FLOORBOARD: "Creaky floorboard",
	Kind.WALL: "Wall",
	Kind.CHASM: "Chasm",
	Kind.CAT: "Cat",
	Kind.PYLON: "Shock pylon",
	Kind.FLAMER: "Flamethrower",
	Kind.JUMP_PAD: "Jump pad",
	Kind.HOLE: "Mouse hole",
	Kind.CONVEYOR: "Conveyor belt",
	Kind.DOOR: "Locked door",
	Kind.SWITCH: "Switch",
}
## The group each kind is in.
const GROUP_OF := {
	Kind.TRAP: Group.TILE_DENIAL,
	Kind.GLUE: Group.TILE_DENIAL,
	Kind.FLOORBOARD: Group.TILE_DENIAL,
	Kind.WALL: Group.STRUCTURE_DENIAL,
	Kind.CHASM: Group.STRUCTURE_DENIAL,
	Kind.CAT: Group.MULTI_TILE_DENIAL,
	Kind.PYLON: Group.MULTI_TILE_DENIAL,
	Kind.FLAMER: Group.MULTI_TILE_DENIAL,
	Kind.JUMP_PAD: Group.MOVEMENT,
	Kind.HOLE: Group.MOVEMENT,
	Kind.CONVEYOR: Group.MOVEMENT,
	Kind.DOOR: Group.PUZZLE,
	Kind.SWITCH: Group.PUZZLE,
}
const GROUP_INFO := {
	Group.TILE_DENIAL: {
		"name": "Tile denial",
		"description": "Spoils one cell: a trap catches the mouse, glue sticks it, a floorboard breaks behind it.",
	},
	Group.STRUCTURE_DENIAL: {
		"name": "Structure denial",
		"description": "Shapes the board: nothing moves through a wall or onto a chasm, so the way goes around.",
	},
	Group.MULTI_TILE_DENIAL: {
		"name": "Multi-tile denial",
		"description": "Threatens several cells at once, and which cells changes from turn to turn.",
	},
	Group.MOVEMENT: {
		"name": "Movement options",
		"description": "Carries the mouse farther than its cards would, and rides chain into each other.",
	},
	Group.PUZZLE: {
		"name": "Multi-step puzzles",
		"description": "Shuts a shortcut that takes more than one move to open: fetch a key, or push a crate.",
	},
}


## The kinds in group, in Kind order.
static func kinds_in(group: Group) -> Array[Kind]:
	var kinds: Array[Kind] = []
	for kind: Kind in GROUP_OF:
		if GROUP_OF[kind] == group:
			kinds.append(kind)
	return kinds
