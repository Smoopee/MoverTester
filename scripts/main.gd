extends Control
## Game controller: deals hands, handles card placement, and plays locked-in turns.

const HAND_SIZE := 6
const SLOT_COUNT := 4
const MIN_CHEESE_DISTANCE := 8
## Chance that a slot gets an effect each turn.
const EFFECT_CHANCE := 0.5
const HINT := "Click a card to put it in the next slot, or drag it to a slot. Then Lock In."
const PLAYING := Color(1.15, 1.15, 0.8)
const PLAYED := Color(1, 1, 1, 0.45)
const FIZZLED := Color(1, 0.5, 0.5, 0.6)

@onready var board: Board = %Board
@onready var hud_label: Label = %HudLabel
@onready var slot_row: HBoxContainer = %SlotRow
@onready var effects_label: Label = %EffectsLabel
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
## Cards played from RECYCLE slots, returned to the next hand.
var recycled: Array[int] = []
## Direction of the last step this turn, for ECHO. -1 before the first one.
var last_dir := -1


func _ready() -> void:
	for i in SLOT_COUNT:
		var slot := CardSlot.new()
		slot.number = i + 1
		slot.card_dropped.connect(_on_card_dropped_on_slot.bind(slot))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		column.add_child(slot.header)
		column.add_child(slot)
		slot_row.add_child(column)
		slots.append(slot)
	hand_box.set_drag_forwarding(Callable(), _can_drop_on_hand, _drop_on_hand)
	lock_in_button.pressed.connect(lock_in)
	new_round_button.pressed.connect(new_round)
	var bug_report := BugReport.new()
	bug_report.get_state = _bug_report_state
	add_child(bug_report)
	new_round()


func new_round() -> void:
	_clear_cards()
	deck.reset()
	recycled.clear()
	var mouse := _random_cell()
	var cheese := _random_cell()
	while _distance(mouse, cheese) < MIN_CHEESE_DISTANCE:
		cheese = _random_cell()
	board.place(mouse, cheese)
	BugReport.note("New round: mouse %s, cheese %s" % [mouse, cheese])
	turn = 1
	win_panel.hide()
	start_turn()


func start_turn() -> void:
	var dirs: Array[int] = []
	dirs.append_array(recycled)
	dirs.append_array(deck.draw(HAND_SIZE - recycled.size()))
	recycled.clear()
	for dir in dirs:
		var card := Card.new()
		card.dir = dir as Card.Dir
		card.pressed.connect(_on_card_clicked.bind(card))
		card.card_dropped_on.connect(_on_card_dropped_on_card.bind(card))
		hand_box.add_child(card)
	BugReport.note("Turn %d: hand %s" % [turn, _dir_names(dirs)])
	_roll_effects()
	status_label.text = HINT
	_refresh_hud()


## Plays the slotted cards in order, then discards everything and deals a new hand.
func lock_in() -> void:
	if busy:
		return
	busy = true
	lock_in_button.disabled = true
	status_label.text = "Moving..."
	for card in _all_cards():
		card.disabled = true
	for slot in slots:
		slot.header.disabled = true

	BugReport.note("Lock in")
	last_dir = -1
	var order := _play_order()
	var reached := false
	var i := 0
	while i < order.size() and not reached:
		var slot := order[i]
		var card := slot.get_card()
		i += 1
		if card == null:
			continue
		card.modulate = PLAYING
		var partner_slot: CardSlot = order[i] if i < order.size() else null
		if slot.effect == CardSlot.Effect.DIAGONAL and partner_slot and partner_slot.get_card():
			var partner := partner_slot.get_card()
			i += 1
			partner.modulate = PLAYING
			var dir := slot.play_dir(card.dir)
			var partner_dir := partner_slot.play_dir(partner.dir)
			var offset: Vector2i = Card.OFFSETS[dir] + Card.OFFSETS[partner_dir]
			last_dir = partner_dir
			reached = await board.jump(offset, dir)
			BugReport.note("  Slot %d DIAGONAL %s + slot %d %s %s -> mouse %s" % [
				slot.number, Card.NAMES[card.dir], partner_slot.number,
				CardSlot.INFO[partner_slot.effect][0], Card.NAMES[partner.dir], board.mouse_cell])
			partner.modulate = PLAYED
		else:
			reached = await _play(slot, card)
			# Facing is the last direction moved, which differs from the card for WILD, GAMBLE, etc.
			BugReport.note("  Slot %d %s%s -> mouse %s" % [slot.number,
				" ".join(PackedStringArray([CardSlot.INFO[slot.effect][0], Card.NAMES[card.dir]])).strip_edges(),
				" (moved %s)" % Card.NAMES[board.facing] if board.facing != card.dir else "",
				board.mouse_cell])
		if card.modulate == PLAYING:
			card.modulate = PLAYED

	var played: Array[int] = []
	for card in _all_cards():
		var slot := card.get_parent() as CardSlot
		var effect: CardSlot.Effect = slot.effect if slot else CardSlot.Effect.NONE
		match effect:
			CardSlot.Effect.RECYCLE:
				recycled.append(card.dir)
			CardSlot.Effect.BURN:
				pass
			CardSlot.Effect.COPY:
				played.append_array([card.dir, card.dir])
			_:
				played.append(card.dir)
	_clear_cards()
	deck.discard(played)
	busy = false
	lock_in_button.disabled = false

	if reached:
		BugReport.note("Found the cheese on turn %d" % turn)
		win_label.text = "You found the cheese in %d turn%s!" % [turn, "" if turn == 1 else "s"]
		win_panel.show()
		_refresh_hud()
		return
	turn += 1
	start_turn()


