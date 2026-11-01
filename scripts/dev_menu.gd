class_name DevMenu
extends CanvasLayer
## F2 developer menu: a drawer of cheats and tools for setting up a game state to test. It doesn't pause
## the game, so changes show on the board as they're made. Every change is logged with a "DEV:" note,
## so a bug report shows when the state was set up by hand. main.gd only adds it in debug builds.

enum Brush { OFF, MOUSE, CHEESE, TRAP, CRUMB, CAT, WALL, GLUE, CONVEYOR, HOLE, FLOORBOARD, CHEST,
	JUMP_PAD, DOOR, KEY, PLATE, GATE, CRATE }

const KEY := KEY_F2
const WIDTH := 380
const BRUSH_NAMES := ["Off", "Mouse", "Cheese", "Trap", "Crumb", "Cat", "Wall", "Glue", "Conveyor",
	"Mouse hole", "Floorboard", "Chest", "Jump pad", "Locked door", "Key", "Plate", "Gate", "Crate"]
## What clicking a cell does with each brush, for the hint under the dropdown.
const BRUSH_HINTS := {
	Brush.MOUSE: "moves the mouse there",
	Brush.CHEESE: "moves the cheese there",
	Brush.WALL: "adds or removes a wall on the side nearest the click",
	Brush.CONVEYOR: "adds a conveyor running toward the side nearest the click, or removes one running that way",
	Brush.HOLE: "adds or removes a mouse hole. Holes link in the order they were added: 1st with 2nd, 3rd with 4th",
	Brush.FLOORBOARD: "adds a floorboard, breaks one, or clears a gap",
	Brush.JUMP_PAD: "adds a jump pad aimed at the side nearest the click. Clicking that side again throws farther, up to 4, then removes it",
	Brush.DOOR: "adds or removes a locked door on the side nearest the click",
	Brush.PLATE: "adds a pressure plate, or removes one and its gates. Gates open from the last plate added",
	Brush.GATE: "adds or removes a gate on the side nearest the click, opened by the last plate added",
}
## Labels of the speed dropdown. The last one turns animation off.
const SPEEDS := ["1x", "2x", "4x", "Instant"]
const SPEED_SCALES := [1.0, 2.0, 4.0]
const HEADING_COLOR := Color(0.96, 0.77, 0.26)

## The game the menu works on. Set by main.gd before the menu is added.
var game: Main

var _brush := Brush.OFF
var _peeking := false

var _panel := PanelContainer.new()
var _tabs := TabContainer.new()
var _readout := Label.new()
var _feedback := Label.new()
var _seed := SpinBox.new()
var _next_boss := OptionButton.new()
var _invincible := CheckBox.new()
var _preview := CheckBox.new()
## Items.Trinket -> its CheckBox.
var _trinket_boxes := {}
var _slot_effects: Array[OptionButton] = []
var _card_dir := OptionButton.new()
var _card_stamp: OptionButton
var _peek := Label.new()


func _ready() -> void:
	layer = 90

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.17, 0.15)
	style.border_color = HEADING_COLOR
	style.border_width_left = 3
	style.content_margin_left = 16
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -WIDTH
	_panel.hide()
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "Dev tools"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	var hint := Label.new()
	hint.text = "F2 or Esc closes. Changes are logged for F12 bug reports."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_readout)

	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.focus_mode = Control.FOCUS_NONE
	vbox.add_child(_tabs)
	_build_run_tab(_add_tab("Run"))
	_build_items_tab(_add_tab("Items"))
	_build_cards_tab(_add_tab("Cards"))
	_build_board_tab(_add_tab("Board"))

	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size = Vector2(0, 36)
	_feedback.add_theme_color_override("font_color", HEADING_COLOR)
	_feedback.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_feedback)

	game.board.cell_clicked.connect(_on_cell_clicked)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY:
		_panel.visible = not _panel.visible
		_feedback.text = ""
	# An open pile viewer gets Esc first.
	elif _panel.visible and key.keycode == KEY_ESCAPE and not game.pile_viewer.visible:
		_panel.hide()
	else:
		return
	get_viewport().set_input_as_handled()


