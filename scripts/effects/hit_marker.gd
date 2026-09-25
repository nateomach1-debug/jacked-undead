extends Label3D
## Brief red flash spawned at a bullet's impact point on a zombie.
## Pops in, holds briefly, fades out, then frees itself.

func _ready() -> void:
	scale = Vector3(0.6, 0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
	tween.tween_interval(0.05)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.finished.connect(queue_free)
