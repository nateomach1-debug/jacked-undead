extends RefCounted
## Wonder weapons: special guns in their own category. They are NOT in the
## Loot Locker pool (locker_weapons.gd); the Loot Locker rolls them separately
## (see random_wonder). No attachments, no rarity. PR upgrades are blocked
## unless WeaponData.wonder_pr_upgradable is set (Frenemy -> Bombie).
##
## The Locker Launcher is an EASTER EGG gun: it is deliberately NOT in
## build_all() or random_wonder(), so the Loot Locker rolls, the 30th-pull
## guarantee and the dev menu picker can never give it.

const BRNH_NAME: String = "Br-Nh"
const FRENEMY_NAME: String = "Frenemy"
const LAUNCHER_NAME: String = "Locker Launcher"


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


## Locker Launcher (easter egg): a Loot Locker you hold like a gun. Every shot
## is a random Loot Locker gun that tumbles through the air and hits ONE zombie
## (no splash / explosion damage). Deliberately not overpowered: normal-gun
## strength, unlike the other wonder weapons.
static func build_locker_launcher() -> WeaponData:
    var w := WeaponData.new()
    w.weapon_name = LAUNCHER_NAME
    w.is_wonder = true
    w.fire_mode = WeaponData.FireMode.WONDER
    w.damage = 90.0
    w.fire_rate = 0.5
    w.mag_size = 6
    w.max_reserve_ammo = 36
    w.reload_time = 2.4
    w.range = 70.0
    w.splash_radius = 0.0
    w.gains_per_hit = 10
    return w


## Every wonder weapon the Loot Locker and the dev menu picker can give.
## The Locker Launcher is NOT here on purpose (easter egg only).
static func build_all() -> Array:
    return [build_brnh(), build_frenemy()]


## A random wonder weapon (the Loot Locker uses this).
static func random_wonder() -> WeaponData:
    var all: Array = build_all()
    return all[randi() % all.size()]


static func is_wonder_weapon(w) -> bool:
    return w != null and w is WeaponData and (w as WeaponData).is_wonder


## Which wonder gun this is ("Br-Nh", "Frenemy" or "Locker Launcher"). PR-upgraded
## copies (Bombie) report their base gun's name.
static func kind_of(w) -> String:
    if w == null or not (w is WeaponData):
        return ""
    return (w as WeaponData).get_base_name()


## First-person / locker model, built pointing straight ahead (-Z) like the other placeholder guns.
## kind is the base gun name (WeaponData.get_base_name()).
static func build_model(kind: String = BRNH_NAME) -> Node3D:
    if kind == FRENEMY_NAME:
        return _build_frenemy_model()
    if kind == LAUNCHER_NAME:
        return _build_launcher_model()
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


