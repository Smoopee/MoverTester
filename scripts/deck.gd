class_name Deck
extends RefCounted
## The run's cards, plus the draw and discard piles a round plays from.

const COPIES_PER_DIRECTION := 3

## Every card the player owns. Persists across a run's rounds; stamps bought in the shop live here.
var cards: Array[CardData] = []
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []


## Builds the starting 12-card deck and shuffles it into the draw pile.
func new_run() -> void:
	cards.clear()
	for dir in Card.Dir.values():
		for i in COPIES_PER_DIRECTION:
			cards.append(CardData.new(dir))
	new_round()


## Shuffles the whole deck into the draw pile. Cards burned or copied last round are back to normal.
func new_round() -> void:
	draw_pile = cards.duplicate()
	discard_pile.clear()
	draw_pile.shuffle()


## Draws up to n cards, reshuffling the discard pile in when the draw pile runs out.
func draw(n: int) -> Array[CardData]:
	var hand: Array[CardData] = []
	for i in n:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			_reshuffle()
		hand.append(draw_pile.pop_back())
	return hand


func discard(discarded: Array[CardData]) -> void:
	discard_pile.append_array(discarded)


func _reshuffle() -> void:
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	draw_pile.shuffle()
