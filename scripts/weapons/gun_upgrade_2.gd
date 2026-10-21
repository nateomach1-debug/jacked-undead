extends "res://scripts/weapons/gun_parts.gd"
## Gun upgrade batch 2: Revolver, Magnum, Pump Shotgun, Double-Barrel, LMG.
## Rounder shapes (rounded boxes, capsules, ellipsoids), more detail, no gaps.
## Every gun keeps the SAME overall size and the same parts at its extremes
## (muzzle, grip bottom, top line, butt), so all attachment mount points,
## OVERRIDES and ADS alignment stay exactly where they were.
## To go back to the old look of one gun, remove its name from KINDS.

const KINDS: Array = ["Revolver", "Magnum", "Pump Shotgun", "Double-Barrel", "LMG"]


static func handles(kind: String) -> bool:
    return KINDS.has(kind)


static func build_upgrade(kind: String, scale_mult: float) -> Node3D:
    var outer := Node3D.new()
    var root := Node3D.new()
    root.scale = Vector3.ONE * scale_mult
    outer.add_child(root)
    match kind:
        "Revolver":
            _revolver(root)
        "Magnum":
            _magnum(root)
        "Pump Shotgun":
            _pump_shotgun(root)
        "Double-Barrel":
            _double_barrel(root)
        "LMG":
            _lmg(root)
    return outer


## Revolver: blued six-shot drum with steel rims, crane, underlug and ejector rod,
## ribbed barrel with crown, low hammer, two-tone wooden grip with medallions.
static func _revolver(p: Node3D) -> void:
    # frame reaching back over the drum, top strap, sideplate screws
    rb(p, Vector3(0.036, 0.066, 0.11), Vector3(0, 0.0, 0.05), &"steel", 0.013)
    rb(p, Vector3(0.022, 0.011, 0.17), Vector3(0, 0.0475, -0.005), &"steel", 0.0045)
    for s in [-1.0, 1.0]:
        cylx(p, 0.0045, 0.003, Vector3(s * 0.0185, 0.008, 0.078), &"gunmetal")
        cylx(p, 0.006, 0.003, Vector3(s * 0.0185, 0.004, 0.03), &"nickel")
    # drum: blued body, steel rim rings (these set the full width), notch band
    cylz(p, 0.0375, 0.0375, 0.07, Vector3(0, 0.012, -0.035), &"blued")
    cylz(p, 0.038, 0.038, 0.006, Vector3(0, 0.012, -0.003), &"steel")
    cylz(p, 0.038, 0.038, 0.006, Vector3(0, 0.012, -0.067), &"steel")
    cylz(p, 0.038, 0.038, 0.004, Vector3(0, 0.012, -0.035), &"gunmetal")
    for i in range(6):
        var a: float = TAU * i / 6.0
        var cx: float = cos(a) * 0.024
        var cy: float = 0.012 + sin(a) * 0.024
        cylz(p, 0.0105, 0.0105, 0.003, Vector3(cx, cy, -0.0705), &"nickel")
        cylz(p, 0.0085, 0.0085, 0.004, Vector3(cx, cy, -0.0712), &"rubber")
    cylz(p, 0.007, 0.007, 0.014, Vector3(0, 0.012, -0.075), &"steel")
    # crane under the drum
    rb(p, Vector3(0.016, 0.02, 0.05), Vector3(0, -0.022, -0.058), &"steel", 0.007)
    # barrel with crown, rib, underlug, ejector rod and knob
    cylz(p, 0.0125, 0.0155, 0.2, Vector3(0, 0.03, -0.17), &"blued")
    cylz(p, 0.0165, 0.0165, 0.012, Vector3(0, 0.03, -0.264), &"steel")
    rb(p, Vector3(0.012, 0.008, 0.2), Vector3(0, 0.046, -0.17), &"gunmetal", 0.0035)
    capz(p, 0.0125, 0.14, Vector3(0, 0.008, -0.135), &"steel")
    cylz(p, 0.0045, 0.0045, 0.03, Vector3(0, 0.008, -0.205), &"gunmetal")
    ell(p, Vector3(0.0055, 0.0055, 0.007), Vector3(0, 0.008, -0.222), &"steel")
    # front sight blade with a white dot
    rb(p, Vector3(0.006, 0.012, 0.014), Vector3(0, 0.056, -0.262), &"black", 0.0025)
    ell(p, Vector3(0.0014, 0.0035, 0.0014), Vector3(0, 0.0585, -0.2545), &"white")
    # hammer (kept low so optics stay clear)
    rb(p, Vector3(0.012, 0.02, 0.014), Vector3(0, 0.04, 0.108), &"gunmetal", 0.004, Vector3(-25, 0, 0))
    # grip: wood body, steel butt cap and backstrap, lighter side panels, brass medallions
    var g: Node3D = pivot(p, Vector3(0, -0.07, 0.105), Vector3(-18, 0, 0))
    rb(g, Vector3(0.032, 0.104, 0.05), Vector3(0, 0.003, 0), &"wood", 0.012)
    rb(g, Vector3(0.036, 0.012, 0.05), Vector3(0, -0.049, 0), &"steel", 0.005)
    rb(g, Vector3(0.022, 0.09, 0.006), Vector3(0, 0.0, 0.0225), &"steel", 0.002)
    for s in [-1.0, 1.0]:
        rb(g, Vector3(0.0035, 0.08, 0.036), Vector3(s * 0.0165, 0.0, 0.0), &"wood_light", 0.0015)
        cylx(g, 0.0065, 0.003, Vector3(s * 0.0185, 0.025, 0.0), &"brass")
    guard(p, Vector3(0, -0.04, 0.02))


