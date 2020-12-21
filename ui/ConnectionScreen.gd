extends Control

func _on_LoginButton_pressed() -> void:
	var email = $TabContainer/Login/GridContainer/Email.text
	var password = $TabContainer/Login/GridContainer/Password.text
	
	UI.hide_screen()
	UI.show_message("Logging in...")
	
	var nakama_session = yield(Online.nakama_client.authenticate_email_async(email, password), "completed")
	
	if nakama_session.is_exception():
		UI.show_message("Login failed!")
		UI.show_screen("ConnectionScreen")
	else:
		Online.nakama_session = nakama_session
		UI.hide_message()
		UI.show_screen("MatchScreen")

func _on_Create_Account_pressed() -> void:
	var username = $"TabContainer/Create Account/GridContainer/Username".text
	var email = $"TabContainer/Create Account/GridContainer/Email".text
	var password = $"TabContainer/Create Account/GridContainer/Password".text
	
	UI.hide_screen()
	UI.show_message("Creating account...")

	var nakama_session = yield(Online.nakama_client.authenticate_email_async(email, password, username, true), "completed")
	
	if nakama_session.is_exception():
		var msg = nakama_session.get_exception().message
		# Nakama treats registration as logging in, so this is what we get if the
		# the email is already is use but the password is wrong.
		if msg == 'Invalid credentials.':
			msg = 'E-mail already in use.'
		elif msg == '':
			msg = "Unable to create account"
		UI.show_message(msg)
		UI.show_screen("ConnectionScreen")
	else:
		Online.nakama_session = nakama_session
		UI.hide_all()
		UI.show_screen("MatchScreen")