## Keeps the readout and the controls in step with the game, which changes them too (a new run, a
## turn rerolling the slots, ...).
func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	var run := game.run
	var board := game.board
	var distance := absi(board.mouse_cell.x - board.cheese_cell.x) + absi(board.mouse_cell.y - board.cheese_cell.y)
	_readout.text = "Round %d, turn %d of %d, boss %s, %d beaten\n%dx%d board, mouse %s, cheese %s, distance %d (%d by path), %d traps, %d walls, %d cats, %d doors, %d keys held, %d switches" % [
		run.round_number, game.turn, game.turn_limit, Boss.INFO[run.boss][0] if run.boss != -1 else "-",
		run.bosses_beaten, board.grid, board.grid, board.mouse_cell, board.cheese_cell, distance,
		game._path_distance(board.mouse_cell, board.cheese_cell), board.traps.size(), board.walls.size(),
		board.cats.size(), board.doors.size(), board.keys_held, board.plates.size()]
	if _next_boss.selected != run.next_boss:
		_next_boss.select(run.next_boss)
	_invincible.set_pressed_no_signal(board.invincible)
	_preview.set_pressed_no_signal(game.preview_on)
	for trinket: int in _trinket_boxes:
		(_trinket_boxes[trinket] as CheckBox).set_pressed_no_signal(run.has(trinket))
	for i in _slot_effects.size():
		_slot_effects[i].get_parent().visible = i < game.slots.size()
		if i < game.slots.size() and _slot_effects[i].selected != game.slots[i].effect:
			_slot_effects[i].select(game.slots[i].effect)
	if _peeking:
		var order := run.deck.draw_pile.duplicate()
		order.reverse()
		_peek.text = "Draw pile, next card first (%d): %s" % [order.size(), game._card_names(order)]


func _build_run_tab(box: VBoxContainer) -> void:
	_heading(box, "Run")
	var row := _row(box)
	_button(row, "New run", func() -> void:
		if _idle():
			game.new_run()
			_did("New run"))
	_seed.max_value = 999999999
	_seed.rounded = true
	_seed.tooltip_text = "Seed for the random numbers, so a run can be played again the same way."
	row.add_child(_seed)
	_button(row, "New run with seed", func() -> void:
		if _idle():
			seed(int(_seed.value))
			game.new_run()
			_did("New run with seed %d" % _seed.value))

	_heading(box, "Round")
	row = _row(box)
	_button(row, "Restart round", func() -> void:
		if _idle():
			game.restart_round(game.run.boss)
			_did("Restarted round %d" % game.run.round_number))
	_button(row, "Next round", func() -> void:
		if _idle():
			game.new_round()
			_did("Skipped to round %d" % game.run.round_number))
	_button(row, "Win round", func() -> void:
		if _in_round():
			game.win_round()
			_did("Won the round"))
	_button(row, "Lose round", func() -> void:
		if _in_round():
			game.lose_round()
			_did("Lost the round"))
	row = _row(box)
	_label(row, "Round number")
	_button(row, "-1", _add_round.bind(-1))
	_button(row, "+1", _add_round.bind(1))
	row = _row(box)
	_label(row, "Card slots")
	_button(row, "-1", _add_slots.bind(-1, 0))
	_button(row, "+1", _add_slots.bind(1, 0))
	_label(row, "Hand size")
	_button(row, "-1", _add_slots.bind(0, -1))
	_button(row, "+1", _add_slots.bind(0, 1))
	row = _row(box)
	_label(row, "Turn limit")
	_button(row, "-1", _add_turns.bind(-1))
	_button(row, "+1", _add_turns.bind(1))
	_button(row, "+10", _add_turns.bind(10))

	_heading(box, "Bosses")
	row = _row(box)
	for kind: Boss.Kind in Boss.Kind.values():
		_button(row, Boss.INFO[kind][0], _play_boss.bind(kind))
	_button(row, "No boss", _play_boss.bind(-1))
	row = _row(box)
	_label(row, "Next boss")
	for kind: Boss.Kind in Boss.Kind.values():
		_next_boss.add_item(Boss.INFO[kind][0], kind)
	_next_boss.focus_mode = Control.FOCUS_NONE
	_next_boss.item_selected.connect(func(index: int) -> void:
		game.run.next_boss = index as Boss.Kind
		game.refresh_ui()
		_did("Next boss: %s" % Boss.INFO[index][0]))
	row.add_child(_next_boss)
	row = _row(box)
	_label(row, "Bosses beaten")
	_button(row, "-1", _add_bosses_beaten.bind(-1))
	_button(row, "+1", _add_bosses_beaten.bind(1))

	_heading(box, "Shop")
	row = _row(box)
	_button(row, "Open shop", _open_shop.bind(false))
	_button(row, "Open boss shop", _open_shop.bind(true))

	_heading(box, "Cheats")
	row = _row(box)
	_label(row, "Speed")
	var speed := OptionButton.new()
	for label: String in SPEEDS:
		speed.add_item(label)
	speed.focus_mode = Control.FOCUS_NONE
	speed.item_selected.connect(_set_speed)
	row.add_child(speed)
	_invincible.text = "Invincible"
	_invincible.tooltip_text = "Traps and cats can't catch the mouse."
	_invincible.focus_mode = Control.FOCUS_NONE
	_invincible.toggled.connect(func(on: bool) -> void:
		game.board.invincible = on
		game.board.queue_redraw()
		_did("Invincible %s" % ("on" if on else "off")))
	row.add_child(_invincible)
	_preview.text = "Preview"
	_preview.tooltip_text = "Draws on the board where the cards in the slots would take the mouse, and keeps it up to date as you move them."
	_preview.focus_mode = Control.FOCUS_NONE
	_preview.toggled.connect(func(on: bool) -> void:
		game.set_preview(on)
		_did("Preview %s" % ("on" if on else "off")))
	row.add_child(_preview)
	row = _row(box)
	_button(row, "Copy game state", func() -> void:
		DisplayServer.clipboard_set(game._bug_report_state())
		_say("Copied the game state to the clipboard."))


