extends RefCounted
## Wonder weapons: special guns in their own category. They are NOT in the
## Loot Locker pool (locker_weapons.gd); the Loot Locker rolls them separately
## (see random_wonder). No attachments, no rarity. PR upgrades are blocked
## unless WeaponData.wonder_pr_upgradable is set (Frenemy -> Bombie).

const BRNH_NAME: String = "Br-Nh"
const FRENEMY_NAME: String = "Frenemy"


## Br-Nh, the first wonder weapon (custom for Sev): fires homing rockets that
## ring a zombie, spike it, then burst into more rockets that chase other zombies.
static func build_brnh() -> WeaponData:
    var w := WeaponData.new()
    w.weapon_name = BRNH_NAME
    w.is_wonder = true
    w.fire_mode = WeaponData.FireMode.WONDER
    w.damage = 2500.0
    w.fire_rate = 0.7
    w.mag_size = 2
    w.max_reserve_ammo = 10
    w.reload_time = 2.5
    w.range = 100.0
    w.gains_per_hit = 20
    return w


## Frenemy, the second wonder weapon: a crossbow pistol. Every zombie it
## shoots turns into a bombie that runs to the closest zombie(s) and explodes
## (no damage to the player). damage = explosion damage, splash_radius = blast
## radius. PR upgrade turns it into "Bombie".
static func build_frenemy() -> WeaponData:
    var w := WeaponData.new()
    w.weapon_name = FRENEMY_NAME
    w.is_wonder = true
    w.wonder_pr_upgradable = true
    w.fire_mode = WeaponData.FireMode.WONDER
    w.damage = 1500.0
    w.fire_rate = 0.5
    w.mag_size = 4
    w.max_reserve_ammo = 16
    w.reload_time = 2.0
    w.range = 80.0
    w.splash_radius = 5.0
    w.gains_per_hit = 20
    return w


## Every wonder weapon (the dev menu picker and the Loot Locker use this).
static func build_all() -> Array:
    return [build_brnh(), build_frenemy()]


## A random wonder weapon (the Loot Locker uses this).
static func random_wonder() -> WeaponData:
    var all: Array = build_all()
    return all[randi() % all.size()]


static func is_wonder_weapon(w) -> bool:
    return w != null and w is WeaponData and (w as WeaponData).is_wonder


## Which wonder gun this is ("Br-Nh" or "Frenemy"). PR-upgraded copies
## (Bombie) report their base gun's name.
static func kind_of(w) -> String:
    if w == null or not (w is WeaponData):
        return ""
    return (w as WeaponData).get_base_name()


## First-person / locker model, built pointing straight ahead (-Z) like the other placeholder guns.
## kind is the base gun name (WeaponData.get_base_name()).
static func build_model(kind: String = BRNH_NAME) -> Node3D:
    if kind == FRENEMY_NAME:
        return _build_frenemy_model()
    return _build_brnh_model()


static func _build_brnh_model() -> Node3D:
    var root := Node3D.new()
    var metal := Color(0.16, 0.10, 0.24)
    var glow := Color(0.65, 0.3, 1.0)
    var dark := Color(0.06, 0.05, 0.09)

    # Body, grip and rear block
    _box(root, Vector3(0.12, 0.16, 0.42), Vector3(0, 0, -0.05), metal, 0.0)
    _box(root, Vector3(0.09, 0.2, 0.1), Vector3(0, -0.17, 0.06), dark, 0.0)
    _box(root, Vector3(0.14, 0.2, 0.14), Vector3(0, 0.02, 0.22), dark, 0.0)

    # Barrel and glowing launch rings
    _cyl(root, 0.055, 0.5, Vector3(0, 0.02, -0.5), metal, 0.0)
    for z in [-0.35, -0.55, -0.75]:
        _cyl(root, 0.075, 0.04, Vector3(0, 0.02, z), glow, 2.0)

    # Spike fins around the muzzle
    for angle in [0.0, 90.0, 180.0, 270.0]:
        var fin := MeshInstance3D.new()
        var cone := CylinderMesh.new()
        cone.top_radius = 0.0
        cone.bottom_radius = 0.03
        cone.height = 0.22
        fin.mesh = cone
        fin.material_override = _mat(glow, 1.5)
        var dir := Vector3(0, 1, 0).rotated(Vector3(0, 0, 1), deg_to_rad(angle))
        fin.position = Vector3(dir.x * 0.1, 0.02 + dir.y * 0.1, -0.8)
        fin.rotation_degrees = Vector3(-90, 0, 0)
        root.add_child(fin)
    return root


