class_name CardData
extends RefCounted
## A card in the deck: its direction and any stamp bought for it in the shop. Piles hold these, and a
## Card node shows one.

var dir: Card.Dir = Card.Dir.UP
## Slot effect the card carries into every slot. It plays after the slot's own effect.
var stamp: CardSlot.Effect = CardSlot.Effect.NONE
## Cells a STRIDE stamp moves, 1 to CardSlot.MAX_STRIDE. The player picks it on the card, and it
## stays picked.
var stride := 1


func _init(card_dir: Card.Dir = Card.Dir.UP, card_stamp: CardSlot.Effect = CardSlot.Effect.NONE) -> void:
	dir = card_dir
	stamp = card_stamp


## Sets the STRIDE stamp to move one more cell, back to 1 after CardSlot.MAX_STRIDE.
func next_stride() -> void:
	stride = stride % CardSlot.MAX_STRIDE + 1


## Turns the card's arrow a quarter turn clockwise, for the SWIVEL stamp.
func swivel() -> void:
	var offset: Vector2i = Card.OFFSETS[dir]
	dir = Card.OFFSETS.find_key(Vector2i(-offset.y, offset.x)) as Card.Dir


## The cards sorted by direction, then stamp, so a listing doesn't give away the draw order.
static func sorted(cards: Array[CardData]) -> Array[CardData]:
	var result := cards.duplicate()
	result.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.dir < b.dir or (a.dir == b.dir and a.stamp < b.stamp))
	return result


func copy() -> CardData:
	var card := CardData.new(dir, stamp)
	card.stride = stride
	return card


## Card name with its stamp, like "UP+LEAP" or "UP+STRIDE 3".
func label() -> String:
	return Card.NAMES[dir] + ("+" + stamp_name() if stamp != CardSlot.Effect.NONE else "")


## The stamp's name, with the cells for STRIDE, like "STRIDE 3".
func stamp_name() -> String:
	var text: String = CardSlot.INFO[stamp][0]
	return "%s %d" % [text, stride] if stamp == CardSlot.Effect.STRIDE else text
