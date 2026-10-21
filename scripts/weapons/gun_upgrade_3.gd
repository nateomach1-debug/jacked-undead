extends "res://scripts/weapons/gun_parts.gd"
## Gun upgrade batch 3: Burst Rifle, Flamethrower, Grenade Launcher, Rocket Launcher, Tactical .45.
## Rounder shapes (rounded boxes, capsules, ellipsoids), more detail, no gaps.
## Every gun keeps the SAME overall size and the same parts at its extremes
## (muzzle, grip bottom, top line, butt), so all attachment mount points,
## OVERRIDES and ADS alignment stay exactly where they were.
## To go back to the old look of one gun, remove its name from KINDS.

const KINDS: Array = ["Burst Rifle", "Flamethrower", "Grenade Launcher", "Rocket Launcher", "Tactical .45"]


static func handles(kind: String) -> bool:
    return KINDS.has(kind)


static func build_upgrade(kind: String, scale_mult: float) -> Node3D:
    var outer := Node3D.new()
    var root := Node3D.new()
    root.scale = Vector3.ONE * scale_mult
    outer.add_child(root)
    match kind:
        "Burst Rifle":
            _burst_rifle(root)
        "Flamethrower":
            _flamethrower(root)
        "Grenade Launcher":
            _grenade_launcher(root)
        "Rocket Launcher":
            _rocket_launcher(root)
        "Tactical .45":
            _tactical_45(root)
    return outer


## Burst Rifle: M16-style with carry-handle rear sight, ringed handguard, ported flash hider,
## ribbed curved magazine, buffer tube and padded stock.
static func _burst_rifle(p: Node3D) -> void:
    # upper receiver, ejection cover, forward assist
    rb(p, Vector3(0.045, 0.055, 0.3), Vector3(0, 0.03, -0.04), &"gunmetal", 0.012)
    rb(p, Vector3(0.047, 0.022, 0.05), Vector3(0, 0.035, -0.02), &"steel", 0.006)
    capz(p, 0.005, 0.03, Vector3(0.0235, 0.04, 0.06), &"steel")
    # carry handle with rear sight and aperture
    rb(p, Vector3(0.02, 0.034, 0.14), Vector3(0, 0.0725, 0.02), &"gunmetal", 0.008)
    rb(p, Vector3(0.024, 0.016, 0.024), Vector3(0, 0.097, 0.074), &"steel", 0.005)
    cylz(p, 0.004, 0.004, 0.002, Vector3(0, 0.098, 0.0865), &"black")
    # front sight tower, base plate and post
    rb(p, Vector3(0.016, 0.057, 0.02), Vector3(0, 0.0565, -0.42), &"gunmetal", 0.005)
    rb(p, Vector3(0.014, 0.006, 0.016), Vector3(0, 0.087, -0.42), &"steel", 0.002)
    capy(p, 0.0028, 0.036, Vector3(0, 0.092, -0.42), &"black")
    # handguard with clamp rings, delta ring, barrel, flash hider
    cylz(p, 0.0295, 0.0295, 0.26, Vector3(0, 0.022, -0.31), &"black")
    for i in range(5):
        cylz(p, 0.031, 0.031, 0.012, Vector3(0, 0.022, -0.425 + i * 0.04), &"gunmetal")
    cylz(p, 0.031, 0.031, 0.014, Vector3(0, 0.022, -0.19), &"steel")
    cylz(p, 0.011, 0.011, 0.16, Vector3(0, 0.022, -0.51), &"steel")
    cylz(p, 0.016, 0.016, 0.05, Vector3(0, 0.022, -0.59), &"black")
    cylz(p, 0.0175, 0.0175, 0.006, Vector3(0, 0.022, -0.6), &"gunmetal")
    cylz(p, 0.0175, 0.0175, 0.006, Vector3(0, 0.022, -0.575), &"gunmetal")
    cylz(p, 0.0075, 0.0075, 0.003, Vector3(0, 0.022, -0.6135), &"rubber")
    # lower receiver, magwell, selector and mag release
    rb(p, Vector3(0.04, 0.055, 0.15), Vector3(0, -0.017, 0), &"gunmetal", 0.01)
    rb(p, Vector3(0.036, 0.03, 0.062), Vector3(0, -0.044, -0.03), &"gunmetal", 0.008)
    cylx(p, 0.006, 0.004, Vector3(-0.0215, 0.0, 0.03), &"steel")
    cylx(p, 0.006, 0.004, Vector3(0.0215, -0.012, -0.03), &"steel")
    # curved-look magazine with ribs and base plate
    var mg: Node3D = pivot(p, Vector3(0, -0.09, -0.03), Vector3(8, 0, 0))
    rb(mg, Vector3(0.032, 0.114, 0.05), Vector3(0, 0.003, 0), &"black", 0.01)
    for i in range(3):
        rb(mg, Vector3(0.0336, 0.003, 0.052), Vector3(0, 0.02 - i * 0.025, 0), &"gunmetal", 0.001)
    rb(mg, Vector3(0.034, 0.012, 0.054), Vector3(0, -0.054, 0), &"gunmetal", 0.004)
    # pistol grip, filler, trigger guard
    var gr: Node3D = pivot(p, Vector3(0, -0.075, 0.09), Vector3(-20, 0, 0))
    rb(gr, Vector3(0.032, 0.09, 0.045), Vector3(0, 0, 0), &"black", 0.012)
    rb(gr, Vector3(0.03, 0.07, 0.004), Vector3(0, 0.0, 0.0245), &"rubber", 0.0015)
    rb(gr, Vector3(0.026, 0.07, 0.004), Vector3(0, 0.0, -0.0245), &"gunmetal", 0.0015)
    rb(p, Vector3(0.036, 0.04, 0.06), Vector3(0, -0.035, 0.075), &"gunmetal", 0.01)
    guard(p, Vector3(0, -0.04, 0.045))
    # buffer tube, nut, stock with butt pad, charging handle
    cylz(p, 0.02, 0.02, 0.12, Vector3(0, 0.02, 0.14), &"black")
    cylz(p, 0.0225, 0.0225, 0.012, Vector3(0, 0.02, 0.1), &"gunmetal")
    var sk: Node3D = pivot(p, Vector3(0, 0.005, 0.31), Vector3(8, 0, 0))
    rb(sk, Vector3(0.04, 0.08, 0.26), Vector3(0, 0, 0), &"black", 0.014)
    rb(sk, Vector3(0.044, 0.1, 0.014), Vector3(0, 0.0089, 0.1356), &"rubber", 0.004)
    rb(p, Vector3(0.03, 0.012, 0.03), Vector3(0, 0.0615, 0.106), &"steel", 0.004)


