extends Control
## A slider built for touch: tap or drag anywhere on the bar. Drawn by hand.
## Use: setup(min, max, step, start), then connect value_changed.
## It reads raw touch input itself, so it works inside scrolling lists too.

signal value_changed(new_value: float)

const HANDLE_R: float = 20.0

var min_value: float = 0.0
var max_value: float = 1.0
var step: float = 0.05
var _value: float = 0.0
var _dragging: bool = false   # mouse (desktop)
var _finger: int = -1         # touch finger index, -1 = none


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(320, 60)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("touch_slider")


func setup(min_v: float, max_v: float, step_v: float, start: float) -> void:
	min_value = min_v
	max_value = max_v
	step = step_v
	_value = _snap(start)
	queue_redraw()


func get_value() -> float:
	return _value


## Changes the value and announces it.
func set_value(v: float) -> void:
	var snapped_v: float = _snap(v)
	if is_equal_approx(snapped_v, _value):
		return
	_value = snapped_v
	queue_redraw()
	value_changed.emit(_value)


## Changes the value without announcing it (for syncing with other controls).
func set_value_silent(v: float) -> void:
	_value = _snap(v)
	queue_redraw()


func _snap(v: float) -> float:
	var s: float = maxf(step, 0.0001)
	return clampf(min_value + snappedf(v - min_value, s), min_value, max_value)


## Touch: read the finger directly (works no matter how the engine routes touches).
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _finger == -1 and is_visible_in_tree() and get_global_rect().has_point(event.position):
				_finger = event.index
				_set_from_x(event.position.x - get_global_rect().position.x)
				get_viewport().set_input_as_handled()
		elif event.index == _finger:
			_finger = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _finger:
			_set_from_x(event.position.x - get_global_rect().position.x)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _finger != -1:
		# Keeps a scrolling list from reacting while a finger is on the slider.
		get_viewport().set_input_as_handled()


## Mouse (desktop testing).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			_set_from_x(event.position.x)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_set_from_x(event.position.x)
		accept_event()


func _set_from_x(x: float) -> void:
	var usable: float = maxf(size.x - HANDLE_R * 2.0, 1.0)
	var ratio: float = clampf((x - HANDLE_R) / usable, 0.0, 1.0)
	set_value(lerpf(min_value, max_value, ratio))


func _draw() -> void:
	var y: float = size.y * 0.5
	var usable: float = maxf(size.x - HANDLE_R * 2.0, 1.0)
	var range_v: float = maxf(max_value - min_value, 0.0001)
	var hx: float = HANDLE_R + usable * ((_value - min_value) / range_v)
	draw_rect(Rect2(HANDLE_R, y - 5.0, usable, 10.0), Color(0.18, 0.18, 0.22))
	draw_rect(Rect2(HANDLE_R, y - 5.0, hx - HANDLE_R, 10.0), Color(1.0, 0.85, 0.3))
	draw_circle(Vector2(hx, y), HANDLE_R, Color(1.0, 0.85, 0.3))
	draw_circle(Vector2(hx, y), HANDLE_R - 6.0, Color(0.12, 0.12, 0.15))
