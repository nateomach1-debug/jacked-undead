extends Control
## Market: spend Juice on characters, attachments, badges, reticles and DLC maps.

const PROFILE_PATH: String = "res://scripts/managers/profile.gd"
const MARKET_PATH: String = "res://scripts/managers/market.gd"
const REGISTRY_PATH: String = "res://scripts/weapons/attachments.gd"
const CHAR_REGISTRY_PATH: String = "res://scripts/managers/character_registry.gd"
const BADGES_PATH: String = "res://scripts/managers/badges.gd"
const ACH_PATH: String = "res://scripts/managers/achievements.gd"
const RETICLES_PATH: String = "res://scripts/ui/reticles.gd"
const MAP_CONFIG_PATH: String = "res://scripts/main_menu/map_config.gd"
const BACKDROP_PATH: String = "res://scripts/ui/poster_backdrop.gd"
const DIVIDER_PATH: String = "res://scripts/ui/poster_divider.gd"

const STAT_LABELS: Dictionary = {
    "damage_mult": "damage", "range_mult": "range", "spread_mult": "spread",
    "fire_rate_mult": "fire rate", "mag_mult": "magazine", "reserve_mult": "reserve ammo",
    "reload_speed_mult": "reload speed", "ads_zoom_mult": "ADS zoom",
}

var _profile = null
var _market = null
var _reg = null      # attachments registry
var _chars = null    # character registry
var _badges = null   # badge registry
var _ach = null      # achievements (reticle names)
var _ret = null      # reticle drawing script (previews)
var _cfg = null      # map config (DLC map titles)
var _juice_label: Label
var _list: VBoxContainer
# {"btn": Button, "label": Label, "card": PanelContainer, "chip": Label, "name": String,
#  "kind": "att"/"char"/"badge"/"ret"/"map", "id": String, "cost": int}
var _rows: Array = []


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    var profile_script = load(PROFILE_PATH)
    var market_script = load(MARKET_PATH)
    var reg_script = load(REGISTRY_PATH)
    var char_script = load(CHAR_REGISTRY_PATH)
    var badge_script = load(BADGES_PATH)
    var ach_script = load(ACH_PATH)
    var ret_script = load(RETICLES_PATH)
    var cfg_script = load(MAP_CONFIG_PATH)
    if profile_script != null:
        _profile = profile_script.new()
    if market_script != null:
        _market = market_script.new()
    if reg_script != null:
        _reg = reg_script.new()
    if char_script != null:
        _chars = char_script.new()
    if badge_script != null:
        _badges = badge_script.new()
    if ach_script != null:
        _ach = ach_script.new()
    if ret_script != null:
        _ret = ret_script.new()
    if cfg_script != null:
        _cfg = cfg_script.new()
    _build_ui()
    _show_tab("attachments")


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

    var top := HBoxContainer.new()
    outer.add_child(top)
    var title := Label.new()
    title.text = "MARKET"
    title.theme_type_variation = &"TitleLabel"
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    title.add_theme_font_size_override("font_size", 40)
    top.add_child(title)
    _juice_label = Label.new()
    _juice_label.theme_type_variation = &"TagLabel"
    _juice_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    _juice_label.add_theme_font_size_override("font_size", 26)
    top.add_child(_juice_label)

    _add_divider(outer)

    var tabs := HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 8)
    outer.add_child(tabs)
    var group := ButtonGroup.new()
    tabs.add_child(_make_tab("CHARACTERS", group, "characters"))
    tabs.add_child(_make_tab("ATTACHMENTS", group, "attachments"))
    tabs.add_child(_make_tab("BADGES", group, "badges"))
    tabs.add_child(_make_tab("RETICLES", group, "reticles"))
    tabs.add_child(_make_tab("MAPS", group, "maps"))

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    outer.add_child(scroll)
    _list = VBoxContainer.new()
    _list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _list.add_theme_constant_override("separation", 14)
    scroll.add_child(_list)

    var back := Button.new()
    back.text = "BACK"
    back.custom_minimum_size = Vector2(200, 70)
    back.add_theme_font_size_override("font_size", 26)
    back.pressed.connect(_close)
    outer.add_child(back)


