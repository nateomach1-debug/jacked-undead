extends RefCounted
## Saved position / size / opacity of the on-screen HUD (user://hud_layout.cfg).
## Loaded with load() + a null check, so a problem here can't break the game.
## corner: bl/br bottom corners, tl/tr top corners, tc/bc top/bottom centre.
## cx / cy = distance from that corner (or from the centre line for tc/bc)
## to the element's centre, in pixels. w / h = size of the editor box.

const FILE: String = "user://hud_layout.cfg"
const ELEMENTS: Array = [
    {"id": "joystick", "group": "touch", "title": "JOYSTICK", "w": 360.0, "h": 360.0, "corner": "bl", "cx": 250.0, "cy": 240.0, "scalable": true},
    {"id": "use", "group": "touch", "title": "USE", "w": 150.0, "h": 150.0, "corner": "br", "cx": 95.0, "cy": 95.0, "scalable": true},
    {"id": "reload", "group": "touch", "title": "RELOAD", "w": 150.0, "h": 150.0, "corner": "br", "cx": 95.0, "cy": 260.0, "scalable": true},
    {"id": "aim", "group": "touch", "title": "AIM", "w": 150.0, "h": 150.0, "corner": "br", "cx": 95.0, "cy": 425.0, "scalable": true},
    {"id": "jump", "group": "touch", "title": "JUMP", "w": 150.0, "h": 150.0, "corner": "br", "cx": 260.0, "cy": 95.0, "scalable": true},
    {"id": "sprint", "group": "touch", "title": "SPRINT", "w": 150.0, "h": 150.0, "corner": "br", "cx": 260.0, "cy": 260.0, "scalable": true},
    {"id": "switch", "group": "touch", "title": "SWAP", "w": 150.0, "h": 150.0, "corner": "br", "cx": 260.0, "cy": 425.0, "scalable": true},
    {"id": "hud_stats", "group": "hud", "title": "HP / AMMO / GAINS", "w": 300.0, "h": 176.0, "corner": "tl", "cx": 174.0, "cy": 112.0, "scalable": true},
    {"id": "hud_round", "group": "hud", "title": "ROUND + ZOMBIES", "w": 280.0, "h": 130.0, "corner": "tc", "cx": 0.0, "cy": 77.0, "scalable": true},
    {"id": "hud_perks", "group": "hud", "title": "PERKS", "w": 440.0, "h": 52.0, "corner": "bc", "cx": 56.0, "cy": 254.0, "scalable": true},
    {"id": "hud_prompt", "group": "hud", "title": "USE PROMPT", "w": 520.0, "h": 52.0, "corner": "bc", "cx": 0.0, "cy": 49.0, "scalable": true},
    {"id": "hud_coords", "group": "hud", "title": "COORDS", "w": 276.0, "h": 36.0, "corner": "tr", "cx": 162.0, "cy": 42.0, "scalable": true},
]

## id -> {"x": fraction, "y": fraction, "s": scale, "a": opacity}
var data: Dictionary = {}


func _init() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(FILE) != OK:
        return
    for sec in cfg.get_sections():
        if info(sec).is_empty():
            continue
        var d: Dictionary = {}
        for key in ["x", "y", "s", "a"]:
            if cfg.has_section_key(sec, key):
                d[key] = float(cfg.get_value(sec, key))
        if not d.is_empty():
            data[sec] = d


func info(id: String) -> Dictionary:
    for e in ELEMENTS:
        if e["id"] == id:
            return e
    return {}


func has_custom() -> bool:
    return not data.is_empty()


func has_entry(id: String) -> bool:
    return data.has(id)


## True when any element of that group ("touch" or "hud") has been changed.
func has_group(group: String) -> bool:
    for id in data.keys():
        if str(info(id).get("group", "")) == group:
            return true
    return false


## Centre of the element in screen pixels (saved spot, or the default one).
func center(id: String, vp: Vector2) -> Vector2:
    var d: Dictionary = data.get(id, {})
    if d.has("x") and d.has("y"):
        return Vector2(float(d["x"]) * vp.x, float(d["y"]) * vp.y)
    var e: Dictionary = info(id)
    if e.is_empty():
        return vp / 2.0
    var x: float = float(e["cx"])
    var y: float = float(e["cy"])
    var corner: String = str(e["corner"])
    var px: float = x
    if corner == "br" or corner == "tr":
        px = vp.x - x
    elif corner == "tc" or corner == "bc":
        px = vp.x / 2.0 + x
    var py: float = y
    if corner == "bl" or corner == "br" or corner == "bc":
        py = vp.y - y
    return Vector2(px, py)


func scale_of(id: String) -> float:
    var e: Dictionary = info(id)
    if e.is_empty() or not bool(e.get("scalable", true)):
        return 1.0
    var d: Dictionary = data.get(id, {})
    return float(d.get("s", 1.0))


func alpha_of(id: String) -> float:
    var d: Dictionary = data.get(id, {})
    return float(d.get("a", 1.0))


func _entry(id: String) -> Dictionary:
    if not data.has(id):
        data[id] = {}
    return data[id]


## Writes the current (default) spot into the entry if it has none yet.
func pin(id: String, vp: Vector2) -> void:
    var d: Dictionary = _entry(id)
    if not (d.has("x") and d.has("y")):
        set_center(id, center(id, vp), vp)


func set_center(id: String, c: Vector2, vp: Vector2) -> void:
    var d: Dictionary = _entry(id)
    d["x"] = c.x / maxf(vp.x, 1.0)
    d["y"] = c.y / maxf(vp.y, 1.0)


func set_scale(id: String, v: float) -> void:
    _entry(id)["s"] = v


func set_alpha(id: String, v: float) -> void:
    _entry(id)["a"] = v


func reset_one(id: String) -> void:
    data.erase(id)


func reset_all() -> void:
    data.clear()


func save() -> void:
    var cfg := ConfigFile.new()
    for id in data.keys():
        var d: Dictionary = data[id]
        for key in d.keys():
            cfg.set_value(id, key, d[key])
    cfg.save(FILE)

# END OF FILE
