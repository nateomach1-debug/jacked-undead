extends RefCounted
## Extra procedural gun models + attachment placement for newer Loot Locker guns.
## 4-space file. Same layout as gun_models.gd: muzzle toward -Z, up +Y.
## SIGHT RULE: the top line of every gun stays flat. Iron sights and hammers
## rise only a few mm, so an optic mounted on top has a completely clear window.

const STEEL: Color = Color(0.62, 0.63, 0.68)
const GUNMETAL: Color = Color(0.22, 0.23, 0.27)
const BLACK: Color = Color(0.07, 0.07, 0.08)
const BRASS: Color = Color(0.8, 0.6, 0.2)
const TAN: Color = Color(0.55, 0.48, 0.32)
const RED: Color = Color(0.7, 0.12, 0.1)
const ORANGE: Color = Color(1.0, 0.45, 0.05)
const GLASS: Color = Color(0.6, 0.85, 1.0)
const WHITE: Color = Color(0.95, 0.95, 0.95)
const IVORY: Color = Color(0.92, 0.9, 0.82)
const WOOD: Color = Color(0.42, 0.26, 0.13)
const WOOD_DARK: Color = Color(0.3, 0.18, 0.09)
const OLIVE: Color = Color(0.27, 0.32, 0.2)

## Size multiplier per gun (raise a number to make that gun bigger).
const SCALE_BY_KIND: Dictionary = {
    "Tactical .45": 2.3,
    "Speed Revolver": 2.4,
    "Hand Cannon": 1.7,
    "Marksman DMR": 1.3,
    "Heavy Burst": 1.4,
    "Auto-Shotgun": 1.4,
}

## Attachment placement per gun (same format as OVERRIDES in attachment_models.gd).
const OVERRIDES: Dictionary = {
    "Tactical .45": {
        "optic": Vector2(0.50, 1.0),
        "barrel": Vector2(1.0, 0.88),
        "magazine": Vector2(0.06, 0.06),
        "magazine_tilt": -12.0,
        "grip": Vector2(0.62, 0.40),
    },
    "Speed Revolver": {
        "optic": Vector2(0.52, 1.0),
        "barrel": Vector2(1.0, 0.85),
        "magazine": Vector2(0.06, 0.07),
        "magazine_tilt": -18.0,
        "grip": Vector2(0.68, 0.64),
    },
    "Hand Cannon": {
        "optic": Vector2(0.44, 1.0),
        "barrel": Vector2(1.0, 0.79),
        "magazine": Vector2(0.06, 0.07),
        "magazine_tilt": -18.0,
        "grip": Vector2(0.66, 0.55),
    },
    "Marksman DMR": {
        "optic": Vector2(0.47, 1.0),
        "barrel": Vector2(1.0, 0.75),
        "magazine": Vector2(0.415, 0.15),
        "grip": Vector2(0.60, 0.55),
    },
    "Heavy Burst": {
        "optic": Vector2(0.36, 1.0),
        "barrel": Vector2(1.0, 0.74),
        "magazine": Vector2(0.17, 0.07),
        "grip": Vector2(0.74, 0.58),
    },
    "Auto-Shotgun": {
        "optic": Vector2(0.45, 1.0),
        "barrel": Vector2(1.0, 0.81),
        "magazine": Vector2(0.445, 0.06),
        "grip": Vector2(0.73, 0.67),
    },
}


static func handles(kind: String) -> bool:
    return SCALE_BY_KIND.has(kind)


static func get_tweaks(weapon_name: String) -> Dictionary:
    return OVERRIDES.get(weapon_name, {})


static func build_extra(kind: String) -> Node3D:
    var outer := Node3D.new()
    var root := Node3D.new()
    root.scale = Vector3.ONE * float(SCALE_BY_KIND.get(kind, 2.0))
    outer.add_child(root)
    match kind:
        "Tactical .45":
            _tactical_45(root)
        "Speed Revolver":
            _speed_revolver(root)
        "Hand Cannon":
            _hand_cannon(root)
        "Marksman DMR":
            _marksman_dmr(root)
        "Heavy Burst":
            _heavy_burst(root)
        "Auto-Shotgun":
            _auto_shotgun(root)
        _:
            _box(root, Vector3(0.06, 0.1, 0.5), Vector3.ZERO, GUNMETAL)
    return outer


