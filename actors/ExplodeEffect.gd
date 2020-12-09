extends CPUParticles2D

onready var sounds = $Sounds

func _ready():
	emitting = true
	sounds.play("Explode")

func _on_Timer_timeout() -> void:
	queue_free()
