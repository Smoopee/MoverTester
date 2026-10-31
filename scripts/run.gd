class_name Run
extends RefCounted
## Everything that carries from round to round until the mouse is caught: the deck, crumbs, trinkets,
## the pouch of consumables, and the card slots and hand size that chests add to.

const START_SLOTS := 4
const MAX_SLOTS := 8
const START_HAND_SIZE := 6
const MAX_HAND_SIZE := 10

var deck := Deck.new()
## Card slots each turn.
var slots := START_SLOTS
## Cards dealt each turn.
var hand_size := START_HAND_SIZE
var round_number := 0
var crumbs := 0
## Owned Items.Trinket values.
var trinkets: Array[int] = []
## Held Items.Consumable values, at most Items.POUCH_SIZE.
var pouch: Array[int] = []
## This round's Boss.Kind, or -1 in a normal round.
var boss := -1
## The Boss.Kind of the next boss round, shown in the shop before it.
var next_boss: Boss.Kind = Boss.roll()
var bosses_beaten := 0


func _init() -> void:
	deck.new_run()


func has(trinket: Items.Trinket) -> bool:
	return trinket in trinkets
