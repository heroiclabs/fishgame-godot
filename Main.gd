extends Node2D

onready var game := $Game
onready var hud := $HUD
onready var ui_layer := $UILayer
onready var ready_screen := $UILayer/ReadyScreen
onready var music := $Music

var nakama_client: NakamaClient
var nakama_session: NakamaSession
var nakama_socket: NakamaSocket

var players := {}
var players_ready := {}
var players_score := {}

var match_started := false

func _ready():
	nakama_client = Nakama.create_client(
		Build.NAKAMA_SERVER_KEY,
		Build.NAKAMA_HOST,
		Build.NAKAMA_PORT,
		'https' if Build.NAKAMA_USE_SSL else 'http')
	
	NakamaWebRTC.connect("error", self, "_on_match_error")
	NakamaWebRTC.connect("disconnected", self, "_on_match_disconnected")
	NakamaWebRTC.connect("match_created", self, "_on_match_created")
	NakamaWebRTC.connect("match_joined", self, "_on_match_joined")
	NakamaWebRTC.connect("matchmaker_matched", self, "_on_matchmaker_matched")
	NakamaWebRTC.connect("player_joined", self, "_on_player_joined")
	NakamaWebRTC.connect("player_left", self, "_on_player_left")
	NakamaWebRTC.connect("player_status_changed", self, "_on_player_status_changed")
	NakamaWebRTC.connect("match_ready", self, "_on_match_ready")
	NakamaWebRTC.connect("match_not_ready", self, "_on_match_not_ready")
	
	game.connect("game_started", self, "_on_game_started")
	game.connect("player_dead", self, "_on_player_dead")
	game.connect("game_over", self, "_on_game_over")
	
	randomize()
	music.play_random()
	
	# Remap controls for a Dvorak keyboard (until we have a settings menu)
	if Build.DVORAK:
		var dvorak_mappings := {
			player1_right = KEY_E,
			player1_down = KEY_O,
			player1_jump = KEY_COMMA,
			player1_grab = KEY_J,
			player1_use = KEY_K,
			player2_grab = KEY_N,
			player2_use = KEY_S,
		}
		for action in dvorak_mappings:
			remap_key_for_action(action, dvorak_mappings[action])

func remap_key_for_action(action: String, key: int) -> void:
	for event in InputMap.get_action_list(action):
		if event is InputEventKey:
			event.scancode = key

#func _unhandled_input(event: InputEvent) -> void:
#	# Trigger debugging action!
#	if event.is_action_pressed("player_debug"):
#		# Close all our peers to force a reconnect (to make sure it works).
#		for session_id in NakamaWebRTC.webrtc_peers:
#			var webrtc_peer = NakamaWebRTC.webrtc_peers[session_id]
#			webrtc_peer.close()

func _on_UILayer_change_screen(name, _screen) -> void:
	if name == 'MatchScreen':
		if not nakama_session or nakama_session.is_expired():
			nakama_socket = null
			# If we were previously connected, then show a message.
			if nakama_session:
				hud.show_message("Login session has expired")
			ui_layer.show_screen("ConnectionScreen")
		elif not nakama_socket or not nakama_socket.is_connected_to_host():
			nakama_socket = Nakama.create_socket_from(nakama_client)
			yield(nakama_socket.connect_async(nakama_session), "completed")
			NakamaWebRTC.nakama_socket = nakama_socket
	
	if name == 'TitleScreen':
		hud.hide_exit_button()
	else:
		hud.show_exit_button()
	
	if name != 'ReadyScreen':
		if match_started:
			match_started = false
			music.play_random()

func _on_TitleScreen_play_online() -> void:
	GameState.online_play = true
	ui_layer.show_screen("MatchScreen")
	
	# Show the game map in the background because we have nothing better.
	game.reload_map()

func _on_TitleScreen_play_local() -> void:
	GameState.online_play = false
	ui_layer.hide_screen()
	
	start_game()

func _on_ConnectionScreen_login(email, password) -> void:
	ui_layer.hide_screen()
	hud.show_message("Logging in...")
	
	nakama_session = yield(nakama_client.authenticate_email_async(email, password), "completed")
	
	if nakama_session.is_exception():
		hud.show_message("Login failed!")
		ui_layer.show_screen("ConnectionScreen")
	else:
		hud.hide_all()
		ui_layer.show_screen("MatchScreen")

func _on_ConnectionScreen_create_account(username, email, password) -> void:
	ui_layer.hide_screen()
	hud.show_message("Creating account...")

	nakama_session = yield(nakama_client.authenticate_email_async(email, password, username, true), "completed")
	
	if nakama_session.is_exception():
		var msg = nakama_session.get_exception().message
		# Nakama treats registration as logging in, so this is what we get if the
		# the email is already is use but the password is wrong.
		if msg == 'Invalid credentials.':
			msg = 'E-mail already in use.'
		elif msg == '':
			msg = "Unable to create account"
		hud.show_message(msg)
		ui_layer.show_screen("ConnectionScreen")
	else:
		hud.hide_all()
		ui_layer.show_screen("MatchScreen")

func _on_MatchScreen_create_match() -> void:
	if nakama_session.is_expired():
		hud.show_message("Login session has expired")
		ui_layer.show_screen("ConnectionScreen")
	else:
		NakamaWebRTC.create_match()
		hud.hide_message()

func _on_MatchScreen_join_match(match_id) -> void:
	if not match_id:
		hud.show_message("Need to paste Match ID to join")
		return
	
	if nakama_session.is_expired():
		hud.show_message("Login session has expired")
		ui_layer.show_screen("ConnectionScreen")
	else:
		NakamaWebRTC.join_match(match_id)
		hud.hide_message()

