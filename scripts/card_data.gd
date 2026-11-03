class_name CardData
extends RefCounted
## A card in the deck: its direction and any stamp and material bought for it in the shop. Piles hold
## these, and a Card node shows one.

var dir: Card.Dir = Card.Dir.UP
## Slot effect the card carries into every slot. It plays after the slot's own effect.
var stamp: CardSlot.Effect = CardSlot.Effect.NONE
## What the card is made of, which pays out each time it plays (main.gd _play_material).
var material: Items.CardMaterial = Items.CardMaterial.NONE:
	set(value):
		if value != material:
			copper_plays = 0
		material = value
## Times a COPPER card has played this run, which its points grow by (copper_points).
var copper_plays := 0
## Cells a STRIDE stamp moves, 1 to CardSlot.MAX_STRIDE. The player picks it on the card, and it
## stays picked.
var stride := 1


func _init(card_dir: Card.Dir = Card.Dir.UP, card_stamp: CardSlot.Effect = CardSlot.Effect.NONE,
		card_material: Items.CardMaterial = Items.CardMaterial.NONE) -> void:
	dir = card_dir
	stamp = card_stamp
	material = card_material


## Sets the STRIDE stamp to move one more cell, back to 1 after CardSlot.MAX_STRIDE.
func next_stride() -> void:
	stride = stride % CardSlot.MAX_STRIDE + 1


## Turns the card's arrow a quarter turn clockwise, for the SWIVEL stamp.
func swivel() -> void:
	var offset: Vector2i = Card.OFFSETS[dir]
	dir = Card.OFFSETS.find_key(Vector2i(-offset.y, offset.x)) as Card.Dir


## The cards sorted by direction, then stamp, then material, so a listing doesn't give away the draw
## order.
static func sorted(cards: Array[CardData]) -> Array[CardData]:
	var result := cards.duplicate()
	result.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.dir != b.dir:
			return a.dir < b.dir
		return a.stamp < b.stamp or (a.stamp == b.stamp and a.material < b.material))
	return result


func copy() -> CardData:
	var card := CardData.new(dir, stamp, material)
	card.stride = stride
	card.copper_plays = copper_plays
	return card


## Points a COPPER card adds the next time it plays.
func copper_points() -> int:
	return Score.COPPER_POINTS + copper_plays * Score.COPPER_GROWTH


## The material's description, with what a COPPER card is up to.
func material_text() -> String:
	var text: String = Items.MATERIALS[material][1]
	return text + " Next play: +%d." % copper_points() if material == Items.CardMaterial.COPPER else text


## Card name with its material and stamp, like "UP+LEAP", "GOLD UP" or "WOOD UP+STRIDE 3".
func label() -> String:
	var text: String = Card.NAMES[dir] + ("+" + stamp_name() if stamp != CardSlot.Effect.NONE else "")
	return "%s %s" % [Items.MATERIALS[material][0], text] if material != Items.CardMaterial.NONE else text


## The stamp's name, with the cells for STRIDE, like "STRIDE 3".
func stamp_name() -> String:
	var text: String = CardSlot.INFO[stamp][0]
	return "%s %d" % [text, stride] if stamp == CardSlot.Effect.STRIDE else text
