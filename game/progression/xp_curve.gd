class_name XpCurve
extends Resource
## XP needed to go from one level to the next:
## floor(base + growth * (level - 1) ^ exponent). Values live in data/tuning/xp_curve.tres.

@export var base: float = 12.0
@export var growth: float = 1.5
@export var exponent: float = 1.3


## Levels below 1 are treated as level 1.
func xp_to_next(level: int) -> int:
	var steps: int = maxi(level, 1) - 1
	return floori(base + growth * pow(steps, exponent))
