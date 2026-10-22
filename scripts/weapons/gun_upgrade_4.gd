extends "res://scripts/weapons/gun_parts.gd"
## Upgrade batch 4: rounded, detailed versions of Speed Revolver, Hand Cannon,
## Marksman DMR, Heavy Burst and Auto-Shotgun. 4-space file.
## Same overall bounding box as the old models (muzzle -Z, up +Y), so attachment
## OVERRIDES and ADS alignment stay valid. Every part overlaps its neighbours.

const KINDS: Array = ["Speed Revolver", "Hand Cannon", "Marksman DMR", "Heavy Burst", "Auto-Shotgun"]


static func handles(kind: String) -> bool:
    return KINDS.has(kind)


static func build_upgrade(kind: String, scale_mult: float) -> Node3D:
    var outer := Node3D.new()
    var root := Node3D.new()
    root.scale = Vector3.ONE * scale_mult
    outer.add_child(root)
    match kind:
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
    return outer


# ---------------------------------------------------------------- guns

## Speed Revolver: snub-nose, fluted drum with a glowing moon clip, rubber grip, brass hammer.
static func _speed_revolver(p: Node3D) -> void:
    # frame, low top strap, side screws, cylinder release
    rb(p, Vector3(0.034, 0.06, 0.1), Vector3(0, 0, 0.045), &"nickel", 0.012)
    rb(p, Vector3(0.022, 0.014, 0.15), Vector3(0, 0.031, -0.015), &"nickel", 0.006)
    for s in [-1.0, 1.0]:
        cylx(p, 0.006, 0.004, Vector3(s * 0.0175, 0.006, 0.065), &"gunmetal")
    rb(p, Vector3(0.008, 0.012, 0.018), Vector3(-0.019, 0.012, 0.0), &"steel", 0.003)
    # fluted drum with six raised ribs, glowing moon clip, chamber bores
    cylz(p, 0.034, 0.034, 0.06, Vector3(0, 0, -0.03), &"blued")
    for i in range(6):
        var a: float = TAU * i / 6.0 + PI / 6.0
        capz(p, 0.006, 0.05, Vector3(cos(a) * 0.029, sin(a) * 0.029, -0.03), &"gunmetal")
    cylz(p, 0.036, 0.036, 0.006, Vector3(0, 0, -0.063), &"glow_orange")
    for i in range(6):
        var a: float = TAU * i / 6.0
        cylz(p, 0.0075, 0.0075, 0.003, Vector3(cos(a) * 0.021, sin(a) * 0.021, -0.0665), &"black")
    cylz(p, 0.007, 0.007, 0.003, Vector3(0, 0, -0.0675), &"steel")
    # short barrel, rib, crown, ejector shroud, low front sight
    cylz(p, 0.013, 0.013, 0.09, Vector3(0, 0.016, -0.105), &"blued")
    rb(p, Vector3(0.01, 0.01, 0.08), Vector3(0, 0.031, -0.105), &"gunmetal", 0.003)
    cylz(p, 0.015, 0.015, 0.006, Vector3(0, 0.016, -0.148), &"nickel")
    cylz(p, 0.008, 0.008, 0.002, Vector3(0, 0.016, -0.1515), &"black")
    cylz(p, 0.01, 0.01, 0.075, Vector3(0, 0.0, -0.105), &"nickel")
    capx(p, 0.004, 0.012, Vector3(0, 0.0, -0.145), &"steel")
    rb(p, Vector3(0.005, 0.01, 0.008), Vector3(0, 0.0365, -0.145), &"black", 0.002)
    rb(p, Vector3(0.012, 0.005, 0.01), Vector3(0, 0.0405, 0.045), &"black", 0.002)
    # small brass hammer spur (kept low)
    rb(p, Vector3(0.01, 0.012, 0.018), Vector3(0, 0.0362, 0.092), &"brass", 0.003, Vector3(-30, 0, 0))
    # rubber grip with finger ridges, nickel backstrap, screw, steel butt cap
    var g: Node3D = pivot(p, Vector3(0, -0.07, 0.095), Vector3(-18, 0, 0))
    rb(g, Vector3(0.036, 0.116, 0.052), Vector3.ZERO, &"rubber", 0.012)
    rb(g, Vector3(0.028, 0.1, 0.008), Vector3(0, 0, 0.0265), &"nickel", 0.003)
    for i in range(3):
        capx(g, 0.005, 0.034, Vector3(0, 0.03 - i * 0.022, -0.026), &"rubber")
    cylx(g, 0.005, 0.042, Vector3(0, 0.03, 0.0), &"steel")
    rb(g, Vector3(0.038, 0.008, 0.056), Vector3(0, -0.0594, -0.0006), &"steel", 0.003)
    guard(p, Vector3(0, -0.034, 0.015))

