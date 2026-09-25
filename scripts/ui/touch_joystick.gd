extends Control

@export var base_radius: float = 100.0
@export var knob_radius: float = 45.0
@export var dead_zone: float = 0.20  # fraction of base_radius that counts as "centered"
@export var fire_action: String = ""   # if set, this stick also presses/releases this Input action (e.g. "shoot")

signal fire_pressed  # emitted the instant a fire_action touch begins, guaranteeing a tap always registers

var value: Vector2 = Vector2.ZERO

var _dragging: bool = false
var _touch_index: int = -1
var _center: Vector2


func _ready() -> void:
	_center = size / 2.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and event.position.distance_to(_center) <= base_radius:
				_touch_index = event.index
				_dragging = true
				_update_from_position(event.position)
				if fire_action != "":
					Input.action_press(fire_action)
					fire_pressed.emit()
		elif event.index == _touch_index:
			_touch_index = -1
			_dragging = false
			value = Vector2.ZERO
			queue_redraw()
			if fire_action != "":
				Input.action_release(fire_action)
		accept_event()
	elif event is InputEventScreenDrag and _dragging and event.index == _touch_index:
		_update_from_position(event.position)
		accept_event()


func _update_from_position(pos: Vector2) -> void:
	var offset := pos - _center
	if offset.length() > base_radius:
		offset = offset.normalized() * base_radius
	var raw_value := offset / base_radius
	value = Vector2.ZERO if raw_value.length() < dead_zone else raw_value
	queue_redraw()


func _draw() -> void:
	draw_circle(_center, base_radius, Color(1, 1, 1, 0.15))
	var knob_pos: Vector2 = _center + value * base_radius
	draw_circle(knob_pos, knob_radius, Color(1, 1, 1, 0.35))
