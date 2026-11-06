class_name GemField
extends RefCounted
## Pickups on the ground (XP gems, or hearts), oldest first. At the cap the
## oldest merges into the next oldest, so the ground never holds more than cap.

## How fast a pickup flies to the player once it is inside the pickup radius.
const FLY_PX_PER_SEC := 220.0

var cap: int
var positions := PackedVector2Array()
var values := PackedInt32Array()


func _init(max_count: int) -> void:
	assert(max_count >= 2, "merging needs room for two pickups")
	cap = max_count


func size() -> int:
	return positions.size()


func add(pos: Vector2, value: int) -> void:
	if positions.size() >= cap:
		values[1] += values[0]
		positions.remove_at(0)
		values.remove_at(0)
	positions.append(pos)
	values.append(value)


## Pickups within pull_px fly toward to; those within reach_px are taken.
## Returns the total value taken.
func collect(to: Vector2, pull_px: float, reach_px: float, delta: float) -> int:
	var total := 0
	var i := positions.size() - 1
	while i >= 0:
		var d := positions[i].distance_to(to)
		if d <= reach_px:
			total += values[i]
			positions.remove_at(i)
			values.remove_at(i)
		elif d <= pull_px:
			positions[i] = positions[i].move_toward(to, FLY_PX_PER_SEC * delta)
		i -= 1
	return total
