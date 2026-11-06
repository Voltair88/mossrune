extends GutTest
## Scene tests: the real nodes, input through the InputMap, and the architecture
## rule that UI and gameplay don't reach into each other.

const GYM := preload("res://game/world/gym.tscn")
const MAIN := preload("res://game/main.tscn")
const UI_DIR := "res://game/ui"
const GAMEPLAY_DIRS: Array[String] = [
	"res://game/combat",
	"res://game/enemies",
	"res://game/player",
	"res://game/world",
	"res://game/core",
	"res://game/progression",
]


func _view(root: Node) -> BattleView:
	for child in root.get_children():
		if child is BattleView:
			return child
	return null


func test_input_map_has_keyboard_and_gamepad_for_every_action() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack"]:
		assert_true(InputMap.has_action(action), action)
		var kinds := { }
		for e in InputMap.action_get_events(action):
			kinds[e.get_class()] = true
		assert_true(kinds.has("InputEventKey"), action + " keyboard")
		assert_true(
			kinds.has("InputEventJoypadButton") or kinds.has("InputEventJoypadMotion"),
			action + " gamepad",
		)


func test_attack_input_hits_a_dummy_in_the_gym() -> void:
	var gym: Node = add_child_autofree(GYM.instantiate())
	await wait_physics_frames(2)
	var view := _view(gym)
	var dummy := view.battle.enemies[0]
	view.battle.player.position = dummy.position - Vector2(14, 0)
	view.battle.player.facing = Vector2.RIGHT
	Input.action_press(&"attack")
	await wait_physics_frames(1)
	Input.action_release(&"attack")
	await wait_physics_frames(20)
	assert_lt(dummy.health.hp, dummy.data.hp, "the swing landed")


func test_move_input_moves_the_player() -> void:
	var gym: Node = add_child_autofree(GYM.instantiate())
	await wait_physics_frames(2)
	var view := _view(gym)
	var start := view.battle.player.position
	Input.action_press(&"move_left")
	await wait_physics_frames(20)
	Input.action_release(&"move_left")
	assert_lt(view.battle.player.position.x, start.x - 10.0)


func test_main_scene_runs_and_the_clock_ticks() -> void:
	var seconds := [-1]
	var on_time := func(s: int) -> void:
		seconds[0] = s
	Events.time_changed.connect(on_time)
	var main: Node = add_child_autofree(MAIN.instantiate())
	await wait_physics_frames(70)
	Events.time_changed.disconnect(on_time)
	assert_eq(seconds[0], 1, "one second on the clock")
	assert_not_null(_view(main))


func test_ui_only_listens_and_gameplay_never_touches_ui() -> void:
	# UI may connect to Events and send only its requests; it reads nothing else
	# of the game.
	var game_classes := [
		"Battle",
		"PlayerBrain",
		"EnemyBrain",
		"BattleView",
		"Run",
		"PlayerView",
		"Session",
	]
	var ui_requests := ["upgrade_chosen", "settings_changed", "restart_requested"]
	var emit := RegEx.create_from_string(r"(\w+)\.emit\(")
	for path in _scripts(UI_DIR):
		var code := FileAccess.get_file_as_string(path)
		for m in emit.search_all(code):
			assert_has(ui_requests, m.get_string(1), path + " emits only UI requests")
		for c: String in game_classes:
			assert_false(
				RegEx.create_from_string("\\b%s\\b" % c).search(code) != null,
				path + " uses " + c,
			)
	for dir in GAMEPLAY_DIRS:
		for path in _scripts(dir):
			var code := FileAccess.get_file_as_string(path)
			assert_false(
				code.contains("Hud") or code.contains("game/ui"),
				path + " reaches into UI",
			)


func _scripts(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	return out
