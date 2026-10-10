extends CharacterBody3D
class_name Zombie
## Base "Gym Rat" zombie. Chases the nearest player, follows the navigation mesh
## around walls when the map has one, climbs stairs, slides off corners when
## stuck, and attacks on contact. Subclass (e.g. RoidRager) can override stats
## in _ready() or via exported values on a variant scene.
##
## Pathfinding: maps with a NavigationRegion3D (the Building map, via
## nav_baker.gd) give zombies a route around obstacles. On maps without one
## (the Gym Arena) they fall back to walking straight at the player.
##
## Co-op: the host runs the real zombies. Other phones get "puppet" copies
## (is_puppet = true) that do nothing but show where the host's zombie is.
## Zombies ignore players who are downed or dead.
##
## Look: the body is built in code (see _build_visuals). Only the base zombie
## script builds it; subclasses such as RoidRager keep their own look for now.

signal died(zombie: Zombie)

const GRAVITY: float = 9.8
const HEADSHOT_KILL_GAINS: int = 175  # awarded instead of gains_on_death when the killing shot was a headshot
const MAX_ATTACK_HEIGHT_GAP: float = 2.2  # can't hit you through a floor or ceiling
const STUCK_CHECK_INTERVAL: float = 0.5   # how often to check whether we're making progress
const STUCK_MOVE_THRESHOLD: float = 0.25  # moved less than this (meters) in that time = stuck
const DETOUR_DURATION: float = 0.9        # seconds spent sliding sideways off a corner
const RETARGET_INTERVAL: float = 0.5      # how often to re-pick the nearest player
const SEPARATION_RADIUS: float = 1.0      # zombies closer than this push each other apart
const SEPARATION_STRENGTH: float = 1.5
const SEPARATION_INTERVAL: float = 0.12   # separation is recalculated this often (cheaper)
const LOS_INTERVAL: float = 0.25          # how often to check for a wall between us and the target

# Look settings
const BASE_SCRIPT_END: String = "scripts/zombies/zombie.gd"
const HIDE_OLD_MESHES: bool = true   # hides the old capsule/mesh the scene had; set false to show it again
const MODEL_HEIGHT: float = 1.9      # the code-built body is 1.9 m tall, scaled to the capsule
const SKIN_COLORS: Array = [
    Color(0.45, 0.58, 0.40),
    Color(0.62, 0.65, 0.55),
    Color(0.50, 0.40, 0.45),
    Color(0.55, 0.60, 0.35),
    Color(0.40, 0.50, 0.50),
]
const TANK_COLORS: Array = [
    Color(0.85, 0.15, 0.15),
    Color(0.15, 0.30, 0.80),
    Color(0.12, 0.12, 0.14),
    Color(0.55, 0.55, 0.58),
    Color(0.90, 0.50, 0.10),
    Color(0.10, 0.55, 0.55),
]
const SHORTS_COLORS: Array = [
    Color(0.08, 0.08, 0.10),
    Color(0.10, 0.12, 0.30),
    Color(0.30, 0.30, 0.32),
    Color(0.35, 0.08, 0.08),
]
const BAND_COLORS: Array = [
    Color(0.95, 0.95, 0.95),
    Color(0.9, 0.2, 0.2),
    Color(0.95, 0.8, 0.1),
]

@export var max_health: float = 100.0
@export var move_speed: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0
@export var gains_on_death: int = 100
@export var head_height_threshold: float = 0.5  # local Y above which a hit counts as a headshot
@export var step_height: float = 0.55           # tallest stair step a zombie can walk straight up
@export var repath_interval: float = 0.5        # seconds between path refreshes
@export var waypoint_reach_distance: float = 0.4

var is_puppet: bool = false  # co-op copy of the host's zombie: no AI, takes no damage

var current_health: float
var _target: Node3D
var _attack_timer: float = 0.0
var _is_dead: bool = false
var _last_source: Node = null  # who last hurt this zombie (decides who gets the kill reward)
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _repath_timer: float = 0.0
var _retarget_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_check_position: Vector3 = Vector3.ZERO
var _detour_time: float = 0.0
var _detour_direction: Vector3 = Vector3.ZERO
var _sep_timer: float = 0.0
var _sep_vector: Vector3 = Vector3.ZERO
var _los_timer: float = 0.0
var _has_los: bool = true

