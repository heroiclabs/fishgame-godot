extends Node

# For developers to set from the outside, for example:
#   OnlineMatch.max_players = 8
#   OnlineMatch.client_version = 'v1.2'
var min_players := 2
var max_players := 4
var client_version := 'dev'

# Nakama variables:
var nakama_socket: NakamaSocket setget _set_readonly_variable
var my_session_id: String setget _set_readonly_variable, get_my_session_id
var match_id: String setget _set_readonly_variable, get_match_id
var matchmaker_ticket: String setget _set_readonly_variable, get_matchmaker_ticket

# RPC variables:
var my_peer_id: int setget _set_readonly_variable

var players: Dictionary
var _next_peer_id: int

enum MatchState {
	LOBBY = 0,
	MATCHING = 1,
	CONNECTING = 2,
	WAITING_FOR_ENOUGH_PLAYERS = 3,
	READY = 4,
	PLAYING = 5,
}
var match_state: int = MatchState.LOBBY setget _set_readonly_variable, get_match_state

enum MatchMode {
	NONE = 0,
	CREATE = 1,
	JOIN = 2,
	MATCHMAKER = 3,
}
var match_mode: int = MatchMode.NONE setget _set_readonly_variable, get_match_mode

enum PlayerStatus {
	CONNECTING = 0,
	CONNECTED = 1,
}

enum MatchOpCode {
	CUSTOM_RPC = 9001,
	JOIN_SUCCESS = 9002,
	JOIN_ERROR = 9003,
}

signal error (message)
signal disconnected ()

signal match_created (match_id)
signal match_joined (match_id)
signal matchmaker_matched (players)

signal player_joined (player)
signal player_left (player)
signal player_status_changed (player, status)

signal match_ready (players)
signal match_not_ready ()

class Player:
	var session_id: String
	var peer_id: int
	var username: String
	
	func _init(_session_id: String, _username: String, _peer_id: int) -> void:
		session_id = _session_id
		username = _username
		peer_id = _peer_id
	
	static func from_presence(presence: NakamaRTAPI.UserPresence, _peer_id: int) -> Player:
		return Player.new(presence.session_id, presence.username, _peer_id)
	
	static func from_dict(data: Dictionary) -> Player:
		return Player.new(data['session_id'], data['username'], int(data['peer_id']))
	
	func to_dict() -> Dictionary:
		return {
			session_id = session_id,
			username = username,
			peer_id = peer_id,
		}

static func serialize_players(_players: Dictionary) -> Dictionary:
	var result := {}
	for key in _players:
		result[key] = _players[key].to_dict()
	return result

static func unserialize_players(_players: Dictionary) -> Dictionary:
	var result := {}
	for key in _players:
		result[key] = Player.from_dict(_players[key])
	return result

func _set_readonly_variable(_value) -> void:
	pass

func _set_nakama_socket(_nakama_socket: NakamaSocket) -> void:
	if nakama_socket == _nakama_socket:
		return
	
	if nakama_socket:
		nakama_socket.disconnect("closed", self, "_on_nakama_closed")
		nakama_socket.disconnect("received_error", self, "_on_nakama_error")
		nakama_socket.disconnect("received_match_state", self, "_on_nakama_match_state")
		nakama_socket.disconnect("received_match_presence", self, "_on_nakama_match_presence")
		nakama_socket.disconnect("received_matchmaker_matched", self, "_on_nakama_matchmaker_matched")
	
	nakama_socket = _nakama_socket
	if nakama_socket:
		nakama_socket.connect("closed", self, "_on_nakama_closed")
		nakama_socket.connect("received_error", self, "_on_nakama_error")
		nakama_socket.connect("received_match_state", self, "_on_nakama_match_state")
		nakama_socket.connect("received_match_presence", self, "_on_nakama_match_presence")
		nakama_socket.connect("received_matchmaker_matched", self, "_on_nakama_matchmaker_matched")

func create_match(_nakama_socket: NakamaSocket) -> void:
	leave()
	_set_nakama_socket(_nakama_socket)
	match_mode = MatchMode.CREATE

	var data = yield(nakama_socket.create_match_async(), "completed")
	if data.is_exception():
		leave()
		emit_signal("error", "Failed to create match: " + str(data.get_exception().message))
	else:
		_on_nakama_match_created(data)

func join_match(_nakama_socket: NakamaSocket, _match_id: String) -> void:
	leave()
	_set_nakama_socket(_nakama_socket)
	match_mode = MatchMode.JOIN
	
	var data = yield(nakama_socket.join_match_async(_match_id), "completed")
	if data.is_exception():
		leave()
		emit_signal("error", "Unable to join match")
	else:
		_on_nakama_match_join(data)

