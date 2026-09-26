extends CanvasLayer

@onready var kills_label: Label = $Dim/CenterContainer/VBox/KillsLabel
@onready var gains_label: Label = $Dim/CenterContainer/VBox/GainsLabel
@onready var round_label: Label = $Dim/CenterContainer/VBox/RoundLabel
@onready var retry_button: Button = $Dim/CenterContainer/VBox/RetryButton
@onready var menu_button: Button = $Dim/CenterContainer/VBox/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	GameManager.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	kills_label.text = "Zombies Killed: %d" % GameManager.kills
	gains_label.text = "Gains Earned: %d" % GameManager.gains
	round_label.text = "Round Reached: %d" % GameManager.round_number
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
