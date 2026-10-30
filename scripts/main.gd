extends Control
## Game controller: runs a run of rounds, deals hands, handles card placement, and plays locked-in turns.

const HAND_SIZE := 6
const SLOT_COUNT := 4
const MIN_CHEESE_DISTANCE := 8
const TRAP_COUNT := 8
## Crumbs scattered on the board each round, worth 1 each.
const CRUMB_COUNT := 6
## Chance that a slot gets an effect each turn.
const EFFECT_CHANCE := 0.5
## Cards the player can swap for a new draw each round.
const DISCARDS_PER_ROUND := 5
const SPARE_PAWS_DISCARDS := 2
## Crumbs for reaching the cheese. Unused discards pay 1 each on top.
const WIN_CRUMBS := 5
const PIGGY_BANK_MAX := 5
const HINT := "Click a card to put it in the next slot, or drag it to a slot. Then Lock In."
const PLAYING := Color(1.15, 1.15, 0.8)
const PLAYED := Color(1, 1, 1, 0.45)
const FIZZLED := Color(1, 0.5, 0.5, 0.6)

@onready var board: Board = %Board
@onready var hud_label: Label = %HudLabel
@onready var trinket_row: HFlowContainer = %TrinketRow
@onready var draw_pile_button: Button = %DrawPileButton
@onready var discard_button: Button = %DiscardButton
@onready var slot_row: HBoxContainer = %SlotRow
@onready var effects_label: Label = %EffectsLabel
@onready var hand_box: HBoxContainer = %Hand
@onready var pouch_row: HBoxContainer = %PouchRow
@onready var discard_card_button: Button = %DiscardCardButton
@onready var lock_in_button: Button = %LockInButton
@onready var status_label: Label = %StatusLabel
@onready var win_panel: Control = %WinPanel
@onready var win_label: Label = %WinLabel
@onready var win_details: Label = %WinDetails
@onready var win_panel_button: Button = %WinPanelButton

var run := Run.new()
var pile_viewer := PileViewer.new()
var shop := Shop.new()
var slots: Array[CardSlot] = []
var turn := 1
var busy := false
var discards_left := DISCARDS_PER_ROUND
## Crumbs picked up on the board this round.
var round_crumbs := 0
## Whether THICK FUR has already broken a trap this round.
var trap_survived := false
## Cards played from RECYCLE slots, returned to the next hand.
var recycled: Array[CardData] = []
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
	discard_card_button.set_drag_forwarding(Callable(), _can_drop_on_discard, _drop_on_discard)
	discard_card_button.pressed.connect(func() -> void:
		status_label.text = "Drag a card onto Discard, or right-click it, to swap it for a new one.")
	lock_in_button.pressed.connect(lock_in)
	win_panel_button.pressed.connect(_on_win_panel_button)
	# The piles are replaced each round, so look them up when the button is pressed.
	draw_pile_button.pressed.connect(func() -> void: _view_pile("Draw pile", run.deck.draw_pile))
	discard_button.pressed.connect(func() -> void: _view_pile("Discard", run.deck.discard_pile))
	board.crumb_collected.connect(_on_crumb_collected)
	add_child(pile_viewer)
	shop.next_round_pressed.connect(new_round)
	add_child(shop)
	var bug_report := BugReport.new()
	bug_report.get_state = _bug_report_state
	add_child(bug_report)
	new_run()


## Starts over with the starting deck, no crumbs and no items.
func new_run() -> void:
	run = Run.new()
	BugReport.note("New run")
	new_round()


func new_round() -> void:
	_clear_cards()
	run.round_number += 1
	run.deck.new_round()
	recycled.clear()
	var mouse := _random_cell()
	var cheese := _random_cell()
	while _distance(mouse, cheese) < MIN_CHEESE_DISTANCE:
		cheese = _random_cell()
	var traps := _place_traps(mouse, cheese)
	var crumbs := _place_crumbs(mouse, cheese, traps)
	board.place(mouse, cheese, traps, crumbs)
	BugReport.note("Round %d: mouse %s, cheese %s, traps %s, crumbs %s" % [
		run.round_number, mouse, cheese, traps, crumbs])
	turn = 1
	discards_left = DISCARDS_PER_ROUND
	if run.has(Items.Trinket.SPARE_PAWS):
		discards_left += SPARE_PAWS_DISCARDS
	round_crumbs = 0
	trap_survived = false
	win_panel.hide()
	pile_viewer.hide()
	shop.hide()
	_refresh_trinkets()
	start_turn()


