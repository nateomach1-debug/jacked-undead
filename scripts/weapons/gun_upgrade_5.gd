extends "res://scripts/weapons/gun_parts.gd"
## Upgrade treatment, batch 5: Micro SMG, Chaingun, Repeater Crossbow,
## Semi-Auto Sniper. Same bounding boxes as the old models in
## gun_models_extra.gd (muzzle toward -Z, up +Y). 4-space file.
## Orange accents use the glow_orange material, tan uses wood_light.

const KINDS: Array = ["Micro SMG", "Chaingun", "Repeater Crossbow", "Semi-Auto Sniper"]


static func handles(kind: String) -> bool:
    return KINDS.has(kind)


static func build_upgrade(kind: String, scale_mult: float) -> Node3D:
    var outer := Node3D.new()
    var root := Node3D.new()
    root.scale = Vector3.ONE * scale_mult
    outer.add_child(root)
    match kind:
        "Micro SMG":
            _micro_smg(root)
        "Chaingun":
            _chaingun(root)
        "Repeater Crossbow":
            _repeater(root)
        "Semi-Auto Sniper":
            _semi_sniper(root)
    return outer


## Round rod (capsule) from point a to point b; its tips reach radius past a and b.
static func _rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, key: StringName) -> void:
    var d: Vector3 = (b - a).normalized()
    var pitch: float = rad_to_deg(asin(-d.y))
    var yaw: float = rad_to_deg(atan2(d.x, d.z))
    var piv: Node3D = pivot(parent, (a + b) * 0.5, Vector3(pitch, yaw, 0.0))
    capz(piv, radius, a.distance_to(b) + radius * 2.0, Vector3.ZERO, key)


## Tiny round bolt head on a side face (axis X).
static func _bolt(parent: Node3D, pos: Vector3, key: StringName) -> void:
    cylx(parent, 0.0035, 0.004, pos, key)


## Micro SMG: tiny machine pistol. Boxy black receiver, flat top cover, threaded
## muzzle cap, tan grip, long stick mag with a glowing orange base plate, wire stock.
static func _micro_smg(p: Node3D) -> void:
    # receiver, front and rear plates
    rb(p, Vector3(0.040, 0.055, 0.17), Vector3(0, 0.02, -0.02), &"black", 0.008)
    rb(p, Vector3(0.044, 0.05, 0.016), Vector3(0, 0.022, -0.105), &"gunmetal", 0.005)
    rb(p, Vector3(0.040, 0.05, 0.012), Vector3(0, 0.022, 0.067), &"gunmetal", 0.005)
    # flat top cover with low ticks (top line y 0.0545)
    rb(p, Vector3(0.036, 0.009, 0.15), Vector3(0, 0.0495, -0.02), &"gunmetal", 0.003)
    for i in range(4):
        rb(p, Vector3(0.030, 0.0026, 0.007), Vector3(0, 0.0532, -0.07 + i * 0.03), &"black", 0.001)
    # side panels with cooling slots
    for s in [-1.0, 1.0]:
        rb(p, Vector3(0.004, 0.036, 0.11), Vector3(s * 0.0195, 0.018, -0.02), &"gunmetal", 0.0015)
        for i in range(3):
            rb(p, Vector3(0.0045, 0.022, 0.006), Vector3(s * 0.0195, 0.018, -0.062 + i * 0.012), &"black", 0.0015)
        _bolt(p, Vector3(s * 0.0195, 0.04, 0.025), &"steel")
        _bolt(p, Vector3(s * 0.0195, 0.0, 0.025), &"steel")
    # ejection port (right side)
    rb(p, Vector3(0.0016, 0.012, 0.034), Vector3(0.0212, 0.032, 0.012), &"black", 0.0005)
    # cocking knob (left side, stem + round head)
    cylx(p, 0.004, 0.012, Vector3(-0.0245, 0.035, 0.035), &"steel")
    capz(p, 0.0045, 0.022, Vector3(-0.0265, 0.035, 0.035), &"steel")
    # short barrel and threaded muzzle cap with three rings
    cylz(p, 0.009, 0.009, 0.075, Vector3(0, 0.03, -0.1325), &"steel")
    cylz(p, 0.0125, 0.0135, 0.033, Vector3(0, 0.03, -0.1795), &"gunmetal")
    for z in [-0.17, -0.18, -0.19]:
        torus(p, 0.0125, 0.0155, Vector3(0, 0.03, z), &"black", Vector3(90, 0, 0))
    cylz(p, 0.0065, 0.0065, 0.003, Vector3(0, 0.03, -0.196), &"black")
    # tiny iron sights (never above the tick line)
    rb(p, Vector3(0.004, 0.005, 0.006), Vector3(0, 0.052, -0.092), &"black", 0.0015)
    for x in [-0.007, 0.007]:
        rb(p, Vector3(0.006, 0.005, 0.008), Vector3(x, 0.052, 0.05), &"black", 0.0015)
    # tan grip housing with ridges
    rb(p, Vector3(0.034, 0.082, 0.046), Vector3(0, -0.044, 0.02), &"wood_light", 0.009)
    for i in range(5):
        rb(p, Vector3(0.036, 0.003, 0.04), Vector3(0, -0.03 - i * 0.01, 0.02), &"wood_dark", 0.001)
    # long straight stick mag, ribs, mag catch, glowing orange base plate
    rb(p, Vector3(0.026, 0.17, 0.036), Vector3(0, -0.1, 0.02), &"black", 0.004)
    for i in range(4):
        rb(p, Vector3(0.028, 0.004, 0.038), Vector3(0, -0.09 - i * 0.025, 0.02), &"gunmetal", 0.0015)
    cylx(p, 0.0035, 0.007, Vector3(-0.0185, -0.06, 0.0), &"steel")
    rb(p, Vector3(0.03, 0.008, 0.04), Vector3(0, -0.189, 0.02), &"glow_orange", 0.003)
    guard(p, Vector3(0, -0.012, -0.04), 0.8)
    # thin wire stock: hinge, two rods, drop legs, rubber end plate
    rb(p, Vector3(0.032, 0.032, 0.014), Vector3(0, 0.02, 0.074), &"steel", 0.005)
    for x in [-0.016, 0.016]:
        capz(p, 0.0025, 0.15, Vector3(x, 0.02, 0.15), &"steel")
        capy(p, 0.0025, 0.04, Vector3(x, 0.0, 0.2255), &"steel")
    rb(p, Vector3(0.038, 0.008, 0.012), Vector3(0, -0.02, 0.228), &"rubber", 0.003)