## Flamethrower: brass-collared pipe gun, red fuel tank with white band, valve block with
## pressure gauge and hand wheel, glowing pilot light at the nozzle.
static func _flamethrower(p: Node3D) -> void:
    # main pipe, brass collars, nozzle with lip and bore
    cylz(p, 0.02, 0.02, 0.6, Vector3(0, 0.03, -0.3), &"steel")
    for z in [-0.1, -0.3, -0.5]:
        cylz(p, 0.026, 0.026, 0.02, Vector3(0, 0.03, z), &"brass")
        cylz(p, 0.0285, 0.0285, 0.006, Vector3(0, 0.03, z), &"brass")
    cylz(p, 0.032, 0.02, 0.07, Vector3(0, 0.03, -0.635), &"gunmetal")
    cylz(p, 0.0345, 0.0345, 0.01, Vector3(0, 0.03, -0.665), &"steel")
    cylz(p, 0.022, 0.022, 0.005, Vector3(0, 0.03, -0.672), &"black")
    # glowing pilot light on a bracket
    capy(p, 0.0035, 0.03, Vector3(0, 0.052, -0.66), &"steel")
    ell(p, Vector3(0.012, 0.012, 0.012), Vector3(0, 0.062, -0.66), &"glow_orange")
    ell(p, Vector3(0.0045, 0.007, 0.0045), Vector3(0, 0.07, -0.66), &"glow_orange")
    # red fuel tank with straps, white band and fittings
    capz(p, 0.055, 0.34, Vector3(0, -0.055, -0.1), &"red")
    for z in [-0.19, -0.01]:
        cylz(p, 0.058, 0.058, 0.014, Vector3(0, -0.055, z), &"gunmetal")
    cylz(p, 0.0556, 0.0556, 0.02, Vector3(0, -0.055, -0.1), &"white")
    cylz(p, 0.016, 0.016, 0.02, Vector3(0, -0.055, -0.275), &"steel")
    cylz(p, 0.016, 0.016, 0.02, Vector3(0, -0.055, 0.075), &"steel")
    # brackets, top valve and fuel hose joining tank and pipe
    rb(p, Vector3(0.03, 0.03, 0.03), Vector3(0, 0.005, -0.19), &"gunmetal", 0.008)
    capy(p, 0.012, 0.036, Vector3(0, 0.004, -0.1), &"brass")
    capz(p, 0.007, 0.12, Vector3(0, 0.004, -0.24), &"rubber")
    # valve block with pressure gauge and red hand wheel
    rb(p, Vector3(0.05, 0.06, 0.12), Vector3(0, 0.02, 0.05), &"gunmetal", 0.014)
    cylx(p, 0.022, 0.014, Vector3(0.029, 0.05, 0.06), &"steel")
    cylx(p, 0.0185, 0.004, Vector3(0.0355, 0.05, 0.06), &"white")
    cylx(p, 0.004, 0.006, Vector3(0.0385, 0.05, 0.06), &"steel")
    capy(p, 0.0016, 0.016, Vector3(0.0385, 0.053, 0.06), &"glow_orange", Vector3(25, 0, 0))
    cylx(p, 0.004, 0.012, Vector3(-0.03, 0.02, 0.06), &"steel")
    cylx(p, 0.018, 0.005, Vector3(-0.036, 0.02, 0.06), &"red")
    # pistol grip with finger grooves, bridge, trigger guard
    var gr: Node3D = pivot(p, Vector3(0, -0.07, 0.11), Vector3(-10, 0, 0))
    rb(gr, Vector3(0.035, 0.1, 0.05), Vector3(0, 0, 0), &"black", 0.014)
    for i in range(3):
        capx(gr, 0.003, 0.036, Vector3(0, 0.02 - i * 0.02, -0.0255), &"rubber")
    rb(gr, Vector3(0.038, 0.012, 0.054), Vector3(0, -0.0445, 0), &"rubber", 0.004)
    rb(p, Vector3(0.03, 0.04, 0.06), Vector3(0, -0.025, 0.095), &"gunmetal", 0.01)
    guard(p, Vector3(0, -0.035, 0.05))
    # stock neck, stock and rubber pad
    rb(p, Vector3(0.032, 0.05, 0.07), Vector3(0, 0.02, 0.125), &"black", 0.01)
    rb(p, Vector3(0.035, 0.06, 0.16), Vector3(0, 0.02, 0.22), &"gunmetal", 0.014)
    rb(p, Vector3(0.038, 0.064, 0.012), Vector3(0, 0.02, 0.294), &"rubber", 0.004)


