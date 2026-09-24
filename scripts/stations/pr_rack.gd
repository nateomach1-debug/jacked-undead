extends Area3D
## "PR Rack" - the Pack-a-Punch equivalent. One tap pays the Gains cost
## and instantly upgrades the weapon currently in your hands.

@export var cost: int = 5000


func interact(player: Node) -> void:
	if not player.current_weapon or player.current_weapon.is_pr_upgraded:
		return
	if GameManager.try_spend_gains(cost):
		player.apply_pr_upgrade()


func get_prompt_text() -> String:
	return "Tap USE to rack a PR - %d Gains" % cost
