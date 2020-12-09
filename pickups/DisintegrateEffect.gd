extends CPUParticles2D

func _ready():
	emitting = true

func _on_Timer_timeout() -> void:
	queue_free()
