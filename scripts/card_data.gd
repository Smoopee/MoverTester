class_name CardData
extends RefCounted
## A card in the deck: its direction and any stamp bought for it in the shop. Piles hold these, and a
## Card node shows one.

var dir: Card.Dir = Card.Dir.UP
## Slot effect the card carries into every slot. It plays after the slot's own effect.
var stamp: CardSlot.Effect = CardSlot.Effect.NONE


func _init(card_dir: Card.Dir = Card.Dir.UP, card_stamp: CardSlot.Effect = CardSlot.Effect.NONE) -> void:
	dir = card_dir
	stamp = card_stamp


## The cards sorted by direction, then stamp, so a listing doesn't give away the draw order.
static func sorted(cards: Array[CardData]) -> Array[CardData]:
	var result := cards.duplicate()
	result.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.dir < b.dir or (a.dir == b.dir and a.stamp < b.stamp))
	return result


func copy() -> CardData:
	return CardData.new(dir, stamp)


## Card name with its stamp, like "UP+LEAP".
func label() -> String:
	return Card.NAMES[dir] + ("+" + CardSlot.INFO[stamp][0] if stamp != CardSlot.Effect.NONE else "")
