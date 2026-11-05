class_name Draft
extends Control
## Overlay where the player takes one of Items.DRAFT_CHOICES skills or traits (an Items.Ability):
## skills at the start of a run and after each boss, traits from each chest the mouse opens (main.gd
## _open_draft, _open_chest_draft). One the run has is offered as its next level. Skills and traits
## aren't sold in the shop, so the drafts are how a run gets them.

signal picked(kind: Items.Ability, id: int)

const TILE_SIZE := Vector2(210, 250)
const ICON_SIZE := 48
## Height of a Take button on a touchscreen, sized for a finger.
const TOUCH_BUTTON_HEIGHT := 44

## Whether skills or traits are on offer.
var kind := Items.Ability.SKILL
## The Items.Skill or Items.Trait values on offer.
var choices: Array[int] = []

var _run: Run
var _style := StyleBoxFlat.new()
var _title := Label.new()
var _subtitle := Label.new()
var _row := HBoxContainer.new()


## Rolls up to Items.DRAFT_CHOICES skills or traits from the run's draft pool (Run.draft_pool).
static func roll(run: Run, of: Items.Ability) -> Array[int]:
	var pool := run.draft_pool(of)
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

	_style.bg_color = Color(0.2, 0.17, 0.15)
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(12)
	_style.content_margin_left = 32
	_style.content_margin_right = 32
	_style.content_margin_top = 24
	_style.content_margin_bottom = 28
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _style)
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


## Shows the offers, skills or traits (of), for the run to take one of. Does nothing, returning
## false, when there are none.
func open(run: Run, of: Items.Ability, offers: Array[int], title: String, subtitle: String) -> bool:
	if offers.is_empty():
		return false
	_run = run
	kind = of
	choices = offers
	_style.border_color = Items.color(kind)
	_title.text = title
	_subtitle.text = subtitle
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	for id in choices:
		_row.add_child(_make_tile(id))
	BugReport.note("%s draft: %s" % [Items.kind_word(kind).capitalize(), ", ".join(choices.map(
		func(id: int) -> String: return Items.title(kind, id, run.level(kind, id) + 1)))])
	show()
	# Takes keyboard focus from Lock In, so Space/Enter can't play a turn under the overlay.
	(_row.get_child(0).find_child("Take", true, false) as Button).grab_focus()
	return true


## Gives the run the skill or trait, or its next level, and closes the draft.
func take(id: int) -> void:
	if not visible or id not in _run.draft_pool(kind):
		return
	_run.add(kind, id)
	Sfx.play(Sfx.Sound.BUY)
	BugReport.note("Drafted %s" % Items.title(kind, id, _run.level(kind, id)))
	hide()
	picked.emit(kind, id)


func _make_tile(id: int) -> Control:
	var level := _run.level(kind, id) + 1
	var color := Items.color(kind)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.border_color = color
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
	icon.texture = ItemIcon.ability(kind, id, ICON_SIZE)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	vbox.add_child(icon)
	var name_label := Label.new()
	name_label.text = Items.title(kind, id, level)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", color)
	name_label.add_theme_font_size_override("font_size", 19)
	vbox.add_child(name_label)
	var tag := Label.new()
	tag.text = "NEW %s" % Items.kind_word(kind) if level == 1 \
		else "LEVEL UP: %d of %d" % [level, Items.max_level(kind, id)]
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 12)
	tag.add_theme_color_override("font_color", Color("fff4b0") if level > 1 else Color(1, 1, 1, 0.55))
	vbox.add_child(tag)
	var description := Label.new()
	description.text = Items.text(kind, id, level)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(TILE_SIZE.x - 24, 0)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 14)
	vbox.add_child(description)
	var use := Label.new()
	use.text = Items.use_text(kind, id, level)
	use.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	use.custom_minimum_size = Vector2(TILE_SIZE.x - 24, 0)
	use.modulate = Color(1, 1, 1, 0.65)
	use.add_theme_font_size_override("font_size", 12)
	vbox.add_child(use)

	var button := Button.new()
	button.name = "Take"
	button.text = "Take"
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
	button.pressed.connect(take.bind(id))
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