func _make_tab(text: String, group: ButtonGroup, tab_id: String) -> Button:
    var b := Button.new()
    b.text = text
    b.toggle_mode = true
    b.button_group = group
    b.button_pressed = (tab_id == "attachments")
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.custom_minimum_size = Vector2(0, 56)
    b.add_theme_font_size_override("font_size", 18)
    b.pressed.connect(_show_tab.bind(tab_id))
    return b


func _show_tab(tab: String) -> void:
    for c in _list.get_children():
        _list.remove_child(c)
        c.queue_free()
    _rows.clear()
    if _profile == null or _market == null:
        _error("MARKET FAILED TO LOAD")
    elif tab == "attachments":
        if _reg == null:
            _error("ATTACHMENTS FAILED TO LOAD")
        else:
            _build_attachment_rows()
    elif tab == "characters":
        if _chars == null:
            _error("CHARACTERS FAILED TO LOAD")
        else:
            _build_character_rows()
    elif tab == "badges":
        if _badges == null:
            _error("BADGES FAILED TO LOAD")
        else:
            _build_badge_rows()
    elif tab == "reticles":
        _build_reticle_rows()
    elif tab == "maps":
        if _cfg == null:
            _error("MAPS FAILED TO LOAD")
        else:
            _build_map_rows()
    _update_buttons()


func _error(text: String) -> void:
    var err := Label.new()
    err.text = text
    err.theme_type_variation = &"DangerLabel"
    _list.add_child(err)


func _build_attachment_rows() -> void:
    for slot in _reg.SLOTS:
        var header := Label.new()
        header.text = str(slot).to_upper()
        header.theme_type_variation = &"GoldLabel"
        header.add_theme_font_size_override("font_size", 22)
        _list.add_child(header)
        for id in _reg.ATTACHMENTS.keys():
            var entry: Dictionary = _reg.ATTACHMENTS[id]
            if str(entry["slot"]) != str(slot):
                continue
            _add_row("att", str(id), str(entry["name"]), _describe(entry["mods"]), int(entry["cost"]))


func _build_character_rows() -> void:
    for i in range(_chars.count()):
        var id: String = _chars.id_at(i)
        _add_row("char", id, _chars.title_at(i), "", _market.character_cost(id))


func _build_badge_rows() -> void:
    for id in _badges.ids():
        var bid: String = str(id)
        _add_row("badge", bid, "%s %s" % [_badges.icon(bid), _badges.title(bid)],
                _badges.description(bid), _badges.cost(bid), _badges.color(bid))


func _build_reticle_rows() -> void:
    var names: Dictionary = {}
    if _ach != null:
        names = _ach.RETICLES
    for id in _market.RETICLE_COSTS.keys():
        var rid: String = str(id)
        _add_row("ret", rid, str(names.get(rid, rid)),
                "Reticle for any optic. Pick it in the weapon gallery.",
                int(_market.RETICLE_COSTS[id]))


## DLC maps (only the ones turned on in map_config.gd).
func _build_map_rows() -> void:
    for m in _cfg.get_dlc_maps():
        var mid: String = str(m["id"])
        _add_row("map", mid, str(m["title"]), _market.map_desc(mid), _market.map_cost(mid))


## Small picture of a reticle for the Market rows (animated ones keep redrawing).
func _draw_preview(ctrl: Control, id: String) -> void:
    if _ret != null:
        _ret.draw_reticle(ctrl, ctrl.size * 0.5, id, 22.0, Color(1, 1, 1))


## One card: name + description on the left, price chip and action button on the right.
func _add_row(kind: String, id: String, item_name: String, desc: String, cost: int,
        tint: Color = Color(1, 1, 1)) -> void:
    var card := PanelContainer.new()
    card.theme_type_variation = &"CardPanel"
    _list.add_child(card)

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 14)
    card.add_child(row)

    if kind == "ret":
        var prev := Control.new()
        prev.custom_minimum_size = Vector2(84, 84)
        prev.clip_contents = true
        prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        prev.draw.connect(_draw_preview.bind(prev, id))
        row.add_child(prev)

    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(info)
    var shown_name: String = item_name.to_upper()
    var name_l := Label.new()
    name_l.text = shown_name
    name_l.add_theme_font_size_override("font_size", 26)
    if tint != Color(1, 1, 1):
        name_l.add_theme_color_override("font_color", tint)
    info.add_child(name_l)
    if desc != "":
        var d := Label.new()
        d.text = desc.to_upper()
        d.theme_type_variation = &"SmallLabel"
        d.add_theme_font_size_override("font_size", 16)
        d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        info.add_child(d)

    var side := VBoxContainer.new()
    side.add_theme_constant_override("separation", 8)
    side.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(side)

    var chip := Label.new()
    chip.theme_type_variation = &"TagLabel"
    chip.add_theme_font_size_override("font_size", 18)
    chip.size_flags_horizontal = Control.SIZE_SHRINK_END
    side.add_child(chip)

    var b := Button.new()
    b.custom_minimum_size = Vector2(200, 64)
    b.add_theme_font_size_override("font_size", 22)
    b.pressed.connect(_buy.bind(kind, id, cost))
    side.add_child(b)
    _rows.append({"btn": b, "label": name_l, "card": card, "chip": chip, "name": shown_name,
            "kind": kind, "id": id, "cost": cost})


