extends Resource
class_name WeaponData
## A reusable stat block for a weapon. Create .tres instances of this
## (Right click in FileSystem -> New Resource -> WeaponData) for each gun,
## or build them in code (see locker_weapons.gd).

enum FireMode { HITSCAN, FLAME, EXPLOSIVE }

@export var weapon_name: String = "Pistol"
@export var damage: float = 20.0          # per bullet / per pellet / per flame tick / per explosion
@export var fire_rate: float = 0.25       # seconds between shots (between bursts for burst guns)
@export var mag_size: int = 12
@export var max_reserve_ammo: int = 96
@export var range: float = 60.0
@export var is_pr_upgraded: bool = false  # true once run through the PR Rack
@export var model_scene: PackedScene      # the .gltf viewmodel shown in the player's hands
@export var fire_sound: AudioStream       # played each shot -- set once you've uploaded audio files

# --- Extended gun behaviour (all defaults match the old single-bullet gun) ---
@export var fire_mode: FireMode = FireMode.HITSCAN
@export var pellets: int = 1              # rays per shot (shotguns)
@export var spread_degrees: float = 0.0   # random cone per pellet
@export var burst_count: int = 1          # rounds per trigger pull
@export var burst_interval: float = 0.06  # seconds between rounds inside a burst
@export var reload_time: float = 0.0      # seconds; 0 = instant reload (old behaviour)
@export var gains_per_hit: int = 10       # Gains paid once per zombie hit per shot
@export var burn_damage_per_second: float = 0.0
@export var burn_duration: float = 0.0
@export var splash_radius: float = 0.0    # explosive guns
@export var projectile_speed: float = 25.0
@export var projectile_gravity: float = 0.0
@export var self_damage_multiplier: float = 0.0  # fraction of blast damage the shooter takes

# --- Placeholder model, used when model_scene is empty ---
@export var placeholder_size: Vector3 = Vector3.ZERO
@export var placeholder_color: Color = Color(0.3, 0.3, 0.3)


## Returns a new Node3D to show this weapon: the real .gltf if there is
## one, otherwise a simple colored box, otherwise null.
func create_model() -> Node3D:
	if model_scene:
		return model_scene.instantiate() as Node3D
	if placeholder_size != Vector3.ZERO:
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = placeholder_size
		mesh_instance.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = placeholder_color
		mesh_instance.material_override = mat
		return mesh_instance
	return null


## Returns a duplicated, upgraded copy of this weapon after a Pack-a-Punch
## ("hitting a PR") pass. Never mutates the original resource.
func get_pr_upgraded_copy() -> WeaponData:
	var upgraded: WeaponData = duplicate()
	upgraded.weapon_name = weapon_name + " - 1RM"
	upgraded.damage *= 2.2
	upgraded.burn_damage_per_second *= 2.2
	upgraded.mag_size = int(mag_size * 1.5)
	upgraded.max_reserve_ammo = int(max_reserve_ammo * 2)
	upgraded.is_pr_upgraded = true
	return upgraded
