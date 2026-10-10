extends Control
## Map selection, reached from the main menu's Start button.
## MAPS tab: Arena, Building and the other normal maps (from map_config.gd).
## DLC tab: the buyable maps; locked ones point to the Market.

const MAP_CONFIG_PATH: String = "res://scripts/main_menu/map_config.gd"
const MARKET_PATH: String = "res://scripts/managers/market.gd"
const PROFILE_PATH: String = "res://scripts/managers/profile.gd"

@onready var arena_button: Button = $CenterContainer/VBox/ArenaButton
@onready var building_button: Button = $CenterContainer/VBox/BuildingButton
@onready var back_button: Button = $CenterContainer/VBox/BackButton
@onready var placeholder_label: Label = $CenterContainer/VBox/PlaceholderLabel

var _config = null
var _market = null
var _profile = null
var _normal_nodes: Array = []
var _dlc_nodes: Array = []
var _maps_tab: Button
var _dlc_tab: Button


func _ready() -> void:
    var cfg_script = load(MAP_CONFIG_PATH)
    if cfg_script != null:
        _config = cfg_script.new()
    var market_script = load(MARKET_PATH)
    if market_script != null:
        _market = market_script.new()
    var profile_script = load(PROFILE_PATH)
    if profile_script != null:
        _profile = profile_script.new()
    placeholder_label.visible = false
    placeholder_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    placeholder_label.custom_minimum_size = Vector2(340, 0)
    arena_button.pressed.connect(_on_arena_pressed)
    building_button.pressed.connect(_on_building_pressed)
    back_button.pressed.connect(_on_back_pressed)
    _add_tab_buttons()
    _add_extra_map_buttons()
    _add_dlc_buttons()
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


func _add_tab_buttons() -> void:
    var vbox: Node = arena_button.get_parent()
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    _maps_tab = _make_tab("MAPS", false)
    _dlc_tab = _make_tab("DLC", true)
    row.add_child(_maps_tab)
    row.add_child(_dlc_tab)
    vbox.add_child(row)
    vbox.move_child(row, arena_button.get_index())


func _make_tab(label: String, dlc: bool) -> Button:
    var b := Button.new()
    b.text = label
    b.toggle_mode = true
    b.custom_minimum_size = Vector2(160, 70)
    b.add_theme_font_size_override("font_size", 24)
    b.pressed.connect(_show_tab.bind(dlc))
    return b


func _show_tab(dlc: bool) -> void:
    arena_button.visible = (not dlc) and _map_enabled("arena")
    building_button.visible = (not dlc) and _map_enabled("building")
    for n in _normal_nodes:
        n.visible = not dlc
    for n in _dlc_nodes:
        n.visible = dlc
    placeholder_label.visible = false
    _maps_tab.button_pressed = not dlc
    _dlc_tab.button_pressed = dlc


func _add_extra_map_buttons() -> void:
    var vbox: Node = building_button.get_parent()
    var insert_at: int = building_button.get_index() + 1
    for m in _extra_maps():
        var b := Button.new()
        b.text = m["title"]
        b.custom_minimum_size = Vector2(340, 90)
        b.add_theme_font_size_override("font_size", 26)
        b.pressed.connect(_on_extra_map_pressed.bind(m["path"]))
        vbox.add_child(b)
        vbox.move_child(b, insert_at)
        insert_at += 1
        _normal_nodes.append(b)


func _add_dlc_buttons() -> void:
    var vbox: Node = building_button.get_parent()
    var insert_at: int = building_button.get_index() + 1
    for m in _dlc_maps():
        var id: String = str(m["id"])
        var b := Button.new()
        b.custom_minimum_size = Vector2(340, 90)
        b.add_theme_font_size_override("font_size", 26)
        if _owns(id):
            b.text = m["title"]
            b.pressed.connect(_on_extra_map_pressed.bind(m["path"]))
        else:
            var price: int = 0
            if _market != null:
                price = _market.map_cost(id)
            b.text = "%s\nLOCKED - %d Juice" % [m["title"], price]
            b.pressed.connect(_on_locked_pressed)
        vbox.add_child(b)
        vbox.move_child(b, insert_at)
        insert_at += 1
        _dlc_nodes.append(b)


func _on_locked_pressed() -> void:
    placeholder_label.text = "Locked. Buy this map in the Market (Profile > Market)."
    placeholder_label.visible = true


func _on_extra_map_pressed(path: String) -> void:
    get_tree().change_scene_to_file(path)


func _on_arena_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_building_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main/building_map.tscn")


func _on_back_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
