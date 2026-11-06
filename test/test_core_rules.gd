extends GutTest
## Plain rule classes: state machine, health (R7), input buffer (R12), swing
## geometry, the spatial grid and the debug arguments.


func test_state_machine_follows_its_table() -> void:
	var m := StateMachine.new(&"a", { &"a": [&"b"], &"b": [] })
	assert_false(m.go(&"a"), "a -> a not allowed")
	m.tick(0.5)
	assert_true(m.go(&"b"))
	assert_eq(m.state, &"b")
	assert_eq(m.time_in_state, 0.0, "timer resets")
	assert_false(m.go(&"a"), "final state")


func test_two_hits_in_one_frame_count_once() -> void:
	# R7
	var h := Health.new(100, 0.8)
	assert_true(h.take(5))
	assert_false(h.take(5))
	assert_eq(h.hp, 95)
	h.tick(0.8)
	assert_true(h.take(5), "invulnerability ends")


func test_health_floors_at_zero_and_heal_caps() -> void:
	var h := Health.new(10)
	h.take(25)
	assert_eq(h.hp, 0)
	assert_true(h.is_dead())
	h.heal(5)
	assert_eq(h.hp, 0, "no healing the dead")
	var g := Health.new(10)
	g.take(3)
	g.heal(50)
	assert_eq(g.hp, 10)


func test_input_buffer_keeps_a_press_for_its_window() -> void:
	# R12
	var b := InputBuffer.new(0.12)
	assert_false(b.consume(), "nothing pressed")
	b.press()
	b.tick(0.1)
	assert_true(b.consume())
	assert_false(b.consume(), "once per press")
	b.press()
	b.tick(0.13)
	assert_false(b.consume(), "expired")


func test_swing_hits_inside_the_arc_only() -> void:
	var half := deg_to_rad(60.0)
	assert_true(Swing.hits(Vector2.ZERO, Vector2.RIGHT, 24.0, half, Vector2(20, 0), 6.0))
	assert_true(Swing.hits(Vector2.ZERO, Vector2.RIGHT, 24.0, half, Vector2(10, 15), 6.0), "56 deg")
	assert_false(
		Swing.hits(Vector2.ZERO, Vector2.RIGHT, 24.0, half, Vector2(-20, 0), 6.0),
		"behind",
	)
	assert_false(
		Swing.hits(Vector2.ZERO, Vector2.RIGHT, 24.0, half, Vector2(40, 0), 6.0),
		"too far",
	)
	assert_true(
		Swing.hits(Vector2.ZERO, Vector2.RIGHT, 24.0, half, Vector2(-3, 0), 6.0),
		"overlapping",
	)


func test_aim_assist_turns_only_inside_the_cone() -> void:
	var half := deg_to_rad(15.0)
	var aim := Swing.assist(Vector2.ZERO, Vector2.RIGHT, Vector2(10, 2), half)
	assert_almost_eq(aim.angle(), Vector2(10, 2).angle(), 0.0001)
	assert_eq(Swing.assist(Vector2.ZERO, Vector2.RIGHT, Vector2(0, 10), half), Vector2.RIGHT)


func test_grid_query_matches_brute_force() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bounds := Rect2(0, 0, 400, 300)
	var grid := SpatialGrid.new(bounds, 32.0)
	var points: Array[Vector2] = []
	for i in 300:
		points.append(Vector2(rng.randf() * 400, rng.randf() * 300))
		grid.insert(points[i])
	for q in 50:
		var c := Vector2(rng.randf() * 400, rng.randf() * 300)
		var expected := 0
		for p in points:
			if p.distance_to(c) <= 20.0:
				expected += 1
		assert_eq(grid.query(c, 20.0), expected)
	grid.clear()
	assert_eq(grid.query(Vector2(100, 100), 500.0), 0, "cleared")


func test_debug_args() -> void:
	var a := DebugArgs.parse(
		["--seed=42", "--god", "--wave=3", "--spawn=slime:300", "--show-states"]
	)
	assert_eq(a.seed_value, 42)
	assert_true(a.god)
	assert_eq(a.wave, 3)
	assert_eq(a.spawns[&"slime"], 300)
	assert_true(a.show_states)
	assert_eq(a.errors.size(), 0)
	var bad := DebugArgs.parse(["--seed=x", "--spawn=slime", "--nope"])
	assert_eq(bad.errors.size(), 3)
