extends Control
## Map selection, reached from the main menu's Start button.
## Arena and Building have fixed buttons; extra maps are listed in EXTRA_MAPS.

const EXTRA_MAPS: Array = [
	{"title": "MULTI-ROOM", "path": "res://scenes/main/multi_room_map.tscn"},
	{"title": "GYM COMPOUND", "path": "res://scenes/main/gym_compound.tscn"},
	{"title": "CHALLENGE MAP", "path": "res://scenes/main/challenge_map.tscn"},
    {"title": "Deadfall Complex", "path": "res://scenes/main/deadfall_complex_mega.tscn"},
]

@onready var arena_button: Button = $CenterContainer/VBox/ArenaButton
@onready var building_button: Button = $CenterContainer/VBox/BuildingButton
@onready var back_button: Button = $CenterContainer/VBox/BackButton
@onready var placeholder_label: Label = $CenterContainer/VBox/PlaceholderLabel


func _ready() -> void:
	placeholder_label.visible = false
	arena_button.pressed.connect(_on_arena_pressed)
	building_button.pressed.connect(_on_building_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_add_extra_map_buttons()


func _add_extra_map_buttons() -> void:
	var vbox: Node = building_button.get_parent()
	var insert_at: int = building_button.get_index() + 1
	for m in EXTRA_MAPS:
		var b := Button.new()
		b.text = m["title"]
		b.custom_minimum_size = Vector2(340, 90)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_extra_map_pressed.bind(m["path"]))
		vbox.add_child(b)
		vbox.move_child(b, insert_at)
		insert_at += 1


func _on_extra_map_pressed(path: String) -> void:
	get_tree().change_scene_to_file(path)


func _on_arena_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_building_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/building_map.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
