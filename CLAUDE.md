# Mouse & Cheese (MoverTester)

A Godot 4.6 deckbuilder prototype. Each turn you draw a hand of direction cards (6 to start), place
them in slots (4 to start), then Lock In: the mouse moves one cell per card, in slot order, on a square grid until it
reaches the cheese, within the round's turn limit. Each turn about half the slots roll an **effect** (REVERSED, SLIDE, ECHO, BURN, ...)
that changes how the card in that slot plays. Slot effects are where the game's content lives.
Each round also gives `DISCARDS_PER_ROUND` (5) discards: right-click a card, or drag it down onto the
discard area under the hand (lit while a card is dragged), to swap it for a new draw (`main.gd` `discard_card`).

The **Preview** checkbox in the F2 dev menu (`main.gd` `preview_on`) draws where the slotted cards would take the mouse, as a dashed
line on the board ending in a ring (red cross if caught, green on the cheese, pale blue in glue, "?"
before a GAMBLE slot's random move). `main.gd` `_update_preview` plays the turn through the same
`_play_cards` as `lock_in`, with `board` swapped for a hidden, non-animated copy (`Board.copy_from`)
that records the mouse's `trail`, and puts back the card tints, status line, THICK FUR and log after.
Anything that changes the cards, slots or board calls `refresh_preview()` (the dev menu's `_did` does).

The board has mouse traps, **walls** and roaming **cats**. Walls are segments on cell edges, laid
in short runs that can turn corners (`main.gd` `_place_walls`, which rejects any run that would cut
a cell off). Nothing walks, slides or jumps through a wall, except the mouse during a turn of the
SQUEEZE consumable. Each cat shows the path it will walk this turn; moving onto a cat or its path
catches the mouse. After the mouse moves, the cats walk their paths and plan new ones, which never
cover the mouse's cell, the cheese or a trap.

Later rounds add **floor tiles** (`main.gd` `_place_floor`), at most one per cell and never on the
mouse, cheese, a trap or a crumb. They act on the cell a move ends on, except where noted:
- **Glue**: the mouse sticks for the rest of the turn (`Board.stuck`; `lock_in` fizzles the cards
  left). Slides stop on it; jumps pass over it.
- **Mouse holes**, in linked pairs (`holes[0]` with `holes[1]`, ...): pop out of the other one.
- **Conveyor belts**: carry the mouse a cell the belt's way, and on along the belt. Never placed
  to push into a wall, off the board or onto a trap.
- **Creaky floorboards**: break into a gap (`broken`) once the mouse walks, slides or jumps off.
  Nothing can move onto a gap, but jumps pass over it. Only placed where breaking every one still
  leaves all cells reachable.

Holes and conveyors chain (`Board._ride`); the pathfinding ignores them (and glue).

**Difficulty** (`scripts/difficulty.gd`) rises with the round number: the first two rounds are a
small board (8x8) with no obstacles, then the grid grows a cell a round up to 20x20 and traps and
walls are added, and the other obstacles join one at a time: cats (round 4), glue (5), mouse holes
(7), conveyors (8) and floorboards (10). Every round has a turn limit, set from the mouse-to-cheese
path length around the walls and traps (`Board.distances_from`) with a few spare turns that shrink
over the run.

A round may have a **chest** (`main.gd` `CHEST_CHANCE`, `_place_chests`), opened by walking or
sliding over it like a crumb. It gives, at random, a card slot (`Run.slots`, up to 8, and never more
slots than cards in hand) or a card in the hand (`Run.hand_size`, up to 10) for the rest of the run,
from the next turn (`_open_chest`); crumbs once both are maxed. `_build_slots` rebuilds the slots at
the start of a turn and shrinks the cards so the slots and the hand each fit their row.

Rounds chain into an endless **run**: the deck, crumbs, trinkets, pouch, slots and hand size carry over until a trap
or a cat catches the mouse, or the turns run out (`main.gd` `lost()`), which starts a new run. A won round pays crumbs (`WIN_CRUMBS` + unused discards, plus
crumbs picked up on the board), then opens the **shop**. It sells trinkets (passive for the run),
consumables (held in the pouch, used once) and card stamps (a slot effect stuck on one card). A
stamped card plays its slot's effect first, then its stamp (`main.gd` `_play`): a BURN slot with a
SLIDE stamp moves 3 cells, then slides. A burned card stays burned whatever its stamp.

Every `Boss.EVERY` (3) rounds is a **boss round** with an extra rule: THE ALLEY KING (a big cat that
hunts the mouse, on top of the usual cats), RUNAWAY CHEESE (the cheese runs from the mouse; a few
extra turns) or KITCHEN LIGHT (a shorter turn limit). The shop before it names the boss. Beating one
pays `Boss.WIN_CRUMBS` and offers a free trinket.

## Layout
- `scenes/main.tscn` — the only scene. Nodes the code uses are `%Unique` names (`%Board`, `%Hand`,
  `%SlotRow`, `%LockInButton`, `%WinPanel`, ...).
- `scripts/main.gd` — turn controller: starts runs and rounds (`new_run` / `new_round`), deals hands,
  rolls slot effects (`_roll_effects`), plays a turn (`lock_in` → `_play`), applies deck effects after
  the turn, pays out the round (`_end_round`), uses consumables (`use_consumable`) and applies trinkets.
- `scripts/card_slot.gd` — `CardSlot`: the `Effect` enum, `INFO` (name / description / color per
  effect) and `play_dir()` for effects that change direction.
- `scripts/difficulty.gd` — `Difficulty`: the per-round curve (`grid`, `traps`, `walls`, `cats`,
  `glue`, `holes`, `belts`, `floorboards`, `turn_limit`)
  and its tuning constants. `main.gd` `_turn_limit` applies the boss changes on top.
- `scripts/board.gd` — `Board`: the `grid` size (smaller boards are drawn zoomed in to fill the same
  area), grid, wall, mouse, cheese, mouse-trap, crumb, chest and cat drawing; `step` / `slide` /
  `jump` movement, each returning true when the round ends (mouse on the cheese, or `is_caught()`:
  `is_trapped()` on a trap or `caught_by_cat()` on a cat or its path). Jumps only check the landing
  cell, so they hop over traps, cat paths and crumbs, but they stop short of walls
  (`_jump_landing`). `walls` is a set of `Vector3i(x, y, 0 right / 1 below)` edge keys
  (`wall_between`, `has_wall`); `squeeze` lets the mouse through them. `step_target` is where a step
  lands and `distances_from` is a BFS around walls and traps (turn limit, SNIFF, the Alley King,
  wall generation, the sim bot). Crumbs emit `crumb_collected`, chests `chest_opened`. `move_cats()`
  walks the cats at the end of a turn, `move_cheese()` runs the cheese for RUNAWAY CHEESE;
  `is_deadly(cell)` says whether moving onto a cell is fatal.
- `scripts/cat.gd` — `Cat`: one roaming cat's cell and this turn's `path` (`steps` cells), and
  `plan()`, which picks the next path. A `hunter` (the Alley King) heads for the mouse instead.
- `scripts/boss.gd` — `Boss`: the `Kind` enum, `INFO` (name / description), and the boss tuning
  constants (cadence, reward, per-boss numbers).
- `scripts/card.gd` — `Card`: the node for a card, with drag-and-drop. `dir` and `stamp` forward to
  its `data`.
- `scripts/card_data.gd` — `CardData`: a deck card's direction and stamp. Piles hold these.
- `scripts/deck.gd` — `Deck`: the run's `cards`, and the round's draw and discard piles built from them.
- `scripts/run.gd` — `Run`: state that lasts a run (deck, slots, hand size, round number, crumbs, trinkets, pouch,
  this and the next boss, bosses beaten).
- `scripts/items.gd` — `Items`: shop content, meaning the `Trinket` and `Consumable` enums with
  name / description / price tables, and the `STAMPS` the shop offers.
- `scripts/shop.gd` — `Shop`: overlay after a won round. Rolls offers, sells them, and picks the card
  for a stamp.
- `scripts/pile_button.gd` — `PileButton`: the draw and discard piles either side of the hand, drawn
  as a card stack with a count (card back / skull). The discard pile also takes dropped cards.
- `scripts/pile_viewer.gd` — `PileViewer`: overlay opened from the pile buttons that lists a
  pile's cards, sorted by direction so the draw order stays hidden.
- `scripts/bug_report.gd` — `BugReport`: F12 panel that saves a description, screenshot, game state
  (`main.gd` `_bug_report_state`) and action log to `bug_reports/` (git-ignored). Log notable events
  with `BugReport.note()`.
- `scripts/dev_menu.gd` — `DevMenu`: F2 drawer of dev tools (debug builds only; doesn't pause). Tabs
  for the run (restart/win/lose round, bosses, shop, speed, invincible), items, cards and slot
  effects, and a board brush that edits cells on click (`Board.cell_clicked`). It works through the
  `# Dev menu` methods at the end of `main.gd` and logs every change as `BugReport.note("DEV: ...")`.
  New game systems should get a dev tool here.
- `tools/balance_sim.gd` — headless balance simulation (see below).

## Conventions
- Statically typed GDScript, tabs, `##` doc comments on classes and non-obvious members.
- Everything is drawn in code (`_draw`, `StyleBoxFlat`): there are no art assets.
- Nodes built in code (`Card`, `CardSlot`) rather than in scenes.
- Movement methods are coroutines; callers `await` them. `Board.animate = false` makes them finish
  instantly (used by the simulation), and new movement code must honor it.

## Commands
Godot 4.6 is at `C:\Program Files\Godot\godot.exe` (the `*_console.exe` launchers in
`C:\Program Files` are broken).

```bash
"/c/Program Files/Godot/godot.exe" --headless --path . --check-only --script res://scripts/main.gd
```

```bash
"/c/Program Files/Godot/godot.exe" --headless --path . --script res://tools/balance_sim.gd -- --rounds 500
```

The sim lets runs go on, so it prints win/loss rates per round number (the difficulty curve). Add
`--round N` to play every round as round N, `--boss <name>` to make every round that boss, and
`--slots N` / `--hand N` to start every run with that many slots / cards in hand.

A new `class_name` script isn't visible to the parse check until Godot refreshes its class cache:
`"/c/Program Files/Godot/godot.exe" --headless --path . --import`.

A PostToolUse hook (`.claude/hooks/godot-check.ps1`) parse-checks every `.gd` file Claude edits.
Skills: `add-card-effect`, `balance-sim`, `ship` (user-only: commit → PR → merge). Agents:
`gdscript-reviewer`, `card-designer`.
