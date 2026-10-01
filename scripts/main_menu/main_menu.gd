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
	_add_dev_button()


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
