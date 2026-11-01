class_name Main
extends Control
## Game controller: runs a run of rounds, deals hands, handles card placement, and plays locked-in turns.

## Chance that a round has a chest. Opening it gives a card slot or a card in the hand for the rest of
## the run (Run.slots, Run.hand_size), or CHEST_CRUMBS once both are at their most.
const CHEST_CHANCE := 0.4
## The chest is at least this many cells from the mouse.
const CHEST_MIN_DISTANCE := 4
const CHEST_CRUMBS := 5
## Width of the row of slots, and of the hand between the piles. Cards shrink so a row of them fits.
const ROW_WIDTH := 560.0
const HAND_WIDTH := 480.0
const SLOT_GAP := 8
## The cheese starts at least this many cells from the mouse, or the board's size less 2 if that's smaller.
const MIN_CHEESE_DISTANCE := 8
## Crumbs scattered on the board each round, worth 1 each.
const CRUMB_COUNT := 6
## Each run of wall is this many wall segments long, end to end along cell edges, turning a corner at
## each one with WALL_TURN_CHANCE.
const WALL_RUN_MIN := 2
const WALL_RUN_MAX := 5
const WALL_TURN_CHANCE := 0.35
## Each chasm is a line of this many cells, a cell wide, turning a corner at each cell with
## CHASM_TURN_CHANCE. A chasm that could do without a bridge still gets one with BRIDGE_CHANCE.
const CHASM_MIN := 3
const CHASM_MAX := 8
const CHASM_TURN_CHANCE := 0.25
const BRIDGE_CHANCE := 0.35
## Each conveyor belt is this many cells in a line, all running the same way.
const BELT_MIN := 2
const BELT_MAX := 4
## Cells a jump pad throws the mouse.
const PAD_MIN := 2
const PAD_MAX := 4
## A flamethrower is only placed pointing a way its jet reaches at least this many cells.
const FLAME_MIN := 2
## Runs of wall tried for each locked door or gate (see _place_locks). The one that makes the way to the
## cheese longest while shut is kept.
const LOCK_TRIES := 40
## Random cells tried for each key, plate and crate. The one closest to the way there is kept.
const ITEM_TRIES := 30
## A crate starts this many cells in a straight line from its plate.
const CRATE_MIN := 2
const CRATE_MAX := 3
const KEY_COLOR := Color("f2c94c")
## Stand-ins for no edge and no cell found.
const NO_EDGE := Vector3i(-1, -1, -1)
const NO_CELL := Vector2i(-1, -1)
## Cats start at least this many cells from the mouse and each other, or half the board's size if
## that's smaller.
const CAT_MIN_DISTANCE := 6
## Chance that a slot gets an effect each turn.
const EFFECT_CHANCE := 0.5
## Cards the player can swap for a new draw each round.
const DISCARDS_PER_ROUND := 5
const SPARE_PAWS_DISCARDS := 2
## Crumbs for reaching the cheese. Unused discards pay 1 each on top.
const WIN_CRUMBS := 5
const PIGGY_BANK_MAX := 5
## Extra crumbs each crumb picked up on the board pays with BOUNTIFUL HARVEST.
const HARVEST_CRUMBS := 2
const HINT := "Click a card to put it in the next slot, or drag it to a slot. Then Lock In."
## Color of the discard area under the hand, which lights up while a card is dragged.
const DISCARD_COLOR := Color("e07a5f")
const PLAYING := Color(1.15, 1.15, 0.8)
const PLAYED := Color(1, 1, 1, 0.45)
const FIZZLED := Color(1, 0.5, 0.5, 0.6)

@onready var board: Board = %Board
@onready var hud_label: Label = %HudLabel
@onready var boss_label: Label = %BossLabel
@onready var trinket_row: HFlowContainer = %TrinketRow
@onready var draw_pile_button: PileButton = %DrawPileButton
@onready var discard_button: PileButton = %DiscardButton
@onready var slot_row: HBoxContainer = %SlotRow
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
## Size of the cards in the slots, smaller when there are more slots, and in the hand, smaller in a
## bigger hand. A card resizes as it moves between them.
var slot_card_size := Card.CARD_SIZE
var hand_card_size := Card.CARD_SIZE
## Set from the F2 dev menu: draws on the board where the slotted cards would take the mouse.
var preview_on := false
## The hand size the cards were last sized for (see _build_slots).
var _built_hand_size := 0
var turn := 1
## The last turn of this round. Not reaching the cheese by the end of it ends the run.
var turn_limit := 1
var busy := false
var discards_left := DISCARDS_PER_ROUND
## Crumbs picked up on the board this round.
var round_crumbs := 0
## What each chest opened this round gave, for the win panel.
var chest_rewards := PackedStringArray()
## Shown in place of the hint at the start of the next turn, after a chest is opened.
var chest_note := ""
## Whether THICK FUR has already broken a trap this round.
var trap_survived := false
## Cards played from RECYCLE slots, returned to the next hand.
var recycled: Array[CardData] = []
## Direction of the last step this turn, for ECHO. -1 before the first one.
var last_dir := -1
## Set when the round's turns run out, which ends the run like being caught.
var out_of_time := false
## Set when the round ends, so dev menu edits to the board afterwards can't change the outcome.
var run_over := false
## For the balance sim: false turns boss rounds off, and a Boss.Kind here makes every round that boss.
var bosses_enabled := true
var force_boss := -1
## The hidden board the preview plays the turn on (_update_preview).
var _preview_board := Board.new()
var _preview_queued := false
## Cells kept clear while laying out a round: the lines crates get pushed along to their plates.
var _crate_lanes: Array[Vector2i] = []
## Shows the keys the mouse holds, next to the HUD, in rounds that have doors or keys.
var _key_label := Label.new()


## The game's theme: a dark, rounded panel behind every tooltip. It goes on the root window so it
## reaches the tooltip popups.
static func _make_theme() -> Theme:
	var theme := Theme.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("2a2420f2")
	panel.border_color = Color(1, 1, 1, 0.18)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 10
	theme.set_stylebox("panel", "TooltipPanel", panel)
	theme.set_color("font_color", "TooltipLabel", Color("f4ecd8"))
	return theme


