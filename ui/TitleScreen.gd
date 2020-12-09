extends Control

signal play_local
signal play_online

func _on_LocalButton_pressed() -> void:
	emit_signal("play_local")

func _on_OnlineButton_pressed() -> void:
	emit_signal("play_online")
