---
name: balance-sim
description: Run the headless Mouse & Cheese balance simulation (tools/balance_sim.gd) and interpret it — turns-to-cheese distribution and per-slot-effect strength. Use when asked about balance, difficulty, round length, or whether an effect is too strong or weak, and after adding or changing an effect.
---

# Balance simulation

`tools/balance_sim.gd` loads the real `scenes/main.tscn` with `Board.animate = false` and plays it with
a greedy bot, so it always tests the current rules. 500 rounds take a few seconds.

## Run
```bash
"/c/Program Files/Godot/godot.exe" --headless --path . --script res://tools/balance_sim.gd -- --rounds 500 --seed 1
```
- `--rounds N` (default 500); `--seed S` (default 1). The same seed gives the same output, so for a
  before/after comparison keep the seed and change one thing. Then check that the conclusion holds
  with 2–3 other seeds.
- Runs go on until the bot loses (caught, or out of turns), so rounds climb the difficulty curve in
  `scripts/difficulty.gd`: bigger boards, more traps and cats, fewer spare turns.
- `--round N` plays every round as round N of a fresh run, to test one point on the curve with
  enough rounds to trust.
- `--boss NAME` (`alley_king`, `runaway_cheese`, `kitchen_light`) makes every round that boss, each
  on a fresh run. Without it boss rounds are off, so the default output is plain rounds only. Pair it
  with `--round N` and compare a boss's caught / out-of-time rates against a plain run of that round
  with the same seed.
- Script errors print as `SCRIPT ERROR`. Fix them before reading any numbers.

## The bot
For each slot in play order (LAST slots at the end) it places the hand card that moves the mouse
closest to the cheese, and only if that move gets closer. It picks the best WILD direction, skips
BLOCKED slots, and ignores distance effects (it plans as if every card moves one cell). It's a
baseline player, not a good one, so effects that reward planning (ECHO, DIAGONAL, LAST, SLIDE
setups) look weaker here than they are for humans.

## Reading the output
- **Caught / out of time:** share of all rounds lost to a trap, a cat, or the turn limit.
- **Round table:** one row per round number reached: its board, how many times it was played, and
  won / trap / cat / time percentages plus mean turns in won rounds. Rounds 1–2 should be near 100%
  won and the win rate should slide down from there. Late rows have few rounds, so treat them as noise
  (or check them with `--round N`).
- **Turns to cheese:** mean, median, max and a histogram. Rounds that hit 200 turns count as
  `unfinished`, which should always be 0. A big tail of 10+ turn rounds means rounds drag on.
- **Effect table**, one row per effect:
  - `rolled` — slot-turns where it appeared. These should be roughly equal unless `_roll_effects()`
    restricts the effect.
  - `used%` — how often the bot found a card worth putting there. A low value means awkward to use
    (LAST is low because earlier slots take the best cards).
  - `gain/turn` — average cells closer to the cheese on turns that used it. This is a whole-turn
    number, so compare effects against each other. The "plain slots" baseline is biased low
    (plain-only turns tend to happen close to the cheese).
  - `win turns` — winning turns where the effect was in use. A high value means it finishes rounds.
- **What to flag:** gain/turn well above the pack (about +0.5) is a candidate for too strong; near or
  below the plain baseline (GAMBLE) is weak or swingy; very low used% means it's often a dead slot.

Report the numbers that matter for the question asked, the seed(s) used, and the bot caveat when it
applies to the effect in question.
