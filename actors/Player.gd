extends KinematicBody2D

var ExplodeEffect: PackedScene = preload("res://actors/ExplodeEffect.tscn")
var InputBuffer: Reference = preload("res://components/InputBuffer.gd")

enum PlayerSkin {
	BLUE,
	GREEN,
	YELLOW,
	RED,
	BEIGE,
	MAX,
}

var skin_resources = [
	preload("res://actors/player_blue_frames.tres"),
	preload("res://actors/player_green_frames.tres"),
	preload("res://actors/player_yellow_frames.tres"),
	preload("res://actors/player_red_frames.tres"),
	preload("res://actors/player_beige_frames.tres"),
]

export (PlayerSkin) var player_skin := PlayerSkin.BLUE setget set_player_skin
export (float) var speed := 550.0
export (float) var acceleration := 4000.0
export (float) var friction := 3000.0
export (float) var sliding_friction := 1000.0
export (float) var jump_speed := 1350.0
export (float) var terminal_velocity := 2000.0
export (float) var push_back_speed := 50.0
export (float) var throw_velocity := 400.0
export (float) var throw_upward_velocity := 800.0
export (float) var throw_vector_mix := 0.5
export (float) var throw_vector_max_length := 700.0
export (float) var throw_torque := 1500.0
export (bool) var invincible := false
export (bool) var player_controlled := false
export (String) var input_prefix := "player1_"

signal player_dead ()

onready var initial_scale = scale
onready var sprite: AnimatedSprite = $Sprite
onready var pickup_position: Position2D = $PickupPosition
onready var pickup_area: Area2D = $PickupArea
onready var state_machine := $StateMachine
onready var sounds := $Sounds

onready var standing_collision_shape := $StandingCollisionShape
onready var ducking_collision_shape := $DuckingCollisionShape

onready var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

var flip_h := false setget set_flip_h

var vector := Vector2.ZERO
var current_pickup: RigidBody2D

const PlayerActions := ['left', 'right', 'down', 'jump', 'grab', 'use']
var input_buffer

const SYNC_DELAY := 3
var sync_forced := false
var sync_counter: int = 0
var sync_state_info := {}

func _ready():
	# Disable the state machine node's _physics_process() so that we can run
	# it manually from here, and ensure everything happens in the right order.
	state_machine.set_physics_process(false)
	
	sprite.frames = skin_resources[player_skin]
	reset_state()

func _get_custom_rpc_methods() -> Array:
	return [
		'_try_pickup',
		'_do_pickup',
		'_do_throw',
		'_do_die',
		'update_remote_player',
	]

func set_player_skin(_player_skin: int) -> void:
	if player_skin != _player_skin and _player_skin < PlayerSkin.MAX and _player_skin >= 0:
		player_skin = _player_skin
		if sprite != null:
			sprite.frames = skin_resources[player_skin]

func set_player_name(_player_name: String) -> void:
	# @todo Implement
	pass

func set_flip_h(_flip_h: bool) -> void:
	if flip_h != _flip_h:
		flip_h = _flip_h
		
		if flip_h:
			scale.x = -initial_scale.x * sign(scale.y)
		else:
			scale.x = initial_scale.x * sign(scale.y)
		
		if current_pickup:
			current_pickup.flip_h = flip_h

func _on_Sprite_frame_changed() -> void:
	var texture: Texture = sprite.frames.get_frame(sprite.animation, sprite.frame)
	sprite.position.y = -texture.get_height()
	
	if sprite.animation == "Duck":
		ducking_collision_shape.set_deferred('disabled', false)
		standing_collision_shape.set_deferred('disabled', true)
	else:
		ducking_collision_shape.set_deferred('disabled', true)
		standing_collision_shape.set_deferred('disabled', false)

func play_animation(name) -> void:
	sprite.play(name)
	_on_Sprite_frame_changed()

func reset_state() -> void:
	var current_state_name = state_machine.current_state.name if state_machine.current_state != null else "None"
	if current_state_name != "Idle":
		state_machine.change_state("Idle")
	set_flip_h(false)
	visible = true

func pickup_or_throw() -> void:
	if not GameState.online_play:
		if current_pickup:
			_do_throw()
		else:
			_try_pickup()
	else:
		if current_pickup:
			# We throw on all clients; the pickup knows to simulate physics
			# only on the master, and sync to the puppets.
			OnlineMatch.custom_rpc_sync(self, '_do_throw')
		else:
			# We try to pickup only on the host so it can make sure that
			# only one client gets it, and then the host will tell everyone
			# else.
			OnlineMatch.custom_rpc_id_sync(self, 1, '_try_pickup')

