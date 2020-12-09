tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("StateMachine", "Node", preload("StateMachine.gd"), preload("StateMachine.png"))
	add_custom_type("State", "Node", preload("State.gd"), preload("State.png"))

func _exit_tree():
	remove_custom_type("StateMachine")
	remove_custom_type("State")


