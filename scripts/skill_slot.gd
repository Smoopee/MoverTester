class_name SkillSlot
extends BaseButton
## One of the slots above the card slots: Items.SKILL_SLOTS for skills on the left, Items.TRAIT_SLOTS
## for traits on the right (main.gd _refresh_skills). A squarer card showing an owned skill's or trait's
## symbol, name and level, or an empty outline. A skill shows the charges it has left this round, and
## pressing it uses the skill for this turn (main.gd use_skill), which lights it up until the turn's
## cards have played. A trait with charges (NINE LIVES) shows them too, but spends them by itself; the
## rest are always on. Hovering it shows what it does.

const SIZE := Vector2(70, 80)
const ICON_SIZE := 34
const FLASH_TIME := 0.6
## The pips that show charges.
const PIP_RADIUS := 3.0
const PIP_GAP := 9.0
## The name's font size, which shrinks to fit a long name.
const NAME_SIZE := 12
const NAME_MIN_SIZE := 8

## Whether the slot holds a skill or a trait. Set it, id, level, charges and active before adding the
## node to the tree.
var kind := Items.Ability.SKILL
## The Items.Skill or Items.Trait shown, or -1 for an empty slot.
var id := -1
## Its level, from 1.
var level := 1
## Charges left this round.
var charges := 0
## Whether the skill is on this turn.
var active := false

var _icon: ItemIcon
var _filled := StyleBoxFlat.new()
var _empty := StyleBoxFlat.new()
var _glow := StyleBoxFlat.new()
var _on := StyleBoxFlat.new()
## 1 right after flash(), fading to 0.
var _flash := 0.0:
	set(value):
		_flash = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = SIZE
	focus_mode = Control.FOCUS_NONE
	_filled.bg_color = Color("f4ecd8")
	_filled.border_color = _color()
	_filled.set_border_width_all(3)
	_filled.set_corner_radius_all(10)
	_empty.bg_color = Color(0, 0, 0, 0.2)
	_empty.border_color = Color(_color(), 0.22)
	_empty.set_border_width_all(2)
	_empty.set_corner_radius_all(10)
	_glow.set_corner_radius_all(10)
	_on.draw_center = false
	_on.border_color = Color("fff4b0")
	_on.set_border_width_all(3)
	_on.set_corner_radius_all(13)
	_on.set_expand_margin_all(3)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	if id != -1:
		_icon = ItemIcon.ability(kind, id, ICON_SIZE)
		tooltip_text = "%s\n\n%s" % [Items.text(kind, id, level), _use_note()]
		disabled = kind != Items.Ability.SKILL or active or charges <= 0
		mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	else:
		disabled = true
		tooltip_text = "An empty skill slot. You pick a skill at the start of a run and after each boss." \
			if kind == Items.Ability.SKILL else "An empty trait slot. Each chest the mouse opens offers a trait."


func _color() -> Color:
	return Items.color(kind)


func _total() -> int:
	return Items.charges(kind, id, level)


func _use_note() -> String:
	var total := _total()
	var max_level := Items.max_level(kind, id)
	var level_note := " Level %d of %d." % [level, max_level] if max_level > 1 else ""
	if kind == Items.Ability.TRAIT:
		if total > 0:
			return "Works by itself: %d of %d left this round.%s" % [charges, total, level_note]
		return "Always on.%s" % level_note
	if active:
		return "On this turn.%s" % level_note
	if charges <= 0:
		return "No charges left this round. They refill next round.%s" % level_note
	return "Click to use it this turn. %d of %d charge%s left this round.%s" % [charges, total,
		"" if total == 1 else "s", level_note]


## Lights the slot up briefly, when its skill or trait does something.
func flash() -> void:
	create_tween().tween_property(self, "_flash", 0.0, FLASH_TIME).from(1.0)


func _make_custom_tooltip(_for_text: String) -> Object:
	if id == -1:
		return CardSlot.make_tooltip("EMPTY", Color(1, 1, 1, 0.6), tooltip_text, Items.kind_word(kind))
	return CardSlot.make_tooltip(Items.title(kind, id, level), _color(), tooltip_text, Items.kind_word(kind))


func _draw() -> void:
	var font := get_theme_default_font()
	var rect := Rect2(Vector2.ZERO, size)
	if id == -1:
		draw_style_box(_empty, rect)
		draw_string(font, Vector2(0, size.y / 2 + 4), Items.kind_word(kind), HORIZONTAL_ALIGNMENT_CENTER, size.x,
				11, Color(_color(), 0.3))
		return
	var total := _total()
	# Spent for the round, it fades; on this turn, it glows with a bright rim.
	var spent := total > 0 and charges <= 0 and not active
	var fade := Color(1, 1, 1, 0.45) if spent else Color.WHITE
	if active:
		draw_style_box(_on, rect)
	draw_style_box(_filled, rect)
	if active or _flash > 0.0 or is_hovered() and not disabled:
		var glow := maxf(_flash, 0.5 if active else 0.0)
		if is_hovered() and not disabled:
			glow = maxf(glow, 0.2)
		_glow.bg_color = Color(_color(), 0.4 * glow)
		draw_style_box(_glow, rect)
	draw_texture(_icon, Vector2((size.x - ICON_SIZE) / 2, 6), fade)
	var ink := _color().darkened(0.3) * fade
	# The level, as a numeral in the top right corner.
	if level > 1:
		draw_string(font, Vector2(size.x - 22, 15), Items.ROMAN[mini(level, Items.ROMAN.size() - 1)],
				HORIZONTAL_ALIGNMENT_RIGHT, 16, 11, ink)
	var title: String = Items.ability_name(kind, id)
	var font_size := NAME_SIZE
	while font_size > NAME_MIN_SIZE and font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 6:
		font_size -= 1
	draw_string(font, Vector2(0, size.y - 20), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, ink)
	if total == 0:
		draw_string(font, Vector2(0, size.y - 7), "ALWAYS ON", HORIZONTAL_ALIGNMENT_CENTER, size.x, 8, ink)
		return
	# One pip a charge, filled while it's left.
	var left := size.x / 2 - (total - 1) * PIP_GAP / 2
	for i in total:
		var at := Vector2(left + i * PIP_GAP, size.y - 10)
		if i < charges:
			draw_circle(at, PIP_RADIUS, _color())
		else:
			draw_circle(at, PIP_RADIUS, _color().darkened(0.25), false, 1.2, true)
