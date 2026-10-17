extends Control
## Settings screen opened from OPTIONS: look speeds, field of view, ADS, reticle, sprint mode.
## Each value has a slider plus - / + buttons (the buttons also work great with a controller).

const SETTINGS_PATH: String = "res://scripts/managers/game_settings.gd"
const SLIDER_PATH: String = "res://scripts/ui/touch_slider.gd"
const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const DIVIDER_PATH: String = "res://scripts/ui/poster_divider.gd"
const ROWS: Array = [
    {"key": "touch_look", "title": "Touch look speed", "min": 0.5, "max": 2.0, "step": 0.1, "fmt": "x%.1f"},
    {"key": "pad_look", "title": "Gamepad look speed", "min": 100.0, "max": 400.0, "step": 20.0, "fmt": "%d DEG/S"},
    {"key": "fov", "title": "Field of view", "min": 60.0, "max": 110.0, "step": 5.0, "fmt": "%d"},
    {"key": "ads_sens", "title": "ADS sensitivity", "min": 25.0, "max": 150.0, "step": 5.0, "fmt": "%d%%"},
    {"key": "ads_zoom", "title": "ADS zoom", "min": 50.0, "max": 150.0, "step": 5.0, "fmt": "%d%%"},
    {"key": "reticle_size", "title": "Reticle size", "min": 50.0, "max": 200.0, "step": 5.0, "fmt": "%d%%"},
]
# A section header is drawn above the row with this key.
const SECTIONS: Dictionary = {
    "touch_look": "LOOK SPEED",
    "fov": "VIEW",
    "ads_sens": "AIMING",
}

var _settings = null
var _slider_script = null
var _labels: Dictionary = {}
var _sliders: Dictionary = {}
var _sprint_button: Button
var _color_button: Button
var _hit_button: Button
var _outline_button: Button
var _outline_color_button: Button
var _replay_button: Button


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var script = load(SETTINGS_PATH)
    if script != null:
        _settings = script.new()
    _slider_script = load(SLIDER_PATH)

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
    title.text = "SETTINGS"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    outer.add_child(title)

    _add_divider(outer)

    # Shows whether the touch fix (drag-to-scroll lists) is running.
    var status := Label.new()
    status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status.add_theme_font_size_override("font_size", 16)
    if get_tree().get_nodes_in_group("touch_fix").size() > 0:
        status.text = "TOUCH FIX: ON"
        status.theme_type_variation = &"GoodLabel"
    else:
        status.text = "TOUCH FIX: NOT INSTALLED (CHECK GAME_MANAGER.GD AND TOUCH_FIX.GD)"
        status.theme_type_variation = &"DangerLabel"
    outer.add_child(status)

    # The list scrolls by dragging; BACK stays pinned at the bottom.
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

    if _settings == null:
        var err := Label.new()
        err.text = "SETTINGS FAILED TO LOAD"
        err.theme_type_variation = &"DangerLabel"
        vbox.add_child(err)
    else:
        for row in ROWS:
            if SECTIONS.has(row["key"]):
                _add_section(vbox, str(SECTIONS[row["key"]]))
            _add_stepper_row(vbox, row)
        _add_section(vbox, "OPTIONS")
        _color_button = _make_button("", _on_reticle_color)
        vbox.add_child(_color_button)
        _hit_button = _make_button("", _on_hit_markers)
        vbox.add_child(_hit_button)
        _outline_button = _make_button("", _on_outline)
        vbox.add_child(_outline_button)
        _outline_color_button = _make_button("", _on_outline_color)
        vbox.add_child(_outline_color_button)
        _sprint_button = _make_button("", _on_sprint_mode)
        vbox.add_child(_sprint_button)
        _refresh_buttons()
        _add_section(vbox, "TOUCH CONTROLS")
        vbox.add_child(_make_button("HUD LAYOUT", _on_hud_layout))
        _add_section(vbox, "RESET")
        var reset := _make_button("RESET TO DEFAULTS", _on_reset)
        reset.theme_type_variation = &"DangerButton"
        vbox.add_child(reset)
        _replay_button = _make_button("REPLAY TUTORIAL", _on_replay_tutorial)
        vbox.add_child(_replay_button)

    var back := _make_button("BACK", _on_back)
    back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    outer.add_child(back)


## Charcoal background with a vignette (plain dark fill if the script is missing).
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


## Small yellow header with a thin line under it.
func _add_section(parent: Control, text: String) -> void:
    var l := Label.new()
    l.text = text
    l.theme_type_variation = &"GoldLabel"
    l.add_theme_font_size_override("font_size", 20)
    parent.add_child(l)
    parent.add_child(HSeparator.new())


