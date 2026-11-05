extends GutTest


func _wave(start: float, duration: float, r0: float, r1: float) -> WaveData:
	var w := WaveData.new()
	w.start_sec = start
	w.duration_sec = duration
	w.spawns_per_sec_start = r0
	w.spawns_per_sec_end = r1
	return w


func test_rate_ramps_linearly_inside_the_wave() -> void:
	var w := _wave(10.0, 20.0, 1.0, 3.0)
	assert_almost_eq(w.rate_at(10.0), 1.0, 0.0001)
	assert_almost_eq(w.rate_at(20.0), 2.0, 0.0001)


func test_rate_is_zero_outside_the_wave() -> void:
	var w := _wave(10.0, 20.0, 1.0, 3.0)
	assert_eq(w.rate_at(9.9), 0.0)
	assert_eq(w.rate_at(30.0), 0.0, "end is exclusive")


func test_spawns_between_is_the_integral() -> void:
	# Area under 1 -> 3 over 20 s is 40.
	var w := _wave(10.0, 20.0, 1.0, 3.0)
	assert_almost_eq(w.spawns_between(0.0, 100.0), 40.0, 0.0001)
	assert_almost_eq(w.spawns_between(10.0, 20.0), 15.0, 0.0001)


func test_spawns_between_adds_up_across_splits() -> void:
	var w := _wave(3.0, 47.0, 0.4, 2.7)
	var whole := w.spawns_between(0.0, 60.0)
	var parts := 0.0
	for s in 60:
		parts += w.spawns_between(s, s + 1)
	assert_almost_eq(parts, whole, 0.001)


func test_empty_or_reversed_range_spawns_nothing() -> void:
	var w := _wave(0.0, 10.0, 1.0, 1.0)
	assert_eq(w.spawns_between(5.0, 5.0), 0.0)
	assert_eq(w.spawns_between(6.0, 5.0), 0.0)


func test_weight_share() -> void:
	var w := _wave(0.0, 10.0, 1.0, 1.0)
	w.enemy_ids = [&"slime", &"bat"]
	w.enemy_weights = [3.0, 1.0]
	assert_almost_eq(w.weight_share(&"slime"), 0.75, 0.0001)
	assert_eq(w.weight_share(&"mossback"), 0.0)


func test_schedule_sums_overlapping_waves_and_splits_by_enemy() -> void:
	var a := _wave(0.0, 10.0, 1.0, 1.0)
	var b := _wave(5.0, 10.0, 2.0, 2.0)
	b.enemy_ids = [&"bat"]
	var schedule := WaveSchedule.new([b, a])
	assert_eq(schedule.waves[0], a, "sorted by start")
	assert_almost_eq(schedule.rate_at(7.0), 3.0, 0.0001)
	var split := schedule.spawns_by_enemy(0.0, 20.0)
	assert_almost_eq(split[&"slime"], 10.0, 0.0001)
	assert_almost_eq(split[&"bat"], 20.0, 0.0001)
