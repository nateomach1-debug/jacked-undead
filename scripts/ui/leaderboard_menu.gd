extends Control
## Leaderboards screen: pick a map (arrows) and SOLO / CO-OP, then sort by
## ROUND, KILLS or HEADSHOTS. Shows the top 10 players (best per player).

const LB_PATH: String = "res://scripts/managers/leaderboard.gd"
const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"

const TABS: Array = [
    {"stat": "best_round", "text": "ROUND"},
    {"stat": "kills", "text": "KILLS"},
    {"stat": "headshots", "text": "HEADSHOTS"},
]

var _lb: Node = null
var _maps: Array = []
var _map_idx: int = 0
var _coop: bool = false
var _stat: String = "best_round"
var _req_id: int = 0

var _map_label: Label = null
var _mode_btn: Button = null
var _tab_btns: Dictionary = {}
var _grid: GridContainer = null
var _status: Label = null


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    var script = load(LB_PATH)
    if script != null:
        _lb = script.instance(get_tree())
        _maps = script.MAPS

    _add_backdrop()

    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    center.add_child(vbox)

    var title := Label.new()
    title.text = "LEADERBOARDS"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    vbox.add_child(title)

    # Map row: < MAP NAME >   SOLO/CO-OP
    var map_row := HBoxContainer.new()
    map_row.alignment = BoxContainer.ALIGNMENT_CENTER
    map_row.add_theme_constant_override("separation", 12)
    vbox.add_child(map_row)

    var prev := Button.new()
    prev.text = "<"
    prev.custom_minimum_size = Vector2(70, 56)
    prev.pressed.connect(_step_map.bind(-1))
    map_row.add_child(prev)

    _map_label = Label.new()
    _map_label.theme_type_variation = &"GoldLabel"
    _map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _map_label.custom_minimum_size = Vector2(360, 56)
    _map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _map_label.add_theme_font_size_override("font_size", 26)
    map_row.add_child(_map_label)

    var nxt := Button.new()
    nxt.text = ">"
    nxt.custom_minimum_size = Vector2(70, 56)
    nxt.pressed.connect(_step_map.bind(1))
    map_row.add_child(nxt)

    _mode_btn = Button.new()
    _mode_btn.custom_minimum_size = Vector2(150, 56)
    _mode_btn.pressed.connect(_toggle_mode)
    map_row.add_child(_mode_btn)

    # Sort tabs.
    var tab_row := HBoxContainer.new()
    tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
    tab_row.add_theme_constant_override("separation", 12)
    vbox.add_child(tab_row)
    for t in TABS:
        var b := Button.new()
        b.text = str(t["text"])
        b.custom_minimum_size = Vector2(170, 52)
        b.pressed.connect(_set_stat.bind(str(t["stat"])))
        tab_row.add_child(b)
        _tab_btns[str(t["stat"])] = b

    # Table card.
    var card := PanelContainer.new()
    card.theme_type_variation = &"CardPanel"
    card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    vbox.add_child(card)
    _grid = GridContainer.new()
    _grid.columns = 5
    _grid.add_theme_constant_override("h_separation", 26)
    _grid.add_theme_constant_override("v_separation", 4)
    card.add_child(_grid)

    _status = Label.new()
    _status.theme_type_variation = &"SmallLabel"
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.add_theme_font_size_override("font_size", 18)
    vbox.add_child(_status)

    var back := Button.new()
    back.text = "BACK"
    back.custom_minimum_size = Vector2(340, 56)
    back.add_theme_font_size_override("font_size", 22)
    back.pressed.connect(queue_free)
    vbox.add_child(back)

    _refresh()


func _add_backdrop() -> void:
    var script = load(BACKDROP_PATH)
    if script == null:
        var bg := ColorRect.new()
        bg.color = Color(0.055, 0.055, 0.067, 1.0)
        add_child(bg)
        bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        return
    var backdrop := Control.new()
    backdrop.set_script(script)
    add_child(backdrop)


func _step_map(dir: int) -> void:
    if _maps.is_empty():
        return
    _map_idx = (_map_idx + dir + _maps.size()) % _maps.size()
    _refresh()


func _toggle_mode() -> void:
    _coop = not _coop
    _refresh()


func _set_stat(stat: String) -> void:
    _stat = stat
    _refresh()


func _board_id() -> String:
    var id: String = str(_maps[_map_idx]["id"])
    if _coop:
        id += ":coop"
    return id


func _refresh() -> void:
    if _maps.is_empty() or _lb == null:
        _status.text = "LEADERBOARD UNAVAILABLE"
        return
    _map_label.text = str(_maps[_map_idx]["title"])
    _mode_btn.text = "CO-OP" if _coop else "SOLO"
    for s in _tab_btns.keys():
        _tab_btns[s].theme_type_variation = &"MainButton" if s == _stat else &""
    _clear_grid()
    _status.text = "LOADING..."
    _req_id += 1
    _status.text = "TEST: NETWORK OFF"


func _on_rows(ok: bool, rows: Array, id: int) -> void:
    if id != _req_id:
        return
    _clear_grid()
    if not ok:
        _status.text = "CAN'T REACH THE LEADERBOARD (CHECK INTERNET)"
        return
    _add_cell("#", true, false)
    _add_cell("PLAYER", true, false)
    _add_cell("ROUND", true, _stat == "best_round")
    _add_cell("KILLS", true, _stat == "kills")
    _add_cell("HEADSHOTS", true, _stat == "headshots")
    var rank: int = 1
    for r in rows:
        _add_cell(str(rank), false, false)
        _add_cell(str(r.get("player_name", "?")), false, false)
        _add_cell(str(int(r.get("best_round", 0))), false, _stat == "best_round")
        _add_cell(str(int(r.get("kills", 0))), false, _stat == "kills")
        _add_cell(str(int(r.get("headshots", 0))), false, _stat == "headshots")
        rank += 1
    _status.text = "" if not rows.is_empty() else "NO RUNS YET - BE THE FIRST"


func _clear_grid() -> void:
    for c in _grid.get_children():
        _grid.remove_child(c)
        c.queue_free()


func _add_cell(text: String, header: bool, highlight: bool) -> void:
    var l := Label.new()
    l.text = text.to_upper()
    l.add_theme_font_size_override("font_size", 20)
    if header or highlight:
        l.theme_type_variation = &"GoldLabel"
    _grid.add_child(l)

# END OF FILE