# Look / animation state
static var _box_cache: Dictionary = {}
var _visual: Node3D = null
var _visual_base_y: float = 0.0
var _upper: Node3D = null
var _head: Node3D = null
var _leg_l: Node3D = null
var _leg_r: Node3D = null
var _arm_l: Node3D = null
var _arm_r: Node3D = null
var _arm_base_l: float = 1.25
var _arm_base_r: float = 1.25
var _flash_mats: Array[StandardMaterial3D] = []
var _flash_tween: Tween = null
var _anim_started: bool = false
var _last_anim_pos: Vector3 = Vector3.ZERO
var _anim_speed: float = 0.0
var _anim_phase: float = 0.0
var _anim_time: float = 0.0
var _idle_seed: float = 0.0
var _swipe: float = 0.0


func _ready() -> void:
    current_health = max_health
    add_to_group("zombies")
    floor_snap_length = 0.4
    _repath_timer = randf() * repath_interval  # stagger so zombies don't all repath on the same frame
    _sep_timer = randf() * SEPARATION_INTERVAL
    _los_timer = randf() * LOS_INTERVAL
    _find_target()
    _build_visuals()


# ---------- look (all built in code) ----------

static func _box_mesh(size: Vector3) -> BoxMesh:
    var key: String = "%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
    if _box_cache.has(key):
        return _box_cache[key] as BoxMesh
    var bm := BoxMesh.new()
    bm.size = size
    _box_cache[key] = bm
    return bm


func _make_mat(color: Color, rough: float = 0.85, flash: bool = true) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    if flash:
        m.emission_enabled = true
        m.emission = Color(1.0, 0.1, 0.05)
        m.emission_energy_multiplier = 0.0
        _flash_mats.append(m)
    return m


func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = _box_mesh(size)
    mi.material_override = mat
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


func _make_leg(x: float, skin: Material, shorts: Material) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = Vector3(x, 0.9, 0.0)
    _visual.add_child(pivot)
    _part(pivot, Vector3(0.16, 0.9, 0.18), Vector3(0.0, -0.45, 0.0), skin)
    _part(pivot, Vector3(0.19, 0.36, 0.21), Vector3(0.0, -0.14, 0.0), shorts)
    return pivot


func _make_arm(x: float, skin: Material) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = Vector3(x, 0.55, 0.0)
    _upper.add_child(pivot)
    _part(pivot, Vector3(0.12, 0.62, 0.12), Vector3(0.0, -0.31, 0.0), skin)
    return pivot


