class_name TouchTips
extends CanvasLayer
## Tooltips for a touchscreen, which has no hover: rest a finger on anything with a tooltip and the tip
## shows above it until the finger lifts. A hold that showed a tip doesn't also press the button under
## it. Main adds this only on a touchscreen. It hides Godot's own tooltips there, which pop up under the
## finger after a tap and stay until the next one.

## Seconds a finger has to rest on something before its tip shows. A card's shows sooner, as its
## hold-to-discard starts filling, since the hold discards it at Card.HOLD_TIME.
const DELAY := 0.3
## Pixels the finger can wander before the hold is a drag instead.
const SLOP := 12.0
## Gap between the tip and what it's about.
const GAP := 10.0
## Closest the tip comes to the screen's edges.
const MARGIN := 8.0
## Plain text tips wrap at this width.
const WRAP_WIDTH := 300.0

var _panel := PanelContainer.new()
## The control the finger rests on, once found, or null.
var _target: Control
var _from := Vector2.ZERO
## Seconds the finger has rested this press, or -1 when no hold is being timed.
var _held := -1.0


func _ready() -> void:
	layer = 110
	_panel.theme_type_variation = &"TooltipPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.hide()
	add_child(_panel)
	set_process(false)
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch and touch.index == 0:
		_hide()
		if touch.pressed:
			_from = touch.position
			_held = 0.0
			set_process(true)
	elif event is InputEventScreenDrag and event.index == 0 and _held >= 0 \
			and event.position.distance_to(_from) > SLOP:
		_hide()


func _process(delta: float) -> void:
	# The emulated mouse press that follows the touch has moved the hover by now.
	if _target == null:
		_target = _tip_owner(get_viewport().gui_get_hovered_control())
		if _target == null:
			_hide()
			return
	if not is_instance_valid(_target) or not _target.is_visible_in_tree():
		_hide()
		return
	if _panel.visible:
		_place()
		return
	_held += delta
	if _held >= (Card.HOLD_SHOW if _target is Card else DELAY):
		_show()


## The control whose tip shows for a finger on control: it or the first parent it passes the touch
## to that has a tooltip, as Godot's own tooltips pick.
func _tip_owner(control: Control) -> Control:
	while control:
		if control.get_tooltip(control.get_local_mouse_position()) != "":
			return control
		if control.mouse_filter != Control.MOUSE_FILTER_PASS or control.top_level:
			return null
		control = control.get_parent_control()
	return null


func _show() -> void:
	var text := _target.get_tooltip(_target.get_local_mouse_position())
	var content: Control
	if _target.has_method("_make_custom_tooltip"):
		content = _target.call("_make_custom_tooltip", text)
	if content == null:
		var label := Label.new()
		label.text = text
		label.theme_type_variation = &"TooltipLabel"
		content = label
	_panel.add_child(content)
	var label := content as Label
	if label and label.get_minimum_size().x > WRAP_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = WRAP_WIDTH
	_ignore_mouse(content)
	_panel.show()
	_place()
	var button := _target as BaseButton
	# A card's hold is its discard, which handles its own press.
	if button and not button is Card and not button.disabled:
		# Disabling the button cancels its press, so lifting the finger doesn't also click it.
		button.disabled = true
		button.disabled = false


## Puts the tip above the target, or beside it on the side with more room when there's no room above.
## Never below: the hand holding the finger is there.
func _place() -> void:
	_panel.reset_size()
	var tip := _panel.size
	var rect := _target.get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	var at := Vector2(rect.get_center().x - tip.x / 2, rect.position.y - GAP - tip.y)
	if at.y < MARGIN:
		at.y = rect.get_center().y - tip.y / 2
		at.x = rect.end.x + GAP if screen.x - rect.end.x > rect.position.x else rect.position.x - GAP - tip.x
	_panel.position = at.clamp(Vector2.ONE * MARGIN, (screen - tip - Vector2.ONE * MARGIN).max(Vector2.ONE * MARGIN))


func _hide() -> void:
	_held = -1.0
	_target = null
	set_process(false)
	_panel.hide()
	for child in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()


func _ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_ignore_mouse(child)


## Hides Godot's own tooltip popups as they show: this node shows the tips instead.
func _on_node_added(node: Node) -> void:
	var popup := node as PopupPanel
	if popup and popup.theme_type_variation == &"TooltipPanel":
		popup.visibility_changed.connect(func() -> void:
			if popup.visible:
				popup.hide.call_deferred())
