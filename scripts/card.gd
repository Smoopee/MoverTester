class_name Card
extends Button
## A movement card. Click it to move it between the hand and the slots, or drag it. Right-click it to
## discard it, or on a touchscreen hold it.

signal card_dropped_on(card: Card)
signal discard_requested
## The player set its STRIDE or SWIVEL stamp: a new distance or direction.
signal stamp_set

enum Dir { UP, DOWN, LEFT, RIGHT }

const OFFSETS := {
	Dir.UP: Vector2i(0, -1),
	Dir.DOWN: Vector2i(0, 1),
	Dir.LEFT: Vector2i(-1, 0),
	Dir.RIGHT: Vector2i(1, 0),
}
## Rotation that turns something pointing up into something pointing in this direction.
const ANGLES := {
	Dir.UP: 0.0,
	Dir.DOWN: PI,
	Dir.LEFT: -PI / 2,
	Dir.RIGHT: PI / 2,
}
const NAMES := {
	Dir.UP: "UP",
	Dir.DOWN: "DOWN",
	Dir.LEFT: "LEFT",
	Dir.RIGHT: "RIGHT",
}
const COLORS := {
	Dir.UP: Color("3b7dd8"),
	Dir.DOWN: Color("d8823b"),
	Dir.LEFT: Color("3ba55c"),
	Dir.RIGHT: Color("9b4fd1"),
}
const CARD_SIZE := Vector2(80, 110)
const ARROW_POINTS: Array[Vector2] = [
	Vector2(0, -24), Vector2(18, -4), Vector2(6, -4), Vector2(6, 20),
	Vector2(-6, 20), Vector2(-6, -4), Vector2(-18, -4),
]
## Seconds a finger has to rest on a card to discard it, on a touchscreen.
const HOLD_TIME := 0.5
## Seconds into a hold before the card starts filling up, so a quick tap doesn't flash.
const HOLD_SHOW := 0.15
## Pixels the finger can wander during a hold before it's a drag instead.
const HOLD_SLOP := 12.0
## Main's DISCARD_COLOR, see-through.
const HOLD_COLOR := Color(0.878, 0.478, 0.373, 0.5)
## Stamps set by clicking the stamp band on a card in play.
const SET_STAMPS: Array[CardSlot.Effect] = [CardSlot.Effect.STRIDE, CardSlot.Effect.SWIVEL]
## Stamps that don't play after the slot's effect, so their tooltips don't say they do.
const QUIET_STAMPS: Array[CardSlot.Effect] = [CardSlot.Effect.SWIVEL, CardSlot.Effect.STEADY]
## The card's face for each material (Items.CardMaterial), which _draw_material then patterns.
const FACES := {
	Items.CardMaterial.NONE: Color("f4ecd8"),
	Items.CardMaterial.WOOD: Color("e2bf8e"),
	Items.CardMaterial.SHINY: Color("e2f1fb"),
	Items.CardMaterial.GOLD: Color("f2d16a"),
	Items.CardMaterial.COPPER: Color("eba67a"),
	Items.CardMaterial.PAPER: Color("fcfcf7"),
	Items.CardMaterial.STONE: Color("cfccc4"),
}

## The deck card this node shows. Set it, or dir, before adding the node to the tree.
var data := CardData.new()
## Size of the card. Smaller cards draw everything scaled down. Set it before adding the node to the tree.
var card_size := CARD_SIZE
var dir: Dir:
	get:
		return data.dir
	set(value):
		data.dir = value
var stamp: CardSlot.Effect:
	get:
		return data.stamp
## True for cards in play, where clicking a STRIDE or SWIVEL stamp sets it (SET_STAMPS). Elsewhere
## (the shop's card picker, the pile viewer) a click on it is a click on the card.
var set_on_click := false

## Seconds the card has been held down this press on a touchscreen, or -1 when it isn't being held.
var _held := -1.0
var _hold_from := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = card_size
	focus_mode = Control.FOCUS_NONE
	set_process(false)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_restyle()
	var tips := PackedStringArray()
	if stamp != CardSlot.Effect.NONE:
		tips.append("%s stamp: %s" % [CardSlot.INFO[stamp][0], _stamp_text()])
	if data.material != Items.CardMaterial.NONE:
		tips.append("%s: %s" % [Items.MATERIALS[data.material][0], data.material_text()])
	tooltip_text = "\n".join(tips)


