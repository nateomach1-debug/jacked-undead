extends Control

const TOUCH_LOOK_SENSITIVITY: float = 0.006

var _player: Node
var _shoot_touch_index: int = -1


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _gui_input(event: InputEvent) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	if event is InputEventScreenDrag:
		if _player and _player.has_method("apply_look_delta"):
			_player.apply_look_delta(event.relative, TOUCH_LOOK_SENSITIVITY)
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x > size.x / 2.0 and _shoot_touch_index == -1:
				_shoot_touch_index = event.index
				Input.action_press("shoot")
				if _player and _player.has_method("fire_once_if_ready"):
					_player.fire_once_if_ready()
		elif event.index == _shoot_touch_index:
			_shoot_touch_index = -1
			Input.action_release("shoot")
		accept_event()
