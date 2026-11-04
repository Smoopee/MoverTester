class_name Items
extends RefCounted
## The run's items. The shop sells trinkets (passive for the rest of the run), consumables (held in
## the pouch, used once), card stamps (which change how a card moves) and card materials (which change
## what it pays when it plays). Skills, held in the SKILL_SLOTS slots above the card slots, aren't
## sold: they're drafted at the start of a run and after each boss (SkillDraft).

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
	# Movement.
	WARP, SPRINT, BURROW,
	# Survival.
	THICK_FUR, NINE_LIVES,
	# Sight and hand.
	KEEN_WHISKERS, PACK_RAT,
	# Score skills (see Score).
	HARD_HEAD, DAREDEVIL, SHOW_OFF,
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
## How a skill works. An ACTIVE one does nothing until it's used: click its slot before Lock In to
## spend a charge and turn it on for that turn. A PASSIVE one is always on. An AUTO one spends a charge
## by itself, when it saves the mouse.
enum SkillUse { ACTIVE, PASSIVE, AUTO }
## Name, use and top level of each skill. Skills aren't sold: the player drafts one at the start of a
## run and after each boss (SkillDraft), and drafting one the run has levels it up.
const SKILLS := {
	Skill.WARP: ["WARP", SkillUse.ACTIVE, 3],
	Skill.SPRINT: ["SPRINT", SkillUse.ACTIVE, 3],
	Skill.BURROW: ["BURROW", SkillUse.ACTIVE, 3],
	Skill.THICK_FUR: ["THICK FUR", SkillUse.PASSIVE, 2],
	Skill.NINE_LIVES: ["NINE LIVES", SkillUse.AUTO, 3],
	Skill.KEEN_WHISKERS: ["KEEN WHISKERS", SkillUse.PASSIVE, 1],
	Skill.PACK_RAT: ["PACK RAT", SkillUse.PASSIVE, 1],
	Skill.HARD_HEAD: ["HARD HEAD", SkillUse.PASSIVE, 3],
	Skill.DAREDEVIL: ["DAREDEVIL", SkillUse.PASSIVE, 3],
	Skill.SHOW_OFF: ["SHOW-OFF", SkillUse.PASSIVE, 3],
}
## Charges a round at level 1 of each skill that has them (ACTIVE and AUTO). Each level after adds
## SKILL_CHARGES_PER_LEVEL. Charges refill at the start of every round.
const SKILL_CHARGES := {
	Skill.WARP: 2,
	Skill.SPRINT: 1,
	Skill.BURROW: 1,
	Skill.NINE_LIVES: 1,
}
const SKILL_CHARGES_PER_LEVEL := 1
## Skills the player can hold at once. With them full, a draft only offers level-ups.
const SKILL_SLOTS := 4
## Skills a draft offers, of which the player takes one.
const DRAFT_CHOICES := 3
const ROMAN: Array[String] = ["", "I", "II", "III", "IV", "V"]
## Cards left in the hand at Lock In that PACK RAT keeps for the next turn, the leftmost first.
const PACK_RAT_CARDS := 2
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


static func skill_name(skill: Skill) -> String:
	return SKILLS[skill][0]


static func skill_use(skill: Skill) -> SkillUse:
	return SKILLS[skill][1]


static func skill_max_level(skill: Skill) -> int:
	return SKILLS[skill][2]


## "THICK FUR" at level 1, "THICK FUR II" at level 2.
static func skill_title(skill: Skill, level: int) -> String:
	return skill_name(skill) if level <= 1 else "%s %s" % [skill_name(skill), ROMAN[mini(level, ROMAN.size() - 1)]]


## Charges a round at level: none for a PASSIVE skill.
static func skill_charges(skill: Skill, level: int) -> int:
	if skill not in SKILL_CHARGES:
		return 0
	return SKILL_CHARGES[skill] + (maxi(level, 1) - 1) * SKILL_CHARGES_PER_LEVEL


## How the skill is used at level: "Click its slot to use it: 2 charges a round.", "Always on.", ...
static func skill_use_text(skill: Skill, level: int) -> String:
	var charges := skill_charges(skill, level)
	match skill_use(skill):
		SkillUse.ACTIVE:
			return "Click its slot before Lock In to use it: %d charge%s a round." % [charges, "" if charges == 1 else "s"]
		SkillUse.AUTO:
			return "Works by itself, %d time%s a round." % [charges, "" if charges == 1 else "s"]
	return "Always on."


## What the skill does at level.
static func skill_text(skill: Skill, level: int) -> String:
	level = maxi(level, 1)
	match skill:
		Skill.WARP:
			return "This turn, every step off an edge brings the mouse in on the opposite side, as in a WRAP slot."
		Skill.SPRINT:
			return "This turn, every card that would take a single step takes two."
		Skill.BURROW:
			return "This turn, every card that would take a single step digs instead: it jumps 2 cells, " \
				+ "under any wall, locked door or gate and over whatever is in between."
		Skill.THICK_FUR:
			return "The first %s the mouse lands on each turn breaks instead of catching it." % (
				"trap" if level == 1 else "%d traps" % level)
		Skill.NINE_LIVES:
			return "When a trap or a cat catches the mouse, it escapes back to where the turn started, and " \
				+ "the turn's other cards don't play. A pylon's or flamethrower's blast, it shrugs off."
		Skill.KEEN_WHISKERS:
			return "Shows on the board where the cards in the slots will take the mouse, before you Lock In."
		Skill.PACK_RAT:
			return "The %d leftmost cards left in your hand at Lock In stay there for the next turn, which draws only up to your hand size." \
				% PACK_RAT_CARDS
		Skill.HARD_HEAD:
			return "Score: +%d mult each time the mouse bumps into a wall, the edge or anything else in its way." \
				% Score.hard_head_mult(level)
		Skill.DAREDEVIL:
			return "Score: x%d mult on a turn whose cards leave the mouse next to a trap, a cat or a cat's path." \
				% Score.daredevil_times(level)
		Skill.SHOW_OFF:
			return "Score: x%d mult on a turn you Lock In with a card in every slot that isn't blocked." \
				% Score.show_off_times(level)
	return ""
