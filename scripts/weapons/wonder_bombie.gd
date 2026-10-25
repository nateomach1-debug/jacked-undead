extends Node3D
## Frenemy / Bombie wonder bolt. Flies straight to a zombie, kills it, and the
## zombie turns into a bombie that runs to the closest zombie and explodes.
## The explosion only hurts zombies (never the player).
## PR upgrade (Bombie): bigger blast, and zombies killed by the blast turn into
## more bombies (one per PR level, up to MAX_DEPTH generations).
## Built entirely in code. Spawned by player_controller.gd (_launch_wonder).
## Note: a zombie's origin is the MIDDLE of its capsule.

const HIT_MASK: int = 1 | 4   # world + zombies
const BOLT_SPEED: float = 55.0
const RUN_SPEED: float = 7.5
const RETARGET_INTERVAL: float = 0.25
const TARGET_RANGE: float = 40.0
const ARRIVE_DIST: float = 1.3
const FUSE_TIME: float = 3.0       # explodes on its own if it can't find a target this long
const MAX_RUN_TIME: float = 12.0
const BLAST_GROWTH_PER_LEVEL: float = 0.25
const MAX_DEPTH: int = 2
const DEFAULT_HALF_HEIGHT: float = 0.9
const COLOR_BODY: Color = Color(0.45, 0.9, 0.2)
const COLOR_BOMB: Color = Color(1.0, 0.45, 0.1)

enum Phase { BOLT, RUN }

var _phase: int = Phase.BOLT
var _dir: Vector3 = Vector3.FORWARD
var _shooter: Node = null
var _damage: float = 0.0
var _gains: int = 10
var _radius: float = 5.0
var _pr_level: int = 0
var _depth: int = 0
var _range_left: float = 80.0
var _book: Dictionary = {}
var _target = null            # untyped on purpose: it can be freed while we hold it
var _retarget_timer: float = 0.0
var _half_height: float = DEFAULT_HALF_HEIGHT
var _age: float = 0.0
var _idle_time: float = 0.0
var _t: float = 0.0
var _bolt_body: Node3D = null
var _bombie: Node3D = null
var _bomb_mat: StandardMaterial3D = null


## Shared setup. book / depth are only passed by chain bombies.
func setup(shooter: Node, damage: float, gains: int, splash_radius: float, pr_level: int, book = null, depth: int = 0) -> void:
    _shooter = shooter
    _damage = damage
    _gains = gains
    _radius = splash_radius
    _pr_level = pr_level
    _book = book if book is Dictionary else {}
    _depth = depth


## Fires the bolt. Call after add_child and after setting global_position.
func launch(shooter: Node, direction: Vector3, damage: float, gains: int, splash_radius: float, pr_level: int, max_range: float) -> void:
    setup(shooter, damage, gains, splash_radius, pr_level)
    _dir = direction.normalized()
    _range_left = max_range
    _phase = Phase.BOLT
    var up: Vector3 = Vector3.UP if absf(_dir.y) < 0.99 else Vector3.RIGHT
    look_at(global_position + _dir, up)

    var shaft := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.025
    cyl.bottom_radius = 0.025
    cyl.height = 0.7
    shaft.mesh = cyl
    shaft.rotation_degrees = Vector3(90, 0, 0)
    shaft.material_override = _glow_mat(COLOR_BODY, 1.0, 2.0)
    add_child(shaft)
    var tip := MeshInstance3D.new()
    var ball := SphereMesh.new()
    ball.radius = 0.1
    ball.height = 0.2
    tip.mesh = ball
    tip.position = Vector3(0, 0, -0.38)
    tip.material_override = _glow_mat(COLOR_BOMB, 1.0, 3.0)
    add_child(tip)
    _bolt_body = Node3D.new()
    _bolt_body.add_child(shaft.duplicate())
    _bolt_body.queue_free()
    _bolt_body = shaft


## Starts straight away as a running bombie (used by Bombie chain bursts).
func start_as_bombie(pos: Vector3) -> void:
    _start_run(pos)


