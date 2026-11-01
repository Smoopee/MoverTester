class_name CardSlot
extends PanelContainer
## One of the play slots. Holds at most one Card, and may have an effect that changes how it plays.

signal card_dropped(card: Card)

enum Effect {
	NONE,
	# Change the direction.
	REVERSED, ROTATE_CW, ROTATE_CCW, MIRROR, WILD, GAMBLE,
	# Change the distance.
	DOUBLE, LEAP, SLIDE, WRAP, DIAGONAL,
	# Change when or whether it plays.
	ECHO, LAST, BLOCKED, SNIFF,
	# Change the deck.
	RECYCLE, BURN, COPY,
}

const DIRECTION_COLOR := Color("6fb3ff")
const DISTANCE_COLOR := Color("ffb35c")
const ORDER_COLOR := Color("c792ff")
const DECK_COLOR := Color("7ed68a")
const BLOCKED_COLOR := Color("e06060")
## Name, description and color of each effect.
const INFO := {
	Effect.NONE: ["", "", Color(1, 1, 1, 0.35)],
	Effect.REVERSED: ["REVERSED", "Moves the opposite way.", DIRECTION_COLOR],
	Effect.ROTATE_CW: ["ROTATE CW", "Turns the arrow a quarter turn clockwise.", DIRECTION_COLOR],
	Effect.ROTATE_CCW: ["ROTATE CCW", "Turns the arrow a quarter turn counterclockwise.", DIRECTION_COLOR],
	Effect.MIRROR: ["MIRROR", "Swaps left and right. Up and down stay the same.", DIRECTION_COLOR],
	Effect.WILD: ["WILD", "Ignores the card's arrow. Click the label to pick the direction.", DIRECTION_COLOR],
	Effect.GAMBLE: ["GAMBLE", "Moves 3 cells in a random direction.", DIRECTION_COLOR],
	Effect.DOUBLE: ["DOUBLE", "Moves twice.", DISTANCE_COLOR],
	Effect.LEAP: ["LEAP", "Jumps 2 cells, passing over the cell in between. A wall stops it short.", DISTANCE_COLOR],
	Effect.SLIDE: ["SLIDE", "Keeps going until it hits a wall, a trap, a cat's path, glue or the cheese.", DISTANCE_COLOR],
	Effect.WRAP: ["WRAP", "Going off an edge brings the mouse in on the opposite side.", DISTANCE_COLOR],
	Effect.DIAGONAL: ["DIAGONAL", "Joins with the next card into one diagonal hop.", DISTANCE_COLOR],
	Effect.ECHO: ["ECHO", "Repeats the previous move, then plays this card.", ORDER_COLOR],
	Effect.LAST: ["LAST", "Plays after all the other slots.", ORDER_COLOR],
	Effect.BLOCKED: ["BLOCKED", "No card can go here this turn.", BLOCKED_COLOR],
	Effect.SNIFF: ["SNIFF", "Only moves if that takes the mouse closer to the cheese, going around walls.", ORDER_COLOR],
	Effect.RECYCLE: ["RECYCLE", "This card comes back to your hand next turn.", DECK_COLOR],
	Effect.BURN: ["BURN", "Moves 3 cells, then the card is gone for the rest of the round.", DECK_COLOR],
	Effect.COPY: ["COPY", "Adds a copy of this card to your deck.", DECK_COLOR],
}

var number := 1
## Size of the cards it holds. Set it before adding the node to the tree.
var card_size := Card.CARD_SIZE
var effect := Effect.NONE
## Direction a WILD slot plays in, whatever card is in it.
var wild_dir := Card.Dir.UP
## Effect name shown above the slot. For a WILD slot, clicking it picks the direction.
var header := Header.new()

var _style := StyleBoxFlat.new()
var _number_label := Label.new()


## The effect name above a slot. Hovering it shows the slot's tooltip.
class Header extends Button:
	var slot: CardSlot

	func _make_custom_tooltip(_for_text: String) -> Object:
		return slot._make_custom_tooltip(_for_text)


