extends Node

# Variables for developers to customize.
var min_players := 2
var max_players := 4
var ice_servers = [{ "urls": ["stun:stun.l.google.com:19302"] }]
var nakama_socket: NakamaSocket setget set_nakama_socket

# Nakama variables:
var my_session_id: String setget _set_readonly_variable, get_my_session_id
var match_id: String setget _set_readonly_variable, get_match_id
var matchmaker_ticket: String setget _set_readonly_variable, get_matchmaker_ticket

# WebRTC variables:
var _webrtc_multiplayer: WebRTCMultiplayer
var _webrtc_peers: Dictionary
var _webrtc_peers_connected: Dictionary

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
var match_state : int = MatchState.LOBBY setget _set_readonly_variable, get_match_state

enum MatchMode {
	NONE = 0,
	CREATE = 1,
	JOIN = 2,
	MATCHMAKER = 3,
}
var match_mode : int = MatchMode.NONE setget _set_readonly_variable, get_match_mode

enum PlayerStatus {
	CONNECTING = 0,
	CONNECTED = 1,
}

enum MatchOpCode {
	WEBRTC_PEER_METHOD = 9001,
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

func _set_readonly_variable(value) -> void:
	pass

func set_nakama_socket(_nakama_socket: NakamaSocket) -> void:
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

func _nakama_socket_required() -> bool:
	if not nakama_socket:
		push_error("NakamaWebRTC: Cannot perform operation without nakama_socket")
		emit_signal("error", "No connection to server")
		return true
	return false

func create_match():
	if _nakama_socket_required():
		return
	
	leave()
	match_mode = MatchMode.CREATE

	var data = yield(nakama_socket.create_match_async(), "completed")
	if data.is_exception():
		leave()
		emit_signal("error", "Failed to create match: " + str(data.get_exception().message))
	else:
		_on_nakama_match_created(data)

func join_match(_match_id: String):
	if _nakama_socket_required():
		return
	
	leave()
	match_mode = MatchMode.JOIN
	
	var data = yield(nakama_socket.join_match_async(_match_id), "completed")
	if data.is_exception():
		leave()
		emit_signal("error", "Unable to join match")
	else:
		_on_nakama_match_join(data)

func start_matchmaking(data: Dictionary = {}):
	if _nakama_socket_required():
		return
	
	leave()
	match_mode = MatchMode.MATCHMAKER
	
	if data.has('min_count'):
		data['min_count'] = max(min_players, data['min_count'])
	else:
		data['min_count'] = min_players
	
	if data.has('max_count'):
		data['max_count'] = min(max_players, data['max_count'])
	else:
		data['max_count'] = max_players
	
	match_state = MatchState.MATCHING
	var result = yield(nakama_socket.add_matchmaker_async(data.get('query', '*'), data['min_count'], data['max_count'], data.get('string_properties', {}), data.get('numeric_properties', {})), 'completed')
	if result.is_exception():
		leave()
		emit_signal("error", "Unable to join match making pool")
	else:
		matchmaker_ticket = result.ticket

func start_playing():
	assert(match_state == MatchState.READY)
	match_state = MatchState.PLAYING

func leave(close_socket = false):
	# WebRTC disconnect.
	if _webrtc_multiplayer:
		_webrtc_multiplayer.close()
		get_tree().set_network_peer(null)
	
	# Nakama disconnect.
	if nakama_socket:
		if match_id:
			yield(nakama_socket.leave_match_async(match_id), 'completed')
		elif matchmaker_ticket:
			yield(nakama_socket.remove_matchmaker_async(matchmaker_ticket), 'completed')
		if close_socket:
			nakama_socket.close()
			self.nakama_socket = null
	
	# Initialize all the variables to their default state.
	my_session_id = ''
	match_id = ''
	matchmaker_ticket = ''
	_create__webrtc_multiplayer()
	_webrtc_peers = {}
	_webrtc_peers_connected = {}
	players = {}
	_next_peer_id = 1
	match_state = MatchState.LOBBY
	match_mode = MatchMode.NONE

func _create__webrtc_multiplayer():
	if _webrtc_multiplayer:
		_webrtc_multiplayer.disconnect("peer_connected", self, "_on_webrtc_peer_connected")
		_webrtc_multiplayer.disconnect("peer_disconnected", self, "_on_webrtc_peer_disconnected")
	
