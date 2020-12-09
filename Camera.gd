extends Camera2D

export (NodePath) var player_container_path
export (float, 0.1, 0.5) var zoom_offset := 0.2

export (float) var custom_smoothing := 2.0

var player_container: Node2D

func _physics_process(delta: float) -> void:
	update_position_and_zoom()

func _center_position(pos: Vector2) -> Vector2:
	return pos - Vector2(0, 35)

func update_position_and_zoom(custom_smoothing_enabled: bool = true) -> void:
	if not player_container_path:
		return
	
	if not player_container:
		player_container = get_node(player_container_path)
		if not player_container:
			return
	
	var count := player_container.get_child_count()
	if count == 0:
		return
	
	var camera_rect := Rect2(_center_position(player_container.get_child(0).global_position), Vector2())
	for index in range(0, count):
		if index == 0:
			continue
		camera_rect = camera_rect.expand(_center_position(player_container.get_child(index).global_position))
	
	var viewport_rect = get_viewport_rect().size
	
	# If the camera_rect is shorter than the viewpoirt, ensure that it's 
	# positioned so that the bottom edge is just below the lowest character.
	var min_height = viewport_rect.y * (1.0 - zoom_offset)
	if camera_rect.size.y < min_height:
		var delta_height = min_height - camera_rect.size.y
		camera_rect.position.y -= delta_height
		camera_rect.size.y += delta_height
	
	var desired_global_position = calculate_center(camera_rect)
	var desired_zoom = calculate_zoom(camera_rect, get_viewport_rect().size)
	
	if custom_smoothing_enabled:
		var delta = get_physics_process_delta_time()
		global_position += (desired_global_position - global_position) * custom_smoothing * delta
		zoom += (desired_zoom - zoom) * custom_smoothing * delta
	else:
		global_position = desired_global_position
		zoom = desired_zoom

func calculate_center(camera_rect: Rect2) -> Vector2:
	return Vector2(
		camera_rect.position.x + (camera_rect.size.x / 2),
		camera_rect.position.y + (camera_rect.size.y / 2))

func calculate_zoom(camera_rect: Rect2, viewport_size: Vector2) -> Vector2:
	var zoom = max(
		max(1.0, (camera_rect.size.x / viewport_size.x) + zoom_offset),
		max(1.0, (camera_rect.size.y / viewport_size.y) + zoom_offset))
	return Vector2(zoom, zoom)
	
