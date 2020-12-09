extends Control

signal login (email, password)
signal create_account (username, email, password)

func _ready():
	pass

func _on_LoginButton_pressed() -> void:
	emit_signal("login",
		$TabContainer/Login/GridContainer/Email.text,
		$TabContainer/Login/GridContainer/Password.text)

func _on_Create_Account_pressed() -> void:
	emit_signal("create_account",
		$"TabContainer/Create Account/GridContainer/Username".text,
		$"TabContainer/Create Account/GridContainer/Email".text,
		$"TabContainer/Create Account/GridContainer/Password".text)
