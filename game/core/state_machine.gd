class_name StateMachine
extends RefCounted
## The current state of an entity and the transitions allowed out of each state.
## Entity state lives here instead of in boolean flags.

var state: StringName
## Seconds since the last transition. The owner advances it with tick().
var time_in_state: float = 0.0
var _allowed: Dictionary[StringName, Array]


## Every state must have an entry, even if it allows nothing (a final state).
func _init(start: StringName, allowed: Dictionary[StringName, Array]) -> void:
	assert(allowed.has(start), "unknown start state " + start)
	for targets: Array in allowed.values():
		for to: StringName in targets:
			assert(allowed.has(to), "transition to unknown state " + to)
	state = start
	_allowed = allowed


func can_go(to: StringName) -> bool:
	return _allowed[state].has(to)


## Changes state and resets the timer. Returns false, and changes nothing, if the
## transition isn't in the table.
func go(to: StringName) -> bool:
	if not can_go(to):
		return false
	state = to
	time_in_state = 0.0
	return true


func tick(delta: float) -> void:
	time_in_state += delta
