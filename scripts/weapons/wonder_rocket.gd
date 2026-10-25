extends Node3D
## Br-Nh wonder rocket. Flies (homing) to a zombie, freezes it, draws a ring
## around it, shoots spikes in from the ring, kills it, then the zombie bursts
## into more rockets that each go after a different zombie and do the same.
## Every zombie is only hit once per chain (shared _book dictionary).
## Built entirely in code. Spawned by player_controller.gd (_launch_wonder).

const HIT_MASK: int = 1 | 4   # world + zombies
const SPEED: float = 24.0
const STEER: float = 7.0
const MAX_LIFETIME: float = 5.0
const AIM_DOT: float = 0.96       # how close to the crosshair a zombie must be to get locked on
const AIM_RANGE: float = 45.0
const CHAIN_ROCKETS: int = 3      # rockets released when a zombie bursts
const CHAIN_RANGE: float = 16.0
const RING_TIME: float = 0.6
const SPIKE_TIME: float = 0.3
const SPIKE_COUNT: int = 8
const RING_RADIUS: float = 1.2
const RETARGET_INTERVAL: float = 0.15
const HIT_MARKER_PATH: String = "res://scenes/effects/hit_marker.tscn"
const COLOR: Color = Color(0.65, 0.3, 1.0)

enum Phase { FLY, RING, SPIKE }

var _phase: int = Phase.FLY
var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 0.0
var _gains: int = 10
var _shooter: Node = null
var _target = null            # untyped on purpose: it can be freed while we hold it
var _victim = null
var _victim_pos: Vector3 = Vector3.ZERO
var _book: Dictionary = {}   # shared by the whole chain: zombie id -> "claimed" or "done"
var _can_retarget: bool = false
var _retarget_timer: float = 0.0
var _age: float = 0.0
var _timer: float = 0.0
var _fx: Node3D = null
var _ring: MeshInstance3D = null
var _spikes: Array = []
var _body: MeshInstance3D = null


func _ready() -> void:
    _body = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.12
    sphere.height = 0.24
    _body.mesh = sphere
    _body.material_override = _glow_mat(1.0, 3.0)
    add_child(_body)


## book / target are only passed by chain rockets (so the whole chain shares them).
func launch(shooter: Node, direction: Vector3, damage: float, gains: int, book = null, target = null) -> void:
    _shooter = shooter
    _velocity = direction.normalized() * SPEED
    _damage = damage
    _gains = gains
    _book = book if book is Dictionary else {}
    if target == null:
        target = _find_aim_target(direction.normalized())
    _set_target(target)


func _exit_tree() -> void:
    if is_instance_valid(_fx):
        _fx.queue_free()
    if _victim != null and is_instance_valid(_victim) and not bool(_victim.get("is_puppet")):
        _victim.set_physics_process(true)


func _physics_process(delta: float) -> void:
    if _phase == Phase.FLY:
        _fly(delta)
    elif _phase == Phase.RING:
        _ring_step(delta)
    else:
        _spike_step(delta)


# ---------- flying ----------

func _fly(delta: float) -> void:
    _age += delta
    if _age > MAX_LIFETIME:
        _fizzle(global_position)
        return

    # Lost the target (or someone else got it)? Pick a new one nearby.
    _retarget_timer -= delta
    if _can_retarget and _retarget_timer <= 0.0 and (_target == null or not _alive(_target) or _is_done(_target)):
        _retarget_timer = RETARGET_INTERVAL
        _target = null
        _set_target(_nearest_free(global_position, CHAIN_RANGE * 2.0))

    if _target != null and _alive(_target):
        var aim: Vector3 = _center(_target)
        var desired: Vector3 = (aim - global_position).normalized()
        var current: Vector3 = _velocity.normalized()
        _velocity = current.lerp(desired, clampf(STEER * delta, 0.0, 1.0)).normalized() * SPEED
        if global_position.distance_to(aim) < 0.9:
            _engage(_target)
            return

    var from: Vector3 = global_position
    var to: Vector3 = from + _velocity * delta
    var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
    query.exclude = _exclude_rids()
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var collider = hit["collider"]
        if collider != null and collider is Node and (collider as Node).is_in_group("zombies") and _alive(collider) and not _is_done(collider):
            _engage(collider)
        else:
            _fizzle(hit["position"])
        return
    global_position = to


