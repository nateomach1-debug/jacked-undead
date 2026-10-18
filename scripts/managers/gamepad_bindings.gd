extends RefCounted
## Saved gamepad bindings (user://gamepad_bindings.cfg).
## A binding is a text like "b:0" (button index) or "a:5" (trigger axis index).

const FILE: String = "user://gamepad_bindings.cfg"
const ACTIONS: Array = [
    {"id": "shoot", "title": "Shoot", "axis_ok": true},
    {"id": "aim", "title": "Aim (toggle)", "axis_ok": true},
    {"id": "jump", "title": "Jump", "axis_ok": true},
    {"id": "reload", "title": "Reload", "axis_ok": true},
    {"id": "interact", "title": "Use / Buy", "axis_ok": true},
    {"id": "sprint", "title": "Sprint", "axis_ok": false},
    {"id": "next_weapon", "title": "Next weapon", "axis_ok": false},
    {"id": "prev_weapon", "title": "Previous weapon", "axis_ok": false},
]
# Actions that exist in the InputMap (the rest are handled in gamepad_manager.gd).
const MAP_ACTIONS: Array = ["shoot", "aim", "jump", "reload", "interact"]

var map: Dictionary = {}


func _init() -> void:
    map = defaults()
    var cfg := ConfigFile.new()
    if cfg.load(FILE) != OK:
        return
    for a in ACTIONS:
        var id: String = a["id"]
        if cfg.has_section_key("bindings", id):
            var raw = cfg.get_value("bindings", id)
            var lst: Array = []
            if raw is Array:
                for d in raw:
                    if _valid(id, str(d)):
                        lst.append(str(d))
            map[id] = lst


func defaults() -> Dictionary:
    return {
        "shoot": ["a:%d" % JOY_AXIS_TRIGGER_RIGHT],
        "aim": ["a:%d" % JOY_AXIS_TRIGGER_LEFT],
        "jump": ["b:%d" % JOY_BUTTON_A],
        "reload": ["b:%d" % JOY_BUTTON_X],
        "interact": ["b:%d" % JOY_BUTTON_B],
        "sprint": ["b:%d" % JOY_BUTTON_LEFT_STICK],
        "next_weapon": ["b:%d" % JOY_BUTTON_Y, "b:%d" % JOY_BUTTON_RIGHT_SHOULDER],
        "prev_weapon": ["b:%d" % JOY_BUTTON_LEFT_SHOULDER],
    }


func axis_ok(action: String) -> bool:
    for a in ACTIONS:
        if a["id"] == action:
            return bool(a["axis_ok"])
    return false


func _valid(action: String, desc: String) -> bool:
    if desc.begins_with("b:"):
        return true
    if desc.begins_with("a:"):
        return axis_ok(action)
    return false


func matches(action: String, button: int) -> bool:
    var lst: Array = map.get(action, [])
    return lst.has("b:%d" % button)


## Binds one button/trigger to an action. If another action had it, that action
## gets the old binding of this one (or becomes unbound if it can't use it).
func assign(action: String, desc: String) -> void:
    var old: Array = (map.get(action, []) as Array).duplicate()
    for other in map.keys():
        if other == action:
            continue
        var lst: Array = map[other]
        if not lst.has(desc):
            continue
        lst.erase(desc)
        if lst.is_empty():
            for d in old:
                if _valid(other, str(d)):
                    lst.append(str(d))
                    break
        map[other] = lst
    map[action] = [desc]
    save()


func reset() -> void:
    map = defaults()
    save()


func save() -> void:
    var cfg := ConfigFile.new()
    for id in map.keys():
        cfg.set_value("bindings", id, map[id])
    cfg.save(FILE)


## Puts the saved bindings on the InputMap actions (keyboard/mouse events stay).
func apply_to_input_map() -> void:
    for action in MAP_ACTIONS:
        if not InputMap.has_action(action):
            InputMap.add_action(action, 0.2)
        for ev in InputMap.action_get_events(action):
            if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
                InputMap.action_erase_event(action, ev)
        for d in map.get(action, []):
            var desc: String = str(d)
            if desc.begins_with("b:"):
                var jb := InputEventJoypadButton.new()
                jb.button_index = int(desc.substr(2)) as JoyButton
                InputMap.action_add_event(action, jb)
            elif desc.begins_with("a:"):
                var jm := InputEventJoypadMotion.new()
                jm.axis = int(desc.substr(2)) as JoyAxis
                jm.axis_value = 1.0
                InputMap.action_add_event(action, jm)

# END OF FILE
