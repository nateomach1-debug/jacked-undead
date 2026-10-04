extends Control
## Market: spend Juice on characters, attachments and badges.

const PROFILE_PATH: String = "res://scripts/managers/profile.gd"
const MARKET_PATH: String = "res://scripts/managers/market.gd"
const REGISTRY_PATH: String = "res://scripts/weapons/attachments.gd"
const CHAR_REGISTRY_PATH: String = "res://scripts/managers/character_registry.gd"
const BADGES_PATH: String = "res://scripts/managers/badges.gd"

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
var _juice_label: Label
var _list: VBoxContainer
# {"btn": Button, "label": Label, "name": String, "kind": "att"/"char"/"badge", "id": String, "cost": int}
var _rows: Array = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var profile_script = load(PROFILE_PATH)
	var market_script = load(MARKET_PATH)
	var reg_script = load(REGISTRY_PATH)
	var char_script = load(CHAR_REGISTRY_PATH)
	var badge_script = load(BADGES_PATH)
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
	_build_ui()
	_show_tab("attachments")


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := Label.new()
	title.text = "MARKET"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	top.add_child(title)
	_juice_label = Label.new()
	_juice_label.add_theme_font_size_override("font_size", 28)
	_juice_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	top.add_child(_juice_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	outer.add_child(tabs)
	var group := ButtonGroup.new()
	tabs.add_child(_make_tab("CHARACTERS", group, "characters"))
	tabs.add_child(_make_tab("ATTACHMENTS", group, "attachments"))
	tabs.add_child(_make_tab("BADGES", group, "badges"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
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
	b.add_theme_font_size_override("font_size", 20)
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
	_update_buttons()


func _error(text: String) -> void:
	var err := Label.new()
	err.text = text
	err.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	_list.add_child(err)


func _build_attachment_rows() -> void:
	for slot in _reg.SLOTS:
		var header := Label.new()
		header.text = str(slot).to_upper()
		header.add_theme_font_size_override("font_size", 22)
		header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
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


func _add_row(kind: String, id: String, item_name: String, desc: String, cost: int,
		tint: Color = Color(1, 1, 1)) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_list.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_l := Label.new()
	name_l.text = item_name
	name_l.add_theme_font_size_override("font_size", 24)
	name_l.add_theme_color_override("font_color", tint)
	info.add_child(name_l)
	if desc != "":
		var d := Label.new()
		d.text = desc
		d.add_theme_font_size_override("font_size", 16)
		d.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(d)

	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 60)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(_buy.bind(kind, id, cost))
	row.add_child(b)
	_rows.append({"btn": b, "label": name_l, "name": item_name, "kind": kind, "id": id, "cost": cost})


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
	return _market.owns_attachment(_profile, id)


func _key(kind: String, id: String) -> String:
	if kind == "char":
		return _market.character_key(id)
	if kind == "badge":
		return _market.badge_key(id)
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
		label.text = str(r["name"])
		if _owned(kind, id):
			if kind == "badge":
				var equipped: bool = NetManager.badge_id == id
				b.text = "UNEQUIP" if equipped else "EQUIP"
				b.disabled = false
				if equipped:
					label.text = str(r["name"]) + "  (EQUIPPED)"
			else:
				b.text = "OWNED"
				b.disabled = true
		else:
			b.text = "%d JUICE" % int(r["cost"])
			b.disabled = juice < int(r["cost"])


## Refreshes the main menu's Juice label, then closes.
func _close() -> void:
	var p := get_parent()
	if p != null and _profile != null:
		for c in p.get_children():
			if c is Label and (c as Label).text.begins_with("JUICE:"):
				(c as Label).text = "JUICE: %d" % _profile.get_juice()
	queue_free()