func _build_items_tab(box: VBoxContainer) -> void:
	_heading(box, "Crumbs")
	var row := _row(box)
	_button(row, "+10", _add_crumbs.bind(10))
	_button(row, "+100", _add_crumbs.bind(100))
	_button(row, "Set to 0", _add_crumbs.bind(-1))

	_heading(box, "Discards")
	row = _row(box)
	_button(row, "+5", func() -> void:
		game.discards_left += 5
		game.refresh_ui()
		_did("Discards +5 (%d left)" % game.discards_left))
	_button(row, "Refill", func() -> void:
		game.discards_left = Main.DISCARDS_PER_ROUND
		if game.run.has(Items.Trinket.SPARE_PAWS):
			game.discards_left += Main.SPARE_PAWS_DISCARDS
		game.refresh_ui()
		_did("Discards refilled (%d left)" % game.discards_left))

	_heading(box, "Trinkets")
	for trinket: Items.Trinket in Items.Trinket.values():
		var info: Array = Items.TRINKETS[trinket]
		var check := CheckBox.new()
		check.text = info[0]
		check.tooltip_text = info[1]
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_color_override("font_color", Items.TRINKET_COLOR)
		check.toggled.connect(_set_trinket.bind(trinket))
		box.add_child(check)
		_trinket_boxes[trinket] = check

	_heading(box, "Consumables")
	row = _row(box)
	for item: Items.Consumable in Items.Consumable.values():
		var button := _button(row, "+ %s" % Items.CONSUMABLES[item][0], func() -> void:
			game.run.pouch.append(item)
			game.refresh_ui()
			_did("Added %s to the pouch" % Items.CONSUMABLES[item][0]))
		button.tooltip_text = Items.CONSUMABLES[item][1]
		button.add_theme_color_override("font_color", Items.CONSUMABLE_COLOR)
	_button(row, "Clear pouch", func() -> void:
		game.run.pouch.clear()
		game.refresh_ui()
		_did("Cleared the pouch"))


