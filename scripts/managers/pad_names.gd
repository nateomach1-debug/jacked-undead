extends RefCounted
## Controller button names for on-screen prompts (Xbox or PlayStation style).


func is_playstation() -> bool:
    var pads: Array = Input.get_connected_joypads()
    if pads.is_empty():
        return false
    var n: String = Input.get_joy_name(int(pads[0])).to_lower()
    for key in ["playstation", "dualsense", "dualshock", "sony", "ps3", "ps4", "ps5", "wireless controller"]:
        if n.contains(key):
            return true
    return false


## Name of the pad button bound to an action, or "" if none.
func button_name(action: String) -> String:
    if not InputMap.has_action(action):
        return ""
    var ps: bool = is_playstation()
    var events: Array = InputMap.action_get_events(action)
    for e in events:
        var jb := e as InputEventJoypadButton
        if jb != null:
            return _button_text(jb.button_index, ps)
    for e in events:
        var jm := e as InputEventJoypadMotion
        if jm != null:
            if jm.axis == JOY_AXIS_TRIGGER_LEFT:
                return "L2" if ps else "LT"
            if jm.axis == JOY_AXIS_TRIGGER_RIGHT:
                return "R2" if ps else "RT"
    return ""


func _button_text(index: int, ps: bool) -> String:
    match index:
        JOY_BUTTON_A:
            return "Cross" if ps else "A"
        JOY_BUTTON_B:
            return "Circle" if ps else "B"
        JOY_BUTTON_X:
            return "Square" if ps else "X"
        JOY_BUTTON_Y:
            return "Triangle" if ps else "Y"
        JOY_BUTTON_LEFT_SHOULDER:
            return "L1" if ps else "LB"
        JOY_BUTTON_RIGHT_SHOULDER:
            return "R1" if ps else "RB"
        JOY_BUTTON_LEFT_STICK:
            return "L3"
        JOY_BUTTON_RIGHT_STICK:
            return "R3"
        JOY_BUTTON_DPAD_UP:
            return "D-pad Up"
        JOY_BUTTON_DPAD_DOWN:
            return "D-pad Down"
        JOY_BUTTON_DPAD_LEFT:
            return "D-pad Left"
        JOY_BUTTON_DPAD_RIGHT:
            return "D-pad Right"
        JOY_BUTTON_START:
            return "Options" if ps else "Menu"
        JOY_BUTTON_BACK:
            return "Create" if ps else "View"
    return "Button %d" % index

## Name for a saved binding such as "b:0" or "a:5".
func descriptor_name(desc: String) -> String:
    var ps: bool = is_playstation()
    if desc.begins_with("b:"):
        return _button_text(int(desc.substr(2)), ps)
    if desc.begins_with("a:"):
        var axis: int = int(desc.substr(2))
        if axis == JOY_AXIS_TRIGGER_LEFT:
            return "L2" if ps else "LT"
        if axis == JOY_AXIS_TRIGGER_RIGHT:
            return "R2" if ps else "RT"
    return "?"

# END OF FILE