## Magnum: slab-sided semi-auto with serrated slide, port, top rib, wedge barrel
## base and a black grip with side panels.
static func _magnum(p: Node3D) -> void:
    # slide with rear and front serrations, ejection port, top rib, sights
    rb(p, Vector3(0.036, 0.05, 0.27), Vector3(0, 0.035, -0.055), &"gunmetal", 0.009)
    for i in range(6):
        rb(p, Vector3(0.0376, 0.044, 0.003), Vector3(0, 0.035, 0.03 + i * 0.009), &"black", 0.0012)
    for i in range(3):
        rb(p, Vector3(0.0376, 0.044, 0.003), Vector3(0, 0.035, -0.14 - i * 0.009), &"black", 0.0012)
    rb(p, Vector3(0.0375, 0.016, 0.05), Vector3(0, 0.043, -0.03), &"black", 0.004)
    rb(p, Vector3(0.014, 0.008, 0.26), Vector3(0, 0.063, -0.055), &"steel", 0.003)
    rb(p, Vector3(0.008, 0.014, 0.008), Vector3(0, 0.072, -0.16), &"black", 0.002)
    rb(p, Vector3(0.022, 0.012, 0.008), Vector3(0, 0.07, 0.065), &"black", 0.002)
    # barrel tip with crown and bore
    cylz(p, 0.013, 0.0145, 0.05, Vector3(0, 0.03, -0.195), &"steel")
    cylz(p, 0.0155, 0.0155, 0.006, Vector3(0, 0.03, -0.217), &"nickel")
    cylz(p, 0.0075, 0.0075, 0.003, Vector3(0, 0.03, -0.2188), &"rubber")
    # frame, wedge under the barrel, trigger housing, slide-lock disc
    rb(p, Vector3(0.03, 0.035, 0.24), Vector3(0, -0.002, -0.05), &"steel", 0.01)
    rb(p, Vector3(0.026, 0.022, 0.1), Vector3(0, -0.022, -0.1), &"steel", 0.009)
    rb(p, Vector3(0.03, 0.02, 0.1), Vector3(0, -0.018, 0.03), &"steel", 0.007)
    cylx(p, 0.007, 0.003, Vector3(0.0175, 0.036, 0.06), &"nickel")
    # grip with side panels, front strap and magazine base plate
    var g: Node3D = pivot(p, Vector3(0, -0.075, 0.07), Vector3(-12, 0, 0))
    rb(g, Vector3(0.034, 0.105, 0.055), Vector3(0, 0.0, 0.0), &"black", 0.012)
    rb(g, Vector3(0.038, 0.075, 0.04), Vector3(0, 0.005, 0.002), &"gunmetal", 0.012)
    rb(g, Vector3(0.02, 0.09, 0.004), Vector3(0, 0.0, -0.0275), &"steel", 0.0015)
    rb(g, Vector3(0.03, 0.01, 0.06), Vector3(0, -0.0565, 0.0013), &"steel", 0.003)
    guard(p, Vector3(0, -0.035, -0.02), 1.1)


