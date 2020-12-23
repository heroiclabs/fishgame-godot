extends Pickup

onready var animation_player = $AnimationPlayer
onready var sounds = $Sounds

func _get_custom_rpc_methods() -> Array:
	return ._get_custom_rpc_methods() + [
		'_do_use',
	]

func use() -> void:
	if animation_player.is_playing():
		return
	
	if not GameState.online_play:
		_do_use()
	else:
		OnlineMatch.custom_rpc_sync(self, '_do_use')

func _on_throw() -> void:
	if animation_player.is_playing() and animation_player.current_animation != "Reset":
		animation_player.play("Reset")

func _do_use() -> void:
	animation_player.play("Swing")
	sounds.play("Swing")
