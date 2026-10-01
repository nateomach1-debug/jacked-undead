extends Node
## Co-op step 2: shares each player's position so everyone sees capsules
## for the other players. Created by main.gd only when playing online.

const SEND_INTERVAL: float = 1.0 / 15.0

var _local_player: Node3D
var _remotes: Dictionary = {}   # peer id -> capsule node
var _targets: Dictionary = {}   # peer id -> {"pos": Vector3, "yaw": float}
var _timer: float = 0.0


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)


func setup(local_player: Node3D) -> void:
	_local_player = local_player


func _physics_process(delta: float) -> void:
	if _local_player == null or not is_instance_valid(_local_player):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SEND_INTERVAL
	_receive_state.rpc(_local_player.global_position, _local_player.rotation.y)


@rpc("any_peer", "call_remote", "unreliable")
func _receive_state(pos: Vector3, yaw: float) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if not _remotes.has(id):
		var capsule: Node3D = _make_remote(id)
		get_parent().add_child(capsule)
		capsule.global_position = pos
		_remotes[id] = capsule
	_targets[id] = {"pos": pos, "yaw": yaw}


func _process(delta: float) -> void:
	var t: float = clampf(delta * 15.0, 0.0, 1.0)
	for id in _remotes.keys():
		var node: Node3D = _remotes[id]
		if node == null or not is_instance_valid(node) or not _targets.has(id):
			continue
		var target: Dictionary = _targets[id]
		node.global_position = node.global_position.lerp(target["pos"], t)
		node.rotation.y = lerp_angle(node.rotation.y, float(target["yaw"]), t)


func _on_peer_left(id: int) -> void:
	if _remotes.has(id):
		var node: Node3D = _remotes[id]
		if node != null and is_instance_valid(node):
			node.queue_free()
		_remotes.erase(id)
		_targets.erase(id)


func _make_remote(id: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Remote_%d" % id

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(float(id) * 0.37, 1.0), 0.7, 0.9)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	capsule.material = mat
	body.mesh = capsule
	root.add_child(body)

	# Small box on the front so you can see which way they face.
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.5)
	box.material = mat
	nose.mesh = box
	nose.position = Vector3(0, 0.6, -0.45)
	root.add_child(nose)

	var tag := Label3D.new()
	tag.text = "HOST" if id == 1 else "P%d" % id
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.pixel_size = 0.01
	tag.font_size = 64
	tag.position = Vector3(0, 1.3, 0)
	root.add_child(tag)
	return root
