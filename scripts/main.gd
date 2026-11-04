class_name Main
extends Control
## Game controller: runs a run of rounds, deals hands, handles card placement, and plays locked-in turns.

## Chance that a round has a chest. Opening it pays CHEST_CRUMBS.
const CHEST_CHANCE := 0.4
## The chest is at least this many cells from the mouse.
const CHEST_MIN_DISTANCE := 4
const CHEST_CRUMBS := 12
## Width of the row of slots, and of the hand between the piles. Cards shrink so a row of them fits.
const ROW_WIDTH := 560.0
const HAND_WIDTH := 480.0
const SLOT_GAP := 8
## The cheese starts at least this many cells from the mouse, or the board's size less 2 if that's smaller.
const MIN_CHEESE_DISTANCE := 8
## Crumbs scattered on the board each round, worth 1 each.
const CRUMB_COUNT := 6
## Each run of wall is WALL_RUN_MIN wall segments long, up to WALL_SPAN of the board's side, end to end
## along cell edges. It turns a corner at most once, at each segment with WALL_TURN_CHANCE.
const WALL_RUN_MIN := 3
const WALL_SPAN := 0.6
const WALL_TURN_CHANCE := 0.25
## Runs of wall tried for each one laid, and for the chest's pocket (see _place_walls, _place_pocket).
## The one that does most is kept.
const WALL_TRIES := 16
const POCKET_TRIES := 40
## A run of wall that doesn't lengthen the way to the cheese is only laid if it lengthens the way to
## at least this share of the board's cells.
const WALL_MIN_REACH := 0.2
## The walls lengthen the way from the mouse to the cheese by at most this share of the board's side.
const WALL_DETOUR := 0.3
## The chest goes in a pocket: a dead end that takes CHEST_MIN_DETOUR to CHEST_MAX_DETOUR more steps to
## go by on the way to the cheese (see _pockets). Pockets the chest isn't in get a crumb.
const CHEST_MIN_DETOUR := 3
const CHEST_MAX_DETOUR := 8
## Cells deep a pocket of wall made for the chest is (see _wall_run).
const POCKET_DEPTH_MIN := 2
const POCKET_DEPTH_MAX := 3
## Each chasm is a run of CHASM_MIN cells up to CHASM_SPAN of the board's side, a cell wide. It turns
## a corner at most once, at each cell with CHASM_TURN_CHANCE.
const CHASM_MIN := 3
const CHASM_SPAN := 0.7
const CHASM_TURN_CHANCE := 0.25
## Chasms tried for each one laid (see _place_chasms). The one that does most is kept.
const CHASM_TRIES := 16
## The chasms lengthen the way from the mouse to the cheese by at most this share of the board's side,
## on top of the walls.
const CHASM_DETOUR := 0.3
## What a chasm that makes its bridge a choke point is worth, in steps longer on the way to the cheese.
const CHASM_CHOKE_SCORE := 3.0
## Chance that a chasm gets a jump pad that throws the mouse across it, if one would save at least
## CHASM_PAD_SAVING steps.
const CHASM_PAD_CHANCE := 0.5
const CHASM_PAD_SAVING := 4
## A conveyor belt is a walk of BELT_MIN cells up to BELT_SPAN of the board's side that turns a corner
## at most once, at each cell with BELT_TURN_CHANCE (see _belt_run).
const BELT_MIN := 3
const BELT_SPAN := 0.5
const BELT_TURN_CHANCE := 0.2
## Belts tried for each one laid (see _place_belts), each starting within BELT_REACH steps of the way
## to the cheese. The one that does most is kept.
const BELT_TRIES := 30
const BELT_REACH := 2
## Chance that a belt is a current, laid to make the way to the cheese longer, rather than a highway
## that saves steps on it.
const BELT_CURRENT_CHANCE := 0.5
## A highway is only laid if riding it saves at least BELT_SAVING steps on the way to the cheese, and
## a current if it makes the way at least BELT_CURRENT_DETOUR steps longer.
const BELT_SAVING := 3
const BELT_CURRENT_DETOUR := 2
## The currents lengthen the way to the cheese by at most this share of the board's side, on top of
## everything laid before them.
const BELT_DETOUR := 0.25
## Cells a jump pad throws the mouse.
const PAD_MIN := 2
const PAD_MAX := 4
## A flamethrower is only placed pointing a way its jet reaches at least this many cells.
const FLAME_MIN := 2
## What a locked door or gate is there for (see _place_locks): a quicker way to the cheese, a chest
## shut away, or the only way to the cheese.
enum LockJob { SHORTCUT, VAULT, GOAL }

## Runs of wall tried for each locked door or gate (see _lock_run). The one that does its job best is
## kept.
const LOCK_TRIES := 40
## A shortcut lock is only laid if going through it saves at least this many steps on the way to the
## cheese, counting the way by its key or crate.
const LOCK_MIN_SAVING := 3
## Chance that one of the round's locked doors is the only way to the cheese.
const LOCK_GOAL_CHANCE := 0.3
## Half the cells tried for a shortcut's key, plate and crate are at most this many cells across and
## down from the lock.
const LOCK_ITEM_REACH := 4
## The most wall segments in a run with a locked door or gate in it.
const LOCK_RUN_MAX := 5
## Random cells tried for each key, and twice as many for each plate and crate, which need room for a
## lane. The one that adds least to the way is kept.
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
const WASTEBASKET_DISCARDS := 2
## Crumbs for reaching the cheese. Unused discards pay 1 each on top.
const WIN_CRUMBS := 5
const PIGGY_BANK_MAX := 5
## Extra crumbs each crumb picked up on the board pays with the SALT SHAKER.
const SALT_SHAKER_CRUMBS := 2
const HINT := "Click a card to put it in the next slot, or drag it to a slot. Then Lock In."
## Color of the discard area under the hand, which lights up while a card is dragged.
## Seconds after a lost round ends before its sad tune plays.
const LOSE_SOUND_DELAY := 0.35
## A card going back to the hand sounds lower than one going into a slot.
const HAND_PITCH := 0.85
const DISCARD_COLOR := Color("e07a5f")
const PLAYING := Color(1.15, 1.15, 0.8)
const PLAYED := Color(1, 1, 1, 0.45)
const FIZZLED := Color(1, 0.5, 0.5, 0.6)

@onready var board: Board = %Board
@onready var hud_label: Label = %HudLabel
@onready var boss_label: Label = %BossLabel
@onready var trinket_row: HFlowContainer = %TrinketRow
@onready var skill_row: HBoxContainer = %SkillRow
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
var skill_draft := SkillDraft.new()
## Shown under the win panel's button once the run is won, to start over instead of going on.
var new_run_button := Button.new()
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
## Crumbs GOLD cards paid this round.
var gold_crumbs := 0
## This round's score and the target it needs (see Score), and the points and mult this turn has
## made so far, added to the score at the end of the turn (_bank_turn).
var round_score := 0
var score_target := 0
var turn_points := 0
var turn_mult := 1
## Cells the card playing now has moved the mouse, for a PAPER card. _play_cards zeroes it for each card.
var card_cells := 0
## What the last turn added to the score, for the HUD.
var last_turn_score := ""
## Points made this frame, by the cell that made them, waiting to pop up together (_pop_points).
var _pending_points: Dictionary[Vector2i, int] = {}
## What each chest opened this round gave, for the win panel.
var chest_rewards := PackedStringArray()
## Shown in place of the hint at the start of the next turn, after a chest is opened.
var chest_note := ""
## Traps THICK FUR has broken this turn.
var traps_broken := 0
## Charges each of the run's skills has left this round (Items.Skill -> count), refilled from
## Items.skill_charges at the start of every round. PASSIVE skills have none.
var skill_charges: Dictionary[int, int] = {}
## ACTIVE skills used this turn, on until the turn's cards have played (use_skill).
var active_skills: Array[int] = []
## Where the mouse was when this turn's cards started to play, for NINE LIVES.
var turn_start_cell := Vector2i.ZERO
## Set when NINE LIVES saved the mouse during this turn's cards: the rest of them don't play.
var escaped := false
## Whether the skill draft that's open is a boss's reward, which leads on to the shop.
var _draft_after_boss := false
## Cards played from RECYCLE slots, returned to the next hand.
var recycled: Array[CardData] = []
## Set from the F2 dev menu: the cards left in the hand at Lock In stay in it for the next turn,
## which draws only up to the hand size. Off, the whole hand is discarded each turn. PACK RAT keeps
## up to Items.PACK_RAT_CARDS of them (_cards_kept).
var keep_hand := false
## Cards left in the hand at the last Lock In, kept for the next hand (_cards_kept).
var kept: Array[CardData] = []
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
## Cells kept clear while laying out a round: the lines crates get pushed along to their plates, and
## the cells either side of each locked door and gate.
var _kept_clear: Array[Vector2i] = []
## Each SHORTCUT lock laid this round, with its key's cell or its crate lane (see _crate_lane), until
## _drop_idle_shortcuts checks them.
var _shortcuts: Dictionary[Vector3i, Array] = {}
## Most steps from the mouse to the cheese the walls may make it while laying out a round (see _place_walls).
var _longest_way := 0
## Shows the keys the mouse holds, next to the HUD, in rounds that have doors or keys.
var _key_label := Label.new()
## Shows the round's score and target, and this turn's points and mult while it plays, before the trinkets.
var _score_label := Label.new()


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
	# The balance sim runs headless, with no one to hear it, so it makes no sounds.
	if DisplayServer.get_name() != "headless":
		add_child(Sfx.new())
		add_child(Music.new())
	hand_box.set_drag_forwarding(Callable(), _can_drop_on_hand, _drop_on_hand)
	hand_box.child_entered_tree.connect(func(node: Node) -> void: _fit_card(node, hand_card_size))
	discard_card_button.set_drag_forwarding(Callable(), _can_drop_on_discard, _drop_on_discard)
	discard_button.set_drag_forwarding(Callable(), _can_drop_on_discard, _drop_on_discard)
	discard_card_button.pressed.connect(func() -> void:
		status_label.text = "Drag a card down here, or %s it, to swap it for a new one." % [
			"hold" if DisplayServer.is_touchscreen_available() else "right-click"])
	_light_discard_area(false)
	lock_in_button.pressed.connect(lock_in)
	lock_in_button.set_meta(Sfx.NO_CLICK, true)
	_preview_board.animate = false
	_preview_board.hide()
	add_child(_preview_board)
	win_panel_button.pressed.connect(_on_win_panel_button)
	new_run_button.text = "New Run"
	new_run_button.custom_minimum_size = win_panel_button.custom_minimum_size
	new_run_button.add_theme_font_size_override("font_size", 20)
	new_run_button.hide()
	new_run_button.pressed.connect(new_run)
	win_panel_button.add_sibling(new_run_button)
	# The piles are replaced each round, so look them up when the button is pressed.
	draw_pile_button.pressed.connect(func() -> void: _view_pile("Draw pile", run.deck.draw_pile))
	discard_button.pressed.connect(func() -> void: _view_pile("Discard", run.deck.discard_pile))
	board.crumb_collected.connect(_on_crumb_collected)
	board.chest_opened.connect(_open_chest)
	board.key_collected.connect(_on_key_collected)
	board.door_unlocked.connect(_on_door_unlocked)
	board.mouse_moved.connect(_on_mouse_moved)
	_key_label.add_theme_color_override("font_color", KEY_COLOR)
	_key_label.add_theme_font_size_override("font_size", hud_label.get_theme_font_size("font_size"))
	_key_label.size_flags_vertical = hud_label.size_flags_vertical
	hud_label.add_sibling(_key_label)
	_score_label.add_theme_color_override("font_color", Score.COLOR)
	_score_label.add_theme_font_size_override("font_size", hud_label.get_theme_font_size("font_size"))
	_score_label.size_flags_vertical = hud_label.size_flags_vertical
	_score_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_score_label.tooltip_text = ("Each turn scores points times mult. Points: %d a cell moved, %d a crumb, %d a "
		+ "chest, %d a ride on a hole, belt or pad. Mult starts at 1, and each turn left over adds %d on the "
		+ "turn you reach the cheese. Meeting the target pays bonus crumbs; in a boss round, missing it ends "
		+ "the run.") % [Score.CELL_POINTS, Score.CRUMB_POINTS, Score.CHEST_POINTS, Score.RIDE_POINTS,
		Score.SPARE_TURN_MULT]
	# On the right, before the trinkets: its text changes length every turn, and under the title it would
	# widen the board's column and push the cards off the screen.
	trinket_row.add_sibling(_score_label)
	trinket_row.get_parent().move_child(_score_label, 0)
	add_child(pile_viewer)
	shop.next_round_pressed.connect(new_round)
	add_child(shop)
	skill_draft.picked.connect(_on_skill_picked)
	add_child(skill_draft)
	var bug_report := BugReport.new()
	bug_report.get_state = _bug_report_state
	add_child(bug_report)
	trinket_row.get_parent().add_child(SoundButton.new())
	# Phones have no F2 or F12 key, so on a touchscreen buttons after the trinkets open them.
	var touch := DisplayServer.is_touchscreen_available()
	if touch:
		_add_touch_button("Bug", bug_report.open)
		add_child(TouchTips.new())
	# True in the editor and debug exports, false in release exports.
	if OS.is_debug_build():
		var dev_menu := DevMenu.new()
		dev_menu.game = self
		add_child(dev_menu)
		if touch:
			_add_touch_button("Dev", dev_menu.toggle)
	new_run()


