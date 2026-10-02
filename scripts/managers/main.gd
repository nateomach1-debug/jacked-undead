extends Node3D
## Root script for the main level. Connects the HUD to the player and the
## round manager, and resets the run state on load. Game-over handling lives in
## scripts/ui/game_over_screen.gd, listening to GameManager.player_died.

@onready var player: Node = $Player
@onready var hud: CanvasLayer = $HUD
@onready var round_manager: Node = get_node_or_null("RoundManager")


func _ready() -> void:
	GameManager.reset_run()
	if player and hud and hud.has_method("bind_player"):
		hud.bind_player(player)
	if round_manager and hud and hud.has_method("bind_round_manager"):
		hud.bind_round_manager(round_manager)
