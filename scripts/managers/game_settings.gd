extends RefCounted
## Player settings saved on the phone (user://settings.cfg).
## Other scripts load this with load() + a null check, so a problem here can't break the game.

const FILE: String = "user://settings.cfg"
const DEFAULTS: Dictionary = {
    "touch_look": 1.0,      # multiplier on touch look speed
    "pad_look": 200.0,      # gamepad look speed, degrees per second
    "fov": 80.0,            # field of view in degrees
    "sprint_hold": 0.0,     # 0 = toggle, 1 = hold
    "tutorial_seen": 0.0,   # 1 = the first-time tutorial has been shown
    "ads_sens": 100.0,      # percent: look speed while aiming
    "ads_zoom": 100.0,      # percent: how much each gun zooms when aiming
    "reticle_size": 100.0,  # percent: size of the optic reticle
    "reticle_color": 0.0,   # index into RETICLE_COLORS
    "hit_markers": 1.0,     # 1 = show hit markers, 0 = hide them
    "outline": 0.0,         # 1 = draw an outline around reticles
    "outline_color": 0.0,   # index into OUTLINE_COLORS
    "pad_dz_look": 20.0,    # percent: right stick deadzone
    "pad_dz_move": 20.0,    # percent: left stick deadzone
    "pad_curve": 0.0,       # 0 = linear, 1 = smooth, 2 = precise
    "pad_invert_y": 0.0,    # 1 = invert gamepad look Y
    "pad_vibration": 1.0,   # 1 = gamepad vibration on, 0 = off
    "music_volume": 0.7,  # Music volume from 0.0 (muted) to 1.0 (full)
}

const RETICLE_COLORS: Array = [
    {"name": "RED", "color": Color(1.0, 0.2, 0.2)},
    {"name": "ORANGE", "color": Color(1.0, 0.6, 0.1)},
    {"name": "YELLOW", "color": Color(1.0, 0.92, 0.2)},
    {"name": "GREEN", "color": Color(0.3, 1.0, 0.3)},
    {"name": "CYAN", "color": Color(0.2, 0.9, 1.0)},
    {"name": "MAGENTA", "color": Color(1.0, 0.3, 0.9)},
    {"name": "WHITE", "color": Color(1.0, 1.0, 1.0)},
]

# Outline colors. "label" (optional) is the color the settings button text uses.
# RAINBOW is special: the reticle code cycles its hue.
const OUTLINE_COLORS: Array = [
    {"name": "BLACK", "color": Color(0.0, 0.0, 0.0), "label": Color(0.6, 0.6, 0.66)},
    {"name": "WHITE", "color": Color(1.0, 1.0, 1.0)},
    {"name": "RED", "color": Color(1.0, 0.15, 0.15)},
    {"name": "ORANGE", "color": Color(1.0, 0.5, 0.05)},
    {"name": "GOLD", "color": Color(1.0, 0.769, 0.0)},
    {"name": "YELLOW", "color": Color(1.0, 0.95, 0.2)},
    {"name": "LIME", "color": Color(0.6, 1.0, 0.1)},
    {"name": "GREEN", "color": Color(0.15, 0.9, 0.3)},
    {"name": "TEAL", "color": Color(0.1, 0.8, 0.7)},
    {"name": "CYAN", "color": Color(0.2, 0.9, 1.0)},
    {"name": "SKY BLUE", "color": Color(0.3, 0.6, 1.0)},
    {"name": "BLUE", "color": Color(0.2, 0.3, 1.0)},
    {"name": "PURPLE", "color": Color(0.6, 0.3, 1.0)},
    {"name": "MAGENTA", "color": Color(1.0, 0.25, 0.85)},
    {"name": "PINK", "color": Color(1.0, 0.55, 0.75)},
    {"name": "SILVER", "color": Color(0.72, 0.74, 0.8)},
    {"name": "RAINBOW", "color": Color(1.0, 0.5, 0.8), "rainbow": true},
]

var values: Dictionary = DEFAULTS.duplicate()


func _init() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(FILE) == OK:
        for key in DEFAULTS.keys():
            values[key] = float(cfg.get_value("settings", key, DEFAULTS[key]))


func get_value(key: String) -> float:
    return float(values.get(key, DEFAULTS.get(key, 0.0)))


func set_value(key: String, v: float) -> void:
    values[key] = v
    save()


## The chosen reticle color.
func reticle_color() -> Color:
    var idx: int = clampi(int(get_value("reticle_color")), 0, RETICLE_COLORS.size() - 1)
    var c: Color = RETICLE_COLORS[idx]["color"]
    return Color(c.r, c.g, c.b, 0.95)


## The chosen outline color.
func outline_color() -> Color:
    var idx: int = clampi(int(get_value("outline_color")), 0, OUTLINE_COLORS.size() - 1)
    var c: Color = OUTLINE_COLORS[idx]["color"]
    return Color(c.r, c.g, c.b, 0.95)


## True when the chosen outline color is the cycling RAINBOW.
func outline_is_rainbow() -> bool:
    var idx: int = clampi(int(get_value("outline_color")), 0, OUTLINE_COLORS.size() - 1)
    return bool(OUTLINE_COLORS[idx].get("rainbow", false))


func reset() -> void:
    var seen: float = get_value("tutorial_seen")
    values = DEFAULTS.duplicate()
    values["tutorial_seen"] = seen
    save()


func save() -> void:
    var cfg := ConfigFile.new()
    for key in values.keys():
        cfg.set_value("settings", key, values[key])
    cfg.save(FILE)
