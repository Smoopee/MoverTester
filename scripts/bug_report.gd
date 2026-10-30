class_name BugReport
extends CanvasLayer
## F12 bug report panel. Pauses the game, takes a screenshot and a snapshot of the game state, and saves
## them with your description and the recent action log to bug_reports/ (user://bug_reports when exported).

const KEY := KEY_F12
const LOG_SIZE := 50
const FOLDER := "res://bug_reports"
const EXPORTED_FOLDER := "user://bug_reports"
const TOAST_TIME := 3.0

## Returns the game state as text for the report. Set by the scene that owns the panel.
var get_state := Callable()

static var _log: Array[String] = []

var _screenshot: Image
var _state := ""
var _actions: Array[String] = []
var _was_paused := false

var _panel := Control.new()
var _hint := Label.new()
var _description := TextEdit.new()
var _save_button := Button.new()
var _toast := Label.new()
var _toast_tween: Tween


## Adds a line to the action log that goes into each report. Only the last LOG_SIZE lines are kept.
static func note(text: String) -> void:
	var seconds := Time.get_ticks_msec() / 1000.0
	_log.append("[%02d:%04.1f] %s" % [int(seconds / 60), fmod(seconds, 60.0), text])
	if _log.size() > LOG_SIZE:
		_log.pop_front()


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.hide()
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

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

	var title := Label.new()
	title.text = "Report a bug"
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	_hint.modulate = Color(1, 1, 1, 0.7)
	vbox.add_child(_hint)

	_description.custom_minimum_size = Vector2(520, 160)
	_description.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_description.placeholder_text = "What happened, and what did you expect?"
	_description.text_changed.connect(_on_text_changed)
	vbox.add_child(_description)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(120, 40)
	cancel.pressed.connect(close)
	buttons.add_child(cancel)

	_save_button.text = "Save Report"
	_save_button.custom_minimum_size = Vector2(160, 40)
	_save_button.pressed.connect(save)
	buttons.add_child(_save_button)

	# Confirmation shown at the bottom of the screen after saving.
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -16
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.hide()
	add_child(_toast)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY and _panel.visible:
		close()
	elif key.keycode == KEY:
		open()
	elif _panel.visible and key.keycode == KEY_ESCAPE:
		close()
	elif _panel.visible and key.ctrl_pressed and key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		save()
	else:
		return
	get_viewport().set_input_as_handled()


## Captures the screen, game state and action log as they are now, then pauses and shows the panel.
func open() -> void:
	# The last rendered frame, from before the panel is shown.
	_screenshot = get_viewport().get_texture().get_image()
	_state = get_state.call() if get_state.is_valid() else ""
	_actions = _log.duplicate()
	_hint.text = "Game paused. Ctrl+Enter saves, Esc cancels."
	_description.text = ""
	_save_button.disabled = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_panel.show()
	_description.grab_focus()


func close() -> void:
	_panel.hide()
	get_tree().paused = _was_paused


## Writes the report (.md) and screenshot (.png), then closes the panel.
func save() -> void:
	if _save_button.disabled:
		return
	var folder := ProjectSettings.globalize_path(FOLDER if OS.has_feature("editor") else EXPORTED_FOLDER)
	DirAccess.make_dir_recursive_absolute(folder)
	# Keeps the editor from importing the screenshots.
	if not FileAccess.file_exists(folder.path_join(".gdignore")):
		FileAccess.open(folder.path_join(".gdignore"), FileAccess.WRITE)

	var time := Time.get_datetime_string_from_system(false, true)
	var file_name := "bug_" + time.replace(" ", "_").replace(":", "-")
	if _screenshot:
		_screenshot.save_png(folder.path_join(file_name + ".png"))

	var lines := PackedStringArray([
		"# Bug report: %s" % time,
		"",
		"%s · Godot %s · %s" % [
			ProjectSettings.get_setting("application/config/name"),
			Engine.get_version_info().string, OS.get_name()],
		"",
		"## Description",
		"",
		_description.text.strip_edges(),
		"",
		"## Game state",
		"",
		"```",
		_state,
		"```",
		"",
		"## Recent actions",
		"",
		"```",
		"\n".join(_actions) if not _actions.is_empty() else "(none)",
		"```",
		"",
		"## Screenshot",
		"",
		"![screenshot](%s.png)" % file_name,
		"",
	])
	var path := folder.path_join(file_name + ".md")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_hint.text = "Couldn't write %s: %s" % [path, error_string(FileAccess.get_open_error())]
		return
	file.store_string("\n".join(lines))
	file.close()
	print("Bug report saved to ", path)
	close()
	_show_toast("Bug report saved: %s.md" % file_name)


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(_toast.hide)


func _on_text_changed() -> void:
	_save_button.disabled = _description.text.strip_edges().is_empty()