## "+20% range, +10% damage, -10% fire rate"
func _describe(mods: Dictionary) -> String:
    var parts: Array = []
    for key in mods.keys():
        var pct: int = int(round((float(mods[key]) - 1.0) * 100.0))
        parts.append("%+d%% %s" % [pct, str(STAT_LABELS.get(key, key))])
    return ", ".join(parts)


func _owned(kind: String, id: String) -> bool:
    if kind == "char":
        return _market.owns_character(_profile, id)
    if kind == "badge":
        return _market.owns_badge(_profile, id)
    if kind == "ret":
        return _market.owns_reticle(_profile, id)
    if kind == "map":
        return _market.owns_map(_profile, id)
    return _market.owns_attachment(_profile, id)


func _key(kind: String, id: String) -> String:
    if kind == "char":
        return _market.character_key(id)
    if kind == "badge":
        return _market.badge_key(id)
    if kind == "ret":
        return _market.reticle_key(id)
    if kind == "map":
        return _market.map_key(id)
    return _market.attachment_key(id)


## Buys the item. Owned badges toggle equipped instead.
func _buy(kind: String, id: String, cost: int) -> void:
    if _profile == null or _market == null:
        return
    if _owned(kind, id):
        if kind == "badge":
            NetManager.set_badge("" if NetManager.badge_id == id else id)
            _update_buttons()
        return
    if _profile.spend_juice(cost):
        _profile.add_item(_key(kind, id))
    _update_buttons()


## Restyles every card: yellow strip + BUY when affordable, red strip + LOCKED when not,
## green strip + OWNED chip once bought (badges keep an EQUIP / UNEQUIP button).
func _update_buttons() -> void:
    if _profile == null:
        _juice_label.text = ""
        return
    var juice: int = _profile.get_juice()
    _juice_label.text = "JUICE: %d" % juice
    if _market == null:
        return
    for r in _rows:
        var b: Button = r["btn"]
        var kind: String = str(r["kind"])
        var id: String = str(r["id"])
        var label: Label = r["label"]
        var card: PanelContainer = r["card"]
        var chip: Label = r["chip"]
        label.text = str(r["name"])
        if _owned(kind, id):
            card.theme_type_variation = &"CardPanelOwned"
            chip.text = "OWNED"
            chip.theme_type_variation = &"OwnedTag"
            if kind == "badge":
                var equipped: bool = NetManager.badge_id == id
                b.visible = true
                b.disabled = false
                b.text = "UNEQUIP" if equipped else "EQUIP"
                b.theme_type_variation = &"" if equipped else &"MainButton"
                if equipped:
                    label.text = str(r["name"]) + "  (EQUIPPED)"
            else:
                b.visible = false
        else:
            var cost: int = int(r["cost"])
            chip.text = "%d JUICE" % cost
            b.visible = true
            if juice >= cost:
                card.theme_type_variation = &"CardPanel"
                chip.theme_type_variation = &"TagLabel"
                b.text = "BUY"
                b.disabled = false
                b.theme_type_variation = &"MainButton"
            else:
                card.theme_type_variation = &"CardPanelLocked"
                chip.theme_type_variation = &"LockedTag"
                b.text = "LOCKED"
                b.disabled = true
                b.theme_type_variation = &"DangerButton"


## Refreshes the main menu's Juice label, then closes.
func _close() -> void:
    var p := get_parent()
    if p != null and _profile != null:
        for c in p.get_children():
            if c is Label and (c as Label).text.begins_with("JUICE:"):
                (c as Label).text = "JUICE: %d" % _profile.get_juice()
    queue_free()
