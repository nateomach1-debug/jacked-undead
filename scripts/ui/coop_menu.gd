extends Control
## Co-op screen: host or join a game. The host also gets MAP and START.
## Default is a 4-letter room code (WebRTC, works on web and Android).
## The IP mode (Android to Android) is the backup.
## Uses on-screen pads because the phone keyboard won't open here:
## a letter pad for the room code, a number pad for the host IP and a
## letter pad for your display name.

# Keep in sync with the maps listed in map_select.gd.
const MAPS: Array = [
    {"title": "GYM ARENA", "path": "res://scenes/main/main.tscn"},
    {"title": "BUILDING", "path": "res://scenes/main/building_map.tscn"},
    {"title": "MULTI-ROOM", "path": "res://scenes/main/multi_room_map.tscn"},
    {"title": "GYM COMPOUND", "path": "res://scenes/main/gym_compound.tscn"},
    {"title": "CHALLENGE MAP", "path": "res://scenes/main/challenge_map.tscn"},
    {"title": "CHEESE CUBE", "path": "res://scenes/main/cheese_cube_map.tscn"},
]

const NAME_KEYS: Array = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
    "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
    "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3",
    "4", "5", "6", "7", "8", "9", "SPACE", "DEL", "OK", "CANCEL",
]

# Same letters the room codes use (no I or O).
const CODE_KEYS: Array = [
    "A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M",
    "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
]
const CODE_LENGTH: int = 4

const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const DIVIDER_PATH: String = "res://scripts/ui/poster_divider.gd"

var _status: Label
var _ip_label: Label
var _map_button: Button
var _start_button: Button
var _name_button: Button
var _name_pad: Control
var _name_display: Label
var _name_buffer: String = ""
var _ip: String = ""
var _code: String = ""
var _hosted_code: String = ""
var _ip_mode: bool = false
var _code_label: Label
var _code_box: VBoxContainer
var _ip_box: VBoxContainer
var _mode_button: Button
var _guide_button: Button
var _map_index: int = 0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    _add_backdrop(self)

    var margin := MarginContainer.new()
    add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 6)
    margin.add_child(outer)

    var title := Label.new()
    title.text = "CO-OP"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    outer.add_child(title)

    _add_divider(outer)

    var center := CenterContainer.new()
    center.size_flags_vertical = Control.SIZE_EXPAND_FILL
    outer.add_child(center)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 40)
    center.add_child(row)

    # Left side: room code pad (default) or IP number pad (backup)
    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation", 10)
    row.add_child(left)

    _code_box = VBoxContainer.new()
    _code_box.add_theme_constant_override("separation", 10)
    left.add_child(_code_box)
    _build_code_box(_code_box)

    _ip_box = VBoxContainer.new()
    _ip_box.add_theme_constant_override("separation", 10)
    _ip_box.visible = false
    left.add_child(_ip_box)

    var ip_card := PanelContainer.new()
    ip_card.theme_type_variation = &"CardPanel"
    _ip_box.add_child(ip_card)
    _ip_label = Label.new()
    _ip_label.theme_type_variation = &"GoldLabel"
    _ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _ip_label.add_theme_font_size_override("font_size", 30)
    ip_card.add_child(_ip_label)

    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    _ip_box.add_child(grid)
    for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "DEL"]:
        var b := Button.new()
        b.text = key
        b.custom_minimum_size = Vector2(130, 72)
        b.add_theme_font_size_override("font_size", 30)
        b.pressed.connect(_on_key.bind(key))
        grid.add_child(b)

    _add_quick_ip_buttons(_ip_box)

    # Right side: status + name / host / join / map / start / back
    var right := VBoxContainer.new()
    right.add_theme_constant_override("separation", 10)
    row.add_child(right)

    var status_card := PanelContainer.new()
    right.add_child(status_card)
    _status = Label.new()
    _status.text = "CO-OP (ROOM CODE)"
    _status.custom_minimum_size = Vector2(440, 70)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _status.add_theme_font_size_override("font_size", 22)
    status_card.add_child(_status)

    _name_button = _make_button("", _on_name, 64)
    right.add_child(_name_button)

    var host_row := HBoxContainer.new()
    host_row.add_theme_constant_override("separation", 10)
    right.add_child(host_row)
    var host_b := _make_button("HOST GAME", _on_host, 72, &"MainButton")
    host_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    host_row.add_child(host_b)
    var join_b := _make_button("JOIN GAME", _on_join, 72)
    join_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    host_row.add_child(join_b)

    _map_button = _make_button("", _on_map, 72)
    _map_button.visible = false
    right.add_child(_map_button)

    _start_button = _make_button("START GAME", _on_start, 80, &"MainButton")
    _start_button.visible = false
    right.add_child(_start_button)

    # The browser can't use the IP backup, so the mode button is for Android only.
    _mode_button = _make_button("", _on_mode, 56)
    _mode_button.visible = not OS.has_feature("web")
    right.add_child(_mode_button)

    _guide_button = _make_button("TAILSCALE GUIDE", _on_guide, 60)
    _guide_button.visible = false
    right.add_child(_guide_button)
    right.add_child(_make_button("BACK", _on_back, 64))

    # Pre-fill the first three numbers from this phone's own Wi-Fi address.
    var mine: String = NetManager.get_local_ip()
    if mine != "unknown":
        _ip = mine.substr(0, mine.rfind(".") + 1)
    _refresh_ip()
    _refresh_code()
    _refresh_map()
    _refresh_name_button()
    _apply_mode()

    _build_name_pad()

    NetManager.status_changed.connect(_on_status)
    NetManager.room_code_ready.connect(_on_room_code)


