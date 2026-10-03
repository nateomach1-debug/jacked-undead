extends RefCounted
## Procedural attachment graphics, sized from the gun they sit on.
## Mount space: the gun points along +X, up is +Y.

const DARK: Color = Color(0.10, 0.10, 0.12)
const STEEL: Color = Color(0.35, 0.36, 0.40)
const ORANGE: Color = Color(0.95, 0.5, 0.1)
const RED: Color = Color(1.0, 0.1, 0.1)

# Where each slot sits on the gun's box: x = 0 rear .. 1 muzzle, y = 0 bottom .. 1 top.
const ANCHORS: Dictionary = {
	"optic": Vector2(0.45, 1.0),
	"barrel": Vector2(1.0, 0.62),
	"magazine": Vector2(0.40, 0.30),
	"grip": Vector2(0.75, 0.25),
}
# Per-gun tweaks after checking screenshots, e.g. {"Rifle": {"optic": Vector2(0.5, 1.0)}}
const OVERRIDES: Dictionary = {}


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
		"scope_4x":
			n.add_child(_cyl(0.032 * s, 0.30 * s, Vector3(0, 0.07, 0) * s, DARK))
			n.add_child(_cyl(0.042 * s, 0.06 * s, Vector3(0.15, 0.07, 0) * s, STEEL))
			n.add_child(_cyl(0.038 * s, 0.05 * s, Vector3(-0.15, 0.07, 0) * s, STEEL))
			n.add_child(_box(Vector3(0.04, 0.05, 0.03) * s, Vector3(0.08, 0.025, 0) * s, STEEL))
			n.add_child(_box(Vector3(0.04, 0.05, 0.03) * s, Vector3(-0.08, 0.025, 0) * s, STEEL))
		"long_barrel":
			n.add_child(_cyl(0.018 * s, 0.22 * s, Vector3(0.11, 0, 0) * s, STEEL))
		"suppressor":
			n.add_child(_cyl(0.032 * s, 0.20 * s, Vector3(0.10, 0, 0) * s, DARK))
			n.add_child(_cyl(0.034 * s, 0.015 * s, Vector3(0.20, 0, 0) * s, STEEL))
		"ext_mag":
			n.add_child(_box(Vector3(0.07, 0.26, 0.05) * s, Vector3(0, -0.13, 0) * s, DARK))
			n.add_child(_box(Vector3(0.072, 0.02, 0.052) * s, Vector3(0, -0.25, 0) * s, STEEL))
		"fast_mag":
			n.add_child(_box(Vector3(0.07, 0.20, 0.05) * s, Vector3(0, -0.10, 0) * s, ORANGE))
		"foregrip":
			n.add_child(_vcyl(0.022 * s, 0.14 * s, Vector3(0, -0.07, 0) * s, DARK))
		"angled_grip":
			var grip := _box(Vector3(0.05, 0.13, 0.04) * s, Vector3(0.03, -0.065, 0) * s, DARK)
			grip.rotation.z = deg_to_rad(-25.0)
			n.add_child(grip)
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