## Chaingun: six barrels in a ring held by two clamps, rounded housing with a flat
## top rail, big olive ammo drum with a brass belt, pistol grip, front side handle.
static func _chaingun(p: Node3D) -> void:
    # rear housing, motor block, lower block, rear cap
    rb(p, Vector3(0.09, 0.09, 0.2), Vector3(0, 0.03, 0.06), &"gunmetal", 0.012)
    rb(p, Vector3(0.082, 0.082, 0.1), Vector3(0, 0.031, -0.09), &"black", 0.01)
    rb(p, Vector3(0.094, 0.03, 0.06), Vector3(0, 0.0, 0.07), &"black", 0.008)
    rb(p, Vector3(0.07, 0.07, 0.024), Vector3(0, 0.03, 0.168), &"black", 0.009)
    # cooling fins and bolt heads on the housing sides
    for s in [-1.0, 1.0]:
        for i in range(4):
            rb(p, Vector3(0.004, 0.05, 0.008), Vector3(s * 0.045, 0.035, 0.0 + i * 0.03), &"black", 0.0015)
        _bolt(p, Vector3(s * 0.0455, 0.062, 0.14), &"steel")
        _bolt(p, Vector3(s * 0.0455, 0.0, 0.14), &"steel")
    # flat top rail (nothing rises above it) with low ticks
    rb(p, Vector3(0.03, 0.012, 0.5), Vector3(0, 0.077, -0.1), &"gunmetal", 0.003)
    for i in range(10):
        rb(p, Vector3(0.026, 0.0035, 0.01), Vector3(0, 0.0825, -0.3 + i * 0.045), &"black", 0.001)
    # center hub and six barrels in a ring
    cylz(p, 0.012, 0.018, 0.52, Vector3(0, 0.03, -0.35), &"gunmetal")
    for i in range(6):
        var a: float = TAU * i / 6.0
        var bx: float = cos(a) * 0.0275
        var by: float = 0.03 + sin(a) * 0.0275
        cylz(p, 0.011, 0.011, 0.5, Vector3(bx, by, -0.35), &"steel")
        torus(p, 0.0095, 0.0125, Vector3(bx, by, -0.594), &"gunmetal", Vector3(90, 0, 0))
        cylz(p, 0.0075, 0.0075, 0.003, Vector3(bx, by, -0.5995), &"black")
    # two clamps with rims, a mount collar for the side handle, front post
    for z in [-0.25, -0.5]:
        cylz(p, 0.044, 0.044, 0.03, Vector3(0, 0.03, z), &"steel")
        torus(p, 0.0415, 0.0475, Vector3(0, 0.03, z + 0.012), &"gunmetal", Vector3(90, 0, 0))
        torus(p, 0.0415, 0.0475, Vector3(0, 0.03, z - 0.012), &"gunmetal", Vector3(90, 0, 0))
    cylz(p, 0.04, 0.04, 0.03, Vector3(0, 0.03, -0.2), &"black")
    rb(p, Vector3(0.006, 0.01, 0.012), Vector3(0, 0.0785, -0.5), &"black", 0.002)
    # big olive ammo drum: rim rings, ribs, steel hub, feed neck
    cylx(p, 0.07, 0.09, Vector3(0, -0.095, -0.09), &"olive")
    for x in [-0.045, 0.045]:
        torus(p, 0.0615, 0.0735, Vector3(x, -0.095, -0.09), &"gunmetal")
    for x in [-0.02, 0.0, 0.02]:
        torus(p, 0.067, 0.073, Vector3(x, -0.095, -0.09), &"olive_dark")
    cylx(p, 0.02, 0.1, Vector3(0, -0.095, -0.09), &"steel")
    cylx(p, 0.008, 0.108, Vector3(0, -0.095, -0.09), &"black")
    rb(p, Vector3(0.05, 0.05, 0.07), Vector3(0, -0.025, -0.09), &"black", 0.008)
    # brass belt climbing the right side, and a loop hanging under the drum
    for i in range(6):
        capz(p, 0.006, 0.022, Vector3(0.05, -0.06 + i * 0.012, -0.09 + i * 0.01), &"brass", Vector3(-25, 0, 0))
    for i in range(5):
        ell(p, Vector3(0.006, 0.008, 0.0135), Vector3(0.0, -0.162 + i * 0.002, -0.14 + i * 0.024), &"brass")
    # pistol grip, trigger guard
    var g: Node3D = pivot(p, Vector3(0, -0.06, 0.045), Vector3(-12, 0, 0))
    rb(g, Vector3(0.036, 0.1, 0.05), Vector3.ZERO, &"black", 0.008)
    rb(g, Vector3(0.038, 0.08, 0.034), Vector3.ZERO, &"rubber", 0.006)
    guard(p, Vector3(0, -0.01, 0.0), 1.1)
    # front side handle (left): arm and round vertical grip
    rb(p, Vector3(0.05, 0.02, 0.03), Vector3(-0.062, 0.025, -0.2), &"steel", 0.006)
    capy(p, 0.0125, 0.085, Vector3(-0.085, -0.01, -0.2), &"black")
    ell(p, Vector3(0.0125, 0.007, 0.0125), Vector3(-0.085, -0.052, -0.2), &"rubber")


