extends SceneTree
## Headless balance simulation. Plays many rounds of the real game with a greedy bot and prints
## how long rounds take and how each slot effect performs.
##
## godot --headless --path . --script res://tools/balance_sim.gd -- --rounds 500 --seed 1

const MAX_TURNS := 200

var rounds := 500
var rng_seed := 1
var main: Node
var board: Board

## Turns each round that reached the cheese took.
var round_turns: Array[int] = []
var unfinished := 0
## Rounds lost to a mouse trap.
var caught := 0
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


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--rounds":
				rounds = args[i + 1].to_int()
			"--seed":
				rng_seed = args[i + 1].to_int()
	for effect in CardSlot.Effect.values():
		effect_stats[effect] = [0, 0, 0, 0]
	_run.call_deferred()


func _run() -> void:
	seed(rng_seed)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	board = main.board
	board.animate = false
	for r in rounds:
		if r > 0:
			# A trap ends the run. The bot never shops, so a run's state doesn't change its play.
			if board.is_caught():
				main.new_run()
			else:
				main.new_round()
		await _play_round()
		# Let freed cards leave the tree.
		await process_frame
	_report()
	quit()


func _play_round() -> void:
	var crumbs_before: int = main.run.crumbs
	while not main.win_panel.visible:
		if main.turn > MAX_TURNS:
			unfinished += 1
			return
		var used := _place_cards()
		var before := _distance()
		for slot: CardSlot in main.slots:
			effect_stats[slot.effect][0] += 1
		await main.lock_in()
		var won: bool = main.win_panel.visible and not board.is_caught()
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
	if board.is_caught():
		caught += 1
	else:
		round_turns.append(main.turn)
		won_crumbs += main.run.crumbs - crumbs_before
		crumbs_picked_up += main.round_crumbs


## Greedy bot: for each slot in play order, places the card that brings the mouse closest to the cheese,
## and only if it gets closer. Ignores distance effects. Never steps straight onto a trap; if one is in
## the way and nothing else gets closer, it sidesteps. Returns the effects of the slots it used.
func _place_cards() -> Array[CardSlot.Effect]:
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
			var cell := _clamp(pos + Card.OFFSETS[slot.play_dir(dir)])
			if cell in board.traps:
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
			var cell := _clamp(pos + Card.OFFSETS[slot.play_dir(card.dir)])
			if cell != pos and cell not in board.traps:
				main._place_in_slot(card, slot)
				placed += 1
				if slot.effect != CardSlot.Effect.NONE:
					used.append(slot.effect)
				return
		return


func _best_dir(pos: Vector2i) -> Card.Dir:
	var best := Card.Dir.UP
	for dir: Card.Dir in Card.Dir.values():
		if _dist(_clamp(pos + Card.OFFSETS[dir])) < _dist(_clamp(pos + Card.OFFSETS[best])):
			best = dir
	return best


func _clamp(cell: Vector2i) -> Vector2i:
	return cell.clamp(Vector2i.ZERO, Vector2i(Board.GRID - 1, Board.GRID - 1))


func _dist(cell: Vector2i) -> int:
	return main._distance(cell, board.cheese_cell)


func _distance() -> int:
	return _dist(board.mouse_cell)


func _report() -> void:
	var sorted := round_turns.duplicate()
	sorted.sort()
	var total := 0
	for t in sorted:
		total += t
	var n := sorted.size()
	print("\nBalance sim: %d rounds, seed %d, greedy bot" % [rounds, rng_seed])
	print("Caught in a trap: %d rounds (%.1f%%)" % [caught, 100.0 * caught / max(rounds, 1)])
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
