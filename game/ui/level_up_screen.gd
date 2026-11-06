class_name LevelUpScreen
extends CanvasLayer
## The level-up offer: up to three upgrades, picked with the keyboard, a gamepad
## or the mouse. Shown on level_up, hidden on upgrade_chosen. Presses are ignored
## for a moment after it opens, so a held attack doesn't pick by accident.
## The cards sit in a row.

const INPUT_DELAY_SEC := 0.4
const CARD_SIZE := Vector2(112, 100)
const ICON_BIG := Vector2(32, 32)
const GAP := 6
const LAYER := 10

var _buttons: Array[Button] = []
var _box: BoxContainer
var _title: Label
var _delay_left: float = 0.0


func _ready() -> void:
	layer = LAYER
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
	_title = UiStyle.label("", column)
	_box = HBoxContainer.new()
	_box.add_theme_constant_override(&"separation", GAP)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_box)
	Events.level_up.connect(_on_level_up)
	Events.upgrade_chosen.connect(_on_upgrade_chosen)


func _process(delta: float) -> void:
	if _delay_left <= 0.0:
		return
	_delay_left -= delta
	if _delay_left <= 0.0:
		for b in _buttons:
			b.disabled = false


func _on_level_up(level: int, offer: Array[UpgradeData]) -> void:
	_title.text = "LEVEL %d" % level
	for b in _buttons:
		_box.remove_child(b)
		b.queue_free()
	_buttons.clear()
	for u in offer:
		_add_button(u)
	_delay_left = INPUT_DELAY_SEC
	for b in _buttons:
		b.disabled = true
	visible = true
	_buttons[0].grab_focus()


func _on_upgrade_chosen(_u: UpgradeData) -> void:
	visible = false


func _add_button(u: UpgradeData) -> void:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.pressed.connect(_pick.bind(u))
	_box.add_child(b)
	_buttons.append(b)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(content)
	content.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE,
		UiStyle.PAD,
	)
	var icon := TextureRect.new()
	icon.texture = u.icon
	icon.custom_minimum_size = ICON_BIG
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(words)
	UiStyle.label(u.title, words)
	var text := UiStyle.label(u.text, words)
	text.modulate = UiStyle.DIM
	text.autowrap_mode = TextServer.AUTOWRAP_WORD


func _pick(u: UpgradeData) -> void:
	if _delay_left > 0.0 or not visible:
		return
	Events.upgrade_chosen.emit(u)