## Borders the card in its direction's color, on its material's face.
func _restyle() -> void:
	var color: Color = COLORS[dir]
	var face: Color = FACES[data.material]
	add_theme_stylebox_override("normal", _make_style(face, color))
	add_theme_stylebox_override("hover", _make_style(face.lerp(Color.WHITE, 0.5), color))
	add_theme_stylebox_override("pressed", _make_style(face.darkened(0.06), color))
	add_theme_stylebox_override("disabled", _make_style(face, color))


func _stamp_text() -> String:
	var text: String = CardSlot.INFO[stamp][1]
	return text if stamp in QUIET_STAMPS else text + " Plays after the slot's own effect."


## Resizes the card, as it moves between the hand and a slot, which hold different sizes of card.
func resize(value: Vector2) -> void:
	card_size = value
	custom_minimum_size = value
	queue_redraw()


## The stamp's tip over the material's, for whichever the card has.
func _make_custom_tooltip(_for_text: String) -> Object:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	if stamp != CardSlot.Effect.NONE:
		var info: Array = CardSlot.INFO[stamp]
		box.add_child(CardSlot.make_tooltip(info[0], info[2], _stamp_text(), "STAMP"))
	if data.material != Items.CardMaterial.NONE:
		var info: Array = Items.MATERIALS[data.material]
		box.add_child(CardSlot.make_tooltip(info[0], info[3], data.material_text(), "MATERIAL"))
	return box


func _draw() -> void:
	var color: Color = COLORS[dir]
	var zoom := size.x / CARD_SIZE.x
	_draw_material(zoom)
	draw_set_transform(Vector2(size.x / 2, size.y * 0.42), ANGLES[dir], Vector2.ONE * zoom)
	draw_colored_polygon(PackedVector2Array(ARROW_POINTS), color)
	draw_set_transform(Vector2.ZERO)
	draw_string(get_theme_default_font(), Vector2(0, size.y - 12 * zoom), NAMES[dir],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, maxi(roundi(14 * zoom), 10), color.darkened(0.25))
	if stamp != CardSlot.Effect.NONE:
		var info: Array = CardSlot.INFO[stamp]
		var font_size := _stamp_font_size()
		draw_rect(_stamp_rect(), info[2])
		draw_string(get_theme_default_font(), Vector2(0, font_size + 4), data.stamp_name(),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, Color("2a2420"))
	# A hold fills the card from the bottom up.
	if _held > HOLD_SHOW:
		var filled := size.y * (_held - HOLD_SHOW) / (HOLD_TIME - HOLD_SHOW)
		var fill := StyleBoxFlat.new()
		fill.bg_color = HOLD_COLOR
		fill.set_corner_radius_all(8)
		draw_style_box(fill, Rect2(0, size.y - filled, size.x, filled))


