extends Control
## Developer menu: locked behind a code, then lets you tweak balance and debug
## settings. Opened from the Options panel (main_menu.gd). Built entirely in
## code. Values live in GameManager (dev_get / dev_set) and are saved to disk.

const CODE: String = "11051993"
const PROFILE_PATH: String = "res://scripts/managers/profile.gd"

# Each row steps through these values with the - / + buttons.
# "flat": a negative value means "use the game's own value".
# "pct": a price multiplier (1.0 = normal price).
const ROWS: Array = [
    {"key": "zombie_damage", "title": "Zombie damage (HP/hit)", "kind": "flat", "steps": [-1.0, 0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 35.0, 50.0, 75.0, 100.0]},
    {"key": "locker_cost", "title": "Loot Locker cost", "kind": "flat", "steps": [-1.0, 0.0, 100.0, 250.0, 500.0, 950.0, 1500.0, 2500.0, 5000.0]},
    {"key": "wall_scale", "title": "Wall buy prices", "kind": "pct", "steps": [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0]},
    {"key": "supp_scale", "title": "Supplement prices", "kind": "pct", "steps": [0.0, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0]},
    {"key": "pr_cost", "title": "PR Rack cost", "kind": "flat", "steps": [-1.0, 0.0, 500.0, 1000.0, 2500.0, 5000.0, 7500.0, 10000.0]},
    {"key": "ending_cost", "title": "Ending cost", "kind": "flat", "steps": [-1.0, 0.0, 1000.0, 5000.0, 10000.0, 25000.0, 50000.0, 75000.0, 100000.0]},
]

var _entered: String = ""
var _code_label: Label
var _lock_box: Control
var _settings_box: Control
var _value_labels: Dictionary = {}
var _nav_button: Button
var _juice_label: Label


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.92)
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var center := CenterContainer.new()
    add_child(center)
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _lock_box = _build_lock_screen()
    _settings_box = _build_settings_screen()
    _settings_box.visible = false
    center.add_child(_lock_box)
    center.add_child(_settings_box)
    _update_code_label()


# ---------- lock screen ----------

func _build_lock_screen() -> Control:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.add_child(_make_label("DEVELOPER MENU - LOCKED", 32, HORIZONTAL_ALIGNMENT_CENTER))

    _code_label = _make_label("", 40, HORIZONTAL_ALIGNMENT_CENTER)
    _code_label.custom_minimum_size = Vector2(0, 56)
    box.add_child(_code_label)

    var grid := GridContainer.new()
    grid.columns = 3
    grid.add_theme_constant_override("h_separation", 10)
    grid.add_theme_constant_override("v_separation", 10)
    for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "<"]:
        grid.add_child(_make_button(key, Vector2(110, 76), _on_key.bind(key)))
    var grid_center := CenterContainer.new()
    grid_center.add_child(grid)
    box.add_child(grid_center)

    var back_center := CenterContainer.new()
    back_center.add_child(_make_button("BACK", Vector2(240, 70), _close))
    box.add_child(back_center)
    return box


func _on_key(key: String) -> void:
    if key == "C":
        _entered = ""
    elif key == "<":
        _entered = _entered.substr(0, maxi(_entered.length() - 1, 0))
    elif _entered.length() < CODE.length():
        _entered += key
    _update_code_label()
    if _entered.length() == CODE.length():
        if _entered == CODE:
            _unlock()
        else:
            _entered = ""
            _code_label.text = "WRONG CODE"


func _update_code_label() -> void:
    var shown: String = ""
    for i in range(CODE.length()):
        shown += ("*" if i < _entered.length() else "_") + " "
    _code_label.text = shown


func _unlock() -> void:
    _lock_box.visible = false
    _settings_box.visible = true
    _refresh()


# ---------- settings screen ----------

func _build_settings_screen() -> Control:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.add_child(_make_label("DEVELOPER MENU", 36, HORIZONTAL_ALIGNMENT_CENTER))

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(920, 420)
    box.add_child(scroll)
    var rows := VBoxContainer.new()
    rows.add_theme_constant_override("separation", 10)
    rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(rows)

    for row in ROWS:
        rows.add_child(_build_stepper_row(row))
    rows.add_child(_build_nav_row())
    rows.add_child(_build_juice_row())

    var bottom := HBoxContainer.new()
    bottom.add_theme_constant_override("separation", 16)
    bottom.alignment = BoxContainer.ALIGNMENT_CENTER
    bottom.add_child(_make_button("RESET DEFAULTS", Vector2(300, 70), _on_reset_pressed))
    bottom.add_child(_make_button("LOCK & CLOSE", Vector2(300, 70), _close))
    box.add_child(bottom)
    return box


