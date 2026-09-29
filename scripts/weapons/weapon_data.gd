extends Resource
class_name WeaponData
## A reusable stat block for a weapon. Create .tres instances of this
## (Right click in FileSystem -> New Resource -> WeaponData) for each gun,
## or build them in code (see locker_weapons.gd).

enum FireMode { HITSCAN, FLAME, EXPLOSIVE }

@export var weapon_name: String = "Pistol"
@export var damage: float = 20.0
@export var fire_rate: float = 0.25
@export var mag_size: int = 12
@export var max_reserve_ammo: int = 96
@export var range: float = 60.0
@export var is_pr_upgraded: bool = false
@export var model_scene: PackedScene
@export var fire_sound: AudioStream

@export var fire_mode: FireMode = FireMode.HITSCAN
@export var pellets: int = 1
@export var spread_degrees: float = 0.0
@export var burst_count: int = 1
@export var burst_interval: float = 0.06
@export var reload_time: float = 0.0
@export var gains_per_hit: int = 10
@export var burn_damage_per_second: float = 0.0
@export var burn_duration: float = 0.0
@export var splash_radius: float = 0.0
@export var projectile_speed: float = 25.0
@export var projectile_gravity: float = 0.0
@export var self_damage_multiplier: float = 0.0

@export var placeholder_kind: String = ""
@export var placeholder_size: Vector3 = Vector3.ZERO
@export var placeholder_color: Color = Color(0.3, 0.3, 0.3)


func create_model() -> Node3D:
	if model_scene:
		return model_scene.instantiate() as Node3D
	if placeholder_kind == "":
		placeholder_kind = weapon_name.replace(" - 1RM", "")
	if placeholder_kind != "":
		# Loaded on demand so a problem in gun_models.gd can never break WeaponData itself.
		var gun_models = load("res://scripts/weapons/gun_models.gd")
		if gun_models:
			return gun_models.build(placeholder_kind)
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


func get_pr_upgraded_copy() -> WeaponData:
	var upgraded: WeaponData = duplicate()
	upgraded.weapon_name = weapon_name + " - 1RM"
	upgraded.damage *= 2.2
	upgraded.burn_damage_per_second *= 2.2
	upgraded.mag_size = int(mag_size * 1.5)
	upgraded.max_reserve_ammo = int(max_reserve_ammo * 2)
	upgraded.is_pr_upgraded = true
	return upgraded
