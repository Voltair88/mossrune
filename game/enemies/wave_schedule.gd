class_name WaveSchedule
extends RefCounted
## All waves of a run, read from WaveData files.

var waves: Array[WaveData] = []


func _init(wave_list: Array[WaveData] = []) -> void:
	waves = wave_list.duplicate()
	waves.sort_custom(
		func(a: WaveData, b: WaveData) -> bool:
			return a.start_sec < b.start_sec,
	)


## Loads every .tres in a folder, so a new wave needs only a new file.
static func load_dir(dir_path: String) -> WaveSchedule:
	var found: Array[WaveData] = []
	for file in DirAccess.get_files_at(dir_path):
		if file.ends_with(".tres"):
			var wave := load(dir_path.path_join(file)) as WaveData
			assert(wave != null, "not a WaveData: " + file)
			found.append(wave)
	return WaveSchedule.new(found)


func rate_at(t: float) -> float:
	var total: float = 0.0
	for wave in waves:
		total += wave.rate_at(t)
	return total


func spawns_between(t0: float, t1: float) -> float:
	var total: float = 0.0
	for wave in waves:
		total += wave.spawns_between(t0, t1)
	return total


## Expected spawns per enemy id in [t0, t1]. Assumes ids within a wave are
## unique, which test_wave_data checks for every file.
func spawns_by_enemy(t0: float, t1: float) -> Dictionary[StringName, float]:
	var out: Dictionary[StringName, float] = { }
	for wave in waves:
		var n: float = wave.spawns_between(t0, t1)
		if n <= 0.0:
			continue
		for id in wave.enemy_ids:
			out[id] = out.get(id, 0.0) + n * wave.weight_share(id)
	return out