func _build_cards_tab(box: VBoxContainer) -> void:
	_heading(box, "Slot effects")
	# One row per slot there can be. _process hides the rows past this round's slots.
	for i in Run.MAX_SLOTS:
		var row := _row(box)
		_label(row, "Slot %d" % (i + 1))
		var dropdown := _effect_dropdown()
		dropdown.item_selected.connect(_set_slot_effect.bind(i))
		row.add_child(dropdown)
		_slot_effects.append(dropdown)
	var row := _row(box)
	_button(row, "Reroll", func() -> void:
		if _idle():
			game.reroll_effects()
			_did("Rerolled slot effects"))
	_button(row, "Clear all", func() -> void:
		if _idle():
			for i in game.slots.size():
				game.set_slot_effect(i, CardSlot.Effect.NONE)
			_did("Cleared slot effects"))

	_heading(box, "New card")
	row = _row(box)
	for dir: Card.Dir in Card.Dir.values():
		_card_dir.add_item(Card.NAMES[dir], dir)
	_card_dir.focus_mode = Control.FOCUS_NONE
	row.add_child(_card_dir)
	_card_stamp = _effect_dropdown()
	_card_stamp.tooltip_text = "Stamp. Any effect, including ones the shop doesn't sell."
	row.add_child(_card_stamp)
	row = _row(box)
	_button(row, "Add to hand", _add_card.bind(false)).tooltip_text = "Only for this round."
	_button(row, "Add to deck", _add_card.bind(true)).tooltip_text = \
		"For the rest of the run. Mid-round it goes into the hand too."

	_heading(box, "Deck")
	row = _row(box)
	_button(row, "Redraw hand", func() -> void:
		if not _idle():
			return
		if game.redraw_hand():
			_did("Redrew the hand")
		else:
			_say("Not enough cards left in the piles to swap the whole hand."))
	_button(row, "Reset deck", func() -> void:
		if _idle():
			game.reset_deck()
			_did("Reset the deck to the starting cards"))
	_button(row, "Peek draw pile", func() -> void:
		_peeking = not _peeking
		_peek.visible = _peeking
		if _peeking:
			BugReport.note("DEV: Peeked at the draw pile"))
	_peek.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_peek.add_theme_font_size_override("font_size", 13)
	_peek.hide()
	box.add_child(_peek)


func _build_board_tab(box: VBoxContainer) -> void:
	_heading(box, "Brush")
	var row := _row(box)
	var brush := OptionButton.new()
	for label: String in BRUSH_NAMES:
		brush.add_item(label)
	brush.focus_mode = Control.FOCUS_NONE
	brush.item_selected.connect(func(index: int) -> void:
		_brush = index as Brush
		_say("" if _brush == Brush.OFF else "Click a cell on the board: %s." % [
			BRUSH_HINTS.get(_brush, "adds or removes a %s" % BRUSH_NAMES[_brush].to_lower())]))
	row.add_child(brush)
	row = _row(box)
	_label(row, "Keys held")
	_button(row, "+1", _add_keys.bind(1))
	_button(row, "-1", _add_keys.bind(-1))
	var hint := Label.new()
	hint.text = "Cats plan new paths after each edit."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)

	_heading(box, "Clear")
	row = _row(box)
	_button(row, "Traps", func() -> void:
		if _idle():
			game.board.traps.clear()
			game.board.plan_cats()
			_did("Cleared the traps"))
	_button(row, "Walls", func() -> void:
		if _idle():
			game.board.walls.clear()
			game.board.plan_cats()
			_did("Cleared the walls"))
	_button(row, "Floor", func() -> void:
		if _idle():
			var board := game.board
			for cell in board.glue + board.conveyors.keys() + board.holes + board.floorboards + board.broken \
					+ board.pads.keys():
				board.clear_tile(cell)
			board.stuck = false
			_did("Cleared the glue, conveyors, mouse holes, floorboards and jump pads")).tooltip_text = \
		"Glue, conveyors, mouse holes, floorboards, gaps and jump pads."
	_button(row, "Doors & keys", func() -> void:
		if _idle():
			game.board.doors.clear()
			game.board.keys.clear()
			game.board.keys_held = 0
			game.board.plan_cats()
			game.refresh_ui()
			_did("Cleared the locked doors and keys")).tooltip_text = "Locked doors, keys on the board and keys held."
	_button(row, "Switches", func() -> void:
		if _idle():
			game.board.plates.clear()
			game.board.gates.clear()
			game.board.crates.clear()
			game.board.plan_cats()
			_did("Cleared the plates, gates and crates")).tooltip_text = "Pressure plates, gates and crates."
	_button(row, "Crumbs", func() -> void:
		if _idle():
			game.board.crumbs.clear()
			game.board.queue_redraw()
			_did("Cleared the crumbs"))
	_button(row, "Chests", func() -> void:
		if _idle():
			game.board.chests.clear()
			game.board.queue_redraw()
			_did("Cleared the chests"))
	_button(row, "Cats", func() -> void:
		if _idle():
			game.board.cats.clear()
			game.board.queue_redraw()
			_did("Cleared the cats"))
	_button(row, "Replan cats", func() -> void:
		if _idle():
			game.board.plan_cats()
			_did("Cats: %s" % game._cat_paths()))


