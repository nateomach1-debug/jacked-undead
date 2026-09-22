extends Zombie
## "Roid Rager" - a special variant zombie. Tankier, faster, hits harder.
## Attach to a duplicate of the Zombie scene (see scenes/zombies/roid_rager.tscn)
## with this script instead of zombie.gd, or just override exported stats
## on a scene variant in the editor.

func _ready() -> void:
	max_health = 300.0
	move_speed = 4.5
	attack_damage = 25.0
	gains_on_death = 35
	super._ready()