## Locker Launcher: the Loot Locker itself (same colors, door, vents, number
## plate, latch, handle, hinges, sticker, scuffs and blood), centered on the
## origin with the closed door facing the player (+Z). No barrel or gun parts.
## Its size in the hand comes from LENGTH_FACTOR in weapon_data.gd.
static func _build_launcher_model() -> Node3D:
    var root := Node3D.new()
    var paint := Color(0.16, 0.30, 0.55)
    var paint_dark := Color(0.10, 0.19, 0.36)
    var door_col := Color(0.24, 0.42, 0.72)
    var door_light := Color(0.30, 0.50, 0.80)
    var chrome := Color(0.78, 0.80, 0.84)
    var yellow := Color(1.0, 0.77, 0.0)
    var dark := Color(0.04, 0.04, 0.06)
    var blood := Color(0.35, 0.02, 0.02)
    var none := Vector3.ZERO

    # Body shell, corner posts, top cap and base plinth
    _box(root, Vector3(1.0, 2.0, 0.8), Vector3(0, 0, 0), paint, 0.0, none, 0.6, 0.0)
    for cx in [-0.5, 0.5]:
        for cz in [-0.4, 0.4]:
            _cyl_up(root, 0.035, 2.0, Vector3(cx, 0, cz), paint_dark)
    _box(root, Vector3(1.06, 0.06, 0.86), Vector3(0, 1.03, 0), paint_dark, 0.0, none, 0.45, 0.3)
    _box(root, Vector3(1.06, 0.12, 0.86), Vector3(0, -0.94, 0), dark, 0.0, none, 0.8, 0.0)
    for sx in [-0.506, 0.506]:
        for sz in [-0.2, 0.2]:
            _box(root, Vector3(0.012, 1.8, 0.04), Vector3(sx, 0, sz), paint_dark, 0.0, none, 0.6, 0.0)

    # Closed door and inner panel
    _box(root, Vector3(0.94, 1.86, 0.05), Vector3(0, 0, 0.42), door_col, 0.0, none, 0.5, 0.2)
    _box(root, Vector3(0.80, 1.70, 0.012), Vector3(0, 0, 0.45), door_light, 0.0, none, 0.55, 0.2)

    # Vent slots (top and bottom)
    for vy in [0.74, 0.66, 0.58, -0.72, -0.80, -0.88]:
        _box(root, Vector3(0.5, 0.025, 0.012), Vector3(0, vy, 0.456), dark, 0.0, none, 0.9, 0.0)

    # Number plate
    _box(root, Vector3(0.16, 0.09, 0.01), Vector3(0, 0.42, 0.458), yellow, 0.0, none, 0.5, 0.0)
    var num := Label3D.new()
    num.text = "07"
    num.font_size = 24
    num.pixel_size = 0.003
    num.modulate = dark
    num.outline_size = 0
    num.position = Vector3(0, 0.42, 0.466)
    root.add_child(num)

    # Latch and handle
    _box(root, Vector3(0.07, 0.32, 0.02), Vector3(0.35, 0, 0.462), chrome, 0.0, none, 0.3, 0.8)
    _box(root, Vector3(0.03, 0.22, 0.03), Vector3(0.35, 0, 0.486), chrome, 0.0, none, 0.25, 0.9)

    # Hinges on the left edge
    for hy in [0.7, 0.0, -0.7]:
        _cyl_up(root, 0.018, 0.14, Vector3(-0.47, hy, 0.42), chrome)

    # Gym sticker, scuffs, rust and blood
    _box(root, Vector3(0.22, 0.12, 0.006), Vector3(-0.17, 0.12, 0.457), Color(0.8, 0.08, 0.08), 0.0, Vector3(0, 0, 0.15), 0.6, 0.0)
    var sticker := Label3D.new()
    sticker.text = "NO PAIN"
    sticker.font_size = 14
    sticker.pixel_size = 0.003
    sticker.outline_size = 0
    sticker.position = Vector3(-0.17, 0.12, 0.462)
    sticker.rotation.z = 0.15
    root.add_child(sticker)
    _box(root, Vector3(0.18, 0.05, 0.006), Vector3(0.15, -0.25, 0.457), paint_dark, 0.0, Vector3(0, 0, -0.4), 0.8, 0.0)
    _box(root, Vector3(0.34, 0.04, 0.006), Vector3(-0.07, -0.9, 0.457), Color(0.35, 0.2, 0.08), 0.0, none, 0.9, 0.0)
    _box(root, Vector3(0.05, 0.2, 0.006), Vector3(-0.27, -0.38, 0.457), blood, 0.0, Vector3(0, 0, 0.1), 0.4, 0.0)
    _box(root, Vector3(0.02, 0.14, 0.006), Vector3(-0.35, -0.55, 0.457), blood, 0.0, none, 0.4, 0.0)
    _box(root, Vector3(0.02, 0.09, 0.006), Vector3(-0.2, -0.5, 0.457), blood, 0.0, none, 0.4, 0.0)
    return root


static func _mat(color: Color, glow: float, rough: float = 0.4, metal: float = 0.5) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metal
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: float, rot: Vector3 = Vector3.ZERO, rough: float = 0.4, metal: float = 0.5) -> void:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = _mat(color, glow, rough, metal)
    mi.position = pos
    mi.rotation = rot
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


## Upright cylinder (along the Y axis).
static func _cyl_up(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> void:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    mesh.rings = 1
    mi.mesh = mesh
    mi.material_override = _mat(color, 0.0, 0.6, 0.0)
    mi.position = pos
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
