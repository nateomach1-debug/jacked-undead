extends Control
## Leaderboards screen (self-contained): pick a map (arrows) and SOLO / CO-OP,
## then sort by ROUND, KILLS or HEADSHOTS. Shows the top 10 players.
## The MODE button cycles NORMAL and every custom mode combination that has
## at least one run on that map (solo or co-op).

const URL: String = "https://qnomdtgtfdocdpoaqyxa.supabase.co/rest/v1/"
const KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFub21kdGd0ZmRvY2Rwb2FxeXhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2NDAxNTIsImV4cCI6MjEwMjIxNjE1Mn0.A8Duae95xq3eAlHBTJokspTMC-pn_1A2Z2wQhP2PSXI"
const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"

const MAPS: Array = [
    {"id": "main", "title": "TRAINING GYM"},
    {"id": "multi_room_map", "title": "MULTI-ROOM"},
    {"id": "building_map", "title": "BUILDING"},
    {"id": "cheese_cube_map", "title": "CHEESE CUBE"},
    {"id": "solar_substation", "title": "SOLAR SUBSTATION"},
    {"id": "challenge_map", "title": "CHALLENGE MAP"},
    {"id": "gym_compound", "title": "GYM COMPOUND"},
    {"id": "generated_gym_map", "title": "RANDOM GYM"},
]

const TABS: Array = [
    {"stat": "best_round", "text": "ROUND"},
    {"stat": "kills", "text": "KILLS"},
    {"stat": "headshots", "text": "HEADSHOTS"},
]

## Readable names for custom mode code parts. Unknown parts show as typed (uppercase).
const TOKEN_NAMES: Dictionary = {
    "nopr": "NO PR",
    "noloot": "NO LOCKER",
    "hp15": "HP X1.5",
}

var _map_idx: int = 0
var _coop: bool = false
var _stat: String = "best_round"
var _mode_code: String = ""          # "" = NORMAL, otherwise a GameManager.custom_code()
var _modes: Array = [""]             # codes that have runs on the current map / solo-coop
var _req_id: int = 0
var _modes_req_id: int = 0

var _map_label: Label = null
var _mode_btn: Button = null
var _custom_btn: Button = null
var _tab_btns: Dictionary = {}
var _grid: GridContainer = null
var _status: Label = null


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

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
    _map_label.text = "TRAINING GYM"
    _map_label.theme_type_variation = &"GoldLabel"
    _map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _map_label.custom_minimum_size = Vector2(360, 56)
    _map_label.add_theme_font_size_override("font_size", 26)
    map_row.add_child(_map_label)

    var nxt := Button.new()
    nxt.text = ">"
    nxt.custom_minimum_size = Vector2(70, 56)
    nxt.pressed.connect(_step_map.bind(1))
    map_row.add_child(nxt)

    _mode_btn = Button.new()
    _mode_btn.text = "SOLO"
    _mode_btn.custom_minimum_size = Vector2(150, 56)
    _mode_btn.pressed.connect(_toggle_mode)
    map_row.add_child(_mode_btn)

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

    _custom_btn = Button.new()
    _custom_btn.text = "MODE: NORMAL"
    _custom_btn.custom_minimum_size = Vector2(340, 52)
    _custom_btn.clip_text = true
    _custom_btn.add_theme_font_size_override("font_size", 18)
    _custom_btn.pressed.connect(_cycle_custom)
    tab_row.add_child(_custom_btn)

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
    _status.text = "LOADING..."
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

    # Draw the screen first, then load the scores.
    await get_tree().process_frame
    if is_inside_tree():
        _refresh()
        _load_modes()


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
    _map_idx = (_map_idx + dir + MAPS.size()) % MAPS.size()
    _refresh()
    _load_modes()


func _toggle_mode() -> void:
    _coop = not _coop
    _refresh()
    _load_modes()


func _set_stat(stat: String) -> void:
    _stat = stat
    _refresh()


## Steps through NORMAL and the custom combos that have runs here.
func _cycle_custom() -> void:
    if _modes.size() <= 1:
        return
    var i: int = _modes.find(_mode_code)
    _mode_code = str(_modes[(i + 1) % _modes.size()])
    _refresh()


