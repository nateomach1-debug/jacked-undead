extends Node
## Co-op sync. Everyone shares their position and downed state (capsules for
## the other players, lying flat when downed). The host also shares every
## zombie plus the round info; the other phones show "puppet" zombies that copy
## the host's, and report their hits back to the host. When every player is
## downed or dead, game over triggers on all phones. Created by net_manager.gd.

const SEND_INTERVAL: float = 1.0 / 15.0
const ZOMBIE_INTERVAL: float = 1.0 / 15.0
const ZOMBIE_SCENE: String = "res://scenes/zombies/zombie.tscn"
const RAGER_SCENE: String = "res://scenes/zombies/roid_rager.tscn"

var _local_player: Node3D
var _round_manager = null
var _remotes: Dictionary = {}         # peer id -> player capsule
var _targets: Dictionary = {}         # peer id -> {"pos", "yaw", "state", "bleed", "progress"}
var _puppets: Dictionary = {}         # zombie net id -> puppet zombie (non-host phones)
var _puppet_targets: Dictionary = {}  # zombie net id -> {"from_pos", "to_pos", "from_yaw", "to_yaw", "elapsed"}
var _timer: float = 0.0
var _zombie_timer: float = 0.0
var _next_zombie_id: int = 1
var _last_remaining: int = -1
var _last_total: int = -1
var _last_sent_state: int = -1
var _last_snapshot_time: float = 0.0
var _snapshot_interval: float = 0.1


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_left)


func setup(local_player: Node3D, round_manager = null) -> void:
	_local_player = local_player
	_round_manager = round_manager


func _physics_process(delta: float) -> void:
	if _local_player != null and is_instance_valid(_local_player):
		var state: int = _local_state()
		_timer -= delta
		# Send on a timer, and immediately whenever up/downed/dead changes.
		if _timer <= 0.0 or state != _last_sent_state:
			_timer = SEND_INTERVAL
			_last_sent_state = state
			_receive_state.rpc(
				_local_player.global_position,
				_local_player.rotation.y,
				state,
				float(_local_player.get("downed_bleed_left")),
				float(_local_player.get("downed_revive_progress"))
			)
		_check_everyone_out()
	if NetManager.is_host:
		_zombie_timer -= delta
		if _zombie_timer <= 0.0:
			_zombie_timer = ZOMBIE_INTERVAL
			_send_zombies()


# ---------- players ----------

## 0 = up, 1 = downed, 2 = dead (bled out).
func _local_state() -> int:
	if bool(_local_player.get("is_dead")):
		return 2
	if bool(_local_player.get("is_downed")):
		return 1
	return 0


@rpc("any_peer", "call_remote", "unreliable")
func _receive_state(pos: Vector3, yaw: float, state: int, bleed: float, progress: float) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if not _remotes.has(id):
		var capsule: Node3D = _make_remote(id)
		get_parent().add_child(capsule)
		capsule.global_position = pos
		_remotes[id] = capsule
	_targets[id] = {"pos": pos, "yaw": yaw, "state": state, "bleed": bleed, "progress": progress}
	var node: Node3D = _remotes[id]
	node.set_meta("downed", state == 1)
	node.set_meta("dead", state == 2)


## If this phone's player is downed/dead and so is everyone else, it's game over.
## It tells every other phone directly, so nobody misses it.
func _check_everyone_out() -> void:
	if GameManager.is_game_over or _remotes.is_empty():
		return
	if not (bool(_local_player.get("is_downed")) or bool(_local_player.get("is_dead"))):
		return
	for id in _remotes.keys():
		var target: Dictionary = _targets.get(id, {})
		if int(target.get("state", 0)) == 0:
			return
	_everyone_out.rpc()
	GameManager.report_player_death()


@rpc("any_peer", "call_remote", "reliable")
func _everyone_out() -> void:
	GameManager.report_player_death()


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
	root.set_meta("downed", false)
	root.set_meta("dead", false)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.from_hsv(fmod(float(id) * 0.37, 1.0), 0.7, 0.9)

	# Body and nose hang off a pivot so the whole body can tip over when downed.
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	capsule.material = mat
	body.mesh = capsule
	pivot.add_child(body)

	# Small box on the front so you can see which way they face.
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.2, 0.2, 0.5)
	box.material = mat
	nose.mesh = box
	nose.position = Vector3(0, 0.6, -0.45)
	pivot.add_child(nose)

	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = "HOST" if id == 1 else "P%d" % id
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.pixel_size = 0.01
	tag.font_size = 64
	tag.position = Vector3(0, 1.3, 0)
	root.add_child(tag)
	return root


func _tag_text(id: int, target: Dictionary) -> String:
	var base: String = "HOST" if id == 1 else "P%d" % id
	if int(target["state"]) == 1:
		if float(target["progress"]) > 0.0:
			return "%s\nREVIVING %.1f/5" % [base, float(target["progress"])]
		return "%s\nDOWNED %d" % [base, ceili(float(target["bleed"]))]
	return base


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

	# How long since the last snapshot: puppets glide to the new spot over that time.
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	_snapshot_interval = clampf(now - _last_snapshot_time, 0.03, 0.3)
	_last_snapshot_time = now

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
			_puppet_targets[id] = {
				"from_pos": positions[i], "to_pos": positions[i],
				"from_yaw": yaws[i], "to_yaw": yaws[i], "elapsed": 0.0
			}
		else:
			_puppet_targets[id] = {
				"from_pos": puppet.global_position, "to_pos": positions[i],
				"from_yaw": puppet.rotation.y, "to_yaw": yaws[i], "elapsed": 0.0
			}

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
		var state: int = int(target["state"])
		node.global_position = node.global_position.lerp(target["pos"], t)
		node.rotation.y = lerp_angle(node.rotation.y, float(target["yaw"]), t)
		node.visible = state != 2  # bled-out players are hidden (they spectate)
		var pivot := node.get_node_or_null("Pivot") as Node3D
		if pivot != null:
			pivot.rotation.x = lerp_angle(pivot.rotation.x, -PI * 0.5 if state == 1 else 0.0, t)
			pivot.position.y = lerpf(pivot.position.y, -0.5 if state == 1 else 0.0, t)
		var tag := node.get_node_or_null("Tag") as Label3D
		if tag != null:
			tag.text = _tag_text(id, target)
			tag.position.y = lerpf(tag.position.y, 0.8 if state == 1 else 1.3, t)

	# Puppet zombies glide in a straight line to the host's latest position.
	for id in _puppets.keys():
		var z = _puppets[id]
		if z == null or not is_instance_valid(z) or not _puppet_targets.has(id):
			continue
		var tgt: Dictionary = _puppet_targets[id]
		tgt["elapsed"] = float(tgt["elapsed"]) + delta
		var a: float = clampf(float(tgt["elapsed"]) / _snapshot_interval, 0.0, 1.0)
		var from_pos: Vector3 = tgt["from_pos"]
		var to_pos: Vector3 = tgt["to_pos"]
		z.global_position = from_pos.lerp(to_pos, a)
		z.rotation.y = lerp_angle(float(tgt["from_yaw"]), float(tgt["to_yaw"]), a)
