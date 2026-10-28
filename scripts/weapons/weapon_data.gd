extends Resource
class_name WeaponData
## A reusable stat block for a weapon. Create .tres instances of this
## (Right click in FileSystem -> New Resource -> WeaponData) for each gun,
## or build them in code (see locker_weapons.gd).

enum FireMode { HITSCAN, FLAME, EXPLOSIVE, WONDER }

# PR Rack upgrade levels. Each list holds the TOTAL bonus at that level
# (index 0 = level 1), applied to the gun's original stats.
const PR_MAX_LEVEL: int = 3
const PR_UPGRADED_NAMES: Dictionary = {
    # Standard weapons
    "Pistol": "Pocket Gains",
    "Shotgun": "Chest Day",
    "SMG": "Superset Sprayer",
    "Rifle": "Gains of Mass Destruction",
    "Crossbow": "Pull Day",
    "Sniper": "One Rep Wonder",

    # Loot Locker weapons
    "Pump Shotgun": "Pump & Dump",
    "Double-Barrel": "Double Scoop",
    "Revolver": "Last Rep",
    "Magnum": "Mass Monster",
    "LMG": "Leg Day",
    "Burst Rifle": "Three-Peat",
    "Flamethrower": "Pre-Workout Rage",
    "Grenade Launcher": "Bulk Season",
    "Rocket Launcher": "Nuclear Bulk",
    "Tactical .45": "Tactical Triceps",
    "Speed Revolver": "Quick Gains",
    "Hand Cannon": "Big Guns",
    "Marksman DMR": "Form Check",
    "Heavy Burst": "Heavy Sets",
    "Auto-Shotgun": "Pec Blaster",
    "Micro SMG": "Tiny Terrors",
    "Chaingun": "Cardio Is Overrated",
    "Repeater Crossbow": "Pull Day Again",
    "Semi-Auto Sniper": "No Spotter Needed",

    # Wonder weapons that can be PR upgraded
    "Frenemy": "Bombie"
}
const PR_SUFFIXES: Array = [" - 1RM", " - 2RM", " - 3RM"]
const PR_DAMAGE: Array = [2.2, 3.2, 4.5]
const PR_FIRE_RATE: Array = [1.15, 1.3, 1.5]     # shots-per-second multiplier
const PR_RELOAD_SPEED: Array = [1.2, 1.4, 1.7]   # reload time is divided by this
const PR_MAG: Array = [1.5, 1.75, 2.0]
const PR_RESERVE: Array = [2.0, 2.5, 3.0]

const WONDER_PATH: String = "res://scripts/weapons/wonder_weapons.gd"

# Gun sizing: every gun is scaled so its length = the starter pistol's length
# times the factor below. 1.0 = pistol-sized. Raise a number to make that gun
# longer, lower it to make it shorter. Guns not listed use DEFAULT_LENGTH_FACTOR.
const STARTER_PISTOL_PATH: String = "res://resources/weapons/pistol.tres"
const DEFAULT_LENGTH_FACTOR: float = 2.0
const LENGTH_FACTOR: Dictionary = {
    # Pistols and revolvers
    "Pistol": 1.0,
    "Tactical .45": 1.0,
    "Revolver": 1.05,
    "Speed Revolver": 1.05,
    "Magnum": 1.15,
    "Hand Cannon": 1.15,
    # SMGs
    "SMG": 1.5,
    "Micro SMG": 1.2,
    # Rifles
    "Rifle": 2.4,
    "Marksman DMR": 2.6,
    "Burst Rifle": 2.3,
    "Heavy Burst": 2.1,
    # Crossbows
    "Crossbow": 1.8,
    "Repeater Crossbow": 1.6,
    # Shotguns
    "Shotgun": 2.3,
    "Pump Shotgun": 2.4,
    "Double-Barrel": 2.2,
    "Auto-Shotgun": 2.3,
    # Snipers
    "Sniper": 3.0,
    "Semi-Auto Sniper": 2.9,
    # Heavy
    "LMG": 2.8,
    "Chaingun": 2.5,
    "Flamethrower": 2.4,
    "Grenade Launcher": 2.2,
    "Rocket Launcher": 2.8,
    # Wonder weapons
    "Frenemy": 1.2,
    "Br-Nh": 1.5,
}

# Length of the starter pistol model (measured once, then remembered).
static var _ref_length: float = -1.0

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

# Wonder weapons: no attachments and no rarity. PR upgrades are blocked
# unless wonder_pr_upgradable is true.
@export var is_wonder: bool = false
@export var wonder_pr_upgradable: bool = false

@export var placeholder_kind: String = ""
@export var placeholder_size: Vector3 = Vector3.ZERO
@export var placeholder_color: Color = Color(0.3, 0.3, 0.3)

# Set on PR-upgraded copies (not saved in .tres files).
var pr_level: int = 0
var pr_base: WeaponData = null


