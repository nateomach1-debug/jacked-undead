extends RefCounted
## Wonder weapons: special guns in their own category. They are NOT in the
## Loot Locker pool (locker_weapons.gd); the Loot Locker rolls them separately.
## No attachments, no rarity, no PR upgrades (WeaponData.is_wonder).

const BRNH_NAME: String = "Br-Nh"


## Br-Nh, the first wonder weapon (custom for Sev): fires homing rockets that
## ring a zombie, spike it, then burst into more rockets that chase other zombies.
static func build_brnh() -> WeaponData:
    var w := WeaponData.new()
    w.weapon_name = BRNH_NAME
    w.is_wonder = true
    w.fire_mode = WeaponData.FireMode.WONDER
    w.damage = 2500.0
    w.fire_rate = 0.7
    w.mag_size = 10
    w.max_reserve_ammo = 30
    w.reload_time = 2.5
    w.range = 100.0
    w.gains_per_hit = 20
    return w


## Every wonder weapon (for future ones).
static func build_all() -> Array:
    return [build_brnh()]


static func is_wonder_weapon(w) -> bool:
    return w != null and w is WeaponData and (w as WeaponData).is_wonder


## First-person / locker model, built pointing straight ahead (-Z) like the other placeholder guns.
static func build_model() -> Node3D:
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
