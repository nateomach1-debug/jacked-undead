extends Control
## Map selection, reached from the main menu's Start button.
## MAPS tab: Arena, Building and the other normal maps (from map_config.gd).
## DLC tab: the buyable maps; locked ones point to the Market.
## Every map is a card in a 2-column grid.

const MAP_CONFIG_PATH: String = "res://scripts/main_menu/map_config.gd"
const MARKET_PATH: String = "res://scripts/managers/market.gd"
const PROFILE_PATH: String = "res://scripts/managers/profile.gd"
const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const DIVIDER_PATH: String = "res://scripts/ui/poster_divider.gd"
const MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"

const BASE_MAPS: Array = [
    {"id": "arena", "title": "GYM ARENA", "path": "res://scenes/main/main.tscn"},
    {"id": "building", "title": "BUILDING", "path": "res://scenes/main/building_map.tscn"},
]

var _config = null
var _market = null
var _profile = null
var _grid: GridContainer
var _message: Label
var _maps_tab: Button
var _dlc_tab: Button
var _normal_cards: Array = []
var _dlc_cards: Array = []


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var cfg_script = load(MAP_CONFIG_PATH)
    if cfg_script != null:
        _config = cfg_script.new()
    var market_script = load(MARKET_PATH)
    if market_script != null:
        _market = market_script.new()
    var profile_script = load(PROFILE_PATH)
    if profile_script != null:
        _profile = profile_script.new()
    _build_ui()
    _add_normal_cards()
    _add_dlc_cards()
    _show_tab(false)


func _map_enabled(id: String) -> bool:
    return _config == null or _config.is_enabled(id)


func _extra_maps() -> Array:
    if _config == null:
        return []
    return _config.get_extra_maps()


func _dlc_maps() -> Array:
    if _config == null:
        return []
    return _config.get_dlc_maps()


func _owns(id: String) -> bool:
    if _market == null:
        return true
    return _market.owns_map(_profile, id)


# ---------- layout ----------

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


func _build_ui() -> void:
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
    title.text = "SELECT MAP"
    title.theme_type_variation = &"TitleLabel"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 40)
    outer.add_child(title)

    _add_divider(outer)

    var tabs := HBoxContainer.new()
    tabs.alignment = BoxContainer.ALIGNMENT_CENTER
    tabs.add_theme_constant_override("separation", 12)
    _maps_tab = _make_tab("MAPS", false)
    _dlc_tab = _make_tab("DLC", true)
    tabs.add_child(_maps_tab)
    tabs.add_child(_dlc_tab)
    outer.add_child(tabs)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)

    _grid = GridContainer.new()
    _grid.columns = 2
    _grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid.add_theme_constant_override("h_separation", 14)
    _grid.add_theme_constant_override("v_separation", 14)
    scroll.add_child(_grid)

    _message = Label.new()
    _message.theme_type_variation = &"DangerLabel"
    _message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _message.add_theme_font_size_override("font_size", 18)
    _message.visible = false
    outer.add_child(_message)

    var back := Button.new()
    back.text = "BACK"
    back.custom_minimum_size = Vector2(240, 70)
    back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    back.add_theme_font_size_override("font_size", 24)
    back.pressed.connect(_on_back_pressed)
    outer.add_child(back)


func _make_tab(label: String, dlc: bool) -> Button:
    var b := Button.new()
    b.text = label
    b.toggle_mode = true
    b.custom_minimum_size = Vector2(200, 64)
    b.add_theme_font_size_override("font_size", 24)
    b.pressed.connect(_show_tab.bind(dlc))
    return b


func _show_tab(dlc: bool) -> void:
    for c in _normal_cards:
        c.visible = not dlc
    for c in _dlc_cards:
        c.visible = dlc
    _message.visible = false
    _maps_tab.button_pressed = not dlc
    _dlc_tab.button_pressed = dlc


# ---------- cards ----------

## One map card: name (+ optional chip) on top, optional description, action button below.
func _add_card(title: String, desc: String, strip: StringName, chip_text: String,
        chip_kind: StringName, button_text: String, button_kind: StringName,
        callback: Callable) -> PanelContainer:
    var card := PanelContainer.new()
    card.theme_type_variation = strip
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grid.add_child(card)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    card.add_child(box)

    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 10)
    box.add_child(top)

    var name_l := Label.new()
    name_l.text = title
    name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    name_l.add_theme_font_size_override("font_size", 26)
    top.add_child(name_l)

    if chip_text != "":
        var chip := Label.new()
        chip.text = chip_text
        chip.theme_type_variation = chip_kind
        chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        chip.add_theme_font_size_override("font_size", 18)
        top.add_child(chip)

    if desc != "":
        var d := Label.new()
        d.text = desc.to_upper()
        d.theme_type_variation = &"SmallLabel"
        d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        d.add_theme_font_size_override("font_size", 16)
        box.add_child(d)

    var b := Button.new()
    b.text = button_text
    b.theme_type_variation = button_kind
    b.custom_minimum_size = Vector2(0, 64)
    b.add_theme_font_size_override("font_size", 24)
    b.pressed.connect(callback)
    box.add_child(b)
    return card


func _add_normal_cards() -> void:
    for m in BASE_MAPS:
        if not _map_enabled(str(m["id"])):
            continue
        _normal_cards.append(_add_card(str(m["title"]).to_upper(), "", &"CardPanel",
                "", &"TagLabel", "PLAY", &"MainButton", _on_map_pressed.bind(str(m["path"]))))
    for m in _extra_maps():
        _normal_cards.append(_add_card(str(m["title"]).to_upper(), "", &"CardPanel",
                "", &"TagLabel", "PLAY", &"MainButton", _on_map_pressed.bind(str(m["path"]))))


func _add_dlc_cards() -> void:
    for m in _dlc_maps():
        var id: String = str(m["id"])
        var desc: String = ""
        if _market != null and _market.has_method("map_desc"):
            desc = str(_market.map_desc(id))
        if _owns(id):
            _dlc_cards.append(_add_card(str(m["title"]).to_upper(), desc, &"CardPanelOwned",
                    "OWNED", &"OwnedTag", "PLAY", &"MainButton", _on_map_pressed.bind(str(m["path"]))))
        else:
            var price: int = 0
            if _market != null:
                price = _market.map_cost(id)
            _dlc_cards.append(_add_card(str(m["title"]).to_upper(), desc, &"CardPanelLocked",
                    "%d JUICE" % price, &"LockedTag", "LOCKED", &"DangerButton", _on_locked_pressed))


# ---------- actions ----------

func _on_locked_pressed() -> void:
    _message.text = "LOCKED. BUY THIS MAP IN THE MARKET (PROFILE > MARKET)."
    _message.visible = true


func _on_map_pressed(path: String) -> void:
    get_tree().change_scene_to_file(path)


func _on_back_pressed() -> void:
    get_tree().change_scene_to_file(MAIN_MENU_PATH)
