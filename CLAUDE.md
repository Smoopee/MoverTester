# Mouse & Cheese (MoverTester)

A Godot 4.6 deckbuilder prototype. Each turn you draw a hand of direction cards (6 to start), place
them in slots (4 to start), then Lock In: the mouse moves one cell per card, in slot order, on a square grid until it
reaches the cheese, within the round's turn limit. Each turn about half the slots roll an **effect** (REVERSED, SLIDE, ECHO, BURN, ...)
that changes how the card in that slot plays. Slot effects are where the game's content lives.
Each round also gives `DISCARDS_PER_ROUND` (5) discards: right-click a card (on a touchscreen, hold it for `Card.HOLD_TIME`), or drag it down onto the
discard area under the hand (lit while a card is dragged), to swap it for a new draw (`main.gd` `discard_card`).

**Touch** (Android playtests): `DisplayServer.is_touchscreen_available()` turns on the hold-to-discard and
puts Bug and Dev buttons after the trinkets (`main.gd` `_add_touch_button`) in place of F12 and F2.
It also swaps Godot's tooltips, which have no hover to go by, for `TouchTips` (`scripts/touch_tips.gd`):
resting a finger on anything with a tooltip shows it above the finger until it lifts, and a hold that
showed a tip doesn't press the button under it. A card's tip shows as its hold-to-discard starts filling.
Desktop play is unchanged. To try it on a PC, set `Input.emulate_touch_from_mouse`. Bug reports from a
phone save to `user://bug_reports`.

