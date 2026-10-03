extends RefCounted
## Character list and model loader (used by the options picker and CoopSync).

const DIR: String = "res://resources/models/characters/"
const CHARACTERS: Array = [
	{"id": "Adventurer", "title": "ADVENTURER"},
	{"id": "Beach", "title": "BEACH"},
	{"id": "Casual_2", "title": "CASUAL"},
	{"id": "Casual_Hoodie", "title": "HOODIE"},
	{"id": "Farmer", "title": "FARMER"},
	{"id": "Punk", "title": "PUNK"},
	{"id": "Spacesuit", "title": "SPACESUIT"},
	{"id": "Suit", "title": "SUIT"},
	{"id": "Swat", "title": "SWAT"},
	{"id": "Worker", "title": "WORKER"},
]


func count() -> int:
	return CHARACTERS.size()


func id_at(i: int) -> String:
	return str(CHARACTERS[posmod(i, CHARACTERS.size())]["id"])


func title_at(i: int) -> String:
	return str(CHARACTERS[posmod(i, CHARACTERS.size())]["title"])


func index_of(id: String) -> int:
	for i in range(CHARACTERS.size()):
		if str(CHARACTERS[i]["id"]) == id:
			return i
	return 0


func has_id(id: String) -> bool:
	for c in CHARACTERS:
		if str(c["id"]) == id:
			return true
	return false


## Loads a character, scales it to target_height, puts its feet at y = 0 and
## faces it -Z (same as a player). Returns null if anything goes wrong.
func build_fitted(id: String, target_height: float) -> Node3D:
	if not has_id(id):
		return null
	var scene = load(DIR + id + ".gltf")
	if scene == null or not (scene is PackedScene):
		return null
	var model := (scene as PackedScene).instantiate() as Node3D
	if model == null:
		return null
	var info: Dictionary = {"has": false, "box": AABB()}
	_collect_aabb(model, Transform3D.IDENTITY, info)
	if not bool(info["has"]):
		model.queue_free()
		return null
	var box: AABB = info["box"]
	if box.size.y < 0.01:
		model.queue_free()
		return null
	model.position += Vector3(-(box.position.x + box.size.x * 0.5), -box.position.y, -(box.position.z + box.size.z * 0.5))
	var fit := Node3D.new()
	var s: float = target_height / box.size.y
	fit.scale = Vector3(s, s, s)
	fit.add_child(model)
	var holder := Node3D.new()
	holder.rotation.y = PI  # glTF models face +Z; players face -Z
	holder.add_child(fit)
	return holder


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