## Hand Cannon: chunky big-bore, four-chamber drum, ported brake, ivory grip.
static func _hand_cannon(p: Node3D) -> void:
    # frame, brass side plate, thick top strap, screws
    rb(p, Vector3(0.04, 0.07, 0.13), Vector3(0, 0, 0.035), &"nickel", 0.014)
    rb(p, Vector3(0.042, 0.04, 0.05), Vector3(0, 0, 0.075), &"brass", 0.012)
    rb(p, Vector3(0.03, 0.026, 0.22), Vector3(0, 0.045, -0.07), &"nickel", 0.01)
    for s in [-1.0, 1.0]:
        cylx(p, 0.007, 0.004, Vector3(s * 0.0225, 0.0, 0.088), &"steel")
    # drum with four raised ribs, brass rings, big chambers
    cylz(p, 0.045, 0.045, 0.08, Vector3(0, 0.005, -0.045), &"blued")
    for i in range(4):
        var a: float = TAU * i / 4.0
        capz(p, 0.008, 0.05, Vector3(cos(a) * 0.037, 0.005 + sin(a) * 0.037, -0.045), &"gunmetal")
    cylz(p, 0.047, 0.047, 0.008, Vector3(0, 0.005, -0.07), &"brass")
    cylz(p, 0.047, 0.047, 0.008, Vector3(0, 0.005, -0.02), &"brass")
    for i in range(4):
        var a: float = TAU * i / 4.0 + PI / 4.0
        cylz(p, 0.0155, 0.0155, 0.003, Vector3(cos(a) * 0.026, 0.005 + sin(a) * 0.026, -0.0865), &"black")
    cylz(p, 0.01, 0.01, 0.003, Vector3(0, 0.005, -0.0865), &"steel")
    # fat chrome barrel, underlug, low rib
    cylz(p, 0.022, 0.022, 0.22, Vector3(0, 0.02, -0.19), &"nickel")
    cylz(p, 0.016, 0.016, 0.17, Vector3(0, -0.012, -0.165), &"gunmetal")
    rb(p, Vector3(0.014, 0.01, 0.14), Vector3(0, 0.0455, -0.22), &"gunmetal", 0.004)
    # ported muzzle brake: ring grooves and top vents
    cylz(p, 0.028, 0.028, 0.05, Vector3(0, 0.02, -0.315), &"gunmetal")
    cylz(p, 0.03, 0.03, 0.006, Vector3(0, 0.02, -0.337), &"nickel")
    for z in [-0.3, -0.315, -0.33]:
        cylz(p, 0.0285, 0.0285, 0.004, Vector3(0, 0.02, z), &"black")
        rb(p, Vector3(0.016, 0.002, 0.006), Vector3(0, 0.0485, z), &"black", 0.0008)
    cylz(p, 0.014, 0.014, 0.002, Vector3(0, 0.02, -0.3405), &"black")
    # low sights (red front, notched rear) and low brass hammer
    rb(p, Vector3(0.006, 0.01, 0.012), Vector3(0, 0.0535, -0.275), &"red", 0.002)
    rb(p, Vector3(0.022, 0.007, 0.01), Vector3(0, 0.0605, 0.03), &"black", 0.002)
    rb(p, Vector3(0.012, 0.02, 0.016), Vector3(0, 0.04, 0.095), &"brass", 0.004, Vector3(-30, 0, 0))
    # ivory grip with brass medallion, finger ridges, brass butt cap
    var g: Node3D = pivot(p, Vector3(0, -0.08, 0.105), Vector3(-18, 0, 0))
    rb(g, Vector3(0.04, 0.12, 0.06), Vector3.ZERO, &"white", 0.014)
    cylx(g, 0.012, 0.044, Vector3(0, 0.025, 0.0), &"brass")
    for i in range(3):
        capx(g, 0.006, 0.036, Vector3(0, 0.035 - i * 0.025, -0.03), &"white")
    rb(g, Vector3(0.044, 0.01, 0.064), Vector3(0, -0.0642, -0.0003), &"brass", 0.004)
    guard(p, Vector3(0, -0.04, 0.02), 1.3)