# ---------------------------------------------------------------- helpers

static func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = 0.3
    m.roughness = 0.55
    return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mi.mesh = mesh
    mi.material_override = _mat(color)
    mi.position = pos
    mi.rotation_degrees = rot_deg
    parent.add_child(mi)
    return mi


## Cylinder lying along Z. r_front is the muzzle end.
static func _cyl_z(parent: Node3D, r_front: float, r_back: float, length: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = r_back
    mesh.bottom_radius = r_front
    mesh.height = length
    mesh.radial_segments = 16
    mi.mesh = mesh
    mi.material_override = _mat(color)
    mi.position = pos
    mi.rotation_degrees = Vector3(90, 0, 0)
    parent.add_child(mi)
    return mi


static func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = inner
    mesh.outer_radius = outer
    mesh.rings = 16
    mesh.ring_segments = 8
    mi.mesh = mesh
    mi.material_override = _mat(color)
    mi.position = pos
    mi.rotation_degrees = Vector3(0, 0, 90)
    parent.add_child(mi)
    return mi


static func _trigger_guard(parent: Node3D, pos: Vector3, scale_mult: float = 1.0) -> void:
    _torus(parent, 0.014 * scale_mult, 0.022 * scale_mult, pos, GUNMETAL)
    _box(parent, Vector3(0.008, 0.026, 0.008), pos + Vector3(0, 0.012, 0.004), STEEL)


# ---------------------------------------------------------------- guns

## Tactical .45: slim black polymer pistol, serrated slide, light on the rail.
static func _tactical_45(p: Node3D) -> void:
    # slide, rear serrations, ejection port, barrel tip
    _box(p, Vector3(0.03, 0.04, 0.2), Vector3(0, 0.04, -0.06), GUNMETAL)
    for i in range(5):
        _box(p, Vector3(0.032, 0.036, 0.003), Vector3(0, 0.04, 0.005 + i * 0.008), BLACK)
    _box(p, Vector3(0.031, 0.012, 0.04), Vector3(0, 0.048, -0.05), BLACK)
    _cyl_z(p, 0.009, 0.009, 0.02, Vector3(0, 0.045, -0.17), STEEL)
    # low iron sights with white dots (5 mm tall, optic sits above them)
    _box(p, Vector3(0.006, 0.005, 0.008), Vector3(0, 0.0625, -0.145), BLACK)
    _box(p, Vector3(0.003, 0.003, 0.002), Vector3(0, 0.0635, -0.1405), WHITE)
    _box(p, Vector3(0.007, 0.005, 0.008), Vector3(-0.0075, 0.0625, 0.03), BLACK)
    _box(p, Vector3(0.007, 0.005, 0.008), Vector3(0.0075, 0.0625, 0.03), BLACK)
    _box(p, Vector3(0.003, 0.003, 0.002), Vector3(-0.0075, 0.0635, 0.0345), WHITE)
    _box(p, Vector3(0.003, 0.003, 0.002), Vector3(0.0075, 0.0635, 0.0345), WHITE)
    # polymer frame, accessory rail, weapon light
    _box(p, Vector3(0.028, 0.026, 0.19), Vector3(0, 0.012, -0.065), BLACK)
    _box(p, Vector3(0.02, 0.008, 0.07), Vector3(0, -0.006, -0.125), GUNMETAL)
    for i in range(3):
        _box(p, Vector3(0.022, 0.003, 0.006), Vector3(0, -0.006, -0.1 - i * 0.02), BLACK)
    _box(p, Vector3(0.026, 0.03, 0.045), Vector3(0, -0.025, -0.12), BLACK)
    _box(p, Vector3(0.018, 0.018, 0.003), Vector3(0, -0.025, -0.1435), GLASS)
    # grip with tan panels and steel mag base plate
    _box(p, Vector3(0.03, 0.1, 0.05), Vector3(0, -0.055, 0.035), BLACK, Vector3(-12, 0, 0))
    _box(p, Vector3(0.032, 0.07, 0.034), Vector3(0, -0.055, 0.037), TAN, Vector3(-12, 0, 0))
    _box(p, Vector3(0.03, 0.01, 0.054), Vector3(0, -0.106, 0.046), STEEL, Vector3(-12, 0, 0))
    _trigger_guard(p, Vector3(0, -0.02, -0.02))


## Speed Revolver: snub-nose with an orange moon clip, rubber grip, brass hammer.
static func _speed_revolver(p: Node3D) -> void:
    # frame and low top strap
    _box(p, Vector3(0.034, 0.06, 0.09), Vector3(0, 0.0, 0.05), STEEL)
    _box(p, Vector3(0.02, 0.008, 0.14), Vector3(0, 0.034, -0.02), STEEL)
    # drum with orange moon clip and six chambers
    _cyl_z(p, 0.034, 0.034, 0.06, Vector3(0, 0.0, -0.03), GUNMETAL)
    _cyl_z(p, 0.036, 0.036, 0.006, Vector3(0, 0.0, -0.063), ORANGE)
    for i in range(6):
        var a: float = TAU * i / 6.0
        _cyl_z(p, 0.0075, 0.0075, 0.003, Vector3(cos(a) * 0.021, sin(a) * 0.021, -0.0665), BLACK)
    _cyl_z(p, 0.007, 0.007, 0.003, Vector3(0, 0.0, -0.0675), STEEL)
    # short barrel, rib, crown, ejector shroud, low front sight
    _cyl_z(p, 0.013, 0.013, 0.084, Vector3(0, 0.016, -0.108), STEEL)
    _box(p, Vector3(0.01, 0.006, 0.084), Vector3(0, 0.032, -0.108), GUNMETAL)
    _cyl_z(p, 0.015, 0.015, 0.006, Vector3(0, 0.016, -0.148), STEEL)
    _cyl_z(p, 0.008, 0.008, 0.002, Vector3(0, 0.016, -0.1515), BLACK)
    _cyl_z(p, 0.009, 0.009, 0.07, Vector3(0, -0.01, -0.105), STEEL)
    _box(p, Vector3(0.005, 0.006, 0.008), Vector3(0, 0.0385, -0.146), BLACK)
    # small brass hammer spur (kept low)
    _box(p, Vector3(0.01, 0.01, 0.014), Vector3(0, 0.037, 0.1), BRASS, Vector3(-30, 0, 0))
    # rubber grip with steel butt cap
    _box(p, Vector3(0.036, 0.11, 0.052), Vector3(0, -0.07, 0.095), BLACK, Vector3(-18, 0, 0))
    _box(p, Vector3(0.038, 0.008, 0.056), Vector3(0, -0.126, 0.112), STEEL, Vector3(-18, 0, 0))
    _trigger_guard(p, Vector3(0, -0.04, 0.015))


## Hand Cannon: chunky big-bore with a 4-chamber drum, ported brake, ivory grip.
static func _hand_cannon(p: Node3D) -> void:
    # frame, brass side plate, thick top strap
    _box(p, Vector3(0.04, 0.07, 0.12), Vector3(0, 0.0, 0.04), STEEL)
    _box(p, Vector3(0.042, 0.04, 0.05), Vector3(0, 0.0, 0.075), BRASS)
    _box(p, Vector3(0.03, 0.022, 0.22), Vector3(0, 0.047, -0.07), STEEL)
    # drum: four big chambers, brass rings
    _cyl_z(p, 0.045, 0.045, 0.08, Vector3(0, 0.005, -0.045), GUNMETAL)
    _cyl_z(p, 0.047, 0.047, 0.008, Vector3(0, 0.005, -0.07), BRASS)
    _cyl_z(p, 0.047, 0.047, 0.008, Vector3(0, 0.005, -0.02), BRASS)
    for i in range(4):
        var a: float = TAU * i / 4.0 + PI / 4.0
        _cyl_z(p, 0.0155, 0.0155, 0.003, Vector3(cos(a) * 0.026, 0.005 + sin(a) * 0.026, -0.0865), BLACK)
    _cyl_z(p, 0.01, 0.01, 0.003, Vector3(0, 0.005, -0.0865), STEEL)
    # fat chrome barrel, underlug shroud, low rib
    _cyl_z(p, 0.022, 0.022, 0.2, Vector3(0, 0.02, -0.19), STEEL)
    _cyl_z(p, 0.016, 0.016, 0.16, Vector3(0, -0.012, -0.17), GUNMETAL)
    _box(p, Vector3(0.014, 0.008, 0.12), Vector3(0, 0.046, -0.23), GUNMETAL)
    # ported muzzle brake
    _cyl_z(p, 0.028, 0.028, 0.05, Vector3(0, 0.02, -0.315), GUNMETAL)
    for z in [-0.30, -0.315, -0.33]:
        _box(p, Vector3(0.06, 0.008, 0.005), Vector3(0, 0.02, z), BLACK)
        _box(p, Vector3(0.016, 0.002, 0.006), Vector3(0, 0.0485, z), BLACK)
    _cyl_z(p, 0.014, 0.014, 0.002, Vector3(0, 0.02, -0.3405), BLACK)
    # low sights (red front, plain rear) and low hammer
    _box(p, Vector3(0.006, 0.008, 0.01), Vector3(0, 0.054, -0.275), RED)
    _box(p, Vector3(0.022, 0.006, 0.01), Vector3(0, 0.061, 0.03), BLACK)
    _box(p, Vector3(0.012, 0.02, 0.016), Vector3(0, 0.04, 0.095), BRASS, Vector3(-30, 0, 0))
    # ivory grip with brass butt cap
    _box(p, Vector3(0.04, 0.12, 0.06), Vector3(0, -0.08, 0.105), IVORY, Vector3(-18, 0, 0))
    _box(p, Vector3(0.044, 0.01, 0.064), Vector3(0, -0.14, 0.1235), BRASS, Vector3(-18, 0, 0))
    _trigger_guard(p, Vector3(0, -0.05, 0.02), 1.3)


## Marksman DMR: wood and steel semi-auto, long thin barrel, short box mag.
static func _marksman_dmr(p: Node3D) -> void:
    # steel receiver, rear block, ejection port, charging handle
    _box(p, Vector3(0.04, 0.055, 0.26), Vector3(0, 0.03, -0.02), STEEL)
    _box(p, Vector3(0.036, 0.05, 0.1), Vector3(0, 0.025, 0.15), STEEL)
    _box(p, Vector3(0.042, 0.02, 0.05), Vector3(0, 0.04, -0.02), BLACK)
    _box(p, Vector3(0.012, 0.012, 0.03), Vector3(0.026, 0.045, 0.04), GUNMETAL)
    # flat top rail with tiny ticks (nothing rises above it)
    _box(p, Vector3(0.02, 0.008, 0.5), Vector3(0, 0.0615, -0.1), GUNMETAL)
    for i in range(8):
        _box(p, Vector3(0.022, 0.0015, 0.01), Vector3(0, 0.0655, -0.32 + i * 0.05), BLACK)
    # wood handguard, steel heat shield with vents, gas block
    _box(p, Vector3(0.05, 0.045, 0.26), Vector3(0, 0.005, -0.3), WOOD)
    _box(p, Vector3(0.04, 0.012, 0.26), Vector3(0, 0.033, -0.3), STEEL)
    for i in range(5):
        _box(p, Vector3(0.042, 0.002, 0.01), Vector3(0, 0.039, -0.4 + i * 0.045), BLACK)
    _box(p, Vector3(0.022, 0.026, 0.04), Vector3(0, 0.03, -0.45), BLACK)
    # long barrel, flash hider, low front sight post
    _cyl_z(p, 0.011, 0.011, 0.22, Vector3(0, 0.02, -0.54), STEEL)
    _cyl_z(p, 0.017, 0.017, 0.01, Vector3(0, 0.02, -0.66), STEEL)
    _cyl_z(p, 0.016, 0.016, 0.07, Vector3(0, 0.02, -0.685), BLACK)
    _cyl_z(p, 0.007, 0.007, 0.002, Vector3(0, 0.02, -0.7205), BLACK)
    _box(p, Vector3(0.012, 0.014, 0.02), Vector3(0, 0.038, -0.5), BLACK)
    _box(p, Vector3(0.006, 0.022, 0.008), Vector3(0, 0.0515, -0.5), BLACK)
    # magwell, short straight box mag, lower receiver
    _box(p, Vector3(0.04, 0.03, 0.07), Vector3(0, -0.012, -0.04), GUNMETAL)
    _box(p, Vector3(0.03, 0.09, 0.045), Vector3(0, -0.0425, -0.04), BLACK)
    _box(p, Vector3(0.032, 0.008, 0.047), Vector3(0, -0.0885, -0.04), STEEL)
    _box(p, Vector3(0.036, 0.028, 0.12), Vector3(0, -0.011, 0.09), GUNMETAL)
    # wood pistol grip, trigger guard
    _box(p, Vector3(0.034, 0.1, 0.05), Vector3(0, -0.07, 0.075), WOOD, Vector3(-20, 0, 0))
    _trigger_guard(p, Vector3(0, -0.02, 0.025))
    # wood stock with cheek riser and butt pad
    _box(p, Vector3(0.04, 0.075, 0.26), Vector3(0, 0.005, 0.3), WOOD, Vector3(6, 0, 0))
    _box(p, Vector3(0.036, 0.02, 0.12), Vector3(0, 0.047, 0.28), WOOD_DARK)
    _box(p, Vector3(0.044, 0.1, 0.014), Vector3(0, -0.005, 0.435), BLACK, Vector3(6, 0, 0))


## Heavy Burst: olive and tan bullpup, mag behind the grip, big muzzle brake.
static func _heavy_burst(p: Node3D) -> void:
    # main body, tan side panels, flat top rail
    _box(p, Vector3(0.055, 0.08, 0.55), Vector3(0, 0.02, 0.05), OLIVE)
    _box(p, Vector3(0.058, 0.04, 0.25), Vector3(0, 0.0, 0.1), TAN)
    _box(p, Vector3(0.022, 0.008, 0.4), Vector3(0, 0.064, 0.02), GUNMETAL)
    # ejection port, charging handle
    _box(p, Vector3(0.058, 0.02, 0.05), Vector3(0, 0.03, 0.18), BLACK)
    _box(p, Vector3(0.012, 0.012, 0.04), Vector3(0.035, 0.05, 0.02), STEEL)
    # ribbed handguard
    _box(p, Vector3(0.05, 0.06, 0.2), Vector3(0, 0.012, -0.325), BLACK)
    for i in range(4):
        _box(p, Vector3(0.054, 0.05, 0.008), Vector3(0, 0.012, -0.4 + i * 0.045), GUNMETAL)
    # short thick barrel and big slotted muzzle brake
    _cyl_z(p, 0.02, 0.02, 0.08, Vector3(0, 0.015, -0.465), STEEL)
    _cyl_z(p, 0.03, 0.03, 0.07, Vector3(0, 0.015, -0.54), BLACK)
    for z in [-0.53, -0.55]:
        _box(p, Vector3(0.064, 0.008, 0.006), Vector3(0, 0.015, z), GUNMETAL)
    _cyl_z(p, 0.012, 0.012, 0.002, Vector3(0, 0.015, -0.576), BLACK)
    # low sights (below the rail top)
    _box(p, Vector3(0.006, 0.02, 0.008), Vector3(0, 0.052, -0.4), BLACK)
    _box(p, Vector3(0.02, 0.008, 0.01), Vector3(0, 0.066, 0.2), BLACK)
    # chunky vertical foregrip
    _box(p, Vector3(0.036, 0.03, 0.07), Vector3(0, -0.035, -0.33), BLACK)
    _box(p, Vector3(0.036, 0.09, 0.045), Vector3(0, -0.085, -0.33), BLACK)
    # pistol grip, trigger guard
    _box(p, Vector3(0.034, 0.1, 0.05), Vector3(0, -0.08, 0.08), BLACK, Vector3(-15, 0, 0))
    _trigger_guard(p, Vector3(0, -0.035, 0.03))
    # magazine behind the grip (bullpup), well block, tan base plate
    _box(p, Vector3(0.04, 0.03, 0.07), Vector3(0, -0.03, 0.2), BLACK)
    _box(p, Vector3(0.034, 0.12, 0.05), Vector3(0, -0.075, 0.2), OLIVE)
    _box(p, Vector3(0.036, 0.008, 0.052), Vector3(0, -0.139, 0.2), TAN)
    # butt pad
    _box(p, Vector3(0.05, 0.09, 0.03), Vector3(0, 0.01, 0.34), BLACK)


## Auto-Shotgun: boxy black combat shotgun, vented shroud, orange ring, curved mag.
static func _auto_shotgun(p: Node3D) -> void:
    # receiver, ejection port, flat top rail
    _box(p, Vector3(0.06, 0.09, 0.32), Vector3(0, 0.025, -0.02), BLACK)
    _box(p, Vector3(0.062, 0.03, 0.07), Vector3(0, 0.04, 0.02), GUNMETAL)
    _box(p, Vector3(0.022, 0.008, 0.38), Vector3(0, 0.074, -0.03), GUNMETAL)
    _box(p, Vector3(0.024, 0.012, 0.02), Vector3(0.042, 0.045, 0.05), STEEL)
    # vented barrel shroud (dark slots), barrel, orange muzzle ring
    _cyl_z(p, 0.034, 0.034, 0.3, Vector3(0, 0.03, -0.33), GUNMETAL)
    for i in range(5):
        _box(p, Vector3(0.074, 0.01, 0.014), Vector3(0, 0.03, -0.22 - i * 0.05), BLACK)
    _cyl_z(p, 0.02, 0.02, 0.08, Vector3(0, 0.03, -0.52), STEEL)
    _cyl_z(p, 0.026, 0.026, 0.012, Vector3(0, 0.03, -0.55), ORANGE)
    _cyl_z(p, 0.015, 0.015, 0.002, Vector3(0, 0.03, -0.561), BLACK)
    # low front post (below the rail top)
    _box(p, Vector3(0.008, 0.014, 0.01), Vector3(0, 0.071, -0.46), BLACK)
    # magwell and curved 8-round box mag with orange base plate
    _box(p, Vector3(0.044, 0.03, 0.09), Vector3(0, -0.035, 0.0), GUNMETAL)
    _box(p, Vector3(0.036, 0.07, 0.085), Vector3(0, -0.07, 0.0), BLACK, Vector3(8, 0, 0))
    _box(p, Vector3(0.036, 0.06, 0.085), Vector3(0, -0.133, -0.015), BLACK, Vector3(20, 0, 0))
    _box(p, Vector3(0.038, 0.008, 0.088), Vector3(0, -0.163, -0.026), ORANGE, Vector3(20, 0, 0))
    # pistol grip, trigger guard
    _box(p, Vector3(0.034, 0.1, 0.05), Vector3(0, -0.07, 0.115), BLACK, Vector3(-15, 0, 0))
    _trigger_guard(p, Vector3(0, -0.035, 0.07))
    # folding stock: hinge, four rods, butt plate
    _box(p, Vector3(0.05, 0.08, 0.03), Vector3(0, 0.025, 0.155), GUNMETAL)
    for x in [-0.02, 0.02]:
        _box(p, Vector3(0.008, 0.008, 0.22), Vector3(x, 0.045, 0.28), STEEL)
        _box(p, Vector3(0.008, 0.008, 0.22), Vector3(x, -0.005, 0.28), STEEL)
    _box(p, Vector3(0.046, 0.1, 0.016), Vector3(0, 0.025, 0.4), BLACK)
