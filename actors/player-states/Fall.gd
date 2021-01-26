extends "res://actors/player-states/Move.gd"

func _state_enter(info: Dictionary) -> void:
	host.play_animation("Fall")

func _state_exit() -> void:
	host.show_gliding = false

func _state_physics_process(delta: float) -> void:
	_check_pickup_or_throw_or_use()
	
	var input_vector = _get_player_input_vector()
	
	if host.is_on_floor():
		if abs(input_vector.x) > 0:
			get_parent().change_state("Move", { input_vector = input_vector })
		else:
			get_parent().change_state("Idle", { landing = true })
		return
	
	do_move(input_vector)
	
	# If the player presses the jump key before landing, then glide.
	if host.input_buffer.is_action_pressed("jump"):
		host.vector.y = -host.glide_speed
		host.show_gliding = true
		host.play_animation("Glide")
	else:
		host.play_animation("Fall")
		
