extends RefCounted
## Procedural attachment graphics, sized from the gun they sit on.
## Mount space: the gun points along +X, up is +Y.

const DARK: Color = Color(0.10, 0.10, 0.12)
const STEEL: Color = Color(0.35, 0.36, 0.40)
const ORANGE: Color = Color(0.95, 0.5, 0.1)
const RED: Color = Color(1.0, 0.1, 0.1)
const TAN: Color = Color(0.45, 0.40, 0.25)

# Where each slot sits on the gun's box: x = 0 rear .. 1 muzzle, y = 0 bottom .. 1 top.
const ANCHORS: Dictionary = {
	"optic": Vector2(0.45, 1.0),
	"barrel": Vector2(1.0, 0.62),
	"magazine": Vector2(0.11, 0.07),
	"grip": Vector2(0.75, 0.25),
}
# Height of the "look-through" point above each optic's origin (fraction of gun length).
const SIGHT_HEIGHT: Dictionary = {"red_dot": 0.055, "holo": 0.057, "scope_4x": 0.07, "scope_8x": 0.075}
# Per-gun tweaks after checking screenshots, e.g. {"Rifle": {"optic": Vector2(0.5, 1.0)}}
const OVERRIDES: Dictionary = {
	"Pistol": {
		"optic": Vector2(0.58, 0.95),
		"barrel": Vector2(1.0, 0.86),
		"magazine": Vector2(0.08, 0.06),
		"magazine_tilt": -25.0,
		"grip": Vector2(0.64, 0.39),
	},
	"Rifle": {
		"optic": Vector2(0.50, 0.90),
		"barrel": Vector2(1.0, 0.63),
		"magazine": Vector2(0.45, 0.09),
		"magazine_tilt": -40.0,
		"grip": Vector2(0.83, 0.20),
	},
	"SMG": {
		"optic": Vector2(0.66, 0.97),
		"barrel": Vector2(1.0, 0.84),
		"magazine": Vector2(0.86, 0.04),
		"grip": Vector2(0.95, 0.66),
	},
	"Revolver": {
		"optic": Vector2(0.40, 0.86),
		"barrel": Vector2(1.0, 0.76),
		"magazine": Vector2(0.05, 0.07),
		"magazine_tilt": -19.0,
		"grip": Vector2(0.68, 0.60),
	},
	"Double-Barrel": {
		"optic": Vector2(0.45, 1.0),
		"barrel": Vector2(1.0, 0.78),
		"magazine": Vector2(0.40, 0.44),
		"grip": Vector2(0.62, 0.38),
	},
	"Pump Shotgun": {
		"optic": Vector2(0.45, 1.0),
		"barrel": Vector2(1.0, 0.83),
		"magazine": Vector2(0.40, 0.52),
		"grip": Vector2(0.63, 0.40),
	},
	"Sniper": {
		"optic": Vector2(0.45, 1.0),
		"barrel": Vector2(1.0, 0.69),
		"magazine": Vector2(0.53, 0.44),
		"grip": Vector2(0.76, 0.45),
	},
	"Crossbow": {
		"optic": Vector2(0.68, 1.0),
		"barrel": Vector2(1.0, 0.80),
		"magazine": Vector2(0.59, 0.53),
				"grip": Vector2(0.72, 0.48),
	},
	"Burst Rifle": {
		"optic": Vector2(0.42, 0.90),
		"barrel": Vector2(1.0, 0.62),
		"magazine": Vector2(0.465, 0.06),
		"magazine_tilt": 10.0,
		"grip": Vector2(0.73, 0.56),
	},
	"Rocket Launcher": {
		"optic": Vector2(0.46, 0.87),
		"barrel": Vector2(1.0, 0.69),
		"magazine": Vector2(0.325, 0.115),
		"magazine_tilt": -30.0,
		"grip": Vector2(0.67, 0.51),
	},
	"LMG": {
		"optic": Vector2(0.45, 0.83),
		"barrel": Vector2(1.0, 0.63),
		"magazine": Vector2(0.41, 0.09),
		"grip": Vector2(0.69, 0.54),
	},
	"Flamethrower": {
		"optic": Vector2(0.51, 0.83),
		"barrel": Vector2(1.0, 0.75),
		"magazine": Vector2(0.33, 0.11),
		"grip": Vector2(0.73, 0.66),
	},
	"Magnum": {
		"optic": Vector2(0.50, 0.94),
		"barrel": Vector2(1.0, 0.78),
		"magazine": Vector2(0.10, 0.05),
		"magazine_tilt": -10.0,
		"grip": Vector2(0.77, 0.55),
	},
	"Grenade Launcher": {
		"optic": Vector2(0.585, 0.84),
		"barrel": Vector2(1.0, 0.63),
		"magazine": Vector2(0.365, 0.04),
		"magazine_tilt": -25.0,
		"grip": Vector2(0.88, 0.54),
	},
}