## Adds a button after the trinkets, top right, sized for a finger.
func _add_touch_button(text: String, on_pressed: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(64, 40)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	trinket_row.get_parent().add_child(button)


## Starts over with the starting deck, no crumbs and no items, then drafts the run's first skill over
## the first round's board.
func new_run() -> void:
	run = Run.new()
	BugReport.note("New run")
	new_round()
	_open_draft(false)


## Opens a skill draft: the run's first skill, or a boss's reward (after_boss). Returns false, opening
## nothing, when there's nothing left to offer.
func _open_draft(after_boss: bool) -> bool:
	_draft_after_boss = after_boss
	var title := "Boss reward: pick a skill" if after_boss else "Pick your first skill"
	var subtitle := "Yours for the whole run. You'll pick another after each boss."
	if after_boss:
		subtitle = "A new skill, or the next level of one you have." if run.skills.size() < Items.SKILL_SLOTS \
			else "Your skill slots are full: pick one to level up."
	var opened := skill_draft.open(run, SkillDraft.roll(run), title, subtitle)
	if opened:
		refresh_preview()
	return opened


## A skill was drafted: it starts with full charges, and a boss's reward goes on to the shop.
func _on_skill_picked(skill: Items.Skill) -> void:
	skill_charges.erase(skill)
	if _draft_after_boss:
		shop.open(run)
	refresh_ui()


func new_round() -> void:
	_clear_cards()
	run.round_number += 1
	run.deck.new_round()
	recycled.clear()
	kept.clear()
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
	# Last round's mouse cell would hold down any plate laid on it while the layout is checked.
	board.mouse_cell = mouse
	var traps := _place_traps(mouse, cheese)
	var walls := _place_walls(mouse, cheese, traps)
	var chasms := _place_chasms(mouse, cheese, traps)
	# A chest goes behind a bridge or in a pocket of wall, once the round has walls. Laid now, so the
	# rest keeps off it.
	var chest := randf() < CHEST_CHANCE
	if chest and Difficulty.walls(run.round_number) > 0:
		var pocket := _place_pocket(mouse, cheese, traps)
		if pocket != NO_CELL:
			board.chests.append(pocket)
	_place_chasm_pads(chasms, mouse, cheese)
	_place_locks(mouse, cheese, traps)
	_place_hazards(mouse, cheese, traps)
	_place_floor(mouse, cheese, traps)
	_drop_idle_shortcuts(mouse, cheese)
	var crumbs := _place_crumbs(mouse, cheese, traps)
	var cats := _place_cats(mouse, cheese, traps)
	board.place(mouse, cheese, traps, crumbs, cats, run.boss == Boss.Kind.ALLEY_KING, walls)
	if chest and board.chests.is_empty():
		board.chests = _place_chest(mouse, cheese, traps, crumbs)
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
	if run.has(Items.Trinket.WASTEBASKET):
		discards_left += WASTEBASKET_DISCARDS
	round_crumbs = 0
	gold_crumbs = 0
	round_score = 0
	score_target = Score.target(run.round_number, run.boss != -1)
	turn_points = 0
	turn_mult = 1
	last_turn_score = ""
	chest_rewards.clear()
	chest_note = ""
	_end_skills()
	skill_charges.clear()
	win_panel.hide()
	pile_viewer.hide()
	shop.hide()
	skill_draft.hide()
	_refresh_trinkets()
	_refresh_skills()
	Music.play(Music.Song.BOSS if run.boss != -1 else Music.Song.BOARD)
	Music.set_muffled(false)
	start_turn()


func start_turn() -> void:
	# Beating a boss, or the dev menu, can have added a slot or a card.
	_build_slots()
	var drawn: Array[CardData] = []
	drawn.append_array(kept)
	drawn.append_array(recycled)
	drawn.append_array(run.deck.draw(maxi(0, _hand_size() - drawn.size())))
	BugReport.note("Turn %d: hand %s%s" % [turn, _card_names(drawn),
		" (kept %s)" % _card_names(kept) if kept else ""])
	kept.clear()
	recycled.clear()
	for data in drawn:
		hand_box.add_child(_make_card(data))
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
	Sfx.play(Sfx.Sound.DEAL)
	if turn == turn_limit and turn > 1:
		Sfx.play(Sfx.Sound.LAST_TURN)
	Music.set_tension(turn_limit - turn < Music.TENSION_TURNS)
	_refresh_hud()
	_refresh_pouch()
	refresh_preview()


## Plays the slotted cards in order, then discards them and deals the next hand. With keep_hand, the
## cards left in the hand stay in it; without, they're discarded too.
func lock_in() -> void:
	# Lock In can still be reached with Tab under the win panel, the shop and the skill draft.
	if busy or win_panel.visible or shop.visible or skill_draft.visible:
		return
	busy = true
	Sfx.play(Sfx.Sound.LOCK_IN)
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
	turn_points = 0
	turn_mult = 1
	turn_start_cell = board.mouse_cell
	var order := _play_order()
	var reached := await _play_cards(order)
	_score_cards()
	_pay_stones()
	# Set when the mouse reaches the cheese or is caught in a trap.
	var ended := _round_over()
	# Glue holds the mouse, or NINE LIVES got it away: the cards left don't move it.
	if (board.stuck or escaped) and not ended:
		for slot in order.slice(reached):
			if slot.get_card():
				slot.get_card().modulate = FIZZLED
		if not escaped:
			status_label.text = "Stuck in glue! The rest of this turn's cards don't move the mouse."
		if board.animate:
			await get_tree().create_timer(Board.STEP_TIME * 2, false).timeout
	if board.squeeze:
		board.squeeze = false
		BugReport.note("Squeeze wore off")
	_end_skills()

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
		if ended and await _spend_life():
			ended = false
	if not ended and turn >= turn_limit:
		out_of_time = true
		ended = true
	_bank_turn()

	var played: Array[CardData] = []
	for card in _all_cards():
		var slot := card.get_parent() as CardSlot
		# A card left in the hand stays there for the next turn.
		if not slot and kept.size() < _cards_kept() and not ended:
			kept.append(card.data)
			continue
		# The slot's effect and the card's stamp both apply. A burned card is gone, so nothing recycles it.
		var effects: Array[CardSlot.Effect] = []
		if slot:
			effects = [_slot_effect(slot, card), card.stamp]
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
	traps_broken = 0
	escaped = false
	var ended := false
	# Until a card plays, for SCURRY.
	var first := true
	var i := 0
	while i < order.size() and not ended and not board.stuck and not escaped:
		var slot := order[i]
		var card := slot.get_card()
		if card == null:
			i += 1
			continue
		var partner_slot: CardSlot = order[i + 1] if i + 1 < order.size() else null
		var diagonal := _slot_effect(slot, card) == CardSlot.Effect.DIAGONAL and partner_slot \
				and partner_slot.get_card()
		if preview and (_slot_effect(slot, card) == CardSlot.Effect.GAMBLE
				or diagonal and _slot_effect(partner_slot, partner_slot.get_card()) == CardSlot.Effect.GAMBLE):
			break
		i += 1
		card.modulate = PLAYING
		card_cells = 0
		if diagonal:
			var partner := partner_slot.get_card()
			i += 1
			partner.modulate = PLAYING
			var dir := _play_dir(slot, card)
			var partner_dir := _play_dir(partner_slot, partner)
			var offset: Vector2i = Card.OFFSETS[dir] + Card.OFFSETS[partner_dir]
			last_dir = partner_dir
			ended = await board.jump(offset, dir)
			BugReport.note("  Slot %d DIAGONAL %s + slot %d %s %s -> mouse %s" % [
				slot.number, card.data.label(), partner_slot.number,
				CardSlot.INFO[partner_slot.effect][0], partner.data.label(), board.mouse_cell])
			partner.modulate = PLAYED
			if not preview:
				_play_material(partner)
		else:
			ended = await _play(slot, card, first)
			# Facing is the last direction moved, which differs from the card for WILD, GAMBLE, etc.
			BugReport.note("  Slot %d %s%s -> mouse %s" % [slot.number,
				" ".join(PackedStringArray([CardSlot.INFO[slot.effect][0], card.data.label()])).strip_edges(),
				" (moved %s)" % Card.NAMES[board.facing] if board.facing != card.dir else "",
				board.mouse_cell])
		if not preview:
			_play_material(card)
		if ended and _survive_trap():
			ended = false
		# The preview shows the catch: NINE LIVES is for when it goes wrong anyway.
		elif ended and not preview and await _spend_life():
			ended = false
		if card.modulate == PLAYING:
			card.modulate = PLAYED
		first = false
	return i


## True when the mouse is on the cheese or caught: the round is over.
func _round_over() -> bool:
	return board.mouse_cell == board.cheese_cell or board.is_caught()


## Whether the preview is drawn: the dev menu's preview_on, or the KEEN WHISKERS skill.
func _previewing() -> bool:
	return preview_on or run.has_skill(Items.Skill.KEEN_WHISKERS)


## How many of the cards left in the hand at Lock In stay for the next turn, the leftmost first: all of
## them with the dev menu's keep_hand, Items.PACK_RAT_CARDS with the PACK RAT skill, else none.
func _cards_kept() -> int:
	if keep_hand:
		return Run.MAX_HAND_SIZE
	return Items.PACK_RAT_CARDS if run.has_skill(Items.Skill.PACK_RAT) else 0


## Shows or hides the preview to match _previewing, at the end of the frame, once however many times
## it's called in the frame.
func refresh_preview() -> void:
	if not _preview_queued:
		_preview_queued = true
		_update_preview.call_deferred()


## While _previewing, plays this turn's cards on a hidden copy of the board and draws where they take
## the mouse on the board. None of it counts: the crumbs and chests on the way stay put, and the cards,
## the status line, THICK FUR and the log are left as they were. NINE LIVES doesn't save the mouse in
## it, so a catch shows.
func _update_preview() -> void:
	_preview_queued = false
	if not _previewing() or busy or win_panel.visible or shop.visible or skill_draft.visible:
		board.show_preview([], Board.PreviewEnd.MOVED)
		return
	var real := board
	var status := status_label.text
	var fur_used := traps_broken
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
	traps_broken = fur_used
	last_dir = dir_before
	for i in cards.size():
		cards[i].modulate = tints[i]
	board.show_preview(_preview_board.trail.duplicate(), end)


## Shows how the round ended: crumbs earned and the way to the shop, or the end of the run.
func _end_round() -> void:
	run_over = board.is_caught() or out_of_time or _short_of_boss_target()
	if _short_of_boss_target():
		BugReport.note("Short of the boss's score target: %d / %d in round %d" % [round_score, score_target,
			run.round_number])
		win_label.text = "%s wanted a score of %d. You scored %d." % [Boss.INFO[run.boss][0], score_target,
			round_score]
	elif out_of_time:
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
		Music.stop()
		# After the snap, pounce or blast that ended it has rung out a little.
		get_tree().create_timer(LOSE_SOUND_DELAY).timeout.connect(Sfx.play.bind(Sfx.Sound.LOSE))
	else:
		Sfx.play(Sfx.Sound.BOSS_WIN if run.boss != -1 or won_run() else Sfx.Sound.WIN)
		Music.set_muffled(true)
		var reward := WIN_CRUMBS if run.boss == -1 else Boss.WIN_CRUMBS
		var lines := PackedStringArray(["%s  +%d" % ["Cheese" if run.boss == -1 else "Boss cheese", reward]])
		var earned := reward + discards_left
		if discards_left > 0:
			lines.append("Unused discards  +%d" % discards_left)
		if run.has(Items.Trinket.PIGGY_BANK):
			var interest := mini(floori(run.crumbs / 5.0), PIGGY_BANK_MAX)
			earned += interest
			lines.append("Piggy bank  +%d" % interest)
		var score_crumbs := Score.crumbs(round_score, score_target)
		earned += score_crumbs
		if score_crumbs > 0:
			lines.append("Score %d of %d  +%d" % [round_score, score_target, score_crumbs])
		else:
			lines.append("Score %d, short of %d  +0" % [round_score, score_target])
		if round_crumbs > 0:
			lines.append("Crumbs picked up  +%d" % round_crumbs)
		if gold_crumbs > 0:
			lines.append("Gold cards  +%d" % gold_crumbs)
		for chest in chest_rewards:
			lines.append("Chest  %s" % chest)
		run.crumbs += earned
		lines.append("You have %d crumbs." % run.crumbs)
		BugReport.note("Found the cheese on turn %d, score %d / %d, earned %d (+%d picked up), %d crumbs" % [
			turn, round_score, score_target, earned, round_crumbs, run.crumbs])
		win_label.text = "You found the cheese in %d turn%s!" % [turn, "" if turn == 1 else "s"]
		if run.boss != -1:
			run.bosses_beaten += 1
			win_label.text = "You beat %s in %d turn%s!" % [Boss.INFO[run.boss][0], turn, "" if turn == 1 else "s"]
			lines.append_array(_boss_upgrade())
			if not run.draft_pool().is_empty():
				lines.append("Pick a skill next.")
		if won_run():
			BugReport.note("Won the run on round %d" % run.round_number)
			win_label.text = "You won the run!"
			lines.append("Keep going in endless mode, or start a new run.")
		var next := run.round_number + 1
		lines.append("Next round: %s, score target %d." % [Difficulty.describe(next),
			Score.target(next, bosses_enabled and Boss.is_boss_round(next))])
		win_details.text = "\n".join(lines)
		win_panel_button.text = "Endless" if won_run() else (
			"Pick a Skill" if run.boss != -1 and not run.draft_pool().is_empty() else "Shop")
	new_run_button.visible = won_run()
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
		if won_run():
			run.endless = true
			BugReport.note("Going on in endless mode")
		win_panel.hide()
		# A boss's reward is a skill draft, which goes on to the shop once a skill is picked.
		if run.boss == -1 or not _open_draft(true):
			shop.open(run)


## True when the round ended the run: the mouse was caught, the turns ran out, or it reached the
## cheese short of a boss round's score target.
func lost() -> bool:
	return run_over


## At the end of a round, true when it won the run: round Run.GOAL_ROUNDS won, before endless mode.
func won_run() -> bool:
	return not lost() and run.round_number == Run.GOAL_ROUNDS and not run.endless


## True when the mouse reached the cheese in a boss round without meeting the score target.
func _short_of_boss_target() -> bool:
	return run.boss != -1 and board.mouse_cell == board.cheese_cell and not board.is_caught() \
		and round_score < score_target


## Scores a move of the mouse (Board.mouse_moved): points for the cells it moved and the rides it
## took, plus what the BUTTER PAT, RIDE TICKET and HARD HEAD add. Only the real board is connected, so the
## preview scores nothing.
func _on_mouse_moved(motion: Board.Motion, cells: int) -> void:
	if motion in [Board.Motion.STEP, Board.Motion.JUMP, Board.Motion.SLIDE]:
		card_cells += cells
	match motion:
		Board.Motion.STEP, Board.Motion.JUMP:
			_add_points(cells * Score.CELL_POINTS, board.mouse_cell)
		Board.Motion.SLIDE:
			var butter := Score.BUTTER_PAT_POINTS if run.has(Items.Trinket.BUTTER_PAT) else 0
			_add_points(cells * (Score.CELL_POINTS + butter), board.mouse_cell)
		Board.Motion.RIDE:
			_add_points(Score.RIDE_POINTS, board.mouse_cell)
			if run.has(Items.Trinket.RIDE_TICKET):
				turn_mult += Score.RIDE_TICKET_MULT
				_pop_mult("+%d mult" % Score.RIDE_TICKET_MULT)
		Board.Motion.BUMP:
			if run.has_skill(Items.Skill.HARD_HEAD):
				var mult := Score.hard_head_mult(run.skill_level(Items.Skill.HARD_HEAD))
				turn_mult += mult
				_pop_mult("+%d mult" % mult)
				_flash_skill(Items.Skill.HARD_HEAD)
	_refresh_hud()


## Pays out a card's material as it plays, where the mouse is: WOOD and COPPER points, PAPER points
## for the cells it moved (card_cells), SHINY mult, GOLD crumbs. The preview's cards pay nothing.
func _play_material(card: Card) -> void:
	match card.data.material:
		Items.CardMaterial.WOOD:
			_add_points(Score.WOOD_POINTS, board.mouse_cell)
		Items.CardMaterial.COPPER:
			_add_points(card.data.copper_points(), board.mouse_cell)
			card.data.copper_plays += 1
		Items.CardMaterial.PAPER:
			if card_cells == 0:
				return
			_add_points(card_cells * Score.PAPER_POINTS, board.mouse_cell)
		Items.CardMaterial.SHINY:
			turn_mult += Score.SHINY_MULT
			_pop_mult("+%d mult" % Score.SHINY_MULT)
		Items.CardMaterial.GOLD:
			run.crumbs += Items.GOLD_CRUMBS
			gold_crumbs += Items.GOLD_CRUMBS
			if board.animate:
				Sfx.play(Sfx.Sound.CRUMB, 1.25)
				ScorePopup.spawn(self, board.cell_global_center(board.mouse_cell) + Vector2(0, 18),
					"+%d crumb" % Items.GOLD_CRUMBS, 0.3)
		_:
			return
	BugReport.note("  %s card paid out" % Items.MATERIALS[card.data.material][0])
	_refresh_hud()


## Adds Score.STONE_MULT for each STONE card left in the hand at Lock In.
func _pay_stones() -> void:
	var stones := _hand_cards().filter(
		func(card: Card) -> bool: return card.data.material == Items.CardMaterial.STONE).size()
	if stones == 0:
		return
	turn_mult += stones * Score.STONE_MULT
	_pop_mult("+%d mult" % (stones * Score.STONE_MULT))
	BugReport.note("  %d STONE card%s in hand paid out" % [stones, "" if stones == 1 else "s"])
	_refresh_hud()


## Adds the mult that goes by how the cards played: DAREDEVIL when they left the mouse next to a trap,
## a cat or a cat's path, and SHOW-OFF when every slot that isn't blocked held a card.
func _score_cards() -> void:
	if run.has_skill(Items.Skill.DAREDEVIL) and not _round_over():
		var times := Score.daredevil_times(run.skill_level(Items.Skill.DAREDEVIL))
		for offset: Vector2i in Card.OFFSETS.values():
			if board.is_deadly(board.mouse_cell + offset):
				turn_mult *= times
				_pop_mult("×%d mult" % times)
				BugReport.note("  DAREDEVIL: next to danger at %s" % (board.mouse_cell + offset))
				_flash_skill(Items.Skill.DAREDEVIL)
				break
	if run.has_skill(Items.Skill.SHOW_OFF) and slots.all(func(slot: CardSlot) -> bool:
			return slot.effect == CardSlot.Effect.BLOCKED or slot.get_card() != null):
		var times := Score.show_off_times(run.skill_level(Items.Skill.SHOW_OFF))
		turn_mult *= times
		_pop_mult("×%d mult" % times)
		BugReport.note("  SHOW-OFF: every slot filled")
		_flash_skill(Items.Skill.SHOW_OFF)
	_refresh_hud()


## Adds this turn's points times its mult to the round's score. On the turn that reaches the cheese,
## each turn left over first adds Score.SPARE_TURN_MULT to the mult.
func _bank_turn() -> void:
	if board.mouse_cell == board.cheese_cell and not board.is_caught():
		turn_mult += (turn_limit - turn) * Score.SPARE_TURN_MULT
	var gained := turn_points * turn_mult
	round_score += gained
	if gained > 0:
		pop_turn_score(gained, turn_points, turn_mult)
	last_turn_score = "+%d (%d × %d)" % [gained, turn_points, turn_mult]
	BugReport.note("Turn score %d x %d = %d, round score %d / %d" % [turn_points, turn_mult, gained,
		round_score, score_target])
	turn_points = 0
	turn_mult = 1


## Adds points a move made on cell to the turn, and pops them up there. Points made on a cell in the
## same frame (a step onto a crumb) pop up as one number.
func _add_points(points: int, cell: Vector2i) -> void:
	turn_points += points
	if points <= 0 or not board.animate:
		return
	if _pending_points.is_empty():
		_pop_points.call_deferred()
	_pending_points[cell] = _pending_points.get(cell, 0) + points


func _pop_points() -> void:
	var strongest := 0.0
	for cell: Vector2i in _pending_points:
		var points := _pending_points[cell]
		var intensity := ScorePopup.points_intensity(points)
		strongest = maxf(strongest, intensity)
		ScorePopup.spawn(self, board.cell_global_center(cell), "+%d" % points, intensity)
	_pending_points.clear()
	Sfx.play(Sfx.Sound.POINTS, 1.0 + strongest * 0.6)


## Pops up mult a trinket or skill added this turn, over the mouse.
func _pop_mult(text: String) -> void:
	if board.animate:
		Sfx.play(Sfx.Sound.MULT)
		ScorePopup.spawn(self, board.cell_global_center(board.mouse_cell) + Vector2(0, -18), text, 0.45,
			false, true)


## Pops up the score a turn banked over the board, bigger and wilder the bigger a share of the round's
## target it is, and flashes the score in the HUD. The dev menu calls it to try out sizes.
func pop_turn_score(gained: int, points: int, mult: int) -> void:
	if not board.animate:
		return
	var strength := ScorePopup.turn_intensity(gained, score_target)
	Sfx.play(Sfx.Sound.SCORE, 0.8 + 0.5 * strength)
	ScorePopup.spawn(self, board.get_global_rect().get_center(), "+%d" % gained, strength, true, false,
		"%d × %d" % [points, mult] if mult > 1 else "")
	var flash := create_tween()
	flash.tween_property(_score_label, "modulate", Color.WHITE, 0.3 + 0.5 * strength) \
		.from(Color.WHITE.lerp(Color(2.2, 2.2, 1.6), 0.4 + 0.6 * strength))


## If the mouse is on a trap and THICK FUR hasn't broken as many traps this turn as its level, breaks
## the trap and returns true so the turn carries on.
func _survive_trap() -> bool:
	if not board.is_trapped() or traps_broken >= run.skill_level(Items.Skill.THICK_FUR):
		return false
	traps_broken += 1
	board.remove_trap(board.mouse_cell)
	BugReport.note("  THICK FUR broke the trap at %s" % board.mouse_cell)
	status_label.text = "Thick Fur! The trap broke."
	# The preview's board doesn't animate, and the preview shouldn't light up the skill.
	if board.animate:
		_flash_skill(Items.Skill.THICK_FUR)
	return true


## If the mouse was just caught and NINE LIVES has a life left this round, spends it and returns true
## so the round goes on. Caught by a trap or a cat during the cards, the mouse escapes back to the cell
## it started the turn on (turn_start_cell, which the cats' paths never cover) and the turn's other
## cards don't play (escaped). A blast at the end of the turn, it shrugs off where it is.
func _spend_life() -> bool:
	var skill := Items.Skill.NINE_LIVES
	if not board.is_caught() or skill_charges.get(skill, 0) <= 0 or not run.has_skill(skill):
		return false
	skill_charges[skill] -= 1
	var left := skill_charges[skill]
	if board.is_blasted():
		board.blasted_by = null
		board.queue_redraw()
		BugReport.note("  NINE LIVES: shrugged off the blast (%d left this round)" % left)
		status_label.text = "Nine Lives! The mouse shrugged off the blast."
	else:
		var caught_at := board.mouse_cell
		escaped = true
		# A floorboard the mouse broke leaving its start would leave it standing over a gap.
		if turn_start_cell in board.broken:
			board.broken.erase(turn_start_cell)
			board.floorboards.append(turn_start_cell)
		board.mouse_cell = turn_start_cell
		if board.animate:
			var tween := board.create_tween()
			tween.tween_property(board, "mouse_pos", Vector2(turn_start_cell), Board.JUMP_TIME * 1.5) \
				.set_trans(Tween.TRANS_SINE)
			await tween.finished
		else:
			board.mouse_pos = Vector2(turn_start_cell)
		BugReport.note("  NINE LIVES: escaped from %s back to %s (%d left this round)" % [caught_at,
			turn_start_cell, left])
		status_label.text = "Nine Lives! The mouse escaped back to where it started the turn."
	_flash_skill(skill)
	_refresh_skills()
	return true


## Moves the mouse for one card: its slot's effect plays first, then the card's stamp. When both
## move the mouse (a BURN slot and a SLIDE stamp), it makes both moves, in that order. When neither
## does, it steps once. STRIDE steps as many cells as the card is set to, and SCURRY steps twice when
## the card is the first of the turn to play (first). Returns true if the round is over.
func _play(slot: CardSlot, card: Card, first: bool) -> bool:
	var dir := _play_dir(slot, card)
	var moved := false
	for effect: CardSlot.Effect in [_slot_effect(slot, card), card.stamp]:
		match effect:
			CardSlot.Effect.DOUBLE, CardSlot.Effect.GAMBLE, CardSlot.Effect.BURN, CardSlot.Effect.LEAP, \
					CardSlot.Effect.SLIDE, CardSlot.Effect.WRAP, CardSlot.Effect.TUNNEL:
				moved = true
				if await _move(effect, dir):
					return true
				if board.stuck:
					return false
			CardSlot.Effect.SCURRY:
				if first:
					moved = true
					if await _steps(dir, 2):
						return true
					if board.stuck:
						return false
			CardSlot.Effect.STRIDE:
				moved = true
				if await _steps(dir, card.data.stride):
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
				var now := _path_distance(board.mouse_cell, board.cheese_cell)
				if _path_distance(board.step_target(board.mouse_cell, dir), board.cheese_cell) >= now:
					card.modulate = FIZZLED
					BugReport.note("  Slot %d SNIFF %s fizzled" % [slot.number, Card.NAMES[dir]])
					status_label.text = "Sniff: %s isn't toward the cheese, so the mouse stays put." % Card.NAMES[dir]
					if board.animate:
						Sfx.play(Sfx.Sound.FIZZLE)
						# Not process_always, so it waits while the F12 bug report has the game paused.
						await get_tree().create_timer(Board.STEP_TIME * 2, false).timeout
					return false
	if moved:
		return false
	return await _single_step(dir)


## A card's move when neither its slot nor its stamp moves the mouse: a step, or two with SPRINT on,
## each a TUNNEL jump with BURROW on. Returns true if the round is over.
func _single_step(dir: Card.Dir) -> bool:
	var sprint := Items.Skill.SPRINT in active_skills
	var burrow := Items.Skill.BURROW in active_skills
	if board.animate:
		for skill: Items.Skill in [Items.Skill.SPRINT, Items.Skill.BURROW]:
			if skill in active_skills:
				_flash_skill(skill)
	if not burrow:
		return await _steps(dir, 2 if sprint else 1)
	for i in 2 if sprint else 1:
		if await _move(CardSlot.Effect.TUNNEL, dir) and not _survive_trap():
			return true
		if board.stuck:
			break
	return false


## Makes the move of an effect that changes the distance. Returns true if the round is over.
func _move(effect: CardSlot.Effect, dir: Card.Dir) -> bool:
	match effect:
		CardSlot.Effect.DOUBLE:
			return await _steps(dir, 2)
		CardSlot.Effect.GAMBLE, CardSlot.Effect.BURN:
			return await _steps(dir, 3)
		CardSlot.Effect.LEAP, CardSlot.Effect.TUNNEL:
			last_dir = dir
			return await board.jump(Card.OFFSETS[dir] * 2, dir, effect == CardSlot.Effect.TUNNEL)
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


## Pays CHEST_CRUMBS.
func _open_chest(cell: Vector2i) -> void:
	Sfx.play(Sfx.Sound.CHEST)
	run.crumbs += CHEST_CRUMBS
	_add_points(Score.CHEST_POINTS, cell)
	var text := "+%d" % CHEST_CRUMBS
	chest_note = "Chest! %d crumbs." % CHEST_CRUMBS
	_refresh_hud()
	chest_rewards.append(text)
	status_label.text = chest_note
	BugReport.note("  Opened a chest at %s: %s" % [cell, text])


## After a boss: Boss.HAND_GAINED more cards in hand and Boss.SLOTS_GAINED more card slots for the rest
## of the run, from the next round, up to Run.MAX_HAND_SIZE and Run.MAX_SLOTS (and never more slots than
## cards). Returns a win panel line for each that grew.
func _boss_upgrade() -> PackedStringArray:
	var lines := PackedStringArray()
	var hand := mini(run.hand_size + Boss.HAND_GAINED, Run.MAX_HAND_SIZE)
	var count := mini(run.slots + Boss.SLOTS_GAINED, mini(hand, Run.MAX_SLOTS))
	if count > run.slots:
		lines.append("+%d card slot%s (%d now)" % [count - run.slots, "" if count - run.slots == 1 else "s", count])
	if hand > run.hand_size:
		lines.append("+%d card%s in hand (%d now)" % [hand - run.hand_size, "" if hand - run.hand_size == 1 else "s", hand])
	run.slots = count
	run.hand_size = hand
	BugReport.note("  Boss upgrade: %d slots, hand size %d" % [run.slots, run.hand_size])
	return lines


## The slot's effect on the card in it (or none): no effect for a STEADY card, which plays as if
## its slot were plain.
func _slot_effect(slot: CardSlot, card: Card) -> CardSlot.Effect:
	return CardSlot.Effect.NONE if card and card.stamp == CardSlot.Effect.STEADY else slot.effect


## The direction the card in slot moves the mouse: its own for a STEADY card.
func _play_dir(slot: CardSlot, card: Card) -> Card.Dir:
	return card.dir if card.stamp == CardSlot.Effect.STEADY else slot.play_dir(card.dir)


## Slots in the order they play: left to right, with LAST slots moved to the end.
func _play_order() -> Array[CardSlot]:
	var order: Array[CardSlot] = []
	var last: Array[CardSlot] = []
	for slot in slots:
		if _slot_effect(slot, slot.get_card()) == CardSlot.Effect.LAST:
			last.append(slot)
		else:
			order.append(slot)
	order.append_array(last)
	return order


## Gives each slot a new effect for this turn. About half the slots stay plain.
func _roll_effects() -> void:
	var pool: Array = CardSlot.Effect.values()
	pool.erase(CardSlot.Effect.NONE)
	for effect in CardSlot.STAMP_ONLY:
		pool.erase(effect)
	if run.has(Items.Trinket.FOUR_LEAF_CLOVER):
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
	Sfx.play(Sfx.Sound.USE)
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
	Sfx.play(Sfx.Sound.DISCARD)
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
	card.set_on_click = true
	card.stamp_set.connect(refresh_preview)
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
			Sfx.play(Sfx.Sound.CARD_PLACE)
			BugReport.note("%s -> slot %d" % [card.data.label(), slot.number])
		else:
			Sfx.play(Sfx.Sound.DENIED)
	else:
		card.reparent(hand_box, false)
		Sfx.play(Sfx.Sound.CARD_PLACE, HAND_PITCH)
		BugReport.note("%s -> hand" % card.data.label())
	refresh_preview()


func _on_card_dropped_on_slot(card: Card, slot: CardSlot) -> void:
	_place_in_slot(card, slot)


func _on_card_dropped_on_card(card: Card, target: Card) -> void:
	var parent := target.get_parent()
	if parent is CardSlot:
		_place_in_slot(card, parent)
	else:
		# In the hand, it takes the target's place, so the hand can be put in order (PACK RAT keeps
		# the leftmost cards).
		_drop_on_hand(Vector2.ZERO, card)
		hand_box.move_child(card, target.get_index())


## Puts a card in a slot. A card already there swaps to where the incoming card came from.
func _place_in_slot(card: Card, slot: CardSlot) -> void:
	if busy or card.get_parent() == slot or slot.effect == CardSlot.Effect.BLOCKED:
		return
	var existing := slot.get_card()
	if existing:
		existing.reparent(card.get_parent(), false)
	card.reparent(slot, false)
	Sfx.play(Sfx.Sound.CARD_PLACE)
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
	Sfx.play(Sfx.Sound.CARD_PLACE, HAND_PITCH)
	BugReport.note("%s -> hand" % data.data.label())
	refresh_preview()


func _on_key_collected(cell: Vector2i) -> void:
	Sfx.play(Sfx.Sound.KEY)
	BugReport.note("  Picked up a key at %s (%d held)" % [cell, board.keys_held])
	status_label.text = "A key! Walk into a locked door to open it."
	_refresh_hud()


func _on_door_unlocked(_edge: Vector3i) -> void:
	Sfx.play(Sfx.Sound.UNLOCK)
	status_label.text = "The key opened the door."
	_refresh_hud()


func _on_crumb_collected(cell: Vector2i) -> void:
	var worth := 1 + (SALT_SHAKER_CRUMBS if run.has(Items.Trinket.SALT_SHAKER) else 0)
	Sfx.play(Sfx.Sound.CRUMB)
	run.crumbs += worth
	round_crumbs += worth
	_add_points(Score.CRUMB_POINTS, cell)
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
	var round_text := "Endless round %d" % run.round_number if run.endless or run.round_number > Run.GOAL_ROUNDS \
		else "Round %d of %d" % [run.round_number, Run.GOAL_ROUNDS]
	# The label wraps to fit beside the title. Non-breaking spaces keep each part on one line.
	var parts := PackedStringArray([round_text, "Turn %d of %d" % [turn, turn_limit], "%d crumbs" % run.crumbs])
	hud_label.text = " · ".join(Array(parts).map(func(part: String) -> String: return part.replace(" ", " ")))
	_key_label.visible = board.keys_held > 0 or not board.keys.is_empty() or not board.doors.is_empty()
	_key_label.text = "· %d key%s" % [board.keys_held, "" if board.keys_held == 1 else "s"]
	_score_label.text = "Score %d / %d" % [round_score, score_target]
	if busy:
		_score_label.text += "  ·  this turn %d × %d" % [turn_points, turn_mult]
	elif last_turn_score:
		_score_label.text += "  ·  last turn %s" % last_turn_score
	_score_label.add_theme_color_override("font_color",
		Color("7ee08a") if round_score >= score_target else Score.COLOR)
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


## Fills the Items.SKILL_SLOTS skill slots above the card slots with the run's skills, the rest empty,
## showing each one's level, the charges it has left this round and whether it's on this turn. A skill
## new to the run (drafted, or from the dev menu) starts with full charges; one the run lost turns off.
func _refresh_skills() -> void:
	for skill in run.skills:
		if skill not in skill_charges:
			skill_charges[skill] = Items.skill_charges(skill, run.skill_level(skill))
	for skill in active_skills.duplicate():
		if not run.has_skill(skill):
			active_skills.erase(skill)
	board.warp = Items.Skill.WARP in active_skills
	for child in skill_row.get_children():
		skill_row.remove_child(child)
		child.queue_free()
	for i in Items.SKILL_SLOTS:
		var slot := SkillSlot.new()
		if i < run.skills.size():
			var skill := run.skills[i]
			slot.skill = skill
			slot.level = run.skill_level(skill)
			slot.charges = skill_charges[skill]
			slot.active = skill in active_skills
			slot.pressed.connect(use_skill.bind(skill))
		skill_row.add_child(slot)


## Spends a charge of an ACTIVE skill to turn it on for this turn, before Lock In. Does nothing while
## the cards play, when it has no charges left or when it's already on. A PASSIVE or AUTO skill says
## that it works by itself.
func use_skill(skill: Items.Skill) -> void:
	if busy or win_panel.visible or shop.visible or skill_draft.visible or not run.has_skill(skill):
		return
	var skill_name := Items.skill_name(skill).capitalize()
	if Items.skill_use(skill) != Items.SkillUse.ACTIVE:
		status_label.text = "%s works by itself." % skill_name
		return
	if skill in active_skills:
		status_label.text = "%s is already on this turn." % skill_name
		return
	if skill_charges.get(skill, 0) <= 0:
		status_label.text = "%s has no charges left this round." % skill_name
		return
	skill_charges[skill] -= 1
	active_skills.append(skill)
	match skill:
		Items.Skill.WARP:
			status_label.text = "Warp: the mouse wraps round the board's edges this turn."
		Items.Skill.SPRINT:
			status_label.text = "Sprint: every card that would take one step takes two this turn."
		Items.Skill.BURROW:
			status_label.text = "Burrow: every card that would take one step digs 2 cells, under walls, this turn."
	BugReport.note("Used %s (%d charge%s left this round)" % [Items.skill_name(skill), skill_charges[skill],
		"" if skill_charges[skill] == 1 else "s"])
	_refresh_skills()
	_flash_skill(skill)
	refresh_preview()


## Turns off the skills used this turn, once its cards have played.
func _end_skills() -> void:
	if active_skills.is_empty():
		return
	BugReport.note("Skills wore off: %s" % ", ".join(active_skills.map(
		func(skill: int) -> String: return Items.skill_name(skill))))
	active_skills.clear()
	board.warp = false
	_refresh_skills()


## Lights up the slot holding skill, when it does something.
func _flash_skill(skill: Items.Skill) -> void:
	var i := run.skills.find(skill)
	if i != -1 and i < skill_row.get_child_count():
		Sfx.play(Sfx.Sound.SKILL)
		(skill_row.get_child(i) as SkillSlot).flash()


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
		button.tooltip_text = "%s %s to use." % [info[1], "Tap" if DisplayServer.is_touchscreen_available() else "Click"]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = busy or win_panel.visible
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Items.CONSUMABLE_COLOR)
		button.pressed.connect(use_consumable.bind(i))
		button.set_meta(Sfx.NO_CLICK, true)
		pouch_row.add_child(button)


