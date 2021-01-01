extends HBoxContainer

func setup(username, score) -> void:
	$UsernameLabel.text = username
	$WinsLabel.text = str(score)
