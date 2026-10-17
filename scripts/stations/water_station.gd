extends Area3D
## "Water Station" - the wall-buy equivalent. Refills reserve ammo for
## the player's current weapon in exchange for Gains. Price rises with
## the weapon's PR level (see ammo_scaling.gd).

@export var cost: int = 500
@export var refill_amount: int = 60


func _price(player: Node) -> int:
    var AS = load("res://scripts/stations/ammo_scaling.gd")
    if AS == null or player == null:
        return cost
    return AS.scaled(cost, player.current_weapon)


func interact(player: Node) -> void:
    if not player.current_weapon:
        return
    if GameManager.try_spend_gains(_price(player)):
        player.add_reserve_ammo(refill_amount)


func get_prompt_text() -> String:
    var player := get_tree().get_first_node_in_group("player")
    return "Tap USE to refill water (ammo) - %d Gains" % _price(player)

# END OF FILE
