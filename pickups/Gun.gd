extends Pickup

var DisintegrateEffect: PackedScene = preload("res://pickups/DisintegrateEffect.tscn")
var SparksEffect: PackedScene = preload("res://pickups/SparksEffect.tscn")

export (PackedScene) var projectile_scene: PackedScene = preload("res://pickups/Projectile.tscn")
export (float) var projectile_velocity := 1200.0
export (float) var projectile_range := 400.0
export (float) var cooldown_time := 0.3
export (int) var max_ammo := 3

onready var projectile_position := $ProjectilePosition
onready var sparks_position := $SparksPosition
onready var dud_detector := $DudDetector
onready var animation_player := $AnimationPlayer
onready var cooldown_timer := $CooldownTimer
onready var sounds := $Sounds

var allow_shoot := true
onready var ammo := max_ammo

var use_by_player: Node = null

func _ready() -> void:
	cooldown_timer.wait_time = cooldown_time

func _get_custom_rpc_methods() -> Array:
	return ._get_custom_rpc_methods() + [
		'_start_use',
		'_do_fire_projectile',
		'_disintegrate',
	]

func use() -> void:
	if not allow_shoot:
		return
	
	allow_shoot = false
	cooldown_timer.start()
	
	if ammo > 0:
		if not GameState.online_play:
			_start_use()
		else:
			OnlineMatch.custom_rpc_sync(self, "_start_use")
	else:
		_fire_projectile()

func _start_use() -> void:
	# Account for a player throwing the gun before it actually fires.
	use_by_player = player
	
	animation_player.play("Shoot")

func _fire_projectile() -> void:
	if GameState.online_play and not OnlineMatch.is_network_master_for_node(use_by_player):
		return
	
	var projectile_name = Util.find_unique_name(original_parent, 'Projectile-')
	var projectile_vector: Vector2 = (Vector2.RIGHT * projectile_velocity).rotated(global_rotation)
	var projectile_dud: bool = dud_detector.get_overlapping_bodies().size() > 0
	
	if not GameState.online_play:
		_do_fire_projectile(projectile_name, projectile_position.global_position, projectile_vector, projectile_range, projectile_dud)
	else:
		OnlineMatch.custom_rpc_sync(self, "_do_fire_projectile", [projectile_name, projectile_position.global_position, projectile_vector, projectile_range, projectile_dud])

func _do_fire_projectile(_projectile_name: String, _projectile_position: Vector2, _projectile_vector: Vector2, _projectile_range: float, _projectile_dud: bool) -> void:
	var projectile_parent = original_parent
	
	if ammo <= 0:
		var sparks = SparksEffect.instance()
		sparks_position.add_child(sparks)
		sounds.play("Empty")
	else:
		ammo -= 1
		
		var projectile = projectile_scene.instance()
		projectile.name = _projectile_name
		projectile_parent.add_child(projectile)
		
		projectile.shoot(_projectile_position, _projectile_vector, _projectile_range, _projectile_dud)
		sounds.play("Shoot")

func _on_throw_finished() -> void:
	if ammo <= 0:
		if not GameState.online_play:
			_disintegrate()
		else:
			OnlineMatch.custom_rpc_sync(self, '_disintegrate')

func _disintegrate() -> void:
	var parent = get_parent();
	if parent:
		var effect = DisintegrateEffect.instance()
		parent.add_child(effect)
		effect.global_position = global_position + Vector2(0, 10)
	
	queue_free()

func _on_CooldownTimer_timeout() -> void:
	allow_shoot = true

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void:
	if anim_name == 'Shoot':
		animation_player.play("Idle")
