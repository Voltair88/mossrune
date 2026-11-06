class_name WaveSpawner
extends RefCounted
## Turns the wave schedule into whole spawns: expected spawns accumulate, and each
## whole one is released. Which enemy comes is a weighted pick from the wave.

var schedule: WaveSchedule
var _owed: float = 0.0


func _init(wave_schedule: WaveSchedule) -> void:
	schedule = wave_schedule


## Spawns due in [t0, t1].
func due(t0: float, t1: float) -> int:
	_owed += schedule.spawns_between(t0, t1)
	var n := floori(_owed)
	_owed -= n
	return n


## Index of the wave running at t, or of the last one that started before it.
func wave_index_at(t: float) -> int:
	var index := 0
	for i in schedule.waves.size():
		if schedule.waves[i].start_sec <= t:
			index = i
	return index


func pick_enemy(t: float, rng: RandomNumberGenerator) -> StringName:
	var wave := schedule.waves[wave_index_at(t)]
	var total := 0.0
	for w in wave.enemy_weights:
		total += w
	var roll := rng.randf() * total
	for i in wave.enemy_ids.size():
		roll -= wave.enemy_weights[i]
		if roll < 0.0:
			return wave.enemy_ids[i]
	return wave.enemy_ids[wave.enemy_ids.size() - 1]
