extends Control
## HUD layout editor (Settings > HUD LAYOUT). Tap a box to select it, drag to
## move it, use the - / + buttons for size and opacity. Saves automatically.

const LAYOUT_PATH: String = "res://scripts/managers/hud_layout.gd"
const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const YELLOW: Color = Color(1.0, 0.769, 0.0)

var _layout = null
var _ghosts: Dictionary = {}
var _selected: String = ""
var _grab: Vector2 = Vector2.ZERO
var _hidden: Array = []
var _title_label: Label
var _size_label: Label
var _alpha_label: Label


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _hide_siblings()
    var script = load(LAYOUT_PATH)
    if script != null:
        _layout = script.new()
    _add_backdrop()
    if _layout != null:
        for info in _layout.ELEMENTS:
            _make_ghost(info)
    _build_panel()
    _update_labels()


func _hide_siblings() -> void:
    var p: Node = get_parent()
    if p == null:
        return
    for c in p.get_children():
        if c != self and c is CanvasItem and c.visible:
            c.visible = false
            _hidden.append(c)


func _exit_tree() -> void:
    for c in _hidden:
        if is_instance_valid(c):
            c.visible = true
    _hidden.clear()


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


func _make_ghost(info: Dictionary) -> void:
    var id: String = str(info["id"])
    var g := Control.new()
    g.size = _layout.size_of(id, get_viewport_rect().size)
    g.pivot_offset = g.size / 2.0
    g.draw.connect(_draw_ghost.bind(g, id))
    g.gui_input.connect(_on_ghost_event.bind(g, id))
    add_child(g)
    _ghosts[id] = g
    _refresh_ghost(id)


func _refresh_ghost(id: String) -> void:
    var g: Control = _ghosts[id]
    var vp: Vector2 = get_viewport_rect().size
    g.position = _layout.center(id, vp) - g.size / 2.0
    g.scale = Vector2.ONE * _layout.scale_of(id)
    g.queue_redraw()


func _draw_ghost(g: Control, id: String) -> void:
    var info: Dictionary = _layout.info(id)
    var a: float = _layout.alpha_of(id)
    var sel: bool = (id == _selected)
    var line: Color = YELLOW if sel else Color(0.75, 0.75, 0.8)
    var fill: Color = Color(1.0, 0.769, 0.0, 0.18 + 0.4 * a) if sel else Color(0.3, 0.3, 0.36, 0.18 + 0.5 * a)
    if id == "joystick":
        var c: Vector2 = g.size / 2.0
        g.draw_circle(c, 155.0, fill)
        g.draw_arc(c, 155.0, 0.0, TAU, 64, line, 4.0)
        g.draw_circle(c, 65.0, Color(line.r, line.g, line.b, 0.45))
    else:
        var r := Rect2(Vector2.ZERO, g.size)
        g.draw_rect(r, fill, true)
        g.draw_rect(r, line, false, 4.0)
    var font: Font = ThemeDB.fallback_font
    var label: String = str(info["title"])
    var fs: int = 26
    var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
    g.draw_string(font, Vector2((g.size.x - ts.x) / 2.0, g.size.y / 2.0 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))


func _on_ghost_event(event: InputEvent, g: Control, id: String) -> void:
    var pressed_now: bool = false
    var released_now: bool = false
    var moving: bool = false
    if event is InputEventMouseButton:
        if event.button_index != MOUSE_BUTTON_LEFT:
            return
        pressed_now = event.pressed
        released_now = not event.pressed
    elif event is InputEventScreenTouch:
        pressed_now = event.pressed
        released_now = not event.pressed
    elif event is InputEventMouseMotion:
        moving = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
    elif event is InputEventScreenDrag:
        moving = true
    else:
        return
    var xf: Transform2D = g.get_global_transform()
    var gp: Vector2 = xf * event.position
    var centre: Vector2 = xf * (g.size / 2.0)
    if pressed_now:
        _select(id)
        _grab = gp - centre
    elif released_now:
        _layout.save()
    elif moving and id == _selected:
        var vp: Vector2 = get_viewport_rect().size
        var half: Vector2 = g.size * _layout.scale_of(id) / 2.0
        var c: Vector2 = gp - _grab
        c.x = clampf(c.x, half.x, vp.x - half.x)
        c.y = clampf(c.y, half.y, vp.y - half.y)
        _layout.set_center(id, c, vp)
        _refresh_ghost(id)
    g.accept_event()


