extends "res://addons/snopek-state-machine/State.gd"

var ExplodeEffect: PackedScene = preload("res://actors/ExplodeEffect.tscn")

onready var host = $"../.."

func _state_enter(info: Dictionary) -> void:
	var explosion = ExplodeEffect.instance()
	host.get_parent().add_child(explosion)
	explosion.global_position = host.global_position
	
	host.die()