## Patterns the face for the card's material, under the arrow: grain for WOOD, a sheen for SHINY,
## sparkles for GOLD, rivets and a patina for COPPER, ruled lines for PAPER, speckles and a crack for STONE.
func _draw_material(zoom: float) -> void:
	var inner := Rect2(Vector2(6, 6), size - Vector2(12, 12))
	match data.material:
		Items.CardMaterial.WOOD:
			var grain := Color("9c6a38", 0.45)
			for i in 5:
				var y := size.y * (0.14 + 0.18 * i)
				var points := PackedVector2Array()
				for step in 9:
					var t := step / 8.0
					points.append(Vector2(lerpf(inner.position.x, inner.end.x, t), y + sin(t * TAU + i * 1.7) * 2 * zoom))
				draw_polyline(points, grain, 1.5 * zoom, true)
			draw_arc(Vector2(size.x * 0.74, size.y * 0.72), 4 * zoom, 0, TAU, 16, grain, 1.5 * zoom, true)
		Items.CardMaterial.SHINY:
			var sheen := Color(1, 1, 1, 0.7)
			for band: Array in [[0.55, 0.15, 0.13], [0.8, 0.4, 0.05]]:
				var top: float = size.x * band[0]
				var bottom: float = size.x * band[1]
				var width: float = size.x * band[2]
				draw_colored_polygon(PackedVector2Array([Vector2(top, inner.position.y),
						Vector2(top + width, inner.position.y), Vector2(bottom + width, inner.end.y),
						Vector2(bottom, inner.end.y)]), sheen)
		Items.CardMaterial.GOLD:
			draw_rect(inner, Color("b8862a", 0.6), false, 1.5 * zoom)
			for at: Vector2 in [Vector2(0.2, 0.27), Vector2(0.82, 0.24), Vector2(0.8, 0.66), Vector2(0.22, 0.7)]:
				var c := at * size
				var r := 4.5 * zoom
				var points := PackedVector2Array()
				for i in 8:
					points.append(c + Vector2.from_angle(i * PI / 4) * (r if i % 2 == 0 else r * 0.3))
				draw_colored_polygon(points, Color(1, 1, 0.92, 0.9))
		Items.CardMaterial.COPPER:
			draw_rect(inner, Color("9a4f22", 0.55), false, 1.5 * zoom)
			for at: Vector2 in [Vector2(0.16, 0.12), Vector2(0.84, 0.12), Vector2(0.16, 0.88), Vector2(0.84, 0.88)]:
				draw_circle(at * size, 2.2 * zoom, Color("9a4f22", 0.7))
			# Verdigris creeping in from a corner.
			for blot: Array in [[Vector2(0.24, 0.74), 5.0], [Vector2(0.34, 0.8), 3.5], [Vector2(0.2, 0.62), 2.5]]:
				draw_circle(blot[0] * size, blot[1] * zoom, Color("5fb59a", 0.45))
		Items.CardMaterial.PAPER:
			var rule := Color("8fb3e0", 0.6)
			for i in 6:
				var y := size.y * (0.18 + 0.13 * i)
				draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), rule, 1.0 * zoom)
			var margin := inner.position.x + size.x * 0.12
			draw_line(Vector2(margin, inner.position.y), Vector2(margin, inner.end.y), Color("e07a7a", 0.6), 1.0 * zoom)
		Items.CardMaterial.STONE:
			var fleck := Color("6f6b62", 0.5)
			for at: Vector2 in [Vector2(0.2, 0.2), Vector2(0.72, 0.16), Vector2(0.84, 0.5), Vector2(0.3, 0.62),
					Vector2(0.62, 0.78), Vector2(0.16, 0.84), Vector2(0.5, 0.12)]:
				draw_circle(at * size, 1.6 * zoom, fleck)
			draw_polyline(PackedVector2Array([Vector2(0.86, 0.3) * size, Vector2(0.74, 0.42) * size,
					Vector2(0.8, 0.54) * size, Vector2(0.68, 0.68) * size]), Color("5a564e", 0.55), 1.3 * zoom, true)


func _stamp_font_size() -> int:
	return maxi(roundi(12 * size.x / CARD_SIZE.x), 9)


## The band across the top of the card that shows its stamp.
func _stamp_rect() -> Rect2:
	return Rect2(3, 3, size.x - 6, _stamp_font_size() + 6)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_RIGHT and button.pressed and not disabled:
		accept_event()
		discard_requested.emit()
	elif button and button.button_index == MOUSE_BUTTON_LEFT and button.pressed and not disabled \
			and set_on_click and stamp in SET_STAMPS and _stamp_rect().has_point(button.position):
		# Taken before the button sees it, so setting the stamp doesn't also move the card.
		accept_event()
		var old := data.label()
		if stamp == CardSlot.Effect.STRIDE:
			data.next_stride()
		else:
			data.swivel()
			_restyle()
		BugReport.note("Set %s -> %s" % [old, data.label()])
		Sfx.play(Sfx.Sound.CLICK)
		queue_redraw()
		stamp_set.emit()
	elif button and button.button_index == MOUSE_BUTTON_LEFT and DisplayServer.is_touchscreen_available():
		_hold_from = button.position
		_set_held(0.0 if button.pressed and not disabled else -1.0)
	elif event is InputEventMouseMotion and _held >= 0 and event.position.distance_to(_hold_from) > HOLD_SLOP:
		_set_held(-1.0)


## Counts up a hold, and discards the card once it's held long enough.
func _process(delta: float) -> void:
	if disabled:
		_set_held(-1.0)
		return
	_held += delta
	queue_redraw()
	if _held < HOLD_TIME:
		return
	_set_held(-1.0)
	# Disabling the button cancels its press, so lifting the finger doesn't also click the card.
	disabled = true
	disabled = false
	discard_requested.emit()


func _set_held(value: float) -> void:
	_held = value
	set_process(value >= 0)
	queue_redraw()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled:
		return null
	_set_held(-1.0)
	Sfx.play(Sfx.Sound.CARD_PICK)
	var preview := Card.new()
	preview.data = data
	preview.card_size = card_size
	preview.position = -card_size / 2
	preview.modulate.a = 0.85
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	modulate.a = 0.4
	return self


func _can_drop_data(_at_position: Vector2, dropped: Variant) -> bool:
	return dropped is Card and dropped != self and not disabled


func _drop_data(_at_position: Vector2, dropped: Variant) -> void:
	card_dropped_on.emit(dropped)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate.a = 1.0


func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	return style