## Moves the mouse for one card, following its slot's effect. Returns true if it reached the cheese.
func _play(slot: CardSlot, card: Card) -> bool:
	var dir := slot.play_dir(card.dir)
	var offset: Vector2i = Card.OFFSETS[dir]
	match slot.effect:
		CardSlot.Effect.DOUBLE:
			return await _steps(dir, 2)
		CardSlot.Effect.GAMBLE, CardSlot.Effect.BURN:
			return await _steps(dir, 3)
		CardSlot.Effect.LEAP:
			last_dir = dir
			return await board.jump(offset * 2, dir)
		CardSlot.Effect.SLIDE:
			last_dir = dir
			return await board.slide(dir)
		CardSlot.Effect.WRAP:
			last_dir = dir
			return await board.step(dir, true)
		CardSlot.Effect.ECHO:
			if last_dir != -1:
				if await _steps(last_dir as Card.Dir, 1):
					return true
		CardSlot.Effect.SNIFF:
			var now := _distance(board.mouse_cell, board.cheese_cell)
			if _distance(board.mouse_cell + offset, board.cheese_cell) >= now:
				card.modulate = FIZZLED
				BugReport.note("  Slot %d SNIFF %s fizzled" % [slot.number, Card.NAMES[dir]])
				status_label.text = "Sniff: %s isn't toward the cheese, so the mouse stays put." % Card.NAMES[dir]
				if board.animate:
					# Not process_always, so it waits while the F12 bug report has the game paused.
					await get_tree().create_timer(Board.STEP_TIME * 2, false).timeout
				return false
	return await _steps(dir, 1)


func _steps(dir: Card.Dir, count: int) -> bool:
	for i in count:
		last_dir = dir
		if await board.step(dir):
			return true
	return false


## Slots in the order they play: left to right, with LAST slots moved to the end.
func _play_order() -> Array[CardSlot]:
	var order: Array[CardSlot] = []
	var last: Array[CardSlot] = []
	for slot in slots:
		if slot.effect == CardSlot.Effect.LAST:
			last.append(slot)
		else:
			order.append(slot)
	order.append_array(last)
	return order


## Gives each slot a new effect for this turn. About half the slots stay plain.
func _roll_effects() -> void:
	var pool: Array = CardSlot.Effect.values()
	pool.erase(CardSlot.Effect.NONE)
	# Don't burn the deck down below a full hand.
	if deck.draw_pile.size() + deck.discard_pile.size() + _all_cards().size() <= HAND_SIZE:
		pool.erase(CardSlot.Effect.BURN)
	for slot in slots:
		var effect := CardSlot.Effect.NONE
		if randf() < EFFECT_CHANCE:
			effect = pool.pick_random()
			# At most one blocked slot per turn.
			if effect == CardSlot.Effect.BLOCKED:
				pool.erase(effect)
		slot.set_effect(effect)

	var lines := PackedStringArray()
	for slot in slots:
		if slot.effect != CardSlot.Effect.NONE:
			var info: Array = CardSlot.INFO[slot.effect]
			lines.append("Slot %d  %s: %s" % [slot.number, info[0], info[1]])
	effects_label.text = "No slot effects this turn." if lines.is_empty() else "\n".join(lines)
	BugReport.note("Effects: %s" % _slot_effects())


