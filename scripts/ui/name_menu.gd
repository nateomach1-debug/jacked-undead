extends Control
## Set your player name (saved on this phone). Used on the leaderboard,
## the co-op lobby and the co-op scoreboard. Uses an on-screen keyboard
## because the phone keyboard never opens in this game.

const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const ROWS: Array = ["1234567890", "QWERTYUIOP", "ASDFGHJKL"]
const KEY_SIZE: Vector2 = Vector2(64, 48)

var _edit: LineEdit = null
var _status: Label = null
var _caps: bool = true
var _letter_keys: Array = []


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    var script = load(BACKDROP_PATH)
    if script == null:
        var bg := ColorRect.new()
        bg.color = Color(0.055, 0.055, 0.067, 1.0)
        add_child(bg)
        bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    else:
        var backdrop := Control.new()
        backdrop.set_script(script)
        add_child(backdrop)

    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    center.add_child(vbox)

    var title := Label.new()
    title.text = "PLAYER NAME"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 36)
    vbox.add_child(title)

    var hint := Label.new()
    hint.text = "SHOWN ON LEADERBOARDS AND IN CO-OP (MAX %d LETTERS)" % NetManager.MAX_NAME_LENGTH
    hint.theme_type_variation = &"SmallLabel"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 18)
    vbox.add_child(hint)

    _edit = LineEdit.new()
    _edit.text = NetManager.player_name
    _edit.placeholder_text = "Tap the keys below"
    _edit.max_length = NetManager.MAX_NAME_LENGTH
    _edit.editable = false
    _edit.focus_mode = Control.FOCUS_NONE
    _edit.virtual_keyboard_enabled = false
    _edit.custom_minimum_size = Vector2(340, 64)
    _edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
    _edit.add_theme_font_size_override("font_size", 28)
    _edit.add_theme_color_override("font_uneditable_color", Color(1, 1, 1, 1))
    vbox.add_child(_edit)

    _status = Label.new()
    _status.theme_type_variation = &"SmallLabel"
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.add_theme_font_size_override("font_size", 18)
    _status.custom_minimum_size = Vector2(0, 24)
    vbox.add_child(_status)

    _build_keyboard(vbox)

    var bottom := HBoxContainer.new()
    bottom.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom.add_theme_constant_override("separation", 12)
    vbox.add_child(bottom)

    var save := Button.new()
    save.text = "SAVE"
    save.custom_minimum_size = Vector2(240, 60)
    save.add_theme_font_size_override("font_size", 26)
    save.pressed.connect(_on_save)
    bottom.add_child(save)

    var back := Button.new()
    back.text = "BACK"
    back.custom_minimum_size = Vector2(240, 60)
    back.add_theme_font_size_override("font_size", 24)
    back.pressed.connect(queue_free)
    bottom.add_child(back)


func _build_keyboard(parent: Control) -> void:
    var pad := VBoxContainer.new()
    pad.add_theme_constant_override("separation", 6)
    parent.add_child(pad)

    for r in ROWS:
        var row_text: String = r
        var row := _make_row()
        pad.add_child(row)
        for i in range(row_text.length()):
            row.add_child(_make_key(row_text.substr(i, 1)))

    var row4 := _make_row()
    pad.add_child(row4)
    var caps_btn := _make_button("aA", 100)
    caps_btn.pressed.connect(_on_caps)
    row4.add_child(caps_btn)
    for ch in "ZXCVBNM":
        row4.add_child(_make_key(ch))
    var del_btn := _make_button("DEL", 100)
    del_btn.pressed.connect(_on_del)
    row4.add_child(del_btn)

    var row5 := _make_row()
    pad.add_child(row5)
    var space_btn := _make_button("SPACE", 360)
    space_btn.pressed.connect(_on_key.bind(" "))
    row5.add_child(space_btn)
    var clear_btn := _make_button("CLEAR", 140)
    clear_btn.pressed.connect(_on_clear)
    row5.add_child(clear_btn)


func _make_row() -> HBoxContainer:
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 6)
    return row


func _make_button(label: String, width: float) -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(width, KEY_SIZE.y)
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 22)
    return b


func _make_key(ch: String) -> Button:
    var b := _make_button(ch, KEY_SIZE.x)
    b.add_theme_font_size_override("font_size", 24)
    b.set_meta("ch", ch)
    b.pressed.connect(_on_key.bind(ch))
    if ch.to_upper() != ch.to_lower():
        _letter_keys.append(b)
        _apply_case(b)
    return b


func _apply_case(b: Button) -> void:
    var ch: String = str(b.get_meta("ch"))
    if _caps:
        b.text = ch.to_upper()
    else:
        b.text = ch.to_lower()


func _on_caps() -> void:
    _caps = not _caps
    for b in _letter_keys:
        _apply_case(b)


func _on_key(ch: String) -> void:
    if _edit.text.length() >= NetManager.MAX_NAME_LENGTH:
        _status.text = "NAME IS AT MAX LENGTH"
        return
    if _caps:
        _edit.text += ch.to_upper()
    else:
        _edit.text += ch.to_lower()
    _status.text = ""


func _on_del() -> void:
    var t: String = _edit.text
    if t.length() > 0:
        _edit.text = t.substr(0, t.length() - 1)
    _status.text = ""


func _on_clear() -> void:
    _edit.text = ""
    _status.text = ""


func _on_save() -> void:
    var cleaned: String = _edit.text.strip_edges()
    if cleaned == "":
        _status.text = "TYPE A NAME FIRST"
        return
    NetManager.set_player_name(cleaned)
    _edit.text = NetManager.player_name
    _status.text = "SAVED AS %s" % NetManager.player_name.to_upper()

# END OF FILE
