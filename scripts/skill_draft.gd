class_name SkillDraft
extends Control
## Overlay where the player takes one of Items.DRAFT_CHOICES skills: at the start of a run and after
## each boss (main.gd _open_draft). A skill the run has is offered as its next level. Skills aren't
## sold in the shop, so the drafts are how a run gets them.

signal picked(skill: Items.Skill)

const TILE_SIZE := Vector2(210, 250)
const ICON_SIZE := 48
## Height of a Take button on a touchscreen, sized for a finger.
const TOUCH_BUTTON_HEIGHT := 44

## The Items.Skill values on offer.
var choices: Array[int] = []

var _run: Run
var _title := Label.new()
var _subtitle := Label.new()
var _row := HBoxContainer.new()


## Rolls up to Items.DRAFT_CHOICES skills from the run's draft pool (Run.draft_pool).
static func roll(run: Run) -> Array[int]:
	var pool := run.draft_pool()
	pool.shuffle()
	return pool.slice(0, Items.DRAFT_CHOICES)


func _ready() -> void:
	# Offsets too: this node is already in the tree, so anchors alone would keep its zero size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.17, 0.15)
	style.border_color = Items.SKILL_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 28
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)
	_title.add_theme_font_size_override("font_size", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)
	_subtitle.add_theme_font_size_override("font_size", 15)
	_subtitle.modulate = Color(1, 1, 1, 0.7)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_subtitle)
	_row.add_theme_constant_override("separation", 14)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_row)


## Shows the offers for the run to take one of. Does nothing, returning false, when there are none.
func open(run: Run, offers: Array[int], title: String, subtitle: String) -> bool:
	if offers.is_empty():
		return false
	_run = run
	choices = offers
	_title.text = title
	_subtitle.text = subtitle
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for skill: Items.Skill in choices:
		_row.add_child(_make_tile(skill))
	BugReport.note("Skill draft: %s" % ", ".join(choices.map(func(skill: int) -> String:
		return Items.skill_title(skill, run.skill_level(skill) + 1))))
	show()
	# Takes keyboard focus from Lock In, so Space/Enter can't play a turn under the overlay.
	(_row.get_child(0).find_child("Take", true, false) as Button).grab_focus()
	return true


## Gives the run the skill, or its next level, and closes the draft.
func take(skill: Items.Skill) -> void:
	if not visible or skill not in _run.draft_pool():
		return
	_run.add_skill(skill)
	Sfx.play(Sfx.Sound.BUY)
	BugReport.note("Drafted %s" % Items.skill_title(skill, _run.skill_level(skill)))
	hide()
	picked.emit(skill)


func _make_tile(skill: Items.Skill) -> Control:
	var level := _run.skill_level(skill) + 1
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.border_color = Items.SKILL_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	tile.add_child(vbox)
	var icon := TextureRect.new()
	icon.texture = ItemIcon.skill(skill, ICON_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	vbox.add_child(icon)
	var name_label := Label.new()
	name_label.text = Items.skill_title(skill, level)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Items.SKILL_COLOR)
	name_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(name_label)
	var tag := Label.new()
	tag.text = "NEW" if level == 1 else "LEVEL UP: %d of %d" % [level, Items.skill_max_level(skill)]
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color("fff4b0") if level > 1 else Color(1, 1, 1, 0.55))
	vbox.add_child(tag)
	var description := Label.new()
	description.text = Items.skill_text(skill, level)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(TILE_SIZE.x - 24, 0)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 14)
	vbox.add_child(description)
	var use := Label.new()
	use.text = Items.skill_use_text(skill, level)
	use.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	use.custom_minimum_size = Vector2(TILE_SIZE.x - 24, 0)
	use.modulate = Color(1, 1, 1, 0.65)
	use.add_theme_font_size_override("font_size", 12)
	vbox.add_child(use)

	var button := Button.new()
	button.name = "Take"
	button.text = "Take"
	var color := Items.SKILL_COLOR
	button.add_theme_stylebox_override("normal", _button_style(color.darkened(0.45), color))
	button.add_theme_stylebox_override("hover", _button_style(color.darkened(0.3), color.lightened(0.3)))
	button.add_theme_stylebox_override("pressed", _button_style(color.darkened(0.6), color))
	button.add_theme_stylebox_override("focus", _button_style(color.darkened(0.3), Color("fff4b0")))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("f4ecd8"))
	button.add_theme_font_size_override("font_size", 16)
	button.custom_minimum_size.y = TOUCH_BUTTON_HEIGHT if DisplayServer.is_touchscreen_available() else 34
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta(Sfx.NO_CLICK, true)
	button.pressed.connect(take.bind(skill))
	vbox.add_child(button)
	return tile


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	return style
