class_name Health
extends RefCounted
## Hit points, with an optional invulnerability window after each hit.

var max_hp: int
var hp: int
var invulnerable_sec: float
var _invulnerable_left: float = 0.0


func _init(max_points: int, invulnerable_after_hit: float = 0.0) -> void:
	max_hp = max_points
	hp = max_points
	invulnerable_sec = invulnerable_after_hit


func is_dead() -> bool:
	return hp <= 0


func invulnerable_left() -> float:
	return _invulnerable_left


## Returns true if the hit landed. A hit during invulnerability, on a dead target
## or for no damage does nothing, so two hits in one frame count once.
func take(amount: int) -> bool:
	if is_dead() or _invulnerable_left > 0.0 or amount <= 0:
		return false
	hp = maxi(hp - amount, 0)
	_invulnerable_left = invulnerable_sec
	return true


func heal(amount: int) -> void:
	if not is_dead():
		hp = mini(hp + amount, max_hp)


func tick(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
