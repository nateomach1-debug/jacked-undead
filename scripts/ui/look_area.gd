extends Control

const TOUCH_LOOK_SENSITIVITY: float = 0.006
const STICK_VISUAL_RADIUS: float = 90.0
const STICK_KNOB_RADIUS: float = 40.0
const SHOOT_ZONE_LEFT_MARGIN: float = 164.0   # matches the perk bar's half-width in hud.tscn
const SHOOT_ZONE_HEIGHT: float = 330.0        # matches the button cluster's height in touch_controls.tscn

var _player: Node
var _shoot_touch_index: int = -1
var _shoot_origin: Vector2 = Vector2.ZERO
var _shoot_knob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("touch_ui")
	_player = get_tree().get_first_node_in_group("player")


func _gui_input(event: InputEvent) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")

	if event is InputEventScreenDrag:
		if _player and _player.has_method("apply_look_delta"):
			_player.apply_look_delta(event.relative, TOUCH_LOOK_SENSITIVITY)
		if event.index == _shoot_touch_index:
			var offset: Vector2 = event.position - _shoot_origin
			if offset.length() > STICK_VISUAL_RADIUS:
				offset = offset.normalized() * STICK_VISUAL_RADIUS
			_shoot_knob_offset = offset
			queue_redraw()
		accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			var in_shoot_zone: bool = event.position.x > (size.x / 2.0 + SHOOT_ZONE_LEFT_MARGIN) and event.position.y > (size.y - SHOOT_ZONE_HEIGHT)
			if in_shoot_zone and _shoot_touch_index == -1:
				_shoot_touch_index = event.index
				_shoot_origin = event.position
				_shoot_knob_offset = Vector2.ZERO
				Input.action_press("shoot")
				if _player and _player.has_method("fire_once_if_ready"):
					_player.fire_once_if_ready()
				queue_redraw()
		elif event.index == _shoot_touch_index:
			_shoot_touch_index = -1
			Input.action_release("shoot")
			queue_redraw()
		accept_event()


func _draw() -> void:
	if _shoot_touch_index == -1:
		return
	draw_circle(_shoot_origin, STICK_VISUAL_RADIUS, Color(1, 1, 1, 0.15))
	draw_circle(_shoot_origin + _shoot_knob_offset, STICK_KNOB_RADIUS, Color(1, 1, 1, 0.35))