func _on_card_clicked(card: Card) -> void:
	if busy:
		return
	if card.get_parent() == hand_box:
		var slot := _first_empty_slot()
		if slot:
			card.reparent(slot, false)
			BugReport.note("%s -> slot %d" % [Card.NAMES[card.dir], slot.number])
	else:
		card.reparent(hand_box, false)
		BugReport.note("%s -> hand" % Card.NAMES[card.dir])


func _on_card_dropped_on_slot(card: Card, slot: CardSlot) -> void:
	_place_in_slot(card, slot)


func _on_card_dropped_on_card(card: Card, target: Card) -> void:
	var parent := target.get_parent()
	if parent is CardSlot:
		_place_in_slot(card, parent)
	else:
		_drop_on_hand(Vector2.ZERO, card)


## Puts a card in a slot. A card already there swaps to where the incoming card came from.
func _place_in_slot(card: Card, slot: CardSlot) -> void:
	if busy or card.get_parent() == slot or slot.effect == CardSlot.Effect.BLOCKED:
		return
	var existing := slot.get_card()
	if existing:
		existing.reparent(card.get_parent(), false)
	card.reparent(slot, false)
	BugReport.note("%s -> slot %d%s" % [Card.NAMES[card.dir], slot.number,
		" (swapped out %s)" % Card.NAMES[existing.dir] if existing else ""])


func _can_drop_on_hand(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and not busy


func _drop_on_hand(_at_position: Vector2, data: Variant) -> void:
	data.reparent(hand_box, false)
	BugReport.note("%s -> hand" % Card.NAMES[data.dir])


func _first_empty_slot() -> CardSlot:
	for slot in slots:
		if slot.get_card() == null and slot.effect != CardSlot.Effect.BLOCKED:
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


## Snapshot of the round for an F12 bug report.
func _bug_report_state() -> String:
	var lines := PackedStringArray()
	lines.append("Turn %d%s%s" % [turn, "  (moving)" if busy else "", "  (won)" if win_panel.visible else ""])
	lines.append("Mouse %s facing %s, cheese %s, distance %d" % [board.mouse_cell,
		Card.NAMES[board.facing], board.cheese_cell, _distance(board.mouse_cell, board.cheese_cell)])
	for slot in slots:
		var card := slot.get_card()
		var effect: String = CardSlot.INFO[slot.effect][0]
		if slot.effect == CardSlot.Effect.WILD:
			effect += " " + Card.NAMES[slot.wild_dir]
		lines.append("Slot %d  %-14s %s" % [slot.number, effect if effect else "-",
			Card.NAMES[card.dir] if card else "(empty)"])
	var hand: Array[int] = []
	for child in hand_box.get_children():
		if child is Card:
			hand.append(child.dir)
	lines.append("Hand: %s" % _dir_names(hand))
	lines.append("Draw pile (%d, top last): %s" % [deck.draw_pile.size(), _dir_names(deck.draw_pile)])
	lines.append("Discard (%d): %s" % [deck.discard_pile.size(), _dir_names(deck.discard_pile)])
	lines.append("Recycled: %s" % _dir_names(recycled))
	lines.append("Last dir: %s" % (Card.NAMES[last_dir] if last_dir != -1 else "-"))
	return "\n".join(lines)


func _slot_effects() -> String:
	var names := PackedStringArray()
	for slot in slots:
		var effect: String = CardSlot.INFO[slot.effect][0]
		names.append(effect if effect else "-")
	return " | ".join(names)


func _dir_names(dirs: Array[int]) -> String:
	var names := PackedStringArray()
	for dir in dirs:
		names.append(Card.NAMES[dir])
	return ", ".join(names) if not names.is_empty() else "(none)"


func _random_cell() -> Vector2i:
	return Vector2i(randi_range(0, Board.GRID - 1), randi_range(0, Board.GRID - 1))


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