func _ready() -> void:
	get_tree().root.theme = _make_theme()
	hand_box.set_drag_forwarding(Callable(), _can_drop_on_hand, _drop_on_hand)
	hand_box.child_entered_tree.connect(func(node: Node) -> void: _fit_card(node, hand_card_size))
	discard_card_button.set_drag_forwarding(Callable(), _can_drop_on_discard, _drop_on_discard)
	discard_button.set_drag_forwarding(Callable(), _can_drop_on_discard, _drop_on_discard)
	discard_card_button.pressed.connect(func() -> void:
		status_label.text = "Drag a card down here, or right-click it, to swap it for a new one.")
	_light_discard_area(false)
	lock_in_button.pressed.connect(lock_in)
	_preview_board.animate = false
	_preview_board.hide()
	add_child(_preview_board)
	win_panel_button.pressed.connect(_on_win_panel_button)
	# The piles are replaced each round, so look them up when the button is pressed.
	draw_pile_button.pressed.connect(func() -> void: _view_pile("Draw pile", run.deck.draw_pile))
	discard_button.pressed.connect(func() -> void: _view_pile("Discard", run.deck.discard_pile))
	board.crumb_collected.connect(_on_crumb_collected)
	board.chest_opened.connect(_open_chest)
	board.key_collected.connect(_on_key_collected)
	board.door_unlocked.connect(_on_door_unlocked)
	_key_label.add_theme_color_override("font_color", KEY_COLOR)
	_key_label.add_theme_font_size_override("font_size", hud_label.get_theme_font_size("font_size"))
	_key_label.size_flags_vertical = hud_label.size_flags_vertical
	hud_label.add_sibling(_key_label)
	add_child(pile_viewer)
	shop.next_round_pressed.connect(new_round)
	add_child(shop)
	var bug_report := BugReport.new()
	bug_report.get_state = _bug_report_state
	add_child(bug_report)
	# True in the editor and debug exports, false in release exports.
	if OS.is_debug_build():
		var dev_menu := DevMenu.new()
		dev_menu.game = self
		add_child(dev_menu)
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
	run.boss = -1
	if force_boss != -1:
		run.boss = force_boss
	elif bosses_enabled and Boss.is_boss_round(run.round_number):
		run.boss = run.next_boss
		run.next_boss = Boss.roll(run.boss)
	board.grid = Difficulty.grid(run.round_number)
	# Last round's gaps, doors and gates would get in the way of laying out this one.
	board.clear_layout()
	var mouse := _random_cell()
	var cheese := _random_cell()
	while _distance(mouse, cheese) < mini(MIN_CHEESE_DISTANCE, board.grid - 2):
		cheese = _random_cell()
	var traps := _place_traps(mouse, cheese)
	var walls := _place_walls(mouse, traps)
	_place_chasms(mouse, cheese, traps)
	_place_locks(mouse, cheese, traps)
	_place_hazards(mouse, cheese, traps)
	_place_floor(mouse, cheese, traps)
	var crumbs := _place_crumbs(mouse, cheese, traps)
	var cats := _place_cats(mouse, cheese, traps)
	board.place(mouse, cheese, traps, crumbs, cats, run.boss == Boss.Kind.ALLEY_KING, walls)
	board.chests = _place_chests(mouse, cheese, traps, crumbs)
	turn_limit = _turn_limit(_path_distance(mouse, cheese))
	BugReport.note("Round %d%s: %dx%d board, %d turns, mouse %s, cheese %s, traps %s, crumbs %s, chests %s" % [
		run.round_number, " (boss %s)" % Boss.INFO[run.boss][0] if run.boss != -1 else "", board.grid,
		board.grid, turn_limit, mouse, cheese, traps, crumbs, board.chests])
	BugReport.note("Walls: %s" % [walls.keys()])
	BugReport.note("Chasms %s, bridges %s" % [board.chasms, board.bridges])
	BugReport.note("Glue %s, conveyors %s, holes %s, floorboards %s, jump pads %s" % [board.glue,
		board.conveyors, board.holes, board.floorboards, board.pads])
	BugReport.note("Doors %s, keys %s, plates %s, gates %s, crates %s" % [board.doors.keys(), board.keys,
		board.plates, board.gates, board.crates])
	BugReport.note("Pylons and flamethrowers: %s" % _hazard_labels())
	BugReport.note("Cats: %s" % _cat_paths())
	turn = 1
	out_of_time = false
	run_over = false
	discards_left = DISCARDS_PER_ROUND
	if run.has(Items.Trinket.SPARE_PAWS):
		discards_left += SPARE_PAWS_DISCARDS
	round_crumbs = 0
	chest_rewards.clear()
	chest_note = ""
	trap_survived = false
	win_panel.hide()
	pile_viewer.hide()
	shop.hide()
	_refresh_trinkets()
	start_turn()


func start_turn() -> void:
	# A chest opened last turn can have added a slot or a card.
	_build_slots()
	var drawn: Array[CardData] = []
	drawn.append_array(recycled)
	drawn.append_array(run.deck.draw(_hand_size() - recycled.size()))
	recycled.clear()
	for data in drawn:
		hand_box.add_child(_make_card(data))
	BugReport.note("Turn %d: hand %s" % [turn, _card_names(drawn)])
	_roll_effects()
	status_label.text = HINT
	if run.boss != -1 and turn == 1:
		status_label.text = "Boss round! %s" % HINT
	elif turn == turn_limit and run.boss == Boss.Kind.KITCHEN_LIGHT:
		status_label.text = "Last turn before the kitchen light comes on!"
	elif turn == turn_limit:
		status_label.text = "Last turn! Reach the cheese now, or the run is over."
	if chest_note:
		status_label.text = chest_note if status_label.text == HINT else "%s %s" % [chest_note, status_label.text]
	chest_note = ""
	_refresh_hud()
	_refresh_pouch()
	refresh_preview()


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
	refresh_preview()
	var order := _play_order()
	var reached := await _play_cards(order)
	# Set when the mouse reaches the cheese or is caught in a trap.
	var ended := _round_over()
	# Glue holds the mouse: the cards left don't move it.
	if board.stuck and not ended:
		for slot in order.slice(reached):
			if slot.get_card():
				slot.get_card().modulate = FIZZLED
		status_label.text = "Stuck in glue! The rest of this turn's cards don't move the mouse."
		if board.animate:
			await get_tree().create_timer(Board.STEP_TIME * 2, false).timeout
	if board.squeeze:
		board.squeeze = false
		BugReport.note("Squeeze wore off")

	# Before the cats walk: the cheese stays off their paths, so no cat ends up on it.
	if not ended and run.boss == Boss.Kind.RUNAWAY_CHEESE:
		status_label.text = "The cheese runs..."
		await board.move_cheese(Boss.CHEESE_STEPS)
		BugReport.note("Cheese ran to %s" % board.cheese_cell)
	if not ended and not board.cats.is_empty():
		status_label.text = "The cats prowl..."
		await board.move_cats()
		BugReport.note("Cats walked: %s" % _cat_paths())
	if not ended and not board.hazards.is_empty():
		var going_off := PackedStringArray()
		for kind: Hazard.Kind in [Hazard.Kind.PYLON, Hazard.Kind.FLAMER]:
			if board.hazards.any(func(hazard: Hazard) -> bool: return hazard.kind == kind and hazard.is_armed()):
				going_off.append("The pylons crackle..." if kind == Hazard.Kind.PYLON else "The flamethrowers roar...")
		if going_off:
			status_label.text = " ".join(going_off)
		ended = await board.fire_hazards()
		BugReport.note("Pylons and flamethrowers: %s%s" % [_hazard_labels(),
			", the %s caught the mouse" % Hazard.NAMES[board.blasted_by.kind] if ended else ""])
	if not ended and turn >= turn_limit:
		out_of_time = true
		ended = true

	var played: Array[CardData] = []
	for card in _all_cards():
		var slot := card.get_parent() as CardSlot
		# The slot's effect and the card's stamp both apply. A burned card is gone, so nothing recycles it.
		var effects: Array[CardSlot.Effect] = []
		if slot:
			effects = [slot.effect, card.stamp]
		if CardSlot.Effect.BURN in effects:
			continue
		if CardSlot.Effect.RECYCLE in effects:
			recycled.append(card.data)
		else:
			played.append(card.data)
		if CardSlot.Effect.COPY in effects:
			played.append(card.data.copy())
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


## Plays the cards in the slots, in order, until the round ends or glue holds the mouse, and returns
## how many of the slots in order it got through. With preview, it also stops before a card that a
## GAMBLE slot plays, since that way is random.
func _play_cards(order: Array[CardSlot], preview := false) -> int:
	last_dir = -1
	board.stuck = false
	var ended := false
	var i := 0
	while i < order.size() and not ended and not board.stuck:
		var slot := order[i]
		var card := slot.get_card()
		if card == null:
			i += 1
			continue
		var partner_slot: CardSlot = order[i + 1] if i + 1 < order.size() else null
		var diagonal := slot.effect == CardSlot.Effect.DIAGONAL and partner_slot and partner_slot.get_card()
		if preview and (slot.effect == CardSlot.Effect.GAMBLE
				or diagonal and partner_slot.effect == CardSlot.Effect.GAMBLE):
			break
		i += 1
		card.modulate = PLAYING
		if diagonal:
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
	return i


## True when the mouse is on the cheese or caught: the round is over.
func _round_over() -> bool:
	return board.mouse_cell == board.cheese_cell or board.is_caught()