The **Preview** checkbox in the F2 dev menu (`main.gd` `preview_on`) draws where the slotted cards would take the mouse, as a dashed
line on the board ending in a ring (red cross if caught, green on the cheese, pale blue in glue, "?"
before a GAMBLE slot's random move). `main.gd` `_update_preview` plays the turn through the same
`_play_cards` as `lock_in`, with `board` swapped for a hidden, non-animated copy (`Board.copy_from`)
that records the mouse's `trail`, and puts back the card tints, status line, THICK FUR and log after.
Anything that changes the cards, slots or board calls `refresh_preview()` (the dev menu's `_did` does).

**Obstacles** fall into five groups (`scripts/obstacle.gd` `Obstacle`: `Kind`, `Group`, `GROUP_OF`,
`GROUP_INFO`). A new obstacle gets a `Kind` and a group there, and the dev menu's brush dropdown
lists its brushes under that group (`dev_menu.gd` `BRUSH_OBSTACLES`).

Glue, mouse holes, conveyors, floorboards and jump pads are **floor tiles** (`main.gd` `_place_floor`):
at most one per cell, never on the mouse, cheese, a trap or a crumb, acting on the cell a move ends on
unless noted. `Board.is_blocked` covers gaps, chasms and machines (nothing moves onto them; jumps
pass over).

### Tile denial: spoil one cell
- **Mouse traps**: moving onto one catches the mouse (`is_trapped()`). Jumps pass over them.
- **Glue**: the mouse sticks for the rest of the turn (`Board.stuck`; `lock_in` fizzles the cards
  left). Slides stop on it; jumps pass over it.
- **Creaky floorboards**: break into a gap (`broken`) once the mouse walks, slides or jumps off.
  Nothing can move onto a gap, but jumps pass over it. Only placed where breaking every one still
  leaves all cells reachable.

### Structure denial: shape the board
- **Walls**: segments on cell edges, laid in short runs that can turn corners (`main.gd`
  `_place_walls`, which rejects any run that would cut a cell off). Nothing walks, slides or jumps
  through a wall, except the mouse during a turn of the SQUEEZE consumable.
- **Chasms** (`main.gd` `_place_chasms`, `board.chasms`): runs of cells a cell wide that can turn
  corners, never on the mouse, cheese or a trap and never touching another chasm. Like a gap, nothing
  can move onto a chasm cell but jumps pass over it, so LEAP crosses one. A chasm that would cut a
  cell off gets a **bridge** (`bridges`, plain floor) on a straight stretch, or is left out; others
  get one with `BRIDGE_CHANCE`.

### Multi-tile denial: threaten several cells, changing each turn
- **Cats**: each shows the path it will walk this turn; moving onto a cat or its path catches the
  mouse. After the mouse moves, the cats walk their paths and plan new ones, which never cover the
  mouse's cell, the cheese or a trap.
- **Shock pylons** and **flamethrowers** (`scripts/hazard.gd` `Hazard`, `board.hazards`, `main.gd`
  `_place_hazards`). Each is a machine on a cell that nothing can move onto (jumps pass over), placed
  only where it cuts no cell off, and shows a countdown. At the end of each turn, after the cats walk,
  `Board.fire_hazards` counts them all down; one that hits 0 goes off and starts over from its
  `period` (2-4 turns). A pylon shocks the 8 cells around it, walls or not; a flamethrower shoots a jet
  up to `Hazard.FLAME_REACH` (3) cells the way it points, stopped by walls, doors, shut gates, crates
  and other machines (`Board.blast_cells`). Only where the mouse ends the turn counts: in a blast, it's
  caught (`blasted_by`, part of `is_caught()`). On the turn a machine shows 1 its blast cells are
  shaded strongly (`in_blast`), and the preview ends in a red cross there.

### Movement options: carry the mouse farther
- **Jump pads** (`pads`, cell -> offset): throw the mouse 2-4 cells the way the pad's arrow points,
  as a jump (`Board.jump_landing`). Only placed where the whole throw is clear and doesn't land on a trap.
- **Mouse holes**, in linked pairs (`holes[0]` with `holes[1]`, ...): pop out of the other one.
  Slides stop on one (and go down it); jumps pass over it.
- **Conveyor belts**: carry the mouse a cell the belt's way, and on along the belt. Never placed
  to push into a wall, off the board or onto a trap.

These chain (`Board._ride`); the pathfinding ignores them (and glue).

### Multi-step puzzles: a shut shortcut
Locked doors and switches (`main.gd` `_place_locks`). Each door or gate sits in a short run of wall,
kept from `LOCK_TRIES` tries as the one that makes the way to the cheese longest while it's shut, and
like walls it never cuts a cell off: opening it is a shortcut. Doors and shut gates are walls to
everything (`Board.is_barrier`), and the turn limit counts them as shut.
- **Keys and locked doors** (`keys`, `doors`): walking or sliding over a key picks it up
  (`keys_held`, shown next to the HUD, for this round only). Walking or sliding into a door with a
  key uses the key and opens the door for good (`Board._unlock`). Jumps stop short of doors.
- **Switches**: a pressure plate (`plates[i]`), the gates it opens (`gates`, edge -> plate index) and
  a crate (`crates`). A gate is open while a crate or the mouse is on its plate (`is_pressed`). The
  mouse pushes a crate by stepping into it, onto plain floor or a plate (`_crate_can_enter`); slides
  stop short of a crate (or push one right next to the mouse) and jumps don't land on one. Each crate
  starts in a straight line from its plate with the lane kept clear (`_crate_lanes`), and no plate is
  next to its gate. Cats never walk through gates, open or not, or onto crates.

**Difficulty** (`scripts/difficulty.gd`) rises with the round number: the first two rounds are a
small board (8x8) with no obstacles. The grid grows by `Difficulty.GRID_GROWTH` (2) cells a side
after each boss round (8, 10, 12, ... up to 20x20 from round 19). Traps and wall runs come from
round 3, a set number per board cell (`TRAPS_PER_CELL`, `WALLS_PER_CELL`), so they step up with the
board. The other obstacles join one at a time on the rounds between boss rounds, spread over the
21-round run: cats (round 4), glue (5), jump pads (7), mouse holes (8), conveyors (10), locked doors
(11), floorboards (13), switches (14), chasms (16), shock pylons (17) and flamethrowers (19), each
then growing every few rounds to its max, which the later ones reach in endless mode. Every round has a turn limit, set from the mouse-to-cheese
path length around the walls and traps (`Board.distances_from`) with a few spare turns that shrink
over the run.

A round may have a **chest** (`main.gd` `CHEST_CHANCE`, `_place_chests`), opened by walking or
sliding over it like a crumb. It pays `CHEST_CRUMBS` (12) (`_open_chest`).

Card slots (`Run.slots`, up to 8, never more than cards in hand) and cards in hand (`Run.hand_size`,
up to 10) grow only by beating a boss: each adds `Boss.SLOTS_GAINED` and `Boss.HAND_GAINED` (1 each)
for the rest of the run, from the next round (`main.gd` `_boss_upgrade`). `_build_slots` rebuilds the
slots at the start of a turn and shrinks the cards so the slots and the hand each fit their row.

Rounds chain into a **run**: the deck, crumbs, trinkets, pouch, slots and hand size carry over until a trap
or a cat catches the mouse (or a pylon or flamethrower), or the turns run out, or a boss round ends short of its score target (`main.gd` `lost()`), which starts a new run.
Beating round `Run.GOAL_ROUNDS` (21, a boss round) wins the run (`main.gd` `won_run()`): the win
panel offers Endless, which goes on to the shop and sets `Run.endless` (the difficulty keeps
climbing to its caps), or New Run. The HUD shows "Round N of 21", then "Endless round N". A won round pays crumbs (`WIN_CRUMBS` + unused discards + the score bonus, plus
crumbs picked up on the board), then opens the **shop**. It sells trinkets (passive for the run),
skills, consumables (held in the pouch, used once) and card stamps (a slot effect stuck on one card).
The trinket and skill rows each have a Reroll button (`shop.gd` `_reroll`): the first reroll in a
visit costs `Shop.REROLL_PRICE` (5) crumbs and each one after costs 5 more, counted across both rows. A
stamped card plays its slot's effect first, then its stamp (`main.gd` `_play`): a BURN slot with a
SLIDE stamp moves 3 cells, then slides. A burned card stays burned whatever its stamp. Some effects
are stamps only, never rolled on a slot (`CardSlot.STAMP_ONLY`). Some are set by clicking the stamp
band on a card in play (`Card.SET_STAMPS`, stored on the `CardData`), and STEADY makes the card ignore
its slot: read a slot's effect on a card through `main.gd` `_slot_effect` / `_play_dir`.

Each round also has a **score** (`scripts/score.gd` `Score`, `main.gd` `round_score`), kept apart from
crumbs, which are money. Each turn adds up points (`Score.CELL_POINTS` a cell walked, slid or
jumped, plus crumbs, chests and rides on holes, belts and pads), times the turn's mult, which starts
at 1. The board reports each move with `Board.mouse_moved` (a `Board.Motion`: STEP, SLIDE, JUMP, RIDE
or BUMP) to `main.gd` `_on_mouse_moved`, `_score_cards` adds the mult that goes by the cards played,
and `_bank_turn` adds the turn to the score, with `Score.SPARE_TURN_MULT` per turn left over on the
turn that reaches the cheese. Only the real board is connected, so the preview scores nothing. The
round's target (`Score.target`) grows each round, and more in a boss round. Meeting it pays bonus
crumbs (`Score.crumbs`), and missing it in a boss round ends the run (`_short_of_boss_target`). The
score trinkets are BUTTER PAT and RIDE TICKET; the score skills are HARD HEAD, SHOW-OFF and DAREDEVIL.

Score shows as **popups** (`scripts/score_popup.gd` `ScorePopup`): points pop up on the cell that
made them (`main.gd` `_add_points`, which every point source goes through), mult from trinkets and skills over
the mouse (`_pop_mult`), and the banked turn over the board (`pop_turn_score`). Each popup's
intensity grows with the score (a move's points on a log scale, a turn's against the round's target):
bigger, hotter in color, shaking, with sparks and a ring at the top. No popups when
`Board.animate` is off. The dev menu's Items tab has Pop buttons to try the sizes.

**Skills** (`Items.Skill`, `Run.skills`) are always-on abilities for the rest of the run, held in
`Items.SKILL_SLOTS` (4) slots shown above the card slots (`main.gd` `_refresh_skills`). WARP makes
every step wrap round the board's edges like a WRAP slot (`Board.warp`); EFFICIENT gives +1 discard
for each crumb picked up (`_on_crumb_collected`); THICK FUR breaks the first trap each round
(`_survive_trap`). A skill's slot lights up (`_flash_skill`) whenever it does something.

**Trinkets are objects, skills are traits.** Any new or renamed item follows these rules:
- A **trinket** is a physical thing the mouse carries, named as one (PIGGY BANK, CRUMB MAGNET), and
  its effect is what that object would plausibly do: a piggy bank saves crumbs, a magnet pulls them in.
  Never a body part, an ability or an adjective.
- A **skill** is a trait or ability of the mouse itself, named as something the mouse is or can do
  (WARP, EFFICIENT), and its effect is that trait at work. Never an object.
- If an idea reads as something the mouse *has in its pouch*, it's a trinket; if it reads as
  something the mouse *is or does*, it's a skill. Pick the name and the category together.

Every `Boss.EVERY` (3) rounds is a **boss round** with an extra rule: THE ALLEY KING (a big cat that
hunts the mouse, on top of the usual cats), RUNAWAY CHEESE (the cheese runs from the mouse; a few
extra turns) or KITCHEN LIGHT (a shorter turn limit). The shop before it names the boss. Beating one
pays `Boss.WIN_CRUMBS`, adds a card slot and a card in hand, and offers a free trinket.

## Layout
- `scenes/main.tscn` — the only scene. Nodes the code uses are `%Unique` names (`%Board`, `%Hand`,
  `%SlotRow`, `%LockInButton`, `%WinPanel`, ...).
- `scripts/main.gd` — turn controller: starts runs and rounds (`new_run` / `new_round`), deals hands,
  rolls slot effects (`_roll_effects`), plays a turn (`lock_in` → `_play`), applies deck effects after
  the turn, pays out the round (`_end_round`), uses consumables (`use_consumable`) and applies trinkets.
- `scripts/card_slot.gd` — `CardSlot`: the `Effect` enum, `INFO` (name / description / color per
  effect) and `play_dir()` for effects that change direction.
- `scripts/difficulty.gd` — `Difficulty`: the per-round curve (`grid`, `traps`, `walls`, `cats`,
  `glue`, `pads`, `holes`, `belts`, `doors`, `floorboards`, `switches`, `chasms`, `pylons`, `flamers`,
  `turn_limit`)
  and its tuning constants. `main.gd` `_turn_limit` applies the boss changes on top.
- `scripts/board.gd` — `Board`: the `grid` size (smaller boards are drawn zoomed in to fill the same
  area), grid, wall, mouse, cheese, mouse-trap, crumb, chest and cat drawing; `step` / `slide` /
  `jump` movement, each returning true when the round ends (mouse on the cheese, or `is_caught()`:
  `is_trapped()` on a trap, `caught_by_cat()` on a cat or its path, or `is_blasted()` after
  `fire_hazards`). Jumps only check the landing
  cell, so they hop over traps, cat paths and crumbs, but they stop short of walls
  (`jump_landing`). `walls` is a set of `Vector3i(x, y, 0 right / 1 below)` edge keys
  (`wall_between`, `has_wall`), as are `doors` and `gates`; `squeeze` lets the mouse through all three. `step_target` is where a step
  lands and `distances_from` is a BFS around walls and traps (turn limit, SNIFF, the Alley King,
  wall generation, the sim bot). Crumbs emit `crumb_collected`, chests `chest_opened`, keys
  `key_collected`, and a door a key opens `door_unlocked`. `clear_layout` empties the floor tiles,
  chasms, doors, keys, switches, pylons and flamethrowers before a round is laid out. `move_cats()`
  walks the cats at the end of a turn, `move_cheese()` runs the cheese for RUNAWAY CHEESE;
  `is_deadly(cell)` says whether moving onto a cell is fatal, and `in_blast(cell)` whether ending
  this turn there is.
- `scripts/score.gd` — `Score`: the round score's tuning (points, mult, score trinket numbers), the
  per-round `target()` and the bonus `crumbs()` it pays.
- `scripts/score_popup.gd` — `ScorePopup`: a floating score number (`spawn()`), drawn more intensely
  the higher the score.
- `scripts/hazard.gd` — `Hazard`: one shock pylon or flamethrower: `kind`, `cell`, `dir`, `period`
  and `timer` (turns until it goes off).
- `scripts/obstacle.gd` — `Obstacle`: the obstacle `Kind`s, the five `Group`s they fall into
  (`GROUP_OF`, `GROUP_INFO` name / description) and `kinds_in(group)`.
- `scripts/cat.gd` — `Cat`: one roaming cat's cell and this turn's `path` (`steps` cells), and
  `plan()`, which picks the next path. A `hunter` (the Alley King) heads for the mouse instead.
- `scripts/boss.gd` — `Boss`: the `Kind` enum, `INFO` (name / description), and the boss tuning
  constants (cadence, reward, per-boss numbers).
- `scripts/card.gd` — `Card`: the node for a card, with drag-and-drop. `dir` and `stamp` forward to
  its `data`.
- `scripts/card_data.gd` — `CardData`: a deck card's direction and stamp. Piles hold these.
- `scripts/deck.gd` — `Deck`: the run's `cards`, and the round's draw and discard piles built from them.
- `scripts/run.gd` — `Run`: state that lasts a run (deck, slots, hand size, round number, crumbs, trinkets,
  skills, pouch, this and the next boss, bosses beaten).
- `scripts/items.gd` — `Items`: shop content, meaning the `Trinket`, `Skill` and `Consumable` enums
  with name / description / price tables, and the `STAMPS` the shop offers.
- `scripts/item_icon.gd` — `ItemIcon`: a `Texture2D` that draws a trinket's, skill's, consumable's or
  stamp's symbol in code (`ItemIcon.trinket(id)`, ...), so it works as a `Button.icon` or in a
  `TextureRect`. A new trinket, skill or consumable needs a symbol in `_draw_trinket` / `_draw_skill`
  / `_draw_consumable`.
- `scripts/skill_slot.gd` — `SkillSlot`: one of the skill slots in `%SkillRow` above the card slots,
  drawn as a squarer card with the skill's symbol and name (or empty). `flash()` lights it up when its
  skill does something.
- `scripts/shop.gd` — `Shop`: overlay after a won round. Rolls offers, rerolls the trinket and skill
  rows, sells them, and picks the card for a stamp.
- `scripts/touch_tips.gd` — `TouchTips`: hold-to-show tooltips on a touchscreen (see Touch above).
- `scripts/pile_button.gd` — `PileButton`: the draw and discard piles either side of the hand, drawn
  as a card stack with a count (card back / skull). The discard pile also takes dropped cards.
- `scripts/pile_viewer.gd` — `PileViewer`: overlay opened from the pile buttons that lists a
  pile's cards, sorted by direction so the draw order stays hidden.
- `scripts/bug_report.gd` — `BugReport`: F12 (or touch Bug button) panel that saves a description, screenshot, game state
  (`main.gd` `_bug_report_state`) and action log to `bug_reports/` (git-ignored). Log notable events
  with `BugReport.note()`.
- `scripts/dev_menu.gd` — `DevMenu`: F2 (or touch Dev button) drawer of dev tools (debug builds only; doesn't pause). Tabs
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
`--slots N` / `--hand N` to start every run with that many slots / cards in hand. The round table
also shows the bot's mean score in won rounds against the target. The bot plays for the cheese, not the
score, so its score is a floor. `--trinkets butter_pat,ride_ticket` starts every run with those
trinkets, and `--skills show_off,daredevil` with those skills.

A new `class_name` script isn't visible to the parse check until Godot refreshes its class cache:
`"/c/Program Files/Godot/godot.exe" --headless --path . --import`.

A PostToolUse hook (`.claude/hooks/godot-check.ps1`) parse-checks every `.gd` file Claude edits.
Another (`.claude/hooks/sheet-reminder.ps1`) reminds Claude to update the design sheet (below) after
an edit to `difficulty.gd` or `score.gd`, or to a `const` in `boss.gd`, `run.gd`, `main.gd` or `board.gd`.
Skills: `add-card-effect`, `balance-sim`, `ship` (user-only: commit → PR → merge). Agents:
`gdscript-reviewer`, `card-designer`.

## Design sheet
The Google Sheet **Mouse and Cheese**
(https://docs.google.com/spreadsheets/d/1Os7GqZFWxtAs7zuOeQZ3AQ9smqf0qJ56Mkpwy8LJ-7s/edit) mirrors
the game's tuning, and must be updated in the same change as the code, through the Google Sheets
connector:
- **Rules** tab: every tuning value (blue) with the constant it comes from, and the obstacle
  schedule (first round, count, growth, max) in the five obstacle groups.
- **Rounds** tab: one row per round to `Run.GOAL_ROUNDS` plus a few endless rounds, all formulas
  over the Rules tab, with a "What's new" note per round and notes on how a round works under it.

A changed value goes in its Rules cell. A change to how a value is used (a formula in
`Difficulty`, `Score.target`, the payout in `_end_round`, ...) also changes the Rounds formula
that copies it, and anything the "What's new" or round notes say about it. A new tuning constant
or obstacle gets a Rules row and, if it varies by round, a Rounds column. Check the numbers against
the game afterwards (e.g. `Difficulty.describe` and `Score.target` for each round in a throwaway
`extends SceneTree` script run with `--script`).
