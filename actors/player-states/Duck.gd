extends "res://actors/player-states/Move.gd"

func _state_enter(info: Dictionary) -> void:
	host.play_animation("Duck")
	host.ducking_collision_shape.set_deferred('disabled', false)
	host.standing_collision_shape.set_deferred('disabled', true)

func _state_exit() -> void:
	host.ducking_collision_shape.set_deferred('disabled', true)
	host.standing_collision_shape.set_deferred('disabled', false)

func _state_physics_process(delta: float) -> void:
	_check_pickup_or_throw_or_use()
	
	var input_vector = _get_player_input_vector()
	do_flip_sprite(input_vector)
	
	_decelerate_to_zero(delta)
	
	if not host.input_buffer.is_action_pressed("down") or not host.is_on_floor():
		get_parent().change_state("Idle")
	elif host.input_buffer.is_action_just_pressed("jump"):
		host.pass_through_one_way_platforms = true
	else:
		# If we haven't started moving by the next frame then we must not have
		# actually been on a one way platform, so we reset this value.
		host.pass_through_one_way_platforms = false