func _select(id: String) -> void:
    _selected = id
    for k in _ghosts.keys():
        (_ghosts[k] as Control).queue_redraw()
    _update_labels()


func _build_panel() -> void:
    var panel := PanelContainer.new()
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.offset_left = -300.0
    panel.offset_right = 300.0
    panel.anchor_top = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_top = -130.0
    panel.offset_bottom = 130.0
    panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    add_child(panel)

    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 12)
    panel.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 8)
    margin.add_child(box)

    _title_label = Label.new()
    _title_label.theme_type_variation = &"GoldLabel"
    _title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _title_label.add_theme_font_size_override("font_size", 24)
    box.add_child(_title_label)

    _size_label = _stepper(box, "SIZE", _on_size.bind(-1), _on_size.bind(1))
    _alpha_label = _stepper(box, "OPACITY", _on_alpha.bind(-1), _on_alpha.bind(1))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    box.add_child(row)
    var reset_one := _small_button("RESET THIS", _on_reset_this, 20)
    reset_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(reset_one)
    var reset_all := _small_button("RESET ALL", _on_reset_all, 20)
    reset_all.theme_type_variation = &"DangerButton"
    reset_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(reset_all)
    var done := _small_button("DONE", _on_done, 20)
    done.theme_type_variation = &"MainButton"
    done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(done)


func _stepper(parent: Control, title: String, dec: Callable, inc: Callable) -> Label:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    parent.add_child(row)
    var t := Label.new()
    t.text = title
    t.custom_minimum_size = Vector2(170, 0)
    t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    t.add_theme_font_size_override("font_size", 22)
    row.add_child(t)
    row.add_child(_small_button("-", dec, 30))
    var v := Label.new()
    v.theme_type_variation = &"GoldLabel"
    v.custom_minimum_size = Vector2(130, 0)
    v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    v.add_theme_font_size_override("font_size", 26)
    row.add_child(v)
    row.add_child(_small_button("+", inc, 30))
    return v


func _small_button(text: String, callback: Callable, font_size: int) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(90, 52)
    b.add_theme_font_size_override("font_size", font_size)
    b.pressed.connect(callback)
    return b


func _update_labels() -> void:
    if _layout == null:
        _title_label.text = "LAYOUT FAILED TO LOAD"
        _size_label.text = "-"
        _alpha_label.text = "-"
        return
    if _selected == "":
        _title_label.text = "TAP A BOX, THEN DRAG TO MOVE"
        _size_label.text = "-"
        _alpha_label.text = "-"
        return
    var info: Dictionary = _layout.info(_selected)
    _title_label.text = "SELECTED: " + str(info["title"])
    if bool(info.get("scalable", true)):
        _size_label.text = "%d%%" % roundi(_layout.scale_of(_selected) * 100.0)
    else:
        _size_label.text = "FIXED"
    _alpha_label.text = "%d%%" % roundi(_layout.alpha_of(_selected) * 100.0)


func _on_size(dir: int) -> void:
    if _layout == null or _selected == "":
        return
    if not bool(_layout.info(_selected).get("scalable", true)):
        return
    var v: float = snappedf(clampf(_layout.scale_of(_selected) + 0.05 * float(dir), 0.5, 2.0), 0.05)
    _layout.pin(_selected, get_viewport_rect().size)
    _layout.set_scale(_selected, v)
    _layout.save()
    _refresh_ghost(_selected)
    _update_labels()


func _on_alpha(dir: int) -> void:
    if _layout == null or _selected == "":
        return
    var amin: float = float(_layout.info(_selected).get("alpha_min", 0.2))
    var v: float = snappedf(clampf(_layout.alpha_of(_selected) + 0.05 * float(dir), amin, 1.0), 0.05)
    _layout.pin(_selected, get_viewport_rect().size)
    _layout.set_alpha(_selected, v)
    _layout.save()
    _refresh_ghost(_selected)
    _update_labels()


func _on_reset_this() -> void:
    if _layout == null or _selected == "":
        return
    _layout.reset_one(_selected)
    _layout.save()
    _refresh_ghost(_selected)
    _update_labels()


func _on_reset_all() -> void:
    if _layout == null:
        return
    _layout.reset_all()
    _layout.save()
    for id in _ghosts.keys():
        _refresh_ghost(id)
    _update_labels()


func _on_done() -> void:
    if _layout != null:
        _layout.save()
    queue_free()

# END OF FILE
