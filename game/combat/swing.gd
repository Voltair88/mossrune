class_name Swing
extends RefCounted
## Geometry of the sword arc.


## True if a circle (target, target_radius) touches the arc in front of origin.
## aim must be normalised. half_arc is in radians.
static func hits(
	origin: Vector2,
	aim: Vector2,
	reach: float,
	half_arc: float,
	target: Vector2,
	target_radius: float,
) -> bool:
	var to := target - origin
	var dist := to.length()
	if dist > reach + target_radius:
		return false
	if dist <= target_radius:
		return true
	# A wide target still touches the arc when its centre is slightly outside it.
	var slack := asin(target_radius / dist)
	return absf(aim.angle_to(to)) <= half_arc + slack


## Turns aim toward target if the target is inside the assist cone.
static func assist(origin: Vector2, aim: Vector2, target: Vector2, half_cone: float) -> Vector2:
	var to := target - origin
	if to == Vector2.ZERO or absf(aim.angle_to(to)) > half_cone:
		return aim
	return to.normalized()