func _make_button(label: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = label
    b.custom_minimum_size = Vector2(560, 60)
    b.add_theme_font_size_override("font_size", 24)
    b.pressed.connect(callback)
    return b


func _add_stepper_row(parent: Control, row: Dictionary) -> void:
    var key: String = row["key"]
    var box := HBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    parent.add_child(box)

    var name_label := Label.new()
    name_label.text = str(row["title"]).to_upper()
    name_label.custom_minimum_size = Vector2(320, 0)
    name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    name_label.add_theme_font_size_override("font_size", 22)
    box.add_child(name_label)

    box.add_child(_step_button("-", key, -1))

    if _slider_script != null:
        var slider = Control.new()
        slider.set_script(_slider_script)
        slider.custom_minimum_size = Vector2(320, 60)
        slider.setup(float(row["min"]), float(row["max"]), float(row["step"]), _settings.get_value(key))
        slider.value_changed.connect(_on_slider.bind(key))
        box.add_child(slider)
        _sliders[key] = slider

    box.add_child(_step_button("+", key, 1))

    var value_label := Label.new()
    value_label.theme_type_variation = &"GoldLabel"
    value_label.custom_minimum_size = Vector2(150, 0)
    value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    value_label.add_theme_font_size_override("font_size", 26)
    box.add_child(value_label)
    _labels[key] = value_label
    _update_label(key)


func _step_button(text: String, key: String, dir: int) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(90, 60)
    b.add_theme_font_size_override("font_size", 34)
    b.pressed.connect(_on_step.bind(key, dir))
    return b


func _row_for(key: String) -> Dictionary:
    for row in ROWS:
        if row["key"] == key:
            return row
    return {}


func _on_step(key: String, dir: int) -> void:
    var row: Dictionary = _row_for(key)
    if row.is_empty():
        return
    var step: float = float(row["step"])
    var v: float = _settings.get_value(key) + float(dir) * step
    v = snappedf(clampf(v, float(row["min"]), float(row["max"])), step / 10.0)
    _settings.set_value(key, v)
    _update_label(key)
    _sync_slider(key)


## Dragging a slider changes the setting (it snaps to the same steps as - / +).
func _on_slider(v: float, key: String) -> void:
    _settings.set_value(key, v)
    _update_label(key)


func _sync_slider(key: String) -> void:
    if _sliders.has(key):
        _sliders[key].set_value_silent(_settings.get_value(key))


func _update_label(key: String) -> void:
    var row: Dictionary = _row_for(key)
    if row.is_empty():
        return
    var v: float = _settings.get_value(key)
    var fmt: String = row["fmt"]
    var shown: String = (fmt % v) if fmt.contains("%.") else (fmt % int(v))
    (_labels[key] as Label).text = shown


## Cycles the reticle color through the list.
func _on_reticle_color() -> void:
    var count: int = _settings.RETICLE_COLORS.size()
    var idx: int = (int(_settings.get_value("reticle_color")) + 1) % count
    _settings.set_value("reticle_color", float(idx))
    _refresh_buttons()


func _on_outline() -> void:
    var on: bool = _settings.get_value("outline") > 0.5
    _settings.set_value("outline", 0.0 if on else 1.0)
    _refresh_buttons()


func _on_outline_color() -> void:
    var count: int = _settings.OUTLINE_COLORS.size()
    var idx: int = (int(_settings.get_value("outline_color")) + 1) % count
    _settings.set_value("outline_color", float(idx))
    _refresh_buttons()


func _on_hit_markers() -> void:
    var on: bool = _settings.get_value("hit_markers") > 0.5
    _settings.set_value("hit_markers", 0.0 if on else 1.0)
    _refresh_buttons()


func _on_sprint_mode() -> void:
    var hold: bool = _settings.get_value("sprint_hold") > 0.5
    _settings.set_value("sprint_hold", 0.0 if hold else 1.0)
    _refresh_buttons()


func _refresh_buttons() -> void:
    var count: int = _settings.RETICLE_COLORS.size()
    var idx: int = clampi(int(_settings.get_value("reticle_color")), 0, count - 1)
    var entry: Dictionary = _settings.RETICLE_COLORS[idx]
    _color_button.text = "RETICLE COLOR: " + str(entry["name"]).to_upper()
    _color_button.add_theme_color_override("font_color", entry["color"])
    _color_button.add_theme_color_override("font_hover_color", entry["color"])
    _color_button.add_theme_color_override("font_pressed_color", entry["color"])
    _hit_button.text = "HIT MARKERS: " + ("ON" if _settings.get_value("hit_markers") > 0.5 else "OFF")
    _outline_button.text = "RETICLE OUTLINE: " + ("ON" if _settings.get_value("outline") > 0.5 else "OFF")
    var oidx: int = clampi(int(_settings.get_value("outline_color")), 0, _settings.OUTLINE_COLORS.size() - 1)
    var oentry: Dictionary = _settings.OUTLINE_COLORS[oidx]
    _outline_color_button.text = "OUTLINE COLOR: " + str(oentry["name"])
    var ocol: Color = oentry.get("label", oentry["color"])
    for c in ["font_color", "font_hover_color", "font_pressed_color"]:
        _outline_color_button.add_theme_color_override(c, ocol)
    _sprint_button.text = "SPRINT: " + ("HOLD" if _settings.get_value("sprint_hold") > 0.5 else "TOGGLE")


func _on_reset() -> void:
    _settings.reset()
    for key in _labels.keys():
        _update_label(key)
        _sync_slider(key)
    _refresh_buttons()


func _on_hud_layout() -> void:
    var script = load("res://scripts/ui/hud_layout_editor.gd")
    if script == null:
        return
    var editor := Control.new()
    editor.set_script(script)
    add_child(editor)


func _on_back() -> void:
    queue_free()


func _on_replay_tutorial() -> void:
    _settings.set_value("tutorial_seen", 0.0)
    _replay_button.text = "TUTORIAL SHOWS AT NEXT GAME"
