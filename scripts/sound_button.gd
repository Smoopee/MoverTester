class_name SoundButton
extends Button
## The speaker button after the trinkets, top right. It opens a panel with the music and sound volumes
## and a switch that mutes everything, which M also toggles. Settings are kept by Sfx.

const ICON := Color("f4ecd8")
const MUTED := Color("e07a5f")

var _panel := PopupPanel.new()
var _mute := CheckBox.new()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(40, 40)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = "Music and sound volume. M mutes everything."
	pressed.connect(_open)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_add_slider(box, "Music", Sfx.MUSIC_BUS, Sfx.music_volume)
	_add_slider(box, "Sound", Sfx.SFX_BUS, Sfx.sfx_volume)
	_mute.text = "Mute all (M)"
	_mute.focus_mode = Control.FOCUS_NONE
	_mute.button_pressed = Sfx.muted
	_mute.toggled.connect(_set_muted)
	box.add_child(_mute)
	_panel.add_child(box)
	add_child(_panel)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_M:
		_mute.button_pressed = not Sfx.muted


func _set_muted(on: bool) -> void:
	Sfx.set_muted(on)
	queue_redraw()


func _add_slider(box: VBoxContainer, title: String, bus: String, volume: float) -> void:
	var label := Label.new()
	label.text = title
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = volume
	slider.custom_minimum_size = Vector2(200, 24)
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(func(value: float) -> void: Sfx.set_volume(bus, value))
	if bus == Sfx.SFX_BUS:
		# A sample of the new level.
		slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play(Sfx.Sound.CRUMB))
	box.add_child(slider)


## Opens the panel under the button, its right edge lined up with the button's.
func _open() -> void:
	var scale := get_global_transform_with_canvas().get_scale()
	var at := get_screen_position() + Vector2(size.x * scale.x, size.y * scale.y + 6)
	_panel.reset_size()
	_panel.popup(Rect2i(Vector2i(at) - Vector2i(_panel.size.x, 0), Vector2i.ZERO))


## A speaker, with sound waves coming out of it, or a cross when muted.
func _draw() -> void:
	var center := size / 2
	var body := PackedVector2Array([
		center + Vector2(-11, -4), center + Vector2(-6, -4), center + Vector2(0, -10),
		center + Vector2(0, 10), center + Vector2(-6, 4), center + Vector2(-11, 4)])
	var color := MUTED if Sfx.muted else ICON
	draw_colored_polygon(body, color)
	if Sfx.muted:
		draw_line(center + Vector2(4, -5), center + Vector2(12, 5), color, 2.5, true)
		draw_line(center + Vector2(4, 5), center + Vector2(12, -5), color, 2.5, true)
		return
	for radius: float in [6.0, 11.0]:
		draw_arc(center + Vector2(-1, 0), radius, -PI / 4, PI / 4, 12, color, 2.0, true)
