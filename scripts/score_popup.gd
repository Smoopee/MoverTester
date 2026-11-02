class_name ScorePopup
extends Control
## A score number that pops up and floats away, drawn over everything: the points or mult a move makes,
## on the board cell that made them, or the score a turn banks, over the board. Its intensity (0 to 1)
## says how big the score is: a higher one pops bigger and hotter in color, tilts, shakes, throws
## sparks and a ring, and stays longer. Main makes them through spawn().

## Font size at intensity 0 and 1, for a move's points and for a turn's banked score.
const SMALL_SIZES := Vector2(15, 30)
const BIG_SIZES := Vector2(30, 78)
## How far it floats up, and how long it lasts, at intensity 0 and 1.
const RISE := Vector2(26, 70)
const LIFE := Vector2(0.75, 1.7)
## Colors the number heats through as intensity rises. Mult is MULT_COLOR whatever the intensity.
const HEAT: Array[Color] = [Color("8fd3ff"), Color("ffffff"), Color("ffd23f"), Color("ff8a2f"), Color("ff3d6e")]
const MULT_COLOR := Color("ff5a4f")
const OUTLINE := Color("1b1612")
## Points a move needs for a popup at intensity 1 (popups grow with the log of the points).
const MAX_POINTS := 20
## A turn's popup is at intensity 1 when it banks this share of the round's score target.
const MAX_TARGET_SHARE := 1.0
## Above these intensities it shakes, throws sparks, and rings.
const SHAKE_FROM := 0.35
const SPARKS_FROM := 0.3
const RING_FROM := 0.6
const MAX_SPARKS := 22
const MAX_SHAKE := 7.0
const MAX_TILT := 0.22
const SPARK_TIME := 0.55
const POP_TIME := 0.16
const SETTLE_TIME := 0.35

var text := ""
## A smaller line under the number (a turn's points × mult), or empty.
var detail := ""
var intensity := 0.0
## A turn's banked score rather than a move's points.
var big := false
## Drawn in MULT_COLOR instead of heating up with intensity.
var mult := false

var _age := 0.0
var _life := 1.0
var _tilt := 0.0
var _shake := Vector2.ZERO
## Each spark's direction times its speed (pixels a second).
var _sparks: Array[Vector2] = []


## Adds a popup to parent, centered on at (a global position).
static func spawn(parent: Node, at: Vector2, label: String, strength: float, is_big := false,
		is_mult := false, sub := "") -> ScorePopup:
	var popup := ScorePopup.new()
	popup.text = label
	popup.detail = sub
	popup.intensity = clampf(strength, 0.0, 1.0)
	popup.big = is_big
	popup.mult = is_mult
	parent.add_child(popup)
	popup.global_position = at
	return popup


## Intensity for points a move made.
static func points_intensity(points: int) -> float:
	return clampf(log(1.0 + points) / log(1.0 + MAX_POINTS), 0.0, 1.0)


## Intensity for the score a turn banked, against the round's target.
static func turn_intensity(gained: int, target: int) -> float:
	return clampf(pow(float(gained) / maxi(target, 1) / MAX_TARGET_SHARE, 0.7), 0.0, 1.0)


