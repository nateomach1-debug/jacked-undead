extends Control
## Set your player name (saved on this phone). Used on the leaderboard,
## the co-op lobby and the co-op scoreboard.

const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"

var _edit: LineEdit = null
var _status: Label = null


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
    vbox.add_theme_constant_override("separation", 14)
    center.add_child(vbox)

    var title := Label.new()
    title.text = "PLAYER NAME"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 44)
    vbox.add_child(title)

    var hint := Label.new()
    hint.text = "SHOWN ON LEADERBOARDS AND IN CO-OP (MAX %d LETTERS)" % NetManager.MAX_NAME_LENGTH
    hint.theme_type_variation = &"SmallLabel"
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hint.add_theme_font_size_override("font_size", 18)
    vbox.add_child(hint)

    _edit = LineEdit.new()
    _edit.text = NetManager.player_name
    _edit.placeholder_text = "Type your name"
    _edit.max_length = NetManager.MAX_NAME_LENGTH
    _edit.custom_minimum_size = Vector2(340, 70)
    _edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
    _edit.add_theme_font_size_override("font_size", 28)
    vbox.add_child(_edit)

    _status = Label.new()
    _status.theme_type_variation = &"SmallLabel"
    _status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _status.add_theme_font_size_override("font_size", 18)
    vbox.add_child(_status)

    var save := Button.new()
    save.text = "SAVE"
    save.custom_minimum_size = Vector2(340, 70)
    save.add_theme_font_size_override("font_size", 26)
    save.pressed.connect(_on_save)
    vbox.add_child(save)

    var back := Button.new()
    back.text = "BACK"
    back.custom_minimum_size = Vector2(340, 60)
    back.add_theme_font_size_override("font_size", 24)
    back.pressed.connect(queue_free)
    vbox.add_child(back)


func _on_save() -> void:
    var cleaned: String = _edit.text.strip_edges()
    if cleaned == "":
        _status.text = "TYPE A NAME FIRST"
        return
    NetManager.set_player_name(cleaned)
    _edit.text = NetManager.player_name
    _status.text = "SAVED AS %s" % NetManager.player_name.to_upper()

# END OF FILE
