extends Control

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var motion := InputEventMouseMotion.new()
		motion.relative = event.relative
		motion.position = event.position
		Input.parse_input_event(motion)
		accept_event()