## Charcoal background with a vignette (plain dark fill if the script is missing).
func _add_backdrop(parent: Control) -> void:
    var script = load(BACKDROP_PATH)
    if script == null:
        var bg := ColorRect.new()
        bg.color = Color(0.055, 0.055, 0.067, 1.0)
        parent.add_child(bg)
        bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        return
    var backdrop := Control.new()
    backdrop.set_script(script)
    parent.add_child(backdrop)
func _add_divider(parent: Control) -> void:
    var script = load(DIVIDER_PATH)
    if script == null:
        return
    var divider := Control.new()
    divider.set_script(script)
    divider.custom_minimum_size = Vector2(0, 24)
    parent.add_child(divider)


func _make_button(label: String, callback: Callable, height: int = 72, kind: StringName = &"") -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(440, height)
    b.add_theme_font_size_override("font_size", 26)
    if kind != &"":
        b.theme_type_variation = kind
    b.pressed.connect(callback)
    return b


func _on_key(key: String) -> void:
    if key == "DEL":
        if _ip.length() > 0:
            _ip = _ip.substr(0, _ip.length() - 1)
    elif _ip.length() < 15:
        _ip += key
    _refresh_ip()


# ---------- room code pad ----------

func _build_code_box(parent: Control) -> void:
    var card := PanelContainer.new()
    card.theme_type_variation = &"CardPanel"
    parent.add_child(card)
    _code_label = Label.new()
    _code_label.theme_type_variation = &"GoldLabel"
    _code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _code_label.add_theme_font_size_override("font_size", 30)
    card.add_child(_code_label)

    var grid := GridContainer.new()
    grid.columns = 6
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 6)
    parent.add_child(grid)
    for key in CODE_KEYS:
        var b := Button.new()
        b.text = str(key)
        b.custom_minimum_size = Vector2(72, 62)
        b.add_theme_font_size_override("font_size", 28)
        b.pressed.connect(_on_code_key.bind(str(key)))
        grid.add_child(b)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    parent.add_child(row)
    for item in [["CLEAR", &"DangerButton"], ["DEL", &""]]:
        var b := Button.new()
        b.text = str(item[0])
        b.custom_minimum_size = Vector2(225, 60)
        b.add_theme_font_size_override("font_size", 24)
        if item[1] != &"":
            b.theme_type_variation = item[1]
        b.pressed.connect(_on_code_key.bind(str(item[0])))
        row.add_child(b)


func _on_code_key(key: String) -> void:
    _hosted_code = ""
    if key == "CLEAR":
        _code = ""
    elif key == "DEL":
        if _code.length() > 0:
            _code = _code.substr(0, _code.length() - 1)
    elif _code.length() < CODE_LENGTH:
        _code += key
    _refresh_code()


func _refresh_code() -> void:
    if _hosted_code != "":
        _code_label.text = "YOUR CODE: " + _hosted_code
    else:
        _code_label.text = "ROOM CODE: " + (_code if _code != "" else "_")


func _on_room_code(code: String) -> void:
    _hosted_code = code
    _refresh_code()


## Switches between the room code pad and the IP backup pad.
func _on_mode() -> void:
    _ip_mode = not _ip_mode
    NetManager.leave()
    _map_button.visible = false
    _start_button.visible = false
    _hosted_code = ""
    _refresh_code()
    _apply_mode()


func _apply_mode() -> void:
    _code_box.visible = not _ip_mode
    _ip_box.visible = _ip_mode
    _guide_button.visible = _ip_mode
    if _ip_mode:
        _mode_button.text = "MODE: IP (BACKUP)"
        _status.text = "CO-OP (SAME WI-FI OR TAILSCALE)"
    else:
        _mode_button.text = "MODE: ROOM CODE"
        _status.text = "CO-OP (ROOM CODE)"


func _refresh_ip() -> void:
    _ip_label.text = "HOST IP: " + (_ip if _ip != "" else "_")


func _refresh_map() -> void:
    _map_button.text = "MAP: " + str(_maps()[_map_index % _maps().size()]["title"])