## Repeater Crossbow: compact black and olive crossbow. Flat top rail with a bolt
## channel, short box mag on top at the rear (behind the optic spot), steel limbs
## with a pulley wheel on each tip, thin string, dark stock + pistol grip.
static func _repeater(p: Node3D) -> void:
    # body with olive side panels
    rb(p, Vector3(0.034, 0.04, 0.46), Vector3(0, 0.0, -0.095), &"black", 0.008)
    rb(p, Vector3(0.038, 0.022, 0.2), Vector3(0, -0.002, -0.03), &"olive", 0.005)
    # flat top rail: two strips with the bolt channel between them (top y 0.028)
    for x in [-0.0085, 0.0085]:
        rb(p, Vector3(0.007, 0.008, 0.46), Vector3(x, 0.024, -0.095), &"gunmetal", 0.0025)
        for i in range(6):
            rb(p, Vector3(0.007, 0.0015, 0.006), Vector3(x, 0.0278, -0.3 + i * 0.04), &"black", 0.0007)
    rb(p, Vector3(0.012, 0.004, 0.46), Vector3(0, 0.0205, -0.095), &"black", 0.0015)
    # loaded bolt in the channel (shaft, tip, glowing orange fletching)
    cylz(p, 0.002, 0.002, 0.14, Vector3(0, 0.0245, -0.2), &"steel")
    cylz(p, 0.0005, 0.002, 0.014, Vector3(0, 0.0245, -0.277), &"steel")
    rb(p, Vector3(0.008, 0.0015, 0.016), Vector3(0, 0.0245, -0.125), &"glow_orange", 0.0007)
    # sight dots flush with the rail
    rb(p, Vector3(0.004, 0.0015, 0.006), Vector3(0.0085, 0.0278, -0.31), &"glow_orange", 0.0007)
    rb(p, Vector3(0.004, 0.0015, 0.006), Vector3(-0.0085, 0.0278, 0.12), &"white", 0.0007)
    rb(p, Vector3(0.004, 0.0015, 0.006), Vector3(0.0085, 0.0278, 0.12), &"white", 0.0007)
    # short box mag on top at the rear: window with orange bolt tips, black cap
    rb(p, Vector3(0.034, 0.016, 0.09), Vector3(0, 0.034, 0.075), &"olive", 0.004)
    rb(p, Vector3(0.036, 0.006, 0.05), Vector3(0, 0.034, 0.075), &"gunmetal", 0.0015)
    for z in [0.063, 0.075, 0.087]:
        rb(p, Vector3(0.037, 0.003, 0.004), Vector3(0, 0.034, z), &"glow_orange", 0.0012)
    rb(p, Vector3(0.036, 0.006, 0.092), Vector3(0, 0.041, 0.075), &"black", 0.0025)
    # limb mount block, foot stirrup
    rb(p, Vector3(0.06, 0.04, 0.05), Vector3(0, 0.0, -0.29), &"gunmetal", 0.008)
    torus(p, 0.008, 0.015, Vector3(0, -0.03, -0.3), &"steel")
    # slim steel limbs swept forward, olive sleeves, pulley wheel and string per side
    for s in [-1.0, 1.0]:
        rb(p, Vector3(0.2, 0.01, 0.02), Vector3(s * 0.13, 0.005, -0.28), &"steel", 0.004, Vector3(0, s * 12.0, 0))
        rb(p, Vector3(0.07, 0.016, 0.026), Vector3(s * 0.07, 0.005, -0.267), &"olive", 0.006, Vector3(0, s * 12.0, 0))
        var tip: Vector3 = Vector3(s * 0.228, 0.005, -0.301)
        cyly(p, 0.024, 0.012, tip, &"gunmetal")
        torus(p, 0.0175, 0.0235, tip, &"black", Vector3(0, 0, 0))
        cyly(p, 0.016, 0.0135, tip, &"black")
        cyly(p, 0.006, 0.02, tip, &"steel")
        _rod(p, Vector3(s * 0.211, 0.006, -0.284), Vector3(0, 0.0215, -0.13), 0.0015, &"white")
    rb(p, Vector3(0.012, 0.008, 0.014), Vector3(0, 0.0215, -0.125), &"steel", 0.003)
    # dark stock, olive cheek panels, butt pad
    rb(p, Vector3(0.034, 0.06, 0.15), Vector3(0, -0.01, 0.175), &"black", 0.008)
    rb(p, Vector3(0.038, 0.034, 0.1), Vector3(0, -0.012, 0.17), &"olive", 0.006)
    rb(p, Vector3(0.04, 0.08, 0.012), Vector3(0, -0.01, 0.25), &"rubber", 0.004)
    # trigger housing, pistol grip with olive panel, trigger guard
    rb(p, Vector3(0.034, 0.03, 0.1), Vector3(0, -0.035, 0.06), &"black", 0.007)
    var g: Node3D = pivot(p, Vector3(0, -0.085, 0.075), Vector3(-15, 0, 0))
    rb(g, Vector3(0.034, 0.1037, 0.05), Vector3.ZERO, &"black", 0.008)
    rb(g, Vector3(0.036, 0.06, 0.03), Vector3(0, 0, 0.005), &"olive", 0.006)
    guard(p, Vector3(0, -0.04, 0.0))


