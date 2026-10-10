extends Node
## MembershipHub (autoload): places the membership counter on co-op maps and
## handles Gains transfers between players (host-authoritative).

const COUNTER_SCRIPT: String = "res://scripts/stations/membership_counter.gd"
const MENU_SCRIPT: String = "res://scripts/ui/membership_menu.gd"
const SPOT_RADIUS: float = 4.5
const CHECK_INTERVAL: float = 1.0

const MIN_TRANSFER: int = 100
const MAX_TRANSFER: int = 1000000
const TRANSFER_FEE: float = 0.0     # 0.1 = 10% "membership fee" is lost on every transfer
const COOLDOWN: float = 3.0         # seconds between transfers
const COMBAT_LOCK: float = 10.0     # no transfers for this long after taking damage
const CLOSE_DISTANCE: float = 4.0   # menu closes if you walk this far from the counter
const INFO_INTERVAL: float = 1.5

# Optional fixed spots per map file, local to the supplement stations' parent:
# "main.tscn": [Vector3(x, y, z), yaw_degrees]
# Leave empty to auto-place beside the first supplement station.
const MAP_SPOTS: Dictionary = {}

var gains_given: int = 0            # Gains this player sent this run (for a scoreboard later)
var peer_info: Dictionary = {}      # peer id -> {"gains", "standing"} shared by every phone

var _timer: float = 0.0
var _info_timer: float = 0.0
var _placed_scene: Node = null
var _hooked: Node = null
var _last_hp: float = -1.0
var _last_hit_msec: int = -100000
var _last_send_msec: int = -100000
var _host_last: Dictionary = {}     # host only: sender id -> last accepted transfer time
var _menu: Node = null
var _menu_counter: Node3D = null
var _toast_label: Label = null
var _toast_tween: Tween = null


func _ready() -> void:
    _build_toast()
    multiplayer.peer_disconnected.connect(_on_peer_left)


func _on_peer_left(id: int) -> void:
    peer_info.erase(id)
    _host_last.erase(id)


func _process(delta: float) -> void:
    if not NetManager.is_online:
        if _menu != null:
            close_menu("")
        return
    _hook_player()
    _info_timer += delta
    if _info_timer >= INFO_INTERVAL:
        _info_timer = 0.0
        _share_info.rpc(GameManager.gains, _local_standing())
    _watch_menu()
    _timer += delta
    if _timer < CHECK_INTERVAL:
        return
    _timer = 0.0
    var scene: Node = get_tree().current_scene
    if scene == null or scene == _placed_scene:
        return
    if not scene.has_node("CoopSync"):
        return
    var station := get_tree().get_first_node_in_group("supplement_station") as Node3D
    if station == null or not scene.is_ancestor_of(station):
        return
    _placed_scene = scene
    gains_given = 0
    _place_counter(scene, station)


# ---------- placing the counter ----------

func _place_counter(scene: Node, station: Node3D) -> void:
    var script = load(COUNTER_SCRIPT)
    if script == null:
        push_warning("membership_counter.gd is missing or broken.")
        return
    var parent: Node = station.get_parent()
    if parent == null or not (parent is Node3D):
        return
    var counter := Area3D.new()
    counter.set_script(script)
    counter.name = "MembershipCounter"
    parent.add_child(counter)

    var file: String = scene.scene_file_path.get_file()
    if MAP_SPOTS.has(file):
        var spot: Array = MAP_SPOTS[file]
        counter.position = spot[0]
        counter.rotation_degrees.y = float(spot[1])
        return

    var pos: Vector3 = _find_spot(station)
    if pos == Vector3.INF:
        push_warning("Membership counter: no clear spot, using fallback.")
        pos = station.global_position + Vector3(SPOT_RADIUS, -0.9, 0.0)
    counter.global_position = pos
    var to_station: Vector3 = station.global_position - pos
    counter.global_rotation = Vector3(0.0, atan2(to_station.x, to_station.z), 0.0)


func _find_spot(station: Node3D) -> Vector3:
    var base: Vector3 = station.global_position
    base.y -= 0.9   # supplement stations are centered 0.9 m above the floor
    for k in range(16):
        var ang: float = float(k) * TAU / 16.0
        var pos: Vector3 = base + Vector3(cos(ang), 0.0, sin(ang)) * SPOT_RADIUS
        if _is_clear(station, pos):
            return pos
    return Vector3.INF


