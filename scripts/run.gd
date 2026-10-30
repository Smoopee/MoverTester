class_name Run
extends RefCounted
## Everything that carries from round to round until the mouse is caught: the deck, crumbs, trinkets
## and the pouch of consumables.

var deck := Deck.new()
var round_number := 0
var crumbs := 0
## Owned Items.Trinket values.
var trinkets: Array[int] = []
## Held Items.Consumable values, at most Items.POUCH_SIZE.
var pouch: Array[int] = []


func _init() -> void:
	deck.new_run()


func has(trinket: Items.Trinket) -> bool:
	return trinket in trinkets
