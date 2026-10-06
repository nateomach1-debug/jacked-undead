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
    NetManager.character_changed.connect(_on_character_changed)
    NetManager.badge_changed.connect(_on_badge_changed)


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
        _send_gun_if_changed()
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
        _apply_gun(id)
        _last_gun_key = ""
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
    _apply_aura(root, id)
    return _with_character(root, id)


func _tag_text(id: int, target: Dictionary) -> String:
    var base: String = _badge_prefix(id) + NetManager.get_player_name(id)
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

const CHAR_HEIGHT: float = 1.8
const CHAR_FOOT_Y: float = -0.9   # feet height relative to the player's position

var _registry = null


func _get_registry():
    if _registry == null:
        var script = load("res://scripts/managers/character_registry.gd")
        if script != null:
            _registry = script.new()
    return _registry


func _with_character(root: Node3D, id: int) -> Node3D:
    _apply_character(root, NetManager.get_character(id))
    return root


## Swaps the capsule for the chosen model (falls back to the capsule if it can't load).
func _apply_character(root: Node3D, char_id: String) -> void:
    var pivot := root.get_node_or_null("Pivot") as Node3D
    if pivot == null:
        return
    var old := pivot.get_node_or_null("CharModel")
    if old != null:
        pivot.remove_child(old)
        old.queue_free()
    var model: Node3D = null
    var reg = _get_registry()
    if reg != null and char_id != "":
        model = reg.build_fitted(char_id, CHAR_HEIGHT)
    if model != null:
        model.name = "CharModel"
        model.position = Vector3(0.0, CHAR_FOOT_Y, 0.0)
        pivot.add_child(model)
    for c in pivot.get_children():
        if c is MeshInstance3D:
            (c as MeshInstance3D).visible = model == null


func _on_character_changed(peer_id: int) -> void:
    var node = _remotes.get(peer_id)
    if node != null and is_instance_valid(node):
        _apply_character(node, NetManager.get_character(peer_id))


## Small walking bob while a remote player is moving (the models have no animations).
func _bob_remote(node: Node3D, target: Dictionary, state: int) -> void:
    var pivot := node.get_node_or_null("Pivot") as Node3D
    if pivot == null:
        return
    var model := pivot.get_node_or_null("CharModel") as Node3D
    if model == null:
        return
    var moving: bool = state == 0 and node.global_position.distance_to(target["pos"]) > 0.08
    var secs: float = float(Time.get_ticks_msec()) / 1000.0
    var bob: float = absf(sin(secs * 10.0)) * 0.07 if moving else 0.0
    model.position.y = lerpf(model.position.y, CHAR_FOOT_Y + bob, 0.4)


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
        _bob_remote(node, target, state)
        var tag := node.get_node_or_null("Tag") as Label3D
        if tag != null:
            tag.text = _tag_text(id, target)
            _style_tag(tag, id)
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


# ---------- badges ----------

var _badge_reg = null
var _badge_reg_tried: bool = false


func _get_badges():
    if not _badge_reg_tried:
        _badge_reg_tried = true
        var script = load("res://scripts/managers/badges.gd")
        if script != null:
            _badge_reg = script.new()
    return _badge_reg


## The badge icon in front of a player's name ("" if none).
func _badge_prefix(id: int) -> String:
    var reg = _get_badges()
    var b: String = NetManager.get_badge(id)
    if reg == null or b == "" or not reg.has_badge(b):
        return ""
    return reg.icon(b) + " "


## Colors a player's name tag with their badge color (rainbow badges cycle).
func _style_tag(tag: Label3D, id: int) -> void:
    var reg = _get_badges()
    var b: String = NetManager.get_badge(id)
    if reg == null or b == "" or not reg.has_badge(b):
        tag.modulate = Color(1, 1, 1)
        return
    if reg.is_rainbow(b):
        var hue: float = fmod(float(Time.get_ticks_msec()) / 1000.0 * 0.4, 1.0)
        tag.modulate = Color.from_hsv(hue, 0.7, 1.0)
    else:
        tag.modulate = reg.color(b)


# ---------- badge effects ----------

const REMOTE_FLASH_POS: Vector3 = Vector3(0.25, 0.35, -0.9)   # in front of a remote player

var _badge_fx = null
var _badge_fx_tried: bool = false


func _get_badge_fx():
    if not _badge_fx_tried:
        _badge_fx_tried = true
        var script = load("res://scripts/effects/badge_effects.gd")
        if script != null:
            _badge_fx = script.new()
    return _badge_fx


