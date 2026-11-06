class_name Hud
extends CanvasLayer
## HP, clock and level in the pixel font, plus the end-of-run panel.
## Read-only: everything it shows arrives through Events.

const FONT := preload("res://assets/fonts/pixel.png")
const FONT_SIZE := 8
const MARGIN := 8
const BAR_BACK := Color("333c57")
const BAR_FILL := Color("ffcd75")
const INK := Color("f4f4f4")
const PANEL := Color(Color("1a1c2c"), 0.85)
const PANEL_SIZE := Vector2(200, 72)
const STRIP_HEIGHT := 14.0
const BAR_SIZE := Vector2(200, 6)
const SECONDS_PER_MINUTE := 60
## The bar blinks below this share of HP (low HP shows by shape and motion too).
const LOW_HP_SHARE := 0.25
const LOW_BLINK_HZ := 2.0
const BLINK_DUTY := 0.5

var _bar_fill: ColorRect
var _clock: Label
var _level: Label
var _panel: ColorRect
var _title: Label
var _stats: Label
var _hp_share: float = 1.0
var _blink: float = 0.0


func _ready() -> void:
	_layout_bottom_strip()

	_panel = ColorRect.new()
	_panel.color = PANEL
	_panel.size = PANEL_SIZE
	_panel.visible = false
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	_title = _label("", Control.PRESET_TOP_WIDE, _panel)
	_stats = _label("", Control.PRESET_HCENTER_WIDE, _panel)
	_label("ATTACK: AGAIN", Control.PRESET_BOTTOM_WIDE, _panel)

	Events.player_hit.connect(_on_player_hit)
	Events.time_changed.connect(_on_time_changed)
	Events.run_ended.connect(_on_run_ended)


## Everything in one strip along the bottom, the top of the screen left clear.
func _layout_bottom_strip() -> void:
	var strip := ColorRect.new()
	strip.color = PANEL
	add_child(strip)
	strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	strip.offset_top = -STRIP_HEIGHT
	var view := get_viewport().get_visible_rect().size
	var back := ColorRect.new()
	back.color = BAR_BACK
	back.position = Vector2((view.x - BAR_SIZE.x) / 2, (STRIP_HEIGHT - BAR_SIZE.y) / 2)
	back.size = BAR_SIZE
	strip.add_child(back)
	_bar_fill = ColorRect.new()
	_bar_fill.color = BAR_FILL
	_bar_fill.size = BAR_SIZE
	back.add_child(_bar_fill)
	_clock = _label("00:00", Control.PRESET_CENTER_LEFT, strip)
	_level = _label("LV 1", Control.PRESET_CENTER_RIGHT, strip)


func _process(delta: float) -> void:
	if _hp_share > LOW_HP_SHARE or _hp_share <= 0.0:
		_bar_fill.visible = true
		return
	_blink = fmod(_blink + delta * LOW_BLINK_HZ, 1.0)
	_bar_fill.visible = _blink < BLINK_DUTY


func _label(text: String, preset: Control.LayoutPreset, parent: Node = self) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override(&"font", FONT)
	l.add_theme_font_size_override(&"font_size", FONT_SIZE)
	l.add_theme_color_override(&"font_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	l.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, MARGIN)
	return l


static func clock_text(seconds: int) -> String:
	return "%02d:%02d" % [seconds / SECONDS_PER_MINUTE, seconds % SECONDS_PER_MINUTE]


func _on_player_hit(hp: int, max_hp: int) -> void:
	_hp_share = float(hp) / max_hp
	_bar_fill.size.x = BAR_SIZE.x * _hp_share


func _on_time_changed(seconds: int) -> void:
	_clock.text = clock_text(seconds)


func _on_run_ended(won: bool, seconds: float, level: int) -> void:
	_title.text = "THE SHRINE HOLDS" if won else "THE WILDS TAKE THE SHRINE"
	_stats.text = "TIME %s   LEVEL %d" % [clock_text(floori(seconds)), level]
	_panel.visible = true