func _refresh_name_button() -> void:
    var n: String = NetManager.player_name
    _name_button.text = "NAME: " + (n.to_upper() if n != "" else "(AUTO)")


# ---------- name pad ----------

func _build_name_pad() -> void:
    _name_pad = Control.new()
    _name_pad.mouse_filter = Control.MOUSE_FILTER_STOP
    _name_pad.visible = false
    add_child(_name_pad)
    _name_pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    _add_backdrop(_name_pad)

    var center := CenterContainer.new()
    _name_pad.add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    center.add_child(box)

    var hint := Label.new()
    hint.text = "ENTER YOUR NAME"
    hint.theme_type_variation = &"SmallLabel"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 20)
    box.add_child(hint)

    _name_display = Label.new()
    _name_display.theme_type_variation = &"TitleLabel"
    _name_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _name_display.add_theme_font_size_override("font_size", 40)
    box.add_child(_name_display)

    var keys := GridContainer.new()
    keys.columns = 10
    keys.add_theme_constant_override("h_separation", 6)
    keys.add_theme_constant_override("v_separation", 6)
    box.add_child(keys)
    for key in NAME_KEYS:
        var b := Button.new()
        b.text = str(key)
        b.custom_minimum_size = Vector2(96, 70)
        b.add_theme_font_size_override("font_size", 24 if str(key).length() > 2 else 30)
        if key == "OK":
            b.theme_type_variation = &"MainButton"
        elif key == "CANCEL":
            b.theme_type_variation = &"DangerButton"
        b.pressed.connect(_on_name_key.bind(str(key)))
        keys.add_child(b)


func _on_name() -> void:
    _name_buffer = NetManager.player_name
    _refresh_name_display()
    _name_pad.visible = true


func _on_name_key(key: String) -> void:
    if key == "DEL":
        if _name_buffer.length() > 0:
            _name_buffer = _name_buffer.substr(0, _name_buffer.length() - 1)
    elif key == "SPACE":
        if _name_buffer.length() < NetManager.MAX_NAME_LENGTH:
            _name_buffer += " "
    elif key == "OK":
        NetManager.set_player_name(_name_buffer)
        _refresh_name_button()
        _name_pad.visible = false
        return
    elif key == "CANCEL":
        _name_pad.visible = false
        return
    elif _name_buffer.length() < NetManager.MAX_NAME_LENGTH:
        _name_buffer += key
    _refresh_name_display()


func _refresh_name_display() -> void:
    _name_display.text = (_name_buffer if _name_buffer != "" else "_")


# ---------- host / join ----------

func _on_host() -> void:
    _hosted_code = ""
    _refresh_code()
    var ok: bool = NetManager.host_game_ip() if _ip_mode else NetManager.host_game()
    if ok:
        _map_button.visible = true
        _start_button.visible = true


func _on_join() -> void:
    _map_button.visible = false
    _start_button.visible = false
    if _ip_mode:
        NetManager.join_game_ip(_ip)
    elif _code.length() < CODE_LENGTH:
        _status.text = "TYPE THE %d-LETTER ROOM CODE" % CODE_LENGTH
    else:
        NetManager.join_game(_code)


func _on_map() -> void:
    _map_index = (_map_index + 1) % _maps().size()
    _refresh_map()


func _on_start() -> void:
    NetManager.start_game_on(str(_maps()[_map_index % _maps().size()]["path"]))


func _on_guide() -> void:
    var guide_script = load("res://scripts/ui/tailscale_guide.gd")
    if guide_script != null:
        get_tree().root.add_child(guide_script.new())


func _on_back() -> void:
    NetManager.leave()
    queue_free()


func _on_status(text: String) -> void:
    _status.text = text.to_upper()


## CLEAR empties the IP; 100. starts a Tailscale address.
func _add_quick_ip_buttons(parent: Control) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    for item in [["CLEAR", "", &"DangerButton"], ["100.  ONLINE", "100.", &""]]:
        var b := Button.new()
        b.text = str(item[0])
        b.custom_minimum_size = Vector2(199, 64)
        b.add_theme_font_size_override("font_size", 24)
        if item[2] != &"":
            b.theme_type_variation = item[2]
        b.pressed.connect(_on_quick_ip.bind(str(item[1])))
        row.add_child(b)
    parent.add_child(row)


func _on_quick_ip(prefix: String) -> void:
    _ip = prefix
    _refresh_ip()


const MAP_CONFIG_PATH: String = "res://scripts/main_menu/map_config.gd"

var _map_config = null


## Co-op maps from map_config.gd (falls back to the MAPS list above if it's missing).
func _maps() -> Array:
    if _map_config == null:
        var cfg_script = load(MAP_CONFIG_PATH)
        if cfg_script != null:
            _map_config = cfg_script.new()
    if _map_config != null:
        var list: Array = _map_config.get_owned_coop_maps()
        if not list.is_empty():
            return list
    return MAPS
