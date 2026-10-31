extends Node
## Easter egg: BIG HEAD MODE.
## Added to the running map by start(). For 60 seconds every zombie's head is
## scaled up, and each zombie gets an extra sphere hit shape on the big head so
## it is really easier to hit (a hit on it counts as a headshot because it sits
## above head_height_threshold). Zombies that spawn during the effect get it too.
## Starting again while it runs does nothing (no reset, no extension).
## The node lives under the map scene, so a restart or game over removes it.

const SCRIPT_PATH: String = "res://scripts/effects/big_head.gd"
const GROUP: String = "big_head_fx"
const DURATION: float = 60.0
const HEAD_SCALE: float = 2.2
const EXTRA_HIT_SHAPE: bool = true
const SHAPE_RADIUS: float = 0.34
const HEAD_CENTER_Y: float = 0.15

var _time_left: float = DURATION
var _applied: Dictionary = {}  # zombie instance id -> {zombie, head, shape}


## Returns true if the effect started, false if it was already running.
static func start(tree: SceneTree) -> bool:
    if tree == null or tree.current_scene == null:
        return false
    if tree.get_first_node_in_group(GROUP) != null:
        return false
    var cls = load(SCRIPT_PATH)
    if cls == null:
        return false
    var fx: Node = cls.new()
    fx.name = "BigHeadFx"
    tree.current_scene.add_child(fx)
    return true


func _ready() -> void:
    add_to_group(GROUP)
    get_tree().node_added.connect(_on_node_added)
    for z in get_tree().get_nodes_in_group("zombies"):
        _apply(z)


## Seconds left of the effect (the power ups display reads this).
func time_left() -> float:
    return maxf(_time_left, 0.0)


func _on_node_added(n: Node) -> void:
    if n is Zombie:
        # Wait until the zombie has built its body in _ready().
        call_deferred("_apply", n)


func _apply(z) -> void:
    if not is_instance_valid(z):
        return
    var id: int = z.get_instance_id()
    if _applied.has(id):
        return
    var head = z.get("_head")
    if head == null or not is_instance_valid(head):
        return
    head.scale = Vector3.ONE * HEAD_SCALE
    var shape: CollisionShape3D = null
    if EXTRA_HIT_SHAPE:
        var k: float = 1.0
        var vis = z.get("_visual")
        if vis != null and is_instance_valid(vis):
            k = float(vis.scale.y)
        var sph := SphereShape3D.new()
        sph.radius = SHAPE_RADIUS * k
        shape = CollisionShape3D.new()
        shape.name = "BigHeadShape"
        shape.shape = sph
        z.add_child(shape)
        _place(z, head, shape)
    _applied[id] = {"zombie": z, "head": head, "shape": shape}


func _place(z: Node3D, head: Node3D, shape: CollisionShape3D) -> void:
    var center: Vector3 = head.to_global(Vector3(0.0, HEAD_CENTER_Y * HEAD_SCALE, 0.0))
    shape.position = z.to_local(center)


func _process(delta: float) -> void:
    _time_left -= delta
    if _time_left <= 0.0:
        _finish()
        return
    for id in _applied.keys():
        var e: Dictionary = _applied[id]
        var z = e["zombie"]
        var head = e["head"]
        if not is_instance_valid(z) or not is_instance_valid(head):
            _applied.erase(id)
            continue
        var shape = e["shape"]
        if shape != null and is_instance_valid(shape):
            _place(z, head, shape)


func _finish() -> void:
    set_process(false)
    for id in _applied.keys():
        var e: Dictionary = _applied[id]
        var head = e["head"]
        if is_instance_valid(head):
            head.scale = Vector3.ONE
        var shape = e["shape"]
        if shape != null and is_instance_valid(shape):
            shape.queue_free()
    _applied.clear()
    queue_free()