## Grenade launcher: fluted six-chamber drum, ringed barrel, red-dot sight with glowing dot,
## ringed foregrip, telescoping stock with cheek rest.
static func _grenade_launcher(p: Node3D) -> void:
    # revolving drum: blued body, steel rims, flutes, six chambers
    cylz(p, 0.0575, 0.0575, 0.13, Vector3(0, 0.02, -0.04), &"blued")
    cylz(p, 0.06, 0.06, 0.01, Vector3(0, 0.02, -0.1), &"steel")
    cylz(p, 0.06, 0.06, 0.01, Vector3(0, 0.02, 0.015), &"steel")
    for i in range(6):
        var a: float = TAU * i / 6.0
        var cx: float = cos(a) * 0.033
        var cy: float = 0.02 + sin(a) * 0.033
        cylz(p, 0.0195, 0.0195, 0.003, Vector3(cx, cy, -0.1065), &"nickel")
        cylz(p, 0.0165, 0.0165, 0.004, Vector3(cx, cy, -0.107), &"black")
        var b: float = TAU * (i + 0.5) / 6.0
        rb(p, Vector3(0.005, 0.016, 0.09), Vector3(cos(b) * 0.0565, 0.02 + sin(b) * 0.0565, -0.04), &"gunmetal", 0.002, Vector3(0, 0, rad_to_deg(b)))
    cylz(p, 0.012, 0.012, 0.014, Vector3(0, 0.02, -0.108), &"steel")
    # barrel with rings, muzzle collar and bore
    cylz(p, 0.026, 0.026, 0.22, Vector3(0, 0.02, -0.21), &"black")
    for z in [-0.16, -0.22, -0.28]:
        cylz(p, 0.0285, 0.0285, 0.008, Vector3(0, 0.02, z), &"gunmetal")
    cylz(p, 0.03, 0.03, 0.02, Vector3(0, 0.02, -0.33), &"steel")
    cylz(p, 0.018, 0.018, 0.004, Vector3(0, 0.02, -0.341), &"black")
    # frame, receiver behind the drum, top rail
    rb(p, Vector3(0.05, 0.05, 0.16), Vector3(0, -0.035, 0.03), &"gunmetal", 0.014)
    rb(p, Vector3(0.044, 0.094, 0.09), Vector3(0, 0.034, 0.07), &"gunmetal", 0.012)
    rb(p, Vector3(0.02, 0.014, 0.34), Vector3(0, 0.084, -0.06), &"black", 0.004)
    # red-dot sight: base, housing, lens ring, lens, glowing dot, knob
    rb(p, Vector3(0.026, 0.014, 0.06), Vector3(0, 0.0905, 0), &"gunmetal", 0.004)
    rb(p, Vector3(0.03, 0.03, 0.05), Vector3(0, 0.105, 0), &"black", 0.008)
    torus(p, 0.0095, 0.0125, Vector3(0, 0.106, -0.0262), &"gunmetal", Vector3(90, 0, 0))
    cylz(p, 0.0095, 0.0095, 0.002, Vector3(0, 0.106, -0.0259), &"white")
    ell(p, Vector3(0.0028, 0.0028, 0.0012), Vector3(0, 0.106, -0.0272), &"glow_orange")
    cylx(p, 0.006, 0.004, Vector3(0.0155, 0.108, 0.0), &"steel")
    # foregrip bracket, grip and rings
    rb(p, Vector3(0.03, 0.042, 0.08), Vector3(0, -0.025, -0.15), &"gunmetal", 0.01)
    capy(p, 0.015, 0.092, Vector3(0, -0.085, -0.15), &"black")
    for y in [-0.07, -0.09, -0.11]:
        torus(p, 0.0135, 0.0165, Vector3(0, y, -0.15), &"gunmetal", Vector3(0, 0, 0))
    # pistol grip, trigger guard
    var gr: Node3D = pivot(p, Vector3(0, -0.095, 0.09), Vector3(-15, 0, 0))
    rb(gr, Vector3(0.036, 0.103, 0.05), Vector3(0, -0.0015, 0), &"black", 0.013)
    for i in range(3):
        capx(gr, 0.003, 0.036, Vector3(0, 0.02 - i * 0.02, -0.0255), &"rubber")
    guard(p, Vector3(0, -0.06, 0.03))
    # telescoping stock, cheek rest, adjuster, butt plate
    rb(p, Vector3(0.04, 0.06, 0.12), Vector3(0, 0.0, 0.17), &"gunmetal", 0.014)
    rb(p, Vector3(0.03, 0.05, 0.14), Vector3(0, 0.0, 0.29), &"steel", 0.01)
    rb(p, Vector3(0.034, 0.012, 0.1), Vector3(0, 0.031, 0.23), &"black", 0.004)
    cylx(p, 0.007, 0.006, Vector3(0.0225, 0.0, 0.2), &"steel")
    rb(p, Vector3(0.04, 0.09, 0.014), Vector3(0, -0.01, 0.365), &"rubber", 0.004)


