extends "res://main/Screen.gd"

var PeerStatus = preload("res://main/screens/PeerStatus.tscn");

onready var ready_button := $Panel/ReadyButton
onready var match_id_container := $Panel/MatchIDContainer
onready var match_id_label := $Panel/MatchIDContainer/MatchID
onready var status_container := $Panel/StatusContainer

signal ready_pressed ()

func _ready() -> void:
	clear_players()

	OnlineMatch.connect("player_joined", self, "_on_OnlineMatch_player_joined")
	OnlineMatch.connect("player_left", self, "_on_OnlineMatch_player_left")
	OnlineMatch.connect("match_ready", self, "_on_OnlineMatch_match_ready")
	OnlineMatch.connect("match_not_ready", self, "_on_OnlineMatch_match_not_ready")

func _show_screen(info: Dictionary = {}) -> void:
	var players: Dictionary = info.get("players", {})
	var match_id: String = info.get("match_id", '')
	var clear: bool = info.get("clear", false)

	if players.size() > 0 or clear:
		clear_players()

	for peer_id in players:
		add_player(peer_id, players[peer_id]['username'])

	if match_id:
		match_id_container.visible = true
		match_id_label.text = match_id
	else:
		match_id_container.visible = false

	ready_button.grab_focus()

func clear_players() -> void:
	for child in status_container.get_children():
		status_container.remove_child(child)
		child.queue_free()
	ready_button.disabled = true

func hide_match_id() -> void:
	match_id_container.visible = false

func add_player(peer_id: int, username: String) -> void:
	if not status_container.has_node(str(peer_id)):
		var status = PeerStatus.instance()
		status_container.add_child(status)
		status.initialize(username)
		status.name = str(peer_id)

func remove_player(peer_id: int) -> void:
	var status = status_container.get_node(str(peer_id))
	if status:
		status.queue_free()

func set_status(peer_id: int, status: String) -> void:
	var status_node = status_container.get_node(str(peer_id))
	if status_node:
		status_node.set_status(status)

func get_status(peer_id: int) -> String:
	var status_node = status_container.get_node(str(peer_id))
	if status_node:
		return status_node.status
	return ''

func reset_status(status: String) -> void:
	for child in status_container.get_children():
		child.set_status(status)

func set_score(peer_id: int, score: int) -> void:
	var status_node = status_container.get_node(str(peer_id))
	if status_node:
		status_node.set_score(score)

func set_ready_button_enabled(enabled: bool = true) -> void:
	ready_button.disabled = !enabled
	if enabled:
		ready_button.grab_focus()

func _on_ReadyButton_pressed() -> void:
	emit_signal("ready_pressed")

func _on_MatchCopyButton_pressed() -> void:
	OS.clipboard = match_id_label.text

#####
# OnlineMatch callbacks:
#####

func _on_OnlineMatch_player_joined(player) -> void:
	add_player(player.peer_id, player.username)

func _on_OnlineMatch_player_left(player) -> void:
	remove_player(player.peer_id)

func _on_OnlineMatch_match_ready(_players: Dictionary) -> void:
	set_ready_button_enabled(true)

func _on_OnlineMatch_match_not_ready() -> void:
	set_ready_button_enabled(false)