## Shows or hides the preview to match preview_on (dev menu), at the end of the frame, once however
## many times it's called in the frame.
func refresh_preview() -> void:
	if not _preview_queued:
		_preview_queued = true
		_update_preview.call_deferred()


## While preview_on is set, plays this turn's cards on a hidden copy of the board and draws
## where they take the mouse on the board. None of it counts: the crumbs and chests on the way stay
## put, and the cards, the status line, THICK FUR and the log are left as they were.
func _update_preview() -> void:
	_preview_queued = false
	if not preview_on or busy or win_panel.visible or shop.visible:
		board.show_preview([], Board.PreviewEnd.MOVED)
		return
	var real := board
	var status := status_label.text
	var fur_used := trap_survived
	var dir_before := last_dir
	var cards := _all_cards()
	var tints: Array[Color] = []
	for card in cards:
		tints.append(card.modulate)
	_preview_board.copy_from(real)
	_preview_board.trail = [real.mouse_cell]
	_preview_board.recording = true
	# The copy doesn't animate, so this plays out within the call and the real board is back at once.
	board = _preview_board
	BugReport.muted = true
	var order := _play_order()
	var reached := await _play_cards(order, true)
	var end := Board.PreviewEnd.MOVED
	# A pylon or flamethrower that goes off at the end of the turn catches a mouse that ends it in the blast.
	var blasted := board.in_blast(board.mouse_cell) and not board.invincible
	if board.is_caught():
		end = Board.PreviewEnd.CAUGHT
	elif board.mouse_cell == board.cheese_cell:
		end = Board.PreviewEnd.CHEESE
	elif board.stuck:
		end = Board.PreviewEnd.CAUGHT if blasted else Board.PreviewEnd.STUCK
	elif reached < order.size():
		end = Board.PreviewEnd.RANDOM
	elif blasted:
		end = Board.PreviewEnd.CAUGHT
	BugReport.muted = false
	board = real
	_preview_board.recording = false
	status_label.text = status
	trap_survived = fur_used
	last_dir = dir_before
	for i in cards.size():
		cards[i].modulate = tints[i]
	board.show_preview(_preview_board.trail.duplicate(), end)


## Shows how the round ended: crumbs earned and the way to the shop, or the end of the run.
func _end_round() -> void:
	run_over = board.is_caught() or out_of_time
	if out_of_time:
		BugReport.note("Out of time on turn %d of round %d" % [turn, run.round_number])
		win_label.text = "Click! The kitchen light came on." if run.boss == Boss.Kind.KITCHEN_LIGHT \
			else "Out of time! Someone put the cheese away."
	elif board.is_blasted():
		var pylon := board.blasted_by.kind == Hazard.Kind.PYLON
		BugReport.note("Caught by a %s at %s on turn %d of round %d" % [Hazard.NAMES[board.blasted_by.kind],
			board.mouse_cell, turn, run.round_number])
		win_label.text = "Zap! A shock pylon shocked the mouse." if pylon \
			else "Whoosh! The mouse was caught in a flamethrower's jet."
	elif board.is_caught():
		var by_cat := board.caught_by_cat()
		BugReport.note("Caught %s at %s on turn %d of round %d" % [
			"by a cat" if by_cat else "in a trap", board.mouse_cell, turn, run.round_number])
		win_label.text = "Pounce! A cat caught the mouse." if by_cat else "Snap! The mouse ran into a trap."
	if lost():
		var won := run.round_number - 1
		win_details.text = "Run over on round %d, after %d cheese%s found." % [
			run.round_number, won, "" if won == 1 else "s"]
		win_panel_button.text = "New Run"
	else:
		var reward := WIN_CRUMBS if run.boss == -1 else Boss.WIN_CRUMBS
		var lines := PackedStringArray(["%s  +%d" % ["Cheese" if run.boss == -1 else "Boss cheese", reward]])
		var earned := reward + discards_left
		if discards_left > 0:
			lines.append("Unused discards  +%d" % discards_left)
		if run.has(Items.Trinket.PIGGY_BANK):
			var interest := mini(floori(run.crumbs / 5.0), PIGGY_BANK_MAX)
			earned += interest
			lines.append("Piggy bank  +%d" % interest)
		if round_crumbs > 0:
			lines.append("Crumbs picked up  +%d" % round_crumbs)
		for chest in chest_rewards:
			lines.append("Chest: %s" % chest)
		run.crumbs += earned
		lines.append("You have %d crumbs." % run.crumbs)
		BugReport.note("Found the cheese on turn %d, earned %d (+%d picked up), %d crumbs" % [
			turn, earned, round_crumbs, run.crumbs])
		win_label.text = "You found the cheese in %d turn%s!" % [turn, "" if turn == 1 else "s"]
		if run.boss != -1:
			run.bosses_beaten += 1
			win_label.text = "You beat %s in %d turn%s!" % [Boss.INFO[run.boss][0], turn, "" if turn == 1 else "s"]
			lines.append("Take a free trinket in the shop.")
		lines.append("Next round: %s." % Difficulty.describe(run.round_number + 1))
		win_details.text = "\n".join(lines)
		win_panel_button.text = "Shop"
	status_label.text = ""
	win_panel.show()
	refresh_preview()
	_refresh_hud()
	_refresh_pouch()
	win_panel_button.grab_focus()


func _on_win_panel_button() -> void:
	if lost():
		new_run()
	else:
		win_panel.hide()
		shop.open(run, run.boss != -1)


## True when the round ended the run: the mouse was caught, or the turns ran out.
func lost() -> bool:
	return run_over


## If the mouse is on a trap and THICK FUR hasn't been used this round, breaks the trap and returns
## true so the turn carries on.
func _survive_trap() -> bool:
	if not board.is_trapped() or trap_survived or not run.has(Items.Trinket.THICK_FUR):
		return false
	trap_survived = true
	board.remove_trap(board.mouse_cell)
	BugReport.note("  THICK FUR broke the trap at %s" % board.mouse_cell)
	status_label.text = "Thick Fur! The trap broke. It won't save you again this round."
	return true


## Moves the mouse for one card: its slot's effect plays first, then the card's stamp. When both
## move the mouse (a BURN slot and a SLIDE stamp), it makes both moves, in that order. When neither
## does, it steps once. Returns true if the round is over.
func _play(slot: CardSlot, card: Card) -> bool:
	var dir := slot.play_dir(card.dir)
	var moved := false
	for effect: CardSlot.Effect in [slot.effect, card.stamp]:
		match effect:
			CardSlot.Effect.DOUBLE, CardSlot.Effect.GAMBLE, CardSlot.Effect.BURN, CardSlot.Effect.LEAP, \
					CardSlot.Effect.SLIDE, CardSlot.Effect.WRAP:
				moved = true
				if await _move(effect, dir):
					return true
				if board.stuck:
					return false
			CardSlot.Effect.ECHO:
				if last_dir != -1:
					if await _steps(last_dir as Card.Dir, 1):
						return true
					if board.stuck:
						return false
			CardSlot.Effect.SNIFF:
				var now := _path_distance(board.cheese_cell, board.mouse_cell)
				if _path_distance(board.cheese_cell, board.step_target(board.mouse_cell, dir)) >= now:
					card.modulate = FIZZLED
					BugReport.note("  Slot %d SNIFF %s fizzled" % [slot.number, Card.NAMES[dir]])
					status_label.text = "Sniff: %s isn't toward the cheese, so the mouse stays put." % Card.NAMES[dir]
					if board.animate:
						# Not process_always, so it waits while the F12 bug report has the game paused.
						await get_tree().create_timer(Board.STEP_TIME * 2, false).timeout
					return false
	if moved:
		return false
	return await _steps(dir, 1)


