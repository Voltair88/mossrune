class_name WaveData
extends Resource
## One wave: a window of time in which enemies spawn at a rate that ramps
## linearly from spawns_per_sec_start to spawns_per_sec_end (build-up to peak).
## Gaps between waves are lulls. Files live in data/waves/.

@export var start_sec: float = 0.0
@export var duration_sec: float = 48.0
@export var spawns_per_sec_start: float = 0.5
@export var spawns_per_sec_end: float = 1.0
## Enemy ids, picked by the matching weight.
@export var enemy_ids: Array[StringName] = [&"slime"]
@export var enemy_weights: PackedFloat32Array = [1.0]


func end_sec() -> float:
	return start_sec + duration_sec


## Spawns per second at time t, 0 outside the wave.
func rate_at(t: float) -> float:
	if t < start_sec or t >= end_sec():
		return 0.0
	var f: float = (t - start_sec) / duration_sec
	return lerpf(spawns_per_sec_start, spawns_per_sec_end, f)


## Expected spawns in [t0, t1]: the exact integral of the linear ramp.
func spawns_between(t0: float, t1: float) -> float:
	var u: float = maxf(t0, start_sec) - start_sec
	var v: float = minf(t1, end_sec()) - start_sec
	if v <= u:
		return 0.0
	var slope: float = (spawns_per_sec_end - spawns_per_sec_start) / duration_sec
	return spawns_per_sec_start * (v - u) + slope * (v * v - u * u) / 2


## Share of spawns that are this enemy id, 0 if the wave doesn't use it.
func weight_share(enemy_id: StringName) -> float:
	var total: float = 0.0
	var mine: float = 0.0
	for i in enemy_ids.size():
		total += enemy_weights[i]
		if enemy_ids[i] == enemy_id:
			mine += enemy_weights[i]
	return mine / total if total > 0.0 else 0.0
