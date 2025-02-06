class_name BlackjackStateMachine
extends Node

enum State {
	BETTING,
	DEALING,
	PLAYER_TURN,
	DEALER_TURN,
	GAME_OVER
}

signal state_changed(from_state: State, to_state: State)
signal state_updated(current_state: State, data: Dictionary)

var current_state: State = State.BETTING
var state_data: Dictionary = {}

# State transition validators
var _valid_transitions = {
	State.BETTING: [State.DEALING],
	State.DEALING: [State.PLAYER_TURN],
	State.PLAYER_TURN: [State.PLAYER_TURN, State.DEALER_TURN],  # Allow transition to self for multiple hands
	State.DEALER_TURN: [State.GAME_OVER],
	State.GAME_OVER: [State.BETTING]
}

func change_state(new_state: State, data: Dictionary = {}) -> bool:
	if not _is_valid_transition(new_state):
		push_error("Invalid state transition from %s to %s" % [State.keys()[current_state], State.keys()[new_state]])
		return false
	
	var old_state = current_state
	current_state = new_state
	state_data = data
	
	emit_signal("state_changed", old_state, current_state)
	emit_signal("state_updated", current_state, state_data)
	return true

func update_state_data(data: Dictionary) -> void:
	state_data.merge(data, true)
	emit_signal("state_updated", current_state, state_data)

func _is_valid_transition(new_state: State) -> bool:
	# Allow transition to same state for BETTING
	if current_state == State.BETTING and new_state == State.BETTING:
		return true
	return new_state in _valid_transitions[current_state]

func get_current_state() -> int:
	return current_state

func is_in_state(state: State) -> bool:
	return current_state == state

func get_state_data() -> Dictionary:
	return state_data.duplicate()