func _build_stepper_row(row: Dictionary) -> Control:
    var key: String = row["key"]
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 10)
    var title := _make_label(row["title"], 26, HORIZONTAL_ALIGNMENT_LEFT)
    title.custom_minimum_size = Vector2(430, 0)
    h.add_child(title)
    h.add_child(_make_button("-", Vector2(80, 64), _step.bind(key, -1)))
    var value_label := _make_label("", 26, HORIZONTAL_ALIGNMENT_CENTER)
    value_label.custom_minimum_size = Vector2(200, 0)
    h.add_child(value_label)
    _value_labels[key] = value_label
    h.add_child(_make_button("+", Vector2(80, 64), _step.bind(key, 1)))
    return h


func _build_nav_row() -> Control:
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 10)
    var title := _make_label("Nav data (polygons, zombies)", 26, HORIZONTAL_ALIGNMENT_LEFT)
    title.custom_minimum_size = Vector2(430, 0)
    h.add_child(title)
    _nav_button = _make_button("OFF", Vector2(370, 64), _on_nav_pressed)
    h.add_child(_nav_button)
    return h


func _build_juice_row() -> Control:
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    _juice_label = _make_label("", 26, HORIZONTAL_ALIGNMENT_LEFT)
    v.add_child(_juice_label)
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 10)
    for amount in [100, 1000, 10000]:
        h.add_child(_make_button("+%d JUICE" % amount, Vector2(280, 64), _on_add_juice.bind(amount)))
    v.add_child(h)
    return v


func _step(key: String, direction: int) -> void:
    var steps: Array = _steps_for(key)
    if steps.is_empty():
        return
    var idx: int = _nearest_index(steps, GameManager.dev_get(key))
    idx = clampi(idx + direction, 0, steps.size() - 1)
    GameManager.dev_set(key, float(steps[idx]))
    _refresh()


func _on_nav_pressed() -> void:
    GameManager.dev_set("show_nav", 0.0 if GameManager.dev_show_nav() else 1.0)
    _refresh()


func _on_reset_pressed() -> void:
    GameManager.dev_reset()
    _refresh()


## Credits Juice straight into the saved profile (does not count as a changed dev setting).
func _on_add_juice(amount: int) -> void:
    var script = load(PROFILE_PATH)
    if script == null:
        return
    var p = script.new()
    p.add_juice(amount)
    _sync_juice_labels(get_tree().root, p.get_juice())
    _refresh()


func _current_juice() -> int:
    var script = load(PROFILE_PATH)
    if script == null:
        return 0
    var p = script.new()
    return p.get_juice()


## Updates any "JUICE: N" label already on screen (main menu).
func _sync_juice_labels(node: Node, value: int) -> void:
    if node is Label and (node as Label).text.begins_with("JUICE:"):
        (node as Label).text = "JUICE: %d" % value
    for c in node.get_children():
        _sync_juice_labels(c, value)


func _refresh() -> void:
    for row in ROWS:
        var key: String = row["key"]
        var label: Label = _value_labels[key]
        label.text = _format(row["kind"], GameManager.dev_get(key))
    _nav_button.text = "ON" if GameManager.dev_show_nav() else "OFF"
    _juice_label.text = "Juice balance: %d" % _current_juice()


func _format(kind: String, value: float) -> String:
    if kind == "pct":
        return "%d%%" % int(round(value * 100.0))
    if value < 0.0:
        return "Default"
    return "%d" % int(value)


func _steps_for(key: String) -> Array:
    for row in ROWS:
        if row["key"] == key:
            return row["steps"]
    return []


func _nearest_index(steps: Array, value: float) -> int:
    var best: int = 0
    var best_diff: float = INF
    for i in range(steps.size()):
        var diff: float = absf(float(steps[i]) - value)
        if diff < best_diff:
            best_diff = diff
            best = i
    return best


func _close() -> void:
    queue_free()


# ---------- small helpers ----------

func _make_button(text: String, min_size: Vector2, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = min_size
    b.add_theme_font_size_override("font_size", 26)
    b.pressed.connect(callback)
    return b


func _make_label(text: String, font_size: int, align: HorizontalAlignment) -> Label:
    var l := Label.new()
    l.text = text
    l.horizontal_alignment = align
    l.add_theme_font_size_override("font_size", font_size)
    return l