## Semi-Auto Sniper: long matte-gray rifle, flat low rail, fluted heavy barrel,
## side-ported brake, short box mag, thumbhole stock with a cheek riser, folded bipod.
static func _semi_sniper(p: Node3D) -> void:
    # receiver, ejection port, charging handle
    rb(p, Vector3(0.045, 0.06, 0.3), Vector3(0, 0.02, -0.02), &"gunmetal", 0.008)
    rb(p, Vector3(0.047, 0.022, 0.07), Vector3(0, 0.03, 0.0), &"black", 0.004)
    cylx(p, 0.0045, 0.012, Vector3(0.027, 0.036, 0.05), &"steel")
    capz(p, 0.005, 0.022, Vector3(0.031, 0.036, 0.05), &"steel")
    # flat top rail with low ticks (top y 0.05825)
    rb(p, Vector3(0.024, 0.01, 0.62), Vector3(0, 0.0525, -0.12), &"blued", 0.003)
    for i in range(10):
        rb(p, Vector3(0.026, 0.0015, 0.01), Vector3(0, 0.0575, -0.4 + i * 0.05), &"black", 0.0007)
    # free-float handguard with vent slots
    rb(p, Vector3(0.05, 0.07, 0.32), Vector3(0, 0.0145, -0.32), &"blued", 0.011)
    for i in range(5):
        rb(p, Vector3(0.052, 0.012, 0.012), Vector3(0, 0.02, -0.44 + i * 0.06), &"black", 0.004)
    # heavy barrel with six flutes, low front sight post
    cylz(p, 0.0145, 0.0145, 0.3, Vector3(0, 0.02, -0.63), &"steel")
    for i in range(6):
        var a: float = TAU * i / 6.0
        capz(p, 0.0025, 0.22, Vector3(cos(a) * 0.0148, 0.02 + sin(a) * 0.0148, -0.63), &"gunmetal")
    rb(p, Vector3(0.006, 0.008, 0.01), Vector3(0, 0.0385, -0.75), &"black", 0.002)
    # muzzle brake with side ports
    cylz(p, 0.02, 0.02, 0.07, Vector3(0, 0.02, -0.815), &"steel")
    for z in [-0.795, -0.815, -0.835]:
        rb(p, Vector3(0.046, 0.007, 0.007), Vector3(0, 0.02, z), &"black", 0.0025)
    torus(p, 0.0185, 0.0215, Vector3(0, 0.02, -0.848), &"gunmetal", Vector3(90, 0, 0))
    cylz(p, 0.008, 0.008, 0.003, Vector3(0, 0.02, -0.85), &"black")
    # magwell and short straight box mag
    rb(p, Vector3(0.042, 0.03, 0.07), Vector3(0, -0.02, -0.06), &"gunmetal", 0.006)
    rb(p, Vector3(0.03, 0.07, 0.045), Vector3(0, -0.065, -0.06), &"black", 0.005)
    rb(p, Vector3(0.032, 0.008, 0.047), Vector3(0, -0.104, -0.06), &"steel", 0.003)
    # folded steel bipod under the handguard: mount, hinge, two legs, rubber feet
    rb(p, Vector3(0.036, 0.02, 0.03), Vector3(0, -0.026, -0.25), &"steel", 0.005)
    for x in [-0.016, 0.016]:
        capz(p, 0.005, 0.18, Vector3(x, -0.039, -0.29), &"steel")
        ell(p, Vector3(0.006, 0.007, 0.01), Vector3(x, -0.039, -0.376), &"rubber")
    # thumbhole stock: top beam, cheek riser on rods, butt block, bottom bar
    rb(p, Vector3(0.04, 0.045, 0.3), Vector3(0, 0.0, 0.28), &"black", 0.01)
    rb(p, Vector3(0.034, 0.022, 0.1), Vector3(0, 0.034, 0.28), &"rubber", 0.006)
    for z in [0.25, 0.31]:
        for x in [-0.012, 0.012]:
            capy(p, 0.0035, 0.014, Vector3(x, 0.0275, z), &"steel")
    cylx(p, 0.006, 0.012, Vector3(0.0225, 0.034, 0.28), &"steel")
    rb(p, Vector3(0.04, 0.1225, 0.17), Vector3(0, -0.0388, 0.345), &"black", 0.01)
    rb(p, Vector3(0.044, 0.1275, 0.014), Vector3(0, -0.04, 0.437), &"rubber", 0.004)
    rb(p, Vector3(0.038, 0.03, 0.25), Vector3(0, -0.115, 0.225), &"black", 0.01)
    # pistol grip (tilted), trigger guard
    var g: Node3D = pivot(p, Vector3(0, -0.07, 0.115), Vector3(-12, 0, 0))
    rb(g, Vector3(0.036, 0.1231, 0.05), Vector3.ZERO, &"black", 0.008)
    rb(g, Vector3(0.038, 0.08, 0.034), Vector3.ZERO, &"rubber", 0.006)
    guard(p, Vector3(0, -0.03, 0.04))
