class_name Deck
extends RefCounted
## Draw pile and discard pile of direction cards (Card.Dir values).

const COPIES_PER_DIRECTION := 3

var draw_pile: Array[int] = []
var discard_pile: Array[int] = []


## Rebuilds the starting 12-card deck and shuffles it.
func reset() -> void:
	draw_pile.clear()
	discard_pile.clear()
	for dir in Card.Dir.values():
		for i in COPIES_PER_DIRECTION:
			draw_pile.append(dir)
	draw_pile.shuffle()


## Draws up to n cards, reshuffling the discard pile in when the draw pile runs out.
func draw(n: int) -> Array[int]:
	var hand: Array[int] = []
	for i in n:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			_reshuffle()
		hand.append(draw_pile.pop_back())
	return hand


func discard(cards: Array[int]) -> void:
	discard_pile.append_array(cards)


func _reshuffle() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	draw_pile.shuffle()
