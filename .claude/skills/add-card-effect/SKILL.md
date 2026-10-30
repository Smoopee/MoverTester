---
name: add-card-effect
description: Add a new per-turn slot effect (the game's card content) to Mouse & Cheese — enum, INFO entry, play logic, roll constraints, then check and balance it. Use when asked to add, design or implement a new effect, modifier or card mechanic.
---

# Add a slot effect

Cards are only the four directions (`Card.Dir`). New content is a **slot effect**: a modifier a slot
rolls for one turn that changes how the card in it plays. Work through these steps in order.

## 1. Pick the category
Effects are grouped by what they change. The group decides the color and where the logic goes.

| Category | Color const | Logic goes in | Existing examples |
|---|---|---|---|
| Direction | `DIRECTION_COLOR` | `CardSlot.play_dir()` | REVERSED, MIRROR, WILD |
| Distance | `DISTANCE_COLOR` | `main.gd` `_play()` match | DOUBLE, LEAP, SLIDE, WRAP |
| When / whether it plays | `ORDER_COLOR` | `_play()`, or `_play_order()` for ordering | ECHO, LAST, SNIFF |
| Deck | `DECK_COLOR` | post-turn match in `lock_in()` | RECYCLE, BURN, COPY |
| Spans two slots | any | the slot loop in `lock_in()` (see DIAGONAL) | DIAGONAL |

If an effect fits none of these, say so and propose where it should live before writing code.

## 2. Declare it — `scripts/card_slot.gd`
- Add the value to `enum Effect` inside its category's comment group. Only append within a group: enum
  values are ints, and nothing persists them, so reordering is safe but noisy in diffs.
- Add an `INFO` entry: `Effect.X: ["NAME", "One short sentence of what it does.", CATEGORY_COLOR]`.
  The name is upper case and fits the slot header (about 12 characters). The sentence is the in-game
  tooltip and the effects list, so write it for players.

## 3. Implement it
- **Direction:** add a `match` arm in `play_dir()` that changes `offset` (or returns a `Card.Dir`).
- **Distance / order:** add an arm in `_play()` in `scripts/main.gd`. Return the "reached cheese" bool
  from the board call. Set `last_dir` for every step taken so ECHO keeps working (`_steps()` already
  does this).
- **Deck:** add an arm in the `match effect` after the play loop in `lock_in()`; `played` is what goes
  to the discard pile and `recycled` comes back next hand.
- **New movement** (not a mix of `step` / `slide` / `jump`): add a `Board` method that updates
  `mouse_cell`, returns `mouse_cell == cheese_cell`, and when `animate` is false sets `mouse_pos`
  directly instead of tweening. Copy the shape of `Board.slide()`.
- Any extra wait (like SNIFF's pause) must be skipped when `not board.animate`, or the balance sim
  slows down.

## 4. Roll constraints — `_roll_effects()` in `main.gd`
New effects join the random pool automatically. Add a rule only if needed, following the existing ones:
at most one per turn (BLOCKED), or never when it would break the game (BURN with a small deck).

## 5. Check
1. The PostToolUse hook parse-checks each edited `.gd` file. Fix anything it reports.
2. Run the `balance-sim` skill and compare the new effect's row with the others: big distance gains or
   a high win share mean it's too strong; a near-zero distance change means it barely matters.
3. Play it with `/run`: the header text fits, the tooltip reads well, and the animation looks right.

Report the category you picked, the files changed, and the sim numbers for the new effect.
