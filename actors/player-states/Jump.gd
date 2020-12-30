extends "res://actors/player-states/Move.gd"

var jumping := false
var gliding := false

func _state_enter(info: Dictionary) -> void:
	host.play_animation("Jump")
	host.sounds.play("Jump")
	host.vector.y = -host.jump_speed
	jumping = true
	gliding = false
	
	if info.has('input_vector'):
		do_move(info['input_vector'])

func _state_exit() -> void:
	_stop_gliding()

func _stop_gliding() -> void:
	if gliding:
		host.pickup_animation_player.play_backwards("RotateUp")
		host.glide_particles.visible = false
		host.glide_particles.emitting = false
		gliding = false

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
		_stop_gliding()
	# If the player presses the jump key before landing, then glide.
	elif not jumping and host.input_buffer.is_action_pressed("jump"):
		host.vector.y = -host.glide_speed
		if not gliding:
			host.pickup_animation_player.play("RotateUp")
			host.glide_particles.visible = true
			host.glide_particles.emitting = true
		gliding = true
		
