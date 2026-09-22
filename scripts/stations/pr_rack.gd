extends Area3D
## "PR Rack" - the Pack-a-Punch equivalent. Interacting starts a deadlift
## attempt; holding the button for lift_duration simulates "hitting a PR".
## On success, upgrades the player's currently held weapon.

@export var cost: int = 5000
@export var lift_duration: float = 2.5

var _lifting_player: Node = null
var _lift_progress: float = 0.0
var _charged: bool = false


func interact(player: Node) -> void:
	if not player.current_weapon:
		return
	if player.current_weapon.is_pr_upgraded:
		return
	if not _charged:
		if GameManager.try_spend_gains(cost):
			_charged = true
			_lifting_player = player
	elif _lifting_player == player:
		# Second press after the timed lift completes: apply the upgrade.
		if _lift_progress >= lift_duration:
			player.apply_pr_upgrade()
			_charged = false
			_lift_progress = 0.0
			_lifting_player = null


func _process(delta: float) -> void:
	if _charged and _lifting_player:
		_lift_progress = min(_lift_progress + delta, lift_duration)


func get_prompt_text() -> String:
	if not _charged:
		return "Hold F to load the bar - %d Gains" % cost
	if _lift_progress < lift_duration:
		return "Deadlifting PR... %d%%" % int((_lift_progress / lift_duration) * 100)
	return "PR hit! Hold F to rack your new max"