func _build_visuals() -> void:
    var script_res: Script = get_script() as Script
    if script_res == null or not script_res.resource_path.ends_with(BASE_SCRIPT_END):
        return  # a subclass (Roid Rager) keeps its own look
    if HIDE_OLD_MESHES:
        for n in find_children("*", "MeshInstance3D", true, false):
            (n as MeshInstance3D).visible = false

    var h: float = MODEL_HEIGHT
    var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if shape_node and shape_node.shape is CapsuleShape3D:
        h = (shape_node.shape as CapsuleShape3D).height

    var skin_col: Color = SKIN_COLORS[randi() % SKIN_COLORS.size()]
    skin_col = skin_col.darkened(randf_range(0.0, 0.2))
    var tank_col: Color = TANK_COLORS[randi() % TANK_COLORS.size()]
    tank_col = tank_col.darkened(randf_range(0.1, 0.35))
    var shorts_col: Color = SHORTS_COLORS[randi() % SHORTS_COLORS.size()]
    var skin := _make_mat(skin_col)
    var tank := _make_mat(tank_col)
    var shorts := _make_mat(shorts_col)
    var mouth := _make_mat(Color(0.08, 0.01, 0.01), 0.9, false)
    var blood := _make_mat(Color(0.35, 0.02, 0.02), 0.4, false)
    var eye_col: Color = Color(0.85, 1.0, 0.2) if randf() < 0.7 else Color(1.0, 0.15, 0.1)
    var eye := StandardMaterial3D.new()
    eye.albedo_color = eye_col.darkened(0.4)
    eye.emission_enabled = true
    eye.emission = eye_col
    eye.emission_energy_multiplier = 3.0

    _idle_seed = randf() * TAU
    _visual = Node3D.new()
    _visual.name = "ZombieVisual"
    _visual_base_y = -h * 0.5
    _visual.position = Vector3(0.0, _visual_base_y, 0.0)
    _visual.scale = Vector3.ONE * ((h / MODEL_HEIGHT) * randf_range(0.93, 1.07))
    add_child(_visual)

    # Legs and hips (the front of the zombie is -Z, same as look_at).
    _leg_l = _make_leg(-0.12, skin, shorts)
    _leg_r = _make_leg(0.12, skin, shorts)
    _part(_visual, Vector3(0.5, 0.16, 0.27), Vector3(0.0, 0.92, 0.0), shorts)

    # Upper body leans forward: torso, tank top with blood, head, arms.
    _upper = Node3D.new()
    _upper.position = Vector3(0.0, 0.9, 0.0)
    _upper.rotation.x = -0.22
    _visual.add_child(_upper)
    _part(_upper, Vector3(0.5, 0.62, 0.26), Vector3(0.0, 0.31, 0.0), skin)
    _part(_upper, Vector3(0.52, 0.44, 0.285), Vector3(0.0, 0.25, 0.0), tank)
    _part(_upper, Vector3(0.18, 0.13, 0.01), Vector3(0.09, 0.22, -0.1475), blood)

    _head = Node3D.new()
    _head.position = Vector3(0.0, 0.64, 0.0)
    _head.rotation.x = -0.18
    _upper.add_child(_head)
    _part(_head, Vector3(0.26, 0.28, 0.26), Vector3(0.0, 0.15, 0.0), skin)
    _part(_head, Vector3(0.055, 0.04, 0.02), Vector3(-0.07, 0.19, -0.135), eye)
    _part(_head, Vector3(0.055, 0.04, 0.02), Vector3(0.07, 0.19, -0.135), eye)
    _part(_head, Vector3(0.15, 0.06, 0.02), Vector3(0.0, 0.07, -0.135), mouth)
    if randf() < 0.45:
        var band_col: Color = BAND_COLORS[randi() % BAND_COLORS.size()]
        _part(_head, Vector3(0.275, 0.05, 0.275), Vector3(0.0, 0.24, 0.0), _make_mat(band_col.darkened(0.15), 0.8, false))

    _arm_l = _make_arm(-0.32, skin)
    _arm_r = _make_arm(0.32, skin)
    _arm_base_l = 1.25 + randf_range(-0.2, 0.2)
    _arm_base_r = 1.25 + randf_range(-0.2, 0.2)
    if randf() < 0.25:  # one arm hangs down instead of reaching
        if randf() < 0.5:
            _arm_base_l = 0.35
        else:
            _arm_base_r = 0.35


func _process(delta: float) -> void:
    if _visual == null or _is_dead:
        return
    if not _anim_started:
        _anim_started = true
        _last_anim_pos = global_position
        return

    # Walk speed is measured from how far we actually moved (works for co-op puppets too).
    var cur: Vector3 = global_position
    var flat: float = Vector2(cur.x - _last_anim_pos.x, cur.z - _last_anim_pos.z).length()
    _last_anim_pos = cur
    var spd: float = minf(flat / maxf(delta, 0.0001), 8.0)
    _anim_speed = lerpf(_anim_speed, spd, clampf(delta * 8.0, 0.0, 1.0))
    var amp: float = clampf(_anim_speed / 2.5, 0.0, 1.0)
    _anim_phase += delta * (2.0 + _anim_speed * 2.2)
    _anim_time += delta
    var s: float = sin(_anim_phase)

    # Swipe: a short arm slam right after an attack lands.
    _swipe = 0.0
    if not is_puppet and _attack_timer > 0.0:
        var since: float = attack_cooldown - _attack_timer
        if since >= 0.0 and since < 0.35:
            _swipe = sin(clampf(since / 0.35, 0.0, 1.0) * PI)

    var swing: float = 0.65 * amp
    _leg_l.rotation.x = s * swing
    _leg_r.rotation.x = -s * swing
    _visual.position.y = _visual_base_y + absf(s) * 0.035 * amp
    _upper.rotation.x = -0.22 - _swipe * 0.3
    _upper.rotation.z = s * 0.07 * amp + sin(_anim_time * 1.1 + _idle_seed) * 0.02
    _head.rotation.z = sin(_anim_time * 1.3 + _idle_seed) * 0.14
    _head.rotation.x = -0.18 + sin(_anim_time * 0.9 + _idle_seed) * 0.05
    _arm_l.rotation.x = _arm_base_l + sin(_anim_phase + 1.0) * 0.12 * amp + sin(_anim_time * 1.7 + _idle_seed) * 0.05 - _swipe * 0.9
    _arm_r.rotation.x = _arm_base_r + sin(_anim_phase + 2.2) * 0.12 * amp + sin(_anim_time * 1.5 + _idle_seed) * 0.05 - _swipe * 0.9
    _arm_l.rotation.z = -0.08
    _arm_r.rotation.z = 0.08


