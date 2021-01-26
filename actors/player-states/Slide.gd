extends "res://actors/player-states/Move.gd"

func _state_enter(info: Dictionary) -> void:
	host.play_animation("Slide")
	host.show_sliding = true
	host.sliding_collision_shape.set_deferred('disabled', false)
	host.standing_collision_shape.set_deferred('disabled', true)

func _state_exit() -> void:
	host.show_sliding = false
	host.sliding_collision_shape.set_deferred('disabled', true)
	host.standing_collision_shape.set_deferred('disabled', false)

func _state_physics_process(delta: float) -> void:
	_check_pickup_or_throw_or_use()
	
	# Decelerate to 0, but with a "slide".
	if host.vector.x < 0:
		host.vector.x = min(0.0, host.vector.x + (host.sliding_friction * delta))
	elif host.vector.x > 0:
		host.vector.x = max(0.0, host.vector.x - (host.sliding_friction * delta))
	
	if host.vector.x == 0.0:
		host.play_animation("SlideFinished")
	
	if not host.input_buffer.is_action_pressed("down") or not host.is_on_floor():
		get_parent().change_state("Idle")

