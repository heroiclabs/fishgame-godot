extends Control

onready var matchmaker_player_count_control := $PanelContainer/VBoxContainer/MatchPanel/SpinBox
onready var join_match_id_control := $PanelContainer/VBoxContainer/JoinPanel/LineEdit

func _ready() -> void:
	$PanelContainer/VBoxContainer/MatchPanel/MatchButton.connect("pressed", self, "_on_match_button_pressed", [OnlineMatch.MatchMode.MATCHMAKER])
	$PanelContainer/VBoxContainer/CreatePanel/CreateButton.connect("pressed", self, "_on_match_button_pressed", [OnlineMatch.MatchMode.CREATE])
	$PanelContainer/VBoxContainer/JoinPanel/JoinButton.connect("pressed", self, "_on_match_button_pressed", [OnlineMatch.MatchMode.JOIN])

func initialize() -> void:
	matchmaker_player_count_control.value = 2
	join_match_id_control.text = ''

func _on_match_button_pressed(mode) -> void:
	# If our session has expired, show the ConnectionScreen again.
	if Online.nakama_session == null or Online.nakama_session.is_expired():
		UI.show_message("Login session has expired")
		UI.show_screen("ConnectionScreen")
		return
	
	# Connect socket to realtime Nakama API if not connected.
	if not Online.is_nakama_socket_connected():
		Online.connect_nakama_socket()
		yield(Online, "socket_connected")
	
	# Call internal method to do actual work.
	match mode:
		OnlineMatch.MatchMode.MATCHMAKER:
			_start_matchmaking()
		OnlineMatch.MatchMode.CREATE:
			_create_match()
		OnlineMatch.MatchMode.JOIN:
			_join_match()

func _start_matchmaking() -> void:
	var min_players = matchmaker_player_count_control.value
	
	UI.hide_screen()
	UI.show_message("Looking for match...")
	UI.show_back_button()
	
	var data = {
		min_count = min_players,
		string_properties = {
			game = "fish_game",
		},
		query = "+properties.game:fish_game",
	}
	
	OnlineMatch.start_matchmaking(Online.nakama_socket, data)

func _create_match() -> void:
	OnlineMatch.create_match(Online.nakama_socket)

func _join_match() -> void:
	var match_id = join_match_id_control.text
	if not match_id:
		UI.show_message("Need to paste Match ID to join")
		return
	
	OnlineMatch.join_match(Online.nakama_socket, match_id)

func _on_PasteButton_pressed() -> void:
	join_match_id_control.text = OS.clipboard
