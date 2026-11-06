class_name ShakeCamera
extends Camera2D
## Damped screenshake: events add trauma, trauma decays, the offset grows with
## trauma squared so small shakes stay small.

var feel: FeelTuning
var trauma: float = 0.0
var _rng := RandomNumberGenerator.new()


func add_trauma(amount: float) -> void:
	if not GameSettings.shake:
		return
	trauma = minf(trauma + amount, 1.0)


func _process(delta: float) -> void:
	if feel == null:
		return
	trauma = maxf(trauma - feel.shake_decay * delta, 0.0)
	var strength := trauma * trauma * feel.shake_max_px
	offset = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * strength
