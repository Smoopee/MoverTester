class_name ItemIcon
extends Texture2D
## A small symbol for a trinket, consumable or card stamp, drawn in code in the item's color. It's a
## texture, so it goes wherever one does: Button.icon, TextureRect.

enum Kind { TRINKET, CONSUMABLE, STAMP }

const SIZE := 18
## The symbols are drawn in a box this wide, centred on the origin, then scaled to fit.
const BOX := 24.0
const ELLIPSE_POINTS := 20

var kind: Kind
## Items.Trinket, Items.Consumable or CardSlot.Effect, depending on kind.
var id: int
var color: Color
## Width and height in pixels.
var size := SIZE

# Where the current draw goes. Set by _paint, used by the shape helpers.
var _item: RID
var _center: Vector2
var _scale: float
var _modulate: Color


static func trinket(trinket_id: Items.Trinket, px := SIZE) -> ItemIcon:
	return _make(Kind.TRINKET, trinket_id, Items.TRINKET_COLOR, px)


static func consumable(consumable_id: Items.Consumable, px := SIZE) -> ItemIcon:
	return _make(Kind.CONSUMABLE, consumable_id, Items.CONSUMABLE_COLOR, px)


static func stamp(effect: CardSlot.Effect, px := SIZE) -> ItemIcon:
	return _make(Kind.STAMP, effect, CardSlot.INFO[effect][2], px)


static func _make(icon_kind: Kind, icon_id: int, icon_color: Color, px: int) -> ItemIcon:
	var icon := ItemIcon.new()
	icon.kind = icon_kind
	icon.id = icon_id
	icon.color = icon_color
	icon.size = px
	return icon


func _get_width() -> int:
	return size


func _get_height() -> int:
	return size


func _has_alpha() -> bool:
	return true


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, _transpose: bool) -> void:
	_paint(to_canvas_item, Rect2(pos, get_size()), modulate)


func _draw_rect(to_canvas_item: RID, rect: Rect2, _tile: bool, modulate: Color, _transpose: bool) -> void:
	_paint(to_canvas_item, rect, modulate)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, _src_rect: Rect2, modulate: Color, _transpose: bool,
		_clip_uv: bool) -> void:
	_paint(to_canvas_item, rect, modulate)


func _paint(to_canvas_item: RID, rect: Rect2, modulate: Color) -> void:
	_item = to_canvas_item
	_center = rect.get_center()
	_scale = minf(rect.size.x, rect.size.y) / BOX
	_modulate = modulate
	var dark := color.darkened(0.6)
	match kind:
		Kind.TRINKET:
			_draw_trinket(id, dark)
		Kind.CONSUMABLE:
			_draw_consumable(id, dark)
		Kind.STAMP:
			_draw_stamp(dark)


