extends StaticBody2D

export (PackedScene) var pickup_scene: PackedScene
export (NodePath) var pickup_parent_path: NodePath = @"../"
export (float) var regenerate_delay := 10.0

onready var timer = $Timer
onready var animation_player = $AnimationPlayer
onready var pickup_position = $PickupPosition

var current_pickup: Node2D

func _ready() -> void:
	animation_player.play("Glow")
	timer.connect("timeout", self, "_do_generate")

func _get_custom_rpc_methods() -> Array:
	return [
		'generate',
	]

func _do_generate() -> void:
	var pickup_parent = get_node(pickup_parent_path)
	if not pickup_parent:
		return
	
	var pickup_name = Util.find_unique_name(pickup_parent, 'Pickup-')
	if GameState.online_play:
		OnlineMatch.custom_rpc_sync(self, "generate", [pickup_name])
	else:
		generate(pickup_name)

func generate(pickup_name: String) -> void:
	if not pickup_scene:
		return
	
	var pickup_parent = get_node(pickup_parent_path)
	if not pickup_parent:
		return
	
	current_pickup = pickup_scene.instance()
	current_pickup.name = pickup_name
	pickup_parent.add_child(current_pickup)
	current_pickup.global_position = pickup_position.global_position
	
	current_pickup.connect("picked_up", self, "_on_current_pickup_picked_up")

func _on_current_pickup_picked_up() -> void:
	current_pickup.disconnect("picked_up", self, "_on_current_pickup_picked_up")
	current_pickup = null
	
	if not GameState.online_play or OnlineMatch.is_network_master_for_node(self):
		timer.start()

func map_object_start() -> void:
	if current_pickup == null and (not GameState.online_play or OnlineMatch.is_network_master_for_node(self)):
		_do_generate()
	timer.wait_time = regenerate_delay

func map_object_stop() -> void:
	timer.stop()
