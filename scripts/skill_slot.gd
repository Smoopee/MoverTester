class_name SkillSlot
extends BaseButton
## One of the Items.SKILL_SLOTS skill slots above the card slots: a squarer card showing an owned
## skill's symbol, name and the charges it has left this round, or an empty outline. Pressing it uses
## the skill for this turn (main.gd use_skill), which lights it up until the turn's cards have played.
## Hovering it shows what the skill does.

const SIZE := Vector2(84, 88)
const ICON_SIZE := 40
const FLASH_TIME := 0.6
## The pips that show charges.
const PIP_RADIUS := 3.5
const PIP_GAP := 10.0

## The Items.Skill shown, or -1 for an empty slot. Set it, charges and active before adding the node
## to the tree.
var skill := -1
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
	_filled.border_color = Items.SKILL_COLOR
	_filled.set_border_width_all(3)
	_filled.set_corner_radius_all(10)
	_empty.bg_color = Color(0, 0, 0, 0.2)
	_empty.border_color = Color(1, 1, 1, 0.18)
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
	if skill != -1:
		_icon = ItemIcon.skill(skill, ICON_SIZE)
		tooltip_text = "%s\n\n%s" % [Items.SKILLS[skill][1], _charge_note()]
		disabled = active or charges <= 0
		mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND
	else:
		disabled = true
		tooltip_text = "An empty skill slot. Skills are sold in the shop."


func _charge_note() -> String:
	var total: int = Items.SKILL_CHARGES[skill]
	if active:
		return "On this turn."
	if charges <= 0:
		return "No charges left this round. They refill next round."
	return "Click to use it this turn. %d of %d charge%s left this round." % [charges, total,
		"" if total == 1 else "s"]


## Lights the slot up briefly, when its skill does something.
func flash() -> void:
	create_tween().tween_property(self, "_flash", 0.0, FLASH_TIME).from(1.0)


func _make_custom_tooltip(_for_text: String) -> Object:
	if skill == -1:
		return CardSlot.make_tooltip("EMPTY", Color(1, 1, 1, 0.6), tooltip_text, "SKILL")
	return CardSlot.make_tooltip(Items.SKILLS[skill][0], Items.SKILL_COLOR, tooltip_text, "SKILL")


func _draw() -> void:
	var font := get_theme_default_font()
	var rect := Rect2(Vector2.ZERO, size)
	if skill == -1:
		draw_style_box(_empty, rect)
		draw_string(font, Vector2(0, size.y / 2 + 5), "SKILL", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
				Color(1, 1, 1, 0.2))
		return
	# Spent for the round, it fades; on this turn, it glows with a bright rim.
	var spent := charges <= 0 and not active
	var fade := Color(1, 1, 1, 0.45) if spent else Color.WHITE
	if active:
		draw_style_box(_on, rect)
	draw_style_box(_filled, rect)
	if active or _flash > 0.0 or is_hovered() and not disabled:
		var glow := maxf(_flash, 0.5 if active else 0.0)
		if is_hovered() and not disabled:
			glow = maxf(glow, 0.2)
		_glow.bg_color = Color(Items.SKILL_COLOR, 0.4 * glow)
		draw_style_box(_glow, rect)
	draw_texture(_icon, Vector2((size.x - ICON_SIZE) / 2, 7), fade)
	draw_string(font, Vector2(0, size.y - 22), Items.SKILLS[skill][0], HORIZONTAL_ALIGNMENT_CENTER, size.x,
			13, Items.SKILL_COLOR.darkened(0.25) * fade)
	# One pip a charge, filled while it's left.
	var total: int = Items.SKILL_CHARGES[skill]
	var left := size.x / 2 - (total - 1) * PIP_GAP / 2
	for i in total:
		var at := Vector2(left + i * PIP_GAP, size.y - 11)
		if i < charges:
			draw_circle(at, PIP_RADIUS, Items.SKILL_COLOR)
		else:
			draw_circle(at, PIP_RADIUS, Items.SKILL_COLOR.darkened(0.25), false, 1.2, true)