## Rocket launcher: RPG-style olive tube with stencil bands, flared exhaust, grooved wood heat
## shield, red-banded warhead with brass nose, side optic with hooded lens.
static func _rocket_launcher(p: Node3D) -> void:
    # launch tube with stencil bands and flared exhaust
    cylz(p, 0.03, 0.03, 0.75, Vector3(0, 0.03, -0.125), &"olive")
    for z in [0.08, 0.14, 0.2]:
        cylz(p, 0.0325, 0.0325, 0.01, Vector3(0, 0.03, z), &"olive_dark")
    cylz(p, 0.0306, 0.0306, 0.02, Vector3(0, 0.03, 0.11), &"white")
    cylz(p, 0.03, 0.05, 0.14, Vector3(0, 0.03, 0.32), &"gunmetal")
    cylz(p, 0.038, 0.038, 0.01, Vector3(0, 0.03, 0.3), &"steel")
    cylz(p, 0.0485, 0.0485, 0.01, Vector3(0, 0.03, 0.36), &"steel")
    cylz(p, 0.05, 0.05, 0.01, Vector3(0, 0.03, 0.385), &"steel")
    cylz(p, 0.042, 0.042, 0.003, Vector3(0, 0.03, 0.391), &"black")
    # wooden heat shield with grooves and metal bands
    cylz(p, 0.04, 0.04, 0.22, Vector3(0, 0.03, -0.12), &"wood")
    for i in range(6):
        cylz(p, 0.0406, 0.0406, 0.005, Vector3(0, 0.03, -0.2 + i * 0.034), &"wood_dark")
    for z in [-0.22, -0.02]:
        cylz(p, 0.043, 0.043, 0.012, Vector3(0, 0.03, z), &"gunmetal")
    # warhead: body, red band, rings, nose cone, tip
    cylz(p, 0.045, 0.045, 0.102, Vector3(0, 0.03, -0.499), &"olive")
    cylz(p, 0.0462, 0.0462, 0.02, Vector3(0, 0.03, -0.47), &"red")
    cylz(p, 0.0464, 0.0464, 0.004, Vector3(0, 0.03, -0.495), &"white")
    cylz(p, 0.0465, 0.0465, 0.008, Vector3(0, 0.03, -0.455), &"olive_dark")
    cylz(p, 0.012, 0.045, 0.162, Vector3(0, 0.03, -0.629), &"brass")
    ell(p, Vector3(0.012, 0.012, 0.012), Vector3(0, 0.03, -0.715), &"gunmetal")
    # pistol grip, trigger housing, guard, foregrip with rings
    var gr: Node3D = pivot(p, Vector3(0, -0.07, 0.02), Vector3(-15, 0, 0))
    rb(gr, Vector3(0.035, 0.113, 0.05), Vector3(0, -0.0015, 0), &"black", 0.013)
    for i in range(3):
        capx(gr, 0.003, 0.036, Vector3(0, 0.02 - i * 0.02, -0.0255), &"rubber")
    rb(p, Vector3(0.036, 0.04, 0.07), Vector3(0, -0.012, 0.02), &"gunmetal", 0.012)
    guard(p, Vector3(0, -0.035, -0.02))
    capy(p, 0.015, 0.09, Vector3(0, -0.05, -0.2), &"black")
    for y in [-0.03, -0.055, -0.08]:
        torus(p, 0.0135, 0.0165, Vector3(0, y, -0.2), &"gunmetal", Vector3(0, 0, 0))
    # side optic: mount, body, lens in hood ring, ocular, turret
    rb(p, Vector3(0.03, 0.01, 0.04), Vector3(-0.03, 0.055, -0.05), &"gunmetal", 0.003)
    rb(p, Vector3(0.03, 0.04, 0.14), Vector3(-0.055, 0.075, -0.05), &"black", 0.01)
    torus(p, 0.0095, 0.0125, Vector3(-0.055, 0.075, -0.1285), &"gunmetal", Vector3(90, 0, 0))
    cylz(p, 0.0105, 0.0105, 0.01, Vector3(-0.055, 0.075, -0.1235), &"white")
    cylz(p, 0.011, 0.011, 0.012, Vector3(-0.055, 0.075, 0.025), &"gunmetal")
    cylx(p, 0.006, 0.012, Vector3(-0.0375, 0.078, -0.05), &"steel")
    # iron sights
    rb(p, Vector3(0.008, 0.036, 0.012), Vector3(0, 0.075, -0.3), &"gunmetal", 0.003)
    rb(p, Vector3(0.01, 0.026, 0.01), Vector3(0, 0.07, 0.1), &"gunmetal", 0.003)


