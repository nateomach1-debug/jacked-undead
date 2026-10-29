extends Node3D
## Goo ball thrown by the Spitter. Flies in an arc, hurts the first player it
## touches, and splats on walls and floors. Dodge it by moving.

const HIT_RADIUS: float = 0.75
const HIT_HEIGHT: float = 1.1
const LIFETIME: float = 4.0

static var _goo_mat: StandardMaterial3D = null

var velocity: Vector3 = Vector3.ZERO
var damage: float = 8.0
var gravity: float = 6.0
var _life: float = 0.0
var _done: bool = false


static func _make_goo_mat() -> StandardMaterial3D:
    if _goo_mat == null:
        _goo_mat = StandardMaterial3D.new()
        _goo_mat.albedo_color = Color(0.45, 0.85, 0.15)
        _goo_mat.roughness = 0.3
        _goo_mat.emission_enabled = true
        _goo_mat.emission = Color(0.35, 0.9, 0.1)
        _goo_mat.emission_energy_multiplier = 1.5
    return _goo_mat


func _ready() -> void:
    var mi := MeshInstance3D.new()
    var sm := SphereMesh.new()
    sm.radius = 0.16
    sm.height = 0.32
    sm.radial_segments = 8
    sm.rings = 4
    mi.mesh = sm
    mi.material_override = _make_goo_mat()
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)


## Call after the ball has been added to the scene and positioned.
func launch(vel: Vector3, dmg: float, grav: float) -> void:
    velocity = vel
    damage = dmg
    gravity = grav


func _physics_process(delta: float) -> void:
    if _done:
        return
    _life += delta
    if _life >= LIFETIME:
        _splat()
        return
    velocity.y -= gravity * delta
    var from_pos: Vector3 = global_position
    var to_pos: Vector3 = from_pos + velocity * delta

    var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
    query.collision_mask = 1
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        global_position = hit["position"]
        var victim: Node = _victim_from_collider(hit.get("collider"))
        if victim != null and not _is_out(victim):
            _hurt(victim)
        _splat()
        return

    global_position = to_pos
    var near: Node3D = _find_victim()
    if near != null:
        _hurt(near)
        _splat()


func _victim_from_collider(collider: Object) -> Node:
    var n := collider as Node
    while n != null:
        if n.is_in_group("player") or n.is_in_group("remote_players"):
            return n
        n = n.get_parent()
    return null


func _find_victim() -> Node3D:
    for group_name in ["player", "remote_players"]:
        for n in get_tree().get_nodes_in_group(group_name):
            var p := n as Node3D
            if p == null or not is_instance_valid(p) or _is_out(p):
                continue
            var off: Vector3 = p.global_position - global_position
            var dy: float = absf(off.y)
            off.y = 0.0
            if off.length() <= HIT_RADIUS and dy <= HIT_HEIGHT:
                return p
    return null


func _hurt(p: Node) -> void:
    var dmg: float = GameManager.get_zombie_damage(damage)
    if p.has_method("take_damage"):
        p.take_damage(dmg)
    elif p.has_meta("peer_id"):
        NetManager.damage_peer(int(p.get_meta("peer_id")), dmg)


func _is_out(p: Node) -> bool:
    return bool(p.get("is_downed")) or bool(p.get("is_dead")) or bool(p.get_meta("downed", false)) or bool(p.get_meta("dead", false))


func _splat() -> void:
    if _done:
        return
    _done = true
    set_physics_process(false)
    var scene: Node = get_tree().current_scene
    if scene != null:
        var blob := MeshInstance3D.new()
        var sm := SphereMesh.new()
        sm.radius = 0.5
        sm.height = 1.0
        sm.radial_segments = 8
        sm.rings = 4
        blob.mesh = sm
        blob.material_override = _make_goo_mat()
        blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        blob.scale = Vector3(0.5, 0.06, 0.5)
        scene.add_child(blob)
        blob.global_position = global_position
        var tw := blob.create_tween()
        tw.tween_interval(0.8)
        tw.tween_property(blob, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
        tw.tween_callback(blob.queue_free)
    queue_free()
