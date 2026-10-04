extends RefCounted
## Badge visual effects: muzzle flash, aura at the feet, and effect lookups.
## Loaded with load() + a null check.

const BADGES_PATH: String = "res://scripts/managers/badges.gd"
const AURA_Y: float = -0.88   # just above the feet of a remote player

var _reg = null
var _tried: bool = false


func _badges():
	if not _tried:
		_tried = true
		var script = load(BADGES_PATH)
		if script != null:
			_reg = script.new()
	return _reg


## The badge's color if it has the wanted effect ("flash", "aura", "hit"),
## otherwise a fully transparent color (alpha 0).
func effect_color(badge_id: String, wanted: String) -> Color:
	var reg = _badges()
	if reg == null or badge_id == "" or not reg.has_badge(badge_id):
		return Color(0, 0, 0, 0)
	if reg.effect(badge_id) != wanted:
		return Color(0, 0, 0, 0)
	return reg.color(badge_id)


## A very short tinted flash (light + glowing ball) at `pos`, relative to `parent`.
func flash(parent: Node3D, pos: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	root.position = pos

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 4.0
	light.shadow_enabled = false
	root.add_child(light)

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	sphere.material = mat
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)

	parent.add_child(root)
	parent.get_tree().create_timer(0.06).timeout.connect(root.queue_free)


## A soft glowing disc to put under a player's feet.
func make_aura(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Aura"
	root.position = Vector3(0.0, AURA_Y, 0.0)

	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.9
	cyl.height = 0.02
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
	cyl.material = mat
	disc.mesh = cyl
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 3.5
	light.position = Vector3(0.0, 0.3, 0.0)
	light.shadow_enabled = false
	root.add_child(light)
	return root
