extends Control
## Map selection, reached from the main menu's Start button.
## Arena loads the current gym map. Building is a placeholder until
## its asset is wired up.

@onready var arena_button: Button = $CenterContainer/VBox/ArenaButton
@onready var building_button: Button = $CenterContainer/VBox/BuildingButton
@onready var back_button: Button = $CenterContainer/VBox/BackButton
@onready var placeholder_label: Label = $CenterContainer/VBox/PlaceholderLabel


func _ready() -> void:
	placeholder_label.visible = false
	arena_button.pressed.connect(_on_arena_pressed)
	building_button.pressed.connect(_on_building_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _on_arena_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_building_pressed() -> void:
	placeholder_label.visible = true


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
