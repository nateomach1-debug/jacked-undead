extends Control
## Market: spend Juice. Attachments tab now; Characters and Badges tabs come next.

const PROFILE_PATH: String = "res://scripts/managers/profile.gd"
const MARKET_PATH: String = "res://scripts/managers/market.gd"
const REGISTRY_PATH: String = "res://scripts/weapons/attachments.gd"

const STAT_LABELS: Dictionary = {
	"damage_mult": "damage", "range_mult": "range", "spread_mult": "spread",
	"fire_rate_mult": "fire rate", "mag_mult": "magazine", "reserve_mult": "reserve ammo",
	"reload_speed_mult": "reload speed", "ads_zoom_mult": "ADS zoom",
}

var _profile = null
var _market = null
var _reg = null
var _juice_label: Label
var _buttons: Dictionary = {}   # attachment id -> Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var profile_script = load(PROFILE_PATH)
	var market_script = load(MARKET_PATH)
	var reg_script = load(REGISTRY_PATH)
	if profile_script != null:
		_profile = profile_script.new()
	if market_script != null:
		_market = market_script.new()
	if reg_script != null:
		_reg = reg_script.new()
	_build_ui()
	_update_buttons()


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
	tabs.add_child(_make_tab("CHARACTERS (SOON)", true))
	tabs.add_child(_make_tab("ATTACHMENTS", false))
	tabs.add_child(_make_tab("BADGES (SOON)", true))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	if _reg == null or _market == null or _profile == null:
		var err := Label.new()
		err.text = "MARKET FAILED TO LOAD"
		err.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		list.add_child(err)
	else:
		_build_attachment_rows(list)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 70)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(_close)
	outer.add_child(back)


func _make_tab(text: String, disabled: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.toggle_mode = true
	b.button_pressed = not disabled
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 56)
	b.add_theme_font_size_override("font_size", 20)
	return b


func _build_attachment_rows(list: VBoxContainer) -> void:
	for slot in _reg.SLOTS:
		var header := Label.new()
		header.text = str(slot).to_upper()
		header.add_theme_font_size_override("font_size", 22)
		header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		list.add_child(header)
		for id in _reg.ATTACHMENTS.keys():
			var entry: Dictionary = _reg.ATTACHMENTS[id]
			if str(entry["slot"]) != str(slot):
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			list.add_child(row)

			var info := VBoxContainer.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			var name_l := Label.new()
			name_l.text = str(entry["name"])
			name_l.add_theme_font_size_override("font_size", 24)
			info.add_child(name_l)
			var desc := Label.new()
			desc.text = _describe(entry["mods"])
			desc.add_theme_font_size_override("font_size", 16)
			desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
			info.add_child(desc)

			var b := Button.new()
			b.custom_minimum_size = Vector2(190, 60)
			b.add_theme_font_size_override("font_size", 20)
			b.pressed.connect(_buy.bind(str(id)))
			row.add_child(b)
			_buttons[str(id)] = b


## "+20% range, +10% damage, -10% fire rate"
func _describe(mods: Dictionary) -> String:
	var parts: Array = []
	for key in mods.keys():
		var pct: int = int(round((float(mods[key]) - 1.0) * 100.0))
		parts.append("%+d%% %s" % [pct, str(STAT_LABELS.get(key, key))])
	return ", ".join(parts)


func _buy(id: String) -> void:
	if _reg == null or _market == null or _profile == null:
		return
	if _market.owns_attachment(_profile, id):
		return
	var cost: int = int(_reg.ATTACHMENTS[id]["cost"])
	if _profile.spend_juice(cost):
		_profile.add_item(_market.attachment_key(id))
	_update_buttons()


func _update_buttons() -> void:
	if _profile == null:
		_juice_label.text = ""
		return
	var juice: int = _profile.get_juice()
	_juice_label.text = "JUICE: %d" % juice
	if _reg == null or _market == null:
		return
	for id in _buttons.keys():
		var b: Button = _buttons[id]
		if _market.owns_attachment(_profile, str(id)):
			b.text = "OWNED"
			b.disabled = true
		else:
			var cost: int = int(_reg.ATTACHMENTS[id]["cost"])
			b.text = "%d JUICE" % cost
			b.disabled = juice < cost


## Refreshes the main menu's Juice label, then closes.
func _close() -> void:
	var p := get_parent()
	if p != null and _profile != null:
		for c in p.get_children():
			if c is Label and (c as Label).text.begins_with("JUICE:"):
				(c as Label).text = "JUICE: %d" % _profile.get_juice()
	queue_free()
