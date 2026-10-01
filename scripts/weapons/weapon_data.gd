extends Resource
class_name WeaponData
## A reusable stat block for a weapon. Create .tres instances of this
## (Right click in FileSystem -> New Resource -> WeaponData) for each gun,
## or build them in code (see locker_weapons.gd).

enum FireMode { HITSCAN, FLAME, EXPLOSIVE }

# PR Rack upgrade levels. Each list holds the TOTAL bonus at that level
# (index 0 = level 1), applied to the gun's original stats.
const PR_MAX_LEVEL: int = 3
const PR_SUFFIXES: Array = [" - 1RM", " - 2RM", " - 3RM"]
const PR_DAMAGE: Array = [2.2, 3.2, 4.5]
const PR_FIRE_RATE: Array = [1.15, 1.3, 1.5]     # shots-per-second multiplier
const PR_RELOAD_SPEED: Array = [1.2, 1.4, 1.7]   # reload time is divided by this
const PR_MAG: Array = [1.5, 1.75, 2.0]
const PR_RESERVE: Array = [2.0, 2.5, 3.0]

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

# Set on PR-upgraded copies (not saved in .tres files).
var pr_level: int = 0
var pr_base: WeaponData = null


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


## The gun's name without any PR suffix ("Pistol" for "Pistol - 2RM").
func get_base_name() -> String:
	return pr_base.weapon_name if pr_base != null else weapon_name


## Returns the next PR level of this gun, built from its ORIGINAL stats so
## the bonuses never compound. Capped at PR_MAX_LEVEL.
func get_pr_upgraded_copy() -> WeaponData:
	var base: WeaponData = pr_base if pr_base != null else self
	var level: int = mini(pr_level + 1, PR_MAX_LEVEL)
	var i: int = level - 1
	var up: WeaponData = base.duplicate()
	up.pr_base = base
	up.pr_level = level
	up.weapon_name = base.weapon_name + PR_SUFFIXES[i]
	up.placeholder_kind = base.placeholder_kind if base.placeholder_kind != "" else base.weapon_name
	up.damage = base.damage * PR_DAMAGE[i]
	up.burn_damage_per_second = base.burn_damage_per_second * PR_DAMAGE[i]
	up.fire_rate = base.fire_rate / PR_FIRE_RATE[i]
	up.burst_interval = base.burst_interval / PR_FIRE_RATE[i]
	up.reload_time = base.reload_time / PR_RELOAD_SPEED[i]
	up.mag_size = int(base.mag_size * PR_MAG[i])
	up.max_reserve_ammo = int(base.max_reserve_ammo * PR_RESERVE[i])
	up.is_pr_upgraded = true
	return up
