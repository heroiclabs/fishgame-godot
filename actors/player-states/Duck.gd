extends "res://actors/player-states/Move.gd"

func _state_enter(info: Dictionary) -> void:
	host.play_animation("Duck")

func _state_physics_process(delta: float) -> void:
	_check_pickup_or_throw_or_use()
	
	# Decelerate to 0, but with a "slide".
	if host.vector.x < 0:
		host.vector.x = min(0.0, host.vector.x + (host.sliding_friction * delta))
	elif host.vector.x > 0:
		host.vector.x = max(0.0, host.vector.x - (host.sliding_friction * delta))
	
	var input_vector = _get_player_input_vector()
	do_flip_sprite(input_vector)
	
	if not host.input_buffer.is_action_pressed("down") or not host.is_on_floor():
		get_parent().change_state("Idle")