## Pump shotgun: barrel over a magazine tube with clamps, vent rib, bead,
## ribbed wooden pump, rounded receiver and wood stock with rubber pad.
static func _pump_shotgun(p: Node3D) -> void:
    # barrel with crown, vent rib, bead sight
    cylz(p, 0.0155, 0.0165, 0.62, Vector3(0, 0.038, -0.36), &"blued")
    cylz(p, 0.0175, 0.0175, 0.012, Vector3(0, 0.038, -0.664), &"gunmetal")
    rb(p, Vector3(0.01, 0.006, 0.62), Vector3(0, 0.056, -0.36), &"steel", 0.0025)
    ell(p, Vector3(0.005, 0.005, 0.005), Vector3(0, 0.064, -0.665), &"brass")
    # magazine tube, end cap, web and clamp bands joining it to the barrel
    cylz(p, 0.013, 0.013, 0.5, Vector3(0, 0.008, -0.31), &"steel")
    cylz(p, 0.0175, 0.0175, 0.014, Vector3(0, 0.008, -0.566), &"gunmetal")
    rb(p, Vector3(0.01, 0.006, 0.5), Vector3(0, 0.0215, -0.31), &"gunmetal", 0.002)
    for z in [-0.52, -0.4]:
        rb(p, Vector3(0.022, 0.05, 0.014), Vector3(0, 0.023, z), &"gunmetal", 0.007)
    # receiver with ejection port, loading gate and rounded rear blend
    rb(p, Vector3(0.042, 0.07, 0.2), Vector3(0, 0.03, -0.02), &"gunmetal", 0.014)
    rb(p, Vector3(0.044, 0.02, 0.07), Vector3(0, 0.05, -0.03), &"black", 0.006)
    rb(p, Vector3(0.03, 0.006, 0.05), Vector3(0, -0.006, -0.03), &"steel", 0.002)
    ell(p, Vector3(0.02, 0.034, 0.04), Vector3(0, 0.026, 0.085), &"gunmetal")
    # pump forend with dark grip rings and two action bars
    rb(p, Vector3(0.05, 0.045, 0.19), Vector3(0, 0.0, -0.27), &"wood", 0.016)
    for i in range(5):
        rb(p, Vector3(0.052, 0.047, 0.007), Vector3(0, 0.0, -0.34 + i * 0.03), &"wood_dark", 0.0035)
    for s in [-1.0, 1.0]:
        rb(p, Vector3(0.008, 0.008, 0.06), Vector3(s * 0.024, 0.014, -0.147), &"steel", 0.003)
    # trigger plate and guard
    rb(p, Vector3(0.034, 0.014, 0.12), Vector3(0, -0.012, 0.03), &"gunmetal", 0.005)
    guard(p, Vector3(0, -0.03, 0.06))
    # wrist, stock and rubber butt pad
    rb(p, Vector3(0.036, 0.06, 0.1), Vector3(0, 0.02, 0.13), &"wood", 0.015)
    rb(p, Vector3(0.04, 0.07, 0.22), Vector3(0, 0.0, 0.29), &"wood", 0.014, Vector3(6, 0, 0))
    rb(p, Vector3(0.044, 0.11, 0.016), Vector3(0, -0.03, 0.405), &"rubber", 0.006, Vector3(6, 0, 0))