## Marksman DMR: wood and steel semi-auto, long thin barrel, short box mag.
static func _marksman_dmr(p: Node3D) -> void:
    # steel receiver, rear block, ejection port, charging handle, bolt-hold pin
    rb(p, Vector3(0.04, 0.055, 0.26), Vector3(0, 0.03, -0.02), &"steel", 0.012)
    rb(p, Vector3(0.036, 0.05, 0.11), Vector3(0, 0.025, 0.145), &"steel", 0.012)
    rb(p, Vector3(0.042, 0.02, 0.05), Vector3(0, 0.04, -0.02), &"black", 0.006)
    capz(p, 0.006, 0.03, Vector3(0.026, 0.045, 0.04), &"gunmetal")
    cylx(p, 0.004, 0.046, Vector3(0, 0.012, 0.1), &"gunmetal")
    # flat top rail with tiny ticks (nothing rises above it)
    rb(p, Vector3(0.02, 0.008, 0.5), Vector3(0, 0.0615, -0.1), &"gunmetal", 0.003)
    for i in range(8):
        rb(p, Vector3(0.022, 0.0015, 0.01), Vector3(0, 0.0655, -0.32 + i * 0.05), &"black", 0.0007)
    # wood handguard, steel heat shield with vents, gas block
    rb(p, Vector3(0.05, 0.045, 0.3), Vector3(0, 0.005, -0.29), &"wood", 0.018)
    rb(p, Vector3(0.04, 0.014, 0.26), Vector3(0, 0.033, -0.3), &"steel", 0.006)
    for i in range(5):
        rb(p, Vector3(0.042, 0.002, 0.01), Vector3(0, 0.04, -0.4 + i * 0.045), &"black", 0.0009)
    rb(p, Vector3(0.022, 0.03, 0.04), Vector3(0, 0.03, -0.45), &"black", 0.008)
    # long barrel, flash hider, low front sight post
    cylz(p, 0.011, 0.011, 0.23, Vector3(0, 0.02, -0.545), &"steel")
    cylz(p, 0.017, 0.017, 0.012, Vector3(0, 0.02, -0.66), &"steel")
    cylz(p, 0.016, 0.016, 0.07, Vector3(0, 0.02, -0.685), &"black")
    for z in [-0.675, -0.695, -0.712]:
        cylz(p, 0.0172, 0.0172, 0.004, Vector3(0, 0.02, z), &"gunmetal")
    cylz(p, 0.007, 0.007, 0.002, Vector3(0, 0.02, -0.7205), &"black")
    rb(p, Vector3(0.012, 0.016, 0.02), Vector3(0, 0.037, -0.5), &"black", 0.004)
    rb(p, Vector3(0.006, 0.022, 0.008), Vector3(0, 0.0515, -0.5), &"black", 0.002)
    # magwell, short straight box mag with ribs, lower receiver
    rb(p, Vector3(0.04, 0.034, 0.07), Vector3(0, -0.012, -0.04), &"gunmetal", 0.01)
    rb(p, Vector3(0.03, 0.09, 0.045), Vector3(0, -0.0425, -0.04), &"black", 0.008)
    for i in range(3):
        rb(p, Vector3(0.032, 0.003, 0.047), Vector3(0, -0.03 - i * 0.02, -0.04), &"gunmetal", 0.001)
    rb(p, Vector3(0.032, 0.008, 0.047), Vector3(0, -0.0885, -0.04), &"steel", 0.003)
    rb(p, Vector3(0.036, 0.03, 0.12), Vector3(0, -0.009, 0.09), &"gunmetal", 0.01)
    # wood pistol grip, trigger guard
    var g: Node3D = pivot(p, Vector3(0, -0.07, 0.075), Vector3(-20, 0, 0))
    rb(g, Vector3(0.034, 0.1085, 0.05), Vector3.ZERO, &"wood", 0.014)
    for i in range(3):
        capx(g, 0.004, 0.032, Vector3(0, 0.025 - i * 0.02, -0.025), &"wood_dark")
    guard(p, Vector3(0, -0.024, 0.025))
    # wood stock with cheek riser, sling loop and butt pad
    rb(p, Vector3(0.04, 0.075, 0.27), Vector3(0, 0.005, 0.3), &"wood", 0.014, Vector3(6, 0, 0))
    rb(p, Vector3(0.036, 0.022, 0.12), Vector3(0, 0.047, 0.28), &"wood_dark", 0.008)
    torus(p, 0.003, 0.007, Vector3(0, -0.036, 0.37), &"steel")
    rb(p, Vector3(0.044, 0.1, 0.014), Vector3(0, -0.005, 0.4355), &"rubber", 0.005, Vector3(6, 0, 0))