func start_matchmaking(_nakama_socket: NakamaSocket, data: Dictionary = {}) -> void:
	leave()
	_set_nakama_socket(_nakama_socket)
	match_mode = MatchMode.MATCHMAKER
	
	if data.has('min_count'):
		data['min_count'] = max(min_players, data['min_count'])
	else:
		data['min_count'] = min_players
	
	if data.has('max_count'):
		data['max_count'] = min(max_players, data['max_count'])
	else:
		data['max_count'] = max_players
	
	if client_version != '':
		if not data.has('string_properties'):
			data['string_properties'] = {}
		data['string_properties']['client_version'] = client_version
		
		var query = '+properties.client_version:' + client_version
		if data.has('query'):
			data['query'] += ' ' + query
		else:
			data['query'] = query
	
	match_state = MatchState.MATCHING
	var result = yield(nakama_socket.add_matchmaker_async(data.get('query', '*'), data['min_count'], data['max_count'], data.get('string_properties', {}), data.get('numeric_properties', {})), 'completed')
	if result.is_exception():
		leave()
		emit_signal("error", "Unable to join match making pool")
	else:
		matchmaker_ticket = result.ticket

func start_playing() -> void:
	assert(match_state == MatchState.READY)
	match_state = MatchState.PLAYING

func leave(close_socket: bool = false) -> void:
	# Nakama disconnect.
	if nakama_socket:
		if match_id:
			yield(nakama_socket.leave_match_async(match_id), 'completed')
		elif matchmaker_ticket:
			yield(nakama_socket.remove_matchmaker_async(matchmaker_ticket), 'completed')
		if close_socket:
			nakama_socket.close()
			_set_nakama_socket(null)
	
	# Initialize all the variables to their default state.
	my_session_id = ''
	match_id = ''
	matchmaker_ticket = ''
	players = {}
	my_peer_id = 0
	_next_peer_id = 1
	match_state = MatchState.LOBBY
	match_mode = MatchMode.NONE

func get_my_session_id() -> String:
	return my_session_id

func get_match_id() -> String:
	return match_id

func get_matchmaker_ticket() -> String:
	return matchmaker_ticket

func get_match_mode() -> int:
	return match_mode

func get_match_state() -> int:
	return match_state

func get_session_id(peer_id: int):
	for session_id in players:
		if players[session_id]['peer_id'] == peer_id:
			return session_id
	return null

func get_player_names_by_peer_id() -> Dictionary:
	var result = {}
	for session_id in players:
		result[players[session_id]['peer_id']] = players[session_id]['username']
	return result

func get_network_unique_id() -> int:
	return my_peer_id

func is_network_server() -> bool:
	return my_peer_id == 1

func is_network_master_for_node(node: Node) -> bool:
	return node.get_network_master() == my_peer_id

func custom_rpc(node: Node, method: String, args: Array = []) -> void:
	custom_rpc_id(node, 0, method, args)

func custom_rpc_id(node: Node, id: int, method: String, args: Array = []) -> void:
	assert(match_state == MatchState.READY or match_state == MatchState.PLAYING)
	assert(match_id != '')
	assert(nakama_socket != null)
	
	if nakama_socket:
		nakama_socket.send_match_state_async(match_id, MatchOpCode.CUSTOM_RPC, JSON.print({
			peer_id = id,
			node_path = str(node.get_path()),
			method = method,
			args = var2str(args),
		}))

func custom_rpc_sync(node: Node, method: String, args: Array = []) -> void:
	node.callv(method, args)
	custom_rpc(node, method, args)

func custom_rpc_id_sync(node: Node, id: int, method: String, args: Array = []) -> void:
	if my_peer_id == id:
		node.callv(method, args)
	else:
		custom_rpc_id(node, id, method, args)

func _on_nakama_error(data) -> void:
	print ("ERROR:")
	print(data)
	leave()
	emit_signal("error", "Websocket connection error")

func _on_nakama_closed() -> void:
	leave()
	emit_signal("disconnected")

func _on_nakama_match_created(data: NakamaRTAPI.Match) -> void:
	match_id = data.match_id
	my_session_id = data.self_user.session_id
	var my_player = Player.from_presence(data.self_user, 1)
	players[my_session_id] = my_player
	my_peer_id = 1
	_next_peer_id = 2
	
	emit_signal("match_created", match_id)
	emit_signal("player_joined", my_player)
	emit_signal("player_status_changed", my_player, PlayerStatus.CONNECTED)

func _check_enough_players() -> void:
	if players.size() >= min_players:
		match_state = MatchState.READY;
		emit_signal("match_ready", players)
	else:
		match_state = MatchState.WAITING_FOR_ENOUGH_PLAYERS

