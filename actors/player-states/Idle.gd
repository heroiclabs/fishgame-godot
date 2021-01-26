extends "res://addons/snopek-state-machine/State.gd"

onready var host = $"../.."

func _state_enter(info: Dictionary) -> void:
	if info.get('landing', false):
		host.play_animation("Land")
	else:
		host.play_animation("Idle" if host.vector.x == 0.0 else "Walk")

func _get_player_input_vector() -> Vector2:
	return Vector2(host.input_buffer.get_action_strength("right") - host.input_buffer.get_action_strength("left"), 0)

func _check_pickup_or_throw_or_use():
	# Only do this on the client controlling this player, because we have 
	# seperate system for sync'ing pickups and throws that this will conflict
	# with if it runs on a remote player.
	if GameState.online_play and not host.player_controlled:
		return
	
	# We use call_deferred() here so that those operation happen after we've
	# moved the player, so we aren't, for example, shooting from our old position
	# rather than our new position.
	if host.input_buffer.is_action_just_pressed("grab"):
		host.call_deferred("pickup_or_throw")
	elif host.input_buffer.is_action_just_pressed("use"):
		host.call_deferred("try_use")

func _decelerate_to_zero(delta: float) -> void:
	if host.vector.x < 0:
		host.vector.x = min(0.0, host.vector.x + (host.friction * delta))
	elif host.vector.x > 0:
		host.vector.x = max(0.0, host.vector.x - (host.friction * delta))

func _state_physics_process(delta: float) -> void:
	_check_pickup_or_throw_or_use()
	
	if host.vector.y > 0:
		get_parent().change_state("Fall")
		return
	
	var input_vector = _get_player_input_vector()
	
	if host.input_buffer.is_action_just_pressed("jump"):
		if host.is_on_floor():
			get_parent().change_state("Jump", {
				"input_vector": input_vector,
			})
			return
	elif host.input_buffer.is_action_pressed("down") and host.is_on_floor():
		get_parent().change_state("Duck")
		return
	elif input_vector != Vector2.ZERO:
		get_parent().change_state("Move", {
			"input_vector": input_vector,
		})
		return
	
	_decelerate_to_zero(delta)
	
	if host.input_buffer.is_action_just_pressed("blop"):
		host.play_animation("Blop")
	
	# If we just decelerated to 0, then switch to the idle animation.
	if not host.get_current_animation() in ["Idle", "Blop", "Land"] and host.vector.x == 0:
		host.play_animation("Idle")

func _on_SpriteAnimationPlayer_animation_finished(anim_name: String) -> void:
	if host.state_machine.current_state == self and anim_name == "Land":
		host.play_animation("Idle")
