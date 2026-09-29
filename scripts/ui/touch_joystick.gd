extends Control

@export var base_radius: float = 100.0
@export var knob_radius: float = 45.0
@export var dead_zone: float = 0.20  # fraction of base_radius that counts as "centered"
@export var fire_action: String = ""   # if set, this stick also presses/releases this Input action (e.g. "shoot")

# --- Forward lock: push forward, slide into the circle above the stick, keep running ---
@export var forward_lock_enabled: bool = true
@export var lock_distance: float = 340.0        # pixels from the stick center up to the lock circle's center
@export var lock_radius: float = 65.0           # size of the lock circle
@export var lock_show_threshold: float = 0.55   # how far forward (0..1) before the circle appears

signal fire_pressed  # emitted the instant a fire_action touch begins, guaranteeing a tap always registers

var value: Vector2 = Vector2.ZERO  # what the player actually uses

var _dragging: bool = false
var _touch_index: int = -1
var _center: Vector2
var _finger: Vector2 = Vector2.ZERO       # where the finger is, in this control's coordinates
var _stick_value: Vector2 = Vector2.ZERO  # raw stick position from the finger
var _locked: bool = false
var _lock_touch: bool = false             # true while the finger that engaged the lock is still down


func _ready() -> void:
	_center = size / 2.0


func _lock_enabled() -> bool:
	return forward_lock_enabled and fire_action == ""


func _lock_center() -> Vector2:
	return _center + Vector2(0.0, -lock_distance)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and event.position.distance_to(_center) <= base_radius:
				_touch_index = event.index
				_dragging = true
				_lock_touch = false
				_update_from_position(event.position)
				if fire_action != "":
					Input.action_press(fire_action)
					fire_pressed.emit()
		elif event.index == _touch_index:
			_touch_index = -1
			_dragging = false
			_lock_touch = false
			_stick_value = Vector2.ZERO
			_update_output()
			if fire_action != "":
				Input.action_release(fire_action)
		accept_event()
	elif event is InputEventScreenDrag and _dragging and event.index == _touch_index:
		_update_from_position(event.position)
		accept_event()


# Drags keep arriving here even after the finger leaves this control's box,
# which is how a finger can reach the lock circle above the stick.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and _dragging and event.index == _touch_index:
		_update_from_position(make_canvas_position_local(event.position))


func _update_from_position(pos: Vector2) -> void:
	_finger = pos
	var offset := pos - _center
	if offset.length() > base_radius:
		offset = offset.normalized() * base_radius
	var raw_value := offset / base_radius
	_stick_value = Vector2.ZERO if raw_value.length() < dead_zone else raw_value
	if _lock_enabled():
		_update_lock()
	_update_output()


func _update_lock() -> void:
	var lock_center := _lock_center()
	if _locked:
		if _lock_touch:
			# The finger that locked it: dragging back down out of the circle cancels.
			if _finger.y > lock_center.y + lock_radius:
				_locked = false
				_lock_touch = false
		else:
			# A fresh touch while locked: pulling the stick back down cancels.
			if _stick_value.y > 0.35:
				_locked = false
	else:
		if _finger.distance_to(lock_center) <= lock_radius and _stick_value.y < -lock_show_threshold:
			_locked = true
			_lock_touch = true


func _update_output() -> void:
	if _locked:
		# Keep running forward; a finger on the stick can still steer left and right.
		value = Vector2(_stick_value.x if _dragging else 0.0, -1.0)
	else:
		value = _stick_value
	queue_redraw()


func _draw() -> void:
	draw_circle(_center, base_radius, Color(1, 1, 1, 0.15))
	var knob_value := value
	if knob_value.length() > 1.0:
		knob_value = knob_value.normalized()
	draw_circle(_center + knob_value * base_radius, knob_radius, Color(1, 1, 1, 0.35))

	if _lock_enabled():
		var show_lock: bool = _locked or (_dragging and _stick_value.y < -lock_show_threshold)
		if show_lock:
			var c := _lock_center()
			var fill := Color(1, 1, 1, 0.12)
			var line := Color(1, 1, 1, 0.4)
			if _locked:
				fill = Color(1.0, 0.85, 0.2, 0.35)
				line = Color(1.0, 0.85, 0.2, 0.85)
			draw_circle(c, lock_radius, fill)
			draw_arc(c, lock_radius, 0.0, TAU, 48, line, 4.0, true)
			# up arrow inside the circle
			draw_line(c + Vector2(0, 22), c + Vector2(0, -22), line, 5.0, true)
			draw_line(c + Vector2(0, -22), c + Vector2(-16, -6), line, 5.0, true)
			draw_line(c + Vector2(0, -22), c + Vector2(16, -6), line, 5.0, true)
