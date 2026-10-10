extends Node
## MembershipHub (autoload): puts the membership counter on every co-op map.
## Step 2 will add the transfer RPCs here.

const COUNTER_SCRIPT: String = "res://scripts/stations/membership_counter.gd"
const SPOT_RADIUS: float = 4.5
const CHECK_INTERVAL: float = 1.0

# Optional fixed spots per map file, local to the supplement stations' parent:
# "main.tscn": [Vector3(x, y, z), yaw_degrees]
# Leave empty to auto-place beside the first supplement station.
const MAP_SPOTS: Dictionary = {}

var _timer: float = 0.0
var _placed_scene: Node = null


func _process(delta: float) -> void:
    _timer += delta
    if _timer < CHECK_INTERVAL:
        return
    _timer = 0.0
    if not NetManager.is_online:
        return
    var scene: Node = get_tree().current_scene
    if scene == null or scene == _placed_scene:
        return
    if not scene.has_node("CoopSync"):
        return
    var station := get_tree().get_first_node_in_group("supplement_station") as Node3D
    if station == null or not scene.is_ancestor_of(station):
        return
    _placed_scene = scene
    _place_counter(scene, station)


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