func _physics_process(delta: float) -> void:
    if _phase == Phase.BOLT:
        _bolt_step(delta)
    else:
        _run_step(delta)


# ---------- the bolt ----------

func _bolt_step(delta: float) -> void:
    var step: float = BOLT_SPEED * delta
    _range_left -= step
    if _range_left <= 0.0:
        queue_free()
        return
    var from: Vector3 = global_position
    var to: Vector3 = from + _dir * step
    var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
    if is_instance_valid(_shooter) and _shooter is CollisionObject3D:
        var ex: Array[RID] = [(_shooter as CollisionObject3D).get_rid()]
        query.exclude = ex
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var collider = hit["collider"]
        if collider != null and collider is Node and (collider as Node).is_in_group("zombies") and _alive(collider):
            _convert(collider)
        else:
            _flash(hit["position"], 0.5, COLOR_BOMB)
            queue_free()
        return
    global_position = to


## The shot zombie dies and a bombie takes its place.
func _convert(z) -> void:
    var pos: Vector3 = z.global_position
    _half_height = _half_height_of(z)
    _book[z.get_instance_id()] = "done"
    var hp: float = float(z.get("current_health"))
    z.take_damage(maxf(hp + 1.0, 1.0), _shooter, false)
    GameManager.add_gains(_gains)
    _start_run(pos)


func _half_height_of(z) -> float:
    var shape_node := z.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if shape_node != null and shape_node.shape is CapsuleShape3D:
        return (shape_node.shape as CapsuleShape3D).height * 0.5
    return DEFAULT_HALF_HEIGHT


# ---------- the bombie ----------

func _start_run(pos: Vector3) -> void:
    _phase = Phase.RUN
    if _bolt_body != null and is_instance_valid(_bolt_body):
        _bolt_body.visible = false
    for c in get_children():
        if c is MeshInstance3D:
            (c as MeshInstance3D).visible = false
    global_position = pos
    _build_bombie()
    _target = _find_target()


func _build_bombie() -> void:
    _bombie = Node3D.new()
    add_child(_bombie)

    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.35
    capsule.height = maxf(_half_height * 2.0, 0.8)
    body.mesh = capsule
    body.material_override = _glow_mat(COLOR_BODY, 1.0, 0.6)
    _bombie.add_child(body)

    var bomb := MeshInstance3D.new()
    var ball := SphereMesh.new()
    ball.radius = 0.3
    ball.height = 0.6
    bomb.mesh = ball
    bomb.position = Vector3(0, _half_height + 0.15, 0)
    _bomb_mat = _glow_mat(COLOR_BOMB, 1.0, 3.0)
    bomb.material_override = _bomb_mat
    _bombie.add_child(bomb)

    var fuse := MeshInstance3D.new()
    var fuse_mesh := BoxMesh.new()
    fuse_mesh.size = Vector3(0.05, 0.2, 0.05)
    fuse.mesh = fuse_mesh
    fuse.position = Vector3(0, _half_height + 0.5, 0)
    fuse.material_override = _glow_mat(Color(1.0, 0.9, 0.3), 1.0, 4.0)
    _bombie.add_child(fuse)