## A tooltip's content: title in color over a thin rule of the same color, then the body. The
## TooltipPanel style around it comes from Main's theme.
static func make_tooltip(title: String, color: Color, body: String, note := "") -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	box.add_child(top)
	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", color)
	top.add_child(title_label)
	if note != "":
		var note_label := Label.new()
		note_label.text = note
		note_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		note_label.add_theme_font_size_override("font_size", 12)
		note_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		top.add_child(note_label)
	var rule := ColorRect.new()
	rule.color = color
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)
	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size = Vector2(250, 0)
	body_label.add_theme_font_size_override("font_size", 14)
	body_label.add_theme_color_override("font_color", Color("f4ecd8"))
	box.add_child(body_label)
	return box


func _init() -> void:
	header.slot = self
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.clip_text = true
	header.pressed.connect(_on_header_pressed)


func _ready() -> void:
	custom_minimum_size = card_size + Vector2(12, 12)
	header.custom_minimum_size = Vector2(card_size.x + 12, 0)
	header.add_theme_font_size_override("font_size", maxi(roundi(13 * card_size.x / Card.CARD_SIZE.x), 10))
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(10)
	_style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", _style)

	# Slot number, hidden behind the card once one is placed.
	_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number_label.add_theme_font_size_override("font_size", roundi(32 * card_size.x / Card.CARD_SIZE.x))
	_number_label.modulate = Color(1, 1, 1, 0.3)
	add_child(_number_label)
	# An empty header is shorter, so hold every header at a named one's height to keep the slots in line.
	header.text = INFO[Effect.REVERSED][0]
	header.custom_minimum_size.y = header.get_combined_minimum_size().y
	_refresh()


func set_effect(value: Effect) -> void:
	effect = value
	wild_dir = Card.Dir.UP
	_refresh()


func get_card() -> Card:
	for child in get_children():
		if child is Card:
			return child
	return null


## The direction a card in this slot moves the mouse, after any direction-changing effect.
func play_dir(card_dir: Card.Dir) -> Card.Dir:
	var offset: Vector2i = Card.OFFSETS[card_dir]
	match effect:
		Effect.REVERSED:
			offset = -offset
		Effect.ROTATE_CW:
			offset = Vector2i(-offset.y, offset.x)
		Effect.ROTATE_CCW:
			offset = Vector2i(offset.y, -offset.x)
		Effect.MIRROR:
			offset.x = -offset.x
		Effect.WILD:
			return wild_dir
		Effect.GAMBLE:
			return Card.Dir.values().pick_random() as Card.Dir
	return Card.OFFSETS.find_key(offset) as Card.Dir


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and not data.disabled and effect != Effect.BLOCKED


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped.emit(data)


func _make_custom_tooltip(_for_text: String) -> Object:
	var info: Array = INFO[effect]
	return make_tooltip(info[0], info[2], info[1], "SLOT %d" % number)


func _on_header_pressed() -> void:
	var offset: Vector2i = Card.OFFSETS[wild_dir]
	wild_dir = Card.OFFSETS.find_key(Vector2i(-offset.y, offset.x)) as Card.Dir
	BugReport.note("Slot %d WILD -> %s" % [number, Card.NAMES[wild_dir]])
	_refresh()


func _refresh() -> void:
	var info: Array = INFO[effect]
	var color: Color = info[2]
	var wild := effect == Effect.WILD
	var blocked := effect == Effect.BLOCKED
	header.text = "WILD: %s" % Card.NAMES[wild_dir] if wild else info[0]
	header.tooltip_text = info[1]
	header.disabled = not wild
	header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if wild else Control.CURSOR_ARROW
	for state in ["font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		header.add_theme_color_override(state, color)
	tooltip_text = info[1]
	_style.bg_color = Color(0, 0, 0, 0.45) if blocked else Color(0, 0, 0, 0.2)
	_style.border_color = color
	_number_label.text = "X" if blocked else str(number)
