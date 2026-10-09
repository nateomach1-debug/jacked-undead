extends CanvasLayer
## In-game Tailscale setup guide, one step per page.
## Open it from any script with:
##   var g = load("res://scripts/ui/tailscale_guide.gd")
##   if g != null:
##       get_tree().root.add_child(g.new())

const PAGES: Array = [
    ["Before you start", "HOST (once): in a browser go to login.tailscale.com/admin/users and tap Invite users. Enter each friend's Google email. The free plan covers up to 6 people.\n\nFRIENDS: tap the invite link and accept it BEFORE you install the app. If you skip this you get your own separate network and can't join."],
    ["1. Install", "Open the Google Play Store, search for Tailscale and install it."],
    ["2. Sign in", "Open Tailscale and tap Get started.\n\nSign in with the SAME Google account that was invited."],
    ["3. Allow the VPN", "Android asks to set up a VPN connection. Tap OK.\n\nTailscale only uses this to reach your friends. It does not slow your normal internet."],
    ["4. Check it is on", "The switch at the top of the Tailscale app must be ON and show Connected.\n\nIf it is off, tap it."],
    ["5. Host: get your address", "In Tailscale, tap your own phone in the device list. Copy the address that looks like 100.x.x.x\n\nSend it to your friends."],
    ["6. Keep it alive", "Android Settings > Apps > Tailscale > Battery > Unrestricted.\n\nOtherwise Android may shut it down in the background."],
    ["7. Before every game", "Turn Tailscale ON first, then open Jacked Undead.\n\nAndroid allows only one VPN at a time, so turn off any other VPN app."],
    ["8. Play together", "HOST: tap CO-OP, pick a map and host.\n\nFRIENDS: tap CO-OP, type the host's 100.x address and join."],
    ["WARNING", "Leaving the game for more than a few seconds counts as dead when you come back.\n\nSet everything up BEFORE the match starts."],
]

var _page: int = 0
var _counter: Label
var _title: Label
var _body: Label
var _back: Button
var _next: Button


func _ready() -> void:
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS
    var root := Control.new()
    add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var bg := ColorRect.new()
    bg.color = Color(0.05, 0.05, 0.07, 0.98)
    root.add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var margin := MarginContainer.new()
    root.add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 40)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 24)
    margin.add_child(box)
    _counter = _make_label(34, Color(0.7, 0.7, 0.7))
    box.add_child(_counter)
    _title = _make_label(58, Color(0.85, 0.12, 0.12))
    box.add_child(_title)
    _body = _make_label(42, Color(0.95, 0.95, 0.95))
    _body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(_body)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 20)
    box.add_child(row)
    _back = _make_button("BACK", _on_back)
    _next = _make_button("NEXT", _on_next)
    var close := _make_button("CLOSE", _on_close)
    row.add_child(_back)
    row.add_child(_next)
    row.add_child(close)
    _show_page()


func _make_label(font_size: int, color: Color) -> Label:
    var l := Label.new()
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return l


func _make_button(label_text: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = label_text
    b.add_theme_font_size_override("font_size", 44)
    b.custom_minimum_size = Vector2(0, 130)
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.pressed.connect(callback)
    return b


func _show_page() -> void:
    _counter.text = "Tailscale guide  %d / %d" % [_page + 1, PAGES.size()]
    _title.text = PAGES[_page][0]
    _body.text = PAGES[_page][1]
    _back.disabled = _page == 0
    _next.disabled = _page == PAGES.size() - 1


func _on_back() -> void:
    _page = max(_page - 1, 0)
    _show_page()


func _on_next() -> void:
    _page = min(_page + 1, PAGES.size() - 1)
    _show_page()


func _on_close() -> void:
    queue_free()
