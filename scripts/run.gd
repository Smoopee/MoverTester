class_name Run
extends RefCounted
## Everything that carries from round to round until the mouse is caught: the deck, crumbs, trinkets,
## skills, the pouch of consumables, and the card slots and hand size that beating a boss adds to.

const START_SLOTS := 4
const MAX_SLOTS := 8
const START_HAND_SIZE := 6
const MAX_HAND_SIZE := 10
## Beating this round (a boss round) wins the run. The player can then go on in endless mode.
const GOAL_ROUNDS := 21

var deck := Deck.new()
## Card slots each turn.
var slots := START_SLOTS
## Cards dealt each turn.
var hand_size := START_HAND_SIZE
var round_number := 0
var crumbs := 0
## Owned Items.Trinket values.
var trinkets: Array[int] = []
## Owned Items.Skill values, at most Items.SKILL_SLOTS, in the order they fill the skill slots.
var skills: Array[int] = []
## Items.Skill -> its level, from 1 (skill_level). Drafting a skill the run has levels it up.
var skill_levels: Dictionary[int, int] = {}
## Held Items.Consumable values, at most Items.POUCH_SIZE.
var pouch: Array[int] = []
## This round's Boss.Kind, or -1 in a normal round.
var boss := -1
## The Boss.Kind of the next boss round, shown in the shop before it.
var next_boss: Boss.Kind = Boss.roll()
var bosses_beaten := 0
## Set when the player goes on past GOAL_ROUNDS after winning the run.
var endless := false


func _init() -> void:
	deck.new_run()


func has(trinket: Items.Trinket) -> bool:
	return trinket in trinkets


func has_skill(skill: Items.Skill) -> bool:
	return skill in skills


## The skill's level, from 1, or 0 when the run doesn't have it.
func skill_level(skill: Items.Skill) -> int:
	return skill_levels.get(skill, 1) if has_skill(skill) else 0


## Gives the run the skill at level 1, or levels it up if the run has it.
func add_skill(skill: Items.Skill) -> void:
	if has_skill(skill):
		skill_levels[skill] = skill_level(skill) + 1
	else:
		skills.append(skill)
		skill_levels[skill] = 1


func remove_skill(skill: Items.Skill) -> void:
	skills.erase(skill)
	skill_levels.erase(skill)


## What a skill draft can offer: the skills the run doesn't have, while a skill slot is free, and
## level-ups of those it has below their top level.
func draft_pool() -> Array[int]:
	var pool: Array[int] = []
	for skill: Items.Skill in Items.Skill.values():
		if has_skill(skill):
			if skill_level(skill) < Items.skill_max_level(skill):
				pool.append(skill)
		elif skills.size() < Items.SKILL_SLOTS:
			pool.append(skill)
	return pool