## Tactical .45: slim black pistol, serrated slide, low white-dot sights, rail with weapon
## light, tan grip panels and steel magazine base plate.
static func _tactical_45(p: Node3D) -> void:
    # slide, serrations, ejection port, barrel tip with bushing and bore
    rb(p, Vector3(0.03, 0.04, 0.2), Vector3(0, 0.04, -0.06), &"gunmetal", 0.008)
    for i in range(5):
        rb(p, Vector3(0.032, 0.036, 0.003), Vector3(0, 0.04, 0.005 + i * 0.008), &"black", 0.001)
    for i in range(3):
        rb(p, Vector3(0.032, 0.036, 0.003), Vector3(0, 0.04, -0.13 - i * 0.008), &"black", 0.001)
    rb(p, Vector3(0.031, 0.012, 0.04), Vector3(0, 0.048, -0.05), &"black", 0.004)
    cylz(p, 0.009, 0.009, 0.024, Vector3(0, 0.045, -0.168), &"steel")
    cylz(p, 0.0115, 0.0115, 0.008, Vector3(0, 0.045, -0.162), &"gunmetal")
    cylz(p, 0.005, 0.005, 0.002, Vector3(0, 0.045, -0.179), &"black")
    # low iron sights with white dots (5 mm tall, optic sits above them)
    rb(p, Vector3(0.006, 0.007, 0.008), Vector3(0, 0.0615, -0.145), &"black", 0.0015)
    ell(p, Vector3(0.0015, 0.0015, 0.001), Vector3(0, 0.0635, -0.1405), &"white")
    rb(p, Vector3(0.007, 0.007, 0.008), Vector3(-0.0075, 0.0615, 0.03), &"black", 0.0015)
    rb(p, Vector3(0.007, 0.007, 0.008), Vector3(0.0075, 0.0615, 0.03), &"black", 0.0015)
    ell(p, Vector3(0.0015, 0.0015, 0.001), Vector3(-0.0075, 0.0635, 0.0345), &"white")
    ell(p, Vector3(0.0015, 0.0015, 0.001), Vector3(0.0075, 0.0635, 0.0345), &"white")
    # slide stop lever
    rb(p, Vector3(0.002, 0.007, 0.024), Vector3(0.015, 0.02, -0.01), &"steel", 0.0008)
    # polymer frame, rear block, accessory rail with slots, weapon light
    rb(p, Vector3(0.028, 0.026, 0.19), Vector3(0, 0.012, -0.065), &"black", 0.009)
    rb(p, Vector3(0.028, 0.03, 0.06), Vector3(0, 0.005, 0.01), &"black", 0.01)
    rb(p, Vector3(0.02, 0.013, 0.07), Vector3(0, -0.0035, -0.125), &"gunmetal", 0.003)
    for i in range(3):
        rb(p, Vector3(0.0215, 0.01, 0.005), Vector3(0, -0.0035, -0.1 - i * 0.02), &"black", 0.001)
    rb(p, Vector3(0.026, 0.031, 0.045), Vector3(0, -0.0235, -0.12), &"black", 0.007)
    torus(p, 0.0085, 0.0115, Vector3(0, -0.0235, -0.1425), &"gunmetal", Vector3(90, 0, 0))
    cylz(p, 0.0105, 0.0105, 0.004, Vector3(0, -0.0235, -0.1405), &"white")
    # grip with tan panels, groove strips and steel mag base plate
    var gr: Node3D = pivot(p, Vector3(0, -0.055, 0.035), Vector3(-12, 0, 0))
    rb(gr, Vector3(0.03, 0.1, 0.05), Vector3(0, 0, 0), &"black", 0.011)
    rb(gr, Vector3(0.032, 0.07, 0.034), Vector3(0, 0, 0.002), &"wood_light", 0.01)
    rb(gr, Vector3(0.03, 0.009, 0.054), Vector3(0, -0.0533, 0.0008), &"steel", 0.003)
    guard(p, Vector3(0, -0.02, -0.02))

# END OF FILE