## Builds all of a gun's attachments, placed using the model's bounding box.
func build_for(model: Node3D, loadout: Dictionary, weapon_name: String) -> Node3D:
	var info: Dictionary = {"has": false, "box": AABB()}
	_collect_aabb(model, Transform3D.IDENTITY, info)
	if not bool(info["has"]):
		return null
	var box: AABB = info["box"]
	var s: float = clampf(box.size.x, 0.2, 2.5)
	var root := Node3D.new()
	root.name = "AttachRoot"
	var tweaks: Dictionary = OVERRIDES.get(weapon_name, {})
	for slot in loadout.keys():
		var node: Node3D = build(str(loadout[slot]), s)
		if node == null:
			continue
		var frac: Vector2 = tweaks.get(slot, ANCHORS.get(slot, Vector2(0.5, 1.0)))
		node.position = Vector3(
			box.position.x + box.size.x * frac.x,
			box.position.y + box.size.y * frac.y,
			box.position.z + box.size.z * 0.5)
		node.rotation_degrees = Vector3(0.0, 0.0, float(tweaks.get(str(slot) + "_tilt", 0.0)))
		node.name = str(slot)
		node.set_meta("optic_id", str(loadout[slot]))
		node.set_meta("sight_local", Vector3(0.0, float(SIGHT_HEIGHT.get(str(loadout[slot]), 0.05)) * s, 0.0))
		root.add_child(node)
	return root