## Board name start for custom boards of the current map and SOLO / CO-OP.
func _custom_prefix() -> String:
    var id: String = str(MAPS[_map_idx]["id"])
    if _coop:
        id += ":coop"
    return id + ":custom:"


func _board_id() -> String:
    var id: String = str(MAPS[_map_idx]["id"])
    if _coop:
        id += ":coop"
    if _mode_code != "":
        id += ":custom:" + _mode_code
    return id


func _mode_text(code: String) -> String:
    if code == "":
        return "NORMAL"
    var parts := PackedStringArray()
    for t in code.split("-"):
        parts.append(str(TOKEN_NAMES.get(t, t.to_upper())))
    return " + ".join(parts)


func _update_custom_btn() -> void:
    _custom_btn.text = "MODE: " + _mode_text(_mode_code)
    _custom_btn.disabled = _modes.size() <= 1
    _custom_btn.modulate = Color(1.0, 0.8, 0.1, 1.0) if _mode_code != "" else Color(1.0, 1.0, 1.0, 1.0)


## Asks the server which custom combos have runs for this map and SOLO / CO-OP.
func _load_modes() -> void:
    _modes_req_id += 1
    var my_id: int = _modes_req_id
    # Until the answer arrives, offer NORMAL (and the mode already shown).
    _modes = [""]
    if _mode_code != "":
        _modes.append(_mode_code)
    _update_custom_btn()

    var prefix: String = _custom_prefix()
    var req := HTTPRequest.new()
    req.timeout = 10.0
    add_child(req)
    req.request_completed.connect(_on_modes_http.bind(req, my_id, prefix))
    var url: String = "%sju_best?select=board&board=like.%s*&limit=1000" % [URL, prefix.uri_encode()]
    var headers := PackedStringArray(["apikey: " + KEY, "Authorization: Bearer " + KEY])
    if req.request(url, headers) != OK:
        req.queue_free()


func _on_modes_http(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, req: HTTPRequest, my_id: int, prefix: String) -> void:
    req.queue_free()
    if my_id != _modes_req_id:
        return
    if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
        return
    var data = JSON.parse_string(body.get_string_from_utf8())
    if not (data is Array):
        return
    var found: Dictionary = {}
    for r in data:
        var b: String = str(r.get("board", ""))
        if b.begins_with(prefix):
            var c: String = b.substr(prefix.length())
            if c != "":
                found[c] = true
    var codes: Array = found.keys()
    codes.sort()
    _modes = [""]
    _modes.append_array(codes)
    if not _modes.has(_mode_code):
        _mode_code = ""
        _refresh()
    else:
        _update_custom_btn()


func _refresh() -> void:
    _map_label.text = str(MAPS[_map_idx]["title"])
    _mode_btn.text = "CO-OP" if _coop else "SOLO"
    _update_custom_btn()
    for s in _tab_btns.keys():
        var tab: Button = _tab_btns[s]
        if s == _stat:
            tab.modulate = Color(1.0, 0.8, 0.1, 1.0)
        else:
            tab.modulate = Color(1.0, 1.0, 1.0, 1.0)
    _clear_grid()
    _status.text = "LOADING..."
    _req_id += 1
    var my_id: int = _req_id

    var req := HTTPRequest.new()
    req.timeout = 10.0
    add_child(req)
    req.request_completed.connect(_on_http.bind(req, my_id))
    var url: String = "%sju_best?board=eq.%s&select=player_name,best_round,kills,headshots&order=%s.desc&limit=10" % [URL, _board_id().uri_encode(), _stat]
    var headers := PackedStringArray(["apikey: " + KEY, "Authorization: Bearer " + KEY])
    if req.request(url, headers) != OK:
        req.queue_free()
        _show_rows(false, [], my_id)


func _on_http(result: int, code: int, _h: PackedStringArray, body: PackedByteArray, req: HTTPRequest, my_id: int) -> void:
    req.queue_free()
    if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
        _show_rows(false, [], my_id)
        return
    var data = JSON.parse_string(body.get_string_from_utf8())
    if data is Array:
        _show_rows(true, data, my_id)
    else:
        _show_rows(false, [], my_id)


func _show_rows(ok: bool, rows: Array, id: int) -> void:
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