	_webrtc_multiplayer = WebRTCMultiplayer.new()
	_webrtc_multiplayer.connect("peer_connected", self, "_on_webrtc_peer_connected")
	_webrtc_multiplayer.connect("peer_disconnected", self, "_on_webrtc_peer_disconnected")

func get_my_session_id():
	return my_session_id

func get_match_id():
	return match_id

func get_matchmaker_ticket():
	return matchmaker_ticket

func get_match_mode():
	return match_mode

func get_match_state():
	return match_state

func get_session_id(peer_id: int):
	for session_id in players:
		if players[session_id]['peer_id'] == peer_id:
			return session_id
	return null

func get_player_names_by_peer_id():
	var result = {}
	for session_id in players:
		result[players[session_id]['peer_id']] = players[session_id]['username']
	return result

func _on_nakama_error(data):
	print ("ERROR:")
	print(data)
	leave()
	emit_signal("error", "Websocket connection error")

func _on_nakama_closed():
	leave()
	emit_signal("disconnected")

func _on_nakama_match_created(data: NakamaRTAPI.Match) -> void:
	match_id = data.match_id
	my_session_id = data.self_user.session_id
	var my_player = Player.from_presence(data.self_user, 1)
	players[my_session_id] = my_player
	_next_peer_id = 2
	
	_webrtc_multiplayer.initialize(1)
	get_tree().set_network_peer(_webrtc_multiplayer)
	
	emit_signal("match_created", match_id)
	emit_signal("player_joined", my_player)
	emit_signal("player_status_changed", my_player, PlayerStatus.CONNECTED)

func _on_nakama_match_presence(data: NakamaRTAPI.MatchPresenceEvent):
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
				
				_webrtc_connect_peer(new_player)
				
				# Tell this player (and the others) about all the players peer ids.
				nakama_socket.send_match_state_async(match_id, MatchOpCode.JOIN_SUCCESS, JSON.print({
					players = serialize_players(players),
				}))
			else:
				# Tell this player that we're full up!
				nakama_socket.send_match_state_async(match_id, MatchOpCode.JOIN_ERROR, JSON.print({
					target = u['session_id'],
					reason = 'Sorry! The match is full.,',
				}))
		elif match_mode == MatchMode.MATCHMAKER:
			emit_signal("player_joined", players[u.session_id])
			_webrtc_connect_peer(players[u.session_id])
	
	for u in data.leaves:
		if u.session_id == my_session_id:
			continue
		
		var player = players[u.session_id]
		_webrtc_disconnect_peer(player)
		
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

func _on_nakama_match_join(data: NakamaRTAPI.Match):
	match_id = data.match_id
	my_session_id = data.self_user.session_id
	
	if match_mode == MatchMode.JOIN:
		emit_signal("match_joined", match_id)
	elif match_mode == MatchMode.MATCHMAKER:
		for u in data.presences:
			if u.session_id == my_session_id:
					continue
			_webrtc_connect_peer(players[u.session_id])

func _on_nakama_matchmaker_matched(data: NakamaRTAPI.MatchmakerMatched):
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
	
	# Initialize multiplayer using our peer id
	_webrtc_multiplayer.initialize(players[my_session_id].peer_id)
	get_tree().set_network_peer(_webrtc_multiplayer)
	
	emit_signal("matchmaker_matched", players)
	emit_signal("player_status_changed", players[my_session_id], PlayerStatus.CONNECTED)
	
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
	if data.op_code == MatchOpCode.WEBRTC_PEER_METHOD:
		if content['target'] == my_session_id:
			var session_id = data.presence.session_id
			var webrtc_peer = _webrtc_peers[session_id]
			match content['method']:
				'set_remote_description':
					webrtc_peer.set_remote_description(content['type'], content['sdp'])
				
				'add_ice_candidate':
					webrtc_peer.add_ice_candidate(content['media'], content['index'], content['name'])
				
				'reconnect':
					_webrtc_multiplayer.remove_peer(players[session_id]['peer_id'])
					_webrtc_reconnect_peer(players[session_id])
	if data.op_code == MatchOpCode.JOIN_SUCCESS && match_mode == MatchMode.JOIN:
		var content_players = unserialize_players(content['players'])
		for session_id in content_players:
			if not players.has(session_id):
				players[session_id] = content_players[session_id]
				_webrtc_connect_peer(players[session_id])
				emit_signal("player_joined", players[session_id])
				if session_id == my_session_id:
					_webrtc_multiplayer.initialize(players[session_id].peer_id)
					get_tree().set_network_peer(_webrtc_multiplayer)
					
					emit_signal("player_status_changed", players[session_id], PlayerStatus.CONNECTED)
	if data.op_code == MatchOpCode.JOIN_ERROR:
		if content['target'] == my_session_id:
			leave()
			emit_signal("error", content['reason'])

func _webrtc_connect_peer(player: Player):
	# Don't add the same peer twice!
	if _webrtc_peers.has(player.session_id):
		return
	