func _exclude_rids() -> Array[RID]:
    var out: Array[RID] = []
    if is_instance_valid(_shooter) and _shooter is CollisionObject3D:
        out.append((_shooter as CollisionObject3D).get_rid())
    for id in _book.keys():
        if _book[id] != "done":
            continue
        var o = instance_from_id(id)
        if o != null and is_instance_valid(o) and o is CollisionObject3D:
            out.append((o as CollisionObject3D).get_rid())
    return out


# ---------- targeting ----------

func _alive(z) -> bool:
    return is_instance_valid(z) and z is Node3D and not bool(z.get("_is_dead"))


func _is_done(z) -> bool:
    return _book.get(z.get_instance_id(), "") == "done"


func _center(z) -> Vector3:
    return z.global_position + Vector3(0, 1.0, 0)


func _set_target(t) -> void:
    _target = t
    if t != null:
        _can_retarget = true
        if not _book.has(t.get_instance_id()):
            _book[t.get_instance_id()] = "claimed"


## Gives up the claim on the current target so another rocket can take it.
func _release_target() -> void:
    if _target != null and is_instance_valid(_target):
        var id: int = _target.get_instance_id()
        if _book.get(id, "") == "claimed":
            _book.erase(id)
    _target = null


func _has_los(from: Vector3, to: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(from, to, 1)
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The zombie closest to where the player is aiming (a small cone around the crosshair).
func _find_aim_target(dir: Vector3):
    var best = null
    var best_dot: float = AIM_DOT
    var from: Vector3 = global_position
    for n in get_tree().get_nodes_in_group("zombies"):
        if not _alive(n) or _book.has(n.get_instance_id()):
            continue
        var to: Vector3 = _center(n) - from
        var dist: float = to.length()
        if dist > AIM_RANGE or dist < 0.5:
            continue
        var d: float = dir.dot(to / dist)
        if d > best_dot and _has_los(from, _center(n)):
            best_dot = d
            best = n
    return best


func _nearest_free(pos: Vector3, max_dist: float):
    var best = null
    var best_dist: float = max_dist
    for n in get_tree().get_nodes_in_group("zombies"):
        if not _alive(n) or _book.has(n.get_instance_id()):
            continue
        var dist: float = pos.distance_to(_center(n))
        if dist < best_dist and _has_los(pos, _center(n)):
            best_dist = dist
            best = n
    return best


# ---------- ring and spikes ----------

func _engage(z) -> void:
    _release_target()
    _phase = Phase.RING
    _victim = z
    _victim_pos = z.global_position
    _book[z.get_instance_id()] = "done"
    if not bool(z.get("is_puppet")):
        z.set_physics_process(false)   # the zombie holds still inside the ring
    _body.visible = false
    global_position = _victim_pos
    _timer = 0.0
    _build_fx()


func _build_fx() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    _fx = Node3D.new()
    scene.add_child(_fx)
    _fx.global_position = _victim_pos + Vector3(0, 1.0, 0)

    _ring = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = RING_RADIUS - 0.06
    torus.outer_radius = RING_RADIUS + 0.06
    _ring.mesh = torus
    _ring.material_override = _glow_mat(0.85, 3.0)
    _fx.add_child(_ring)
    _ring.scale = Vector3.ONE * 1.6

    for i in range(SPIKE_COUNT):
        var ang: float = TAU * float(i) / float(SPIKE_COUNT)
        var dir := Vector3(cos(ang), 0.0, sin(ang))
        var pivot := Node3D.new()
        var cone_mi := MeshInstance3D.new()
        var cone := CylinderMesh.new()
        cone.top_radius = 0.0
        cone.bottom_radius = 0.07
        cone.height = 0.9
        cone_mi.mesh = cone
        cone_mi.rotation_degrees = Vector3(-90, 0, 0)   # tip points along the pivot's -Z (at the zombie)
        cone_mi.material_override = _glow_mat(1.0, 2.5)
        pivot.add_child(cone_mi)
        pivot.visible = false
        _fx.add_child(pivot)
        pivot.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), dir * RING_RADIUS)
        _spikes.append({"node": pivot, "dir": dir})


