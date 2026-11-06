extends GutTest
## R10: the level-up screen and the pause menu work with only a keyboard or only
## a gamepad. Events come from the InputMap itself, so the test follows rebinds.

const KINDS: Array[String] = ["InputEventKey", "InputEventJoypadButton"]

var _offer: Array[UpgradeData] = []
var _picked: Array[UpgradeData] = []


func before_all() -> void:
	_offer = UpgradePool.load_dir("res://data/upgrades").upgrades.slice(0, UpgradePool.OFFER_SIZE)


func before_each() -> void:
	_picked.clear()
	Events.upgrade_chosen.connect(_on_chosen)


func after_each() -> void:
	Events.upgrade_chosen.disconnect(_on_chosen)
	get_tree().paused = false


func _on_chosen(u: UpgradeData) -> void:
	_picked.append(u)


func _tap(action: StringName, kind: String) -> void:
	var source: InputEvent
	for e in InputMap.action_get_events(action):
		if e.get_class() == kind:
			source = e
			break
	assert_not_null(source, "%s has a %s binding" % [action, kind])
	for pressed: bool in [true, false]:
		var e := source.duplicate() as InputEvent
		if e is InputEventKey:
			(e as InputEventKey).pressed = pressed
		elif e is InputEventJoypadButton:
			(e as InputEventJoypadButton).pressed = pressed
		Input.parse_input_event(e)
		await wait_process_frames(2)


func _screen() -> LevelUpScreen:
	var s := LevelUpScreen.new()
	add_child_autofree(s)
	return s


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func test_level_up_screen_focuses_waits_then_picks_with_accept() -> void:
	for kind in KINDS:
		_picked.clear()
		var s := _screen()
		await wait_process_frames(1)
		Events.level_up.emit(2, _offer)
		await wait_process_frames(1)
		assert_true(s.visible, kind)
		assert_true(_focused() is Button, kind + ": a choice has focus")
		await _tap(&"ui_accept", kind)
		assert_true(_picked.is_empty(), kind + ": a press right away is ignored")
		await wait_seconds(LevelUpScreen.INPUT_DELAY_SEC + 0.1)
		await _tap(&"ui_right", kind)
		await _tap(&"ui_accept", kind)
		assert_eq(_picked.size(), 1, kind + ": accept picks")
		assert_false(s.visible, kind + ": hidden after the pick")


func test_pause_opens_and_closes_with_keyboard_and_gamepad() -> void:
	for kind in KINDS:
		var menu := PauseMenu.new()
		add_child_autofree(menu)
		await wait_process_frames(1)
		await _tap(&"pause", kind)
		assert_true(menu.visible, kind + ": open")
		assert_true(get_tree().paused, kind + ": paused")
		assert_true(_focused() is Button, kind + ": resume has focus")
		await _tap(&"ui_cancel", kind)
		assert_false(menu.visible, kind + ": closed")
		assert_false(get_tree().paused, kind + ": running again")


func test_pause_toggles_send_settings_and_focus_returns() -> void:
	var s := _screen()
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	await wait_process_frames(1)
	Events.level_up.emit(2, _offer)
	await wait_process_frames(1)
	var choice := _focused()
	var sent: Array[bool] = []
	var on_settings := func(shake: bool, _flashes: bool) -> void:
		sent.append(shake)
	Events.settings_changed.connect(on_settings)
	await _tap(&"pause", "InputEventKey")
	await _tap(&"ui_down", "InputEventKey")
	await _tap(&"ui_accept", "InputEventKey")
	Events.settings_changed.disconnect(on_settings)
	assert_eq(sent, [not GameSettings.shake] as Array[bool], "screenshake toggled")
	await _tap(&"pause", "InputEventKey")
	assert_eq(_focused(), choice, "focus goes back to the level-up choice")
	assert_true(s.visible)


func test_end_panel_focuses_again_and_restarts_with_accept() -> void:
	for kind in KINDS:
		var hud := Hud.new()
		add_child_autofree(hud)
		await wait_process_frames(1)
		var asked := [0]
		var on_restart := func() -> void:
			asked[0] += 1
		Events.restart_requested.connect(on_restart)
		Events.run_ended.emit(false, 30.0, 2, 0.0, 0)
		await wait_process_frames(1)
		assert_true(_focused() is Button, kind + ": again has focus")
		await _tap(&"ui_accept", kind)
		assert_eq(asked[0], 0, kind + ": a press right away is ignored")
		await wait_seconds(Hud.RESTART_DELAY_SEC + 0.1)
		await _tap(&"ui_accept", kind)
		Events.restart_requested.disconnect(on_restart)
		assert_eq(asked[0], 1, kind + ": accept restarts")
