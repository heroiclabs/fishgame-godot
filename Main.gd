extends Node2D

onready var game = $Game
onready var ready_screen = $UILayer/ReadyScreen
onready var music := $Music

var players := {}

var players_ready := {}
var players_score := {}

var match_started := false

func _ready() -> void:
	UI.setup($UILayer, $HUD)
	
	OnlineMatch.connect("error", self, "_on_OnlineMatch_error")
	OnlineMatch.connect("disconnected", self, "_on_OnlineMatch_disconnected")
	OnlineMatch.connect("match_created", self, "_on_OnlineMatch_created")
	OnlineMatch.connect("match_joined", self, "_on_OnlineMatch_joined")
	OnlineMatch.connect("matchmaker_matched", self, "_on_OnlineMatch_matchmaker_matched")
	OnlineMatch.connect("player_left", self, "_on_OnlineMatch_player_left")
	
	# Replace Nakama server information with values in Build.gd, which will be
	# filled in by the build system for production builds.
	Online.nakama_server_key = Build.NAKAMA_SERVER_KEY
	Online.nakama_host = Build.NAKAMA_HOST
	Online.nakama_port = Build.NAKAMA_PORT
	Online.nakama_scheme = 'https' if Build.NAKAMA_USE_SSL else 'http'
	
	# Set the client version based on value from the build.
	OnlineMatch.client_version = Build.CLIENT_VERSION
	
	randomize()
	music.play_random()

func _get_custom_rpc_methods() -> Array:
	return [
		'player_ready',
		'show_winner'
	]

#####
# UI callbacks
#####

func _on_TitleScreen_play_local() -> void:
	GameState.online_play = false
	
	UI.hide_screen()
	UI.show_back_button()
	
	start_game()

func _on_TitleScreen_play_online() -> void:
	GameState.online_play = true
	
	# Show the game map in the background because we have nothing better.
	game.reload_map()
	
	UI.show_screen("MatchScreen")

func _on_UILayer_change_screen(name: String, _screen) -> void:
	if name == 'MatchScreen' or name == 'LeaderboardScreen':
		if not Online.nakama_session or Online.nakama_session.is_expired():
			# If we were previously connected, then show a message.
			if Online.nakama_session:
				UI.show_message("Login session has expired")
			UI.show_screen("ConnectionScreen")
	
	if name == 'TitleScreen':
		UI.hide_back_button()
	else:
		UI.show_back_button()
	
	if name != 'ReadyScreen':
		if match_started:
			match_started = false
			music.play_random()

func _on_HUD_back_button() -> void:
	UI.hide_message()
	
	stop_game()
	
	if GameState.online_play:
		OnlineMatch.leave()
	
	var current_screen_name = UI.ui_layer.current_screen_name
	if current_screen_name in ['ConnectionScreen', 'MatchScreen', 'CreditsScreen']:
		UI.show_screen("TitleScreen")
	elif not GameState.online_play:
		UI.show_screen("TitleScreen")
	else:
		UI.show_screen("MatchScreen")

func _on_ReadyScreen_ready_pressed() -> void:
	OnlineMatch.custom_rpc_sync(self, "player_ready", [OnlineMatch.get_my_session_id()])

#####
# OnlineMatch callbacks
#####

func _on_OnlineMatch_error(message: String):
	if message != '':
		UI.show_message(message)
	UI.show_screen("MatchScreen")

func _on_OnlineMatch_disconnected():
	#_on_OnlineMatch_error("Disconnected from host")
	_on_OnlineMatch_error('')

func _on_OnlineMatch_created(match_id: String):
	UI.show_screen("ReadyScreen", [{}, match_id, true])
	UI.show_back_button()

func _on_OnlineMatch_joined(match_id: String):
	UI.show_screen("ReadyScreen", [{}, match_id, true])
	UI.show_back_button()

func _on_OnlineMatch_matchmaker_matched(_players: Dictionary):
	UI.show_screen("ReadyScreen", [_players])
	UI.hide_message()
	UI.show_back_button()

func _on_OnlineMatch_player_left(player) -> void:
	UI.show_message(player.username + " has left")
	
	game.kill_player(player.peer_id)
	
	players.erase(player.peer_id)
	players_ready.erase(player.peer_id)

func _on_OnlineMatch_player_status_changed(player, status) -> void:
	if status == OnlineMatch.PlayerStatus.CONNECTED:
		if OnlineMatch.is_network_server():
			# Tell this new player about all the other players that are already ready.
			for session_id in players_ready:
				OnlineMatch.custom_rpc_id(self, player.peer_id, "player_ready", [session_id])

#####
# Gameplay methods and callbacks
#####

func player_ready(session_id: String) -> void:
	ready_screen.set_status(session_id, "READY!")
	
	if OnlineMatch.is_network_server() and not players_ready.has(session_id):
		players_ready[session_id] = true
		if players_ready.size() == OnlineMatch.players.size():
			if OnlineMatch.match_state != OnlineMatch.MatchState.PLAYING:
				OnlineMatch.start_playing()
			start_game()

func start_game() -> void:
	if GameState.online_play:
		players = OnlineMatch.get_player_names_by_peer_id()
	else:
		players = {
			1: "Player1",
			2: "Player2",
		}
	
	game.game_start(players)

func stop_game() -> void:
	OnlineMatch.leave()
	
	players.clear()
	players_ready.clear()
	players_score.clear()
	
	game.game_stop()

func restart_game() -> void:
	stop_game()
	start_game()

func _on_Game_game_started() -> void:
	UI.hide_screen()
	UI.hide_all()
	UI.show_back_button()
	
	if not match_started:
		match_started = true
		music.play_random()

func _on_Game_player_dead(player_id: int) -> void:
	if GameState.online_play:
		var my_id = OnlineMatch.get_network_unique_id()
		if player_id == my_id:
			UI.show_message("You lose!")

func _on_Game_game_over(player_id: int) -> void:
	players_ready.clear()
	
	if not GameState.online_play:
		show_winner(players[player_id])
	elif OnlineMatch.is_network_server():
		if not players_score.has(player_id):
			players_score[player_id] = 1
		else:
			players_score[player_id] += 1
		
		var player_session_id = OnlineMatch.get_session_id(player_id)
		var is_match: bool = players_score[player_id] >= 5
		OnlineMatch.custom_rpc_sync(self, "show_winner", [players[player_id], player_session_id, players_score[player_id], is_match])
		
func update_wins_leaderboard() -> void:
	if not Online.nakama_session or Online.nakama_session.is_expired():
		# If our session has expired, then wait until a new session is setup.
		yield(Online, "session_changed")
	
	Online.nakama_client.write_leaderboard_record_async(Online.nakama_session, 'fish_game_wins', 1)

func show_winner(name: String, session_id: String = '', score: int = 0, is_match: bool = false) -> void:
	if is_match:
		UI.show_message(name + " WINS THE WHOLE MATCH!")
	else:
		UI.show_message(name + " wins this round!")
	
	yield(get_tree().create_timer(2.0), "timeout")
	if not game.game_started:
		return
	
	if GameState.online_play:
		if is_match:
			stop_game()
			if session_id == OnlineMatch.my_session_id:
				update_wins_leaderboard()
			UI.show_screen("MatchScreen")
		else:
			ready_screen.hide_match_id()
			ready_screen.reset_status("Waiting...")
			ready_screen.set_score(session_id, score)
			UI.show_screen("ReadyScreen")
	else:
		restart_game()

func _on_Music_song_finished(song) -> void:
	if not music.current_song.playing:
		music.play_random()
