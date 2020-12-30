extends Area2D

onready var ray_cast = $RayCast2D
onready var trail := $Trail

var vector := Vector2.ZERO
var start_position := Vector2.ZERO
var max_distance := 0.0

func _ready():
	trail.set_as_toplevel(true)
	trail.global_position = Vector2(0, 0)

func shoot(_start_position: Vector2, _vector: Vector2, _max_distance: float) -> void:
	start_position = _start_position
	vector = _vector
	max_distance = _max_distance
	
	global_position = _start_position
	trail.add_point(_start_position)
	
	# Advance one frame right away, to make it harder to shoot yourself.
	_physics_process(1.0 / 60.0)

func _physics_process(delta: float) -> void:
	if vector == Vector2.ZERO:
		return
	
	var increment = vector * delta
	ray_cast.cast_to = increment
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		global_position = ray_cast.get_collision_point()
		vector = Vector2.ZERO
	else:
		global_position += increment
	
	trail.add_point(global_position)
	while trail.get_point_count() > 5:
		trail.remove_point(0)
	
	if start_position.distance_to(global_position) >= max_distance:
		queue_free()

func _on_Projectile_body_entered(body: Node) -> void:
	queue_free()