func _on_nakama_match_presence(data: NakamaRTAPI.MatchPresenceEvent) -> void:
	for u in data.joins:
		if u.session_id == my_session_id:
			continue
		
		if match_mode == MatchMode.CREATE:
			if match_state == MatchState.PLAYING:
				# Tell this player that we've already started
				nakama_socket.send_match_state_async(match_id, MatchOpCode.JOIN_ERROR, JSON.print({
					target = u['session_id'],
					reason = 'Sorry! The match has already begun.',
				}))
			
			if players.size() < max_players:
				var new_player = Player.from_presence(u, _next_peer_id)
				_next_peer_id += 1
				players[u.session_id] = new_player
				emit_signal("player_joined", new_player)
				emit_signal("player_status_changed", new_player, PlayerStatus.CONNECTED)
				
				# Tell this player (and the others) about all the players peer ids.
				nakama_socket.send_match_state_async(match_id, MatchOpCode.JOIN_SUCCESS, JSON.print({
					players = serialize_players(players),
					client_version = client_version,
				}))
				
				_check_enough_players()
			else:
				# Tell this player that we're full up!
				nakama_socket.send_match_state_async(match_id, MatchOpCode.JOIN_ERROR, JSON.print({
					target = u['session_id'],
					reason = 'Sorry! The match is full.,',
				}))
		elif match_mode == MatchMode.MATCHMAKER:
			emit_signal("player_joined", players[u.session_id])
	
	for u in data.leaves:
		if u.session_id == my_session_id:
			continue
		if not players.has(u.session_id):
			continue
		
		var player = players[u.session_id]
		
		# If the host disconnects, this is the end!
		if player.peer_id == 1:
			leave()
			emit_signal("error", "Host has disconnected")
		else:
			players.erase(u.session_id)
			emit_signal("player_left", player)
			
			if players.size() < min_players:
				# If state was previously ready, but this brings us below the minimum players,
				# then we aren't ready anymore.
				if match_state == MatchState.READY || match_state == MatchState.PLAYING:
					emit_signal("match_not_ready")

func _on_nakama_match_join(data: NakamaRTAPI.Match) -> void:
	match_id = data.match_id
	my_session_id = data.self_user.session_id
	
	if match_mode == MatchMode.JOIN:
		emit_signal("match_joined", match_id)
	elif match_mode == MatchMode.MATCHMAKER:
		_check_enough_players()

func _on_nakama_matchmaker_matched(data: NakamaRTAPI.MatchmakerMatched) -> void:
	if data.is_exception():
		leave()
		emit_signal("error", "Matchmaker error")
		return
	
	my_session_id = data.self_user.presence.session_id
	
	# Use the list of users to assign peer ids.
	for u in data.users:
		players[u.presence.session_id] = Player.from_presence(u.presence, 0)
	var session_ids = players.keys();
	session_ids.sort()
	for session_id in session_ids:
		players[session_id].peer_id = _next_peer_id
		_next_peer_id += 1
	
	my_peer_id = players[my_session_id].peer_id
	
	emit_signal("matchmaker_matched", players)
	for session_id in players:
		emit_signal("player_status_changed", players[session_id], PlayerStatus.CONNECTED)
	
	# Join the match.
	var result = yield(nakama_socket.join_matched_async(data), "completed")
	if result.is_exception():
		leave()
		emit_signal("error", "Unable to join match")
	else:
		_on_nakama_match_join(result)

func _on_nakama_match_state(data: NakamaRTAPI.MatchData):
	var json_result = JSON.parse(data.data)
	if json_result.error != OK:
		return
		
	var content = json_result.result
	if data.op_code == MatchOpCode.CUSTOM_RPC:
		if content['peer_id'] == 0 or content['peer_id'] == my_peer_id:
			var node = get_node(content['node_path'])
			if not node or not is_instance_valid(node) or node.is_queued_for_deletion():
				push_warning("Custom RPC: Cannot find node at path: %s" % [content['node_path']])
				return
			
			if not node.has_method('_get_custom_rpc_methods') or not node._get_custom_rpc_methods().has(content['method']):
				push_error("Custom RPC: Method %s is not returned by %s._get_custom_rpc_methods()" % [content['method'], content['node_path']])
				return
			
			node.callv(content['method'], str2var(content['args']))
	if data.op_code == MatchOpCode.JOIN_SUCCESS && match_mode == MatchMode.JOIN:
		var host_client_version = content.get('client_version', '')
		if client_version != host_client_version:
			leave()
			emit_signal("error", "Client version doesn't match host")
			return
		
		var content_players = unserialize_players(content['players'])
		my_peer_id = content_players[my_session_id].peer_id
		for session_id in content_players:
			if not players.has(session_id):
				players[session_id] = content_players[session_id]
				emit_signal("player_joined", players[session_id])
				emit_signal("player_status_changed", players[session_id], PlayerStatus.CONNECTED)
		_check_enough_players()
	if data.op_code == MatchOpCode.JOIN_ERROR:
		if content['target'] == my_session_id:
			leave()
			emit_signal("error", content['reason'])
