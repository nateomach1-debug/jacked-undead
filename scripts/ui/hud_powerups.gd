extends Control
## HUD for power-ups: one row per active power-up (coloured ring that drains,
## short code, name, seconds left) plus a centre banner on pickup.
## Reads time_left() from the "powerup_manager" node every frame, so each
## phone shows its own countdown. Rows blink during the last 5 seconds.
## Built by hud.gd with load() + a null check, so a problem here can't break the HUD.

const MGR_GROUP: String = "powerup_manager"
const ORDER: Array = ["max_lift", "pre_workout", "full_rack", "pr_day", "hot_yoga", "ice_bath", "cardio_kick", "spotter"]
const INFO: Dictionary = {
    "max_lift": {"name": "MAX LIFT", "short": "ML", "desc": "INSTA-KILL", "color": Color(1.0, 0.25, 0.2)},
    "pre_workout": {"name": "PRE-WORKOUT SURGE", "short": "PW", "desc": "DOUBLE GAINS", "color": Color(0.95, 0.75, 0.1)},
    "full_rack": {"name": "FULL RACK", "short": "FR", "desc": "AMMO REFILLED", "color": Color(0.7, 0.75, 0.85)},
    "pr_day": {"name": "PR DAY", "short": "PR", "desc": "GUN HITS HARDER", "color": Color(0.7, 0.4, 1.0)},
    "hot_yoga": {"name": "HOT YOGA", "short": "HY", "desc": "BULLETS IGNITE", "color": Color(1.0, 0.5, 0.1)},
    "ice_bath": {"name": "ICE BATH", "short": "IB", "desc": "ZOMBIES SLOWED", "color": Color(0.3, 0.8, 1.0)},
    "cardio_kick": {"name": "CARDIO KICK", "short": "CK", "desc": "FASTER + INFINITE SPRINT", "color": Color(0.3, 1.0, 0.45)},
    "spotter": {"name": "SPOTTER", "short": "SP", "desc": "HALF DAMAGE + INSTANT REVIVES", "color": Color(0.35, 0.55, 1.0)},
}
const ROW_H: float = 48.0
const ROW_GAP: float = 6.0
const RADIUS: float = 20.0
const BLINK_TIME: float = 5.0
const BANNER_TOP: float = 330.0

var _mgr: Node = null
var _dur: Dictionary = {}       # id -> full duration of the current run
var _rows: Array = []           # [id, seconds left] for every active power-up
var _time: float = 0.0
var _had_rows: bool = false
var _banner: Label = null
var _banner_tween: Tween = null


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called by hud.gd: creates the centre banner on the HUD layer.
func attach(hud: Node) -> void:
    _banner = Label.new()
    _banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _banner.add_theme_font_size_override("font_size", 44)
    _banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
    _banner.add_theme_constant_override("outline_size", 10)
    _banner.visible = false
    hud.add_child(_banner)
    _banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, int(BANNER_TOP))
    _banner.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _process(delta: float) -> void:
    _time += delta
    if _mgr == null or not is_instance_valid(_mgr):
        _mgr = get_tree().get_first_node_in_group(MGR_GROUP)
        if _mgr != null and _mgr.has_signal("powerup_started"):
            _mgr.powerup_started.connect(_on_started)
    _rows.clear()
    if _mgr != null:
        for id in ORDER:
            var left: float = float(_mgr.time_left(id))
            if left > 0.0:
                _dur[id] = maxf(float(_dur.get(id, 0.0)), left)
                _rows.append([id, left])
            else:
                _dur.erase(id)
    if not _rows.is_empty() or _had_rows:
        queue_redraw()
    _had_rows = not _rows.is_empty()


func _on_started(id: String, duration: float) -> void:
    if duration > 0.0:
        _dur[id] = duration
    _show_banner(id)


func _show_banner(id: String) -> void:
    if _banner == null or not INFO.has(id):
        return
    var info: Dictionary = INFO[id]
    _banner.text = str(info["name"]) + "\n" + str(info["desc"])
    _banner.add_theme_color_override("font_color", info["color"])
    _banner.modulate.a = 1.0
    _banner.visible = true
    if _banner_tween != null:
        _banner_tween.kill()
    _banner_tween = create_tween()
    _banner_tween.tween_interval(1.6)
    _banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
    _banner_tween.tween_callback(_banner.hide)


func _draw() -> void:
    var font: Font = ThemeDB.fallback_font
    var i: int = 0
    for row in _rows:
        var id: String = str(row[0])
        var left: float = float(row[1])
        var info: Dictionary = INFO.get(id, {})
        if info.is_empty():
            continue
        var col: Color = info["color"]
        var dur: float = maxf(float(_dur.get(id, left)), 0.1)
        var frac: float = clampf(left / dur, 0.0, 1.0)
        var a: float = 1.0
        if left <= BLINK_TIME and int(_time * 4.0) % 2 == 0:
            a = 0.3
        var y: float = float(i) * (ROW_H + ROW_GAP)
        var c := Vector2(RADIUS + 4.0, y + ROW_H * 0.5)

        draw_circle(c, RADIUS, Color(0.0, 0.0, 0.0, 0.55 * a))
        draw_arc(c, RADIUS - 3.0, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.15 * a), 5.0, true)
        if frac > 0.001:
            draw_arc(c, RADIUS - 3.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color(col.r, col.g, col.b, a), 5.0, true)

        var short: String = str(info["short"])
        var sw: float = font.get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
        var sp := Vector2(c.x - sw * 0.5, c.y + 6.0)
        draw_string_outline(font, sp, short, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, a))
        draw_string(font, sp, short, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, a))

        var tx: float = c.x + RADIUS + 10.0
        var name_pos := Vector2(tx, y + 20.0)
        draw_string_outline(font, name_pos, str(info["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, a))
        draw_string(font, name_pos, str(info["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.95, 0.9, a))
        var secs: String = "%ds" % int(ceil(left))
        var sec_pos := Vector2(tx, y + 43.0)
        draw_string_outline(font, sec_pos, secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, a))
        draw_string(font, sec_pos, secs, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(col.r, col.g, col.b, a))
        i += 1