## Edits the board with the brush.
func _on_cell_clicked(cell: Vector2i, side: Card.Dir) -> void:
	if not _panel.visible or _brush == Brush.OFF or not _idle():
		return
	var board := game.board
	match _brush:
		Brush.WALL, Brush.DOOR, Brush.GATE:
			var other: Vector2i = cell + Card.OFFSETS[side]
			# The board's edge is already a wall.
			if not board._in_bounds(other):
				return
			if _brush == Brush.GATE and board.plates.is_empty():
				_say("Add a plate first: a gate is opened by the last plate added.")
				return
			var edge := Board.wall_between(cell, other)
			var kinds := {Brush.WALL: board.walls, Brush.DOOR: board.doors, Brush.GATE: board.gates}
			var had: bool = (kinds[_brush] as Dictionary).has(edge)
			board.clear_edge(cell, other)
			if not had:
				kinds[_brush][edge] = true if _brush != Brush.GATE else board.plates.size() - 1
			board.plan_cats()
			_did("%s brush: %s the %s side of %s" % [BRUSH_NAMES[_brush], "removed from" if had else "added on",
				Card.NAMES[side], cell])
			return
		Brush.GLUE:
			var had := cell in board.glue
			board.clear_tile(cell)
			if not had:
				board.glue.append(cell)
		Brush.CONVEYOR:
			var had: bool = board.conveyors.get(cell, -1) == side
			board.clear_tile(cell)
			if not had:
				board.conveyors[cell] = side
		Brush.HOLE:
			var had := cell in board.holes
			board.clear_tile(cell)
			if not had:
				board.holes.append(cell)
		Brush.FLOORBOARD:
			var was_board := cell in board.floorboards
			var was_gap := cell in board.broken
			board.clear_tile(cell)
			if was_board:
				board.broken.append(cell)
			elif not was_gap:
				board.floorboards.append(cell)
		Brush.MOUSE:
			board.mouse_cell = cell
			board.mouse_pos = Vector2(cell)
		Brush.CHEESE:
			board.cheese_cell = cell
			board.cheese_pos = Vector2(cell)
		Brush.TRAP:
			_toggle(board.traps, cell)
		Brush.CRUMB:
			_toggle(board.crumbs, cell)
		Brush.CHEST:
			_toggle(board.chests, cell)
		Brush.JUMP_PAD:
			var offset: Vector2i = Card.OFFSETS[side]
			var had: Vector2i = board.pads.get(cell, Vector2i.ZERO)
			board.clear_tile(cell)
			var distance := 2 if had.sign() != offset else absi(had.x + had.y) + 1
			if distance <= Main.PAD_MAX:
				board.pads[cell] = offset * distance
		Brush.KEY:
			_toggle(board.keys, cell)
		Brush.CRATE:
			_toggle(board.crates, cell)
		Brush.PLATE:
			var index := board.plates.find(cell)
			if index != -1:
				board.remove_plate(index)
			elif board.plates.size() == Board.SWITCH_COLORS.size():
				_say("There are only %d switch colors: remove a plate first." % Board.SWITCH_COLORS.size())
				return
			else:
				board.plates.append(cell)
		Brush.CAT:
			var found := board.cats.filter(func(cat: Cat) -> bool: return cat.cell == cell)
			if found.is_empty():
				board.cats.append(Cat.new(cell))
			else:
				board.cats.erase(found[0])
	board.plan_cats()
	_did("%s brush at %s" % [BRUSH_NAMES[_brush], cell])


func _toggle(cells: Array[Vector2i], cell: Vector2i) -> void:
	if cell in cells:
		cells.erase(cell)
	else:
		cells.append(cell)


func _play_boss(kind: int) -> void:
	if _idle():
		game.restart_round(kind)
		_did("Round %d as %s" % [game.run.round_number, Boss.INFO[kind][0] if kind != -1 else "a normal round"])


func _add_round(by: int) -> void:
	game.run.round_number = maxi(game.run.round_number + by, 1)
	game.refresh_ui()
	_did("Round number %d (Restart round for its board: %s)" % [game.run.round_number,
		Difficulty.describe(game.run.round_number)])


