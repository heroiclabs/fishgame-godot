extends Pickup

var DisintegrateEffect: PackedScene = preload("res://pickups/DisintegrateEffect.tscn")
var SparksEffect: PackedScene = preload("res://pickups/SparksEffect.tscn")

export (NodePath) var projectile_parent_path := @"../"
export (PackedScene) var projectile_scene: PackedScene = preload("res://pickups/Projectile.tscn")
export (float) var projectile_velocity := 1200.0
export (float) var projectile_range := 400.0
export (float) var cooldown_time := 0.3
export (int) var max_ammo := 3

onready var projectile_position := $ProjectilePosition
onready var cooldown_timer := $CooldownTimer
onready var sounds := $Sounds

var allow_shoot := true
onready var ammo := max_ammo

func _ready() -> void:
	cooldown_timer.wait_time = cooldown_time

func use() -> void:
	if not allow_shoot:
		return
	
	allow_shoot = false
	cooldown_timer.start()
	
	var projectile_name = Util.find_unique_name(get_node(projectile_parent_path), 'Projectile-')
	var projectile_vector: Vector2 = (Vector2.LEFT if flip_h else Vector2.RIGHT) * projectile_velocity
	
	if not GameState.online_play:
		_do_use(projectile_name, projectile_position.global_position, projectile_vector, projectile_range)
	else:
		rpc("_do_use", projectile_name, projectile_position.global_position, projectile_vector, projectile_range)

remotesync func _do_use(_projectile_name: String, _projectile_position: Vector2, _projectile_vector: Vector2, _projectile_range: float) -> void:
	var projectile_parent = get_node(projectile_parent_path)
	
	if ammo <= 0:
		var sparks = SparksEffect.instance()
		# We use the 'project_position' node rather than '_project_position'
		# on purpose, because we want to make sure it appears at the local
		# position of the gun, since this is a purely visual effect.
		projectile_position.add_child(sparks)
		sounds.play("Empty")
	else:
		ammo -= 1
		
		var projectile = projectile_scene.instance()
		projectile.name = _projectile_name
		projectile_parent.add_child(projectile)
		
		projectile.shoot(_projectile_position, _projectile_vector, _projectile_range)
		sounds.play("Shoot")

func _on_throw_finished() -> void:
	if ammo <= 0:
		if not GameState.online_play:
			_disintegrate()
		else:
			rpc('_disintegrate')

remotesync func _disintegrate() -> void:
	var parent = get_parent();
	if parent:
		var effect = DisintegrateEffect.instance()
		parent.add_child(effect)
		effect.global_position = global_position + Vector2(0, 10)
	
	queue_free()

func _on_CooldownTimer_timeout() -> void:
	allow_shoot = true
