class_name InputBuffer
extends RefCounted
## Remembers a press for a short window, so an attack pressed just before the
## player is ready still fires.

var window_sec: float
var _age: float = INF


func _init(window: float) -> void:
	window_sec = window


func press() -> void:
	_age = 0.0


func tick(delta: float) -> void:
	_age += delta


## True once per press, if the press is no older than the window.
func consume() -> bool:
	if _age > window_sec:
		return false
	_age = INF
	return true