## Changes the run's card slots and hand size, as a chest does, and deals a new hand mid-round.
func _add_slots(slots_by: int, hand_by: int) -> void:
	if _idle():
		game.set_slots_and_hand(game.run.slots + slots_by, game.run.hand_size + hand_by)
		_did("%d card slots, hand size %d" % [game.run.slots, game.run.hand_size])


## Moves this round's last turn, though never before the turn being played.
func _add_turns(by: int) -> void:
	game.turn_limit = maxi(game.turn_limit + by, game.turn)
	game.refresh_ui()
	_did("Turn limit %d" % game.turn_limit)


func _add_keys(by: int) -> void:
	if _in_round():
		game.board.keys_held = maxi(game.board.keys_held + by, 0)
		game.refresh_ui()
		_did("Keys held %d" % game.board.keys_held)


func _add_bosses_beaten(by: int) -> void:
	game.run.bosses_beaten = maxi(game.run.bosses_beaten + by, 0)
	_did("Bosses beaten %d" % game.run.bosses_beaten)


func _open_shop(free_trinket: bool) -> void:
	if _idle():
		game.win_panel.hide()
		game.shop.open(game.run, free_trinket)
		_did("Opened the %sshop" % ("boss " if free_trinket else ""))


func _set_speed(index: int) -> void:
	var instant := index == SPEEDS.size() - 1
	game.board.animate = not instant
	Engine.time_scale = 1.0 if instant else SPEED_SCALES[index]
	_did("Speed %s" % SPEEDS[index])


## Adds amount crumbs, or sets them to 0 for -1.
func _add_crumbs(amount: int) -> void:
	game.run.crumbs = 0 if amount == -1 else game.run.crumbs + amount
	game.refresh_ui()
	_did("Crumbs set to %d" % game.run.crumbs)


func _set_trinket(on: bool, trinket: Items.Trinket) -> void:
	if on and not game.run.has(trinket):
		game.run.trinkets.append(trinket)
	elif not on:
		game.run.trinkets.erase(trinket)
	game.refresh_ui()
	_did("%s %s" % ["Added" if on else "Removed", Items.TRINKETS[trinket][0]])


func _set_slot_effect(index: int, slot: int) -> void:
	if _idle():
		game.set_slot_effect(slot, index as CardSlot.Effect)
		_did("Slot %d effect: %s" % [slot + 1, _effect_name(index)])


func _add_card(keep: bool) -> void:
	if not _idle():
		return
	var data := CardData.new(_card_dir.selected as Card.Dir, _card_stamp.selected as CardSlot.Effect)
	var in_hand := game.add_card(data, keep)
	if not keep and not in_hand:
		_say("There's no hand between rounds.")
		return
	_did("Added %s to the %s" % [data.label(), "deck" if keep else "hand"])


## A dropdown of every slot effect, where the item index is the CardSlot.Effect value.
func _effect_dropdown() -> OptionButton:
	var dropdown := OptionButton.new()
	for effect: CardSlot.Effect in CardSlot.Effect.values():
		dropdown.add_item(_effect_name(effect), effect)
		dropdown.set_item_tooltip(effect, CardSlot.INFO[effect][1])
	dropdown.focus_mode = Control.FOCUS_NONE
	return dropdown


func _effect_name(effect: int) -> String:
	return CardSlot.INFO[effect][0] if effect != CardSlot.Effect.NONE else "(none)"


## True when the game can be changed now. While the mouse is moving, says to wait instead.
func _idle() -> bool:
	if game.busy:
		_say("Busy: wait for the move to finish.")
	return not game.busy


## Like _idle, and also says no once the round is over (the win panel or the shop is up).
func _in_round() -> bool:
	if not _idle():
		return false
	if game.win_panel.visible or game.shop.visible:
		_say("The round is already over.")
		return false
	return true


## Shows what happened and logs it for bug reports.
func _did(text: String) -> void:
	BugReport.note("DEV: " + text)
	game.refresh_preview()
	_say(text + ".")


func _say(text: String) -> void:
	_feedback.text = text


func _add_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	_tabs.add_child(scroll)
	return box


func _heading(box: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADING_COLOR)
	label.add_theme_font_size_override("font_size", 16)
	box.add_child(label)


func _row(box: VBoxContainer) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	box.add_child(row)
	return row


func _label(row: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	row.add_child(label)


func _button(row: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	row.add_child(button)
	return button