## Heavy Burst: olive and tan bullpup, mag behind the grip, big muzzle brake.
static func _heavy_burst(p: Node3D) -> void:
    # main body, tan side panels, flat top rail
    rb(p, Vector3(0.055, 0.08, 0.56), Vector3(0, 0.02, 0.055), &"olive", 0.016)
    rb(p, Vector3(0.058, 0.04, 0.25), Vector3(0, 0.0, 0.1), &"wood_light", 0.014)
    rb(p, Vector3(0.022, 0.008, 0.4), Vector3(0, 0.064, 0.02), &"gunmetal", 0.003)
    # ejection port, charging handle
    rb(p, Vector3(0.058, 0.02, 0.05), Vector3(0, 0.03, 0.18), &"black", 0.006)
    rb(p, Vector3(0.012, 0.008, 0.02), Vector3(0.028, 0.05, 0.02), &"steel", 0.003)
    capz(p, 0.006, 0.04, Vector3(0.035, 0.05, 0.02), &"steel")
    # ribbed handguard
    rb(p, Vector3(0.05, 0.06, 0.21), Vector3(0, 0.012, -0.325), &"black", 0.016)
    for i in range(4):
        rb(p, Vector3(0.054, 0.05, 0.008), Vector3(0, 0.012, -0.4 + i * 0.045), &"gunmetal", 0.003)
    # short thick barrel and big slotted muzzle brake
    cylz(p, 0.02, 0.02, 0.09, Vector3(0, 0.015, -0.47), &"steel")
    cylz(p, 0.03, 0.03, 0.074, Vector3(0, 0.015, -0.538), &"black")
    for z in [-0.53, -0.55]:
        cylz(p, 0.032, 0.032, 0.006, Vector3(0, 0.015, z), &"gunmetal")
    cylz(p, 0.012, 0.012, 0.002, Vector3(0, 0.015, -0.576), &"black")
    # low sights (below the rail top)
    rb(p, Vector3(0.006, 0.024, 0.008), Vector3(0, 0.05, -0.4), &"black", 0.002)
    rb(p, Vector3(0.02, 0.008, 0.01), Vector3(0, 0.066, 0.2), &"black", 0.003)
    # chunky vertical foregrip
    rb(p, Vector3(0.036, 0.04, 0.07), Vector3(0, -0.035, -0.33), &"black", 0.012)
    rb(p, Vector3(0.036, 0.09, 0.045), Vector3(0, -0.085, -0.33), &"rubber", 0.014)
    for i in range(3):
        capx(p, 0.004, 0.038, Vector3(0, -0.06 - i * 0.02, -0.355), &"black")
    # pistol grip, trigger guard
    var g: Node3D = pivot(p, Vector3(0, -0.075, 0.08), Vector3(-15, 0, 0))
    rb(g, Vector3(0.034, 0.108, 0.05), Vector3.ZERO, &"rubber", 0.013)
    guard(p, Vector3(0, -0.04, 0.03))
    # magazine behind the grip (bullpup), well block, tan base plate
    rb(p, Vector3(0.04, 0.034, 0.07), Vector3(0, -0.03, 0.2), &"black", 0.01)
    rb(p, Vector3(0.034, 0.12, 0.05), Vector3(0, -0.075, 0.2), &"olive", 0.012)
    for i in range(3):
        rb(p, Vector3(0.036, 0.003, 0.052), Vector3(0, -0.06 - i * 0.025, 0.2), &"olive_dark", 0.001)
    rb(p, Vector3(0.036, 0.008, 0.052), Vector3(0, -0.139, 0.2), &"wood_light", 0.003)
    # butt pad
    rb(p, Vector3(0.05, 0.09, 0.03), Vector3(0, 0.01, 0.34), &"rubber", 0.01)

