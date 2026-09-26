extends Control
## Main menu: Start loads the game scene, Options shows a placeholder
## panel, Exit quits the app entirely.

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


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_options_pressed() -> void:
	options_panel.visible = true


func _on_options_back_pressed() -> void:
	options_panel.visible = false


func _on_exit_pressed() -> void:
	get_tree().quit()
