extends Control
## CONTROLLER screen (opened from Settings): tap an action, then press a pad button.

const BINDINGS_PATH: String = "res://scripts/managers/gamepad_bindings.gd"
const NAMES_PATH: String = "res://scripts/managers/pad_names.gd"
const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const DIVIDER_PATH: String = "res://scripts/ui/poster_divider.gd"
const RESERVED: Array = [
    JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
    JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_GUIDE,
]

var _bindings = null
var _names = null
var _buttons: Dictionary = {}
var _hint: Label
var _listening: String = ""
var _ignore_until: int = 0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bscript = load(BINDINGS_PATH)
    if bscript != null:
        _bindings = bscript.new()
    var nscript = load(NAMES_PATH)
    if nscript != null:
        _names = nscript.new()

    _add_backdrop()

    var margin := MarginContainer.new()
    add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 20)

    var outer := VBoxContainer.new()
    outer.add_theme_constant_override("separation", 8)
    margin.add_child(outer)

    var title := Label.new()
    title.text = "CONTROLLER"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    outer.add_child(title)

    _add_divider(outer)

    _hint = Label.new()
    _hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint.theme_type_variation = &"SmallLabel"
    _hint.add_theme_font_size_override("font_size", 18)
    outer.add_child(_hint)
    _set_default_hint()

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)

    var center := CenterContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(center)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 10)
    center.add_child(vbox)

    if _bindings == null or _names == null:
        var err := Label.new()
        err.text = "CONTROLLER SETTINGS FAILED TO LOAD"
        err.theme_type_variation = &"DangerLabel"
        vbox.add_child(err)
    else:
        for a in _bindings.ACTIONS:
            _add_row(vbox, a)
        var reset := _make_button("RESET TO DEFAULTS", _on_reset)
        reset.theme_type_variation = &"DangerButton"
        vbox.add_child(reset)
        _refresh()

    var back := _make_button("BACK", _on_back)
    back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    outer.add_child(back)


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


func _add_divider(parent: Control) -> void:
    var script = load(DIVIDER_PATH)
    if script == null:
        return
    var divider := Control.new()
    divider.set_script(script)
    divider.custom_minimum_size = Vector2(0, 24)
    parent.add_child(divider)


func _make_button(label: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(560, 60)
    b.add_theme_font_size_override("font_size", 24)
    b.pressed.connect(callback)
    return b


func _add_row(parent: Control, a: Dictionary) -> void:
    var id: String = a["id"]
    var box := HBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    parent.add_child(box)

    var name_label := Label.new()
    name_label.text = str(a["title"]).to_upper()
    name_label.custom_minimum_size = Vector2(300, 0)
    name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_label.add_theme_font_size_override("font_size", 22)
    box.add_child(name_label)

    var b := Button.new()
    b.custom_minimum_size = Vector2(380, 60)
    b.add_theme_font_size_override("font_size", 24)
    b.pressed.connect(_on_row.bind(id))
    box.add_child(b)
    _buttons[id] = b


func _set_default_hint() -> void:
    _hint.text = "TAP AN ACTION, THEN PRESS A BUTTON. D-PAD LEFT/RIGHT ALWAYS SWITCH WEAPONS. MENUS USE A / B."


func _row_text(id: String) -> String:
    var lst: Array = _bindings.map.get(id, [])
    if lst.is_empty():
        return "UNBOUND"
    var parts := PackedStringArray()
    for d in lst:
        parts.append(_names.descriptor_name(str(d)).to_upper())
    return " / ".join(parts)


func _refresh() -> void:
    for id in _buttons.keys():
        var b: Button = _buttons[id]
        if id == _listening:
            b.text = "PRESS A BUTTON..."
        else:
            b.text = _row_text(id)


func _title_of(id: String) -> String:
    for a in _bindings.ACTIONS:
        if a["id"] == id:
            return str(a["title"]).to_upper()
    return id.to_upper()


func _on_row(id: String) -> void:
    if Time.get_ticks_msec() < _ignore_until:
        return
    if _listening == id:
        _listening = ""
        _set_default_hint()
    else:
        _listening = id
        _ignore_until = Time.get_ticks_msec() + 300
        var extra: String = "" if _bindings.axis_ok(id) else " (BUTTONS ONLY)"
        _hint.text = "PRESS A BUTTON FOR " + _title_of(id) + extra + ". TAP AGAIN TO CANCEL."
    _refresh()


func _input(event: InputEvent) -> void:
    if _listening == "" or _bindings == null:
        return
    if event is InputEventJoypadButton:
        get_viewport().set_input_as_handled()
        if not event.pressed or Time.get_ticks_msec() < _ignore_until:
            return
        if RESERVED.has(event.button_index):
            _hint.text = "D-PAD AND MENU BUTTONS CAN'T BE USED. PRESS ANOTHER BUTTON."
            return
        _assign("b:%d" % event.button_index)
    elif event is InputEventJoypadMotion:
        if Time.get_ticks_msec() < _ignore_until or absf(event.axis_value) < 0.7:
            return
        if event.axis != JOY_AXIS_TRIGGER_LEFT and event.axis != JOY_AXIS_TRIGGER_RIGHT:
            return
        get_viewport().set_input_as_handled()
        if not _bindings.axis_ok(_listening):
            _hint.text = "THIS ACTION TAKES BUTTONS ONLY. PRESS A BUTTON."
            return
        _assign("a:%d" % event.axis)


func _assign(desc: String) -> void:
    _bindings.assign(_listening, desc)
    _listening = ""
    _set_default_hint()
    _refresh()
    GamepadManager.reload_bindings()


func _on_reset() -> void:
    if _bindings == null:
        return
    _listening = ""
    _bindings.reset()
    _set_default_hint()
    _refresh()
    GamepadManager.reload_bindings()


func _on_back() -> void:
    queue_free()

# END OF FILE
