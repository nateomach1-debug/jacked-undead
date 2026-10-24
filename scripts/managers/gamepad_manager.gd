extends Node
## Gamepad support (autoload "GamepadManager"). Nothing else depends on it.

const LOOK_DEG_PER_SEC: float = 200.0
const ACTIVATE_AXIS_THRESHOLD: float = 0.5
const DEFAULT_DEADZONE: float = 0.2
const BINDINGS_PATH: String = "res://scripts/managers/gamepad_bindings.gd"

var gamepad_active: bool = false
var _sprint_on: bool = false
var _bindings = null


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
    _add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
    _add_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
    _add_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
    _add_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
    _add_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
    _add_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
    _add_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
    reload_bindings()
    _refresh_settings()


## Loads the saved bindings (Settings > CONTROLLER BUTTONS) onto the InputMap.
func reload_bindings() -> void:
    var script = load(BINDINGS_PATH)
    _bindings = script.new() if script != null else null
    if _bindings != null:
        _bindings.apply_to_input_map()
        return
    # Fallback if the bindings script is missing: the original layout.
    _add_axis("shoot", JOY_AXIS_TRIGGER_RIGHT, 1.0)
    _add_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
    _add_button("jump", JOY_BUTTON_A)
    _add_button("reload", JOY_BUTTON_X)
    _add_button("interact", JOY_BUTTON_B)


func _ensure_action(action: String) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action, DEFAULT_DEADZONE)


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


## Short vibration on the active pad. Does nothing unless a pad is in use and the setting is on.
func rumble(weak: float, strong: float, duration: float) -> void:
    if not gamepad_active:
        return
    if _setting("pad_vibration") < 0.5:
        return
    var pads: Array = Input.get_connected_joypads()
    if pads.is_empty():
        return
    Input.start_joy_vibration(int(pads[0]), clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)


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

        # A presses the focused menu button directly.
        if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A and had_focus:
            _press_focused_button()
            get_viewport().set_input_as_handled()


func _set_active(on: bool) -> void:
    if on == gamepad_active:
        return
    gamepad_active = on
    _apply_deadzones()
    if not on and _sprint_on:
        _sprint_on = false
        Input.action_release("sprint")


## True if this button is bound to the action (falls back to the original layout).
func _bound(action: String, button: int) -> bool:
    if _bindings != null:
        return _bindings.matches(action, button)
    match action:
        "next_weapon":
            return button == JOY_BUTTON_Y or button == JOY_BUTTON_RIGHT_SHOULDER
        "prev_weapon":
            return button == JOY_BUTTON_LEFT_SHOULDER
        "sprint":
            return button == JOY_BUTTON_LEFT_STICK
    return false


func _handle_button(button: int) -> void:
    if not _in_game():
        return
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return
    if _bound("next_weapon", button) or button == JOY_BUTTON_DPAD_RIGHT:
        if player.has_method("switch_weapon"):
            player.switch_weapon(1)
    elif _bound("prev_weapon", button) or button == JOY_BUTTON_DPAD_LEFT:
        if player.has_method("switch_weapon"):
            player.switch_weapon(-1)
    elif _bound("sprint", button):
        _sprint_on = not _sprint_on
        if _sprint_on:
            Input.action_press("sprint")
        else:
            Input.action_release("sprint")


func _process(delta: float) -> void:
    _refresh_settings()

    # Keep the touch UI hidden while a pad is in use (new maps bring a fresh copy).
    for n in get_tree().get_nodes_in_group("touch_ui"):
        if bool(n.get("visible")) == gamepad_active:
            n.set("visible", not gamepad_active)

    if not _in_game():
    _process_menu_scroll(delta)
    return
        return
    var look: Vector2 = _shaped_look()
    if look.length() < 0.01:
        return
    var player := get_tree().get_first_node_in_group("player")
    if player != null and player.has_method("apply_look_delta"):
        player.apply_look_delta(look, deg_to_rad(_pad_look_speed()) * delta)


func _process_menu_scroll(delta: float) -> void:
    var x: float = Input.get_axis("look_left", "look_right")
    var y: float = Input.get_axis("look_up", "look_down")

    if absf(x) < 0.25 and absf(y) < 0.25:
        return

    var scroll := _find_menu_scroll_container()
    if scroll == null:
        return

    var vbar := scroll.get_v_scroll_bar()
    var hbar := scroll.get_h_scroll_bar()

    if absf(y) >= 0.25 and vbar.max_value > vbar.page:
        scroll.scroll_vertical = clampi(
            scroll.scroll_vertical + int(y * 700.0 * delta),
            0,
            maxi(0, int(vbar.max_value - vbar.page))
        )

    if absf(x) >= 0.25 and hbar.max_value > hbar.page:
        scroll.scroll_horizontal = clampi(
            scroll.scroll_horizontal + int(x * 700.0 * delta),
            0,
            maxi(0, int(hbar.max_value - hbar.page))
        )