func _on_MatchScreen_find_match(min_players: int):
	if nakama_session.is_expired():
		hud.show_message("Login session has expired")
		ui_layer.show_screen("ConnectionScreen")
	else:
		ui_layer.hide_screen()
		hud.show_message("Looking for match...")
		hud.show_exit_button()
		
		var data = {
			min_count = min_players,
			string_properties = {
				game = "test_game",
			},
			query = "+properties.game:test_game",
		}
		NakamaWebRTC.start_matchmaking(data)

func _on_match_error(message: String):
	if message != '':
		hud.show_message(message)
	ui_layer.show_screen("MatchScreen")

func _on_match_disconnected():
	#_on_match_error("Disconnected from host")
	_on_match_error('')

func _on_match_created(match_id):
	ui_layer.show_screen("ReadyScreen", [{}, match_id, true])
	hud.show_exit_button()

func _on_match_joined(match_id):
	ui_layer.show_screen("ReadyScreen", [{}, match_id, true])
	hud.show_exit_button()

func _on_matchmaker_matched(_players):
	hud.hide_all()
	ui_layer.show_screen("ReadyScreen", [_players])
	hud.show_exit_button()

func _on_player_joined(player):
	ready_screen.add_player(player.session_id, player.username)

func _on_player_left(player):
	hud.show_message(player.username + " has left")
	
	ready_screen.remove_player(player.session_id)
	
	game.kill_player(player.peer_id)
	
	players.erase(player.peer_id)
	players_ready.erase(player.peer_id)

func _on_player_status_changed(player, status):
	if status == NakamaWebRTC.PlayerStatus.CONNECTED:
		# Don't go backwards from 'READY!'
		if ready_screen.get_status(player.session_id) != 'READY!':
			ready_screen.set_status(player.session_id, 'Connected.')
		
		if get_tree().is_network_server():
			# Tell this new player about all the other players that are already ready.
			for session_id in players_ready:
				rpc_id(player.peer_id, "player_ready", session_id)
	elif status == NakamaWebRTC.PlayerStatus.CONNECTING:
		ready_screen.set_status(player.session_id, 'Connecting...')

func _on_match_ready(_players):
	ready_screen.set_ready_button_enabled(true)

func _on_match_not_ready():
	ready_screen.set_ready_button_enabled(false)

func _on_ReadyScreen_ready_pressed() -> void:
	rpc("player_ready", NakamaWebRTC.get_my_session_id())

remotesync func player_ready(session_id):
	ready_screen.set_status(session_id, "READY!")
	
	if get_tree().is_network_server() and not players_ready.has(session_id):
		players_ready[session_id] = true
		if players_ready.size() == NakamaWebRTC.players.size():
			if NakamaWebRTC.match_state != NakamaWebRTC.MatchState.PLAYING:
				NakamaWebRTC.start_playing()
			start_game()

func _on_HUD_start() -> void:
	start_game()

func _on_HUD_exit() -> void:
	stop_game()
	hud.hide_all()
	
	if ui_layer.current_screen_name == 'ConnectionScreen' or ui_layer.current_screen_name == 'MatchScreen':
		ui_layer.show_screen("TitleScreen")
	elif not GameState.online_play:
		ui_layer.show_screen("TitleScreen")
	else:
		ui_layer.show_screen("MatchScreen")

func start_game() -> void:
	if GameState.online_play:
		players = NakamaWebRTC.get_player_names_by_peer_id()
	else:
		players = {
			1: "Player1",
			2: "Player2",
		}
	
	game.game_start(players)

func _on_game_started() -> void:
	ui_layer.hide_screen()
	hud.hide_all()
	hud.show_exit_button()
	
	if not match_started:
		match_started = true
		music.play_random()

func stop_game() -> void:
	NakamaWebRTC.leave()
	
	players.clear()
	players_ready.clear()
	players_score.clear()
	
	game.game_stop()

func restart_game() -> void:
	stop_game()
	start_game()

func _on_player_dead(player_id : int) -> void:
	if GameState.online_play:
		var my_id = get_tree().get_network_unique_id()
		if player_id == my_id:
			hud.show_message("You lose!")

func _on_game_over(player_id: int) -> void:
	players_ready.clear()
	
	if not GameState.online_play:
		show_winner(players[player_id])
	elif get_tree().is_network_server():
		if not players_score.has(player_id):
			players_score[player_id] = 1
		else:
			players_score[player_id] += 1
		
		var player_session_id = NakamaWebRTC.get_session_id(player_id)
		var is_match: bool = players_score[player_id] >= 5
		rpc("show_winner", players[player_id], player_session_id, players_score[player_id], is_match)

remotesync func show_winner(name, session_id: String = '', score: int = 0, is_match: bool = false):
	if is_match:
		hud.show_message(name + " WINS THE WHOLE MATCH!")
	else:
		hud.show_message(name + " wins this round!")
	
	yield(get_tree().create_timer(2.0), "timeout")
	
	if GameState.online_play:
		if is_match:
			stop_game()
			ui_layer.show_screen("MatchScreen")
		else:
			ready_screen.hide_match_id()
			ready_screen.reset_status("Waiting...")
			ready_screen.set_score(session_id, score)
			ui_layer.show_screen("ReadyScreen")
	else:
		restart_game()

func _on_Music_song_finished(song) -> void:
	if not music.current_song.playing:
		music.play_random()