func _view_pile(title: String, cards: Array[CardData]) -> void:
	BugReport.note("Viewed %s" % title.to_lower())
	pile_viewer.show_pile(title, cards)


# Dev menu: shortcuts the F2 DevMenu calls. The menu logs each one with a "DEV:" note.

## Gives every skill the run has its full charges for this round back.
func refill_skill_charges() -> void:
	skill_charges.clear()
	_refresh_skills()


## Redraws everything that shows the run: the HUD, pouch, trinkets, skills and an open shop.
func refresh_ui() -> void:
	_refresh_hud()
	_refresh_pouch()
	_refresh_trinkets()
	_refresh_skills()
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


## Ends the round as a win: the mouse jumps onto the cheese, then the usual payout and the shop. The
## score is raised to the target, so a boss round counts as won.
func win_round() -> void:
	if busy or win_panel.visible or shop.visible:
		return
	_clear_cards()
	out_of_time = false
	round_score = maxi(round_score, score_target)
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


## Sets the run's card slots and hand size, as beating a boss does. Mid-round, the cards held go to the
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
	kept.clear()
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
		elif _short_of_boss_target():
			outcome = "  (short of the boss's score target)"
		else:
			outcome = "  (won)"
	elif shop.visible:
		outcome = "  (shopping)"
	lines.append("Round %d, turn %d of %d%s%s, %d discards left, %dx%d board" % [run.round_number, turn,
		turn_limit, "  (moving)" if busy else "", outcome, discards_left, board.grid, board.grid])
	lines.append("Boss: %s, next boss %s, %d beaten" % [Boss.INFO[run.boss][0] if run.boss != -1 else "-",
		Boss.INFO[run.next_boss][0], run.bosses_beaten])
	lines.append("Score %d / %d, this turn %d x %d, last turn %s" % [round_score, score_target, turn_points,
		turn_mult, last_turn_score if last_turn_score else "-"])
	var trinket_names := PackedStringArray()
	for trinket in run.trinkets:
		trinket_names.append(Items.TRINKETS[trinket][0])
	var skill_names := PackedStringArray()
	for skill in run.skills:
		var level := run.skill_level(skill)
		var total := Items.skill_charges(skill, level)
		skill_names.append("%s%s%s" % [Items.skill_title(skill, level),
			" %d/%d" % [skill_charges.get(skill, 0), total] if total > 0 else "",
			" (on)" if skill in active_skills else ""])
	var pouch_names := PackedStringArray()
	for item in run.pouch:
		pouch_names.append(Items.CONSUMABLES[item][0])
	lines.append("Crumbs %d (%d picked up this round), trinkets: %s, skills: %s, pouch: %s%s" % [run.crumbs,
		round_crumbs, ", ".join(trinket_names) if trinket_names else "-",
		", ".join(skill_names) if skill_names else "-", ", ".join(pouch_names) if pouch_names else "-",
		", thick fur broke %d" % traps_broken if traps_broken > 0 else ""])
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
	lines.append("Keep hand: %s" % ("on" if keep_hand else "off"))
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