func _ring_step(delta: float) -> void:
    _timer += delta
    var t: float = clampf(_timer / RING_TIME, 0.0, 1.0)
    if _ring != null:
        _ring.scale = Vector3.ONE * lerpf(1.6, 1.0, t)
    if t >= 1.0:
        _phase = Phase.SPIKE
        _timer = 0.0
        for s in _spikes:
            (s["node"] as Node3D).visible = true


func _spike_step(delta: float) -> void:
    _timer += delta
    var t: float = clampf(_timer / SPIKE_TIME, 0.0, 1.0)
    var radius: float = lerpf(RING_RADIUS, 0.2, t * t)
    for s in _spikes:
        (s["node"] as Node3D).position = (s["dir"] as Vector3) * radius
    if t >= 1.0:
        _finish_hit()


func _finish_hit() -> void:
    var z = _victim
    if z != null and is_instance_valid(z):
        var marker_scene = load(HIT_MARKER_PATH)
        if marker_scene:
            var marker: Node3D = marker_scene.instantiate()
            get_tree().current_scene.add_child(marker)
            marker.global_position = _victim_pos + Vector3(0, 1.4, 0)
        var hp: float = float(z.get("current_health"))
        z.take_damage(maxf(_damage, hp + 1.0), _shooter, false)   # the spikes always kill
        GameManager.add_gains(_gains)
    _flash(_victim_pos + Vector3(0, 1.0, 0), 1.8)
    _spawn_chain(_victim_pos)
    queue_free()


## The zombie bursts: up to CHAIN_ROCKETS new rockets, each at a different zombie nearby.
func _spawn_chain(pos: Vector3) -> void:
    var found: Array = []
    for n in get_tree().get_nodes_in_group("zombies"):
        if not _alive(n) or _book.has(n.get_instance_id()):
            continue
        var d: float = pos.distance_to(n.global_position)
        if d > CHAIN_RANGE:
            continue
        found.append({"d": d, "z": n})
    found.sort_custom(func(a, b): return a["d"] < b["d"])
    var count: int = mini(CHAIN_ROCKETS, found.size())
    var origin: Vector3 = pos + Vector3(0, 1.2, 0)
    for i in range(count):
        var z = found[i]["z"]
        var rocket = get_script().new()
        get_tree().current_scene.add_child(rocket)
        rocket.global_position = origin
        var dir: Vector3 = (_center(z) - origin).normalized()
        dir = (dir + Vector3(randf_range(-0.3, 0.3), 0.5, randf_range(-0.3, 0.3))).normalized()
        rocket.launch(_shooter, dir, _damage, _gains, _book, z)


# ---------- effects ----------

func _fizzle(at: Vector3) -> void:
    _release_target()
    _flash(at, 0.8)
    queue_free()


func _glow_mat(alpha: float, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, alpha)
    if alpha < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.emission_enabled = true
    m.emission = COLOR
    m.emission_energy_multiplier = energy
    return m


func _flash(at: Vector3, radius: float) -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var fx := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    fx.mesh = sphere
    var mat: StandardMaterial3D = _glow_mat(0.6, 2.0)
    fx.material_override = mat
    scene.add_child(fx)
    fx.global_position = at
    fx.scale = Vector3.ONE * 0.3
    var tween := fx.create_tween()
    tween.set_parallel(true)
    tween.tween_property(fx, "scale", Vector3.ONE * radius, 0.25)
    tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
    tween.chain().tween_callback(fx.queue_free)