func _is_clear(station: Node3D, pos: Vector3) -> bool:
    var space: PhysicsDirectSpaceState3D = station.get_world_3d().direct_space_state
    var shape := SphereShape3D.new()
    shape.radius = 0.5
    var offsets: Array = [Vector3.ZERO, Vector3(1.1, 0, 0), Vector3(-1.1, 0, 0), Vector3(0, 0, 1.1), Vector3(0, 0, -1.1)]
    for off in offsets:
        var q := PhysicsShapeQueryParameters3D.new()
        q.shape = shape
        q.transform = Transform3D(Basis.IDENTITY, pos + off + Vector3(0.0, 1.0, 0.0))
        q.collision_mask = 1
        if not space.intersect_shape(q, 1).is_empty():
            return false
    var ray := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -3.0, 0.0), 1)
    return not space.intersect_ray(ray).is_empty()


# ---------- local player state ----------

func _local_standing() -> bool:
    var p: Node = get_tree().get_first_node_in_group("player")
    if p == null:
        return false
    return not (bool(p.get("is_downed")) or bool(p.get("is_dead")))


func _hook_player() -> void:
    if _hooked != null and not is_instance_valid(_hooked):
        _hooked = null
    var p: Node = get_tree().get_first_node_in_group("player")
    if p == null or p == _hooked:
        return
    _hooked = p
    _last_hp = -1.0
    if p.has_signal("health_changed"):
        p.connect("health_changed", _on_health_changed)


## Any drop in health starts the combat lock and closes the menu.
func _on_health_changed(current: float, _max_hp: float) -> void:
    if _last_hp >= 0.0 and current < _last_hp - 0.01:
        _last_hit_msec = Time.get_ticks_msec()
        if _menu != null:
            close_menu("You were hit")
    _last_hp = current


## Empty string = this player may send right now, otherwise the reason why not.
func can_send() -> String:
    if not NetManager.is_online:
        return "Not in a co-op game"
    if not _local_standing():
        return "You can't do that while downed"
    var now: int = Time.get_ticks_msec()
    var since_hit: float = float(now - _last_hit_msec) / 1000.0
    if since_hit < COMBAT_LOCK:
        return "Hit recently - wait %d s" % ceili(COMBAT_LOCK - since_hit)
    var since_send: float = float(now - _last_send_msec) / 1000.0
    if since_send < COOLDOWN:
        return "Wait %d s" % ceili(COOLDOWN - since_send)
    return ""


# ---------- teammates ----------

func _is_standing(id: int) -> bool:
    if id == multiplayer.get_unique_id():
        return _local_standing()
    for n in get_tree().get_nodes_in_group("remote_players"):
        if int(n.get_meta("peer_id", 0)) == id:
            return not (bool(n.get_meta("downed", false)) or bool(n.get_meta("dead", false)))
    var info: Dictionary = peer_info.get(id, {})
    return bool(info.get("standing", true))


## Everyone else in the game: [{"id", "name", "gains" (-1 = unknown), "standing"}].
func get_targets() -> Array:
    var out: Array = []
    if not NetManager.is_online:
        return out
    var me: int = multiplayer.get_unique_id()
    var ids: Array = Array(multiplayer.get_peers())
    if me != 1 and not ids.has(1):
        ids.append(1)
    for id in ids:
        var pid: int = int(id)
        if pid == me:
            continue
        var info: Dictionary = peer_info.get(pid, {})
        out.append({
            "id": pid,
            "name": NetManager.get_player_name(pid),
            "gains": int(info.get("gains", -1)),
            "standing": _is_standing(pid),
        })
    out.sort_custom(func(a, b): return int(a["id"]) < int(b["id"]))
    return out


@rpc("any_peer", "call_remote", "unreliable")
func _share_info(gains: int, standing: bool) -> void:
    peer_info[multiplayer.get_remote_sender_id()] = {"gains": gains, "standing": standing}


# ---------- menu ----------

func open_menu(counter: Node3D) -> void:
    if _menu != null and is_instance_valid(_menu):
        return
    if not NetManager.is_online:
        return
    var script = load(MENU_SCRIPT)
    if script == null:
        push_warning("membership_menu.gd is missing or broken.")
        return
    var m := CanvasLayer.new()
    m.set_script(script)
    m.layer = 60
    add_child(m)
    _menu = m
    _menu_counter = counter
    m.call("setup", self)


func close_menu(message: String) -> void:
    if _menu != null and is_instance_valid(_menu):
        _menu.queue_free()
    _menu = null
    _menu_counter = null
    if message != "":
        _toast(message, Color(1.0, 0.45, 0.35))


func _watch_menu() -> void:
    if _menu == null:
        return
    if not is_instance_valid(_menu):
        _menu = null
        return
    if _menu_counter == null or not is_instance_valid(_menu_counter):
        close_menu("")
        return
    if not _local_standing():
        close_menu("")
        return
    var p := get_tree().get_first_node_in_group("player") as Node3D
    if p != null and p.global_position.distance_to(_menu_counter.global_position) > CLOSE_DISTANCE:
        close_menu("")


