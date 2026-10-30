extends Control
## Game controller: deals hands, handles card placement, and plays locked-in turns.

const HAND_SIZE := 6
const SLOT_COUNT := 4
const MIN_CHEESE_DISTANCE := 8
const HINT := "Click a card to put it in the next slot, or drag it to a slot. Then Lock In."

@onready var board: Board = %Board
@onready var hud_label: Label = %HudLabel
@onready var slot_row: HBoxContainer = %SlotRow
@onready var hand_box: HBoxContainer = %Hand
@onready var lock_in_button: Button = %LockInButton
@onready var status_label: Label = %StatusLabel
@onready var win_panel: Control = %WinPanel
@onready var win_label: Label = %WinLabel
@onready var new_round_button: Button = %NewRoundButton

var deck := Deck.new()
var slots: Array[CardSlot] = []
var turn := 1
var busy := false


func _ready() -> void:
	for i in SLOT_COUNT:
		var slot := CardSlot.new()
		slot.number = i + 1
		slot.card_dropped.connect(_on_card_dropped_on_slot.bind(slot))
		slot_row.add_child(slot)
		slots.append(slot)
	hand_box.set_drag_forwarding(Callable(), _can_drop_on_hand, _drop_on_hand)
	lock_in_button.pressed.connect(lock_in)
	new_round_button.pressed.connect(new_round)
	new_round()


func new_round() -> void:
	_clear_cards()
	deck.reset()
	var mouse := _random_cell()
	var cheese := _random_cell()
	while _distance(mouse, cheese) < MIN_CHEESE_DISTANCE:
		cheese = _random_cell()
	board.place(mouse, cheese)
	turn = 1
	win_panel.hide()
	start_turn()


func start_turn() -> void:
	for dir in deck.draw(HAND_SIZE):
		var card := Card.new()
		card.dir = dir as Card.Dir
		card.pressed.connect(_on_card_clicked.bind(card))
		card.card_dropped_on.connect(_on_card_dropped_on_card.bind(card))
		hand_box.add_child(card)
	status_label.text = HINT
	_refresh_hud()


## Plays the slotted cards left to right, then discards everything and deals a new hand.
func lock_in() -> void:
	if busy:
		return
	busy = true
	lock_in_button.disabled = true
	status_label.text = "Moving..."
	for card in _all_cards():
		card.disabled = true

	var reached := false
	for slot in slots:
		var card := slot.get_card()
		if card == null:
			continue
		card.modulate = Color(1.15, 1.15, 0.8)
		reached = await board.step(card.dir)
		card.modulate = Color(1, 1, 1, 0.45)
		if reached:
			break

	var played: Array[int] = []
	for card in _all_cards():
		played.append(card.dir)
	_clear_cards()
	deck.discard(played)
	busy = false
	lock_in_button.disabled = false

	if reached:
		win_label.text = "You found the cheese in %d turn%s!" % [turn, "" if turn == 1 else "s"]
		win_panel.show()
		_refresh_hud()
		return
	turn += 1
	start_turn()


func _on_card_clicked(card: Card) -> void:
	if busy:
		return
	if card.get_parent() == hand_box:
		var slot := _first_empty_slot()
		if slot:
			card.reparent(slot, false)
	else:
		card.reparent(hand_box, false)


func _on_card_dropped_on_slot(card: Card, slot: CardSlot) -> void:
	_place_in_slot(card, slot)


func _on_card_dropped_on_card(card: Card, target: Card) -> void:
	var parent := target.get_parent()
	if parent is CardSlot:
		_place_in_slot(card, parent)
	else:
		card.reparent(hand_box, false)


## Puts a card in a slot. A card already there swaps to where the incoming card came from.
func _place_in_slot(card: Card, slot: CardSlot) -> void:
	if busy or card.get_parent() == slot:
		return
	var existing := slot.get_card()
	if existing:
		existing.reparent(card.get_parent(), false)
	card.reparent(slot, false)


func _can_drop_on_hand(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and not busy


func _drop_on_hand(_at_position: Vector2, data: Variant) -> void:
	data.reparent(hand_box, false)


func _first_empty_slot() -> CardSlot:
	for slot in slots:
		if slot.get_card() == null:
			return slot
	return null


func _all_cards() -> Array[Card]:
	var cards: Array[Card] = []
	for child in hand_box.get_children():
		if child is Card:
			cards.append(child)
	for slot in slots:
		var card := slot.get_card()
		if card:
			cards.append(card)
	return cards


func _clear_cards() -> void:
	for card in _all_cards():
		card.get_parent().remove_child(card)
		card.queue_free()


func _refresh_hud() -> void:
	hud_label.text = "Turn %d     Draw pile: %d     Discard: %d" % [
		turn, deck.draw_pile.size(), deck.discard_pile.size()]


func _random_cell() -> Vector2i:
	return Vector2i(randi_range(0, Board.GRID - 1), randi_range(0, Board.GRID - 1))


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
