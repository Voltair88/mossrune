extends GutTest
## Checks the wave files in data/waves against the Design page's rules.

const RUN_SEC := 600.0
const LULL_MIN_SEC := 10.0
const LULL_MAX_SEC := 15.0

var _schedule: WaveSchedule


func before_all() -> void:
	_schedule = WaveSchedule.load_dir("res://data/waves")


func test_there_are_waves() -> void:
	assert_gt(_schedule.waves.size(), 0)


func test_each_wave_is_well_formed() -> void:
	for w in _schedule.waves:
		var name := w.resource_path.get_file()
		assert_gt(w.duration_sec, 0.0, name)
		assert_true(w.spawns_per_sec_start >= 0.0 and w.spawns_per_sec_end >= 0.0, name)
		assert_eq(w.enemy_ids.size(), w.enemy_weights.size(), name + " ids and weights match")
		for id in w.enemy_ids:
			assert_eq(w.enemy_ids.count(id), 1, name + " duplicate id " + id)
		for weight in w.enemy_weights:
			assert_gt(weight, 0.0, name)


func test_waves_fit_the_run_with_lulls_between() -> void:
	var waves := _schedule.waves
	assert_eq(waves[0].start_sec, 0.0, "first wave starts at once")
	assert_almost_eq(waves[-1].end_sec(), RUN_SEC, 0.001, "last wave runs to the end")
	for i in range(1, waves.size()):
		var lull := waves[i].start_sec - waves[i - 1].end_sec()
		assert_between(
			lull,
			LULL_MIN_SEC,
			LULL_MAX_SEC,
			"lull before " + waves[i].resource_path.get_file(),
		)


func test_each_wave_peaks_at_least_as_high_as_the_last() -> void:
	var waves := _schedule.waves
	for i in range(1, waves.size()):
		assert_true(
			waves[i].spawns_per_sec_end >= waves[i - 1].spawns_per_sec_end,
			waves[i].resource_path.get_file(),
		)