func _run_step(delta: float) -> void:
    _age += delta
    _t += delta
    if _age > MAX_RUN_TIME:
        _explode()
        return

    # Pulse the bomb faster and faster, and bob while running.
    if _bomb_mat != null:
        _bomb_mat.emission_energy_multiplier = 2.0 + 2.5 * absf(sin(_t * (6.0 + _age * 2.0)))
    if _bombie != null:
        _bombie.position.y = absf(sin(_t * 10.0)) * 0.12

    _retarget_timer -= delta
    if _retarget_timer <= 0.0 and (_target == null or not _alive(_target)):
        _retarget_timer = RETARGET_INTERVAL
        _target = _find_target()

    if _target == null or not _alive(_target):
        _idle_time += delta
        if _idle_time >= FUSE_TIME:
            _explode()
        return
    _idle_time = 0.0

    var to: Vector3 = (_target as Node3D).global_position - global_position
    if to.length() < ARRIVE_DIST:
        _explode()
        return
    var flat := Vector3(to.x, 0.0, to.z)
    if flat.length() < 0.01:
        _explode()
        return
    var dir: Vector3 = flat.normalized()
    var step: float = RUN_SPEED * delta

    # A wall in the way: blow up against it.
    var wall := PhysicsRayQueryParameters3D.create(global_position, global_position + dir * (step + 0.6), 1)
    if not get_world_3d().direct_space_state.intersect_ray(wall).is_empty():
        _explode()
        return

    global_position += dir * step
    _snap_to_floor()
    if _bombie != null:
        _bombie.look_at(_bombie.global_position + dir, Vector3.UP)


func _snap_to_floor() -> void:
    var from: Vector3 = global_position + Vector3(0, 1.0, 0)
    var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -5.0, 0), 1)
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        global_position.y = float(hit["position"].y) + _half_height


# ---------- targeting ----------

func _alive(z) -> bool:
    return is_instance_valid(z) and z is Node3D and not bool(z.get("_is_dead"))


func _has_los(from: Vector3, to: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The closest zombie (one it can see is preferred over one behind a wall).
func _find_target():
    var best_los = null
    var best_los_d: float = TARGET_RANGE
    var best_any = null
    var best_any_d: float = TARGET_RANGE
    for n in get_tree().get_nodes_in_group("zombies"):
        if not _alive(n) or _book.get(n.get_instance_id(), "") == "done":
            continue
        var d: float = global_position.distance_to(n.global_position)
        if d < best_any_d:
            best_any_d = d
            best_any = n
        if d < best_los_d and _has_los(global_position, n.global_position):
            best_los_d = d
            best_los = n
    return best_los if best_los != null else best_any


# ---------- the explosion ----------

func _explode() -> void:
    var center: Vector3 = global_position
    var r: float = _radius * (1.0 + BLAST_GROWTH_PER_LEVEL * float(_pr_level))
    var killed: Array = []
    for n in get_tree().get_nodes_in_group("zombies"):
        if not _alive(n):
            continue
        var d: float = center.distance_to(n.global_position)
        if d > r:
            continue
        var pos: Vector3 = n.global_position
        _book[n.get_instance_id()] = "done"
        n.take_damage(_damage, _shooter, false)
        GameManager.add_gains(_gains)
        if bool(n.get("_is_dead")):
            killed.append({"d": d, "pos": pos})
    _flash(center, r, COLOR_BOMB)

    # Bombie: zombies killed by the blast turn into more bombies.
    if _pr_level > 0 and _depth < MAX_DEPTH:
        killed.sort_custom(func(a, b): return a["d"] < b["d"])
        var count: int = mini(_pr_level, killed.size())
        var scene := get_tree().current_scene
        if scene != null:
            for i in range(count):
                var b = get_script().new()
                scene.add_child(b)
                b.global_position = killed[i]["pos"]
                b.setup(_shooter, _damage, _gains, _radius, _pr_level, _book, _depth + 1)
                b.start_as_bombie(killed[i]["pos"])
    queue_free()


# ---------- effects ----------

func _glow_mat(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = Color(color.r, color.g, color.b, alpha)
    if alpha < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = energy
    return m


func _flash(at: Vector3, radius: float, color: Color) -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var fx := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    fx.mesh = sphere
    var mat: StandardMaterial3D = _glow_mat(color, 0.6, 2.5)
    fx.material_override = mat
    scene.add_child(fx)
    fx.global_position = at
    fx.scale = Vector3.ONE * radius * 0.2
    var tween := fx.create_tween()
    tween.set_parallel(true)
    tween.tween_property(fx, "scale", Vector3.ONE * radius, 0.3)
    tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
    tween.chain().tween_callback(fx.queue_free)
