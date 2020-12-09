tool
extends Node

export (String, MULTILINE) var allowed_transitions setget set_allowed_transitions

var current_state
var allowed_transitions_parsed := {}

signal state_changed (state, info)

# @todo Causes some error in game!
#func _get_configuration_warning() -> String:
#	var bad_children = PoolStringArray()
#	for child in get_children():
#		if not child is preload("res://addons/snopek-state-machine/State.gd"):
#			bad_children.append(child.name)
#	if bad_children.size() > 0:
#		return "All direct children of StateMachine must be State: " + bad_children.join(", ")
#	return ""

func set_allowed_transitions(_allowed_transitions) -> void:
	if allowed_transitions != _allowed_transitions:
		allowed_transitions = _allowed_transitions
		
		allowed_transitions_parsed = {}
		for line in allowed_transitions.split("\n", false):
			var parts = line.split("->", false)
			if parts.size() == 2:
				var start = parts[0].strip_edges()
				var end = parts[1].strip_edges()
				
				if !allowed_transitions_parsed.has(start):
					allowed_transitions_parsed[start] = []
				allowed_transitions_parsed[start].append(end)

func check_allowed_transition(start, end) -> bool:
	if allowed_transitions_parsed.size() == 0:
		return true
	if allowed_transitions_parsed.has('*') and allowed_transitions_parsed['*'].find(end) != -1:
		return true
	if !allowed_transitions_parsed.has(start):
		return false
	return allowed_transitions_parsed[start].find(end) != -1 or allowed_transitions_parsed[start].find('*') != -1

func change_state(name : String, info : Dictionary = {}):
	var next_state = get_node(name)
	if next_state == null:
		return
	
	if current_state == next_state:
		return
	
	if current_state:
		if !check_allowed_transition(current_state.name, next_state.name):
			return

	if current_state:
		if current_state.has_method('_state_exit'):
			current_state._state_exit()
	
	var previous_state = current_state
	current_state = next_state
	
	# Re-enable processing for the current state
	if current_state.has_method('_input'):
		current_state.set_process_input(true)
	if current_state.has_method('_unhandled_input'):
		current_state.set_process_unhandled_input(true)
	if current_state.has_method('_unhandled_key_input'):
		current_state.set_process_unhandled_key_input(true)
	if current_state.has_method('_process'):
		current_state.set_process(true)
	if current_state.has_method('_physics_process'):
		current_state.set_physics_process(true)	
	
	if current_state != previous_state:
		if current_state.has_method('_state_enter'):
			current_state._state_enter(info)
	
	emit_signal("state_changed", current_state, info)

func _input(event: InputEvent) -> void:
	if current_state and current_state.has_method('_state_input'):
		current_state._state_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if current_state and current_state.has_method('_state_unhandled_input'):
		current_state._state_unhandled_input(event)

func _unhandled_key_input(event: InputEventKey) -> void:
	if current_state and current_state.has_method('_state_unhandled_key_input'):
		current_state._state_unhandled_key_input(event)

func _process(delta: float) -> void:
	if current_state and current_state.has_method('_state_process'):
		current_state._state_process(delta)

func _physics_process(delta: float) -> void:
	if current_state and current_state.has_method('_state_physics_process'):
		current_state._state_physics_process(delta)
