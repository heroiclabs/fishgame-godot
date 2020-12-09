extends "res://addons/snopek-state-machine/State.gd"

onready var host = $"../.."
onready var timer = $Timer

func _state_enter(info: Dictionary) -> void:
	host.play_animation("Hurt")
	host.sounds.play("Hurt")
	var push_back_vector = info['push_back_vector'] if info.has("push_back_vector") else Vector2.UP
	host.vector = push_back_vector * host.push_back_speed
	timer.start()

func _state_exit() -> void:
	timer.stop()

func _on_Timer_timeout() -> void:
	if host.state_machine.current_state == self:
		host.state_machine.change_state("Dead")