## Double-barrel: two barrels joined by a web, engraved round breech plates with
## brass rosettes, brass top lever, wooden forend and stock, two triggers.
static func _double_barrel(p: Node3D) -> void:
    # side-by-side barrels with crowns and bores
    for side in [-1.0, 1.0]:
        cylz(p, 0.0145, 0.0155, 0.55, Vector3(side * 0.0165, 0.03, -0.3), &"blued")
        cylz(p, 0.0165, 0.0165, 0.01, Vector3(side * 0.0165, 0.03, -0.57), &"gunmetal")
        cylz(p, 0.0105, 0.0105, 0.003, Vector3(side * 0.0165, 0.03, -0.576), &"rubber")
    # web between the barrels, top and bottom ribs, bead sight
    rb(p, Vector3(0.014, 0.022, 0.55), Vector3(0, 0.03, -0.3), &"gunmetal", 0.005)
    rb(p, Vector3(0.012, 0.006, 0.55), Vector3(0, 0.048, -0.3), &"steel", 0.0025)
    rb(p, Vector3(0.012, 0.006, 0.55), Vector3(0, 0.012, -0.3), &"steel", 0.0025)
    ell(p, Vector3(0.005, 0.005, 0.005), Vector3(0, 0.055, -0.56), &"brass")
    # breech with side rosettes
    rb(p, Vector3(0.07, 0.075, 0.14), Vector3(0, 0.025, -0.01), &"steel", 0.02)
    rb(p, Vector3(0.074, 0.05, 0.09), Vector3(0, 0.02, 0.0), &"gunmetal", 0.015)
    for s in [-1.0, 1.0]:
        cylx(p, 0.016, 0.003, Vector3(s * 0.0358, 0.02, 0.0), &"nickel")
        cylx(p, 0.008, 0.0032, Vector3(s * 0.0358, 0.02, 0.0), &"brass")
    # brass top lever with thumb piece
    rb(p, Vector3(0.008, 0.006, 0.05), Vector3(0, 0.065, 0.04), &"brass", 0.0025)
    ell(p, Vector3(0.007, 0.0025, 0.012), Vector3(0, 0.0655, 0.07), &"brass")
    # wooden forend with steel cap, web into the barrels
    rb(p, Vector3(0.06, 0.04, 0.16), Vector3(0, -0.005, -0.2), &"wood", 0.016)
    rb(p, Vector3(0.062, 0.042, 0.012), Vector3(0, -0.005, -0.286), &"steel", 0.004)
    rb(p, Vector3(0.034, 0.012, 0.16), Vector3(0, 0.012, -0.2), &"gunmetal", 0.004)
    # trigger plate, guard and the second trigger
    rb(p, Vector3(0.03, 0.012, 0.1), Vector3(0, -0.012, 0.04), &"steel", 0.004)
    guard(p, Vector3(0, -0.03, 0.05))
    capy(p, 0.003, 0.022, Vector3(0, -0.012, 0.075), &"steel", Vector3(-10, 0, 0))
    # stock and rubber butt pad
    rb(p, Vector3(0.04, 0.07, 0.3), Vector3(0, 0.0, 0.2), &"wood", 0.016, Vector3(8, 0, 0))
    rb(p, Vector3(0.046, 0.11, 0.016), Vector3(0, -0.03, 0.355), &"rubber", 0.006, Vector3(8, 0, 0))