## Makes the move of an effect that changes the distance. Returns true if the round is over.
func _move(effect: CardSlot.Effect, dir: Card.Dir) -> bool:
	match effect:
		CardSlot.Effect.DOUBLE:
			return await _steps(dir, 2)
		CardSlot.Effect.GAMBLE, CardSlot.Effect.BURN:
			return await _steps(dir, 3)
		CardSlot.Effect.LEAP:
			last_dir = dir
			return await board.jump(Card.OFFSETS[dir] * 2, dir)
		CardSlot.Effect.SLIDE:
			last_dir = dir
			return await board.slide(dir)
		CardSlot.Effect.WRAP:
			last_dir = dir
			return await board.step(dir, true)
	return await _steps(dir, 1)


## Steps count cells. A trap THICK FUR breaks doesn't stop the remaining steps, but glue does.
func _steps(dir: Card.Dir, count: int) -> bool:
	for i in count:
		last_dir = dir
		if await board.step(dir) and not _survive_trap():
			return true
		if board.stuck:
			break
	return false


## Builds the run's slots (Run.slots), and sizes the cards so the slots, and the hand (Run.hand_size),
## each fit in a row. Does nothing when they're already built for them. The slots must be empty.
func _build_slots() -> void:
	var count := run.slots
	var hand := _hand_size()
	if count == slots.size() and hand == _built_hand_size:
		return
	_built_hand_size = hand
	for column in slot_row.get_children():
		slot_row.remove_child(column)
		column.queue_free()
	slots.clear()
	# A slot is its card plus 12 pixels of border. The hand is tighter: cards 4 pixels apart at least.
	slot_card_size = _card_size_for((ROW_WIDTH - (count - 1) * SLOT_GAP) / count - 12)
	hand_card_size = _card_size_for((HAND_WIDTH - (hand - 1) * 4) / hand)
	hand_box.custom_minimum_size.y = hand_card_size.y
	hand_box.add_theme_constant_override("separation",
		clampi(floori((HAND_WIDTH - hand * hand_card_size.x) / maxi(hand - 1, 1)), 4, SLOT_GAP))
	for card in _hand_cards():
		_fit_card(card, hand_card_size)
	for i in count:
		var slot := CardSlot.new()
		slot.number = i + 1
		slot.card_size = slot_card_size
		slot.child_entered_tree.connect(_fit_card.bind(slot_card_size))
		slot.card_dropped.connect(_on_card_dropped_on_slot.bind(slot))
		# A WILD slot's header turns its direction.
		slot.header.pressed.connect(refresh_preview)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		column.add_child(slot.header)
		column.add_child(slot)
		slot_row.add_child(column)
		slots.append(slot)


## A card's size for a width that fits its row: no bigger than Card.CARD_SIZE, in the same proportions.
func _card_size_for(width: float) -> Vector2:
	width = floorf(minf(width, Card.CARD_SIZE.x))
	return Vector2(width, roundf(width * Card.CARD_SIZE.y / Card.CARD_SIZE.x))


## Sizes a card that moved into the hand or a slot, which hold different sizes of card.
func _fit_card(node: Node, fit: Vector2) -> void:
	if node is Card:
		node.resize(fit)


## Cards dealt each turn.
func _hand_size() -> int:
	return run.hand_size


## Gives a card slot or a card in the hand for the rest of the run, picked at random, starting next
## turn. A slot is only on offer while there are fewer slots than cards, so it can be filled. Once
## neither can grow, pays CHEST_CRUMBS instead.
func _open_chest(cell: Vector2i) -> void:
	var rewards: Array[String] = []
	if run.slots < mini(run.hand_size, Run.MAX_SLOTS):
		rewards.append("slot")
	if run.hand_size < Run.MAX_HAND_SIZE:
		rewards.append("card")
	var reward: String = "crumbs" if rewards.is_empty() else rewards.pick_random()
	var text := ""
	match reward:
		"slot":
			run.slots += 1
			text = "+1 card slot (%d now)" % run.slots
			chest_note = "Chest! You have another card slot: %d now." % run.slots
		"card":
			run.hand_size += 1
			text = "+1 card in hand (%d now)" % run.hand_size
			chest_note = "Chest! You draw another card each turn: %d now." % run.hand_size
		"crumbs":
			run.crumbs += CHEST_CRUMBS
			round_crumbs += CHEST_CRUMBS
			text = "+%d crumbs" % CHEST_CRUMBS
			chest_note = "Chest! %d crumbs." % CHEST_CRUMBS
			_refresh_hud()
	chest_rewards.append(text)
	status_label.text = chest_note
	BugReport.note("  Opened a chest at %s: %s" % [cell, text])


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
	if run.deck.draw_pile.size() + run.deck.discard_pile.size() + _all_cards().size() <= _hand_size():
		pool.erase(CardSlot.Effect.BURN)
	# Set once an earlier slot plays before this one, so ECHO has a move to repeat.
	var after_a_move := false
	for slot in slots:
		var effect := CardSlot.Effect.NONE
		if randf() < EFFECT_CHANCE:
			var choices := pool.duplicate()
			if not after_a_move:
				choices.erase(CardSlot.Effect.ECHO)
			# LAST on the final slot changes nothing.
			if slot == slots[-1]:
				choices.erase(CardSlot.Effect.LAST)
			effect = choices.pick_random()
			# At most one blocked slot per turn.
			if effect == CardSlot.Effect.BLOCKED:
				pool.erase(effect)
		if effect != CardSlot.Effect.LAST and effect != CardSlot.Effect.BLOCKED:
			after_a_move = true
		_set_slot_effect(slot, effect)
	BugReport.note("Effects: %s" % _slot_effects())
	refresh_preview()


func _set_slot_effect(slot: CardSlot, effect: CardSlot.Effect) -> void:
	slot.set_effect(effect)
	# Rerolling with FRESH BREEZE can block a slot that already has a card.
	var card := slot.get_card()
	if card and effect == CardSlot.Effect.BLOCKED:
		card.reparent(hand_box, false)


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
			BugReport.note("Effects: %s" % _slot_effects())
			status_label.text = "Calm: no slot effects this turn."
		Items.Consumable.NEW_PAWS:
			if not _swap_hand():
				return
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
		Items.Consumable.SQUEEZE:
			if board.walls.is_empty() or board.squeeze:
				status_label.text = "There are no walls to squeeze through." if board.walls.is_empty() \
					else "The mouse is already squeezing through walls this turn."
				return
			board.squeeze = true
			status_label.text = "Squeeze: walls won't stop the mouse this turn."
	run.pouch.remove_at(index)
	BugReport.note("Used %s" % item_name)
	_refresh_hud()
	_refresh_pouch()
	refresh_preview()


## Swaps the cards in the hand for new draws. Returns false, changing nothing, when the piles can't
## refill the whole hand, so BURN can't make it shrink.
func _swap_hand() -> bool:
	var hand := _hand_cards()
	if hand.is_empty() or run.deck.draw_pile.size() + run.deck.discard_pile.size() < hand.size():
		status_label.text = "Not enough cards left to swap the whole hand."
		return false
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
	return true


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
	refresh_preview()


func _make_card(data: CardData) -> Card:
	var card := Card.new()
	card.data = data
	card.card_size = hand_card_size
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
	refresh_preview()


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
	refresh_preview()


