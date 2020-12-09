extends Control

signal find_match (min_players)
signal create_match ()
signal join_match (match_id)

onready var matchmaker_player_count_control := $PanelContainer/VBoxContainer/MatchPanel/SpinBox
onready var join_match_id_control := $PanelContainer/VBoxContainer/JoinPanel/LineEdit

func _ready():
	pass

func initialize() -> void:
	matchmaker_player_count_control.value = 2
	join_match_id_control.text = ''

func _on_MatchButton_pressed() -> void:
	emit_signal("find_match", matchmaker_player_count_control.value)

func _on_CreateButton_pressed() -> void:
	emit_signal("create_match")

func _on_JoinButton_pressed() -> void:
	emit_signal("join_match", join_match_id_control.text)

func _on_PasteButton_pressed() -> void:
	join_match_id_control.text = OS.clipboard
