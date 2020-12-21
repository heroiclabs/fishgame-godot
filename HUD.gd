extends CanvasLayer

onready var message_label = $Message
onready var back_button = $BackButton

signal back_button ()

func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true

func hide_message() -> void:
	message_label.visible = false

func show_back_button() -> void:
	back_button.visible = true

func hide_back_button() -> void:
	back_button.visible = false

func hide_all() -> void:
	hide_message()
	hide_back_button()

func _on_BackButton_pressed() -> void:
	emit_signal("back_button")
