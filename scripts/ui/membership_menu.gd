extends CanvasLayer
## Membership transfer menu (built in code). Opened by the membership counter
## through MembershipHub.open_menu().

const TRIM: Color = Color(0.95, 0.75, 0.1, 1)
const RED: Color = Color(1.0, 0.45, 0.35, 1)
const GREY: Color = Color(0.75, 0.75, 0.75, 1)
const MIN_AMOUNT: int = 100
const MAX_AMOUNT: int = 1000000
const STEP: int = 250
const CHIPS: Array = [100, 500, 1000, 5000]

var _hub: Node = null
var _selected: int = 0
var _amount: int = 500
var _buttons: Dictionary = {}   # peer id -> Button
var _hidden: Array = []
var _list_box: VBoxContainer = null
var _empty: Label = null
var _gains_label: Label = null
var _amount_label: Label = null
var _status: Label = null
var _msg: String = ""
var _msg_color: Color = GREY
var _msg_left: float = 0.0
var _timer: float = 0.0


func setup(hub: Node) -> void:
    _hub = hub
    _hide_touch_ui()
    _build_ui()
    _refresh()


func _process(delta: float) -> void:
    if _hub == null:
        return
    _msg_left = maxf(_msg_left - delta, 0.0)
    _timer += delta
    if _timer >= 0.3:
        _timer = 0.0
        _refresh()
    _apply_status()


func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _close()


func _exit_tree() -> void:
    for n in _hidden:
        if is_instance_valid(n):
            n.set("visible", true)
    _hidden.clear()


func _close() -> void:
    if _hub != null:
        _hub.call("close_menu", "")


# The on-screen controls are hidden while the menu is open, so touches can't move you.
func _hide_touch_ui() -> void:
    for n in get_tree().get_nodes_in_group("touch_ui"):
        if is_instance_valid(n) and n.get("visible") != null and bool(n.get("visible")):
            n.set("visible", false)
            _hidden.append(n)


# ---------- building the screen ----------

func _new_label(text: String, size: int, color: Color) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l


func _new_button(text: String, size: int, min_h: float) -> Button:
    var b := Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(0.0, min_h)
    b.add_theme_font_size_override("font_size", size)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return b


func _paint(b: Button, bg: Color, fg: Color) -> void:
    for state in ["normal", "hover", "pressed", "focus"]:
        var sb := StyleBoxFlat.new()
        sb.bg_color = bg.darkened(0.25) if state == "pressed" else bg
        sb.set_corner_radius_all(10)
        if state == "focus":
            sb.set_border_width_all(4)
            sb.border_color = Color(1, 1, 1, 1)
        b.add_theme_stylebox_override(state, sb)
    for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
        b.add_theme_color_override(c, fg)


func _build_ui() -> void:
    var vs: Vector2 = get_viewport().get_visible_rect().size

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.6)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var margin := MarginContainer.new()
    margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
    margin.add_theme_constant_override("margin_left", int(vs.x * 0.06))
    margin.add_theme_constant_override("margin_right", int(vs.x * 0.06))
    margin.add_theme_constant_override("margin_top", int(vs.y * 0.05))
    margin.add_theme_constant_override("margin_bottom", int(vs.y * 0.05))
    add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var panel := PanelContainer.new()
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.07, 0.07, 0.09, 0.97)
    sb.border_color = TRIM
    sb.set_border_width_all(4)
    sb.set_corner_radius_all(14)
    sb.set_content_margin_all(18)
    panel.add_theme_stylebox_override("panel", sb)
    margin.add_child(panel)

    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 12)
    panel.add_child(root)

    var title: Label = _new_label("MEMBERSHIP COUNTER", 44, TRIM)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(title)
    _gains_label = _new_label("", 34, Color(1, 1, 1, 1))
    _gains_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(_gains_label)

    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 20)
    root.add_child(body)

    # Left: teammates.
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_constant_override("separation", 8)
    body.add_child(left)
    left.add_child(_new_label("Who gets the membership?", 32, TRIM))
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    left.add_child(scroll)
    _list_box = VBoxContainer.new()
    _list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list_box.add_theme_constant_override("separation", 8)
    scroll.add_child(_list_box)
    _empty = _new_label("No teammates connected", 30, GREY)
    _list_box.add_child(_empty)

    # Right: amount and buttons.
    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 10)
    body.add_child(right)
    _amount_label = _new_label("", 40, Color(1, 1, 1, 1))
    right.add_child(_amount_label)

    var chips := HBoxContainer.new()
    chips.add_theme_constant_override("separation", 8)
    right.add_child(chips)
    for v in CHIPS:
        var c: Button = _new_button(str(v), 32, 80.0)
        c.pressed.connect(_set_amount.bind(int(v)))
        chips.add_child(c)

    var adjust := HBoxContainer.new()
    adjust.add_theme_constant_override("separation", 8)
    right.add_child(adjust)
    var minus: Button = _new_button("- %d" % STEP, 32, 80.0)
    minus.pressed.connect(_adjust.bind(-STEP))
    adjust.add_child(minus)
    var plus: Button = _new_button("+ %d" % STEP, 32, 80.0)
    plus.pressed.connect(_adjust.bind(STEP))
    adjust.add_child(plus)
    var all_btn: Button = _new_button("ALL", 32, 80.0)
    all_btn.pressed.connect(_set_all)
    adjust.add_child(all_btn)

    _status = _new_label("", 30, GREY)
    _status.size_flags_vertical = Control.SIZE_EXPAND_FILL
    right.add_child(_status)

    var buy: Button = _new_button("BUY MEMBERSHIP", 40, 110.0)
    _paint(buy, TRIM, Color(0.05, 0.05, 0.05, 1))
    buy.pressed.connect(_on_buy)
    right.add_child(buy)
    var close: Button = _new_button("CLOSE", 36, 90.0)
    close.pressed.connect(_close)
    right.add_child(close)