## The gun's model, sized relative to the starter pistol.
func create_model() -> Node3D:
    var raw: Node3D = _create_raw_model()
    if raw == null:
        return null
    var ref: float = _get_ref_length()
    if ref <= 0.0:
        return raw
    var length: float = _model_length(raw)
    if length < 0.001:
        return raw
    var factor: float = float(
        LENGTH_FACTOR.get(get_base_name(), DEFAULT_LENGTH_FACTOR)
    )
    var fit: float = (ref * factor) / length
    # The model sits inside a holder so callers that reset the top node's
    # rotation/scale don't lose the sizing.
    var holder := Node3D.new()
    holder.name = "SizedGun"
    holder.add_child(raw)
    raw.scale = raw.scale * fit
    return holder


func _create_raw_model() -> Node3D:
    if is_wonder:
        var wonder_script = load(WONDER_PATH)
        if wonder_script:
            return wonder_script.build_model(get_base_name())
        return null
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


## Length of the starter pistol's model (0 if it can't be measured).
static func _get_ref_length() -> float:
    if _ref_length >= 0.0:
        return _ref_length
    _ref_length = 0.0
    if not ResourceLoader.exists(STARTER_PISTOL_PATH):
        return _ref_length
    var pistol = load(STARTER_PISTOL_PATH)
    if pistol == null or pistol.model_scene == null:
        return _ref_length
    var node: Node3D = pistol.model_scene.instantiate() as Node3D
    if node == null:
        return _ref_length
    _ref_length = _model_length(node)
    node.free()
    return _ref_length


## Longest horizontal size of a model (x or z), from its meshes.
static func _model_length(root: Node3D) -> float:
    var box: Array = [AABB(), false]
    _collect_bounds(root, Transform3D.IDENTITY, box)
    if not bool(box[1]):
        return 0.0
    var b: AABB = box[0]
    return maxf(b.size.x, b.size.z)


static func _collect_bounds(node: Node, xf: Transform3D, box: Array) -> void:
    var here: Transform3D = xf
    if node is Node3D:
        here = xf * (node as Node3D).transform
    if node is MeshInstance3D:
        var mi: MeshInstance3D = node
        if mi.mesh != null:
            var aabb: AABB = mi.mesh.get_aabb()
            for i in range(8):
                var p: Vector3 = here * aabb.get_endpoint(i)
                if bool(box[1]):
                    var cur: AABB = box[0]
                    box[0] = cur.expand(p)
                else:
                    box[0] = AABB(p, Vector3.ZERO)
                    box[1] = true
    for child in node.get_children():
        _collect_bounds(child, here, box)


## The gun's name without any PR suffix ("Pistol" for "Pistol - 2RM").
func get_base_name() -> String:
    return pr_base.weapon_name if pr_base != null else weapon_name


## True when the PR Rack can upgrade this gun right now (not a blocked wonder
## gun, and not already at the max level). The PR Rack should check this
## BEFORE taking the player's Gains.
func can_pr_upgrade() -> bool:
    if is_wonder and not wonder_pr_upgradable:
        return false
    return pr_level < PR_MAX_LEVEL


## Returns the next PR level of this gun, built from its ORIGINAL stats so
## the bonuses never compound. Capped at PR_MAX_LEVEL.
## Wonder weapons can't be upgraded unless wonder_pr_upgradable is set:
## otherwise they come back unchanged.
func get_pr_upgraded_copy() -> WeaponData:
    if is_wonder and not wonder_pr_upgradable:
        return self
    var base: WeaponData = pr_base if pr_base != null else (get_meta("attach_base") if has_meta("attach_base") else self)
    var level: int = mini(pr_level + 1, PR_MAX_LEVEL)
    var i: int = level - 1
    var up: WeaponData = base.duplicate()
    up.pr_base = base
    up.pr_level = level
    up.weapon_name = str(
        PR_UPGRADED_NAMES.get(
            base.weapon_name,
            base.weapon_name + PR_SUFFIXES[i]
        )
    )
    up.placeholder_kind = base.placeholder_kind if base.placeholder_kind != "" else base.weapon_name
    up.damage = base.damage * PR_DAMAGE[i]
    up.burn_damage_per_second = base.burn_damage_per_second * PR_DAMAGE[i]
    up.fire_rate = base.fire_rate / PR_FIRE_RATE[i]
    up.burst_interval = base.burst_interval / PR_FIRE_RATE[i]
    up.reload_time = base.reload_time / PR_RELOAD_SPEED[i]
    up.mag_size = int(base.mag_size * PR_MAG[i])
    up.max_reserve_ammo = int(base.max_reserve_ammo * PR_RESERVE[i])
    up.is_pr_upgraded = true
    # Rarity (set by the Loot Locker) survives PR upgrades.
    for key in ["rarity", "rarity_slots"]:
        if base.has_meta(key):
            up.set_meta(key, base.get_meta(key))
    return up
