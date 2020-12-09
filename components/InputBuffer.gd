extends Reference

var action_prefix := ''
var actions := []
var buffer := {}

enum ActionType {
	PRESSED,
	JUST_PRESSED,
	JUST_RELEASED,
	STRENGTH,
}

func _init(_actions: Array, _action_prefix: String = '') -> void:
	action_prefix = _action_prefix
	actions = _actions

func update_local() -> bool:
	var new_buffer := {}
	for action in actions:
		new_buffer[action] = {
			ActionType.PRESSED: Input.is_action_pressed(action_prefix + action),
			ActionType.JUST_PRESSED: Input.is_action_just_pressed(action_prefix + action),
			ActionType.JUST_RELEASED: Input.is_action_just_released(action_prefix + action),
			ActionType.STRENGTH: Input.get_action_strength(action_prefix + action),
		}
	var changed: bool = new_buffer.hash() != buffer.hash()
	buffer = new_buffer
	return changed

func predict_next_frame() -> void:
	for action in buffer:
		buffer[action][ActionType.JUST_PRESSED] = false
		buffer[action][ActionType.JUST_RELEASED] = false

func is_action_pressed(action) -> bool:
	if not buffer.has(action):
		return false
	return buffer[action][ActionType.PRESSED]

func is_action_just_pressed(action) -> bool:
	if not buffer.has(action):
		return false
	return buffer[action][ActionType.JUST_PRESSED]

func is_action_just_released(action) -> bool:
	if not buffer.has(action):
		return false
	return buffer[action][ActionType.JUST_RELEASED]

func get_action_strength(action) -> float:
	if not buffer.has(action):
		return 0.0
	return buffer[action][ActionType.STRENGTH]
