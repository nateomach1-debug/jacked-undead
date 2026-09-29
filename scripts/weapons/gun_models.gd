extends RefCounted
## Procedural gun models built from boxes, cylinders and spheres, used for
## any weapon that has no .gltf asset yet. Every gun is built pointing
## straight ahead: muzzle toward -Z, up is +Y, grip near the origin.
## build() picks the model by the weapon's placeholder_kind name.

const STEEL: Color = Color(0.62, 0.63, 0.68)
const GUNMETAL: Color = Color(0.22, 0.23, 0.27)
const BLACK: Color = Color(0.07, 0.07, 0.08)
const WOOD: Color = Color(0.42, 0.26, 0.13)
const WOOD_DARK: Color = Color(0.3, 0.18, 0.09)
const BRASS: Color = Color(0.8, 0.6, 0.2)
const OLIVE: Color = Color(0.27, 0.32, 0.2)
const TAN: Color = Color(0.55, 0.48, 0.32)
const RED: Color = Color(0.7, 0.12, 0.1)
const ORANGE: Color = Color(1.0, 0.45, 0.05)
const GLASS: Color = Color(0.6, 0.85, 1.0)


static func build(kind: String) -> Node3D:
	var root := Node3D.new()
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
		"Burst Rifle":
			_burst_rifle(root)
		"Flamethrower":
			_flamethrower(root)
		"Grenade Launcher":
			_grenade_launcher(root)
		"Rocket Launcher":
			_rocket_launcher(root)
		_:
			_box(root, Vector3(0.06, 0.1, 0.5), Vector3.ZERO, GUNMETAL)
	return root


# ---------------------------------------------------------------- helpers

