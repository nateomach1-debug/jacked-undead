extends Node
## Gamepad support (autoload "GamepadManager"). Nothing else depends on it.

const LOOK_DEG_PER_SEC: float = 200.0
const ACTIVATE_AXIS_THRESHOLD: float = 0.5

var gamepad_active: bool = false
var _sprint_on: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_axis("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_button("jump", JOY_BUTTON_A)
	_add_button("reload", JOY_BUTTON_X)
	_add_button("interact", JOY_BUTTON_B)
	_add_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)

func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _add_button(action: String, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _in_game() -> bool:
	return not get_tree().paused and get_tree().get_first_node_in_group("player") != null


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_set_active(false)
		return
	var had_focus: bool = get_viewport().gui_get_focus_owner() != null
	var used: bool = false
	if event is InputEventJoypadButton and event.pressed:
		used = true
		_set_active(true)
		_handle_button(event.button_index)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > ACTIVATE_AXIS_THRESHOLD:
		used = true
		_set_active(true)
	if used and not _in_game():
		_ensure_menu_focus()
		# A presses the focused menu button directly (the engine's accept wasn't reaching it).
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and had_focus:
			_press_focused_button()
			get_viewport().set_input_as_handled()


func _set_active(on: bool) -> void:
	if on == gamepad_active:
		return
	gamepad_active = on
	if not on and _sprint_on:
		_sprint_on = false
		Input.action_release("sprint")


func _handle_button(button: int) -> void:
	if not _in_game():
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	match button:
		JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT:
			if player.has_method("switch_weapon"):
				player.switch_weapon(1)
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT:
			if player.has_method("switch_weapon"):
				player.switch_weapon(-1)
		JOY_BUTTON_LEFT_STICK:
			_sprint_on = not _sprint_on
			if _sprint_on:
				Input.action_press("sprint")
			else:
				Input.action_release("sprint")


func _process(delta: float) -> void:
	# Keep the touch UI hidden while a pad is in use (new maps bring a fresh copy).
	for n in get_tree().get_nodes_in_group("touch_ui"):
		if bool(n.get("visible")) == gamepad_active:
			n.set("visible", not gamepad_active)

	if not _in_game():
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() < 0.01:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("apply_look_delta"):
		player.apply_look_delta(look, deg_to_rad(LOOK_DEG_PER_SEC) * delta)


# ---------- menus ----------

## If nothing is focused, focuses a button so the d-pad / A button work.
func _ensure_menu_focus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and focused.is_visible_in_tree() and focused.can_process():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Newest top-level child first (overlays are added last), buttons in order inside it.
	var kids: Array = scene.get_children()
	kids.reverse()
	for c in kids:
		var b := _find_button(c)
		if b != null:
			b.grab_focus()
			return


func _find_button(node: Node) -> Button:
	var v = node.get("visible")
	if v != null and not bool(v):
		return null
	if node is Button:
		var b := node as Button
		if not b.disabled and b.focus_mode != Control.FOCUS_NONE and b.is_visible_in_tree() and b.can_process():
			return b
	for c in node.get_children():
		var found := _find_button(c)
		if found != null:
			return found
	return null


func _press_focused_button() -> void:
	var f: Control = get_viewport().gui_get_focus_owner()
	if f is BaseButton:
		var b := f as BaseButton
		if not b.disabled:
			b.pressed.emit()
