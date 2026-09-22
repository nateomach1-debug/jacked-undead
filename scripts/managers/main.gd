extends Node3D
## Root script for the main level. Connects the HUD to the player and
## resets the run state on load.

@onready var player: Node = $Player
@onready var hud: CanvasLayer = $HUD


func _ready() -> void:
	GameManager.reset_run()
	if player and hud and hud.has_method("bind_player"):
		hud.bind_player(player)
	GameManager.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("Player died on round ", GameManager.round_number, " with ", GameManager.gains, " gains.")
	# TODO: show a game-over / restart screen here.
