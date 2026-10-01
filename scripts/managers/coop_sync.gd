extends Node
## Co-op sync. Everyone shares their position (capsules for the other players).
## The host also shares every zombie plus the round info; the other phones
## show "puppet" zombies that copy the host's, and report their hits back to
## the host. Created by main.gd online only.

const SEND_INTERVAL: float = 1.0 / 15.0
const ZOMBIE_INTERVAL: float = 1.0 / 10.0
const ZOMBIE_SCENE: String = "res://scenes/zombies/zombie.tscn"
const RAGER_SCENE: String = "res://scenes/zombies/roid_rager.tscn"

var _local_player: Node3D
var _round_manager = null
var _remotes: Dictionary = {}         # peer id -> player capsule
var _targets: Dictionary = {}         # peer id -> {"pos", "yaw"}
var _puppets: Dictionary = {}         # zombie net id -> puppet zombie (non-host phones)
var _puppet_targets: Dictionary = {}  # zombie net id -> {"pos", "yaw"}
var _timer: float = 0.0
var _zombie_timer: float = 0.0
var _next_zombie_id: int = 1
var _last_remaining: int = -1
var _last_total: int = -1


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)


func setup(local_player: Node3D, round_manager = null) -> void:
	_local_player = local_player
	_round_manager = round_manager


func _physics_process(delta: float) -> void:
	if _local_player != null and is_instance_valid(_local_player):
		_timer -= delta
		if _timer <= 0.0:
			_timer = SEND_INTERVAL
			_receive_state.rpc(_local_player.global_position, _local_player.rotation.y)
	if NetManager.is_host:
		_zombie_timer -= delta
		if _zombie_timer <= 0.0:
			_zombie_timer = ZOMBIE_INTERVAL
			_send_zombies()


# ---------- players ----------

@rpc("any_peer", "call_remote", "unreliable")
func _receive_state(pos: Vector3, yaw: float) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if not _remotes.has(id):
		var capsule: Node3D = _make_remote(id)
		get_parent().add_child(capsule)
		capsule.global_position = pos
		_remotes[id] = capsule
	_targets[id] = {"pos": pos, "yaw": yaw}


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
	# Zombies on the host chase these and damage the phone that owns them.
	root.add_to_group("remote_players")
	root.set_meta("peer_id", id)

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


# ---------- zombies ----------

## Host: packs every live zombie and the round info into one message.
func _send_zombies() -> void:
	var ids := PackedInt32Array()
	var kinds := PackedInt32Array()
	var positions := PackedVector3Array()
	var yaws := PackedFloat32Array()
	for n in get_tree().get_nodes_in_group("zombies"):
		var z := n as Node3D
		if z == null or not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		if not z.has_meta("net_id"):
			z.set_meta("net_id", _next_zombie_id)
			_next_zombie_id += 1
		var is_rager: bool = z.scene_file_path == RAGER_SCENE or float(z.get("max_health")) >= 250.0
		ids.append(int(z.get_meta("net_id")))
		kinds.append(1 if is_rager else 0)
		positions.append(z.global_position)
		yaws.append(z.rotation.y)

	var remaining: int = 0
	var total: int = 0
	if _round_manager != null:
		remaining = _round_manager.get_zombies_remaining()
		total = _round_manager.get_zombies_total()
	_receive_zombies.rpc(ids, kinds, positions, yaws, GameManager.round_number, remaining, total)


## Other phones: create / move / remove puppet zombies, update round + counter.
@rpc("authority", "call_remote", "unreliable")
func _receive_zombies(ids: PackedInt32Array, kinds: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array, round_num: int, remaining: int, total: int) -> void:
	if GameManager.round_number != round_num:
		GameManager.round_number = round_num
		GameManager.round_changed.emit(round_num)
	if _round_manager != null and (remaining != _last_remaining or total != _last_total):
		_last_remaining = remaining
		_last_total = total
		_round_manager.zombies_changed.emit(remaining, total)

	var alive: Dictionary = {}
	for i in range(ids.size()):
		var id: int = ids[i]
		alive[id] = true
		var puppet = _puppets.get(id)
		if puppet == null or not is_instance_valid(puppet):
			puppet = _make_puppet(kinds[i], positions[i], id)
			if puppet == null:
				continue
			_puppets[id] = puppet
		_puppet_targets[id] = {"pos": positions[i], "yaw": yaws[i]}

	for id in _puppets.keys():
		if not alive.has(id):
			var node = _puppets[id]
			if node != null and is_instance_valid(node):
				node.queue_free()
			_puppets.erase(id)
			_puppet_targets.erase(id)


func _make_puppet(kind: int, at: Vector3, net_id: int):
	var scene = load(RAGER_SCENE if kind == 1 else ZOMBIE_SCENE)
	if scene == null:
		return null
	var z = scene.instantiate()
	z.is_puppet = true
	z.set_meta("net_id", net_id)
	z.collision_layer = 4  # shootable: shots at it are forwarded to the host
	z.collision_mask = 0
	z.set_physics_process(false)
	get_parent().add_child(z)
	z.global_position = at
	return z


# ---------- shooting ----------

## Called by a puppet zombie on a non-host phone when this player hits it.
func send_hit(net_id: int, amount: float, headshot: bool) -> void:
	if NetManager.is_online and not NetManager.is_host:
		_zombie_hit.rpc_id(1, net_id, amount, headshot)


## Host: applies a hit reported by another phone to the real zombie.
@rpc("any_peer", "call_remote", "reliable")
func _zombie_hit(net_id: int, amount: float, headshot: bool) -> void:
	if not NetManager.is_host:
		return
	var shooter = _remotes.get(multiplayer.get_remote_sender_id())
	for n in get_tree().get_nodes_in_group("zombies"):
		if is_instance_valid(n) and n.has_meta("net_id") and int(n.get_meta("net_id")) == net_id:
			n.take_damage(amount, shooter, headshot)
			return


# ---------- smoothing ----------

func _process(delta: float) -> void:
	var t: float = clampf(delta * 15.0, 0.0, 1.0)
	for id in _remotes.keys():
		var node: Node3D = _remotes[id]
		if node == null or not is_instance_valid(node) or not _targets.has(id):
			continue
		var target: Dictionary = _targets[id]
		node.global_position = node.global_position.lerp(target["pos"], t)
		node.rotation.y = lerp_angle(node.rotation.y, float(target["yaw"]), t)

	var tz: float = clampf(delta * 12.0, 0.0, 1.0)
	for id in _puppets.keys():
		var z = _puppets[id]
		if z == null or not is_instance_valid(z) or not _puppet_targets.has(id):
			continue
		var tgt: Dictionary = _puppet_targets[id]
		z.global_position = z.global_position.lerp(tgt["pos"], tz)
		z.rotation.y = lerp_angle(z.rotation.y, float(tgt["yaw"]), tz)
