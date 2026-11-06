class_name Run
extends RefCounted
## One run: its clock, level and seed. Owned by the main scene. Phase 4 adds XP
## and the chosen upgrades.

var run_seed: int
var rng := RandomNumberGenerator.new()
var elapsed: float = 0.0
var length_sec: float
var level: int = 1


func _init(seed_value: int, run_length: float) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	length_sec = run_length


func is_won() -> bool:
	return elapsed >= length_sec


## Whole seconds on the clock, for the HUD.
func seconds() -> int:
	return floori(elapsed)
