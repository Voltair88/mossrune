class_name Run
extends RefCounted
## One run: its clock, level, XP and seed. Owned by the main scene.

var run_seed: int
var rng := RandomNumberGenerator.new()
var elapsed: float = 0.0
var length_sec: float
var level: int = 1
## XP gathered toward the next level.
var xp: int = 0
var curve: XpCurve


func _init(seed_value: int, run_length: float, xp_curve: XpCurve) -> void:
	run_seed = seed_value
	rng.seed = seed_value
	length_sec = run_length
	curve = xp_curve


func is_won() -> bool:
	return elapsed >= length_sec


## Whole seconds on the clock, for the HUD.
func seconds() -> int:
	return floori(elapsed)


func xp_needed() -> int:
	return curve.xp_to_next(level)


## Adds XP and returns how many levels it gained (several from one big pickup).
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		gained += 1
	return gained
