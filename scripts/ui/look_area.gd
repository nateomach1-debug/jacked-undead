extends Control

const TOUCH_LOOK_SENSITIVITY: float = 0.006

var _player: Node


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		if not _player:
			_player = get_tree().get_first_node_in_group("player")
		if _player and _player.has_method("apply_look_delta"):
			_player.apply_look_delta(event.relative, TOUCH_LOOK_SENSITIVITY)
		accept_event()
