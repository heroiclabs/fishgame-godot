extends Control

func setup(username, score) -> void:
	$HBoxContainer/UsernameLabel.text = username
	$HBoxContainer/WinsLabel.text = str(score)