## One attachment's graphic. s = the gun's length, so parts scale with the gun.
func build(id: String, s: float) -> Node3D:
	var n := Node3D.new()
	match id:
		"red_dot":
			n.add_child(_box(Vector3(0.14, 0.025, 0.06) * s, Vector3(0, 0.0125, 0) * s, DARK))
			n.add_child(_box(Vector3(0.10, 0.06, 0.012) * s, Vector3(0, 0.055, 0.024) * s, DARK))
			n.add_child(_box(Vector3(0.10, 0.06, 0.012) * s, Vector3(0, 0.055, -0.024) * s, DARK))
			n.add_child(_box(Vector3(0.008, 0.045, 0.04) * s, Vector3(0.04, 0.055, 0) * s, Color(1.0, 0.2, 0.2, 0.45), true))
		"holo":
			n.add_child(_box(Vector3(0.12, 0.02, 0.07) * s, Vector3(0, 0.01, 0) * s, DARK))
			n.add_child(_box(Vector3(0.11, 0.075, 0.012) * s, Vector3(0, 0.0575, 0.032) * s, DARK))
			n.add_child(_box(Vector3(0.11, 0.075, 0.012) * s, Vector3(0, 0.0575, -0.032) * s, DARK))
			n.add_child(_box(Vector3(0.11, 0.012, 0.076) * s, Vector3(0, 0.1, 0) * s, DARK))
			n.add_child(_box(Vector3(0.008, 0.06, 0.05) * s, Vector3(0.045, 0.057, 0) * s, Color(0.3, 0.8, 1.0, 0.35), true))
		"scope_4x":
			n.add_child(_cyl(0.032 * s, 0.30 * s, Vector3(0, 0.07, 0) * s, DARK))
			n.add_child(_cyl(0.042 * s, 0.06 * s, Vector3(0.15, 0.07, 0) * s, STEEL))
			n.add_child(_cyl(0.038 * s, 0.05 * s, Vector3(-0.15, 0.07, 0) * s, STEEL))
			n.add_child(_box(Vector3(0.04, 0.05, 0.03) * s, Vector3(0.08, 0.025, 0) * s, STEEL))
			n.add_child(_box(Vector3(0.04, 0.05, 0.03) * s, Vector3(-0.08, 0.025, 0) * s, STEEL))
		"scope_8x":
			n.add_child(_cyl(0.036 * s, 0.40 * s, Vector3(0, 0.075, 0) * s, DARK))
			n.add_child(_cyl(0.052 * s, 0.07 * s, Vector3(0.20, 0.075, 0) * s, STEEL))
			n.add_child(_cyl(0.042 * s, 0.05 * s, Vector3(-0.20, 0.075, 0) * s, STEEL))
			n.add_child(_box(Vector3(0.03, 0.02, 0.03) * s, Vector3(0, 0.12, 0) * s, STEEL))
			n.add_child(_box(Vector3(0.04, 0.055, 0.03) * s, Vector3(0.10, 0.027, 0) * s, STEEL))
			n.add_child(_box(Vector3(0.04, 0.055, 0.03) * s, Vector3(-0.10, 0.027, 0) * s, STEEL))
		"long_barrel":
			n.add_child(_cyl(0.018 * s, 0.22 * s, Vector3(0.11, 0, 0) * s, STEEL))
		"suppressor":
			n.add_child(_cyl(0.032 * s, 0.20 * s, Vector3(0.10, 0, 0) * s, DARK))
			n.add_child(_cyl(0.034 * s, 0.015 * s, Vector3(0.20, 0, 0) * s, STEEL))
		"compensator":
			n.add_child(_cyl(0.022 * s, 0.07 * s, Vector3(0.035, 0, 0) * s, STEEL))
			n.add_child(_box(Vector3(0.015, 0.012, 0.03) * s, Vector3(0.02, 0.024, 0) * s, DARK))
			n.add_child(_box(Vector3(0.015, 0.012, 0.03) * s, Vector3(0.05, 0.024, 0) * s, DARK))
		"heavy_barrel":
			n.add_child(_cyl(0.03 * s, 0.16 * s, Vector3(0.08, 0, 0) * s, DARK))
			n.add_child(_cyl(0.034 * s, 0.012 * s, Vector3(0.04, 0, 0) * s, STEEL))
			n.add_child(_cyl(0.034 * s, 0.012 * s, Vector3(0.15, 0, 0) * s, STEEL))
		"ext_mag":
			n.add_child(_box(Vector3(0.07, 0.26, 0.05) * s, Vector3(0, -0.13, 0) * s, DARK))
			n.add_child(_box(Vector3(0.072, 0.02, 0.052) * s, Vector3(0, -0.25, 0) * s, STEEL))
		"fast_mag":
			n.add_child(_box(Vector3(0.07, 0.20, 0.05) * s, Vector3(0, -0.10, 0) * s, ORANGE))
		"drum_mag":
			n.add_child(_box(Vector3(0.05, 0.05, 0.045) * s, Vector3(0, -0.025, 0) * s, DARK))
			n.add_child(_zcyl(0.075 * s, 0.05 * s, Vector3(0, -0.11, 0) * s, DARK))
			n.add_child(_zcyl(0.04 * s, 0.054 * s, Vector3(0, -0.11, 0) * s, STEEL))
		"ammo_pouch":
			n.add_child(_box(Vector3(0.09, 0.12, 0.075) * s, Vector3(0.07, -0.06, 0) * s, TAN))
			n.add_child(_box(Vector3(0.092, 0.03, 0.077) * s, Vector3(0.07, -0.015, 0) * s, DARK))
		"foregrip":
			n.add_child(_vcyl(0.022 * s, 0.14 * s, Vector3(0, -0.07, 0) * s, DARK))
		"angled_grip":
			var grip := _box(Vector3(0.05, 0.13, 0.04) * s, Vector3(0.03, -0.065, 0) * s, DARK)
			grip.rotation.z = deg_to_rad(-25.0)
			n.add_child(grip)
		"vertical_grip":
			n.add_child(_vcyl(0.022 * s, 0.20 * s, Vector3(0, -0.10, 0) * s, DARK))
			n.add_child(_vcyl(0.026 * s, 0.02 * s, Vector3(0, -0.20, 0) * s, STEEL))
		"ergo_grip":
			var ergo := _box(Vector3(0.05, 0.14, 0.045) * s, Vector3(-0.025, -0.07, 0) * s, DARK)
			ergo.rotation.z = deg_to_rad(20.0)
			n.add_child(ergo)
			n.add_child(_box(Vector3(0.052, 0.015, 0.047) * s, Vector3(-0.04, -0.13, 0) * s, ORANGE))
		_:
			return null
	return n


func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.5
	m.roughness = 0.5
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
	return m


func _box(size: Vector3, pos: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _material(color, glow)
	return mi


## A cylinder lying along the gun (X axis).
func _cyl(radius: float, length: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mi.mesh = mesh
	mi.rotation.z = deg_to_rad(90.0)
	mi.position = pos
	mi.material_override = _material(color)
	return mi


## A cylinder standing up (Y axis).
func _vcyl(radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _material(color)
	return mi


## A disc facing sideways (axis across the gun, Z), like a drum magazine.
func _zcyl(radius: float, width: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mi.mesh = mesh
	mi.rotation.x = deg_to_rad(90.0)
	mi.position = pos
	mi.material_override = _material(color)
	return mi


func _collect_aabb(node: Node, parent_xf: Transform3D, info: Dictionary) -> void:
	var xf: Transform3D = parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var local: AABB = (node as MeshInstance3D).get_aabb()
		if local.size.length() > 0.0:
			var box: AABB = xf * local
			if bool(info["has"]):
				var prev: AABB = info["box"]
				info["box"] = prev.merge(box)
			else:
				info["box"] = box
				info["has"] = true
	for c in node.get_children():
		_collect_aabb(c, xf, info)
