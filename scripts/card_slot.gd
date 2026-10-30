class_name CardSlot
extends PanelContainer
## One of the play slots. Holds at most one Card.

signal card_dropped(card: Card)

var number := 1


func _ready() -> void:
	custom_minimum_size = Card.CARD_SIZE + Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.2)
	style.border_color = Color(1, 1, 1, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	add_theme_stylebox_override("panel", style)

	# Slot number, hidden behind the card once one is placed.
	var label := Label.new()
	label.text = str(number)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = Color(1, 1, 1, 0.3)
	add_child(label)


func get_card() -> Card:
	for child in get_children():
		if child is Card:
			return child
	return null


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Card and not data.disabled


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	card_dropped.emit(data)