func _find_menu_scroll_container() -> ScrollContainer:
    # Prefer the scroll area containing the focused control.
    var focused := get_viewport().gui_get_focus_owner()
    var node: Node = focused

    while node != null:
        if node is ScrollContainer:
            var sc := node as ScrollContainer
            if sc.is_visible_in_tree() and sc.get_global_rect().has_area():
                return sc
        node = node.get_parent()

    # Otherwise, search visible menu content from the topmost scene children.
    var scene := get_tree().current_scene
    if scene == null:
        return null

    var stack: Array[Node] = [scene]
    var candidates: Array[ScrollContainer] = []

    while not stack.is_empty():
        var current: Node = stack.pop_back()

        if current is Control and not (current as Control).is_visible_in_tree():
            continue

        if current is ScrollContainer:
            var sc := current as ScrollContainer
            if sc.get_global_rect().has_area():
                candidates.append(sc)

        for child in current.get_children():
            stack.append(child)

    for i in range(candidates.size() - 1, -1, -1):
        var sc := candidates[i]
        var vb := sc.get_v_scroll_bar()
        var hb := sc.get_h_scroll_bar()
        if vb.max_value > vb.page or hb.max_value > hb.page:
            return sc


    return null

## Right stick after the deadzone (set on the look_* actions), the look curve and invert Y.
func _shaped_look() -> Vector2:
    var v: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
    var m: float = v.length()
    if m < 0.001:
        return Vector2.ZERO
    var power: float = 1.0
    var curve: int = int(_setting("pad_curve"))
    if curve == 1:
        power = 1.6
    elif curve == 2:
        power = 2.4
    v = v / m * pow(clampf(m, 0.0, 1.0), power)
    if _setting("pad_invert_y") > 0.5:
        v.y = -v.y
    return v


## Applies the stick deadzones from Settings. The move deadzone only counts while a pad is
## in use, so the touch joystick keeps its normal feel.
func _apply_deadzones() -> void:
    if _settings == null or not _settings.DEFAULTS.has("pad_dz_move"):
        return
    var move_dz: float = DEFAULT_DEADZONE
    if gamepad_active:
        move_dz = clampf(float(_settings.get_value("pad_dz_move")) / 100.0, 0.0, 0.6)
    var look_dz: float = clampf(float(_settings.get_value("pad_dz_look")) / 100.0, 0.0, 0.6)
    for a in ["move_left", "move_right", "move_forward", "move_back"]:
        if InputMap.has_action(a):
            InputMap.action_set_deadzone(a, move_dz)
    for a in ["look_left", "look_right", "look_up", "look_down"]:
        if InputMap.has_action(a):
            InputMap.action_set_deadzone(a, look_dz)

# ---------- menus ----------



## If nothing is focused, focuses a button so the d-pad / A button work.

func _ensure_menu_focus() -> void:
    var focused: Control = get_viewport().gui_get_focus_owner()
    if focused != null and focused.is_visible_in_tree() and focused.can_process():
        return

    var scene := get_tree().current_scene
    if scene == null:
        return

    # Search the newest visible top-level menu first.
    var kids: Array = scene.get_children()
    kids.reverse()

    for c in kids:
        if c is CanvasLayer:
            continue

        var visible_value = c.get("visible")
        if visible_value != null and not bool(visible_value):
            continue

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


var _settings = null
var _next_settings_check: int = 0


## Re-reads the saved settings every couple of seconds so menu changes apply.
func _refresh_settings() -> void:
    var now: int = Time.get_ticks_msec()
    if now < _next_settings_check:
        return
    _next_settings_check = now + 2000
    var script = load("res://scripts/managers/game_settings.gd")
    _settings = script.new() if script != null else null
    _apply_deadzones()


func _setting(key: String) -> float:
    _refresh_settings()
    if _settings == null:
        return 0.0
    return float(_settings.get_value(key))


func _pad_look_speed() -> float:
    _refresh_settings()
    if _settings == null:
        return LOOK_DEG_PER_SEC
    return float(_settings.get_value("pad_look"))


func _sprint_hold_mode() -> bool:
    _refresh_settings()
    return _settings != null and _settings.get_value("sprint_hold") > 0.5


## Hold mode: letting go of the sprint button stops sprinting.
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventJoypadButton and not event.pressed and _bound("sprint", event.button_index):
        if _sprint_hold_mode() and _sprint_on:
            _sprint_on = false
            Input.action_release("sprint")

# END OF FILE