func start_turn() -> void:
	var drawn: Array[CardData] = []
	drawn.append_array(recycled)
	drawn.append_array(run.deck.draw(HAND_SIZE - recycled.size()))
	recycled.clear()
	for data in drawn:
		hand_box.add_child(_make_card(data))
	BugReport.note("Turn %d: hand %s" % [turn, _card_names(drawn)])
	_roll_effects()
	status_label.text = HINT
	_refresh_hud()
	_refresh_pouch()


## Plays the slotted cards in order, then discards everything and deals a new hand.
func lock_in() -> void:
	# Lock In can still be reached with Tab under the win panel and the shop.
	if busy or win_panel.visible or shop.visible:
		return
	busy = true
	lock_in_button.disabled = true
	draw_pile_button.disabled = true
	discard_button.disabled = true
	discard_card_button.disabled = true
	status_label.text = "Moving..."
	for card in _all_cards():
		card.disabled = true
	for slot in slots:
		slot.header.disabled = true
	for button: Button in pouch_row.get_children():
		button.disabled = true

	BugReport.note("Lock in")
	last_dir = -1
	var order := _play_order()
	# Set when the mouse reaches the cheese or is caught in a trap.
	var ended := false
	var i := 0
	while i < order.size() and not ended:
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
			ended = await board.jump(offset, dir)
			BugReport.note("  Slot %d DIAGONAL %s + slot %d %s %s -> mouse %s" % [
				slot.number, card.data.label(), partner_slot.number,
				CardSlot.INFO[partner_slot.effect][0], partner.data.label(), board.mouse_cell])
			partner.modulate = PLAYED
		else:
			ended = await _play(slot, card)
			# Facing is the last direction moved, which differs from the card for WILD, GAMBLE, etc.
			BugReport.note("  Slot %d %s%s -> mouse %s" % [slot.number,
				" ".join(PackedStringArray([CardSlot.INFO[slot.effect][0], card.data.label()])).strip_edges(),
				" (moved %s)" % Card.NAMES[board.facing] if board.facing != card.dir else "",
				board.mouse_cell])
		if ended and _survive_trap():
			ended = false
		if card.modulate == PLAYING:
			card.modulate = PLAYED

	var played: Array[CardData] = []
	for card in _all_cards():
		var slot := card.get_parent() as CardSlot
		var effect: CardSlot.Effect = slot.effect_for(card) if slot else CardSlot.Effect.NONE
		match effect:
			CardSlot.Effect.RECYCLE:
				recycled.append(card.data)
			CardSlot.Effect.BURN:
				pass
			CardSlot.Effect.COPY:
				played.append_array([card.data, card.data.copy()])
			_:
				played.append(card.data)
	_clear_cards()
	run.deck.discard(played)
	busy = false
	lock_in_button.disabled = false
	draw_pile_button.disabled = false
	discard_button.disabled = false

	if ended:
		_end_round()
		return
	turn += 1
	start_turn()


## Shows how the round ended: crumbs earned and the way to the shop, or the end of the run.
func _end_round() -> void:
	if board.is_caught():
		BugReport.note("Caught in a trap at %s on turn %d of round %d" % [board.mouse_cell, turn, run.round_number])
		win_label.text = "Snap! The mouse ran into a trap."
		var won := run.round_number - 1
		win_details.text = "Run over on round %d, after %d cheese%s found." % [
			run.round_number, won, "" if won == 1 else "s"]
		win_panel_button.text = "New Run"
	else:
		var lines := PackedStringArray(["Cheese  +%d" % WIN_CRUMBS])
		var earned := WIN_CRUMBS + discards_left
		if discards_left > 0:
			lines.append("Unused discards  +%d" % discards_left)
		if run.has(Items.Trinket.PIGGY_BANK):
			var interest := mini(floori(run.crumbs / 5.0), PIGGY_BANK_MAX)
			earned += interest
			lines.append("Piggy bank  +%d" % interest)
		if round_crumbs > 0:
			lines.append("Crumbs picked up  +%d" % round_crumbs)
		run.crumbs += earned
		lines.append("You have %d crumbs." % run.crumbs)
		BugReport.note("Found the cheese on turn %d, earned %d (+%d picked up), %d crumbs" % [
			turn, earned, round_crumbs, run.crumbs])
		win_label.text = "You found the cheese in %d turn%s!" % [turn, "" if turn == 1 else "s"]
		win_details.text = "\n".join(lines)
		win_panel_button.text = "Shop"
	status_label.text = ""
	win_panel.show()
	_refresh_hud()
	_refresh_pouch()
	win_panel_button.grab_focus()


