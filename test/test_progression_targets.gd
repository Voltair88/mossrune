extends GutTest
## Fails when a tuning change pushes the paper simulation off the Design
## page's pacing targets. Run tools/sim/progression.gd for the tables.

const Sim := preload("res://tools/sim/progression_sim.gd")


func test_tuned_data_meets_pacing_targets() -> void:
	var curve := load("res://data/tuning/xp_curve.tres") as XpCurve
	var result := Sim.run(curve, WaveSchedule.load_dir("res://data/waves"))
	var misses := Sim.misses(result)
	assert_eq(misses.size(), 0, "\n".join(misses))


func test_misses_reports_a_slow_curve() -> void:
	var slow := XpCurve.new()
	slow.base = 1000.0
	var result := Sim.run(slow, WaveSchedule.load_dir("res://data/waves"))
	assert_gt(Sim.misses(result).size(), 0)