## Adds (or removes) the glowing aura under a remote player to match their badge.
func _apply_aura(root: Node3D, id: int) -> void:
    var old := root.get_node_or_null("Aura")
    if old != null:
        root.remove_child(old)
        old.queue_free()
    var fx = _get_badge_fx()
    if fx == null:
        return
    var color: Color = fx.effect_color(NetManager.get_badge(id), "aura")
    if color.a <= 0.0:
        return
    root.add_child(fx.make_aura(color))


func _on_badge_changed(peer_id: int) -> void:
    var node = _remotes.get(peer_id)
    if node != null and is_instance_valid(node):
        _apply_aura(node, peer_id)


## Called by my player when it fires with a flash badge equipped.
func send_shot() -> void:
    if NetManager.is_online:
        _remote_shot.rpc()


@rpc("any_peer", "call_remote", "unreliable")
func _remote_shot() -> void:
    var id: int = multiplayer.get_remote_sender_id()
    var node = _remotes.get(id)
    if node == null or not is_instance_valid(node):
        return
    var fx = _get_badge_fx()
    if fx == null:
        return
    var color: Color = fx.effect_color(NetManager.get_badge(id), "flash")
    if color.a <= 0.0:
        return
    fx.flash(node, REMOTE_FLASH_POS, color)


# ---------- held guns ----------

const GUN_HAND_POS: Vector3 = Vector3(0.3, 0.15, -0.4)   # relative to the remote's Pivot; tune if off

var _guns: Dictionary = {}       # peer id -> {"name": base gun name, "loadout": {slot: attachment id}}
var _last_gun_key: String = ""
var _attach_builder = null
var _attach_builder_tried: bool = false


## Sends my current gun + attachments whenever they change.
func _send_gun_if_changed() -> void:
    var w = _local_player.get("current_weapon")
    if w == null:
        return
    var loadout: Dictionary = {}
    var raw = w.get_meta("attachments", {})
    if raw is Dictionary:
        for k in raw.keys():
            loadout[str(k)] = str(raw[k])
    var gun_name: String = str(w.get_base_name())
    var key: String = gun_name + str(loadout)
    if key == _last_gun_key:
        return
    _last_gun_key = key
    _receive_gun.rpc(gun_name, loadout)


@rpc("any_peer", "call_remote", "reliable")
func _receive_gun(gun_name: String, loadout: Dictionary) -> void:
    var id: int = multiplayer.get_remote_sender_id()
    _guns[id] = {"name": gun_name, "loadout": loadout}
    _apply_gun(id)


func _get_attach_builder():
    if not _attach_builder_tried:
        _attach_builder_tried = true
        var script = load("res://scripts/weapons/attachment_models.gd")
        if script != null:
            _attach_builder = script.new()
    return _attach_builder


## Builds the gun model like the first-person one: .tres guns first, else the placeholder builder.
func _build_gun_model(gun_name: String) -> Dictionary:
    var path: String = "res://resources/weapons/%s.tres" % gun_name.to_lower()
    if ResourceLoader.exists(path):
        var res = load(path)
        if res != null:
            var m = res.create_model()
            if m != null:
                return {"model": m, "is_scene": res.model_scene != null}
    var gun_models = load("res://scripts/weapons/gun_models.gd")
    if gun_models != null:
        var m2 = gun_models.build(gun_name)
        if m2 != null:
            return {"model": m2, "is_scene": false}
    return {}


## Puts (or removes) the held gun on a remote player's pivot.
func _apply_gun(id: int) -> void:
    var root = _remotes.get(id)
    if root == null or not is_instance_valid(root):
        return
    var pivot := root.get_node_or_null("Pivot") as Node3D
    if pivot == null:
        return
    var old := pivot.get_node_or_null("HeldGun")
    if old != null:
        pivot.remove_child(old)
        old.queue_free()
    var info: Dictionary = _guns.get(id, {})
    if info.is_empty():
        return
    var built: Dictionary = _build_gun_model(str(info["name"]))
    if built.is_empty():
        return
    var model: Node3D = built["model"]
    var mount := Node3D.new()
    mount.name = "HeldGun"
    mount.position = GUN_HAND_POS
    # Same mount rotation as my first-person gun (gun points along +X in mount space).
    var wm = _local_player.get("weapon_mount") if _local_player != null else null
    if wm is Node3D:
        mount.basis = (wm as Node3D).transform.basis
    else:
        mount.basis = Basis(Vector3.UP, PI * 0.5)
    if not bool(built["is_scene"]):
        model.transform.basis = mount.basis.orthonormalized().inverse()
    mount.add_child(model)
    var builder = _get_attach_builder()
    var loadout = info.get("loadout", {})
    if builder != null and loadout is Dictionary and not loadout.is_empty():
        var att: Node3D = builder.build_for(model, loadout, str(info["name"]))
        if att != null:
            mount.add_child(att)
    pivot.add_child(mount)
