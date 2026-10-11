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
const MATTE: Color = Color(0.36, 0.37, 0.39)
const MATTE_DARK: Color = Color(0.24, 0.25, 0.27)
const STOCK_GRAY: Color = Color(0.15, 0.16, 0.18)

## Size multiplier per gun (raise a number to make that gun bigger).
const SCALE_BY_KIND: Dictionary = {
    "Tactical .45": 2.3,
    "Speed Revolver": 2.4,
    "Hand Cannon": 1.7,
    "Marksman DMR": 1.3,
    "Heavy Burst": 1.4,
    "Auto-Shotgun": 1.4,
    "Micro SMG": 1.9,
    "Chaingun": 1.2,
    "Repeater Crossbow": 1.5,
    "Semi-Auto Sniper": 1.2,
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
    "Micro SMG": {
        "optic": Vector2(0.55, 1.0),
        "barrel": Vector2(1.0, 0.90),
        "magazine": Vector2(0.49, 0.02),
        "grip": Vector2(0.80, 0.68),
    },
    "Chaingun": {
        "optic": Vector2(0.35, 1.0),
        "barrel": Vector2(1.0, 0.79),
        "magazine": Vector2(0.34, 0.04),
        "grip": Vector2(0.60, 0.45),
    },
    # Repeater: the built-in mag sits on top at the rear, so the rail top is
    # below the model's top (optic y 0.79 instead of 1.0).
    "Repeater Crossbow": {
        "optic": Vector2(0.54, 0.91),
        "barrel": Vector2(1.0, 0.82),
        "magazine": Vector2(0.61, 0.22),
        "grip": Vector2(0.75, 0.65),
    },
    "Semi-Auto Sniper": {
        "optic": Vector2(0.38, 1.0),
        "barrel": Vector2(1.0, 0.80),
        "magazine": Vector2(0.39, 0.13),
        "grip": Vector2(0.68, 0.59),
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
        "Micro SMG":
            _micro_smg(root)
        "Chaingun":
            _chaingun(root)
        "Repeater Crossbow":
            _repeater_crossbow(root)
        "Semi-Auto Sniper":
            _semi_auto_sniper(root)
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


## Cylinder lying along X (a drum seen from the side).
static func _cyl_x(parent: Node3D, radius: float, width: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = width
    mesh.radial_segments = 20
    mi.mesh = mesh
    mi.material_override = _mat(color)
    mi.position = pos
    mi.rotation_degrees = Vector3(0, 0, 90)
    parent.add_child(mi)
    return mi


## Upright cylinder (a flat disc seen from above, e.g. a pulley wheel).
static func _cyl_y(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 20
    mi.mesh = mesh
    mi.material_override = _mat(color)
    mi.position = pos
    parent.add_child(mi)
    return mi


## Thin line (bowstring) from point a to point b.
static func _string(parent: Node3D, a: Vector3, b: Vector3) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.003, 0.003, a.distance_to(b))
    mi.mesh = mesh
    mi.material_override = _mat(IVORY)
    mi.position = (a + b) * 0.5
    mi.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
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


## Micro SMG: tiny Mac-style machine pistol. Boxy black receiver, flat top cover,
## threaded muzzle cap, tan grip, long stick mag with orange base plate, wire stock.
static func _micro_smg(p: Node3D) -> void:
    # boxy receiver, front plate, ejection port, flat top cover (top line y 0.0535)
    _box(p, Vector3(0.042, 0.055, 0.17), Vector3(0, 0.02, -0.02), BLACK)
    _box(p, Vector3(0.044, 0.05, 0.016), Vector3(0, 0.022, -0.105), GUNMETAL)
    _box(p, Vector3(0.044, 0.018, 0.04), Vector3(0, 0.032, -0.01), GUNMETAL)
    _box(p, Vector3(0.036, 0.006, 0.15), Vector3(0, 0.0505, -0.02), GUNMETAL)
    for i in range(4):
        _box(p, Vector3(0.038, 0.002, 0.008), Vector3(0, 0.0535, -0.07 + i * 0.03), BLACK)
    # side cocking knob
    _box(p, Vector3(0.01, 0.01, 0.022), Vector3(-0.026, 0.035, 0.035), STEEL)
    # short barrel and threaded muzzle cap (three thread rings)
    _cyl_z(p, 0.009, 0.009, 0.06, Vector3(0, 0.03, -0.135), STEEL)
    _cyl_z(p, 0.013, 0.013, 0.032, Vector3(0, 0.03, -0.18), GUNMETAL)
    for z in [-0.17, -0.18, -0.19]:
        _cyl_z(p, 0.0145, 0.0145, 0.004, Vector3(0, 0.03, z), BLACK)
    _cyl_z(p, 0.007, 0.007, 0.002, Vector3(0, 0.03, -0.1965), BLACK)
    # tiny iron sights, below the top cover
    _box(p, Vector3(0.004, 0.004, 0.006), Vector3(0, 0.0505, -0.09), BLACK)
    _box(p, Vector3(0.007, 0.004, 0.008), Vector3(-0.007, 0.0505, 0.05), BLACK)
    _box(p, Vector3(0.007, 0.004, 0.008), Vector3(0.007, 0.0505, 0.05), BLACK)
    # tan grip housing, long straight stick mag, orange base plate
    _box(p, Vector3(0.034, 0.07, 0.046), Vector3(0, -0.05, 0.02), TAN)
    _box(p, Vector3(0.026, 0.17, 0.036), Vector3(0, -0.1, 0.02), BLACK)
    for i in range(4):
        _box(p, Vector3(0.028, 0.004, 0.038), Vector3(0, -0.09 - i * 0.025, 0.02), GUNMETAL)
    _box(p, Vector3(0.03, 0.008, 0.04), Vector3(0, -0.189, 0.02), ORANGE)
    _trigger_guard(p, Vector3(0, -0.012, -0.04), 0.8)
    # thin wire stock: hinge, two rods, end plate
    _box(p, Vector3(0.03, 0.03, 0.012), Vector3(0, 0.02, 0.071), STEEL)
    for x in [-0.016, 0.016]:
        _box(p, Vector3(0.005, 0.005, 0.15), Vector3(x, 0.02, 0.15), STEEL)
        _box(p, Vector3(0.005, 0.04, 0.005), Vector3(x, 0.0, 0.225), STEEL)
    _box(p, Vector3(0.038, 0.008, 0.012), Vector3(0, -0.02, 0.228), BLACK)


## Chaingun: six barrels in a ring held by two clamps, squared housing with a flat
## top rail, big olive ammo drum with brass belt, pistol grip, front side handle.
static func _chaingun(p: Node3D) -> void:
    # rear housing, motor block, rear cap (top of housing y 0.075)
    _box(p, Vector3(0.09, 0.09, 0.2), Vector3(0, 0.03, 0.06), GUNMETAL)
    _box(p, Vector3(0.082, 0.08, 0.1), Vector3(0, 0.03, -0.09), BLACK)
    _box(p, Vector3(0.07, 0.07, 0.02), Vector3(0, 0.03, 0.17), BLACK)
    _box(p, Vector3(0.094, 0.03, 0.06), Vector3(0, 0.0, 0.07), BLACK)
    # flat top rail (nothing rises above it)
    _box(p, Vector3(0.03, 0.008, 0.5), Vector3(0, 0.079, -0.1), GUNMETAL)
    for i in range(10):
        _box(p, Vector3(0.032, 0.0015, 0.01), Vector3(0, 0.0835, -0.3 + i * 0.045), BLACK)
    # six barrels in a ring around a center hub
    _cyl_z(p, 0.018, 0.018, 0.52, Vector3(0, 0.03, -0.35), GUNMETAL)
    for i in range(6):
        var a: float = TAU * i / 6.0
        var bx: float = cos(a) * 0.028
        var by: float = 0.03 + sin(a) * 0.028
        _cyl_z(p, 0.011, 0.011, 0.5, Vector3(bx, by, -0.35), STEEL)
        _cyl_z(p, 0.008, 0.008, 0.002, Vector3(bx, by, -0.601), BLACK)
    # two steel clamps holding the ring, tiny front post on the front clamp
    _cyl_z(p, 0.044, 0.044, 0.03, Vector3(0, 0.03, -0.25), STEEL)
    _cyl_z(p, 0.044, 0.044, 0.03, Vector3(0, 0.03, -0.5), STEEL)
    _cyl_z(p, 0.046, 0.046, 0.006, Vector3(0, 0.03, -0.265), GUNMETAL)
    _cyl_z(p, 0.046, 0.046, 0.006, Vector3(0, 0.03, -0.515), GUNMETAL)
    _box(p, Vector3(0.006, 0.008, 0.01), Vector3(0, 0.078, -0.5), BLACK)
    # big olive ammo drum under the body, end rings, brass feed neck
    _cyl_x(p, 0.07, 0.09, Vector3(0, -0.095, -0.09), OLIVE)
    _cyl_x(p, 0.073, 0.008, Vector3(0.049, -0.095, -0.09), GUNMETAL)
    _cyl_x(p, 0.073, 0.008, Vector3(-0.049, -0.095, -0.09), GUNMETAL)
    _cyl_x(p, 0.02, 0.1, Vector3(0, -0.095, -0.09), STEEL)
    _box(p, Vector3(0.05, 0.04, 0.07), Vector3(0, -0.03, -0.09), BLACK)
    # brass belt: rounds climbing the side to the feed port, plus a hanging loop
    for i in range(6):
        _box(p, Vector3(0.012, 0.014, 0.022), Vector3(0.05, -0.06 + i * 0.012, -0.09 + i * 0.01), BRASS, Vector3(-25, 0, 0))
    for i in range(5):
        _box(p, Vector3(0.012, 0.016, 0.022), Vector3(0.0, -0.162 + i * 0.002, -0.14 + i * 0.024), BRASS)
    # pistol grip, trigger guard
    _box(p, Vector3(0.036, 0.1, 0.05), Vector3(0, -0.06, 0.045), BLACK, Vector3(-12, 0, 0))
    _trigger_guard(p, Vector3(0, -0.01, -0.0), 1.1)
    # front side handle (left): arm and vertical grip
    _box(p, Vector3(0.04, 0.02, 0.03), Vector3(-0.065, 0.03, -0.2), STEEL)
    _box(p, Vector3(0.025, 0.08, 0.025), Vector3(-0.085, -0.01, -0.2), BLACK)


## Repeater Crossbow: compact black and olive crossbow. Flat top rail with a bolt
## channel down the middle, short box mag on top at the rear (behind the optic spot),
## steel limbs with a pulley wheel on each tip, thin string, dark stock + pistol grip.
static func _repeater_crossbow(p: Node3D) -> void:
    # main body with olive side panels (top of body y 0.02)
    _box(p, Vector3(0.034, 0.04, 0.46), Vector3(0, 0.0, -0.095), BLACK)
    _box(p, Vector3(0.038, 0.022, 0.2), Vector3(0, -0.002, -0.03), OLIVE)
    # flat top rail: two strips with the bolt channel between them (top y 0.028)
    for x in [-0.0085, 0.0085]:
        _box(p, Vector3(0.007, 0.008, 0.46), Vector3(x, 0.024, -0.095), GUNMETAL)
        for i in range(6):
            _box(p, Vector3(0.007, 0.0015, 0.006), Vector3(x, 0.0278, -0.3 + i * 0.04), BLACK)
    _box(p, Vector3(0.01, 0.004, 0.46), Vector3(0, 0.0205, -0.095), BLACK)
    # loaded bolt lying in the channel (steel shaft, orange fletching, pointed tip)
    _cyl_z(p, 0.002, 0.002, 0.14, Vector3(0, 0.0245, -0.2), STEEL)
    _cyl_z(p, 0.0005, 0.002, 0.014, Vector3(0, 0.0245, -0.277), STEEL)
    _box(p, Vector3(0.008, 0.0015, 0.016), Vector3(0, 0.0245, -0.125), ORANGE)
    # tiny sight dots, flush with the rail (orange front, white rear)
    _box(p, Vector3(0.004, 0.0015, 0.006), Vector3(0.0085, 0.0278, -0.31), ORANGE)
    _box(p, Vector3(0.004, 0.0015, 0.006), Vector3(-0.0085, 0.0278, 0.12), WHITE)
    _box(p, Vector3(0.004, 0.0015, 0.006), Vector3(0.0085, 0.0278, 0.12), WHITE)
    # short box magazine on top at the rear: window with orange bolt tips, black cap
    _box(p, Vector3(0.034, 0.012, 0.09), Vector3(0, 0.034, 0.075), OLIVE)
    _box(p, Vector3(0.036, 0.006, 0.05), Vector3(0, 0.034, 0.075), GUNMETAL)
    for z in [0.063, 0.075, 0.087]:
        _box(p, Vector3(0.037, 0.003, 0.004), Vector3(0, 0.034, z), ORANGE)
    _box(p, Vector3(0.036, 0.004, 0.092), Vector3(0, 0.042, 0.075), BLACK)
    # limb mount block (below the rail top) and foot stirrup
    _box(p, Vector3(0.06, 0.04, 0.05), Vector3(0, 0.0, -0.29), GUNMETAL)
    _torus(p, 0.005, 0.013, Vector3(0, -0.032, -0.3), STEEL)
    # slim steel limbs swept forward, olive sleeves, pulley wheel and string per side
    for s in [-1.0, 1.0]:
        _box(p, Vector3(0.2, 0.01, 0.02), Vector3(s * 0.13, 0.005, -0.28), STEEL, Vector3(0, s * 12.0, 0))
        _box(p, Vector3(0.07, 0.016, 0.026), Vector3(s * 0.07, 0.005, -0.267), OLIVE, Vector3(0, s * 12.0, 0))
        var tip := Vector3(s * 0.228, 0.005, -0.301)
        _cyl_y(p, 0.024, 0.012, tip, GUNMETAL)
        _cyl_y(p, 0.016, 0.0125, tip, BLACK)
        _cyl_y(p, 0.006, 0.02, tip, STEEL)
        _string(p, Vector3(s * 0.211, 0.006, -0.284), Vector3(0, 0.0215, -0.13))
    _box(p, Vector3(0.012, 0.008, 0.014), Vector3(0, 0.0215, -0.125), STEEL)
    # dark stock, olive cheek panels, butt pad
    _box(p, Vector3(0.034, 0.06, 0.15), Vector3(0, -0.01, 0.175), BLACK)
    _box(p, Vector3(0.038, 0.034, 0.1), Vector3(0, -0.012, 0.17), OLIVE)
    _box(p, Vector3(0.04, 0.08, 0.012), Vector3(0, -0.01, 0.25), GUNMETAL)
    # trigger housing, pistol grip with olive panel, trigger guard
    _box(p, Vector3(0.034, 0.03, 0.1), Vector3(0, -0.035, 0.06), BLACK)
    _box(p, Vector3(0.034, 0.1, 0.05), Vector3(0, -0.085, 0.075), BLACK, Vector3(-15, 0, 0))
    _box(p, Vector3(0.036, 0.06, 0.03), Vector3(0, -0.085, 0.08), OLIVE, Vector3(-15, 0, 0))
    _trigger_guard(p, Vector3(0, -0.04, 0.0))


## Semi-Auto Sniper: long matte-gray rifle, flat low rail, fluted heavy barrel,
## side-ported brake, short box mag, thumbhole stock with a cheek riser, folded bipod.
static func _semi_auto_sniper(p: Node3D) -> void:
    # receiver, ejection port, charging handle
    _box(p, Vector3(0.045, 0.06, 0.3), Vector3(0, 0.02, -0.02), MATTE)
    _box(p, Vector3(0.047, 0.022, 0.07), Vector3(0, 0.03, 0.0), BLACK)
    _box(p, Vector3(0.012, 0.012, 0.03), Vector3(0.03, 0.036, 0.05), STEEL)
    # flat top rail with tiny ticks (nothing rises above it, top y 0.0583)
    _box(p, Vector3(0.024, 0.008, 0.62), Vector3(0, 0.0535, -0.12), MATTE_DARK)
    for i in range(10):
        _box(p, Vector3(0.026, 0.0015, 0.01), Vector3(0, 0.0575, -0.4 + i * 0.05), BLACK)
    # free-float handguard with vent slots
    _box(p, Vector3(0.05, 0.07, 0.32), Vector3(0, 0.0145, -0.32), MATTE_DARK)
    for i in range(5):
        _box(p, Vector3(0.052, 0.012, 0.012), Vector3(0, 0.02, -0.44 + i * 0.06), BLACK)
    # heavy barrel with six flutes, low front sight post
    _cyl_z(p, 0.0145, 0.0145, 0.3, Vector3(0, 0.02, -0.63), STEEL)
    for i in range(6):
        var a: float = TAU * i / 6.0
        _box(p, Vector3(0.004, 0.004, 0.22), Vector3(cos(a) * 0.0143, 0.02 + sin(a) * 0.0143, -0.63), GUNMETAL)
    _box(p, Vector3(0.006, 0.008, 0.01), Vector3(0, 0.0385, -0.75), BLACK)
    # muzzle brake with side ports
    _cyl_z(p, 0.02, 0.02, 0.07, Vector3(0, 0.02, -0.815), STEEL)
    for z in [-0.795, -0.815, -0.835]:
        _box(p, Vector3(0.046, 0.007, 0.007), Vector3(0, 0.02, z), BLACK)
    _cyl_z(p, 0.008, 0.008, 0.002, Vector3(0, 0.02, -0.8505), BLACK)
    # magwell and short straight box mag
    _box(p, Vector3(0.042, 0.03, 0.07), Vector3(0, -0.02, -0.06), GUNMETAL)
    _box(p, Vector3(0.03, 0.07, 0.045), Vector3(0, -0.065, -0.06), BLACK)
    _box(p, Vector3(0.032, 0.008, 0.047), Vector3(0, -0.104, -0.06), STEEL)
    # folded steel bipod under the handguard: mount, two legs, rubber feet
    _box(p, Vector3(0.036, 0.016, 0.03), Vector3(0, -0.028, -0.25), STEEL)
    for x in [-0.016, 0.016]:
        _box(p, Vector3(0.008, 0.012, 0.18), Vector3(x, -0.042, -0.29), STEEL)
        _box(p, Vector3(0.01, 0.014, 0.016), Vector3(x, -0.042, -0.378), BLACK)
    # thumbhole stock: top beam, cheek riser on rods, butt block, bottom bar, grip pillar
    _box(p, Vector3(0.04, 0.045, 0.3), Vector3(0, 0.0, 0.28), STOCK_GRAY)
    _box(p, Vector3(0.034, 0.022, 0.1), Vector3(0, 0.034, 0.28), MATTE_DARK)
    for z in [0.25, 0.31]:
        for x in [-0.012, 0.012]:
            _box(p, Vector3(0.005, 0.01, 0.005), Vector3(x, 0.0275, z), STEEL)
    _box(p, Vector3(0.012, 0.012, 0.012), Vector3(0.0225, 0.034, 0.28), STEEL)
    _box(p, Vector3(0.04, 0.1225, 0.17), Vector3(0, -0.0388, 0.345), STOCK_GRAY)
    _box(p, Vector3(0.044, 0.1275, 0.014), Vector3(0, -0.04, 0.437), BLACK)
    _box(p, Vector3(0.038, 0.03, 0.25), Vector3(0, -0.115, 0.225), STOCK_GRAY)
    _box(p, Vector3(0.036, 0.12, 0.05), Vector3(0, -0.07, 0.115), BLACK, Vector3(-12, 0, 0))
    _trigger_guard(p, Vector3(0, -0.03, 0.04))
