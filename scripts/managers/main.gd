extends Node3D
## Root script for the main level. Connects the HUD to the player and the
## round manager, and resets the run state on load. Game-over handling lives in
## scripts/ui/game_over_screen.gd, listening to GameManager.player_died.

const COOP_SYNC_PATH: String = "res://scripts/managers/coop_sync.gd"

@onready var player: Node = $Player
@onready var hud: CanvasLayer = $HUD
@onready var round_manager: Node = get_node_or_null("RoundManager")


func _ready() -> void:
	GameManager.reset_run()
	if player and hud and hud.has_method("bind_player"):
		hud.bind_player(player)
	if round_manager and hud and hud.has_method("bind_round_manager"):
		hud.bind_round_manager(round_manager)
	if NetManager.is_online:
		_setup_coop()


## Co-op: only the host runs zombies and rounds; other phones show copies.
## Each phone's player starts in its own spot so they don't overlap.
func _setup_coop() -> void:
	if round_manager and not NetManager.is_host:
		round_manager.zombie_scene = null
		round_manager.roid_rager_scene = null

	var coop_script = load(COOP_SYNC_PATH)
	if coop_script == null:
		push_warning("coop_sync.gd is missing or broken.")
		return

	var my_id: int = multiplayer.get_unique_id()
	var ids: Array = multiplayer.get_peers()
	ids.append(my_id)
	ids.sort()
	var slot: int = ids.find(my_id)
	if player:
		player.global_position = Vector3(float(slot) * 2.0 - 1.0, 1.0, 0.0)

	var coop := Node.new()
	coop.set_script(coop_script)
	coop.name = "CoopSync"
	add_child(coop)
	coop.setup(player, round_manager)
