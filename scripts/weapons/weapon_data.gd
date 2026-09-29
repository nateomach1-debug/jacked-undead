extends Resource
class_name WeaponData
## A reusable stat block for a weapon. Create .tres instances of this
## (Right click in FileSystem -> New Resource -> WeaponData) for each gun.

@export var weapon_name: String = "Pistol"
@export var damage: float = 20.0
@export var fire_rate: float = 0.25       # seconds between shots
@export var mag_size: int = 12
@export var max_reserve_ammo: int = 96
@export var range: float = 60.0
@export var is_pr_upgraded: bool = false  # true once run through the PR Rack
@export var model_scene: PackedScene      # the .gltf viewmodel shown in the player's hands
@export var fire_sound: AudioStream       # played each shot -- set once you've uploaded audio files

## Returns a duplicated, upgraded copy of this weapon after a Pack-a-Punch
## ("hitting a PR") pass. Never mutates the original resource.
func get_pr_upgraded_copy() -> WeaponData:
	var upgraded: WeaponData = duplicate()
	upgraded.weapon_name = weapon_name + " - 1RM"
	upgraded.damage *= 2.2
	upgraded.mag_size = int(mag_size * 1.5)
	upgraded.max_reserve_ammo = int(max_reserve_ammo * 2)
	upgraded.is_pr_upgraded = true
	return upgraded
