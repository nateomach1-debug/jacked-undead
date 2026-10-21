extends Control
## "WHAT'S NEW" popup. Opens on the main menu only when there are update
## entries the player has not seen yet. The last seen version is saved on the
## phone when they tap CLOSE.

const DATA_PATH: String = "res://scripts/ui/update_log_data.gd"
const SAVE_PATH: String = "user://update_log.cfg"
## TRIAL SWITCH: true = show ALL entries on every launch and never save.
const FORCE_SHOW: bool = false
## A brand-new install: false = show only the latest entry, true = show all.
const NEW_PLAYER_SHOWS_ALL: bool = false

var _newest: int = 0


func _ready() -> void:
    var data = load(DATA_PATH)
    if data == null:
        queue_free()
        return
    var pending: Array = _pending(data.entries())
    if pending.is_empty():
        queue_free()
        return
    _build(pending)


func _pending(all: Array) -> Array:
    var sorted: Array = all.duplicate()
    if sorted.is_empty():
        return []
    sorted.sort_custom(func(a, b): return int(a["version"]) > int(b["version"]))
    _newest = int(sorted[0]["version"])
    if FORCE_SHOW:
        return sorted
    var last: int = _load_last_seen()
    if last < 0:
        if NEW_PLAYER_SHOWS_ALL:
            return sorted
        return [sorted[0]]
    var out: Array = []
    for e in sorted:
        if int(e["version"]) > last:
            out.append(e)
    return out


func _load_last_seen() -> int:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return -1
    return int(cfg.get_value("log", "last_seen", -1))


func _save_last_seen() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("log", "last_seen", _newest)
    cfg.save(SAVE_PATH)


func _build(pending: Array) -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP

    var dim := ColorRect.new()
    dim.color = Color(0.0, 0.0, 0.0, 0.8)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var panel := PanelContainer.new()
    panel.theme_type_variation = &"CardPanel"
    panel.custom_minimum_size = Vector2(860, 560)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_top", 20)
    margin.add_theme_constant_override("margin_bottom", 20)
    panel.add_child(margin)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    margin.add_child(vbox)

    var title := Label.new()
    title.text = "WHAT'S NEW"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    vbox.add_child(title)

    var sub := Label.new()
    if pending.size() == 1:
        sub.text = "1 UPDATE"
    else:
        sub.text = "%d UPDATES SINCE YOU LAST PLAYED" % pending.size()
    sub.theme_type_variation = &"SmallLabel"
    sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sub.add_theme_font_size_override("font_size", 18)
    vbox.add_child(sub)

    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.custom_minimum_size = Vector2(0, 340)
    vbox.add_child(scroll)

    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation", 8)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)

    for i in range(pending.size()):
        var e: Dictionary = pending[i]
        if i > 0:
            var sep := HSeparator.new()
            sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
            list.add_child(sep)
        var head := Label.new()
        head.text = ("UPDATE %d  -  %s  -  %s" % [int(e["version"]), str(e["date"]), str(e["title"])]).to_upper()
        head.theme_type_variation = &"GoldLabel"
        head.add_theme_font_size_override("font_size", 22)
        head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        head.custom_minimum_size = Vector2(740, 0)
        head.mouse_filter = Control.MOUSE_FILTER_IGNORE
        list.add_child(head)
        for line in e["lines"]:
            var l := Label.new()
            l.text = "-  " + str(line)
            l.add_theme_font_size_override("font_size", 20)
            l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            l.custom_minimum_size = Vector2(740, 0)
            l.mouse_filter = Control.MOUSE_FILTER_IGNORE
            list.add_child(l)

    var close := Button.new()
    close.text = "CLOSE"
    close.theme_type_variation = &"MainButton"
    close.custom_minimum_size = Vector2(300, 64)
    close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    close.add_theme_font_size_override("font_size", 26)
    close.pressed.connect(_on_close)
    vbox.add_child(close)


func _on_close() -> void:
    if not FORCE_SHOW:
        _save_last_seen()
    queue_free()

# END OF FILE