	# If the match was previously ready, then we need to switch back to not ready.
	if match_state == MatchState.READY:
		emit_signal("match_not_ready")
	
	# If we're already PLAYING, then this is a reconnect attempt, so don't mess with the state.
	# Otherwise, change state to CONNECTING because we're trying to connect to all peers.
	if match_state != MatchState.PLAYING:
		match_state = MatchState.CONNECTING
	
	var webrtc_peer := WebRTCPeerConnection.new()
	webrtc_peer.initialize({
		"iceServers": ice_servers,
	})
	webrtc_peer.connect("session_description_created", self, "_on_webrtc_peer_session_description_created", [player.session_id])
	webrtc_peer.connect("ice_candidate_created", self, "_on_webrtc_peer_ice_candidate_created", [player.session_id])
	
	_webrtc_peers[player.session_id] = webrtc_peer
	
	#get_tree().multiplayer._del_peer(u['peer_id'])
	_webrtc_multiplayer.add_peer(webrtc_peer, player.peer_id)
	
	if my_session_id.casecmp_to(player.session_id) < 0:
		var result = webrtc_peer.create_offer()
		if result != OK:
			emit_signal("error", "Unable to create WebRTC offer")

func _webrtc_disconnect_peer(player: Player):
	var webrtc_peer = _webrtc_peers[player.session_id]
	webrtc_peer.close()
	_webrtc_peers.erase(player.session_id)
	_webrtc_peers_connected.erase(player.session_id)

func _webrtc_reconnect_peer(player: Player):
	var old_webrtc_peer = _webrtc_peers[player.session_id]
	if old_webrtc_peer:
		old_webrtc_peer.close()
	
	_webrtc_peers_connected.erase(player.session_id)
	_webrtc_peers.erase(player.session_id)
	
	print ("Starting WebRTC reconnect...")
	
	_webrtc_connect_peer(player)
	
	emit_signal("player_status_changed", player, PlayerStatus.CONNECTING)
	
	if match_state == MatchState.READY:
		match_state = MatchState.CONNECTING
		emit_signal("match_not_ready")

func _on_webrtc_peer_session_description_created(type : String, sdp : String, session_id : String):
	var webrtc_peer = _webrtc_peers[session_id]
	webrtc_peer.set_local_description(type, sdp)
	
	# Send this data to the peer so they can call call .set_remote_description().
	nakama_socket.send_match_state_async(match_id, MatchOpCode.WEBRTC_PEER_METHOD, JSON.print({
		method = "set_remote_description",
		target = session_id,
		type = type,
		sdp = sdp,
	}))

func _on_webrtc_peer_ice_candidate_created(media : String, index : int, name : String, session_id : String):
	# Send this data to the peer so they can call .add_ice_candidate()
	nakama_socket.send_match_state_async(match_id, MatchOpCode.WEBRTC_PEER_METHOD, JSON.print({
		method = "add_ice_candidate",
		target = session_id,
		media = media,
		index = index,
		name = name,
	}))

func _on_webrtc_peer_connected(peer_id: int):
	for session_id in players:
		if players[session_id]['peer_id'] == peer_id:
			_webrtc_peers_connected[session_id] = true
			emit_signal("player_status_changed", players[session_id], PlayerStatus.CONNECTED)

	# We have a WebRTC peer for each connection to another player, so we'll have one less than
	# the number of players (ie. no peer connection to ourselves).
	if _webrtc_peers_connected.size() == players.size() - 1:
		if players.size() >= min_players:
			# All our peers are good, so we can assume RPC will work now.
			match_state = MatchState.READY;
			emit_signal("match_ready", players)
		else:
			match_state = MatchState.WAITING_FOR_ENOUGH_PLAYERS

func _on_webrtc_peer_disconnected(peer_id: int):
	print ("WebRTC peer disconnected: " + str(peer_id))
	
	for session_id in players:
		if players[session_id]['peer_id'] == peer_id:
			# We initiate the reconnection process from only one side (the offer side).
			if my_session_id.casecmp_to(session_id) < 0:
				# Tell the remote peer to restart their connection.
				nakama_socket.send_match_state_async(match_id, MatchOpCode.WEBRTC_PEER_METHOD, JSON.print({
					method = "reconnect",
					target = session_id,
				}))
			
				# Initiate reconnect on our end now (the other end will do it when they receive
				# the message above).
				_webrtc_reconnect_peer(players[session_id])
