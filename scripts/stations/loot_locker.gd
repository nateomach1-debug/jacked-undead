extends Area3D
## Loot Locker: the gym version of the mystery box. Pay Gains, the locker
## rattles while a random gun cycles by, then the door swings open and the
## gun floats out. Tap USE again within take_window seconds to grab it, or
## the locker closes and you lose it. Built entirely in code.
## Pulling a gun you already own gives it a full ammo refill (player.grant_weapon).
##
## Several lockers on one map: only ONE is usable at a time (picked at random
## when the map loads); the rest show an OUT OF ORDER sign. Every roll also has
## a chance to lock the locker (same odds as one gun): you are refunded, the
## sign appears and a different locker becomes the usable one.
## Co-op: the host picks the first one, then every lock is sent to all phones.

const DISPLAY_LENGTH: float = 0.9  # every gun shown in the locker is scaled to this length (meters)

enum State { IDLE, ROLLING, READY, LOCKED }

@export var cost: int = 950
@export var roll_time: float = 2.5
@export var take_window: float = 8.0

var _state: int = State.IDLE
var _is_active: bool = true
var _will_lock: bool = false
var _pool: Array = []
var _total_weight: int = 0
var _rolled: WeaponData = null
var _timer: float = 0.0
var _cycle_timer: float = 0.0

var _visual_root: Node3D
var _door_pivot: Node3D
var _label: Label3D
var _display_mount: Node3D
var _display_model: Node3D = null
var _sign: Node3D


func _ready() -> void:
    add_to_group("loot_lockers")
    _build_visuals()
    var locker_weapons = load("res://scripts/weapons/locker_weapons.gd")
    if locker_weapons:
        _pool = locker_weapons.build_pool()
    for entry in _pool:
        _total_weight += int(entry["weight"])
    _set_idle_label()
    _init_active.call_deferred()


func _build_visuals() -> void:
    _visual_root = Node3D.new()
    add_child(_visual_root)

    # Locker body
    _add_box(_visual_root, Vector3(1.0, 2.0, 0.8), Vector3(0, 1.0, 0), Color(0.2, 0.35, 0.6))

    # Door, hinged on its left edge
    _door_pivot = Node3D.new()
    _door_pivot.position = Vector3(-0.5, 1.0, 0.42)
    _visual_root.add_child(_door_pivot)
    _add_box(_door_pivot, Vector3(1.0, 1.9, 0.05), Vector3(0.5, 0, 0), Color(0.3, 0.5, 0.8))
    _add_box(_door_pivot, Vector3(0.05, 0.25, 0.06), Vector3(0.85, 0, 0.04), Color(0.9, 0.9, 0.9))

    # OUT OF ORDER sign, taped across the door
    _sign = Node3D.new()
    _sign.position = Vector3(0, 1.0, 0.5)
    _sign.rotation_degrees = Vector3(0, 0, 12)
    _sign.visible = false
    _visual_root.add_child(_sign)
    _add_box(_sign, Vector3(0.95, 0.32, 0.03), Vector3.ZERO, Color(0.8, 0.1, 0.1))
    var sign_text := Label3D.new()
    sign_text.text = "OUT OF ORDER"
    sign_text.font_size = 40
    sign_text.pixel_size = 0.004
    sign_text.outline_size = 6
    sign_text.position = Vector3(0, 0, 0.025)
    _sign.add_child(sign_text)

    _label = Label3D.new()
    _label.font_size = 48
    _label.pixel_size = 0.006
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.outline_size = 12
    _label.position = Vector3(0, 2.6, 0)
    add_child(_label)

    # Where the rolled gun floats
    _display_mount = Node3D.new()
    _display_mount.position = Vector3(0, 1.3, 0.9)
    add_child(_display_mount)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    mesh_instance.mesh = box
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh_instance.material_override = mat
    mesh_instance.position = pos
    parent.add_child(mesh_instance)
    return mesh_instance


# ------------------------------------------------- which locker is usable

## Every locker on the map, in the same order on every phone.
func _all_lockers() -> Array:
    var all: Array = get_tree().get_nodes_in_group("loot_lockers")
    all.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
    return all


## Runs once per locker right after the map loads. Maps with one locker keep
## the old behaviour (always usable, never locks).
func _init_active() -> void:
    var all: Array = _all_lockers()
    if all.size() <= 1:
        return
    var is_host: bool = (not NetManager.is_online) or multiplayer.is_server()
    if not is_host:
        # Wait for the host to say which locker is usable.
        _set_active(false)
        if all[0] == self:
            _net_request.rpc_id(1)
        return
    if all[0] == self:
        _apply_active(randi() % all.size())


## Makes locker number idx (in sorted order) the usable one, all others locked.
func _apply_active(idx: int) -> void:
    var all: Array = _all_lockers()
    for i in all.size():
        all[i]._set_active(i == idx)


func _set_active(on: bool) -> void:
    _is_active = on
    if on:
        if _state == State.LOCKED:
            _state = State.IDLE
            _sign.visible = false
            _set_idle_label()
    elif _state != State.LOCKED:
        _state = State.LOCKED
        _rolled = null
        _will_lock = false
        _visual_root.position = Vector3.ZERO
        _clear_model()
        _set_door_open(false)
        _sign.visible = true
        _label.text = "OUT OF ORDER"