func _on_win_panel_button() -> void:
	if board.is_caught():
		new_run()
	else:
		win_panel.hide()
		shop.open(run)


## If the mouse is on a trap and THICK FUR hasn't been used this round, breaks the trap and returns
## true so the turn carries on.
func _survive_trap() -> bool:
	if not board.is_caught() or trap_survived or not run.has(Items.Trinket.THICK_FUR):
		return false
	trap_survived = true
	board.remove_trap(board.mouse_cell)
	BugReport.note("  THICK FUR broke the trap at %s" % board.mouse_cell)
	status_label.text = "Thick Fur! The trap broke. It won't save you again this round."
	return true


## Moves the mouse for one card, following its slot's effect, or the card's stamp in a plain slot.
## Returns true if the round is over.
func _play(slot: CardSlot, card: Card) -> bool:
	var dir := slot.play_dir(card.dir)
	var offset: Vector2i = Card.OFFSETS[dir]
	match slot.effect_for(card):
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


## Steps count cells. A trap THICK FUR breaks doesn't stop the remaining steps.
func _steps(dir: Card.Dir, count: int) -> bool:
	for i in count:
		last_dir = dir
		if await board.step(dir) and not _survive_trap():
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
	if run.has(Items.Trinket.LUCKY_TAIL):
		pool.erase(CardSlot.Effect.BLOCKED)
	# Don't burn the deck down below a full hand.
	if run.deck.draw_pile.size() + run.deck.discard_pile.size() + _all_cards().size() <= HAND_SIZE:
		pool.erase(CardSlot.Effect.BURN)
	for slot in slots:
		var effect := CardSlot.Effect.NONE
		if randf() < EFFECT_CHANCE:
			effect = pool.pick_random()
			# At most one blocked slot per turn.
			if effect == CardSlot.Effect.BLOCKED:
				pool.erase(effect)
		slot.set_effect(effect)
		# Rerolling with FRESH BREEZE can block a slot that already has a card.
		var card := slot.get_card()
		if card and effect == CardSlot.Effect.BLOCKED:
			card.reparent(hand_box, false)
	_refresh_effects_label()
	BugReport.note("Effects: %s" % _slot_effects())


func _refresh_effects_label() -> void:
	var lines := PackedStringArray()
	for slot in slots:
		if slot.effect != CardSlot.Effect.NONE:
			var info: Array = CardSlot.INFO[slot.effect]
			lines.append("Slot %d  %s: %s" % [slot.number, info[0], info[1]])
	effects_label.text = "No slot effects this turn." if lines.is_empty() else "\n".join(lines)


## Uses the consumable at index in the pouch.
func use_consumable(index: int) -> void:
	if busy or index >= run.pouch.size():
		return
	var item: Items.Consumable = run.pouch[index]
	var item_name: String = Items.CONSUMABLES[item][0]
	match item:
		Items.Consumable.FRESH_BREEZE:
			_roll_effects()
			status_label.text = "Fresh Breeze: new slot effects."
		Items.Consumable.CALM:
			for slot in slots:
				slot.set_effect(CardSlot.Effect.NONE)
			_refresh_effects_label()
			BugReport.note("Effects: %s" % _slot_effects())
			status_label.text = "Calm: no slot effects this turn."
		Items.Consumable.NEW_PAWS:
			var hand := _hand_cards()
			# Only when the piles can refill the whole hand, so BURN can't make it shrink.
			if hand.is_empty() or run.deck.draw_pile.size() + run.deck.discard_pile.size() < hand.size():
				status_label.text = "Not enough cards left to swap the whole hand."
				return
			# Draw before discarding so the old hand can't be reshuffled straight back in.
			var drawn := run.deck.draw(hand.size())
			var old: Array[CardData] = []
			for card in hand:
				old.append(card.data)
				hand_box.remove_child(card)
				card.queue_free()
			run.deck.discard(old)
			for data in drawn:
				hand_box.add_child(_make_card(data))
			BugReport.note("  Hand %s -> %s" % [_card_names(old), _card_names(drawn)])
			status_label.text = "New Paws: a fresh hand."
		Items.Consumable.CHEESE_BAIT:
			if board.traps.is_empty():
				status_label.text = "There are no traps left."
				return
			var nearest: Vector2i = board.traps[0]
			for trap in board.traps:
				if _distance(trap, board.mouse_cell) < _distance(nearest, board.mouse_cell):
					nearest = trap
			board.remove_trap(nearest)
			BugReport.note("  Removed trap at %s" % nearest)
			status_label.text = "Cheese Bait: the nearest trap is gone."
	run.pouch.remove_at(index)
	BugReport.note("Used %s" % item_name)
	_refresh_hud()
	_refresh_pouch()


