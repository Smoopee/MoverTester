class_name Items
extends RefCounted
## What the shop sells: trinkets (passive for the rest of the run), consumables (held in the pouch,
## used once) and card stamps.

enum Trinket { SPARE_PAWS, LUCKY_TAIL, THICK_FUR, CRUMB_MAGNET, PIGGY_BANK }
enum Consumable { FRESH_BREEZE, CALM, NEW_PAWS, CHEESE_BAIT }

const TRINKET_COLOR := Color("f5c542")
const CONSUMABLE_COLOR := Color("6fd6c8")
## Name, description and price of each trinket.
const TRINKETS := {
	Trinket.SPARE_PAWS: ["SPARE PAWS", "+2 discards every round.", 6],
	Trinket.LUCKY_TAIL: ["LUCKY TAIL", "Slots never roll BLOCKED.", 5],
	Trinket.THICK_FUR: ["THICK FUR", "The first trap each round breaks instead of catching the mouse.", 12],
	Trinket.CRUMB_MAGNET: ["CRUMB MAGNET", "Crumbs picked up on the board are worth 2.", 6],
	Trinket.PIGGY_BANK: ["PIGGY BANK", "Each win pays +1 crumb per 5 you hold (up to +5).", 7],
}
## Name, description and price of each consumable.
const CONSUMABLES := {
	Consumable.FRESH_BREEZE: ["FRESH BREEZE", "Reroll this turn's slot effects.", 3],
	Consumable.CALM: ["CALM", "Clear every slot effect this turn.", 3],
	Consumable.NEW_PAWS: ["NEW PAWS", "Swap your whole hand for new cards. Uses no discards.", 3],
	Consumable.CHEESE_BAIT: ["CHEESE BAIT", "Remove the trap nearest the mouse.", 4],
}
## Slot effects the shop can stamp onto a card. Only ones that work on a single card with no extra
## input: direction effects would just make it another direction card.
const STAMPS: Array[CardSlot.Effect] = [
	CardSlot.Effect.DOUBLE, CardSlot.Effect.LEAP, CardSlot.Effect.SLIDE, CardSlot.Effect.WRAP,
	CardSlot.Effect.RECYCLE,
]
const STAMP_PRICE := 6
## Consumables the player can hold at once.
const POUCH_SIZE := 3
