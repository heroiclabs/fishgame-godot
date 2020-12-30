extends "res://actors/player-states/Move.gd"

var jumping := false

func _state_enter(info: Dictionary) -> void:
	host.play_animation("Jump")
	host.sounds.play("Jump")
	host.vector.y = -host.jump_speed
	jumping = true
	
	if info.has('input_vector'):
		do_move(info['input_vector'])

func _state_exit() -> void:
	host.show_gliding = false

func _state_physics_process(delta: float) -> void:
	_check_pickup_or_throw_or_use()
	_check_blop()
	
	if host.is_on_floor():
		get_parent().change_state("Idle")
		return
	
	var input_vector = _get_player_input_vector()
	do_move(input_vector)
	
	# If the player releases the jump key, then interrupt the jump.
	if host.input_buffer.is_action_just_released("jump"):
		if host.vector.y < 0.0:
			host.vector.y = 0.0
		jumping = false
		host.show_gliding = false
	# If the player presses the jump key before landing, then glide.
	elif not jumping and host.input_buffer.is_action_pressed("jump"):
		host.vector.y = -host.glide_speed
		host.show_gliding = true
		