# ---------- updating ----------

func _refresh() -> void:
    if _hub == null or _list_box == null:
        return
    var targets: Array = _hub.call("get_targets")
    var seen: Dictionary = {}
    for t in targets:
        var id: int = int(t["id"])
        seen[id] = true
        var b: Button = _buttons.get(id)
        if b == null:
            b = _new_button("", 34, 90.0)
            b.pressed.connect(_select.bind(id))
            _list_box.add_child(b)
            _buttons[id] = b
        var gains_text: String = "?" if int(t["gains"]) < 0 else str(int(t["gains"]))
        var line: String = "%s  -  %s Gains" % [str(t["name"]), gains_text]
        if not bool(t["standing"]):
            line += "  (DOWN)"
        b.text = (">> " if id == _selected else "") + line
        b.disabled = not bool(t["standing"])
        b.modulate = TRIM if id == _selected else Color(1, 1, 1, 1)
    for id in _buttons.keys():
        if not seen.has(id):
            _buttons[id].queue_free()
            _buttons.erase(id)
            if _selected == id:
                _selected = 0
    _empty.visible = targets.is_empty()
    _gains_label.text = "Your Gains: %d" % GameManager.gains
    var over: bool = _amount > GameManager.gains
    _amount_label.text = "Amount: %d" % _amount
    _amount_label.add_theme_color_override("font_color", RED if over else Color(1, 1, 1, 1))


func _apply_status() -> void:
    if _status == null:
        return
    if _msg_left > 0.0:
        _status.text = _msg
        _status.add_theme_color_override("font_color", _msg_color)
        return
    var reason: String = str(_hub.call("can_send"))
    if reason != "":
        _status.text = reason
        _status.add_theme_color_override("font_color", RED)
    else:
        _status.text = "Pick a teammate, then an amount"
        _status.add_theme_color_override("font_color", GREY)


func _say(text: String, color: Color) -> void:
    _msg = text
    _msg_color = color
    _msg_left = 3.0


func _select(id: int) -> void:
    _selected = id
    _refresh()


func _set_amount(v: int) -> void:
    _amount = clampi(v, MIN_AMOUNT, MAX_AMOUNT)
    _refresh()


func _adjust(delta: int) -> void:
    _amount = clampi(_amount + delta, MIN_AMOUNT, MAX_AMOUNT)
    _refresh()


func _set_all() -> void:
    _amount = clampi(GameManager.gains, MIN_AMOUNT, MAX_AMOUNT)
    _refresh()


func _on_buy() -> void:
    if _selected == 0:
        _say("Pick a teammate first", RED)
        return
    var amt: int = _amount
    var reason: String = str(_hub.call("request_transfer", _selected, amt))
    if reason != "":
        _say(reason, RED)
    else:
        _say("Sending %d Gains..." % amt, TRIM)
    _refresh()