func _draw_trinket(trinket_id: int, dark: Color) -> void:
	match trinket_id:
		Items.Trinket.SPARE_PAWS:
			# A paw print.
			_ellipse(Vector2(0, 4), Vector2(5.5, 4.5), 0.0, color)
			for toe: Vector2 in [Vector2(-6.5, -2), Vector2(-2.4, -6.5), Vector2(2.4, -6.5), Vector2(6.5, -2)]:
				_circle(toe, 2.5, color)
		Items.Trinket.LUCKY_TAIL:
			# A four-leaf clover.
			_line([Vector2(0, 0), Vector2(1.5, 5), Vector2(4, 10)], 1.8, color)
			# Each leaf is a heart: two lobes and a point at the middle.
			var mid := Vector2(0, -2)
			for i in 4:
				var d := Vector2.from_angle(PI / 4 + i * PI / 2)
				var n := d.orthogonal()
				_circle(mid + d * 5.4 + n * 1.9, 2.3, color)
				_circle(mid + d * 5.4 - n * 1.9, 2.3, color)
				_polygon([mid + d * 0.6, mid + d * 5.6 + n * 4.1, mid + d * 5.6 - n * 4.1], color)
		Items.Trinket.THICK_FUR:
			# A shield with a tuft of fur across it.
			_polygon([Vector2(-8, -8), Vector2(0, -10.5), Vector2(8, -8), Vector2(8, -1), Vector2(5, 5),
					Vector2(0, 10), Vector2(-5, 5), Vector2(-8, -1)], color)
			_line([Vector2(-5, 0), Vector2(-2.5, -3.5), Vector2(0, 0), Vector2(2.5, -3.5), Vector2(5, 0)], 1.6, dark)
		Items.Trinket.CRUMB_MAGNET:
			# A horseshoe magnet with light tips and a crumb between them.
			var points: Array[Vector2] = [Vector2(-6, -7)]
			for i in 13:
				points.append(Vector2(0, 1) + Vector2.from_angle(PI - i * PI / 12) * 6)
			points.append(Vector2(6, -7))
			_line(points, 4.2, color)
			var tip := color.lightened(0.7)
			_rect(Rect2(-8.1, -10.5, 4.2, 3.5), tip)
			_rect(Rect2(3.9, -10.5, 4.2, 3.5), tip)
			_circle(Vector2(0, -5), 1.6, color)
		Items.Trinket.PIGGY_BANK:
			# A pig facing right, with a coin slot on its back.
			_rect(Rect2(-5.5, 4, 2.5, 5), color)
			_rect(Rect2(2.5, 4, 2.5, 5), color)
			_ellipse(Vector2(-0.5, 1), Vector2(8, 6), 0.0, color)
			_polygon([Vector2(2.5, -3.5), Vector2(4.5, -8.5), Vector2(6.5, -3)], color)
			_ellipse(Vector2(8, 1.5), Vector2(2.4, 3), 0.0, color.lightened(0.3))
			_circle(Vector2(7.4, 0.5), 0.7, dark)
			_circle(Vector2(8.6, 2.5), 0.7, dark)
			_circle(Vector2(4.5, -1), 1.1, dark)
			_line([Vector2(-4.5, -3), Vector2(-0.5, -3)], 1.6, dark)
			_line([Vector2(-8.5, 0), Vector2(-10.5, -1.5), Vector2(-10, -3.5), Vector2(-8.5, -3)], 1.3, color)
		Items.Trinket.BOUNTIFUL_HARVEST:
			# An ear of wheat.
			_line([Vector2(0, 10.5), Vector2(0, -5)], 1.6, color)
			for i in 3:
				var y := -5.0 + i * 4.6
				_ellipse(Vector2(-3, y), Vector2(1.6, 3), -0.6, color)
				_ellipse(Vector2(3, y), Vector2(1.6, 3), 0.6, color)
			_ellipse(Vector2(0, -8.5), Vector2(1.6, 3), 0.0, color)