## Crossbow pistol: grip, short body, wide bow limbs, taut string, and a
## glowing bomb-tipped bolt sitting on the rail.
static func _build_frenemy_model() -> Node3D:
    var root := Node3D.new()
    var metal := Color(0.12, 0.2, 0.1)
    var dark := Color(0.05, 0.07, 0.05)
    var glow := Color(0.55, 1.0, 0.2)
    var orange := Color(1.0, 0.45, 0.1)

    # Grip and body
    _box(root, Vector3(0.09, 0.2, 0.1), Vector3(0, -0.17, 0.08), dark, 0.0)
    _box(root, Vector3(0.1, 0.13, 0.4), Vector3(0, 0, -0.05), metal, 0.0)
    _box(root, Vector3(0.12, 0.05, 0.14), Vector3(0, 0.08, 0.1), dark, 0.0)

    # Rail the bolt rides on
    _box(root, Vector3(0.05, 0.03, 0.5), Vector3(0, 0.08, -0.3), dark, 0.0)

    # Bow limbs (swept slightly forward at the tips) and glowing tips
    for side in [-1.0, 1.0]:
        var limb := MeshInstance3D.new()
        var limb_mesh := BoxMesh.new()
        limb_mesh.size = Vector3(0.3, 0.03, 0.04)
        limb.mesh = limb_mesh
        limb.material_override = _mat(metal, 0.0)
        limb.position = Vector3(side * 0.15, 0.06, -0.5)
        limb.rotation_degrees = Vector3(0, side * 18.0, 0)
        root.add_child(limb)
        _box(root, Vector3(0.04, 0.04, 0.04), Vector3(side * 0.29, 0.06, -0.58), glow, 2.0)

    # String pulled back to the body
    for side in [-1.0, 1.0]:
        var str_mi := MeshInstance3D.new()
        var str_mesh := BoxMesh.new()
        str_mesh.size = Vector3(0.012, 0.012, 0.2)
        str_mi.mesh = str_mesh
        str_mi.material_override = _mat(Color(0.85, 0.85, 0.7), 0.0)
        str_mi.position = Vector3(side * 0.14, 0.06, -0.48)
        str_mi.rotation_degrees = Vector3(0, side * -35.0, 0)
        root.add_child(str_mi)

    # Bolt with a little bomb on the tip
    _cyl(root, 0.012, 0.45, Vector3(0, 0.11, -0.35), Color(0.7, 0.7, 0.7), 0.0)
    _sphere(root, 0.055, Vector3(0, 0.11, -0.62), orange, 2.5)
    _box(root, Vector3(0.02, 0.05, 0.02), Vector3(0, 0.17, -0.62), glow, 2.5)
    return root


static func _mat(color: Color, glow: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.4
    m.metallic = 0.5
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: float) -> void:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = _mat(color, glow)
    mi.position = pos
    parent.add_child(mi)


## Cylinder lying along the Z axis.
static func _cyl(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color, glow: float) -> void:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mi.mesh = mesh
    mi.material_override = _mat(color, glow)
    mi.position = pos
    mi.rotation_degrees = Vector3(90, 0, 0)
    parent.add_child(mi)


static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, glow: float) -> void:
    var mi := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mi.mesh = mesh
    mi.material_override = _mat(color, glow)
    mi.position = pos
    parent.add_child(mi)