## LMG: rounded receiver and feed cover, arched carry handle, vented heat shield
## with rings, flash hider, folding bipod on a mount, olive ammo box with ribs
## and a brass belt feeding into the gun, pistol grip and rounded stock.
static func _lmg(p: Node3D) -> void:
    # receiver, feed cover, tray lip, rear block
    rb(p, Vector3(0.06, 0.08, 0.34), Vector3(0, 0.03, -0.05), &"gunmetal", 0.014)
    rb(p, Vector3(0.07, 0.02, 0.16), Vector3(0, 0.08, -0.08), &"black", 0.007)
    rb(p, Vector3(0.066, 0.012, 0.05), Vector3(0, 0.054, -0.2), &"black", 0.004)
    rb(p, Vector3(0.045, 0.07, 0.1), Vector3(0, 0.03, 0.17), &"gunmetal", 0.014)
    # carry handle: bases, posts and bar
    rb(p, Vector3(0.016, 0.014, 0.034), Vector3(0, 0.076, -0.24), &"gunmetal", 0.004)
    rb(p, Vector3(0.016, 0.014, 0.016), Vector3(0, 0.078, -0.36), &"gunmetal", 0.004)
    capy(p, 0.005, 0.04, Vector3(0, 0.1, -0.36), &"steel")
    capy(p, 0.005, 0.04, Vector3(0, 0.1, -0.24), &"steel")
    capz(p, 0.005, 0.14, Vector3(0, 0.125, -0.3), &"steel")
    # barrel, vented heat shield with end rings, flash hider
    cylz(p, 0.015, 0.016, 0.42, Vector3(0, 0.045, -0.5), &"steel")
    cylz(p, 0.03, 0.03, 0.24, Vector3(0, 0.045, -0.36), &"black")
    cylz(p, 0.026, 0.026, 0.05, Vector3(0, 0.045, -0.235), &"gunmetal")
    cylz(p, 0.032, 0.032, 0.012, Vector3(0, 0.045, -0.245), &"gunmetal")
    cylz(p, 0.032, 0.032, 0.012, Vector3(0, 0.045, -0.475), &"gunmetal")
    for i in range(4):
        var vz: float = -0.44 + i * 0.05
        ell(p, Vector3(0.011, 0.0035, 0.011), Vector3(0, 0.0755, vz), &"gunmetal")
        for s in [-1.0, 1.0]:
            ell(p, Vector3(0.0035, 0.011, 0.011), Vector3(s * 0.0295, 0.045, vz), &"gunmetal")
    cylz(p, 0.019, 0.022, 0.06, Vector3(0, 0.045, -0.72), &"black")
    cylz(p, 0.011, 0.011, 0.003, Vector3(0, 0.045, -0.7485), &"rubber")
    rb(p, Vector3(0.044, 0.006, 0.01), Vector3(0, 0.045, -0.73), &"gunmetal", 0.002)
    rb(p, Vector3(0.006, 0.044, 0.01), Vector3(0, 0.045, -0.73), &"gunmetal", 0.002)
    # folding bipod on a mount, with rubber feet
    rb(p, Vector3(0.04, 0.024, 0.04), Vector3(0, 0.02, -0.56), &"gunmetal", 0.006)
    for s in [-1.0, 1.0]:
        capz(p, 0.005, 0.16, Vector3(s * 0.02, 0.008, -0.6), &"steel")
        ell(p, Vector3(0.0055, 0.005, 0.008), Vector3(s * 0.02, 0.008, -0.678), &"rubber")
    # front and rear sights
    rb(p, Vector3(0.006, 0.03, 0.008), Vector3(0, 0.076, -0.66), &"black", 0.002)
    rb(p, Vector3(0.016, 0.016, 0.016), Vector3(0, 0.075, 0.06), &"gunmetal", 0.004)
    rb(p, Vector3(0.02, 0.02, 0.02), Vector3(0, 0.09, 0.06), &"black", 0.005)
    # charging handle
    cylx(p, 0.005, 0.026, Vector3(0.044, 0.04, -0.03), &"steel")
    # ammo box with lid, ribs and feed neck
    rb(p, Vector3(0.09, 0.09, 0.16), Vector3(0, -0.07, -0.02), &"olive", 0.012)
    rb(p, Vector3(0.092, 0.012, 0.164), Vector3(0, -0.027, -0.02), &"gunmetal", 0.004)
    rb(p, Vector3(0.05, 0.03, 0.07), Vector3(0, -0.018, -0.02), &"black", 0.006)
    for z in [-0.085, 0.045]:
        rb(p, Vector3(0.092, 0.088, 0.008), Vector3(0, -0.07, z), &"olive_dark", 0.003)
    # brass belt rising from the box to the feed cover
    for i in range(9):
        var t: float = i / 8.0
        rb(p, Vector3(0.012, 0.012, 0.02), Vector3(0.05 - 0.02 * t, -0.03 + 0.11 * t, -0.02 - 0.05 * t), &"brass", 0.005, Vector3(0, 0, 25))
    # pistol grip, trigger housing, guard
    rb(p, Vector3(0.035, 0.1, 0.05), Vector3(0, -0.06, 0.14), &"black", 0.014, Vector3(-15, 0, 0))
    rb(p, Vector3(0.03, 0.02, 0.1), Vector3(0, -0.02, 0.1), &"gunmetal", 0.006)
    guard(p, Vector3(0, -0.03, 0.08))
    # stock and butt plate
    rb(p, Vector3(0.05, 0.09, 0.26), Vector3(0, 0.02, 0.35), &"black", 0.016, Vector3(4, 0, 0))
    rb(p, Vector3(0.054, 0.1, 0.014), Vector3(0, 0.01, 0.485), &"gunmetal", 0.005, Vector3(4, 0, 0))

# END OF FILE
