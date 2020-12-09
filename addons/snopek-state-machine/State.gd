tool
extends Node

const StateMachine = preload("res://addons/snopek-state-machine/StateMachine.gd")

func _get_configuration_warning() -> String:
	if not get_parent() is StateMachine:
		return "Parent node must be a StateMachine node"
	return ""

func _state_enter(info : Dictionary):
	pass
	
func _state_exit():
	pass
