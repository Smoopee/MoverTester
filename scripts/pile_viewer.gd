class_name PileViewer
extends Control
## Overlay that lists the cards in a pile. Cards are shown sorted by direction and stamp, so viewing the
## draw pile doesn't reveal what's coming next. Closes on Close, Esc, or a click outside the panel.

const COLUMNS := 6
const MAX_GRID_HEIGHT := 360.0

var _title := Label.new()
var _summary := Label.new()
var _empty := Label.new()
var _scroll := ScrollContainer.new()
var _grid := GridContainer.new()
var _close_button := Button.new()


func _ready() -> void:
	# Offsets too: this node is already in the tree, so anchors alone would keep its zero size.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Lets clicks around the panel reach the dim behind it.
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.17, 0.15)
	style.border_color = Color(0.96, 0.77, 0.26)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	box.add_child(vbox)

	_title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_title)

	_summary.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_summary)

	_empty.text = "(empty)"
	_empty.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_empty)

	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_grid)
	vbox.add_child(_scroll)

	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(120, 40)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(hide)
	vbox.add_child(_close_button)


## Shows the cards under the given title.
func show_pile(title: String, cards: Array[CardData]) -> void:
	var sorted := CardData.sorted(cards)
	_title.text = "%s (%d)" % [title, sorted.size()]

	var counts := PackedStringArray()
	for dir in Card.Dir.values():
		counts.append("%s %d" % [Card.NAMES[dir], sorted.filter(func(c: CardData) -> bool:
			return c.dir == dir).size()])
	_summary.text = "   ".join(counts)

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for data in sorted:
		var card := Card.new()
		card.data = data
		card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(card)

	_empty.visible = sorted.is_empty()
	_scroll.visible = not sorted.is_empty()
	var rows := ceili(sorted.size() / float(COLUMNS))
	var grid_height := rows * Card.CARD_SIZE.y + maxi(rows - 1, 0) * 8
	# Room for the vertical scroll bar when the pile is too tall to fit.
	var bar_width := 16.0 if grid_height > MAX_GRID_HEIGHT else 0.0
	_scroll.custom_minimum_size = Vector2(
		COLUMNS * Card.CARD_SIZE.x + (COLUMNS - 1) * 8 + bar_width, minf(grid_height, MAX_GRID_HEIGHT))
	show()
	# Takes keyboard focus from Lock In, so Space/Enter can't play a turn under the overlay.
	_close_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func _on_dim_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		hide()
