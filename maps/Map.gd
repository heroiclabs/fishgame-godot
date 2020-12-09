extends Node2D

const TILE_SIZE = Vector2(70, 70)

func map_start() -> void:
	get_tree().call_group("map_object", "map_object_start")

func map_stop() -> void:
	get_tree().call_group("map_object", "map_object_stop")

func get_map_rect() -> Rect2:
	var rect: Rect2
	for child in get_children():
		if child is TileMap:
			if rect == null:
				rect = child.get_used_rect()
			else:
				rect = rect.merge(child.get_used_rect())
	return Rect2(rect.position * TILE_SIZE, rect.size * TILE_SIZE)
