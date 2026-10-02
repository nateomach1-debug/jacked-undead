extends Area3D
## Buyable door / barricade. It blocks the way until the player buys it with
## Gains, then it disappears and unlocks the listed zones (spawn points tagged
## with metadata "zone" start spawning there). On the Building map the nav
## baker rebakes so zombies can path through the opening.
## Co-op: buying it tells the other phones, so it opens for everyone.
##
## The door's origin is the CENTER OF ITS BASE on the floor. Width is along
## local X, thickness along local Z. For a door in a wall that runs along the
## Z axis, use size = Vector3(0.4, 3, 4) instead of rotating it.

@export var size: Vector3 = Vector3(4.0, 3.0, 0.4)
@export var cost: int = 1250
@export var display_name: String = "Door"
@export var unlocks_zones: PackedStringArray = PackedStringArray()
@export var color: Color = Color(0.45, 0.3, 0.15, 1.0)

var _opened: bool = false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	add_to_group("navmesh_source")  # the nav bake treats the closed door as a wall

	# Interact zone: same size as the door, a hair thicker so the USE ray hits it first.
	var zone_shape := CollisionShape3D.new()
	var zone_box := BoxShape3D.new()
	zone_box.size = Vector3(size.x, size.y, size.z + 0.3)
	zone_shape.shape = zone_box
	zone_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	add_child(zone_shape)

	# Solid part that blocks the player and zombies.
	var body := StaticBody3D.new()
	add_child(body)
	var body_shape := CollisionShape3D.new()
	var body_box := BoxShape3D.new()
	body_box.size = size
	body_shape.shape = body_box
	body_shape.position = Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(body_shape)

	var mesh_node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_node.material_override = mat
	mesh_node.position = Vector3(0.0, size.y * 0.5, 0.0)
	body.add_child(mesh_node)


func interact(_player: Node) -> void:
	if _opened:
		return
	if not GameManager.try_spend_gains(cost):
		return
	_opened = true
	NetManager.announce_door_opened(get_path())
	GameManager.open_barrier(unlocks_zones)
	queue_free()


## Co-op: another phone bought this door, so open it here without charging.
func remote_open() -> void:
	if _opened:
		return
	_opened = true
	GameManager.open_barrier(unlocks_zones)
	queue_free()


func get_prompt_text() -> String:
	return "Tap USE to open %s - %d Gains" % [display_name, cost]


func get_prompt_color() -> Color:
	return Color(1.0, 0.85, 0.3, 1.0)
