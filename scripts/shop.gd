class_name Shop
extends Control
## Overlay between rounds where crumbs buy trinkets, consumables and card stamps. Opens after each won
## round; Next Round closes it and starts the next one.

signal next_round_pressed

enum Kind { TRINKET, CONSUMABLE, STAMP }

const OFFERS_PER_ROW := 2
const OFFER_SIZE := Vector2(200, 112)
const SECTION_WIDTH := 150.0
const PICKER_COLUMNS := 6


## One thing for sale this visit.
class Offer:
	var kind: Kind
	## Items.Trinket, Items.Consumable or CardSlot.Effect, depending on kind.
	var id: int
	var price: int
	var sold := false
	var button: Button


var _run: Run
var _offers: Array[Offer] = []
## The stamp offer whose card is being picked, or null.
var _pending: Offer

var _title := Label.new()
var _crumbs_label := Label.new()
var _sections := VBoxContainer.new()
var _rows := {}
var _pouch_label := Label.new()
var _picker := VBoxContainer.new()
var _picker_title := Label.new()
var _picker_grid := GridContainer.new()
var _next_button := Button.new()


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
	vbox.add_theme_constant_override("separation", 14)
	box.add_child(vbox)

	var header := HBoxContainer.new()
	_title.text = "Shop"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override("font_size", 26)
	header.add_child(_title)
	_crumbs_label.add_theme_font_size_override("font_size", 20)
	_crumbs_label.add_theme_color_override("font_color", Items.TRINKET_COLOR)
	header.add_child(_crumbs_label)
	vbox.add_child(header)

	_sections.add_theme_constant_override("separation", 12)
	vbox.add_child(_sections)
	_add_section(Kind.TRINKET, "Trinkets", "Yours for the rest of the run.")
	_add_section(Kind.CONSUMABLE, "Consumables", "")
	_add_section(Kind.STAMP, "Card stamps", "Puts an effect on one card for good.")

	_picker.add_theme_constant_override("separation", 12)
	_picker_title.add_theme_font_size_override("font_size", 18)
	_picker.add_child(_picker_title)
	_picker_grid.columns = PICKER_COLUMNS
	_picker_grid.add_theme_constant_override("h_separation", 8)
	_picker_grid.add_theme_constant_override("v_separation", 8)
	_picker.add_child(_picker_grid)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(120, 40)
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_END
	cancel.pressed.connect(_close_picker)
	_picker.add_child(cancel)
	vbox.add_child(_picker)

	_next_button.text = "Next Round"
	_next_button.custom_minimum_size = Vector2(180, 44)
	_next_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next_button.add_theme_font_size_override("font_size", 20)
	_next_button.pressed.connect(_on_next_round)
	vbox.add_child(_next_button)


## Rolls this visit's offers and shows the shop.
func open(run: Run) -> void:
	_run = run
	_offers.clear()
	var trinkets: Array = Items.Trinket.values().filter(func(t: int) -> bool: return not run.has(t))
	_fill_row(Kind.TRINKET, trinkets)
	_fill_row(Kind.CONSUMABLE, Items.Consumable.values())
	_fill_row(Kind.STAMP, Items.STAMPS.duplicate())
	_close_picker()
	BugReport.note("Shop opened with %d crumbs" % run.crumbs)
	show()
	# Takes keyboard focus from Lock In, so Space/Enter can't play a turn under the overlay.
	_next_button.grab_focus()


func _add_section(kind: Kind, title: String, hint: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var labels := VBoxContainer.new()
	labels.custom_minimum_size = Vector2(SECTION_WIDTH, 0)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 18)
	labels.add_child(title_label)
	var hint_label := _pouch_label if kind == Kind.CONSUMABLE else Label.new()
	hint_label.text = hint
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(SECTION_WIDTH, 0)
	hint_label.modulate = Color(1, 1, 1, 0.6)
	hint_label.add_theme_font_size_override("font_size", 13)
	labels.add_child(hint_label)
	row.add_child(labels)
	var offers := HBoxContainer.new()
	offers.add_theme_constant_override("separation", 10)
	row.add_child(offers)
	_rows[kind] = offers
	_sections.add_child(row)