## Swaps a card in the hand or a slot for a new draw, using up one of the round's discards.
## The new card goes to the hand, in the old card's place if it came from there.
func discard_card(card: Card) -> void:
	if busy or discards_left == 0:
		return
	# Draw before discarding so the card can't be reshuffled straight back into the hand.
	var drawn := run.deck.draw(1)
	if drawn.is_empty():
		status_label.text = "No cards left to draw."
		return
	discards_left -= 1
	run.deck.discard([card.data])
	var new_card := _make_card(drawn[0])
	hand_box.add_child(new_card)
	if card.get_parent() == hand_box:
		hand_box.move_child(new_card, card.get_index())
	card.get_parent().remove_child(card)
	card.queue_free()
	BugReport.note("Discarded %s, drew %s (%d discards left)" % [
		card.data.label(), new_card.data.label(), discards_left])
	status_label.text = "Discarded %s, drew %s." % [card.data.label(), new_card.data.label()]
	_refresh_hud()


func _make_card(data: CardData) -> Card:
	var card := Card.new()
	card.data = data
	card.pressed.connect(_on_card_clicked.bind(card))
	card.card_dropped_on.connect(_on_card_dropped_on_card.bind(card))
	card.discard_requested.connect(discard_card.bind(card))
	return card


func _on_card_clicked(card: Card) -> void:
	if busy:
		return
	if card.get_parent() == hand_box:
		var slot := _first_empty_slot()
		if slot:
			card.reparent(slot, false)
			BugReport.note("%s -> slot %d" % [card.data.label(), slot.number])
	else:
		card.reparent(hand_box, false)
		BugReport.note("%s -> hand" % card.data.label())


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
	BugReport.note("%s -> slot %d%s" % [card.data.label(), slot.number,
		" (swapped out %s)" % existing.data.label() if existing else ""])