func _can_drop_on_hand(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and not busy


func _can_drop_on_discard(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and not busy and discards_left > 0


func _drop_on_discard(_at_position: Vector2, data: Variant) -> void:
	discard_card(data)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		_light_discard_area(data is Card and not data.disabled and not busy and discards_left > 0)
	elif what == NOTIFICATION_DRAG_END:
		_light_discard_area(false)


## Styles the discard area under the hand, lit while a card that can be discarded is being dragged.
func _light_discard_area(lit: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(DISCARD_COLOR, 0.2 if lit else 0.06)
		style.border_color = Color(DISCARD_COLOR, 0.9 if lit else 0.3)
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		if state == "disabled":
			style.border_color.a = 0.12
		discard_card_button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		discard_card_button.add_theme_color_override(state, DISCARD_COLOR.lightened(0.5) if lit
				else Color(1, 1, 1, 0.6))


func _drop_on_hand(_at_position: Vector2, data: Variant) -> void:
	data.reparent(hand_box, false)
	BugReport.note("%s -> hand" % data.data.label())
	refresh_preview()


func _on_key_collected(cell: Vector2i) -> void:
	BugReport.note("  Picked up a key at %s (%d held)" % [cell, board.keys_held])
	status_label.text = "A key! Walk into a locked door to open it."
	_refresh_hud()


func _on_door_unlocked(_edge: Vector3i) -> void:
	status_label.text = "The key opened the door."
	_refresh_hud()


func _on_crumb_collected(cell: Vector2i) -> void:
	var worth := 1 + (HARVEST_CRUMBS if run.has(Items.Trinket.BOUNTIFUL_HARVEST) else 0)
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
	hud_label.text = "Round %d · Turn %d of %d · %d crumbs" % [run.round_number, turn, turn_limit, run.crumbs]
	_key_label.visible = board.keys_held > 0 or not board.keys.is_empty() or not board.doors.is_empty()
	_key_label.text = "· %d key%s" % [board.keys_held, "" if board.keys_held == 1 else "s"]
	boss_label.visible = run.boss != -1
	if run.boss != -1:
		boss_label.text = "BOSS  %s" % Boss.describe(run.boss)
	draw_pile_button.count = run.deck.draw_pile.size()
	discard_button.count = run.deck.discard_pile.size()
	discard_card_button.text = "Drag a card here to discard  ·  %d left" % discards_left if discards_left > 0 \
			else "No discards left this round"
	discard_card_button.disabled = busy or discards_left == 0


## Shows the run's trinkets as tags next to the pile buttons.
func _refresh_trinkets() -> void:
	board.magnet = run.has(Items.Trinket.CRUMB_MAGNET)
	for child in trinket_row.get_children():
		trinket_row.remove_child(child)
		child.queue_free()
	for trinket in run.trinkets:
		var info: Array = Items.TRINKETS[trinket]
		var tag := HBoxContainer.new()
		tag.tooltip_text = info[1]
		tag.mouse_filter = Control.MOUSE_FILTER_PASS
		tag.add_theme_constant_override("separation", 3)
		var icon := TextureRect.new()
		icon.texture = ItemIcon.trinket(trinket, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(icon)
		var label := Label.new()
		label.text = info[0]
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Items.TRINKET_COLOR)
		tag.add_child(label)
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
		button.icon = ItemIcon.consumable(run.pouch[i], 16)
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


# Dev menu: shortcuts the F2 DevMenu calls. The menu logs each one with a "DEV:" note.

## Redraws everything that shows the run: the HUD, pouch, trinkets and an open shop.
func refresh_ui() -> void:
	_refresh_hud()
	_refresh_pouch()
	_refresh_trinkets()
	if shop.visible:
		shop.refresh()
	refresh_preview()


## Starts this round over on a new board, as the given Boss.Kind, or as a normal round for -1. The
## round number and the next boss stay the same.
func restart_round(boss: int) -> void:
	if busy:
		return
	run.round_number -= 1
	var saved_force := force_boss
	var saved_enabled := bosses_enabled
	# With bosses off, -1 means a normal round even on a boss round number.
	force_boss = boss
	bosses_enabled = false
	new_round()
	force_boss = saved_force
	bosses_enabled = saved_enabled


## Ends the round as a win: the mouse jumps onto the cheese, then the usual payout and the shop.
func win_round() -> void:
	if busy or win_panel.visible or shop.visible:
		return
	_clear_cards()
	out_of_time = false
	board.mouse_cell = board.cheese_cell
	board.mouse_pos = Vector2(board.cheese_cell)
	_end_round()


## Ends the round with the mouse caught in a trap, which ends the run.
func lose_round() -> void:
	if busy or win_panel.visible or shop.visible:
		return
	_clear_cards()
	board.invincible = false
	if not board.is_caught():
		board.traps.append(board.mouse_cell)
		board.queue_redraw()
	_end_round()


func set_slot_effect(index: int, effect: CardSlot.Effect) -> void:
	if busy:
		return
	_set_slot_effect(slots[index], effect)
	BugReport.note("Effects: %s" % _slot_effects())
	refresh_preview()


func set_preview(on: bool) -> void:
	preview_on = on
	refresh_preview()


func reroll_effects() -> void:
	if not busy:
		_roll_effects()


## Sets the run's card slots and hand size, as chests would. Mid-round, the cards held go to the
## discard pile and a new hand is dealt; between rounds, they apply from the next round.
func set_slots_and_hand(slot_count: int, hand_size: int) -> void:
	if busy:
		return
	run.slots = clampi(slot_count, 1, Run.MAX_SLOTS)
	run.hand_size = clampi(hand_size, 1, Run.MAX_HAND_SIZE)
	if win_panel.visible or shop.visible:
		return
	var held: Array[CardData] = []
	for card in _all_cards():
		held.append(card.data)
	_clear_cards()
	run.deck.discard(held)
	start_turn()


## Adds a card to the hand. With keep, it joins the deck for the rest of the run too. Between rounds
## there's no hand, so only a kept card is added. Returns whether the card went into the hand.
func add_card(data: CardData, keep: bool) -> bool:
	if busy:
		return false
	if keep:
		run.deck.cards.append(data)
		# A stamp picker that's open was built from the old deck.
		shop.close_picker()
	if win_panel.visible or shop.visible:
		return false
	hand_box.add_child(_make_card(data))
	return true


## Swaps the hand for new cards without using a discard.
func redraw_hand() -> bool:
	return not busy and _swap_hand()


## Puts the deck back to the starting cards. Mid-round, it also deals a new hand and rerolls the slots.
func reset_deck() -> void:
	if busy:
		return
	run.deck.new_run()
	recycled.clear()
	# A stamp picker that's open holds the old cards, which would take the stamp and the crumbs.
	shop.close_picker()
	if not win_panel.visible and not shop.visible:
		_clear_cards()
		start_turn()


## Snapshot of the round for an F12 bug report.
func _bug_report_state() -> String:
	var lines := PackedStringArray()
	var outcome := ""
	if win_panel.visible:
		if out_of_time:
			outcome = "  (out of time)"
		elif board.is_blasted():
			outcome = "  (caught by a %s)" % Hazard.NAMES[board.blasted_by.kind]
		elif board.is_caught():
			outcome = "  (caught by a cat)" if board.caught_by_cat() else "  (caught in a trap)"
		else:
			outcome = "  (won)"
	elif shop.visible:
		outcome = "  (shopping)"
	lines.append("Round %d, turn %d of %d%s%s, %d discards left, %dx%d board" % [run.round_number, turn,
		turn_limit, "  (moving)" if busy else "", outcome, discards_left, board.grid, board.grid])
	lines.append("Boss: %s, next boss %s, %d beaten" % [Boss.INFO[run.boss][0] if run.boss != -1 else "-",
		Boss.INFO[run.next_boss][0], run.bosses_beaten])
	var trinket_names := PackedStringArray()
	for trinket in run.trinkets:
		trinket_names.append(Items.TRINKETS[trinket][0])
	var pouch_names := PackedStringArray()
	for item in run.pouch:
		pouch_names.append(Items.CONSUMABLES[item][0])
	lines.append("Crumbs %d (%d picked up this round), trinkets: %s, pouch: %s%s" % [run.crumbs,
		round_crumbs, ", ".join(trinket_names) if trinket_names else "-",
		", ".join(pouch_names) if pouch_names else "-", ", thick fur used" if trap_survived else ""])
	lines.append("Mouse %s facing %s, cheese %s, distance %d (%d by path)%s" % [board.mouse_cell,
		Card.NAMES[board.facing], board.cheese_cell, _distance(board.mouse_cell, board.cheese_cell),
		_path_distance(board.mouse_cell, board.cheese_cell), ", squeezing" if board.squeeze else ""])
	lines.append("Traps: %s" % [board.traps])
	lines.append("Walls (x, y, 0 right / 1 below): %s" % [board.walls.keys()])
	lines.append("Glue: %s%s" % [board.glue, ", mouse stuck" if board.stuck else ""])
	var belts := PackedStringArray()
	for cell: Vector2i in board.conveyors:
		belts.append("%s %s" % [cell, Card.NAMES[board.conveyors[cell]]])
	lines.append("Conveyors: %s" % ", ".join(belts))
	lines.append("Mouse holes (linked in pairs): %s" % [board.holes])
	lines.append("Floorboards: %s, broken: %s" % [board.floorboards, board.broken])
	lines.append("Chasms: %s, bridges: %s" % [board.chasms, board.bridges])
	var pads := PackedStringArray()
	for cell: Vector2i in board.pads:
		pads.append("%s -> %s" % [cell, cell + board.pads[cell]])
	lines.append("Jump pads: %s" % ", ".join(pads))
	lines.append("Locked doors (x, y, 0 right / 1 below): %s, keys on board: %s, keys held: %d" % [
		board.doors.keys(), board.keys, board.keys_held])
	var switches := PackedStringArray()
	for i in board.plates.size():
		switches.append("plate %s%s opens %s" % [board.plates[i], " (pressed)" if board.is_pressed(i) else "",
			board.gates.keys().filter(func(gate: Vector3i) -> bool: return board.gates[gate] == i)])
	lines.append("Switches: %s, crates: %s" % [", ".join(switches), board.crates])
	lines.append("Pylons and flamethrowers (turns left/period): %s" % _hazard_labels())
	lines.append("Crumbs on board: %s, chests: %s" % [board.crumbs, board.chests])
	lines.append("Slots %d, hand size %d, chests opened this round: %s%s" % [run.slots, run.hand_size,
		", ".join(chest_rewards) if chest_rewards else "-", ", preview on" if preview_on else ""])
	lines.append("Cats: %s" % _cat_paths())
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
	return Vector2i(randi_range(0, board.grid - 1), randi_range(0, board.grid - 1))


## Picks trap cells off the cheese and not next to the mouse's start. No two traps touch, even
## diagonally, so they can never wall off part of the board.
func _place_traps(mouse: Vector2i, cheese: Vector2i) -> Array[Vector2i]:
	var traps: Array[Vector2i] = []
	for attempt in 1000:
		if traps.size() == _trap_count():
			break
		var cell := _random_cell()
		if cell == cheese or _touching(cell, mouse):
			continue
		if traps.any(func(trap: Vector2i) -> bool: return _touching(cell, trap)):
			continue
		traps.append(cell)
	return traps


## Lays down Difficulty.walls() runs of wall, each a line of wall segments along cell edges that
## sometimes turns a corner. A run that would cut any cell off from the mouse (with the traps' help)
## is left out, so the cheese and every crumb can always be reached and no cat gets shut in.
func _place_walls(mouse: Vector2i, traps: Array[Vector2i]) -> Dictionary[Vector3i, bool]:
	# Built on the board so its pathfinding can check each run.
	board.walls = {}
	board.traps = traps
	var open_cells := board.grid * board.grid - traps.size()
	var runs := 0
	for attempt in 200:
		if runs == Difficulty.walls(run.round_number):
			break
		var added: Array[Vector3i] = []
		for wall in _wall_run():
			if not board.walls.has(wall):
				board.walls[wall] = true
				added.append(wall)
		if not added.is_empty() and board.distances_from(mouse).size() == open_cells:
			runs += 1
		else:
			for wall in added:
				board.walls.erase(wall)
	return board.walls


## A random run of wall: a walk along the grid lines between cells, from a corner inside the board,
## that ends early rather than run along the board's edge. Empty if that leaves it shorter than
## WALL_RUN_MIN.
func _wall_run() -> Array[Vector3i]:
	var walls: Array[Vector3i] = []
	# Points are cell corners: (x, y) is the top-left corner of cell (x, y).
	var point := Vector2i(randi_range(1, board.grid - 1), randi_range(1, board.grid - 1))
	var dir: Card.Dir = Card.Dir.values().pick_random()
	for i in randi_range(WALL_RUN_MIN, WALL_RUN_MAX):
		if i > 0 and randf() < WALL_TURN_CHANCE:
			var offset: Vector2i = Card.OFFSETS[dir]
			dir = Card.OFFSETS.find_key(Vector2i(offset.y, offset.x) * [1, -1].pick_random()) as Card.Dir
		var next: Vector2i = point + Card.OFFSETS[dir]
		var low := Vector2i(mini(point.x, next.x), mini(point.y, next.y))
		var horizontal := point.y == next.y
		# A horizontal edge is the top of the cell to its lower right, a vertical one its left.
		if horizontal and (low.y <= 0 or low.y >= board.grid or low.x < 0 or low.x >= board.grid):
			break
		if not horizontal and (low.x <= 0 or low.x >= board.grid or low.y < 0 or low.y >= board.grid):
			break
		walls.append(Vector3i(low.x, low.y - 1, 1) if horizontal else Vector3i(low.x - 1, low.y, 0))
		point = next
	if walls.size() < WALL_RUN_MIN:
		walls.clear()
	return walls


## Lays down Difficulty.chasms() chasms (see _chasm_run), off the mouse, the cheese and the traps. A
## chasm that would cut any cell off from the mouse gets a bridge across a straight stretch of it, if
## one is enough, and is left out otherwise. Any other chasm gets a bridge with BRIDGE_CHANCE.
func _place_chasms(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> void:
	var open_cells := board.grid * board.grid - traps.size()
	var count := 0
	for attempt in 200:
		if count == Difficulty.chasms(run.round_number):
			break
		var cells := _chasm_run(mouse, cheese, traps)
		if cells.is_empty():
			continue
		# A bridge goes where the chasm runs straight, so it has floor at both ends.
		var spans: Array[Vector2i] = []
		for i in range(1, cells.size() - 1):
			if cells[i] - cells[i - 1] == cells[i + 1] - cells[i]:
				spans.append(cells[i])
		spans.shuffle()
		var tries: Array[Vector2i] = spans.duplicate()
		if spans.is_empty() or randf() >= BRIDGE_CHANCE:
			tries.push_front(NO_CELL)
		for bridge in tries:
			var added := cells.filter(func(cell: Vector2i) -> bool: return cell != bridge)
			board.chasms.append_array(added)
			if board.distances_from(mouse).size() == open_cells - board.chasms.size():
				if bridge != NO_CELL:
					board.bridges.append(bridge)
				count += 1
				break
			for cell: Vector2i in added:
				board.chasms.erase(cell)


## A random chasm: a walk of CHASM_MIN to CHASM_MAX cells from a random one, sometimes turning a
## corner, that stops short of the board's edge, the mouse, the cheese, a trap or another chasm. It
## stays a cell wide: no cell in it touches another chasm cell (even one of its own) but the ones
## before and after it. Empty if that leaves it shorter than CHASM_MIN.
func _chasm_run(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var cell := _random_cell()
	var dir: Card.Dir = Card.Dir.values().pick_random()
	for i in randi_range(CHASM_MIN, CHASM_MAX):
		if i > 0:
			if randf() < CHASM_TURN_CHANCE:
				var offset: Vector2i = Card.OFFSETS[dir]
				dir = Card.OFFSETS.find_key(Vector2i(offset.y, offset.x) * [1, -1].pick_random()) as Card.Dir
			cell += Card.OFFSETS[dir]
		if not board._in_bounds(cell) or cell == mouse or cell == cheese or cell in traps:
			break
		var touches := false
		for offset: Vector2i in Card.OFFSETS.values():
			var next := cell + offset
			if next in board.chasms or next in board.bridges or next in cells and next != cells[-1]:
				touches = true
		if touches or cell in board.chasms or cell in board.bridges:
			break
		cells.append(cell)
	if cells.size() < CHASM_MIN:
		cells.clear()
	return cells


## Lays down the round's locked doors, each with a key, and its switches: a gate, the pressure plate
## that opens it and a crate to push onto the plate. Each door and gate sits in a run of wall (see
## _lock_run), placed so that while it's shut it cuts no cell off but makes the way to the cheese
## longer: opening it is a shortcut. Each key, and each plate with its crate, goes where it adds least
## to the way to its door or gate, out of ITEM_TRIES cells. A plate is never next to its gate, so the
## mouse needs the crate to keep the gate open. The crate starts in a straight line from the plate, and
## the cells it's pushed along, and the one the mouse pushes from, are kept clear (_crate_lanes).
func _place_locks(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> void:
	_crate_lanes.clear()
	var open_cells := board.grid * board.grid - traps.size() - board.chasms.size()
	var free := func(cell: Vector2i) -> bool:
		return board._in_bounds(cell) and cell != mouse and cell != cheese and cell not in traps \
			and not board.has_tile(cell) and not board.has_item(cell) and cell not in _crate_lanes
	for i in Difficulty.doors(run.round_number):
		var door := _lock_run(mouse, cheese, open_cells)
		if door == NO_EDGE:
			break
		board.doors[door] = true
		var from_mouse := board.distances_from(mouse)
		var sides := _edge_cells(door)
		var from_door := [board.distances_from(sides[0]), board.distances_from(sides[1])]
		var best := NO_CELL
		var best_cost := INF
		for attempt in ITEM_TRIES:
			var cell := _random_cell()
			if not free.call(cell) or _distance(cell, mouse) < 2:
				continue
			var cost: float = from_mouse.get(cell, INF) + mini(from_door[0].get(cell, 999), from_door[1].get(cell, 999))
			if cost < best_cost:
				best = cell
				best_cost = cost
		if best == NO_CELL:
			board.doors.erase(door)
		else:
			board.keys.append(best)

	for i in Difficulty.switches(run.round_number):
		var gate := _lock_run(mouse, cheese, open_cells)
		if gate == NO_EDGE:
			break
		var plate := board.plates.size()
		board.gates[gate] = plate
		var from_mouse := board.distances_from(mouse)
		var sides := _edge_cells(gate)
		var from_gate := [board.distances_from(sides[0]), board.distances_from(sides[1])]
		var best: Array[Vector2i] = []
		var best_cost := INF
		for attempt in ITEM_TRIES:
			var cell := _random_cell()
			if not free.call(cell) or sides.any(func(side: Vector2i) -> bool: return _distance(cell, side) < 2):
				continue
			var lane := _crate_lane(cell, free)
			if lane.is_empty():
				continue
			# Walk behind the crate, push it onto the plate, then go to the gate.
			var cost: float = from_mouse.get(lane[-1], INF) + lane.size() - 2 \
				+ mini(from_gate[0].get(cell, 999), from_gate[1].get(cell, 999))
			if cost < best_cost:
				best = lane
				best_cost = cost
		if best.is_empty():
			board.gates.erase(gate)
			continue
		board.plates.append(best[0])
		board.crates.append(best[-2])
		_crate_lanes.append_array(best.slice(1, -2))
		_crate_lanes.append(best[-1])


## Tries LOCK_TRIES runs of wall (see _wall_run) with a lock (a door or gate) in the middle, and lays
## the walls of the one that makes the way from the mouse to the cheese longest while the lock is shut,
## out of those that cut no cell off. Returns the lock's edge, which the caller makes a door or a gate,
## or NO_EDGE when no run fits.
func _lock_run(mouse: Vector2i, cheese: Vector2i, open_cells: int) -> Vector3i:
	var best: Array[Vector3i] = []
	var best_lock := NO_EDGE
	var best_gain := -1
	for attempt in LOCK_TRIES:
		var walls := _wall_run()
		if walls.is_empty() or walls.any(func(wall: Vector3i) -> bool:
				return board.walls.has(wall) or board.doors.has(wall) or board.gates.has(wall)):
			continue
		# In the middle of the run, so going round the end of the run takes longer.
		var lock: Vector3i = walls[randi_range(1, walls.size() - 2)] if walls.size() > 2 else walls.pick_random()
		for wall in walls:
			board.walls[wall] = true
		var shut := board.distances_from(mouse)
		board.walls.erase(lock)
		var open := board.distances_from(mouse)
		for wall in walls:
			board.walls.erase(wall)
		if shut.size() != open_cells:
			continue
		var gain: int = shut[cheese] - open[cheese]
		if gain > best_gain:
			best = walls
			best_lock = lock
			best_gain = gain
	for wall in best:
		if wall != best_lock:
			board.walls[wall] = true
	return best_lock


## A straight lane for pushing a crate onto the plate cell: the plate, the cells the crate is pushed
## along, the crate's cell, and last the cell the mouse pushes from, CRATE_MIN to CRATE_MAX pushes away
## in a random direction, with no wall, door or gate across it. The cells the crate is on or passes
## over must be free(cell), and the mouse's not a trap, cheese or item. Empty if no direction fits.
func _crate_lane(plate: Vector2i, free: Callable) -> Array[Vector2i]:
	var dirs: Array = Card.Dir.values()
	dirs.shuffle()
	for dir: Card.Dir in dirs:
		var offset: Vector2i = Card.OFFSETS[dir]
		var pushes := randi_range(CRATE_MIN, CRATE_MAX)
		var lane: Array[Vector2i] = [plate]
		for i in pushes + 1:
			lane.append(lane[-1] + offset)
		var behind := lane[-1]
		var fits := board._in_bounds(behind) and behind != board.cheese_cell and behind not in board.traps \
			and not board.is_blocked(behind) and not board.has_item(behind) and lane.slice(1, -1).all(free)
		for i in range(1, lane.size()):
			fits = fits and not board.is_barrier(lane[i - 1], lane[i])
		if fits:
			return lane
	return []


## The two cells either side of a cell edge (a key into Board.walls).
static func _edge_cells(edge: Vector3i) -> Array[Vector2i]:
	var cell := Vector2i(edge.x, edge.y)
	return [cell, cell + (Vector2i(1, 0) if edge.z == 0 else Vector2i(0, 1))]


## Lays down Difficulty.pylons() shock pylons and Difficulty.flamers() flamethrowers (see Hazard), off
## the mouse, the cheese, the traps, the chasms, the keys, plates, crates and crate lanes, and not
## touching each other. Nothing can move onto one, so each goes only where it cuts no cell off from the
## mouse. A flamethrower points a way its jet reaches at least FLAME_MIN cells. Each starts at a random
## point in its countdown, but not about to go off on a mouse that starts in its blast.
func _place_hazards(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> void:
	var open_cells := board.grid * board.grid - traps.size() - board.chasms.size()
	for kind: Hazard.Kind in [Hazard.Kind.PYLON, Hazard.Kind.FLAMER]:
		var count := Difficulty.pylons(run.round_number) if kind == Hazard.Kind.PYLON \
			else Difficulty.flamers(run.round_number)
		var placed := 0
		for attempt in 500:
			if placed == count:
				break
			var cell := _random_cell()
			if cell == mouse or cell == cheese or cell in traps or board.has_tile(cell) or board.has_item(cell) \
					or cell in _crate_lanes or board.hazards.any(func(other: Hazard) -> bool: return _touching(cell, other.cell)):
				continue
			var hazard := Hazard.new(kind, cell, Card.Dir.UP, randi_range(Hazard.PERIOD_MIN, Hazard.PERIOD_MAX))
			if kind == Hazard.Kind.FLAMER:
				var dirs: Array = Card.Dir.values()
				dirs.shuffle()
				for dir: Card.Dir in dirs:
					hazard.dir = dir
					if board.blast_cells(hazard).size() >= FLAME_MIN:
						break
				if board.blast_cells(hazard).size() < FLAME_MIN:
					continue
			board.hazards.append(hazard)
			if board.distances_from(mouse).size() != open_cells - board.hazards.size():
				board.hazards.pop_back()
				continue
			hazard.timer = randi_range(2 if mouse in board.blast_cells(hazard) else 1, hazard.period)
			placed += 1


## Lays down the round's glue pads, jump pads, mouse holes, conveyor belts and creaky floorboards, at
## most one on a cell and none on the mouse, the cheese, a trap, a chasm or bridge, a pylon or
## flamethrower, a key, plate or crate, or a crate's lane. Linked holes are at least half the board apart. A jump pad throws the mouse its whole way,
## with no wall in it, and not onto a trap. A belt runs in a straight line with no walls across it, and
## never carries the mouse off the board, into a wall or a chasm, or onto a trap. Floorboards only go where
## breaking all of them would still leave every cell reachable, so they can't shut the mouse off from
## the cheese.
func _place_floor(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> void:
	var number := run.round_number
	var bounds := Rect2i(0, 0, board.grid, board.grid)
	var free := func(cell: Vector2i) -> bool:
		return bounds.has_point(cell) and cell != mouse and cell != cheese and cell not in traps \
			and not board.has_tile(cell) and not board.has_item(cell) and cell not in _crate_lanes
	for attempt in 500:
		if board.pads.size() == Difficulty.pads(number):
			break
		var cell := _random_cell()
		var offset: Vector2i = Card.OFFSETS[Card.Dir.values().pick_random()] * randi_range(PAD_MIN, PAD_MAX)
		var landing := board.jump_landing(cell, offset)
		if free.call(cell) and landing == cell + offset and landing not in traps:
			board.pads[cell] = offset

	for attempt in 500:
		if board.glue.size() == Difficulty.glue(number):
			break
		var cell := _random_cell()
		if free.call(cell):
			board.glue.append(cell)

	for attempt in 500:
		if board.holes.size() == Difficulty.holes(number) * 2:
			break
		var cell := _random_cell()
		if free.call(cell) and (board.holes.size() % 2 == 0
				or _distance(cell, board.holes[-1]) >= floori(board.grid / 2.0)):
			board.holes.append(cell)
	if board.holes.size() % 2 == 1:
		board.holes.pop_back()

	var belts := 0
	for attempt in 500:
		if belts == Difficulty.belts(number):
			break
		var dir: Card.Dir = Card.Dir.values().pick_random()
		var offset: Vector2i = Card.OFFSETS[dir]
		var cells: Array[Vector2i] = [_random_cell()]
		for i in randi_range(BELT_MIN, BELT_MAX) - 1:
			cells.append(cells[-1] + offset)
		var end := cells[-1] + offset
		var fits := cells.all(free) and bounds.has_point(end) and end not in traps and not board.is_blocked(end)
		for cell in cells:
			fits = fits and not board.is_barrier(cell, cell + offset)
		if fits:
			for cell in cells:
				board.conveyors[cell] = dir
			belts += 1

	var open_cells := board.grid * board.grid - traps.size() - board.chasms.size() - board.hazards.size()
	for attempt in 500:
		if board.floorboards.size() == Difficulty.floorboards(number):
			break
		var cell := _random_cell()
		if not free.call(cell):
			continue
		# Check with every floorboard broken.
		board.broken.assign(board.floorboards + [cell])
		var reachable := board.distances_from(mouse).size()
		if reachable == open_cells - board.broken.size():
			board.floorboards.append(cell)
		board.broken.clear()


## Picks crumb cells off the mouse, the cheese, the traps, the floor tiles (see _place_floor), the
## keys, plates, crates and crate lanes (see _place_locks) and each other.
func _place_crumbs(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Array[Vector2i]:
	var crumbs: Array[Vector2i] = []
	for attempt in 1000:
		if crumbs.size() == CRUMB_COUNT:
			break
		var cell := _random_cell()
		if cell not in [mouse, cheese] and cell not in traps and cell not in crumbs and not board.has_tile(cell) \
				and not board.has_item(cell) and cell not in _crate_lanes:
			crumbs.append(cell)
	return crumbs


## With CHEST_CHANCE, picks a cell for a chest at least CHEST_MIN_DISTANCE from the mouse, and off the
## cheese, the traps, the floor tiles, the keys, plates, crates and crate lanes, and the crumbs.
func _place_chests(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i],
		crumbs: Array[Vector2i]) -> Array[Vector2i]:
	var chests: Array[Vector2i] = []
	if randf() >= CHEST_CHANCE:
		return chests
	var spacing := mini(CHEST_MIN_DISTANCE, board.grid - 2)
	for attempt in 1000:
		var cell := _random_cell()
		if _distance(cell, mouse) >= spacing and cell != cheese and cell not in traps \
				and cell not in crumbs and not board.has_tile(cell) and not board.has_item(cell) \
				and cell not in _crate_lanes:
			chests.append(cell)
			break
	return chests


## Picks cat cells off the cheese, the traps, the chasms, the pylons and flamethrowers and the crates,
## well away from the mouse and spread out from each other.
func _place_cats(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Array[Vector2i]:
	var cats: Array[Vector2i] = []
	var spacing := mini(CAT_MIN_DISTANCE, floori(board.grid / 2.0))
	for attempt in 1000:
		if cats.size() == _cat_count():
			break
		var cell := _random_cell()
		if _distance(cell, mouse) < spacing or cell == cheese or cell in traps or cell in board.crates \
				or board.is_blocked(cell):
			continue
		if cats.any(func(cat: Vector2i) -> bool: return _distance(cell, cat) < spacing):
			continue
		cats.append(cell)
	return cats


func _trap_count() -> int:
	return Difficulty.traps(run.round_number)


## This round's cats, plus the Alley King in its boss round.
func _cat_count() -> int:
	return Difficulty.cats(run.round_number) + (1 if run.boss == Boss.Kind.ALLEY_KING else 0)


## Turns to reach cheese distance cells away this round: fewer in KITCHEN LIGHT, more in RUNAWAY CHEESE.
func _turn_limit(distance: int) -> int:
	var limit := Difficulty.turn_limit(run.round_number, distance)
	match run.boss:
		Boss.Kind.KITCHEN_LIGHT:
			limit = maxi(limit - Boss.KITCHEN_LIGHT_TURNS_CUT, Boss.KITCHEN_LIGHT_MIN_TURNS)
		Boss.Kind.RUNAWAY_CHEESE:
			limit += Boss.RUNAWAY_CHEESE_EXTRA_TURNS
	return limit


## Steps from one cell to another around the walls and traps (through the walls while squeezing), or
## the straight distance when there's no way through.
func _path_distance(from: Vector2i, to: Vector2i) -> int:
	return board.distances_from(from, board.squeeze).get(to, _distance(from, to))


## Each pylon's and flamethrower's cell and countdown, for the bug report.
func _hazard_labels() -> String:
	var parts := PackedStringArray()
	for hazard in board.hazards:
		parts.append(hazard.label())
	return ", ".join(parts) if not parts.is_empty() else "(none)"


## Each cat's cell and the path it will walk, for the bug report.
func _cat_paths() -> String:
	var parts := PackedStringArray()
	for cat in board.cats:
		parts.append("%s -> %s" % [cat.cell, cat.path])
	return ", ".join(parts) if not parts.is_empty() else "(none)"


## True when the cells are the same or neighbors, including diagonally.
func _touching(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1


func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