func _ready() -> void:
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	_life = lerpf(LIFE.x, LIFE.y, intensity)
	_tilt = randf_range(-1.0, 1.0) * MAX_TILT * intensity
	if intensity >= SPARKS_FROM:
		var count := roundi(MAX_SPARKS * pow(intensity, 1.5) * (1.0 if big else 0.5))
		var reach := (BIG_SIZES if big else SMALL_SIZES).y * lerpf(1.5, 3.5, intensity)
		for i in count:
			var angle := TAU * (i + randf() * 0.6) / count
			_sparks.append(Vector2.from_angle(angle) * reach * randf_range(0.6, 1.0) / SPARK_TIME)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	var shake_for := _life * 0.45
	if intensity > SHAKE_FROM and _age < shake_for:
		var amount := MAX_SHAKE * (intensity - SHAKE_FROM) / (1.0 - SHAKE_FROM) * (1.0 - _age / shake_for)
		_shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * (1.6 if big else 1.0)
	else:
		_shake = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	var t := _age / _life
	var alpha := 1.0 if t < 0.6 else 1.0 - (t - 0.6) / 0.4
	var color := _color()
	var rise := -lerpf(RISE.x, RISE.y, intensity) * (1.0 - pow(1.0 - t, 2.0)) * (1.6 if big else 1.0)

	# Sparks fly out from where it popped, behind the number.
	if _age < SPARK_TIME:
		var s := _age / SPARK_TIME
		var out := 1.0 - pow(1.0 - s, 3.0)
		for velocity in _sparks:
			var head := velocity * SPARK_TIME * out
			var tail := head - velocity * 0.05 * (1.0 - s)
			var spark := color.lerp(Color.WHITE, 0.4)
			spark.a = 1.0 - s
			draw_line(tail, head, spark, lerpf(2.0, 4.0, intensity) * (1.0 - s * 0.5), true)

	# A ring rings out.
	if intensity >= RING_FROM and _age < SETTLE_TIME * 1.5:
		var r := _age / (SETTLE_TIME * 1.5)
		var ring := color
		ring.a = (1.0 - r) * 0.8
		var font_top := (BIG_SIZES if big else SMALL_SIZES).y
		draw_arc(Vector2.ZERO, font_top * (0.4 + r * 1.6 * intensity), 0, TAU, 48, ring, 3.0 * (1.0 - r) + 1.0, true)

	draw_set_transform(Vector2(0, rise) + _shake, _tilt * _wobble(), Vector2.ONE * _pop())
	var font := get_theme_default_font()
	var sizes := BIG_SIZES if big else SMALL_SIZES
	var font_size := roundi(lerpf(sizes.x, sizes.y, intensity))
	color.a = alpha
	var outline := OUTLINE
	outline.a = alpha
	_draw_centered(font, text, Vector2.ZERO, font_size, color, outline)
	if detail:
		var sub_size := maxi(roundi(font_size * 0.4), 13)
		var under := Vector2(0, font_size * 0.55 + sub_size * 0.5)
		_draw_centered(font, detail, under, sub_size, Color(1, 1, 1, alpha), outline)
	draw_set_transform(Vector2.ZERO)


## Draws text with an outline, centered on at.
func _draw_centered(font: Font, line: String, at: Vector2, font_size: int, color: Color, outline: Color) -> void:
	var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var base := at + Vector2(-width / 2.0, (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0)
	draw_string_outline(font, base, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		roundi(lerpf(4.0, 9.0, intensity) * (1.3 if big else 1.0)), outline)
	draw_string(font, base, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Scale: pops past full size, more the higher the intensity, then settles.
func _pop() -> float:
	var peak := 1.0 + 0.7 * intensity
	if _age < POP_TIME:
		return lerpf(0.3, peak, 1.0 - pow(1.0 - _age / POP_TIME, 3.0))
	if _age < SETTLE_TIME:
		return lerpf(peak, 1.0, (_age - POP_TIME) / (SETTLE_TIME - POP_TIME))
	return 1.0


## The tilt swings back and forth and dies down.
func _wobble() -> float:
	return cos(_age * 16.0) * exp(-_age * 3.0)


## The number's color: heats up with intensity, and flickers hot at the top.
func _color() -> Color:
	if mult:
		return MULT_COLOR
	var at := intensity * (HEAT.size() - 1)
	var i := mini(floori(at), HEAT.size() - 2)
	var color := HEAT[i].lerp(HEAT[i + 1], at - i)
	if intensity > 0.85:
		color = color.lerp(HEAT[2], (sin(_age * 30.0) * 0.5 + 0.5) * 0.6)
	return color