func _try_pickup() -> void:
	for body in pickup_area.get_overlapping_bodies():
		if not body.can_pickup():
			continue
		body.pickup_state = Pickup.PickupState.PICKED_UP
		
		if GameState.online_play:
			OnlineMatch.custom_rpc_sync(self, '_do_pickup', [body.get_path()])
		else:
			_do_pickup(body.get_path())
		
		return

func _do_pickup(pickup_path: NodePath) -> void:
	sounds.play("Pickup")
	current_pickup = get_node(pickup_path)
	current_pickup.pickup(pickup_position.global_position)
	current_pickup.flip_h = flip_h

func _do_throw() -> void:
	sounds.play("Throw")
	var throw_vector = (vector * throw_vector_mix) + ((Vector2.LEFT if flip_h else Vector2.RIGHT) * throw_velocity)
	throw_vector += Vector2.UP * throw_upward_velocity
	current_pickup.throw(pickup_position.global_position, throw_vector.clamped(throw_vector_max_length), throw_torque)
	current_pickup = null

func try_use() -> void:
	if not current_pickup:
		return
	current_pickup.use()

func hurt(node: Node2D) -> void:
	if current_pickup and current_pickup == node.get_parent():
		# Prevent cutting yourself with your own sword.
		return
	
	var current_state_name = state_machine.current_state.name if state_machine.current_state != null else "None"
	if current_state_name == "Hurt" or current_state_name == "Dead":
		return
	
	var push_back_vector = (global_position - node.global_position).normalized() * push_back_speed
		
	state_machine.change_state("Hurt", {
		push_back_vector = push_back_vector,
	})

func die() -> void:
	if GameState.online_play:
		if current_pickup:
			OnlineMatch.custom_rpc_sync(self, "_do_throw")
		OnlineMatch.custom_rpc_sync(self, "_do_die")
	else:
		if current_pickup:
			_do_throw()
		_do_die();

func _do_die() -> void:
	# @todo Move this to the Dead.gd state, if we can sync the state machine.
	var explosion = ExplodeEffect.instance()
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	
	queue_free()
	emit_signal("player_dead")

func _physics_process(delta: float) -> void:
	# Initialize the input buffer.
	if input_buffer == null:
		input_buffer = InputBuffer.new(PlayerActions, input_prefix)
	
	var input_buffer_changed := false
	if player_controlled:
		input_buffer_changed = input_buffer.update_local()
	
	state_machine._physics_process(delta)
	
	vector.y += (gravity * delta)
	if vector.y > terminal_velocity:
		vector.y = terminal_velocity
	vector = move_and_slide(vector, Vector2.UP)
	
	update_pickup_positions()
	
	if GameState.online_play:
		if player_controlled:
			# Sync every so many physics frames.
			sync_counter += 1
			if sync_forced or input_buffer_changed or sync_counter >= SYNC_DELAY:
				sync_counter = 0
				sync_forced = false
				OnlineMatch.custom_rpc(self, "update_remote_player", [input_buffer.buffer, state_machine.current_state.name, sync_state_info, global_position, vector, sprite.animation, sprite.frame, flip_h])
				if sync_state_info.size() > 0:
					sync_state_info.clear()
		else:
			input_buffer.predict_next_frame()

func update_pickup_positions() -> void:
	if current_pickup:
		current_pickup.global_position = pickup_position.global_position

func update_remote_player(_input_buffer: Dictionary, current_state: String, state_info: Dictionary, _position: Vector2, _vector: Vector2, animation: String, frame: int, flip_h: bool) -> void:
	# Initialize the input buffer.
	if input_buffer == null:
		input_buffer = InputBuffer.new(PlayerActions, input_prefix)
	
	input_buffer.buffer = _input_buffer
	state_machine.change_state(current_state, state_info)
	global_position = _position
	vector = _vector
	sprite.animation = animation
	sprite.frame = frame
	_on_Sprite_frame_changed()
	set_flip_h(flip_h)
	update_pickup_positions()

func _on_StateMachine_state_changed(state, info: Dictionary) -> void:
	sync_forced = true
	sync_state_info = info
