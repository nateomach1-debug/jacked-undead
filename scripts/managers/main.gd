extends Node3D
## Root script for the main level. Connects the HUD to the player and the
## round manager, and resets the run state on load. Game-over handling lives in
## scripts/ui/game_over_screen.gd, listening to GameManager.player_died.

@onready var player: Node = $Player
@onready var hud: CanvasLayer = $HUD
@onready var round_manager: Node = get_node_or_null("RoundManager")


func _ready() -> void:
    MusicManager.set_playlist_for_scene(self)
    GameManager.reset_run()
    if player and hud and hud.has_method("bind_player"):
        hud.bind_player(player)
    if round_manager and hud and hud.has_method("bind_round_manager"):
        hud.bind_round_manager(round_manager)

    if GameManager.TESTING_PAUSE_ENABLED:
        var pause_script = load("res://scripts/ui/testing_pause_menu.gd")
        if pause_script != null:
            var pause_menu: Node = pause_script.new()
            pause_menu.name = "TestingPauseMenu"
            pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
            add_child(pause_menu)
        else:
            push_warning("Testing pause menu script could not be loaded."
)
