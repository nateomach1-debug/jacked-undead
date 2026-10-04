extends Control
## Profile hub: WEAPONS, MARKET and ACHIEVEMENTS in one place.
## Each screen opens on top of this one (as a child of the main menu) and closes back to it.

const SCREENS: Array = [
	{"text": "WEAPONS", "path": "res://scripts/ui/weapon_gallery.gd"},
	{"text": "MARKET", "path": "res://scripts/ui/market_menu.gd"},
	{"text": "ACHIEVEMENTS", "path": "res://scripts/ui/achievements_menu.gd"},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "PROFILE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	for s in SCREENS:
		var b := Button.new()
		b.text = str(s["text"])
		b.custom_minimum_size = Vector2(340, 80)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_open.bind(str(s["path"])))
		vbox.add_child(b)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(340, 70)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(queue_free)
	vbox.add_child(back)


## Opens a screen on top of the hub. It's added to the main menu (the hub's parent) so
## screens that refresh the main menu's Juice label can find it.
func _open(path: String) -> void:
	var menu_script = load(path)
	if menu_script == null:
		push_warning("%s is missing or broken." % path)
		return
	var menu := Control.new()
	menu.set_script(menu_script)
	var host: Node = get_parent()
	if host == null:
		host = self
	host.add_child(menu)