## Puts up to OFFERS_PER_ROW random picks from pool up for sale in the kind's row.
func _fill_row(kind: Kind, pool: Array) -> void:
	var row: HBoxContainer = _rows[kind]
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()
	pool.shuffle()
	for id: int in pool.slice(0, OFFERS_PER_ROW):
		var offer := Offer.new()
		offer.kind = kind
		offer.id = id
		offer.price = _info(offer)[2]
		_offers.append(offer)
		row.add_child(_make_tile(offer))
	if pool.is_empty():
		var none := Label.new()
		none.text = "Sold out."
		none.modulate = Color(1, 1, 1, 0.6)
		row.add_child(none)


func _make_tile(offer: Offer) -> Control:
	var info := _info(offer)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.25)
	style.border_color = info[3]
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = OFFER_SIZE
	tile.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	tile.add_child(vbox)
	var name_label := Label.new()
	name_label.text = info[0]
	name_label.add_theme_color_override("font_color", info[3])
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)
	var description := Label.new()
	description.text = info[1]
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(OFFER_SIZE.x - 20, 0)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 13)
	vbox.add_child(description)
	offer.button = Button.new()
	offer.button.focus_mode = Control.FOCUS_NONE
	offer.button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	offer.button.pressed.connect(_buy.bind(offer))
	vbox.add_child(offer.button)
	return tile


## Name, description, price and color of an offer.
func _info(offer: Offer) -> Array:
	match offer.kind:
		Kind.TRINKET:
			return Items.TRINKETS[offer.id] + [Items.TRINKET_COLOR]
		Kind.CONSUMABLE:
			return Items.CONSUMABLES[offer.id] + [Items.CONSUMABLE_COLOR]
	var effect: Array = CardSlot.INFO[offer.id]
	return ["%s STAMP" % effect[0], effect[1], Items.STAMP_PRICE, effect[2]]


func _buy(offer: Offer) -> void:
	if offer.sold or offer.price > _run.crumbs:
		return
	match offer.kind:
		Kind.TRINKET:
			_run.trinkets.append(offer.id)
		Kind.CONSUMABLE:
			if _run.pouch.size() >= Items.POUCH_SIZE:
				return
			_run.pouch.append(offer.id)
		Kind.STAMP:
			_open_picker(offer)
			return
	_sell(offer, "")


## Takes the crumbs for a bought offer and marks it sold.
func _sell(offer: Offer, detail: String) -> void:
	_run.crumbs -= offer.price
	offer.sold = true
	BugReport.note("Bought %s for %d%s (%d crumbs left)" % [_info(offer)[0], offer.price, detail, _run.crumbs])
	_refresh()


## Swaps the offers for a grid of the deck's cards to put the stamp on. Nothing is paid until one is
## picked.
func _open_picker(offer: Offer) -> void:
	_pending = offer
	_picker_title.text = "Pick a card for the %s stamp. A card that already has one gets the new one." % \
			CardSlot.INFO[offer.id][0]
	for child in _picker_grid.get_children():
		_picker_grid.remove_child(child)
		child.queue_free()
	for data in CardData.sorted(_run.deck.cards):
		var card := Card.new()
		card.data = data
		# Already has this stamp: buying it again would change nothing.
		card.disabled = data.stamp == offer.id
		card.pressed.connect(_apply_stamp.bind(data))
		_picker_grid.add_child(card)
	_sections.hide()
	_next_button.hide()
	_picker.show()


func _apply_stamp(data: CardData) -> void:
	var offer := _pending
	var old := data.label()
	data.stamp = offer.id as CardSlot.Effect
	_close_picker()
	_sell(offer, " on %s" % old)


func _close_picker() -> void:
	_pending = null
	_picker.hide()
	_sections.show()
	_next_button.show()
	_refresh()


func _refresh() -> void:
	if _run == null:
		return
	_crumbs_label.text = "%d crumbs" % _run.crumbs
	var pouch_full := _run.pouch.size() >= Items.POUCH_SIZE
	_pouch_label.text = "Used once, then gone. Pouch %d/%d." % [_run.pouch.size(), Items.POUCH_SIZE]
	for offer in _offers:
		var blocked := offer.kind == Kind.CONSUMABLE and pouch_full
		offer.button.text = "Sold" if offer.sold else ("Pouch full" if blocked else "Buy (%d)" % offer.price)
		offer.button.disabled = offer.sold or blocked or offer.price > _run.crumbs


func _on_next_round() -> void:
	hide()
	next_round_pressed.emit()
