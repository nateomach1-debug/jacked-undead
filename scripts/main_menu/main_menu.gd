extends Control
## Main menu: Start loads the game scene, Options shows the options panel
## (with a locked Developer menu), Exit quits the app entirely.

@onready var start_button: Button = $CenterContainer/VBox/StartButton
@onready var options_button: Button = $CenterContainer/VBox/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBox/ExitButton
@onready var options_panel: Control = $OptionsPanel
@onready var options_back_button: Button = $OptionsPanel/CenterContainer/VBox/BackButton


func _ready() -> void:
	options_panel.visible = false
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	options_back_button.pressed.connect(_on_options_back_pressed)
	_add_settings_button()
	_add_character_picker()
	_add_dev_button()
	_add_coop_button()
	_add_weapons_button()
	_add_market_button()
	_add_juice_label()


## Adds a DEVELOPER button to the options panel, just above BACK.
func _add_dev_button() -> void:
	var vbox: Node = options_back_button.get_parent()
	var dev_button := Button.new()
	dev_button.text = "DEVELOPER"
	dev_button.custom_minimum_size = Vector2(240, 80)
	dev_button.add_theme_font_size_override("font_size", 24)
	dev_button.pressed.connect(_on_dev_pressed)
	vbox.add_child(dev_button)
	vbox.move_child(dev_button, options_back_button.get_index())


## Adds a CO-OP button to the main menu, just below START.
func _add_coop_button() -> void:
	var vbox: Node = start_button.get_parent()
	var coop_button := Button.new()
	coop_button.text = "CO-OP"
	coop_button.custom_minimum_size = start_button.custom_minimum_size
	coop_button.add_theme_font_size_override("font_size", 26)
	coop_button.pressed.connect(_on_coop_pressed)
	vbox.add_child(coop_button)
	vbox.move_child(coop_button, start_button.get_index() + 1)


func _on_coop_pressed() -> void:
	var menu_script = load("res://scripts/ui/coop_menu.gd")
	if menu_script == null:
		push_warning("coop_menu.gd is missing or broken.")
		return
	var menu := Control.new()
	menu.set_script(menu_script)
	add_child(menu)


func _on_dev_pressed() -> void:
	var menu_script = load("res://scripts/ui/dev_menu.gd")
	if menu_script == null:
		push_warning("dev_menu.gd is missing or broken.")
		return
	var menu := Control.new()
	menu.set_script(menu_script)
	add_child(menu)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/map_select.tscn")


func _on_options_pressed() -> void:
	options_panel.visible = true


func _on_options_back_pressed() -> void:
	options_panel.visible = false


func _on_exit_pressed() -> void:
	get_tree().quit()


## Adds the character picker (with preview) to the options panel, above DEVELOPER.
func _add_character_picker() -> void:
	var vbox: Node = options_back_button.get_parent()
	var picker_script = load("res://scripts/ui/character_picker.gd")
	if picker_script == null:
		_add_menu_note(vbox, "CHARACTER PICKER FAILED TO LOAD")
		return
	var picker := VBoxContainer.new()
	picker.set_script(picker_script)
	vbox.add_child(picker)
	vbox.move_child(picker, options_back_button.get_index())


func _add_menu_note(vbox: Node, text: String) -> void:
	var note := Label.new()
	note.text = text
	note.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(note)
	vbox.move_child(note, options_back_button.get_index())


## Adds a SETTINGS button to the options panel, above BACK.
func _add_settings_button() -> void:
	var vbox: Node = options_back_button.get_parent()
	var b := Button.new()
	b.text = "SETTINGS"
	b.custom_minimum_size = Vector2(240, 70)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(_on_settings_pressed)
	vbox.add_child(b)
	vbox.move_child(b, options_back_button.get_index())


func _on_settings_pressed() -> void:
	var menu_script = load("res://scripts/ui/settings_menu.gd")
	if menu_script == null:
		push_warning("settings_menu.gd is missing or broken.")
		return
	var menu := Control.new()
	menu.set_script(menu_script)
	add_child(menu)


## Shows the saved Juice balance in the top-right corner.
func _add_juice_label() -> void:
	var profile_script = load("res://scripts/managers/profile.gd")
	if profile_script == null:
		return
	var profile = profile_script.new()
	if profile == null:
		return
	var label := Label.new()
	label.text = "JUICE: %d" % profile.get_juice()
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	label.grow_horizontal = Control.GROW_DIRECTION_BEGIN


## Adds a WEAPONS button to the main menu, just below CO-OP.
func _add_weapons_button() -> void:
	var vbox: Node = start_button.get_parent()
	var b := Button.new()
	b.text = "WEAPONS"
	b.custom_minimum_size = start_button.custom_minimum_size
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(_on_weapons_pressed)
	vbox.add_child(b)
	vbox.move_child(b, start_button.get_index() + 2)


func _on_weapons_pressed() -> void:
	var menu_script = load("res://scripts/ui/weapon_gallery.gd")
	if menu_script == null:
		push_warning("weapon_gallery.gd is missing or broken.")
		return
	var menu := Control.new()
	menu.set_script(menu_script)
	add_child(menu)


## Adds a MARKET button to the main menu, just below WEAPONS.
func _add_market_button() -> void:
	var vbox: Node = start_button.get_parent()
	var b := Button.new()
	b.text = "MARKET"
	b.custom_minimum_size = start_button.custom_minimum_size
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(_on_market_pressed)
	vbox.add_child(b)
	vbox.move_child(b, start_button.get_index() + 3)


func _on_market_pressed() -> void:
	var menu_script = load("res://scripts/ui/market_menu.gd")
	if menu_script == null:
		push_warning("market_menu.gd is missing or broken.")
		return
	var menu := Control.new()
	menu.set_script(menu_script)
	add_child(menu)
