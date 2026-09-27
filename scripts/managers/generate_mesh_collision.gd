extends Node
## Attach as a sibling of imported level art. On load, walks every node
## under target_path and generates real trimesh collision from each
## visual mesh -- so imported building/level geometry gets accurate
## collision without hand-built shapes for geometry we can't inspect.

@export var target_path: NodePath = ".."


func _ready() -> void:
	var target: Node = get_node(target_path)
	if target:
		_generate_for(target)


func _generate_for(node: Node) -> void:
	if node is MeshInstance3D:
		node.create_trimesh_collision()
	for child in node.get_children():
		_generate_for(child)