static func _mat(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.3
	m.roughness = 0.55
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
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


## Cylinder lying along the Z axis (barrels, tubes). r_front is the muzzle end.
static func _cyl_z(parent: Node3D, r_front: float, r_back: float, length: float, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_back
	mesh.bottom_radius = r_front
	mesh.height = length
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.material_override = _mat(color, glow)
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(mi)
	return mi


## Cylinder lying along the X axis (gauges, pins).
static func _cyl_x(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation_degrees = Vector3(0, 0, 90)
	parent.add_child(mi)
	return mi


## Upright cylinder (vertical foregrips).
static func _cyl_y(parent: Node3D, radius: float, length: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mi.mesh = mesh
	mi.material_override = _mat(color, glow)
	mi.position = pos
	parent.add_child(mi)
	return mi


## Ring standing upright, seen as a loop from the side (trigger guards).
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

## Revolver: six-shot wheel gun with wooden grip, ejector rod and hammer.
static func _revolver(p: Node3D) -> void:
	# frame + top strap
	_box(p, Vector3(0.034, 0.06, 0.09), Vector3(0, 0.0, 0.06), STEEL)
	_box(p, Vector3(0.02, 0.008, 0.16), Vector3(0, 0.048, 0.0), STEEL)
	# cylinder drum with six chambers on its face
	_cyl_z(p, 0.038, 0.038, 0.07, Vector3(0, 0.012, -0.035), GUNMETAL)
	for i in range(6):
		var a: float = TAU * i / 6.0
		_cyl_z(p, 0.0085, 0.0085, 0.004, Vector3(cos(a) * 0.024, 0.012 + sin(a) * 0.024, -0.071), BLACK)
	# barrel, rib, ejector rod, front sight
	_cyl_z(p, 0.014, 0.014, 0.2, Vector3(0, 0.03, -0.17), STEEL)
	_box(p, Vector3(0.012, 0.008, 0.2), Vector3(0, 0.046, -0.17), GUNMETAL)
	_cyl_z(p, 0.006, 0.006, 0.12, Vector3(0, 0.0, -0.13), GUNMETAL)
	_cyl_z(p, 0.011, 0.011, 0.025, Vector3(0, 0.0, -0.075), STEEL)
	_box(p, Vector3(0.006, 0.012, 0.012), Vector3(0, 0.056, -0.262), BLACK)
	# hammer
	_box(p, Vector3(0.012, 0.035, 0.014), Vector3(0, 0.06, 0.1), GUNMETAL, Vector3(-25, 0, 0))
	# wooden grip
	_box(p, Vector3(0.032, 0.11, 0.05), Vector3(0, -0.07, 0.105), WOOD, Vector3(-18, 0, 0))
	_trigger_guard(p, Vector3(0, -0.04, 0.02))


## Magnum: big desert-eagle style semi-auto with serrated slide and top rib.
static func _magnum(p: Node3D) -> void:
	# slide with rear serrations and protruding barrel tip
	_box(p, Vector3(0.036, 0.05, 0.27), Vector3(0, 0.035, -0.055), GUNMETAL)
	for i in range(5):
		_box(p, Vector3(0.038, 0.046, 0.004), Vector3(0, 0.035, 0.035 + i * 0.009), BLACK)
	_cyl_z(p, 0.014, 0.014, 0.03, Vector3(0, 0.03, -0.205), STEEL)
	# frame under the slide, top rib, sights, ejection port
	_box(p, Vector3(0.03, 0.035, 0.24), Vector3(0, -0.002, -0.05), STEEL)
	_box(p, Vector3(0.014, 0.008, 0.26), Vector3(0, 0.063, -0.055), STEEL)
	_box(p, Vector3(0.008, 0.014, 0.008), Vector3(0, 0.072, -0.16), BLACK)
	_box(p, Vector3(0.022, 0.012, 0.008), Vector3(0, 0.07, 0.065), BLACK)
	_box(p, Vector3(0.0375, 0.016, 0.05), Vector3(0, 0.043, -0.03), BLACK)
	# grip with side panels and magazine base plate
	_box(p, Vector3(0.034, 0.105, 0.055), Vector3(0, -0.075, 0.07), BLACK, Vector3(-12, 0, 0))
	_box(p, Vector3(0.038, 0.075, 0.04), Vector3(0, -0.07, 0.072), GUNMETAL, Vector3(-12, 0, 0))
	_box(p, Vector3(0.03, 0.01, 0.06), Vector3(0, -0.13, 0.083), STEEL, Vector3(-12, 0, 0))
	_trigger_guard(p, Vector3(0, -0.035, -0.02), 1.1)


## Pump shotgun: barrel over a magazine tube, ribbed pump forend, wood stock.
static func _pump_shotgun(p: Node3D) -> void:
	# barrel, magazine tube, tube cap, vent rib, bead sight
	_cyl_z(p, 0.016, 0.016, 0.62, Vector3(0, 0.038, -0.36), GUNMETAL)
	_cyl_z(p, 0.013, 0.013, 0.5, Vector3(0, 0.008, -0.31), STEEL)
	_cyl_z(p, 0.017, 0.017, 0.012, Vector3(0, 0.008, -0.566), GUNMETAL)
	_box(p, Vector3(0.01, 0.006, 0.62), Vector3(0, 0.056, -0.36), STEEL)
	_sphere(p, 0.005, Vector3(0, 0.064, -0.665), BRASS)
	# receiver with ejection port and loading gate
	_box(p, Vector3(0.042, 0.07, 0.2), Vector3(0, 0.03, -0.02), GUNMETAL)
	_box(p, Vector3(0.044, 0.02, 0.07), Vector3(0, 0.05, -0.03), BLACK)
	_box(p, Vector3(0.03, 0.006, 0.05), Vector3(0, -0.006, -0.03), STEEL)
	# pump forend with grip grooves and action bars
	_box(p, Vector3(0.05, 0.045, 0.19), Vector3(0, 0.0, -0.27), WOOD)
	for i in range(5):
		_box(p, Vector3(0.052, 0.006, 0.008), Vector3(0, -0.012, -0.34 + i * 0.03), WOOD_DARK)
	_box(p, Vector3(0.008, 0.008, 0.06), Vector3(-0.024, 0.014, -0.147), STEEL)
	_box(p, Vector3(0.008, 0.008, 0.06), Vector3(0.024, 0.014, -0.147), STEEL)
	# wooden stock with butt pad
	_box(p, Vector3(0.036, 0.06, 0.1), Vector3(0, 0.02, 0.13), WOOD)
	_box(p, Vector3(0.04, 0.07, 0.22), Vector3(0, 0.0, 0.29), WOOD, Vector3(6, 0, 0))
	_box(p, Vector3(0.044, 0.11, 0.016), Vector3(0, -0.03, 0.405), BLACK, Vector3(6, 0, 0))
	_trigger_guard(p, Vector3(0, -0.03, 0.06))


## Double-barrel: side-by-side barrels, engraved breech, top lever, two triggers.
static func _double_barrel(p: Node3D) -> void:
	# side-by-side barrels with muzzle holes
	for side in [-1.0, 1.0]:
		_cyl_z(p, 0.015, 0.015, 0.55, Vector3(side * 0.0165, 0.03, -0.3), GUNMETAL)
		_cyl_z(p, 0.011, 0.011, 0.003, Vector3(side * 0.0165, 0.03, -0.576), BLACK)
	_box(p, Vector3(0.012, 0.006, 0.55), Vector3(0, 0.048, -0.3), STEEL)
	_box(p, Vector3(0.012, 0.006, 0.55), Vector3(0, 0.012, -0.3), STEEL)
	_sphere(p, 0.005, Vector3(0, 0.055, -0.56), BRASS)
	# breech with side plates and brass top lever
	_box(p, Vector3(0.07, 0.075, 0.14), Vector3(0, 0.025, -0.01), STEEL)
	_box(p, Vector3(0.074, 0.05, 0.09), Vector3(0, 0.02, 0.0), GUNMETAL)
	_box(p, Vector3(0.008, 0.006, 0.05), Vector3(0, 0.065, 0.04), BRASS)
	# wooden forend, stock and butt pad
	_box(p, Vector3(0.06, 0.04, 0.16), Vector3(0, -0.005, -0.2), WOOD)
	_box(p, Vector3(0.04, 0.07, 0.3), Vector3(0, 0.0, 0.2), WOOD, Vector3(8, 0, 0))
	_box(p, Vector3(0.046, 0.11, 0.016), Vector3(0, -0.03, 0.355), BLACK, Vector3(8, 0, 0))
	# double triggers
	_trigger_guard(p, Vector3(0, -0.03, 0.05))
	_box(p, Vector3(0.006, 0.024, 0.006), Vector3(0, -0.012, 0.075), STEEL)


## LMG: belt-fed squad gun with vented heat shield, bipod, carry handle, ammo box.
static func _lmg(p: Node3D) -> void:
	# receiver and feed cover
	_box(p, Vector3(0.06, 0.08, 0.34), Vector3(0, 0.03, -0.05), GUNMETAL)
	_box(p, Vector3(0.07, 0.02, 0.16), Vector3(0, 0.08, -0.08), BLACK)
	_box(p, Vector3(0.045, 0.07, 0.1), Vector3(0, 0.03, 0.17), GUNMETAL)
	# carry handle
	_box(p, Vector3(0.008, 0.04, 0.008), Vector3(0, 0.1, -0.36), GUNMETAL)
	_box(p, Vector3(0.008, 0.04, 0.008), Vector3(0, 0.1, -0.24), GUNMETAL)
	_box(p, Vector3(0.014, 0.01, 0.14), Vector3(0, 0.125, -0.3), GUNMETAL)
	# barrel, vented heat shield, flash hider
	_cyl_z(p, 0.016, 0.016, 0.42, Vector3(0, 0.045, -0.5), GUNMETAL)
	_cyl_z(p, 0.03, 0.03, 0.24, Vector3(0, 0.045, -0.36), BLACK)
	for i in range(4):
		_box(p, Vector3(0.024, 0.004, 0.02), Vector3(0, 0.0755, -0.44 + i * 0.05), GUNMETAL)
	_cyl_z(p, 0.022, 0.022, 0.06, Vector3(0, 0.045, -0.72), BLACK)
	# folded bipod legs and front sight
	_box(p, Vector3(0.008, 0.008, 0.16), Vector3(-0.02, 0.008, -0.6), STEEL)
	_box(p, Vector3(0.008, 0.008, 0.16), Vector3(0.02, 0.008, -0.6), STEEL)
	_box(p, Vector3(0.006, 0.03, 0.008), Vector3(0, 0.076, -0.66), BLACK)
	_box(p, Vector3(0.02, 0.02, 0.02), Vector3(0, 0.09, 0.06), BLACK)
	# ammo box with brass belt feeding into the gun
	_box(p, Vector3(0.09, 0.09, 0.16), Vector3(0, -0.07, -0.02), OLIVE)
	_box(p, Vector3(0.092, 0.012, 0.164), Vector3(0, -0.027, -0.02), GUNMETAL)
	for i in range(6):
		var t: float = i / 5.0
		_box(p, Vector3(0.012, 0.012, 0.02), Vector3(0.05 - 0.02 * t, -0.03 + 0.11 * t, -0.02 - 0.05 * t), BRASS, Vector3(0, 0, 25))
	# pistol grip, trigger guard, stock
	_box(p, Vector3(0.035, 0.1, 0.05), Vector3(0, -0.06, 0.14), BLACK, Vector3(-15, 0, 0))
	_trigger_guard(p, Vector3(0, -0.03, 0.08))
	_box(p, Vector3(0.05, 0.09, 0.26), Vector3(0, 0.02, 0.35), BLACK, Vector3(4, 0, 0))
	_box(p, Vector3(0.054, 0.1, 0.014), Vector3(0, 0.01, 0.485), GUNMETAL, Vector3(4, 0, 0))


## Burst rifle: M16-style with carry-handle sight, ribbed handguard, curved mag.
static func _burst_rifle(p: Node3D) -> void:
	# upper receiver, carry-handle sight, front sight tower
	_box(p, Vector3(0.045, 0.055, 0.3), Vector3(0, 0.03, -0.04), GUNMETAL)
	_box(p, Vector3(0.02, 0.03, 0.14), Vector3(0, 0.075, 0.02), GUNMETAL)
	_box(p, Vector3(0.024, 0.014, 0.02), Vector3(0, 0.098, 0.075), BLACK)
	_box(p, Vector3(0.012, 0.05, 0.012), Vector3(0, 0.06, -0.42), GUNMETAL)
	_box(p, Vector3(0.004, 0.02, 0.004), Vector3(0, 0.1, -0.42), BLACK)
	# ribbed handguard, barrel, flash hider
	_cyl_z(p, 0.03, 0.03, 0.26, Vector3(0, 0.022, -0.31), BLACK)
	for i in range(4):
		_box(p, Vector3(0.062, 0.004, 0.012), Vector3(0, 0.022, -0.4 + i * 0.05), GUNMETAL)
	_cyl_z(p, 0.011, 0.011, 0.14, Vector3(0, 0.022, -0.51), STEEL)
	_cyl_z(p, 0.016, 0.016, 0.05, Vector3(0, 0.022, -0.59), BLACK)
	# lower receiver, magazine, pistol grip, trigger guard
	_box(p, Vector3(0.04, 0.055, 0.15), Vector3(0, -0.017, 0.0), GUNMETAL)
	_box(p, Vector3(0.032, 0.12, 0.05), Vector3(0, -0.09, -0.03), BLACK, Vector3(8, 0, 0))
	_box(p, Vector3(0.032, 0.09, 0.045), Vector3(0, -0.075, 0.09), BLACK, Vector3(-20, 0, 0))
	_trigger_guard(p, Vector3(0, -0.04, 0.045))
	# buffer tube, fixed stock, butt plate, charging handle, ejection cover
	_box(p, Vector3(0.036, 0.06, 0.1), Vector3(0, 0.02, 0.13), BLACK)
	_box(p, Vector3(0.04, 0.08, 0.26), Vector3(0, 0.005, 0.31), BLACK, Vector3(8, 0, 0))
	_box(p, Vector3(0.044, 0.1, 0.014), Vector3(0, -0.005, 0.445), GUNMETAL, Vector3(8, 0, 0))
	_box(p, Vector3(0.03, 0.01, 0.03), Vector3(0, 0.062, 0.12), STEEL)
	_box(p, Vector3(0.047, 0.02, 0.05), Vector3(0, 0.035, -0.02), STEEL)


## Flamethrower: brass-collared pipe gun, red fuel tank, pressure gauge, pilot light.
static func _flamethrower(p: Node3D) -> void:
	# main pipe, brass collars, nozzle
	_cyl_z(p, 0.02, 0.02, 0.6, Vector3(0, 0.03, -0.3), STEEL)
	for z in [-0.1, -0.3, -0.5]:
		_cyl_z(p, 0.026, 0.026, 0.02, Vector3(0, 0.03, z), BRASS)
	_cyl_z(p, 0.032, 0.02, 0.07, Vector3(0, 0.03, -0.635), GUNMETAL)
	_cyl_z(p, 0.02, 0.02, 0.005, Vector3(0, 0.03, -0.672), BLACK)
	# glowing pilot light at the muzzle
	_sphere(p, 0.012, Vector3(0, 0.062, -0.66), ORANGE, true)
	_sphere(p, 0.007, Vector3(0, 0.07, -0.66), Color(1.0, 0.85, 0.3), true)
	# red fuel tank with straps and dark end caps
	_cyl_z(p, 0.055, 0.055, 0.34, Vector3(0, -0.055, -0.1), RED)
	for z in [-0.22, 0.02]:
		_cyl_z(p, 0.058, 0.058, 0.014, Vector3(0, -0.055, z), GUNMETAL)
	_cyl_z(p, 0.05, 0.05, 0.01, Vector3(0, -0.055, -0.275), GUNMETAL)
	_cyl_z(p, 0.05, 0.05, 0.01, Vector3(0, -0.055, 0.075), GUNMETAL)
	# fuel hose from tank to pipe
	_box(p, Vector3(0.012, 0.012, 0.09), Vector3(0, -0.005, -0.3), BLACK, Vector3(-25, 0, 0))
	# valve block with pressure gauge
	_box(p, Vector3(0.05, 0.06, 0.1), Vector3(0, 0.02, 0.06), GUNMETAL)
	_cyl_x(p, 0.02, 0.012, Vector3(0.028, 0.05, 0.06), Color(0.92, 0.92, 0.92))
	_cyl_x(p, 0.008, 0.014, Vector3(0.031, 0.05, 0.06), ORANGE)
	# pistol grip, trigger guard, short stock
	_box(p, Vector3(0.035, 0.1, 0.05), Vector3(0, -0.07, 0.11), BLACK, Vector3(-10, 0, 0))
	_trigger_guard(p, Vector3(0, -0.035, 0.05))
	_box(p, Vector3(0.035, 0.06, 0.16), Vector3(0, 0.02, 0.22), GUNMETAL)


## Grenade launcher: revolver-drum style with red-dot sight and foregrip.
static func _grenade_launcher(p: Node3D) -> void:
	# revolving drum with six chambers
	_cyl_z(p, 0.058, 0.058, 0.13, Vector3(0, 0.02, -0.04), GUNMETAL)
	_cyl_z(p, 0.06, 0.06, 0.01, Vector3(0, 0.02, -0.1), STEEL)
	for i in range(6):
		var a: float = TAU * i / 6.0
		_cyl_z(p, 0.017, 0.017, 0.004, Vector3(cos(a) * 0.033, 0.02 + sin(a) * 0.033, -0.107), BLACK)
	# barrel with muzzle ring and bore
	_cyl_z(p, 0.026, 0.026, 0.2, Vector3(0, 0.02, -0.22), BLACK)
	_cyl_z(p, 0.03, 0.03, 0.02, Vector3(0, 0.02, -0.33), STEEL)
	_cyl_z(p, 0.018, 0.018, 0.002, Vector3(0, 0.02, -0.342), BLACK)
	# frame, top rail, red-dot sight
	_box(p, Vector3(0.05, 0.05, 0.16), Vector3(0, -0.035, 0.03), GUNMETAL)
	_box(p, Vector3(0.02, 0.01, 0.34), Vector3(0, 0.085, -0.06), BLACK)
	_box(p, Vector3(0.03, 0.03, 0.05), Vector3(0, 0.105, 0.0), BLACK)
	_box(p, Vector3(0.026, 0.02, 0.003), Vector3(0, 0.108, -0.026), GLASS)
	_sphere(p, 0.003, Vector3(0, 0.108, -0.024), RED, true)
	# vertical foregrip on a bracket
	_box(p, Vector3(0.03, 0.04, 0.08), Vector3(0, -0.025, -0.15), BLACK)
	_cyl_y(p, 0.014, 0.09, Vector3(0, -0.085, -0.15), BLACK)
	# pistol grip, trigger guard
	_box(p, Vector3(0.036, 0.1, 0.05), Vector3(0, -0.095, 0.09), BLACK, Vector3(-15, 0, 0))
	_trigger_guard(p, Vector3(0, -0.06, 0.03))
	# telescoping stock
	_box(p, Vector3(0.04, 0.06, 0.12), Vector3(0, 0.0, 0.17), GUNMETAL)
	_box(p, Vector3(0.03, 0.05, 0.14), Vector3(0, 0.0, 0.29), STEEL)
	_box(p, Vector3(0.04, 0.09, 0.014), Vector3(0, -0.01, 0.365), BLACK)


## Rocket launcher: RPG-style tube with flared exhaust, wood heat shield, warhead.
static func _rocket_launcher(p: Node3D) -> void:
	# launch tube with flared rear exhaust
	_cyl_z(p, 0.03, 0.03, 0.7, Vector3(0, 0.03, -0.1), OLIVE)
	_cyl_z(p, 0.03, 0.05, 0.14, Vector3(0, 0.03, 0.32), GUNMETAL)
	_cyl_z(p, 0.04, 0.04, 0.003, Vector3(0, 0.03, 0.391), BLACK)
	# wooden heat shield with metal bands
	_cyl_z(p, 0.04, 0.04, 0.22, Vector3(0, 0.03, -0.12), WOOD)
	for z in [-0.22, -0.02]:
		_cyl_z(p, 0.043, 0.043, 0.012, Vector3(0, 0.03, z), GUNMETAL)
	# rocket warhead: body, orange band, nose cone, tip
	_cyl_z(p, 0.045, 0.045, 0.1, Vector3(0, 0.03, -0.5), OLIVE)
	_cyl_z(p, 0.046, 0.046, 0.02, Vector3(0, 0.03, -0.47), ORANGE)
	_cyl_z(p, 0.012, 0.045, 0.16, Vector3(0, 0.03, -0.63), TAN)
	_sphere(p, 0.012, Vector3(0, 0.03, -0.715), GUNMETAL)
	# pistol grip, trigger guard, foregrip
	_box(p, Vector3(0.035, 0.11, 0.05), Vector3(0, -0.07, 0.02), BLACK, Vector3(-15, 0, 0))
	_trigger_guard(p, Vector3(0, -0.035, -0.02))
	_box(p, Vector3(0.03, 0.09, 0.03), Vector3(0, -0.05, -0.2), BLACK)
	# side-mounted optical sight and iron sights
	_box(p, Vector3(0.03, 0.01, 0.04), Vector3(-0.03, 0.055, -0.05), GUNMETAL)
	_box(p, Vector3(0.03, 0.04, 0.14), Vector3(-0.055, 0.075, -0.05), BLACK)
	_box(p, Vector3(0.02, 0.02, 0.005), Vector3(-0.055, 0.075, -0.125), GLASS)
	_box(p, Vector3(0.006, 0.03, 0.01), Vector3(0, 0.075, -0.3), BLACK)
	_box(p, Vector3(0.006, 0.02, 0.008), Vector3(0, 0.07, 0.1), BLACK)
