extends Control

@export var base_radius: float = 100.0
@export var knob_radius: float = 45.0

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
		elif event.index == _touch_index:
			_touch_index = -1
			_dragging = false
			value = Vector2.ZERO
			queue_redraw()
		accept_event()
	elif event is InputEventScreenDrag and _dragging and event.index == _touch_index:
		_update_from_position(event.position)
		accept_event()


func _update_from_position(pos: Vector2) -> void:
	var offset := pos - _center
	if offset.length() > base_radius:
		offset = offset.normalized() * base_radius
	value = offset / base_radius
	queue_redraw()


func _draw() -> void:
	draw_circle(_center, base_radius, Color(1, 1, 1, 0.15))
	var knob_pos: Vector2 = _center + value * base_radius
	draw_circle(knob_pos, knob_radius, Color(1, 1, 1, 0.35))
