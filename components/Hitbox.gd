extends Area2D

export (bool) var disabled := false setget set_disabled

func _ready() -> void:
	_update_disabled()

func set_disabled(_disabled: bool) -> void:
	if disabled != _disabled:
		disabled = _disabled
		_update_disabled()

func _update_disabled() -> void:
	for child in get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.set_deferred("disabled", disabled)

func _on_body_entered(body: Node) -> void:
	if not disabled and body.has_method('hurt'):
		if not GameState.online_play or OnlineMatch.is_network_master_for_node(body):
			body.hurt(self)
