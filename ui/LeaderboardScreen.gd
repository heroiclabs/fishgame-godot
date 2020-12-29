extends Control

var LeaderboardRecord = preload("res://ui/LeaderboardRecord.tscn")

onready var record_container = $PanelContainer/VBoxContainer/Panel/ScrollContainer/VBoxContainer

func _ready() -> void:
	clear_records()

func clear_records() -> void:
	for child in record_container.get_children():
		record_container.remove_child(child)
		child.queue_free()

func initialize() -> void:
	UI.hide_message()
	
	var result: NakamaAPI.ApiLeaderboardRecordList = yield(Online.nakama_client.list_leaderboard_records_async(Online.nakama_session, 'fish_game_wins'), "completed")
	if result.is_exception():
		UI.show_message("Unable to retrieve leaderboard")
		UI.show_screen("MatchScreen")
	
	clear_records()
	for record in result.records:
		var record_node = LeaderboardRecord.instance()
		record_container.add_child(record_node)
		record_node.setup(record.username, record.score)
