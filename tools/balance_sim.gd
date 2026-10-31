extends SceneTree
## Headless balance simulation. Plays many rounds of the real game with a greedy bot and prints
## how long rounds take, how far runs get through the difficulty curve and how each slot effect performs.
##
## godot --headless --path . --script res://tools/balance_sim.gd -- --rounds 500 --seed 1
##
## Runs go on until the bot loses, so later rounds are bigger and busier (see Difficulty). --round N
## plays every round as round N of a fresh run instead. Boss rounds are off unless --boss names one
## (alley_king, runaway_cheese, kitchen_light): then every round is that boss, each on a fresh run.
## --slots N and --hand N start every run with that many card slots and cards in hand (chests add more).

const MAX_TURNS := 200

var rounds := 500
var rng_seed := 1
## The Boss.Kind every round is, or -1 for plain rounds.
var boss := -1
## The round number every round is played as, or 0 to let runs go on.
var fixed_round := 0
## Card slots and hand size each run starts with, or 0 for the game's own (Run.START_SLOTS, ...).
var slot_count := 0
var hand_size := 0
## Rounds that had a chest, and chests opened.
var chest_rounds := 0
var chests_opened := 0
var main: Node
var board: Board

## Turns each round that reached the cheese took.
var round_turns: Array[int] = []
var unfinished := 0
## Rounds lost to a mouse trap, and to a cat.
var caught := 0
var caught_by_cat := 0
## Rounds lost to the turn limit.
var out_of_time := 0
## Per round number: [rounds played, won, caught in a trap, caught by a cat, out of time, turns in won rounds].
var round_stats := {}
## Crumbs earned in rounds that reached the cheese: the win reward, unused discards and pickups.
var won_crumbs := 0
var crumbs_picked_up := 0
## Per effect: [times rolled, times the bot used it, total cells gained on those turns, winning turns].
var effect_stats := {}
## Cells gained per turn and turn count on turns where cards went only into plain slots.
var plain_gain := 0
var plain_turns := 0
## Cards the bot placed this turn.
var placed := 0
## Steps from each cell to the cheese around the walls and traps, refreshed each turn (see _dist).
var to_cheese: Dictionary[Vector2i, int] = {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--rounds":
				rounds = args[i + 1].to_int()
			"--seed":
				rng_seed = args[i + 1].to_int()
			"--boss":
				boss = Boss.Kind.get(args[i + 1].to_upper(), -1)
				if boss == -1:
					printerr("Unknown boss %s, expected one of %s" % [args[i + 1], Boss.Kind.keys()])
					quit(1)
					return
			"--round":
				fixed_round = maxi(args[i + 1].to_int(), 1)
			"--slots":
				slot_count = clampi(args[i + 1].to_int(), 1, Run.MAX_SLOTS)
			"--hand":
				hand_size = clampi(args[i + 1].to_int(), 1, Run.MAX_HAND_SIZE)
	for effect in CardSlot.Effect.values():
		effect_stats[effect] = [0, 0, 0, 0]
	_run.call_deferred()


func _run() -> void:
	seed(rng_seed)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	board = main.board
	board.animate = false
	main.bosses_enabled = false
	main.force_boss = boss
	if boss != -1 or fixed_round > 0 or slot_count > 0 or hand_size > 0:
		_new_run()
	for r in rounds:
		if r > 0:
			# Losing ends the run. The bot never shops, so a run's state doesn't change its play.
			if main.lost() or boss != -1 or fixed_round > 0:
				_new_run()
			else:
				main.new_round()
		await _play_round()
		# Let freed cards leave the tree.
		await process_frame
	_report()
	quit()


## Starts a run, skipping ahead to fixed_round if one is set.
func _new_run() -> void:
	main.new_run()
	if fixed_round > 1:
		main.run.round_number = fixed_round - 1
		main.new_round()
	if slot_count > 0 or hand_size > 0:
		main.set_slots_and_hand(slot_count if slot_count > 0 else main.run.slots,
			hand_size if hand_size > 0 else main.run.hand_size)


func _play_round() -> void:
	var crumbs_before: int = main.run.crumbs
	var number: int = main.run.round_number
	if number not in round_stats:
		round_stats[number] = [0, 0, 0, 0, 0, 0]
	var tally: Array = round_stats[number]
	tally[0] += 1
	if not board.chests.is_empty():
		chest_rounds += 1
	while not main.win_panel.visible:
		if main.turn > MAX_TURNS:
			unfinished += 1
			return
		var used := _place_cards()
		var before := _distance()
		for slot: CardSlot in main.slots:
			effect_stats[slot.effect][0] += 1
		await main.lock_in()
		var won: bool = main.win_panel.visible and not main.lost()
		# The cheese can have run (RUNAWAY CHEESE).
		_refresh_distances()
		var gain := before - _distance()
		if used.is_empty() and placed > 0:
			plain_gain += gain
			plain_turns += 1
		for effect in used:
			var stats: Array = effect_stats[effect]
			stats[1] += 1
			stats[2] += gain
			if won:
				stats[3] += 1
	if main.out_of_time:
		out_of_time += 1
		tally[4] += 1
	elif board.caught_by_cat():
		caught_by_cat += 1
		tally[3] += 1
	elif board.is_caught():
		caught += 1
		tally[2] += 1
	else:
		tally[1] += 1
		tally[5] += main.turn
		round_turns.append(main.turn)
		won_crumbs += main.run.crumbs - crumbs_before
		crumbs_picked_up += main.round_crumbs
	chests_opened += main.chest_rewards.size()


## Greedy bot: for each slot in play order, places the card that brings the mouse closest to the cheese
## (by the path around the walls), and only if it gets closer. Ignores distance effects. Never steps
## straight onto a trap, a cat or a cat's path; if one is in the way and nothing else gets closer, it
## sidesteps. Returns the effects of the slots it used.
func _place_cards() -> Array[CardSlot.Effect]:
	_refresh_distances()
	var used: Array[CardSlot.Effect] = []
	var pos := board.mouse_cell
	var trap_in_way := false
	placed = 0
	for slot: CardSlot in main._play_order():
		if slot.effect == CardSlot.Effect.BLOCKED:
			continue
		var best: Card = null
		var best_cell := pos
		for card: Card in main.hand_box.get_children():
			var dir := card.dir
			if slot.effect == CardSlot.Effect.WILD:
				dir = _best_dir(pos)
				slot.wild_dir = dir
			var cell := board.step_target(pos, slot.play_dir(dir))
			if board.is_deadly(cell):
				trap_in_way = trap_in_way or _dist(cell) < _dist(pos)
			elif _dist(cell) < _dist(best_cell):
				best = card
				best_cell = cell
		if best:
			main._place_in_slot(best, slot)
			pos = best_cell
			placed += 1
			if slot.effect != CardSlot.Effect.NONE:
				used.append(slot.effect)
	if placed == 0 and trap_in_way:
		_sidestep(pos, used)
	return used


## Puts the first card that moves the mouse without hitting a trap into the first open slot.
func _sidestep(pos: Vector2i, used: Array[CardSlot.Effect]) -> void:
	for slot: CardSlot in main._play_order():
		if slot.effect == CardSlot.Effect.BLOCKED:
			continue
		for card: Card in main.hand_box.get_children():
			var cell := board.step_target(pos, slot.play_dir(card.dir))
			if cell != pos and not board.is_deadly(cell):
				main._place_in_slot(card, slot)
				placed += 1
				if slot.effect != CardSlot.Effect.NONE:
					used.append(slot.effect)
				return
		return


func _best_dir(pos: Vector2i) -> Card.Dir:
	var best := Card.Dir.UP
	for dir: Card.Dir in Card.Dir.values():
		if _dist(board.step_target(pos, dir)) < _dist(board.step_target(pos, best)):
			best = dir
	return best


func _refresh_distances() -> void:
	to_cheese = board.distances_from(board.cheese_cell)


## Steps from the cell to the cheese, or the straight distance from a cell the path search can't reach
## (a trap).
func _dist(cell: Vector2i) -> int:
	return to_cheese.get(cell, main._distance(cell, board.cheese_cell))


func _distance() -> int:
	return _dist(board.mouse_cell)


func _report() -> void:
	var sorted := round_turns.duplicate()
	sorted.sort()
	var total := 0
	for t in sorted:
		total += t
	var n := sorted.size()
	print("\nBalance sim: %d rounds, seed %d, greedy bot%s%s%s" % [rounds, rng_seed,
		", boss %s" % Boss.INFO[boss][0] if boss != -1 else "",
		", runs start with %d slots and %d cards" % [slot_count if slot_count > 0 else Run.START_SLOTS,
			hand_size if hand_size > 0 else Run.START_HAND_SIZE] if slot_count > 0 or hand_size > 0 else "",
		", every round is round %d (%s)" % [fixed_round, Difficulty.describe(fixed_round)] if fixed_round > 0 else ""])
	print("Caught in a trap: %d rounds (%.1f%%)" % [caught, 100.0 * caught / max(rounds, 1)])
	print("Caught by a cat: %d rounds (%.1f%%)" % [caught_by_cat, 100.0 * caught_by_cat / max(rounds, 1)])
	print("Out of time: %d rounds (%.1f%%)" % [out_of_time, 100.0 * out_of_time / max(rounds, 1)])
	_report_rounds()
	if n == 0:
		print("No rounds finished.")
		return
	print("Turns to cheese: mean %.1f  median %d  max %d  unfinished %d" % [
		float(total) / n, sorted[n / 2], sorted[-1], unfinished])
	for bucket in [[1, 3], [4, 6], [7, 9], [10, 14], [15, MAX_TURNS]]:
		var count := sorted.filter(func(t: int) -> bool: return t >= bucket[0] and t <= bucket[1]).size()
		var share := 100.0 * count / n
		var label := "%d-%d" % bucket if bucket[1] < MAX_TURNS else "%d+" % bucket[0]
		print("  %-6s %5.1f%%  %s" % [label, share, "#".repeat(roundi(share / 2))])
	print("Crumbs per won round: %.1f (%.1f picked up on the board)" % [
		float(won_crumbs) / n, float(crumbs_picked_up) / n])
	print("Chests: %d rounds had one, the bot opened %d (it doesn't go for them)" % [chest_rounds, chests_opened])

	print("\nCells gained per turn with cards only in plain slots: %.2f" % [
		float(plain_gain) / max(plain_turns, 1)])
	print("%-12s %7s %6s %10s %9s" % ["Effect", "rolled", "used%", "gain/turn", "win turns"])
	for effect in CardSlot.Effect.values():
		if effect == CardSlot.Effect.NONE:
			continue
		var stats: Array = effect_stats[effect]
		var gain := "-" if stats[1] == 0 else "%.2f" % (float(stats[2]) / stats[1])
		print("%-12s %7d %5.1f%% %10s %9d" % [
			CardSlot.INFO[effect][0], stats[0], 100.0 * stats[1] / max(stats[0], 1), gain, stats[3]])


## How each round number of a run went: the difficulty curve as the bot sees it.
func _report_rounds() -> void:
	var numbers := round_stats.keys()
	numbers.sort()
	# The board goes last: its description grows with the obstacles.
	print("\n%-6s %6s %6s %6s %6s %6s %6s  %s" % ["Round", "played", "won%", "trap%", "cat%", "time%",
		"turns", "Board"])
	for number: int in numbers:
		var tally: Array = round_stats[number]
		var played: int = tally[0]
		print("%-6d %6d %5.1f%% %5.1f%% %5.1f%% %5.1f%% %6s  %s" % [number, played,
			100.0 * tally[1] / played, 100.0 * tally[2] / played, 100.0 * tally[3] / played,
			100.0 * tally[4] / played, "-" if tally[1] == 0 else "%.1f" % (float(tally[5]) / tally[1]),
			Difficulty.describe(number)])
