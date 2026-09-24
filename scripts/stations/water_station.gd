extends Area3D
## "Water Station" - the wall-buy equivalent. Refills reserve ammo for
## the player's current weapon in exchange for Gains.

@export var cost: int = 500
@export var refill_amount: int = 60


func interact(player: Node) -> void:
	if not player.current_weapon:
		return
	if GameManager.try_spend_gains(cost):
		player.add_reserve_ammo(refill_amount)


func get_prompt_text() -> String:
	return "Tap USE to refill water (ammo) - %d Gains" % cost
