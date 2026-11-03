class_name Items
extends RefCounted
## What the shop sells: trinkets (passive for the rest of the run), skills (always on, held in the
## SKILL_SLOTS slots above the card slots), consumables (held in the pouch, used once), card stamps
## (which change how a card moves) and card materials (which change what it pays when it plays).

## A trinket is an object the mouse carries and does what that object would; a skill is a trait of
## the mouse itself (see CLAUDE.md).
enum Trinket {
	WASTEBASKET, FOUR_LEAF_CLOVER, CRUMB_MAGNET, PIGGY_BANK, SALT_SHAKER,
	# Score trinkets (see Score).
	BUTTER_PAT, RIDE_TICKET,
}
## What a card is made of. It pays out each time the card plays, whatever the slot does, except STONE,
## which pays when the card stays in the hand.
enum CardMaterial { NONE, WOOD, SHINY, GOLD, COPPER, PAPER, STONE }
enum Consumable { FRESH_BREEZE, CALM, NEW_PAWS, CHEESE_BAIT, SQUEEZE }
enum Skill {
	WARP, EFFICIENT, THICK_FUR,
	# Score skills (see Score).
	HARD_HEAD, SHOW_OFF, DAREDEVIL,
}

const TRINKET_COLOR := Color("f5c542")
const CONSUMABLE_COLOR := Color("6fd6c8")
const SKILL_COLOR := Color("e86aa6")
## Name, description and price of each trinket.
const TRINKETS := {
	Trinket.WASTEBASKET: ["WASTEBASKET", "Room to toss more cards: +2 discards every round.", 6],
	Trinket.FOUR_LEAF_CLOVER: ["FOUR-LEAF CLOVER", "Luck keeps the slots clear: they never roll BLOCKED.", 5],
	Trinket.CRUMB_MAGNET: ["CRUMB MAGNET", "After each move, the mouse also picks up crumbs right next to it (up, down, left or right).", 6],
	Trinket.PIGGY_BANK: ["PIGGY BANK", "Each win pays +1 crumb per 5 you hold (up to +5).", 7],
	Trinket.SALT_SHAKER: ["SALT SHAKER", "Seasoned crumbs: each one picked up on the board is worth +2.", 7],
	Trinket.BUTTER_PAT: ["BUTTER PAT",
		"Score: +%d points for each cell the mouse slides on buttered feet." % Score.BUTTER_PAT_POINTS, 6],
	Trinket.RIDE_TICKET: ["RIDE TICKET",
		"Score: +%d mult for each mouse hole, conveyor cell or jump pad the mouse rides." % Score.RIDE_TICKET_MULT, 6],
}
## Name, description and price of each consumable.
const CONSUMABLES := {
	Consumable.FRESH_BREEZE: ["FRESH BREEZE", "Reroll this turn's slot effects.", 3],
	Consumable.CALM: ["CALM", "Clear every slot effect this turn.", 3],
	Consumable.NEW_PAWS: ["NEW PAWS", "Swap your whole hand for new cards. Uses no discards.", 3],
	Consumable.CHEESE_BAIT: ["CHEESE BAIT", "Remove the trap nearest the mouse.", 4],
	Consumable.SQUEEZE: ["SQUEEZE", "This turn the mouse squeezes through walls.", 3],
}
## Name, description and price of each skill.
const SKILLS := {
	Skill.WARP: ["WARP", "Every step off an edge brings the mouse in on the opposite side, as in a WRAP slot.", 10],
	Skill.EFFICIENT: ["EFFICIENT", "Each crumb picked up on the board gives +1 discard this round.", 7],
	Skill.THICK_FUR: ["THICK FUR", "The first trap each round breaks instead of catching the mouse.", 12],
	Skill.HARD_HEAD: ["HARD HEAD",
		"Score: +%d mult each time the mouse bumps into a wall, the edge or anything else in its way." % Score.HARD_HEAD_MULT, 7],
	Skill.SHOW_OFF: ["SHOW-OFF",
		"Score: +%d mult for each slot effect and stamp the cards play." % Score.SHOW_OFF_MULT, 7],
	Skill.DAREDEVIL: ["DAREDEVIL",
		"Score: x%d mult when the cards leave the mouse next to a trap, a cat or a cat's path." % Score.DAREDEVIL_TIMES, 8],
}
## Skills the player can hold at once.
const SKILL_SLOTS := 4
## Slot effects the shop can stamp onto a card. Only ones that work on a single card: direction
## effects would just make it another direction card. Some are stamps only (CardSlot.STAMP_ONLY).
const STAMPS: Array[CardSlot.Effect] = [
	CardSlot.Effect.DOUBLE, CardSlot.Effect.LEAP, CardSlot.Effect.SLIDE, CardSlot.Effect.STRIDE,
	CardSlot.Effect.SWIVEL, CardSlot.Effect.STEADY, CardSlot.Effect.TUNNEL, CardSlot.Effect.SCURRY,
]
const STAMP_PRICE := 6
## Stamps that cost something other than STAMP_PRICE.
const STAMP_PRICES := {
	CardSlot.Effect.SWIVEL: 9,
	CardSlot.Effect.TUNNEL: 8,
}
## Crumbs a GOLD card pays each time it plays.
const GOLD_CRUMBS := 1
## Name, description, price and color of each card material the shop sells.
const MATERIALS := {
	CardMaterial.WOOD: ["WOOD", "Score: +%d points each time the card plays." % Score.WOOD_POINTS, 4,
		Color("d29b62")],
	CardMaterial.SHINY: ["SHINY", "Score: +%d mult for the turn each time the card plays." % Score.SHINY_MULT, 6,
		Color("9fd8ff")],
	CardMaterial.GOLD: ["GOLD", "+%d crumb each time the card plays." % GOLD_CRUMBS, 8, Color("f5c542")],
	CardMaterial.COPPER: ["COPPER",
		# Two formats: one with an array isn't a constant expression.
		("Score: +%d point the first time the card plays, " % Score.COPPER_POINTS)
			+ ("and %d more each time after, for the rest of the run." % Score.COPPER_GROWTH), 6, Color("e0844f")],
	CardMaterial.PAPER: ["PAPER", "Score: +%d point for each cell the card moves the mouse." % Score.PAPER_POINTS,
		4, Color("c9d6e8")],
	CardMaterial.STONE: ["STONE", "Score: +%d mult when you Lock In with the card still in your hand." \
		% Score.STONE_MULT, 6, Color("a8a49a")],
}
## Consumables the player can hold at once.
const POUCH_SIZE := 3


static func stamp_price(effect: CardSlot.Effect) -> int:
	return STAMP_PRICES.get(effect, STAMP_PRICE)
