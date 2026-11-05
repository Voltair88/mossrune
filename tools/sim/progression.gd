extends SceneTree
## Prints the paper simulation's tables and exits 1 if a pacing target is missed.
## godot_console --headless --path . -s res://tools/sim/progression.gd

const Sim := preload("res://tools/sim/progression_sim.gd")


func _init() -> void:
	var curve := load("res://data/tuning/xp_curve.tres") as XpCurve
	var result := Sim.run(curve, WaveSchedule.load_dir("res://data/waves"))

	print("minute  spawns  kills    xp  level")
	for m in result.minutes.size():
		var row: Dictionary = result.minutes[m]
		print("%6d  %6.0f  %5.0f  %4.0f  %5d" % [m + 1, row.spawns, row.kills, row.xp, row.level])

	print("\nlevel  reached  gap  xp_to_next")
	var prev := 0.0
	for i in result.level_times.size():
		var t := result.level_times[i]
		var stamp := "%d:%02d" % [int(t) / Sim.MINUTE_SEC, int(t) % Sim.MINUTE_SEC]
		print("%5d  %7s  %3.0f  %10d" % [i + 2, stamp, t - prev, curve.xp_to_next(i + 2)])
		prev = t

	var misses := Sim.misses(result)
	if misses.is_empty():
		print("\nall pacing targets met")
		quit(0)
	else:
		printerr("\nmissed targets:\n  " + "\n  ".join(misses))
		quit(1)
