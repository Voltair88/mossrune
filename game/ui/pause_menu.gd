class_name PauseMenu
extends CanvasLayer
## Pause (Escape, P or Start) stops the game at any time, the level-up screen
## included. Resume, or turn screenshake and hit flashes off. Escape, the
## gamepad's back button or pause again closes it.

const LAYER := 20
const GAP := 4

var _resume: Button
var _shake: Button
var _flashes: Button
var _return_focus: Control
var _shake_on: bool = true
var _flashes_on: bool = true


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root := CenterContainer.new()
	root.theme = UiStyle.make_theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", GAP)
	panel.add_child(column)
	UiStyle.label("PAUSED", column)
	_resume = _button(column, close)
	_resume.text = "RESUME"
	_shake = _button(column, _toggle_shake)
	_flashes = _button(column, _toggle_flashes)


func _unhandled_input(event: InputEvent) -> void:
	if not visible and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		open()
	elif visible and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	_shake_on = GameSettings.shake
	_flashes_on = GameSettings.flashes
	_show_settings()
	visible = true
	_resume.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false
	if is_instance_valid(_return_focus) and _return_focus.is_visible_in_tree():
		_return_focus.grab_focus()


func _toggle_shake() -> void:
	_shake_on = not _shake_on
	_changed()


func _toggle_flashes() -> void:
	_flashes_on = not _flashes_on
	_changed()


func _changed() -> void:
	_show_settings()
	Events.settings_changed.emit(_shake_on, _flashes_on)


func _show_settings() -> void:
	_shake.text = "SCREENSHAKE: " + ("ON" if _shake_on else "OFF")
	_flashes.text = "FLASHES: " + ("ON" if _flashes_on else "OFF")


func _button(parent: Node, on_press: Callable) -> Button:
	var b := Button.new()
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b