## Quick red flash on every shot that doesn't kill.
func _flash_hit() -> void:
    if _visual == null:
        return
    for m in _flash_mats:
        m.emission_energy_multiplier = 2.5
    if _flash_tween != null and _flash_tween.is_valid():
        _flash_tween.kill()
    _flash_tween = create_tween()
    _flash_tween.set_parallel(true)
    for m in _flash_mats:
        _flash_tween.tween_property(m, "emission_energy_multiplier", 0.0, 0.18)


## On death the body is handed to the scene: it falls backwards, lies there a
## few seconds, sinks into the floor and is removed. The zombie itself is freed
## right away so nothing about the round or collision changes.
func _spawn_corpse() -> void:
    if _visual == null or not is_instance_valid(_visual):
        return
    var scene: Node = get_tree().current_scene
    if scene == null:
        return
    var xf: Transform3D = _visual.global_transform
    var body: Node3D = _visual
    _visual = null
    remove_child(body)
    scene.add_child(body)
    body.global_transform = xf
    var y0: float = body.position.y
    var tw := body.create_tween()
    tw.tween_property(body, "rotation:x", PI * 0.5, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(body, "position:y", y0 + 0.1, 0.45)
    tw.tween_interval(3.0)
    tw.tween_property(body, "position:y", y0 - 0.8, 1.2)
    tw.tween_callback(body.queue_free)


## Picks the nearest player who is still up: this phone's player plus any
## co-op players. Becomes null if everyone is downed or dead.
func _find_target() -> void:
    var best: Node3D = null
    var best_dist: float = INF
    for group_name in ["player", "remote_players"]:
        for n in get_tree().get_nodes_in_group(group_name):
            var p := n as Node3D
            if p == null or not is_instance_valid(p):
                continue
            if _is_out(p):
                continue
            var d: float = p.global_position.distance_squared_to(global_position)
            if d < best_dist:
                best_dist = d
                best = p
    _target = best


func _physics_process(delta: float) -> void:
    if is_puppet:
        return

    # Drop a target that went down / died / left right away; re-pick regularly.
    if _target != null and (not is_instance_valid(_target) or _is_out(_target)):
        _target = null
        _retarget_timer = 0.0
    _retarget_timer -= delta
    if _retarget_timer <= 0.0:
        _retarget_timer = RETARGET_INTERVAL
        _find_target()

    if not is_on_floor():
        velocity.y -= GRAVITY * delta
    else:
        velocity.y = 0.0

    if _attack_timer > 0.0:
        _attack_timer -= delta

    _update_separation(delta)
    _update_line_of_sight(delta)

    if _target != null and is_instance_valid(_target):
        var to_target := _target.global_position - global_position
        var vertical_gap: float = absf(to_target.y)
        to_target.y = 0.0
        var distance := to_target.length()

        # Only attack when close in all three axes AND nothing solid is between us
        # (otherwise keep pathing, e.g. around the stair wall to get up to you).
        if distance > attack_range or vertical_gap > MAX_ATTACK_HEIGHT_GAP or not _has_los:
            var direction := _get_move_direction(to_target, delta)
            direction = _apply_unstuck(direction, delta)
            direction = _apply_separation(direction)
            velocity.x = direction.x * move_speed
            velocity.z = direction.z * move_speed
            if direction.length() > 0.01:
                look_at(global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)
        else:
            velocity.x = 0.0
            velocity.z = 0.0
            _stuck_timer = 0.0
            _detour_time = 0.0
            # Heavily overlapped with another zombie: shuffle sideways (around the player).
            if _sep_vector.length() > 0.5 and distance > 0.01:
                var toward: Vector3 = to_target.normalized()
                var sideways: Vector3 = _sep_vector - toward * _sep_vector.dot(toward)
                velocity.x = sideways.x * move_speed * 0.4
                velocity.z = sideways.z * move_speed * 0.4
            if distance > 0.01:
                look_at(Vector3(_target.global_position.x, global_position.y, _target.global_position.z), Vector3.UP)
            _try_attack()
    else:
        # Nobody to chase (everyone downed or dead): stand still.
        velocity.x = 0.0
        velocity.z = 0.0

    _step_up_if_blocked(delta)
    move_and_slide()


## A few times a second, checks whether map geometry (walls, rails, closed doors:
## anything under a "navmesh_source" node) sits between us and the target.
func _update_line_of_sight(delta: float) -> void:
    _los_timer -= delta
    if _los_timer > 0.0:
        return
    _los_timer = LOS_INTERVAL
    _has_los = true
    if _target == null or not is_instance_valid(_target):
        return
    var from_pos: Vector3 = global_position + Vector3(0.0, 0.4, 0.0)
    var to_pos: Vector3 = _target.global_position + Vector3(0.0, 0.4, 0.0)
    var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
    query.exclude = [get_rid()]
    query.collision_mask = 1
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    if _blocks_sight(hit.get("collider")) and not (hit.get("collider") is CharacterBody3D):
        _has_los = false


func _blocks_sight(collider: Object) -> bool:
    var n := collider as Node
    while n != null:
        if n.is_in_group("navmesh_source"):
            return true
        n = n.get_parent()
    return false


## Recalculates the push away from nearby zombies a few times a second.
func _update_separation(delta: float) -> void:
    _sep_timer -= delta
    if _sep_timer > 0.0:
        return
    _sep_timer = SEPARATION_INTERVAL
    var push := Vector3.ZERO
    var radius_sq: float = SEPARATION_RADIUS * SEPARATION_RADIUS
    for n in get_tree().get_nodes_in_group("zombies"):
        if n == self:
            continue
        var other := n as Node3D
        if other == null or not is_instance_valid(other):
            continue
        var offset: Vector3 = global_position - other.global_position
        offset.y = 0.0
        var d_sq: float = offset.length_squared()
        if d_sq >= radius_sq:
            continue
        if d_sq < 0.0001:
            offset = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
            d_sq = maxf(offset.length_squared(), 0.0001)
        var d: float = sqrt(d_sq)
        push += (offset / d) * (1.0 - d / SEPARATION_RADIUS)
    _sep_vector = push


## Bends the walking direction away from nearby zombies so they don't stack.
func _apply_separation(direction: Vector3) -> Vector3:
    if _sep_vector == Vector3.ZERO:
        return direction
    var mixed: Vector3 = direction + _sep_vector * SEPARATION_STRENGTH
    mixed.y = 0.0
    if mixed.length() < 0.01:
        return direction
    return mixed.normalized()


## Which way to walk this frame: along the navigation path if there is one,
## otherwise straight at the player.
func _get_move_direction(to_target: Vector3, delta: float) -> Vector3:
    _repath_timer -= delta
    if _repath_timer <= 0.0:
        _repath_timer = repath_interval
        _refresh_path()

    while _path_index < _path.size():
        var point := _path[_path_index]
        var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
        var dy: float = absf(point.y - _feet_y())
        if flat.length() < waypoint_reach_distance and dy < 1.0:
            _path_index += 1
        elif flat.length() < 0.05:
            _path_index += 1  # straight above/below this point: skip it instead of freezing
        else:
            return flat.normalized()

    if to_target.length() < 0.05:
        return -global_transform.basis.z  # target straight above/below: keep moving, never freeze
    return to_target.normalized()


## World Y of this zombie's feet (the body origin is the middle of its capsule).
func _feet_y() -> float:
    var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if shape_node and shape_node.shape is CapsuleShape3D:
        return global_position.y - (shape_node.shape as CapsuleShape3D).height * 0.5
    return global_position.y - 0.95


func _refresh_path() -> void:
    _path = PackedVector3Array()
    _path_index = 0
    if _target == null or not is_instance_valid(_target):
        return
    var nav_map: RID = get_world_3d().navigation_map
    if NavigationServer3D.map_get_regions(nav_map).is_empty():
        return  # this map has no navigation mesh: walk straight at the player
    if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
        return  # navigation mesh not ready yet
    var from_pos := Vector3(global_position.x, _feet_y(), global_position.z)
    var to_pos := Vector3(_target.global_position.x, _target.global_position.y - 0.9, _target.global_position.z)
    _path = NavigationServer3D.map_get_path(nav_map, from_pos, to_pos, true)


## If we've barely moved for half a second while trying to chase, get a fresh
## route and slide sideways along the wall for a moment to clear the corner.
func _apply_unstuck(direction: Vector3, delta: float) -> Vector3:
    _stuck_timer += delta
    if _stuck_timer >= STUCK_CHECK_INTERVAL:
        _stuck_timer = 0.0
        var moved: float = global_position.distance_to(_last_check_position)
        _last_check_position = global_position
        if moved < STUCK_MOVE_THRESHOLD and _detour_time <= 0.0:
            _refresh_path()
            _start_detour(direction)

    if _detour_time > 0.0:
        _detour_time -= delta
        return _detour_direction
    return direction


func _start_detour(direction: Vector3) -> void:
    var tangent: Vector3 = Vector3.ZERO
    var away: Vector3 = Vector3.ZERO
    if is_on_wall():
        var normal: Vector3 = get_wall_normal()
        normal.y = 0.0
        if normal.length() > 0.01:
            normal = normal.normalized()
            tangent = normal.cross(Vector3.UP).normalized()
            var side: float = tangent.dot(direction)
            if absf(side) < 0.1:
                if randf() < 0.5:
                    tangent = -tangent
            elif side < 0.0:
                tangent = -tangent
            away = normal * 0.3  # a little push off the wall so we clear the corner
    if tangent.length() < 0.01:
        tangent = Vector3(-direction.z, 0.0, direction.x)
        if randf() < 0.5:
            tangent = -tangent
    _detour_direction = (tangent + away).normalized()
    _detour_time = DETOUR_DURATION


## True only if something ahead would stop us AND it is not a walkable slope.
func _blocked_by_steep(motion: Vector3) -> bool:
    var params := PhysicsTestMotionParameters3D.new()
    params.from = global_transform
    params.motion = motion
    params.max_collisions = 4
    var result := PhysicsTestMotionResult3D.new()
    if not PhysicsServer3D.body_test_motion(get_rid(), params, result):
        return false
    for i in result.get_collision_count():
        if result.get_collision_normal(i).angle_to(Vector3.UP) > deg_to_rad(30.0):
            return true
    return false


## Same trick as the player: CharacterBody3D can't climb steps on its own, so
## if walking forward would hit something but stepping up clears it, nudge up.
func _step_up_if_blocked(delta: float) -> void:
    if not is_on_floor():
        return
    var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
    if motion.length() < 0.001:
        return
    if not _blocked_by_steep(motion):
        return
    var raised := global_transform
    raised.origin += Vector3(0.0, step_height, 0.0)
    if test_move(raised, motion):
        return  # still blocked even raised: a real wall, not a step
    global_position.y += step_height


## Hits whoever we're chasing. A co-op player on another phone is a capsule
## here, so the damage is sent over the network to that phone.
func _try_attack() -> void:
    if _attack_timer > 0.0 or _target == null:
        return
    var dmg: float = GameManager.get_zombie_damage(attack_damage)
    if _target.has_method("take_damage"):
        _target.take_damage(dmg)
    elif _target.has_meta("peer_id"):
        NetManager.damage_peer(int(_target.get_meta("peer_id")), dmg)
    else:
        return
    _attack_timer = attack_cooldown


func is_headshot(world_hit_position: Vector3) -> bool:
    return (world_hit_position.y - global_position.y) >= head_height_threshold


func take_damage(amount: float, source: Node = null, was_headshot: bool = false) -> void:
    if _is_dead:
        return
    if is_puppet:
        _flash_hit()
        _forward_hit_to_host(amount, was_headshot)
        return
    _last_source = source
    current_health -= amount
    if current_health <= 0.0:
        _die(was_headshot)
    else:
        _flash_hit()


## Co-op: a puppet can't die on its own, so it tells the host it was hit.
func _forward_hit_to_host(amount: float, was_headshot: bool) -> void:
    var coop = get_tree().current_scene.get_node_or_null("CoopSync")
    if coop != null and coop.has_method("send_hit") and has_meta("net_id"):
        coop.send_hit(int(get_meta("net_id")), amount, was_headshot)


func _die(was_headshot: bool = false) -> void:
    _is_dead = true
    var reward: int = HEADSHOT_KILL_GAINS if was_headshot else gains_on_death
    # A kill by a co-op player pays that player's phone; otherwise it pays the host.
    if _last_source != null and is_instance_valid(_last_source) and _last_source.has_meta("peer_id"):
        NetManager.reward_kill(int(_last_source.get_meta("peer_id")), reward, was_headshot)
    else:
        GameManager.add_gains(reward)
        GameManager.add_kill(was_headshot)
    _spawn_corpse()
    died.emit(self)
    queue_free()


## True for a co-op player who is downed or dead: zombies ignore them.
func _is_out(p: Node) -> bool:
    return bool(p.get("is_downed")) or bool(p.get("is_dead")) or bool(p.get_meta("downed", false)) or bool(p.get_meta("dead", false))