func _can_drop_on_hand(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and not busy


func _can_drop_on_discard(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and not busy and discards_left > 0


func _drop_on_discard(_at_position: Vector2, data: Variant) -> void:
	discard_card(data)


func _drop_on_hand(_at_position: Vector2, data: Variant) -> void:
	data.reparent(hand_box, false)
	BugReport.note("%s -> hand" % data.data.label())


func _on_crumb_collected(cell: Vector2i) -> void:
	var worth := 2 if run.has(Items.Trinket.CRUMB_MAGNET) else 1
	run.crumbs += worth
	round_crumbs += worth
	BugReport.note("  Picked up a crumb at %s (+%d)" % [cell, worth])
	_refresh_hud()


func _first_empty_slot() -> CardSlot:
	for slot in slots:
		if slot.get_card() == null and slot.effect != CardSlot.Effect.BLOCKED:
			return slot
	return null


func _hand_cards() -> Array[Card]:
	var cards: Array[Card] = []
	for child in hand_box.get_children():
		if child is Card:
			cards.append(child)
	return cards


func _all_cards() -> Array[Card]:
	var cards := _hand_cards()
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
	hud_label.text = "Round %d · Turn %d · %d crumbs" % [run.round_number, turn, run.crumbs]
	draw_pile_button.text = "Draw pile: %d" % run.deck.draw_pile.size()
	discard_button.text = "Discard pile: %d" % run.deck.discard_pile.size()
	discard_card_button.text = "Discard (%d left)" % discards_left
	discard_card_button.disabled = busy or discards_left == 0


## Shows the run's trinkets as tags next to the title.
func _refresh_trinkets() -> void:
	for child in trinket_row.get_children():
		trinket_row.remove_child(child)
		child.queue_free()
	for trinket in run.trinkets:
		var info: Array = Items.TRINKETS[trinket]
		var tag := Label.new()
		tag.text = info[0]
		tag.tooltip_text = info[1]
		tag.mouse_filter = Control.MOUSE_FILTER_PASS
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", Items.TRINKET_COLOR)
		trinket_row.add_child(tag)


## Rebuilds the pouch's consumable buttons in the hand header.
func _refresh_pouch() -> void:
	for child in pouch_row.get_children():
		pouch_row.remove_child(child)
		child.queue_free()
	for i in run.pouch.size():
		var info: Array = Items.CONSUMABLES[run.pouch[i]]
		var button := Button.new()
		button.text = info[0]
		button.tooltip_text = "%s Click to use." % info[1]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = busy or win_panel.visible
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Items.CONSUMABLE_COLOR)
		button.pressed.connect(use_consumable.bind(i))
		pouch_row.add_child(button)


func _view_pile(title: String, cards: Array[CardData]) -> void:
	BugReport.note("Viewed %s" % title.to_lower())
	pile_viewer.show_pile(title, cards)


## Snapshot of the round for an F12 bug report.
func _bug_report_state() -> String:
	var lines := PackedStringArray()
	var outcome := ""
	if win_panel.visible:
		outcome = "  (caught)" if board.is_caught() else "  (won)"
	elif shop.visible:
		outcome = "  (shopping)"
	lines.append("Round %d, turn %d%s%s, %d discards left" % [run.round_number, turn,
		"  (moving)" if busy else "", outcome, discards_left])
	var trinket_names := PackedStringArray()
	for trinket in run.trinkets:
		trinket_names.append(Items.TRINKETS[trinket][0])
	var pouch_names := PackedStringArray()
	for item in run.pouch:
		pouch_names.append(Items.CONSUMABLES[item][0])
	lines.append("Crumbs %d (%d picked up this round), trinkets: %s, pouch: %s%s" % [run.crumbs,
		round_crumbs, ", ".join(trinket_names) if trinket_names else "-",
		", ".join(pouch_names) if pouch_names else "-", ", thick fur used" if trap_survived else ""])
	lines.append("Mouse %s facing %s, cheese %s, distance %d" % [board.mouse_cell,
		Card.NAMES[board.facing], board.cheese_cell, _distance(board.mouse_cell, board.cheese_cell)])
	lines.append("Traps: %s" % [board.traps])
	lines.append("Crumbs on board: %s" % [board.crumbs])
	for slot in slots:
		var card := slot.get_card()
		var effect: String = CardSlot.INFO[slot.effect][0]
		if slot.effect == CardSlot.Effect.WILD:
			effect += " " + Card.NAMES[slot.wild_dir]
		lines.append("Slot %d  %-14s %s" % [slot.number, effect if effect else "-",
			card.data.label() if card else "(empty)"])
	var hand: Array[CardData] = []
	for card in _hand_cards():
		hand.append(card.data)
	lines.append("Hand: %s" % _card_names(hand))
	lines.append("Deck (%d): %s" % [run.deck.cards.size(), _card_names(CardData.sorted(run.deck.cards))])
	lines.append("Draw pile (%d, top last): %s" % [run.deck.draw_pile.size(), _card_names(run.deck.draw_pile)])
	lines.append("Discard (%d): %s" % [run.deck.discard_pile.size(), _card_names(run.deck.discard_pile)])
	lines.append("Recycled: %s" % _card_names(recycled))
	lines.append("Last dir: %s" % (Card.NAMES[last_dir] if last_dir != -1 else "-"))
	return "\n".join(lines)


func _slot_effects() -> String:
	var names := PackedStringArray()
	for slot in slots:
		var effect: String = CardSlot.INFO[slot.effect][0]
		names.append(effect if effect else "-")
	return " | ".join(names)


func _card_names(cards: Array[CardData]) -> String:
	var names := PackedStringArray()
	for data in cards:
		names.append(data.label())
	return ", ".join(names) if not names.is_empty() else "(none)"


func _random_cell() -> Vector2i:
	return Vector2i(randi_range(0, Board.GRID - 1), randi_range(0, Board.GRID - 1))


## Picks trap cells off the cheese and not next to the mouse's start. No two traps touch, even
## diagonally, so they can never wall off part of the board.
func _place_traps(mouse: Vector2i, cheese: Vector2i) -> Array[Vector2i]:
	var traps: Array[Vector2i] = []
	for attempt in 1000:
		if traps.size() == TRAP_COUNT:
			break
		var cell := _random_cell()
		if cell == cheese or _touching(cell, mouse):
			continue
		if traps.any(func(trap: Vector2i) -> bool: return _touching(cell, trap)):
			continue
		traps.append(cell)
	return traps


## Picks crumb cells off the mouse, the cheese, the traps and each other.
func _place_crumbs(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Array[Vector2i]:
	var crumbs: Array[Vector2i] = []
	for attempt in 1000:
		if crumbs.size() == CRUMB_COUNT:
			break
		var cell := _random_cell()
		if cell not in [mouse, cheese] and cell not in traps and cell not in crumbs:
			crumbs.append(cell)
	return crumbs


## True when the cells are the same or neighbors, including diagonally.
func _touching(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
