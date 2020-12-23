extends RigidBody2D
class_name Pickup

onready var initial_scale = scale

var flip_h := false setget set_flip_h

enum PickupState {
	FREE = 0,
	PICKED_UP,
	WORN,
	THROWING,
	THROWN,
}

# Minimum thresholds in order to sleep physics on this body.
const MIN_LINEAR_VELOCITY = 10.0
const MIN_ANGULAR_VELOCITY = 1.0

var pickup_state: int = PickupState.FREE
var throw_position := Vector2.ZERO

signal picked_up()

func _ready():
	pass

func _get_custom_rpc_methods() -> Array:
	return [
		'update_remote_pickup',
	]

func set_flip_h(_flip_h: bool) -> void:
	flip_h = _flip_h
	
	if flip_h:
		scale.x = -initial_scale.x * sign(scale.y)
	else:
		scale.x = initial_scale.x * sign(scale.y)

func can_pickup() -> bool:
	return pickup_state == PickupState.FREE or pickup_state == PickupState.THROWN

func pickup(_pickup_position: Vector2) -> void:
	mode = RigidBody2D.MODE_KINEMATIC
	pickup_state = PickupState.PICKED_UP
	global_position = _pickup_position
	global_rotation = 0.0
	emit_signal("picked_up")

func _on_throw() -> void:
	# This allows the pickup to do something special just before it's thrown.
	pass

func _on_throw_finished() -> void:
	# This allows the pickup to do something special once its stopped moving.
	pass

func throw(_throw_position: Vector2, _throw_vector: Vector2, _throw_torque: float) -> void:
	_on_throw()
	if not GameState.online_play or OnlineMatch.is_network_master_for_node(self):
		mode = RigidBody2D.MODE_RIGID
		pickup_state = PickupState.THROWING
		throw_position = _throw_position
		apply_central_impulse(_throw_vector)
		apply_torque_impulse(_throw_torque)
	else:
		mode = RigidBody2D.MODE_KINEMATIC
		pickup_state = PickupState.FREE

func use() -> void:
	# Implement this in child classes.
	pass

func _integrate_forces(state: Physics2DDirectBodyState) -> void:
	if pickup_state == PickupState.THROWING:
		global_transform = Transform2D(0.0, throw_position)
		state.transform = global_transform
		pickup_state = PickupState.THROWN
	else:
		if linear_velocity.length() < MIN_LINEAR_VELOCITY and angular_velocity < MIN_ANGULAR_VELOCITY:
			sleeping = true
			if pickup_state == PickupState.THROWN:
				_on_throw_finished()
				pickup_state = PickupState.FREE
	
	if GameState.online_play and OnlineMatch.is_network_master_for_node(self) and not sleeping and (pickup_state == PickupState.FREE or pickup_state == PickupState.THROWN):
		OnlineMatch.custom_rpc(self, 'update_remote_pickup', [global_transform])

func update_remote_pickup(_remote_transform) -> void:
	global_transform = _remote_transform
