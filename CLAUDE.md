# Mouse & Cheese (MoverTester)

A Godot 4.6 deckbuilder prototype. Each turn you draw a hand of direction cards, place up to four in
slots, then Lock In: the mouse moves one cell per card, in slot order, on a 20x20 grid until it
reaches the cheese. Each turn about half the slots roll an **effect** (REVERSED, SLIDE, ECHO, BURN, ...)
that changes how the card in that slot plays. Slot effects are where the game's content lives.
Each round also gives `DISCARDS_PER_ROUND` (5) discards: right-click a card, or drag it onto the
Discard button, to swap it for a new draw (`main.gd` `discard_card`).

Rounds chain into an endless **run**: the deck, crumbs, trinkets and pouch carry over until a trap
catches the mouse, which starts a new run. A won round pays crumbs (`WIN_CRUMBS` + unused discards, plus
crumbs picked up on the board), then opens the **shop**. It sells trinkets (passive for the run),
consumables (held in the pouch, used once) and card stamps (a slot effect stuck on one card, used when
that card is in a plain slot).

## Layout
- `scenes/main.tscn` — the only scene. Nodes the code uses are `%Unique` names (`%Board`, `%Hand`,
  `%SlotRow`, `%LockInButton`, `%WinPanel`, ...).
- `scripts/main.gd` — turn controller: starts runs and rounds (`new_run` / `new_round`), deals hands,
  rolls slot effects (`_roll_effects`), plays a turn (`lock_in` → `_play`), applies deck effects after
  the turn, pays out the round (`_end_round`), uses consumables (`use_consumable`) and applies trinkets.
- `scripts/card_slot.gd` — `CardSlot`: the `Effect` enum, `INFO` (name / description / color per
  effect), `play_dir()` for effects that change direction, and `effect_for(card)` (the slot's effect,
  else the card's stamp).
- `scripts/board.gd` — `Board`: grid, mouse, cheese, mouse-trap and crumb drawing; `step` / `slide` /
  `jump` movement, each returning true when the round ends (mouse on the cheese, or `is_caught()`
  on a trap). Jumps only check the landing cell, so they hop over traps and crumbs. Crumbs emit
  `crumb_collected`.
- `scripts/card.gd` — `Card`: the node for a card, with drag-and-drop. `dir` and `stamp` forward to
  its `data`.
- `scripts/card_data.gd` — `CardData`: a deck card's direction and stamp. Piles hold these.
- `scripts/deck.gd` — `Deck`: the run's `cards`, and the round's draw and discard piles built from them.
- `scripts/run.gd` — `Run`: state that lasts a run (deck, round number, crumbs, trinkets, pouch).
- `scripts/items.gd` — `Items`: shop content, meaning the `Trinket` and `Consumable` enums with
  name / description / price tables, and the `STAMPS` the shop offers.
- `scripts/shop.gd` — `Shop`: overlay after a won round. Rolls offers, sells them, and picks the card
  for a stamp.
- `scripts/pile_viewer.gd` — `PileViewer`: overlay opened from the HUD's pile buttons that lists a
  pile's cards, sorted by direction so the draw order stays hidden.
- `scripts/bug_report.gd` — `BugReport`: F12 panel that saves a description, screenshot, game state
  (`main.gd` `_bug_report_state`) and action log to `bug_reports/` (git-ignored). Log notable events
  with `BugReport.note()`.
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

A PostToolUse hook (`.claude/hooks/godot-check.ps1`) parse-checks every `.gd` file Claude edits.
Skills: `add-card-effect`, `balance-sim`, `ship` (user-only: commit → PR → merge). Agents:
`gdscript-reviewer`, `card-designer`.