## Lays down Difficulty.walls() runs of wall (see _wall_run), each the one of WALL_TRIES that most
## lengthens the way from the mouse to the cheese, then the way to the most cells. A run that does
## neither, or lengthens the way to fewer than WALL_MIN_REACH of the cells, is left out, so every wall
## is in the way of something. All together they lengthen the way to the cheese by at most WALL_DETOUR
## of the board's side (_longest_way), so the board doesn't turn into a maze. A run is cut short rather
## than cut any cell off from the mouse (with the traps' help), so the cheese and every crumb can always
## be reached and no cat gets shut in.
func _place_walls(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Dictionary[Vector3i, bool]:
	# Built on the board so its pathfinding can check each run.
	board.walls = {}
	board.traps = traps
	var open_cells := board.grid * board.grid - traps.size()
	_longest_way = board.distances_from(mouse)[cheese] + ceili(board.grid * WALL_DETOUR)
	for i in Difficulty.walls(run.round_number):
		var before := board.distances_from(mouse)
		var best: Array[Vector3i] = []
		var best_score := 0.0
		for attempt in WALL_TRIES:
			var walls := _wall_run()
			var after := _lay_run(walls, mouse, open_cells)
			for wall in walls:
				board.walls.erase(wall)
			if after.is_empty() or after[cheese] > _longest_way:
				continue
			var longer := 0
			for cell in after:
				if after[cell] > before[cell]:
					longer += 1
			var gain: int = after[cheese] - before[cheese]
			if gain == 0 and longer < open_cells * WALL_MIN_REACH:
				continue
			var score := gain + longer / float(open_cells)
			if score > best_score:
				best = walls
				best_score = score
		for wall in best:
			board.walls[wall] = true
	return board.walls


## Finds a place to hide the chest in: a nook behind a bridge (see _nooks), or a pocket (see _pockets),
## the one farthest off the way to the cheese. The chasms and walls laid so far may have made one. If
## not, tries POCKET_TRIES U-shaped runs of wall (see _wall_run) that keep the way to the cheese within
## _longest_way, and lays the one that makes the farthest pocket. Returns the cell, or NO_CELL with
## nothing laid when no run makes one.
func _place_pocket(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Vector2i:
	var nooks := _nooks(mouse, cheese)
	if not nooks.is_empty():
		return _farthest(nooks)
	var pockets := _pockets(board.distances_from(mouse), mouse, cheese)
	if not pockets.is_empty():
		return _farthest(pockets)
	var open_cells := board.grid * board.grid - traps.size() - board.chasms.size()
	var best: Array[Vector3i] = []
	var best_cell := NO_CELL
	var best_detour := 0
	for attempt in POCKET_TRIES:
		var walls := _wall_run(true)
		var from_mouse := _lay_run(walls, mouse, open_cells)
		if not from_mouse.is_empty() and from_mouse[cheese] <= _longest_way:
			pockets = _pockets(from_mouse, mouse, cheese)
		else:
			pockets.clear()
		for wall in walls:
			board.walls.erase(wall)
		if pockets.is_empty():
			continue
		var cell := _farthest(pockets)
		if pockets[cell] > best_detour:
			best = walls
			best_cell = cell
			best_detour = pockets[cell]
	for wall in best:
		board.walls[wall] = true
	return best_cell


## Pockets: dead ends (see _dead_end) at least CHEST_MIN_DISTANCE from the mouse that make going by them
## on the way to the cheese take CHEST_MIN_DETOUR to CHEST_MAX_DETOUR more steps, given the steps from
## the mouse to each cell, with the locks open. Maps each to those steps.
func _pockets(from_mouse: Dictionary[Vector2i, int], mouse: Vector2i, cheese: Vector2i) -> Dictionary[Vector2i, int]:
	var from_cheese := board.distances_from(cheese, false, Board.Belts.TO, Board.Locks.OPEN)
	var spacing := mini(CHEST_MIN_DISTANCE, board.grid - 2)
	var pockets: Dictionary[Vector2i, int] = {}
	for cell in from_mouse:
		var detour: int = from_mouse[cell] + from_cheese.get(cell, CHEST_MAX_DETOUR) - from_mouse[cheese]
		if detour >= CHEST_MIN_DETOUR and detour <= CHEST_MAX_DETOUR and cell != cheese \
				and _distance(cell, mouse) >= spacing and _dead_end(cell):
			pockets[cell] = detour
	return pockets


## The pocket off pockets (see _pockets) with the most steps.
func _farthest(pockets: Dictionary[Vector2i, int]) -> Vector2i:
	var best := NO_CELL
	for cell in pockets:
		if best == NO_CELL or pockets[cell] > pockets[best]:
			best = cell
	return best


## True when there's only one way onto the cell: walls, the board's edge, traps and the like close off
## the other three sides.
func _dead_end(cell: Vector2i) -> bool:
	var ways := 0
	for offset: Vector2i in Card.OFFSETS.values():
		if board._can_step(cell, cell + offset) and cell + offset not in board.traps:
			ways += 1
	return ways == 1


## Lays the run of walls on the board, dropping walls off its end while it cuts any cell off from the
## mouse, down to WALL_RUN_MIN. Returns the steps from the mouse to each cell with what's left of the
## run laid, and leaves that laid, or returns nothing and lays nothing when no part of it fits.
func _lay_run(walls: Array[Vector3i], mouse: Vector2i, open_cells: int) -> Dictionary[Vector2i, int]:
	for wall in walls:
		board.walls[wall] = true
	while walls.size() >= WALL_RUN_MIN:
		var distances := board.distances_from(mouse)
		if distances.size() == open_cells:
			return distances
		board.walls.erase(walls.pop_back())
	for wall in walls:
		board.walls.erase(wall)
	walls.clear()
	var none: Dictionary[Vector2i, int] = {}
	return none


## A random run of wall: a walk along the grid lines between cells, WALL_RUN_MIN to WALL_SPAN of the
## board's side long (or to longest, if set), that turns a corner at most once. With pocket, it's a U
## instead: POCKET_DEPTH along, one across, and back, around a dead end a cell wide. It starts on the
## board's edge heading in, at the loose end of a wall, door or gate, or anywhere inside, and stops on
## reaching the edge or another wall, so walls join up rather than cross. Empty if that leaves it
## shorter than WALL_RUN_MIN.
func _wall_run(pocket := false, longest := 0) -> Array[Vector3i]:
	var walls: Array[Vector3i] = []
	var size := board.grid
	# Points are cell corners: (x, y) is the top-left corner of cell (x, y).
	var point := Vector2i(randi_range(1, size - 1), randi_range(1, size - 1))
	var offset: Vector2i = Card.OFFSETS.values().pick_random()
	var ends := _wall_ends()
	var start := randf()
	if start < 0.5:
		# On the edge the run heads away from.
		if offset.x != 0:
			point.x = 0 if offset.x > 0 else size
		else:
			point.y = 0 if offset.y > 0 else size
	elif start < 0.75 and not ends.is_empty():
		point = ends.pick_random()
	# Which way each wall goes from the last: a quarter turn one way or the other.
	var turn: int = [1, -1].pick_random()
	var offsets: Array[Vector2i] = []
	if pocket:
		var depth := randi_range(POCKET_DEPTH_MIN, POCKET_DEPTH_MAX)
		for leg: int in [depth, 1, depth]:
			for i in leg:
				offsets.append(offset)
			offset = Vector2i(-offset.y, offset.x) * turn
	else:
		var turned := false
		if longest == 0:
			longest = roundi(size * WALL_SPAN)
		for i in randi_range(WALL_RUN_MIN, maxi(longest, WALL_RUN_MIN)):
			if i > 0 and not turned and randf() < WALL_TURN_CHANCE:
				offset = Vector2i(-offset.y, offset.x) * turn
				turned = true
			offsets.append(offset)
	for step in offsets:
		offset = step
		var edge := _grid_line(point, point + offset)
		if edge == NO_EDGE or _is_wall(edge):
			break
		walls.append(edge)
		point += offset
		if _on_rim(point) or _touches_wall(point):
			break
	if walls.size() < WALL_RUN_MIN:
		walls.clear()
	return walls


## The edge key for the stretch of grid line between two neighboring cell corners, or NO_EDGE when it
## runs along the board's edge or off the board.
func _grid_line(a: Vector2i, b: Vector2i) -> Vector3i:
	var low := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	# A horizontal edge is the top of the cell to its lower right, a vertical one its left.
	if a.y == b.y:
		if low.y <= 0 or low.y >= board.grid or low.x < 0 or low.x >= board.grid:
			return NO_EDGE
		return Vector3i(low.x, low.y - 1, 1)
	if low.x <= 0 or low.x >= board.grid or low.y < 0 or low.y >= board.grid:
		return NO_EDGE
	return Vector3i(low.x - 1, low.y, 0)


## True when a wall, a locked door or a gate is on the edge.
func _is_wall(edge: Vector3i) -> bool:
	return board.walls.has(edge) or board.doors.has(edge) or board.gates.has(edge)


func _on_rim(point: Vector2i) -> bool:
	return point.x == 0 or point.y == 0 or point.x == board.grid or point.y == board.grid


## True when a wall, a locked door or a gate meets the cell corner.
func _touches_wall(point: Vector2i) -> bool:
	for offset: Vector2i in Card.OFFSETS.values():
		var edge := _grid_line(point, point + offset)
		if edge != NO_EDGE and _is_wall(edge):
			return true
	return false


## Cell corners inside the board where a wall, a locked door or a gate ends without meeting another.
func _wall_ends() -> Array[Vector2i]:
	var meeting: Dictionary[Vector2i, int] = {}
	for edges: Dictionary in [board.walls, board.doors, board.gates]:
		for edge: Vector3i in edges:
			# Below cell (x, y) runs from its lower left corner, right of it from its upper right.
			var first := Vector2i(edge.x, edge.y + 1) if edge.z == 1 else Vector2i(edge.x + 1, edge.y)
			for point: Vector2i in [first, Vector2i(edge.x + 1, edge.y + 1)]:
				meeting[point] = meeting.get(point, 0) + 1
	var ends: Array[Vector2i] = []
	for point in meeting:
		if meeting[point] == 1 and not _on_rim(point):
			ends.append(point)
	return ends


## Lays down Difficulty.chasms() chasms (see _chasm_run), each the one of CHASM_TRIES that does most,
## like the walls (see _place_walls). A chasm that cuts part of the board off from the mouse gets a
## bridge across a straight stretch of it (see _bridge_spots), which makes the bridge a choke point:
## the only way over to the cheese, or into a nook that gets the chest or a crumb (see _nooks). That's
## worth CHASM_CHOKE_SCORE, and the bridge kept is the one that most lengthens the way to the cheese. A
## chasm one bridge can't join back up is left out. Any other chasm is only laid if it lengthens the way
## to the cheese, or to WALL_MIN_REACH of the cells, like a wall. All together the chasms lengthen the
## way to the cheese by at most CHASM_DETOUR of the board's side on top of the walls (_longest_way).
## Returns the chasms laid, each as its cells, bridge and all.
func _place_chasms(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Array[Array]:
	var chasms: Array[Array] = []
	var count := Difficulty.chasms(run.round_number)
	if count == 0:
		return chasms
	_longest_way = maxi(_longest_way, board.distances_from(mouse)[cheese] + ceili(board.grid * CHASM_DETOUR))
	for i in count:
		var open_cells := board.grid * board.grid - traps.size() - board.chasms.size()
		var before := board.distances_from(mouse)
		var best: Array[Vector2i] = []
		var best_bridge := NO_CELL
		var best_score := 0.0
		for attempt in CHASM_TRIES:
			var cells := _chasm_run(mouse, cheese, traps)
			if cells.is_empty():
				continue
			board.chasms.append_array(cells)
			var left := open_cells - cells.size()
			var choke := board.distances_from(mouse).size() != left
			var bridges: Array[Vector2i] = [NO_CELL]
			if choke:
				bridges = _bridge_spots(cells)
				left += 1
			for bridge in bridges:
				board.chasms.erase(bridge)
				var after := board.distances_from(mouse)
				if choke:
					board.chasms.append(bridge)
				if after.size() != left or after[cheese] > _longest_way:
					continue
				var longer := 0
				for cell in after:
					if after[cell] > before[cell]:
						longer += 1
				var gain: int = after[cheese] - before[cheese]
				if not choke and gain == 0 and longer < open_cells * WALL_MIN_REACH:
					continue
				var score := gain + longer / float(open_cells) + (CHASM_CHOKE_SCORE if choke else 0.0)
				if score > best_score:
					best = cells
					best_bridge = bridge
					best_score = score
			for cell in cells:
				board.chasms.erase(cell)
		if best.is_empty():
			continue
		for cell in best:
			if cell != best_bridge:
				board.chasms.append(cell)
		if best_bridge != NO_CELL:
			board.bridges.append(best_bridge)
		chasms.append(best)
	return chasms


## The cells of a chasm a bridge can go on: where it runs straight, with floor and no wall on both
## sides across it.
func _bridge_spots(cells: Array[Vector2i]) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for i in range(1, cells.size() - 1):
		var along := cells[i] - cells[i - 1]
		if cells[i + 1] - cells[i] != along:
			continue
		var across := Vector2i(along.y, along.x)
		if [cells[i] + across, cells[i] - across].all(func(side: Vector2i) -> bool:
				return board._in_bounds(side) and not board.is_blocked(side) and not board.has_wall(cells[i], side)):
			spots.append(cells[i])
	return spots


## A random chasm: a walk of CHASM_MIN cells up to CHASM_SPAN of the board's side, a cell wide, that
## turns a corner at most once. Like a run of wall (see _wall_run) it starts on the board's edge heading
## in, beside a wall or a chasm heading away from it, or anywhere inside, and stops on reaching the
## edge, a wall or another chasm (even diagonally), so chasms join up with the walls and each other into
## dividers. It stops short of the mouse, the cheese, a trap and a bridge. Empty if that leaves it
## shorter than CHASM_MIN.
func _chasm_run(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var size := board.grid
	var cell := _random_cell()
	var offset: Vector2i = Card.OFFSETS.values().pick_random()
	var starts := _chasm_starts()
	var start := randf()
	if start < 0.5:
		# On the edge the run heads away from.
		if offset.x != 0:
			cell.x = 0 if offset.x > 0 else size - 1
		else:
			cell.y = 0 if offset.y > 0 else size - 1
	elif start < 0.75 and not starts.is_empty():
		var from: Array = starts.pick_random()
		cell = from[0]
		offset = from[1]
	# Which way the corner turns: a quarter turn one way or the other.
	var turn: int = [1, -1].pick_random()
	var turned := false
	for i in randi_range(CHASM_MIN, maxi(roundi(size * CHASM_SPAN), CHASM_MIN)):
		if i > 0:
			if not turned and randf() < CHASM_TURN_CHANCE:
				offset = Vector2i(-offset.y, offset.x) * turn
				turned = true
			if board.has_wall(cell, cell + offset):
				break
			cell += offset
		if not board._in_bounds(cell) or cell == mouse or cell == cheese or cell in traps or board.is_blocked(cell) \
				or cell in board.bridges:
			break
		cells.append(cell)
		var on_edge := cell.x == 0 or cell.y == 0 or cell.x == size - 1 or cell.y == size - 1
		if i > 0 and (on_edge or _touches_chasm(cell, cells)):
			break
	if cells.size() < CHASM_MIN:
		cells.clear()
	return cells


## Where a chasm can start beside a wall or a chasm: [cell, offset] pairs, the offset heading straight
## away from it.
func _chasm_starts() -> Array:
	var starts := []
	for edge: Vector3i in board.walls:
		var sides := _edge_cells(edge)
		starts.append([sides[0], sides[0] - sides[1]])
		starts.append([sides[1], sides[1] - sides[0]])
	for chasm in board.chasms:
		for offset: Vector2i in Card.OFFSETS.values():
			starts.append([chasm + offset, offset])
	return starts


## True when a chasm or a bridge that isn't one of the run's cells is next to the cell, even diagonally.
func _touches_chasm(cell: Vector2i, run_cells: Array[Vector2i]) -> bool:
	for x in range(-1, 2):
		for y in range(-1, 2):
			var next := cell + Vector2i(x, y)
			if next not in run_cells and (next in board.chasms or next in board.bridges):
				return true
	return false


## Nooks: the parts of the board, but the cheese's, that a bridge is the only way into from the mouse,
## with the locks open. Maps the cell in each farthest from the mouse and off the floor tiles, if it's
## at least CHEST_MIN_DISTANCE from the mouse, to its steps from the mouse.
func _nooks(mouse: Vector2i, cheese: Vector2i) -> Dictionary[Vector2i, int]:
	var open := Board.Locks.OPEN
	var from_mouse := board.distances_from(mouse, false, Board.Belts.FROM, open)
	var spacing := mini(CHEST_MIN_DISTANCE, board.grid - 2)
	var nooks: Dictionary[Vector2i, int] = {}
	for bridge in board.bridges:
		board.chasms.append(bridge)
		var shut := board.distances_from(mouse, false, Board.Belts.FROM, open)
		board.chasms.erase(bridge)
		if not shut.has(cheese):
			continue
		var far := NO_CELL
		for cell in from_mouse:
			if not shut.has(cell) and cell != cheese and not board.has_tile(cell) \
					and (far == NO_CELL or from_mouse[cell] > from_mouse[far]):
				far = cell
		if far != NO_CELL and _distance(far, mouse) >= spacing:
			nooks[far] = from_mouse[far]
	return nooks


## Gives each chasm, with CHASM_PAD_CHANCE, a jump pad beside it that throws the mouse across: of the
## ones that would, the one that saves the most steps on the way from the mouse to where it lands, if
## that's at least CHASM_PAD_SAVING. The pad and its landing are off the cheese, the traps, the floor
## tiles and the items.
func _place_chasm_pads(chasms: Array[Array], mouse: Vector2i, cheese: Vector2i) -> void:
	for cells in chasms:
		if randf() >= CHASM_PAD_CHANCE:
			continue
		var from_mouse := board.distances_from(mouse)
		var best_pad := NO_CELL
		var best_offset := Vector2i.ZERO
		var best_saving := CHASM_PAD_SAVING - 1
		for cell: Vector2i in cells:
			if cell not in board.chasms:
				continue
			for offset: Vector2i in Card.OFFSETS.values():
				var pad := cell - offset
				if not from_mouse.has(pad) or pad == mouse or pad == cheese or board.has_tile(pad) \
						or board.has_item(pad):
					continue
				for reach in range(PAD_MIN, PAD_MAX + 1):
					var landing := pad + offset * reach
					if board.jump_landing(pad, offset * reach) != landing or not from_mouse.has(landing) \
							or landing == cheese or board.has_tile(landing) or board.has_item(landing):
						continue
					var saving: int = from_mouse[landing] - from_mouse[pad] - 1
					if saving > best_saving:
						best_pad = pad
						best_offset = offset * reach
						best_saving = saving
		if best_pad != NO_CELL:
			board.pads[best_pad] = best_offset


## Lays down the round's locked doors, each with a key, and its switches: a gate, the pressure plate
## that opens it and a crate to push onto the plate. Each lock tries the jobs (LockJob) in turn and is
## laid for the first that fits, or left out:
## - VAULT: the lock shuts the one way into the dead end the round's chest is in (see _vault_lock).
## - GOAL, in a round that rolls LOCK_GOAL_CHANCE, until one door fits it: the lock is the only way to
##   the cheese. Never a gate: a crate pushed into a corner would shut the cheese away for good.
## - SHORTCUT: going through the lock saves at least LOCK_MIN_SAVING steps on the way to the cheese,
##   counting the way by its key or crate.
## A GOAL or SHORTCUT lock sits in a run of wall (see _lock_run). Keys, plates and crates are in reach
## with every lock shut, each where it adds least to the way (see _place_lock). A plate is never next to
## its gate, so the mouse needs the crate to keep the gate open. The crate starts in a straight line
## from the plate, and the cells it's pushed along, the one the mouse pushes from, and the cells either
## side of each lock are kept clear (_kept_clear).
func _place_locks(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> void:
	_kept_clear.clear()
	_shortcuts.clear()
	var free := func(cell: Vector2i) -> bool:
		return board._in_bounds(cell) and cell != mouse and cell != cheese and cell not in traps \
			and not board.has_tile(cell) and not board.has_item(cell) and cell not in _kept_clear
	# Whether a door still has to be the only way to the cheese.
	var goal := randf() < LOCK_GOAL_CHANCE
	# Switches first, so a crate puzzle gets first claim on the chest.
	for gate: bool in [true, false]:
		var count := Difficulty.switches(run.round_number) if gate else Difficulty.doors(run.round_number)
		for i in count:
			var jobs: Array[LockJob] = [LockJob.VAULT]
			if not gate and goal:
				jobs.append(LockJob.GOAL)
			jobs.append(LockJob.SHORTCUT)
			for job in jobs:
				if _place_lock(job, gate, mouse, cheese, free):
					goal = goal and job != LockJob.GOAL
					break


## Lays a lock for job (see _place_locks): a gate with its plate and crate, or else a door with its key.
## Out of ITEM_TRIES cells, the key or crate goes where it adds least to the way (see _item_steps): for
## a SHORTCUT, on through the lock to the cheese, else to the lock. A lock never takes a key, plate,
## crate or crate lane out of reach with every lock shut, and a SHORTCUT takes nothing out of reach.
## Returns false, laying nothing, when the job doesn't fit. free says which cells a key, plate or crate
## can go on.
func _place_lock(job: LockJob, gate: bool, mouse: Vector2i, cheese: Vector2i, free: Callable) -> bool:
	var walls: Array[Vector3i] = []
	var lock := NO_EDGE
	if job == LockJob.VAULT:
		lock = _vault_lock()
	else:
		walls = _lock_run(job, mouse, cheese)
		if not walls.is_empty():
			lock = walls.pop_back()
	if lock == NO_EDGE:
		return false
	var reach := board.distances_from(mouse)
	for wall in walls:
		board.walls[wall] = true
	var way := _shut_way(lock, mouse, cheese)
	if gate:
		board.gates[lock] = board.plates.size()
	else:
		board.doors[lock] = true
	# With every lock shut, so the key or crate is in reach without opening one.
	var from_mouse := board.distances_from(mouse)
	var sides := _edge_cells(lock)
	var onward: Array[Dictionary] = []
	if job == LockJob.SHORTCUT:
		onward.append(board.distances_from(cheese, false, Board.Belts.TO, Board.Locks.OPEN))
	else:
		onward.append_array([board.distances_from(sides[0]), board.distances_from(sides[1])])
	var best: Array[Vector2i] = []
	var best_steps := INF
	var held: Array[Vector2i] = board.keys + board.plates + board.crates + _kept_clear
	if not held.any(func(cell: Vector2i) -> bool: return reach.has(cell) and not from_mouse.has(cell)) \
			and sides.any(func(side: Vector2i) -> bool: return from_mouse.has(side)) \
			and (job != LockJob.SHORTCUT or from_mouse.size() == reach.size()):
		for attempt in ITEM_TRIES * (2 if gate else 1):
			var cell := _random_cell()
			# Half a shortcut's tries are near the lock, where its key or crate costs least.
			if job == LockJob.SHORTCUT and attempt % 2 == 0:
				cell = sides.pick_random() + Vector2i(randi_range(-LOCK_ITEM_REACH, LOCK_ITEM_REACH),
					randi_range(-LOCK_ITEM_REACH, LOCK_ITEM_REACH))
			if not free.call(cell):
				continue
			var lane: Array[Vector2i] = [cell]
			if gate:
				if sides.any(func(side: Vector2i) -> bool: return _distance(cell, side) < 2):
					continue
				lane = _crate_lane(cell, free)
				if lane.is_empty():
					continue
			elif _distance(cell, mouse) < 2:
				continue
			var steps := _item_steps(lane, from_mouse, onward)
			if steps < best_steps:
				best = lane
				best_steps = steps
	var saving := way - best_steps
	if best.is_empty() or job == LockJob.SHORTCUT and saving < LOCK_MIN_SAVING:
		for wall in walls:
			board.walls.erase(wall)
		board.doors.erase(lock)
		board.gates.erase(lock)
		return false
	if gate:
		board.plates.append(best[0])
		board.crates.append(best[-2])
		_kept_clear.append_array(best.slice(1, -2))
		_kept_clear.append(best[-1])
	else:
		board.keys.append(best[0])
	_kept_clear.append_array(sides)
	if job == LockJob.SHORTCUT:
		_shortcuts[lock] = best
	BugReport.note("  %s %s at %s%s" % [LockJob.keys()[job].capitalize(), "gate" if gate else "door", lock,
		", saves %d steps" % saving if job == LockJob.SHORTCUT else ""])
	return true


## Steps from the mouse to the cheese with the lock shut and the round's other locks open: the way a
## shortcut through the lock must beat.
func _shut_way(lock: Vector3i, mouse: Vector2i, cheese: Vector2i) -> int:
	var plate: int = board.gates.get(lock, -1)
	var door := board.doors.erase(lock)
	board.gates.erase(lock)
	board.walls[lock] = true
	var way: int = board.distances_from(mouse, false, Board.Belts.FROM, Board.Locks.OPEN).get(cheese, 0)
	board.walls.erase(lock)
	if door:
		board.doors[lock] = true
	if plate != -1:
		board.gates[lock] = plate
	return way


## Steps the mouse takes for a lock's key or crate: from its start (from_mouse) to a key on lane[0], or
## behind a crate on a crate lane (see _crate_lane) and pushing it onto the plate, then on to the
## nearest of the start cells onward counts steps from.
func _item_steps(lane: Array[Vector2i], from_mouse: Dictionary[Vector2i, int], onward: Array[Dictionary]) -> float:
	var there: Vector2i = lane[1] if lane.size() > 1 else lane[0]
	return from_mouse.get(lane[-1], INF) + maxi(lane.size() - 2, 0) \
		+ onward.map(func(steps: Dictionary) -> int: return steps.get(there, 999)).min()


## Takes each SHORTCUT lock that no longer saves LOCK_MIN_SAVING steps, now the round's machines and
## floor tiles are laid, off the board with its key, or its plate and crate, leaving a gap in its run of
## wall. Opening a way never cuts anything off, as walling it up could.
func _drop_idle_shortcuts(mouse: Vector2i, cheese: Vector2i) -> void:
	for lock in _shortcuts:
		var lane: Array[Vector2i] = _shortcuts[lock]
		var onward: Array[Dictionary] = [board.distances_from(cheese, false, Board.Belts.TO, Board.Locks.OPEN)]
		var saving := _shut_way(lock, mouse, cheese) - _item_steps(lane, board.distances_from(mouse), onward)
		if saving >= LOCK_MIN_SAVING:
			continue
		BugReport.note("  Shortcut %s at %s saves %d steps now: taken out" % [
			"gate" if board.gates.has(lock) else "door", lock, saving])
		if board.gates.has(lock):
			var plate := board.gates[lock]
			board.gates.erase(lock)
			board.plates.remove_at(plate)
			for edge in board.gates:
				if board.gates[edge] > plate:
					board.gates[edge] -= 1
			board.crates.erase(lane[-2])
		else:
			board.doors.erase(lock)
			board.keys.erase(lane[0])
	_shortcuts.clear()


## The edge into the round's chest, for a VAULT lock, if the chest is in a dead end (see _dead_end) with
## nothing shut across the way in yet. Else NO_EDGE.
func _vault_lock() -> Vector3i:
	if board.chests.is_empty() or not _dead_end(board.chests[0]):
		return NO_EDGE
	var chest := board.chests[0]
	for offset: Vector2i in Card.OFFSETS.values():
		if board._can_step(chest, chest + offset) and chest + offset not in board.traps:
			return Board.wall_between(chest, chest + offset)
	return NO_EDGE


## Tries LOCK_TRIES runs of wall with a lock in them, and returns the one that does job best, with the
## lock's edge last, or nothing when none does it. Half are random runs (see _wall_run) with the lock in
## the middle, and half plug the way to the cheese: the lock on an edge a shortest way crosses, in a run
## along its grid line (see _plug_run). Each is tried with the lock shut and the round's other locks
## open. For GOAL, the lock is the only way from the mouse to the cheese, and the best leaves least of
## the board on the cheese's side. For SHORTCUT, the run cuts no cell off, and the best makes the way to
## the cheese longest while the lock is shut, by at least LOCK_MIN_SAVING.
func _lock_run(job: LockJob, mouse: Vector2i, cheese: Vector2i) -> Array[Vector3i]:
	var from_mouse := board.distances_from(mouse, false, Board.Belts.FROM, Board.Locks.OPEN)
	var to_cheese := board.distances_from(cheese, false, Board.Belts.TO, Board.Locks.OPEN)
	var cells := from_mouse.size()
	var crossings: Array[Vector3i] = []
	for cell in from_mouse:
		for offset: Vector2i in Card.OFFSETS.values():
			var next := cell + offset
			if from_mouse[cell] + 1 + to_cheese.get(next, cells) == from_mouse[cheese] \
					and not board.is_barrier(cell, next):
				crossings.append(Board.wall_between(cell, next))
	crossings.shuffle()
	var best: Array[Vector3i] = []
	var best_lock := NO_EDGE
	var best_score := 0
	for attempt in LOCK_TRIES:
		var walls: Array[Vector3i] = []
		var lock := NO_EDGE
		if attempt % 2 == 0:
			walls = _wall_run(false, LOCK_RUN_MAX)
			if walls.is_empty() or walls.any(_is_wall):
				continue
			# In the middle of the run, so going round the end of the run takes longer.
			lock = walls[randi_range(1, walls.size() - 2)] if walls.size() > 2 else walls.pick_random()
		elif attempt / 2 < crossings.size():
			lock = crossings[attempt / 2]
			walls = _plug_run(lock)
		else:
			continue
		for wall in walls:
			board.walls[wall] = true
		var shut := board.distances_from(mouse, false, Board.Belts.FROM, Board.Locks.OPEN)
		board.walls.erase(lock)
		var open := board.distances_from(mouse, false, Board.Belts.FROM, Board.Locks.OPEN)
		for wall in walls:
			board.walls.erase(wall)
		if open.size() != cells:
			continue
		var score := 0
		if job == LockJob.GOAL:
			if shut.has(cheese):
				continue
			score = shut.size()
		elif shut.size() == cells:
			score = shut[cheese] - open[cheese] - LOCK_MIN_SAVING + 1
		if score > best_score:
			best = walls
			best_lock = lock
			best_score = score
	if not best.is_empty():
		best.erase(best_lock)
		best.append(best_lock)
	return best


## A run of wall through the lock's edge, the lock and then on along its grid line both ways, to where
## each end meets the board's edge or another wall, at most LOCK_RUN_MAX long: a lock that plugs a gap.
func _plug_run(lock: Vector3i) -> Array[Vector3i]:
	var walls: Array[Vector3i] = [lock]
	# The cell corners at the ends of the run (see _wall_ends), and whether each goes on.
	var ends: Array[Vector2i] = [Vector2i(lock.x, lock.y + 1) if lock.z == 1 else Vector2i(lock.x + 1, lock.y),
		Vector2i(lock.x + 1, lock.y + 1)]
	var along := ends[1] - ends[0]
	var going: Array[bool] = []
	for end in ends:
		going.append(not _on_rim(end) and not _touches_wall(end))
	while walls.size() < LOCK_RUN_MAX and (going[0] or going[1]):
		for i in 2:
			if not going[i] or walls.size() == LOCK_RUN_MAX:
				continue
			var offset := along if i == 1 else -along
			var edge := _grid_line(ends[i], ends[i] + offset)
			if edge == NO_EDGE or _is_wall(edge):
				going[i] = false
				continue
			walls.append(edge)
			ends[i] += offset
			going[i] = not _on_rim(ends[i]) and not _touches_wall(ends[i])
	return walls


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
## the mouse, the cheese, the traps, the chasms, the keys, plates, crates and crate lanes, the cells
## beside a lock, and not touching each other. Nothing can move onto one, so each goes only where it
## cuts no cell off from the mouse, with the locks open or shut, so no key gets shut away. A
## flamethrower points a way its jet reaches at least FLAME_MIN cells. Each starts at a random point in
## its countdown, but not about to go off on a mouse that starts in its blast.
func _place_hazards(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> void:
	var open_cells := board.grid * board.grid - traps.size() - board.chasms.size()
	var shut := board.distances_from(mouse)
	for kind: Hazard.Kind in [Hazard.Kind.PYLON, Hazard.Kind.FLAMER]:
		var count := Difficulty.pylons(run.round_number) if kind == Hazard.Kind.PYLON \
			else Difficulty.flamers(run.round_number)
		var placed := 0
		for attempt in 500:
			if placed == count:
				break
			var cell := _random_cell()
			if cell == mouse or cell == cheese or cell in traps or board.has_tile(cell) or board.has_item(cell) \
					or cell in _kept_clear or board.hazards.any(func(other: Hazard) -> bool: return _touching(cell, other.cell)):
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
			var now := board.distances_from(mouse)
			if now.size() != shut.size() - int(shut.has(cell)) or board.distances_from(mouse, false,
					Board.Belts.FROM, Board.Locks.OPEN).size() != open_cells - board.hazards.size():
				board.hazards.pop_back()
				continue
			shut = now
			hazard.timer = randi_range(2 if mouse in board.blast_cells(hazard) else 1, hazard.period)
			placed += 1


## Lays down the round's glue pads, jump pads, mouse holes, conveyor belts and creaky floorboards, at
## most one on a cell and none on the mouse, the cheese, a trap, a chasm or bridge, a pylon or
## flamethrower, a key, plate or crate, a crate's lane or beside a lock. Linked holes are at least half
## the board apart, and out from behind the locks, so they never lead round one. A jump pad throws the
## mouse its whole way, with no wall in it, and not onto a trap. Belts are laid where they matter (see
## _place_belts), and never carry the mouse off the board, into a wall or a chasm, or onto a trap.
## Floorboards only go where breaking all of them would still leave every cell reachable, with the
## locks open or shut, so they can't shut the mouse off from the cheese or a key.
func _place_floor(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> void:
	var number := run.round_number
	var bounds := Rect2i(0, 0, board.grid, board.grid)
	var free := func(cell: Vector2i) -> bool:
		return bounds.has_point(cell) and cell != mouse and cell != cheese and cell not in traps \
			and not board.has_tile(cell) and not board.has_item(cell) and cell not in _kept_clear
	# On top of any thrown across a chasm (see _place_chasm_pads).
	var pad_count := board.pads.size() + Difficulty.pads(number)
	for attempt in 500:
		if board.pads.size() == pad_count:
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

	var shut := board.distances_from(mouse)
	for attempt in 500:
		if board.holes.size() == Difficulty.holes(number) * 2:
			break
		var cell := _random_cell()
		if free.call(cell) and shut.has(cell) and (board.holes.size() % 2 == 0
				or _distance(cell, board.holes[-1]) >= floori(board.grid / 2.0)):
			board.holes.append(cell)
	if board.holes.size() % 2 == 1:
		board.holes.pop_back()

	_place_belts(mouse, cheese, traps, free)

	var open_cells := board.grid * board.grid - traps.size() - board.chasms.size() - board.hazards.size()
	shut = board.distances_from(mouse)
	var shut_back := board.distances_from(mouse, false, Board.Belts.TO)
	for attempt in 500:
		if board.floorboards.size() == Difficulty.floorboards(number):
			break
		var cell := _random_cell()
		if not free.call(cell):
			continue
		# Check with every floorboard broken.
		board.broken.assign(board.floorboards + [cell])
		var reachable := board.distances_from(mouse, false, Board.Belts.FROM, Board.Locks.OPEN).size()
		# With the belts one-way, every cell must also get back to the mouse's start, and so to the
		# cheese wherever it runs. With the locks shut, the gaps must cost no other cell either.
		if reachable == open_cells - board.broken.size() \
				and board.distances_from(mouse, false, Board.Belts.TO, Board.Locks.OPEN).size() == reachable \
				and board.distances_from(mouse).size() \
					== shut.size() - board.broken.filter(func(gap: Vector2i) -> bool: return shut.has(gap)).size() \
				and board.distances_from(mouse, false, Board.Belts.TO).size() \
					== shut_back.size() - board.broken.filter(func(gap: Vector2i) -> bool: return shut_back.has(gap)).size():
			board.floorboards.append(cell)
		board.broken.clear()


## Lays the round's conveyor belts, each one the best of BELT_TRIES runs (see _belt_run): with
## BELT_CURRENT_CHANCE a current, the one that makes the way to the cheese longest (by at least
## BELT_CURRENT_DETOUR), else a highway, the one whose ride saves most steps on it (at least
## BELT_SAVING). A belt that does neither is left out. Belts are one-way (Board.against_belt), so each
## must leave every cell reachable from the mouse's start and able to get back to it (and so to the
## cheese, wherever it runs), and the currents together add at most BELT_DETOUR of the board's side
## to the way. All this goes with the locks open, and a belt must also leave what's reachable with the
## locks shut as it was, so no key gets shut away. free says which cells a belt can go on.
func _place_belts(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i], free: Callable) -> void:
	var count := Difficulty.belts(run.round_number)
	if count == 0:
		return
	var open := Board.Locks.OPEN
	var longest: int = board.distances_from(cheese, false, Board.Belts.TO, open)[mouse] \
		+ ceili(board.grid * BELT_DETOUR)
	var shut := _shut_reach(mouse)
	for i in count:
		var current := randf() < BELT_CURRENT_CHANCE
		var from_mouse := board.distances_from(mouse, false, Board.Belts.FROM, open)
		var to_cheese := board.distances_from(cheese, false, Board.Belts.TO, open)
		var way: int = to_cheese[mouse]
		var best: Dictionary[Vector2i, Card.Dir] = {}
		var best_score := (BELT_CURRENT_DETOUR if current else BELT_SAVING) - 1
		# The cells on a shortest way to the cheese, which the belts start near.
		var route: Array[Vector2i] = []
		for cell in from_mouse:
			if from_mouse[cell] + to_cheese.get(cell, way) == way:
				route.append(cell)
		var tried := 0
		for attempt in BELT_TRIES * 20:
			if tried == BELT_TRIES:
				break
			var belt := _belt_run(route, traps, free)
			if belt.is_empty():
				continue
			tried += 1
			var score := 0
			if not current:
				score = _belt_saving(belt, from_mouse, to_cheese, way)
				if score <= best_score:
					continue
			board.conveyors.merge(belt)
			var after := board.distances_from(mouse, false, Board.Belts.FROM, open)
			var back := board.distances_from(mouse, false, Board.Belts.TO, open)
			var kept := after.size() == from_mouse.size() and back.size() == from_mouse.size() \
				and after[cheese] <= longest and _shut_reach(mouse) == shut
			for cell in belt:
				board.conveyors.erase(cell)
			if not kept:
				continue
			if current:
				score = after[cheese] - way
			if score > best_score:
				best = belt
				best_score = score
		if not best.is_empty():
			board.conveyors.merge(best)
			BugReport.note("  %s of %d cells, %d steps %s" % ["Current" if current else "Highway", best.size(),
				best_score, "longer" if current else "saved"])


## How many cells the mouse can reach from its start with the locks shut, and how many can get back to
## it.
func _shut_reach(mouse: Vector2i) -> Vector2i:
	return Vector2i(board.distances_from(mouse).size(), board.distances_from(mouse, false, Board.Belts.TO).size())


## A random conveyor belt starting within BELT_REACH steps of one of the near cells: a walk of
## BELT_MIN cells up to BELT_SPAN of the board's side that turns a corner at most once, each cell
## running on to the next, on free cells (see _place_floor). It stops short of a cell that isn't free
## or a wall across it. The cell past its end, where it drops the mouse, is not a trap, a gap, a chasm,
## a machine or another belt. Empty if that leaves it shorter than BELT_MIN.
func _belt_run(near: Array[Vector2i], traps: Array[Vector2i], free: Callable) -> Dictionary[Vector2i, Card.Dir]:
	var belt: Dictionary[Vector2i, Card.Dir] = {}
	var shift := Vector2i(randi_range(-BELT_REACH, BELT_REACH), 0)
	shift.y = randi_range(absi(shift.x) - BELT_REACH, BELT_REACH - absi(shift.x))
	var cell: Vector2i = near.pick_random() + shift
	var offset: Vector2i = Card.OFFSETS.values().pick_random()
	# Which way the corner turns: a quarter turn one way or the other.
	var turn: int = [1, -1].pick_random()
	var turned := false
	for i in randi_range(BELT_MIN, maxi(roundi(board.grid * BELT_SPAN), BELT_MIN)):
		if i > 0 and not turned and randf() < BELT_TURN_CHANCE:
			offset = Vector2i(-offset.y, offset.x) * turn
			turned = true
		if not free.call(cell) or belt.has(cell) or not board._can_cross(cell, cell + offset):
			break
		belt[cell] = Card.OFFSETS.find_key(offset)
		cell += offset
	if belt.size() < BELT_MIN or cell in traps or board.is_blocked(cell) or board.conveyors.has(cell) \
			or belt.has(cell):
		return {}
	return belt


## Steps a belt saves on the way from the mouse to the cheese (way steps), given the steps from the
## mouse to each cell and from each cell to the cheese without it: stepping onto it anywhere but
## against it, the mouse rides free to the cell past its end.
func _belt_saving(belt: Dictionary[Vector2i, Card.Dir], from_mouse: Dictionary[Vector2i, int],
		to_cheese: Dictionary[Vector2i, int], way: int) -> int:
	var drop: Vector2i = belt.keys()[-1] + Card.OFFSETS[belt.values()[-1]]
	if not to_cheese.has(drop):
		return 0
	var shortest := way
	for cell in belt:
		for offset: Vector2i in Card.OFFSETS.values():
			var from := cell + offset
			if belt.has(from) or not from_mouse.has(from) or offset == Card.OFFSETS[belt[cell]] \
					or board.is_barrier(from, cell):
				continue
			shortest = mini(shortest, from_mouse[from] + 1 + to_cheese[drop])
	return way - shortest


## Picks crumb cells off the mouse, the cheese, the traps, the floor tiles (see _place_floor), the
## keys, plates, crates, chests and crate lanes (see _place_locks) and each other. Nooks behind a bridge
## (see _nooks) and pockets the walls made (see _pockets) get theirs first, so a dead end always has
## something in it.
func _place_crumbs(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i]) -> Array[Vector2i]:
	var crumbs: Array[Vector2i] = []
	var from_mouse := board.distances_from(mouse, false, Board.Belts.FROM, Board.Locks.OPEN)
	for cell in _nooks(mouse, cheese).keys() + _pockets(from_mouse, mouse, cheese).keys():
		if crumbs.size() < CRUMB_COUNT and cell not in crumbs and not board.has_tile(cell) \
				and not board.has_item(cell) and cell not in _kept_clear:
			crumbs.append(cell)
	for attempt in 1000:
		if crumbs.size() == CRUMB_COUNT:
			break
		var cell := _random_cell()
		if cell not in [mouse, cheese] and cell not in traps and cell not in crumbs and not board.has_tile(cell) \
				and not board.has_item(cell) and cell not in _kept_clear:
			crumbs.append(cell)
	return crumbs


## Picks a cell for a chest out in the open, for a round with no walls to make a pocket of (see
## _place_pocket): at least CHEST_MIN_DISTANCE from the mouse, and off the cheese, the traps, the floor
## tiles, the keys, plates, crates and crate lanes, and the crumbs.
func _place_chest(mouse: Vector2i, cheese: Vector2i, traps: Array[Vector2i],
		crumbs: Array[Vector2i]) -> Array[Vector2i]:
	var chests: Array[Vector2i] = []
	var spacing := mini(CHEST_MIN_DISTANCE, board.grid - 2)
	for attempt in 1000:
		var cell := _random_cell()
		if _distance(cell, mouse) >= spacing and cell != cheese and cell not in traps \
				and cell not in crumbs and not board.has_tile(cell) and not board.has_item(cell) \
				and cell not in _kept_clear:
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


## Steps from one cell to another around the walls and traps (through the walls while squeezing) and
## with the belts, or the straight distance when there's no way through. When locked doors are in the
## way, it's the way through them: straight there with a key in hand, else by the nearest key.
func _path_distance(from: Vector2i, to: Vector2i) -> int:
	var steps := board.distances_from(to, board.squeeze, Board.Belts.TO)
	if steps.has(from) or board.doors.is_empty():
		return steps.get(from, _distance(from, to))
	steps = board.distances_from(to, false, Board.Belts.TO, Board.Locks.DOORS_OPEN)
	if board.keys_held > 0 or not steps.has(from):
		return steps.get(from, _distance(from, to))
	var from_start := board.distances_from(from)
	var shortest: int = steps[from]
	var by_key := false
	for key in board.keys:
		if from_start.has(key) and steps.has(key) and (not by_key or from_start[key] + steps[key] < shortest):
			shortest = from_start[key] + steps[key]
			by_key = true
	return shortest


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
