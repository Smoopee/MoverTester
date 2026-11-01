class_name SkillSlot
extends Control
## One of the Items.SKILL_SLOTS skill slots above the card slots: a squarer card showing an owned
## skill's symbol and name, or an empty outline. Hovering it shows what the skill does.

const SIZE := Vector2(84, 88)
const ICON_SIZE := 44
const FLASH_TIME := 0.6

## The Items.Skill shown, or -1 for an empty slot. Set it before adding the node to the tree.
var skill := -1

var _icon: ItemIcon
var _filled := StyleBoxFlat.new()
var _empty := StyleBoxFlat.new()
var _glow := StyleBoxFlat.new()
## 1 right after flash(), fading to 0.
var _flash := 0.0:
	set(value):
		_flash = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = SIZE
	_filled.bg_color = Color("f4ecd8")
	_filled.border_color = Items.SKILL_COLOR
	_filled.set_border_width_all(3)
	_filled.set_corner_radius_all(10)
	_empty.bg_color = Color(0, 0, 0, 0.2)
	_empty.border_color = Color(1, 1, 1, 0.18)
	_empty.set_border_width_all(2)
	_empty.set_corner_radius_all(10)
	_glow.set_corner_radius_all(10)
	if skill != -1:
		_icon = ItemIcon.skill(skill, ICON_SIZE)
		tooltip_text = Items.SKILLS[skill][1]
	else:
		tooltip_text = "An empty skill slot. Skills are sold in the shop."


## Lights the slot up briefly, when its skill does something.
func flash() -> void:
	create_tween().tween_property(self, "_flash", 0.0, FLASH_TIME).from(1.0)


func _make_custom_tooltip(_for_text: String) -> Object:
	if skill == -1:
		return CardSlot.make_tooltip("EMPTY", Color(1, 1, 1, 0.6), tooltip_text, "SKILL")
	return CardSlot.make_tooltip(Items.SKILLS[skill][0], Items.SKILL_COLOR, tooltip_text, "SKILL")


func _draw() -> void:
	var font := get_theme_default_font()
	if skill == -1:
		draw_style_box(_empty, Rect2(Vector2.ZERO, size))
		draw_string(font, Vector2(0, size.y / 2 + 5), "SKILL", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13,
				Color(1, 1, 1, 0.2))
		return
	draw_style_box(_filled, Rect2(Vector2.ZERO, size))
	if _flash > 0.0:
		_glow.bg_color = Color(Items.SKILL_COLOR, 0.4 * _flash)
		draw_style_box(_glow, Rect2(Vector2.ZERO, size))
	draw_texture(_icon, Vector2((size.x - ICON_SIZE) / 2, 9))
	draw_string(font, Vector2(0, size.y - 12), Items.SKILLS[skill][0], HORIZONTAL_ALIGNMENT_CENTER, size.x,
			13, Items.SKILL_COLOR.darkened(0.25))
