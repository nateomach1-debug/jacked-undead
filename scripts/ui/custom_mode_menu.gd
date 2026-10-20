extends Control
## Custom game mode screen, opened over the map select by its CUSTOM MODE button.
## Each row switches one feature on or off for your next run. Weapon levels and
## Juice still count. Settings live in GameManager.custom and stay until you
## reset them or close the app.
## To add a toggle: add a line to OPTIONS (key must exist in GameManager.CUSTOM_DEFAULTS).

signal closed

const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const DIVIDER_PATH: String = "res://scripts/ui/poster_divider.gd"

const OPTIONS: Array = [
    {"key": "pr_rack", "label": "PR RACK"},
    {"key": "loot_locker", "label": "LOOT LOCKER"},
    {"key": "rarity", "label": "WEAPON RARITY"},
    {"key": "attachments", "label": "ATTACHMENTS"},
]

var _buttons: Dictionary = {}


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_ui()
    _refresh()


func _build_ui() -> void:
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

    var margin := MarginContainer.new()
    add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 8)
    margin.add_child(outer)

    var title := Label.new()
    title.text = "CUSTOM MODE"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    outer.add_child(title)

    var div_script = load(DIVIDER_PATH)
    if div_script != null:
        var divider := Control.new()
        divider.set_script(div_script)
        divider.custom_minimum_size = Vector2(0, 24)
        outer.add_child(divider)

    var info := Label.new()
    info.text = "SWITCH FEATURES OFF FOR YOUR NEXT RUN. WEAPON LEVELS AND JUICE STILL COUNT."
    info.theme_type_variation = &"SmallLabel"
    info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_theme_font_size_override("font_size", 16)
    outer.add_child(info)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)

    var rows := VBoxContainer.new()
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    rows.add_theme_constant_override("separation", 10)
    scroll.add_child(rows)

    for opt in OPTIONS:
        var key: String = str(opt["key"])
        var b := Button.new()
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.custom_minimum_size = Vector2(0, 64)
        b.add_theme_font_size_override("font_size", 24)
        b.pressed.connect(_on_toggle.bind(key))
        rows.add_child(b)
        _buttons[key] = b

    var bottom := HBoxContainer.new()
    bottom.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom.add_theme_constant_override("separation", 14)
    outer.add_child(bottom)

    var reset := Button.new()
    reset.text = "RESET ALL"
    reset.custom_minimum_size = Vector2(260, 70)
    reset.add_theme_font_size_override("font_size", 24)
    reset.pressed.connect(_on_reset)
    bottom.add_child(reset)

    var done := Button.new()
    done.text = "DONE"
    done.theme_type_variation = &"MainButton"
    done.custom_minimum_size = Vector2(260, 70)
    done.add_theme_font_size_override("font_size", 24)
    done.pressed.connect(_on_done)
    bottom.add_child(done)


func _refresh() -> void:
    for opt in OPTIONS:
        var key: String = str(opt["key"])
        var b: Button = _buttons.get(key)
        if b == null:
            continue
        var on: bool = GameManager.custom_on(key)
        b.text = "%s: %s" % [str(opt["label"]), "ON" if on else "OFF"]
        b.theme_type_variation = &"OwnedButton" if on else &"DangerButton"


func _on_toggle(key: String) -> void:
    GameManager.custom_set(key, not GameManager.custom_on(key))
    _refresh()


func _on_reset() -> void:
    GameManager.custom_reset()
    _refresh()


func _on_done() -> void:
    closed.emit()
    queue_free()
