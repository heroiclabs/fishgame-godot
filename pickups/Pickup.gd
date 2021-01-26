extends KinematicBody2D
class_name Pickup

onready var held_position: Position2D = $HeldPosition
onready var original_parent: Node2D = get_parent()
onready var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
onready var linear_damp: float = float(ProjectSettings.get_setting("physics/2d/default_linear_damp"))
onready var angular_damp: float = float(ProjectSettings.get_setting("physics/2d/default_angular_damp"))

enum PickupPosition {
	FRONT,
	BACK,
}

export (PickupPosition) var pickup_position = PickupPosition.FRONT

enum PickupState {
	FREE = 0,
	PICKED_UP,
	WORN,
	THROWING,
	THROWN,
}

# Minimum thresholds in order to sleep physics on this body.
const MIN_LINEAR_VELOCITY := 10.0
const MIN_ANGULAR_VELOCITY := 10.0

var player: Node2D
var pickup_state: int = PickupState.FREE
var throw_position := Vector2.ZERO

var sleeping := false
var linear_velocity := Vector2.ZERO
var angular_velocity := 0.0
var bounce := 0.1

signal picked_up()

func _ready():
	pass

func _get_custom_rpc_methods() -> Array:
	return [
		'_do_physics_finished',
	]

func can_pickup() -> bool:
	return pickup_state == PickupState.FREE or pickup_state == PickupState.THROWN

func pickup(_player: Node2D) -> void:
	pickup_state = PickupState.PICKED_UP
	player = _player
	rotation = 0.0
	sleeping = true
	emit_signal("picked_up")

func _on_throw() -> void:
	# This allows the pickup to do something special just before it's thrown.
	pass

func _on_throw_finished() -> void:
	# This allows the pickup to do something special once its stopped moving.
	pass

func throw(_throw_position: Vector2, _throw_vector: Vector2, _throw_torque: float) -> void:
	_on_throw()
	
	pickup_state = PickupState.THROWING
	player = null
	
	throw_position = _throw_position
	linear_velocity = _throw_vector
	angular_velocity = _throw_torque
	
	sleeping = false

func use() -> void:
	# Implement this in child classes.
	pass

func _physics_process(delta: float) -> void:
	if sleeping:
		return
	if pickup_state == PickupState.PICKED_UP or pickup_state == PickupState.WORN:
		return
	
	if pickup_state == PickupState.THROWING:
		global_transform = Transform2D(0.0, throw_position)
		pickup_state = PickupState.THROWN
	
	# Apply gravity.
	linear_velocity += (Vector2.DOWN * gravity * delta)
	
	# Apply linear damp.
	var ld := 1.0 - (linear_damp * delta)
	if ld < 0:
		ld = 0.0
	linear_velocity *= ld
	
	# Apply angular damp.
	var ad := 1.0 - (angular_damp * delta)
	if ad < 0:
		ad = 0.0
	angular_velocity *= ad
	
	# Rotate/move object and detect collisions.
	global_rotation += (angular_velocity * delta)
	var collision: KinematicCollision2D = move_and_collide(linear_velocity * delta)
	
	# Bounce the object if it collides.
	if collision:
		#linear_velocity = collision.normal * collision.remainder.length()
		linear_velocity = collision.normal * (linear_velocity.length() * bounce)
		move_and_collide(collision.normal * collision.remainder.length())
	
	# Sleep the object if it gets below certain linear/angular velocity thresholds.
	if not GameState.online_play or OnlineMatch.is_network_master_for_node(self):
		if linear_velocity.length() < MIN_LINEAR_VELOCITY and angular_velocity < MIN_ANGULAR_VELOCITY:
			if GameState.online_play:
				OnlineMatch.custom_rpc_sync(self, '_do_physics_finished', [global_transform])
			else:
				_do_physics_finished(global_transform)

func _do_physics_finished(_remote_transform = null) -> void:
	if _remote_transform:
		global_transform = _remote_transform
	
	sleeping = true
	if pickup_state == PickupState.THROWN:
		_on_throw_finished()
		pickup_state = PickupState.FREE
