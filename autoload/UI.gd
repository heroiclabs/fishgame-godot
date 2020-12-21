extends Node

var ui_layer
var hud

func setup(_ui_layer, _hud) -> void:
	# TODO: Could this instead initialize the UI scenes at the top-level?
	ui_layer = _ui_layer
	hud = _hud

func show_screen(name: String, args: Array = []) -> void:
	if ui_layer:
		ui_layer.show_screen(name, args)
	else:
		OS.alert("Unable to show screen: " + name)

func hide_screen() -> void:
	if ui_layer:
		ui_layer.hide_screen()

func show_message(message: String) -> void:
	if hud:
		hud.show_message(message)
	else:
		OS.alert(message)

func hide_message() -> void:
	if hud:
		hud.hide_message()

func show_back_button() -> void:
	if hud:
		hud.show_back_button()

func hide_back_button() -> void:
	if hud:
		hud.hide_back_button()

func hide_all() -> void:
	if ui_layer:
		ui_layer.hide_screen()
	if hud:
		hud.hide_all()