## Co-op: a client asks the host which locker is usable.
@rpc("any_peer", "call_remote", "reliable")
func _net_request() -> void:
    var sender: int = multiplayer.get_remote_sender_id()
    var all: Array = _all_lockers()
    for i in all.size():
        if all[i]._is_active:
            _net_active.rpc_id(sender, i)
            return


## Co-op: tells this phone which locker is now the usable one.
@rpc("any_peer", "call_remote", "reliable")
func _net_active(idx: int) -> void:
    _apply_active(idx)


# ------------------------------------------------------------- using it

func _process(delta: float) -> void:
    if _state == State.ROLLING:
        _timer -= delta
        # Rattle the whole locker a little
        _visual_root.position = Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(-0.03, 0.03))
        # Flip through random guns for suspense
        _cycle_timer -= delta
        if _cycle_timer <= 0.0:
            _cycle_timer = 0.2
            _show_model(_random_weapon())
        if _timer <= 0.0:
            _finish_roll()
    elif _state == State.READY:
        _timer -= delta
        if _display_model:
            _display_mount.rotate_y(delta * 1.5)
        if _timer <= 0.0:
            _close_locker()


func interact(player: Node) -> void:
    if _state == State.IDLE:
        if GameManager.try_spend_gains(GameManager.loot_locker_cost(cost)):
            _start_roll()
    elif _state == State.READY:
        if _rolled and player.has_method("grant_weapon"):
            player.grant_weapon(_rolled)
        _close_locker()


func get_prompt_text() -> String:
    if _state == State.IDLE:
        return "Tap USE to open Loot Locker - %d Gains" % GameManager.loot_locker_cost(cost)
    if _state == State.READY and _rolled:
        return "Tap USE to grab %s" % _rolled.weapon_name
    if _state == State.LOCKED:
        return "Out of order"
    return ""


func _start_roll() -> void:
    _will_lock = _roll_lock()
    _rolled = _pick_weapon()
    _state = State.ROLLING
    _timer = roll_time
    _cycle_timer = 0.0
    _label.text = "..."


## The lock outcome has the same weight as one gun (the average gun weight).
## Only possible when the map has more than one locker.
func _roll_lock() -> bool:
    if _pool.is_empty() or _all_lockers().size() <= 1:
        return false
    var avg: int = maxi(int(float(_total_weight) / float(_pool.size())), 1)
    return randi() % (_total_weight + avg) < avg


func _finish_roll() -> void:
    _visual_root.position = Vector3.ZERO
    if _will_lock:
        _will_lock = false
        _lock_up()
        return
    _show_model(_rolled)
    _set_door_open(true)
    _state = State.READY
    _timer = take_window
    _label.text = _rolled.weapon_name if _rolled else "Empty"


## Out of order: refund the roll, show the sign, and move to another locker.
func _lock_up() -> void:
    GameManager.add_gains(GameManager.loot_locker_cost(cost))
    var all: Array = _all_lockers()
    var me: int = all.find(self)
    var next: int = randi() % (all.size() - 1)
    if next >= me:
        next += 1
    _apply_active(next)
    if NetManager.is_online:
        _net_active.rpc(next)


func _close_locker() -> void:
    _state = State.IDLE
    _rolled = null
    _visual_root.position = Vector3.ZERO
    _clear_model()
    _set_door_open(false)
    _set_idle_label()


func _set_idle_label() -> void:
    _label.text = "LOOT LOCKER\n%d Gains" % GameManager.loot_locker_cost(cost)


func _set_door_open(open: bool) -> void:
    var tween := create_tween()
    tween.tween_property(_door_pivot, "rotation_degrees:y", -110.0 if open else 0.0, 0.3)


func _show_model(w: WeaponData) -> void:
    _clear_model()
    if w == null:
        return
    var model: Node3D = w.create_model()
    if model:
        _display_model = model
        if not w.model_scene:
            model.rotation_degrees.y = -90.0  # turn built-in guns side-on, like the asset guns
        _display_mount.add_child(model)
        _fit_model(model)


func _collect_meshes(node: Node, out: Array) -> void:
    if node is MeshInstance3D:
        out.append(node)
    for child in node.get_children():
        _collect_meshes(child, out)


## Scales the shown gun so its longest side is DISPLAY_LENGTH, and centers it
## on the mount so it spins around its middle.
func _fit_model(model: Node3D) -> void:
    var meshes: Array = []
    _collect_meshes(model, meshes)
    var to_mount: Transform3D = _display_mount.global_transform.affine_inverse()
    var box := AABB()
    var found: bool = false
    for m in meshes:
        var mi: MeshInstance3D = m
        var local_box: AABB = (to_mount * mi.global_transform) * mi.get_aabb()
        if found:
            box = box.merge(local_box)
        else:
            box = local_box
            found = true
    if not found:
        return
    var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
    if longest <= 0.0001:
        return
    var factor: float = DISPLAY_LENGTH / longest
    model.scale = Vector3.ONE * factor
    model.position = -box.get_center() * factor


func _clear_model() -> void:
    if _display_model:
        _display_model.queue_free()
        _display_model = null
    _display_mount.rotation = Vector3.ZERO


func _pick_weapon() -> WeaponData:
    if _pool.is_empty():
        return null
    var roll: int = randi() % maxi(_total_weight, 1)
    for entry in _pool:
        roll -= int(entry["weight"])
        if roll < 0:
            return entry["weapon"]
    return _pool[0]["weapon"]


func _random_weapon() -> WeaponData:
    if _pool.is_empty():
        return null
    return _pool[randi() % _pool.size()]["weapon"]