## Auto-Shotgun: boxy black combat shotgun, vented shroud, glowing ring, curved mag.
static func _auto_shotgun(p: Node3D) -> void:
    # receiver, ejection port, flat top rail, ejection deflector
    rb(p, Vector3(0.06, 0.09, 0.34), Vector3(0, 0.025, -0.01), &"black", 0.014)
    rb(p, Vector3(0.062, 0.03, 0.07), Vector3(0, 0.04, 0.02), &"gunmetal", 0.008)
    rb(p, Vector3(0.022, 0.008, 0.38), Vector3(0, 0.074, -0.03), &"gunmetal", 0.003)
    rb(p, Vector3(0.024, 0.012, 0.02), Vector3(0.042, 0.045, 0.05), &"steel", 0.004)
    # vented barrel shroud (dark fins), barrel, glowing muzzle ring
    cylz(p, 0.034, 0.034, 0.32, Vector3(0, 0.03, -0.34), &"gunmetal")
    for i in range(5):
        rb(p, Vector3(0.074, 0.01, 0.014), Vector3(0, 0.03, -0.22 - i * 0.05), &"black", 0.004)
    cylz(p, 0.02, 0.02, 0.082, Vector3(0, 0.03, -0.52), &"steel")
    cylz(p, 0.026, 0.026, 0.012, Vector3(0, 0.03, -0.55), &"glow_orange")
    cylz(p, 0.015, 0.015, 0.002, Vector3(0, 0.03, -0.561), &"black")
    # low front post (below the rail top)
    rb(p, Vector3(0.008, 0.016, 0.01), Vector3(0, 0.069, -0.46), &"black", 0.003)
    # magwell and curved 8-round box mag with glowing base plate
    rb(p, Vector3(0.044, 0.034, 0.09), Vector3(0, -0.035, 0.0), &"gunmetal", 0.01)
    rb(p, Vector3(0.036, 0.07, 0.085), Vector3(0, -0.07, 0.0), &"black", 0.012, Vector3(8, 0, 0))
    rb(p, Vector3(0.036, 0.06, 0.085), Vector3(0, -0.133, -0.015), &"black", 0.012, Vector3(20, 0, 0))
    rb(p, Vector3(0.038, 0.008, 0.088), Vector3(0, -0.1634, -0.026), &"glow_orange", 0.0012, Vector3(20, 0, 0))
    # pistol grip, trigger guard
    var g: Node3D = pivot(p, Vector3(0, -0.07, 0.115), Vector3(-15, 0, 0))
    rb(g, Vector3(0.034, 0.108, 0.05), Vector3.ZERO, &"rubber", 0.013)
    guard(p, Vector3(0, -0.035, 0.07))
    # folding stock: hinge, four rods, butt plate
    rb(p, Vector3(0.05, 0.08, 0.03), Vector3(0, 0.025, 0.155), &"gunmetal", 0.01)
    for x in [-0.02, 0.02]:
        capz(p, 0.004, 0.24, Vector3(x, 0.045, 0.285), &"steel")
        capz(p, 0.004, 0.24, Vector3(x, -0.005, 0.285), &"steel")
    rb(p, Vector3(0.046, 0.1, 0.016), Vector3(0, 0.025, 0.4), &"rubber", 0.006)