func _draw_consumable(consumable_id: int, dark: Color) -> void:
	match consumable_id:
		Items.Consumable.FRESH_BREEZE:
			# Gusts of wind, curling at the ends.
			_line([Vector2(-10, -4), Vector2(4, -4)] + _arc(Vector2(4, -7), 3, PI / 2, -PI, 8), 1.8, color)
			_line([Vector2(-10, 1), Vector2(9, 1)], 1.8, color)
			_line([Vector2(-10, 6), Vector2(2, 6)] + _arc(Vector2(2, 8.25), 2.25, -PI / 2, PI, 8), 1.8, color)
		Items.Consumable.CALM:
			# A crescent moon and a star.
			var points := _arc(Vector2.ZERO, 8.5, deg_to_rad(10), deg_to_rad(280), 20)
			var tip_a := points[-1]
			var tip_b := points[0]
			for i in range(1, 12):
				var t := i / 12.0
				var bend := Vector2(-1.5, 0.5)
				points.append(tip_a.lerp(bend, t).lerp(bend.lerp(tip_b, t), t))
			_polygon(points, color)
			_star(Vector2(6.5, -6.5), 2.6, color)
		Items.Consumable.NEW_PAWS:
			# Two arrows going round: swap the hand.
			for start: float in [deg_to_rad(20), deg_to_rad(200)]:
				var end := start + deg_to_rad(130)
				_line(_arc(Vector2.ZERO, 7, start, end, 10), 2.2, color)
				var p := Vector2.from_angle(end) * 7
				var t := Vector2.from_angle(end + PI / 2)
				var n := Vector2.from_angle(end)
				_polygon([p + t * 3.5, p - t * 0.5 + n * 3.2, p - t * 0.5 - n * 3.2], color)
		Items.Consumable.CHEESE_BAIT:
			# A wedge of cheese.
			_polygon([Vector2(-10, 6), Vector2(10, 6), Vector2(10, -7)], color)
			_circle(Vector2(5.5, 1.5), 2, dark)
			_circle(Vector2(8, -3), 1.2, dark)
			_circle(Vector2(1, 4), 1.1, dark)
		Items.Consumable.SQUEEZE:
			# An arrow straight through a brick wall.
			var wall := Color(color, 0.45)
			_rect(Rect2(-3, -10, 6, 20), wall)
			for y: float in [-5.0, 0.0, 5.0]:
				_line([Vector2(-3, y), Vector2(3, y)], 1, dark)
			_line([Vector2(-10, 0), Vector2(5, 0)], 2.6, color)
			_polygon([Vector2(10.5, 0), Vector2(4.5, -5), Vector2(4.5, 5)], color)


## A rubber stamp, for card stamps.
func _draw_stamp(dark: Color) -> void:
	_circle(Vector2(0, -6.5), 3.4, color)
	_rect(Rect2(-1.6, -4, 3.2, 4.5), color)
	_rect(Rect2(-8, 0, 16, 4.5), color)
	_rect(Rect2(-8, 3, 16, 1.5), dark)
	_line([Vector2(-9.5, 8), Vector2(9.5, 8)], 1.6, color)


## Points along a circle from angle `from` to angle `to`.
func _arc(c: Vector2, r: float, from: float, to: float, steps: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in steps + 1:
		points.append(c + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * r)
	return points


# Shape helpers. They take points in the BOX and map them onto the rect being drawn.

func _to_px(p: Vector2) -> Vector2:
	return _center + p * _scale


func _circle(c: Vector2, r: float, col: Color) -> void:
	RenderingServer.canvas_item_add_circle(_item, _to_px(c), r * _scale, col * _modulate, true)


func _rect(rect: Rect2, col: Color) -> void:
	RenderingServer.canvas_item_add_rect(_item, Rect2(_to_px(rect.position), rect.size * _scale), col * _modulate)


func _polygon(points: Array, col: Color) -> void:
	var px := PackedVector2Array()
	for p: Vector2 in points:
		px.append(_to_px(p))
	RenderingServer.canvas_item_add_polygon(_item, px, PackedColorArray([col * _modulate]))


func _line(points: Array, width: float, col: Color) -> void:
	var px := PackedVector2Array()
	for p: Vector2 in points:
		px.append(_to_px(p))
	RenderingServer.canvas_item_add_polyline(_item, px, PackedColorArray([col * _modulate]), width * _scale, true)


## An ellipse with radii r, turned by angle.
func _ellipse(c: Vector2, r: Vector2, angle: float, col: Color) -> void:
	var points: Array[Vector2] = []
	for i in ELLIPSE_POINTS:
		var a := TAU * i / ELLIPSE_POINTS
		points.append(c + (Vector2(cos(a), sin(a)) * r).rotated(angle))
	_polygon(points, col)


## A five-pointed star of outer radius r.
func _star(c: Vector2, r: float, col: Color) -> void:
	var points: Array[Vector2] = []
	for i in 10:
		points.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * (r if i % 2 == 0 else r * 0.45))
	_polygon(points, col)
