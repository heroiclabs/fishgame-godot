extends CanvasLayer

signal change_screen (name, screen)

var current_screen_name: String = ''
var _is_ready := false

func _ready() -> void:
	show_screen("TitleScreen")
	_is_ready = true

func show_screen(name: String, args: Array = []) -> void:
	hide_screen()
	var screen = get_node(name)
	screen.visible = true
	if screen.has_method("initialize"):
		screen.callv("initialize", args)
	current_screen_name = name
	if _is_ready:
		emit_signal("change_screen", name, screen)

func hide_screen() -> void:
	for child in get_children():
		child.visible = false
	current_screen_name = ''