# ---------- transfers ----------

## Called by the menu. Returns "" if the transfer was sent, otherwise the reason it wasn't.
func request_transfer(target_id: int, amount: int) -> String:
    var reason: String = can_send()
    if reason != "":
        return reason
    if amount < MIN_TRANSFER:
        return "Minimum is %d Gains" % MIN_TRANSFER
    if amount > MAX_TRANSFER:
        return "Maximum is %d Gains" % MAX_TRANSFER
    var known: bool = false
    for t in get_targets():
        if int(t["id"]) == target_id:
            known = true
    if not known:
        return "That player is not here"
    if not _is_standing(target_id):
        return "%s is downed" % NetManager.get_player_name(target_id)
    if not GameManager.try_spend_gains(amount):
        return "Not enough Gains"
    _last_send_msec = Time.get_ticks_msec()
    if multiplayer.is_server():
        _host_transfer(1, target_id, amount)
    else:
        _server_transfer.rpc_id(1, target_id, amount)
    return ""


@rpc("any_peer", "call_remote", "reliable")
func _server_transfer(target_id: int, amount: int) -> void:
    if not multiplayer.is_server():
        return
    _host_transfer(multiplayer.get_remote_sender_id(), target_id, amount)


## Host only: checks the transfer, then pays the target or refunds the sender.
func _host_transfer(sender: int, target: int, amount: int) -> void:
    var reason: String = _check_transfer(sender, target, amount)
    if reason != "":
        if sender == multiplayer.get_unique_id():
            _transfer_refused(amount, reason)
        else:
            _transfer_refused.rpc_id(sender, amount, reason)
        return
    var fee: int = int(floor(float(amount) * TRANSFER_FEE))
    var received: int = amount - fee
    if target == multiplayer.get_unique_id():
        _got_membership(received, sender)
    else:
        _got_membership.rpc_id(target, received, sender)
    if sender == multiplayer.get_unique_id():
        _sent_membership(amount, target)
    else:
        _sent_membership.rpc_id(sender, amount, target)


func _check_transfer(sender: int, target: int, amount: int) -> String:
    if target == sender:
        return "You can't pay yourself"
    if amount < MIN_TRANSFER or amount > MAX_TRANSFER:
        return "Bad amount"
    var peers: Array = Array(multiplayer.get_peers())
    if target != 1 and not peers.has(target):
        return "That player left"
    if not _is_standing(sender):
        return "You are downed"
    if not _is_standing(target):
        return "%s is downed" % NetManager.get_player_name(target)
    var now: int = Time.get_ticks_msec()
    if now - int(_host_last.get(sender, -100000)) < int(COOLDOWN * 800.0):
        return "Slow down"
    _host_last[sender] = now
    return ""


@rpc("authority", "call_remote", "reliable")
func _got_membership(amount: int, from_id: int) -> void:
    GameManager.add_gains(amount, false)   # a transfer is not "Gains earned"
    _toast("+%d Gains - %s bought you a membership" % [amount, NetManager.get_player_name(from_id)], Color(0.45, 1.0, 0.45))


@rpc("authority", "call_remote", "reliable")
func _sent_membership(amount: int, to_id: int) -> void:
    gains_given += amount
    _toast("-%d Gains - membership sent to %s" % [amount, NetManager.get_player_name(to_id)], Color(0.95, 0.75, 0.1))


@rpc("authority", "call_remote", "reliable")
func _transfer_refused(amount: int, reason: String) -> void:
    GameManager.add_gains(amount, false)
    _toast("Transfer failed: %s (refunded)" % reason, Color(1.0, 0.45, 0.35))


# ---------- on-screen banner ----------

func _build_toast() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 55
    add_child(layer)
    _toast_label = Label.new()
    _toast_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _toast_label.offset_top = 260.0
    _toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _toast_label.add_theme_font_size_override("font_size", 36)
    _toast_label.add_theme_constant_override("outline_size", 8)
    _toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    _toast_label.modulate.a = 0.0
    layer.add_child(_toast_label)


func _toast(text: String, color: Color) -> void:
    if _toast_label == null:
        return
    _toast_label.text = text
    _toast_label.add_theme_color_override("font_color", color)
    _toast_label.modulate.a = 1.0
    if _toast_tween != null and _toast_tween.is_valid():
        _toast_tween.kill()
    _toast_tween = create_tween()
    _toast_tween.tween_interval(2.5)
    _toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 1.0)
