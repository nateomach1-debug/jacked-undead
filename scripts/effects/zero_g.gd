extends Node
## Easter egg: ZERO-G. Once started, every zombie that dies from then on
## floats up into the air (tumbling) and shrinks away, instead of lying down.
## Lasts until the map ends (game over / restart removes this node).
## Works without touching zombie.gd: it watches each zombie's death, takes the
## corpse body that zombie.gd hands to the scene, freezes zombie.gd's own
## fall/sink tween and floats the body itself.

const SCRIPT_PATH: String = "res://scripts/effects/zero_g.gd"
const GROUP: String = "zero_g_fx"
const FLOAT_HEIGHT: float = 6.0
const FLOAT_TIME: float = 3.0
const SHRINK_TIME: float = 0.4
const TUMBLE_X: float = PI * 1.5
const TUMBLE_Z: float = PI * 0.6


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
    fx.name = "ZeroGFx"
    tree.current_scene.add_child(fx)
    return true


func _ready() -> void:
    add_to_group(GROUP)
    get_tree().node_added.connect(_on_node_added)
    for z in get_tree().get_nodes_in_group("zombies"):
        _watch(z)


func _on_node_added(n: Node) -> void:
    if n is Zombie:
        _watch(n)


func _watch(z) -> void:
    if not is_instance_valid(z) or z.has_meta("zg_watched"):
        return
    z.set_meta("zg_watched", true)
    z.child_exiting_tree.connect(_on_child_exit.bind(z))
    z.died.connect(_on_died)


## zombie.gd removes its body from the zombie right before handing it to the scene.
func _on_child_exit(child: Node, z: Node) -> void:
    if is_instance_valid(z) and child is Node3D:
        z.set_meta("zg_corpse", child)


func _on_died(z) -> void:
    if not is_instance_valid(z):
        return
    var body = z.get_meta("zg_corpse", null)
    if body == null or not is_instance_valid(body):
        return
    if not (body is Node3D) or body is CollisionShape3D:
        return
    # The real corpse is the one that now sits directly under the map scene.
    if body.get_parent() != get_tree().current_scene:
        return
    _float_corpse(body)


func _float_corpse(body: Node3D) -> void:
    # Freezes zombie.gd's own corpse tween (fall back, lie, sink, free).
    body.process_mode = Node.PROCESS_MODE_DISABLED
    var tw: Tween = create_tween()
    tw.set_parallel(true)
    tw.tween_property(body, "position:y", body.position.y + FLOAT_HEIGHT, FLOAT_TIME) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tw.tween_property(body, "rotation:x", body.rotation.x + TUMBLE_X, FLOAT_TIME)
    tw.tween_property(body, "rotation:z", body.rotation.z + TUMBLE_Z, FLOAT_TIME)
    tw.chain().tween_property(body, "scale", Vector3.ZERO, SHRINK_TIME)
    tw.chain().tween_callback(body.queue_free)
