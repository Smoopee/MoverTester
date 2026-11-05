class_name Run
extends RefCounted
## Everything that carries from round to round until the mouse is caught: the deck, crumbs, trinkets,
## skills, traits, the pouch of consumables, and the card slots and hand size that beating a boss adds to.

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
## Owned Items.Trait values, at most Items.TRAIT_SLOTS, in the order they fill the trait slots.
var traits: Array[int] = []
## Items.Skill -> its level, from 1, and the same for Items.Trait. Drafting one the run has levels it up.
var skill_levels: Dictionary[int, int] = {}
var trait_levels: Dictionary[int, int] = {}
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


## The run's skills or traits, in slot order.
func owned(kind: Items.Ability) -> Array[int]:
	return skills if kind == Items.Ability.SKILL else traits


func _levels(kind: Items.Ability) -> Dictionary[int, int]:
	return skill_levels if kind == Items.Ability.SKILL else trait_levels


func has_ability(kind: Items.Ability, id: int) -> bool:
	return id in owned(kind)


## The skill's or trait's level, from 1, or 0 when the run doesn't have it.
func level(kind: Items.Ability, id: int) -> int:
	return _levels(kind).get(id, 1) if has_ability(kind, id) else 0


func has_skill(skill: Items.Skill) -> bool:
	return has_ability(Items.Ability.SKILL, skill)


func has_trait(trait_id: Items.Trait) -> bool:
	return has_ability(Items.Ability.TRAIT, trait_id)


func skill_level(skill: Items.Skill) -> int:
	return level(Items.Ability.SKILL, skill)


func trait_level(trait_id: Items.Trait) -> int:
	return level(Items.Ability.TRAIT, trait_id)


## Gives the run the skill or trait at level 1, or levels it up if the run has it.
func add(kind: Items.Ability, id: int) -> void:
	if has_ability(kind, id):
		_levels(kind)[id] = level(kind, id) + 1
	else:
		owned(kind).append(id)
		_levels(kind)[id] = 1


func remove(kind: Items.Ability, id: int) -> void:
	owned(kind).erase(id)
	_levels(kind).erase(id)


## Sets an owned skill's or trait's level.
func set_level(kind: Items.Ability, id: int, to: int) -> void:
	if has_ability(kind, id):
		_levels(kind)[id] = to


## What a draft of skills or traits can offer: the ones the run doesn't have, while a slot is free,
## and level-ups of those it has below their top level.
func draft_pool(kind: Items.Ability) -> Array[int]:
	var pool: Array[int] = []
	for id: int in Items.all(kind):
		if has_ability(kind, id):
			if level(kind, id) < Items.max_level(kind, id):
				pool.append(id)
		elif owned(kind).size() < Items.slots(kind):
			pool.append(id)
	return pool
