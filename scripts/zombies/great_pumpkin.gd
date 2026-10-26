
extends Zombie

const BASE_HEALTH: float = 1200.0
const BOSS_SCALE: float = 2.3
const BASE_MOVE_SPEED: float = 1.55
const PHASE_TWO_SPEED_MULTIPLIER: float = 1.35
const BASE_ATTACK_DAMAGE: float = 35.0
const BASE_ATTACK_RANGE: float = 2.8
const BASE_ATTACK_COOLDOWN: float = 2.2
const BOSS_GAINS_REWARD: int = 2500

const MINIMUM_SPAWN_ROUND: int = 5
const SPAWN_CHANCE: float = 0.15
const MIN_ROUNDS_BETWEEN_SPAWNS: int = 5

const SLAM_RANGE: float = 9.0
const SLAM_RADIUS: float = 5.0
const SLAM_DAMAGE: float = 35.0
const SLAM_TELEGRAPH_SECONDS: float = 1.0
const SLAM_COOLDOWN: float = 8.0
const PHASE_TWO_SLAM_COOLDOWN: float = 4.5

const BOMB_COOLDOWN: float = 9.0
const BOMB_DAMAGE: float = 25.0
const BOMB_RADIUS: float = 3.5
const BOMB_FLIGHT_SECONDS: float = 1.3
const BOMBS_PER_VOLLEY: int = 3

const HEADSHOT_MARGIN: float = 0.55
const BOSS_UI_PATH: String = "res://scripts/ui/boss_health_bar.gd"
const BOMB_SCRIPT_PATH: String = "res://scripts/zombies/pumpkin_bomb.gd"
const SUPPLEMENT_DROP_PATH: String = "res://scripts/pickups/supplement_reward_drop.gd"

static var _shared_meshes: Dictionary = {}
static var _shared_materials: Dictionary = {}

var phase_two: bool = false
var _slam_timer: float = 3.0
var _bomb_timer: float = 5.0
var _state_timer: float = 0.0
var _boss_ui: Node = null
var _pumpkin_material: StandardMaterial3D = null
var _face_material: StandardMaterial3D = null


func _ready() -> void:
    max_health = BASE_HEALTH
    move_speed = BASE_MOVE_SPEED
    attack_damage = BASE_ATTACK_DAMAGE
    attack_range = BASE_ATTACK_RANGE
    attack_cooldown = BASE_ATTACK_COOLDOWN
    gains_on_death = BOSS_GAINS_REWARD
    headshot_kill_gains = BOSS_GAINS_REWARD
    head_height_threshold = 1.0
    max_lift_fraction = 0.08
    super._ready()

    add_to_group("great_pumpkin")
    _slam_timer = 3.0
    _bomb_timer = 5.0
    _create_boss_ui()


func _process(delta: float) -> void:
    super._process(delta)

    if _is_dead:
        return

    if not is_puppet:
        _update_phase()

        _state_timer -= delta
        if _state_timer <= 0.0:
            _state_timer = 0.15
            if NetManager.is_online and NetManager.is_host and has_meta("net_id"):
                var coop = get_tree().current_scene.get_node_or_null("CoopSync")
                if coop != null and coop.has_method("broadcast_pumpkin_state"):
                    coop.broadcast_pumpkin_state(
                        int(get_meta("net_id")),
                        current_health,
                        max_health,
                        phase_two
                    )


func _physics_process(delta: float) -> void:
    if is_puppet:
        return

    super._physics_process(delta)

    if _is_dead or _target == null or not is_instance_valid(_target):
        return

    _slam_timer -= delta
    _bomb_timer -= delta

    var distance: float = global_position.distance_to(_target.global_position)

    if distance <= SLAM_RANGE and _slam_timer <= 0.0:
        _slam_timer = PHASE_TWO_SLAM_COOLDOWN if phase_two else SLAM_COOLDOWN
        _start_slam(_target.global_position)
    elif _bomb_timer <= 0.0:
        _bomb_timer = BOMB_COOLDOWN * (0.7 if phase_two else 1.0)
        _throw_bombs()


func _update_phase() -> void:
    if phase_two or current_health > max_health * 0.5:
        return

    phase_two = true
    move_speed = BASE_MOVE_SPEED * PHASE_TWO_SPEED_MULTIPLIER

    if _pumpkin_material != null:
        _pumpkin_material.albedo_color = Color(0.85, 0.12, 0.025)
        _pumpkin_material.emission = Color(0.9, 0.04, 0.01)
        _pumpkin_material.emission_energy_multiplier = 0.45

    if _face_material != null:
        _face_material.albedo_color = Color(0.18, 0.015, 0.005)


func is_headshot(world_hit_position: Vector3) -> bool:
    if _head == null or not is_instance_valid(_head):
        return super.is_headshot(world_hit_position)

    var head_center: Vector3 = _head.to_global(Vector3.ZERO)
    return world_hit_position.y >= head_center.y - HEADSHOT_MARGIN * BOSS_SCALE


func _build_visuals() -> void:
    if HIDE_OLD_MESHES:
        for n in find_children("*", "MeshInstance3D", true, false):
            (n as MeshInstance3D).visible = false

    var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
    var body_height: float = 4.4
    if shape_node != null and shape_node.shape is CapsuleShape3D:
        body_height = (shape_node.shape as CapsuleShape3D).height

    var skin := _make_mat(Color(0.24, 0.31, 0.16))
    var shirt := _make_mat(Color(0.12, 0.16, 0.10))
    var shorts := _make_mat(Color(0.12, 0.07, 0.035))
    var dark := _make_mat(Color(0.035, 0.018, 0.008), 0.9, false)
    var orange := _make_mat(Color(0.95, 0.29, 0.025), 0.8, false)
    var green := _make_mat(Color(0.13, 0.32, 0.055), 0.8, false)

    _pumpkin_material = orange
    _face_material = dark

    _visual = Node3D.new()
    _visual.name = "GreatPumpkinVisual"
    _visual.position = Vector3(0.0, -body_height * 0.5, 0.0)
    _visual.scale = Vector3.ONE * BOSS_SCALE
    add_child(_visual)

    _leg_l = _make_leg(-0.19, skin, shorts)
    _leg_r = _make_leg(0.19, skin, shorts)
    _part(_visual, Vector3(0.58, 0.18, 0.32), Vector3(0.0, 0.92, 0.0), shorts)

    _upper = Node3D.new()
    _upper.position = Vector3(0.0, 0.9, 0.0)
    _upper.rotation.x = -0.12
    _visual.add_child(_upper)

    _part(_upper, Vector3(0.72, 0.65, 0.42), Vector3(0.0, 0.35, 0.0), skin)
    _part(_upper, Vector3(0.82, 0.48, 0.45), Vector3(0.0, 0.35, 0.0), shirt)
    _part(_upper, Vector3(0.18, 0.12, 0.02), Vector3(0.12, 0.35, -0.235), orange)

    _head = Node3D.new()
    _head.position = Vector3(0.0, 0.91, -0.02)
    _upper.add_child(_head)

    _put_mesh(
        _head,
        _mesh_sphere(0.43),
        Vector3.ZERO,
        orange,
        Vector3.ONE,
        Vector3.ZERO
    )

    var stem := _mesh_cylinder(0.06, 0.10, 0.22)
    _put_mesh(_head, stem, Vector3(0.0, 0.49, 0.0), green, Vector3.ONE, Vector3(0.0, 0.0, -0.2))

    for side in [-1.0, 1.0]:
        _put_mesh(
            _head,
            _mesh_sphere(0.075),
            Vector3(side * 0.16, 0.12, -0.35),
            dark,
            Vector3(1.0, 1.25, 0.35),
            Vector3.ZERO
        )

    _put_mesh(
        _head,
        _mesh_box(Vector3(0.30, 0.07, 0.035)),
        Vector3(0.0, -0.14, -0.40),
        dark,
        Vector3.ONE,
        Vector3.ZERO
    )

    for x in [-0.11, 0.0, 0.11]:
        _put_mesh(
            _head,
            _mesh_box(Vector3(0.045, 0.07, 0.025)),
            Vector3(x, -0.15, -0.425),
            orange,
            Vector3.ONE,
            Vector3.ZERO
        )

    _arm_l = _make_arm(-0.46, skin)
    _arm_r = _make_arm(0.46, skin)
    _arm_base_l = 1.0
    _arm_base_r = 1.0


func _put_mesh(
    parent: Node3D,
    mesh: Mesh,
    pos: Vector3,
    mat: Material,
    scl: Vector3,
    rot: Vector3
) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = pos
    instance.scale = scl
    instance.rotation = rot
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(instance)
    return instance


static func _mesh_sphere(radius: float) -> SphereMesh:
    var key: String = "sphere_%.2f" % radius
    if not _shared_meshes.has(key):
        var mesh := SphereMesh.new()
        mesh.radius = radius
        mesh.height = radius * 2.0
        mesh.radial_segments = 10
        mesh.rings = 5
        _shared_meshes[key] = mesh
    return _shared_meshes[key] as SphereMesh


static func _mesh_box(size: Vector3) -> BoxMesh:
    var key: String = "box_%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
    if not _shared_meshes.has(key):
        var mesh := BoxMesh.new()
        mesh.size = size
        _shared_meshes[key] = mesh
    return _shared_meshes[key] as BoxMesh


static func _mesh_cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
    var key: String = "cylinder_%.2f_%.2f_%.2f" % [top, bottom, height]
    if not _shared_meshes.has(key):
        var mesh := CylinderMesh.new()
        mesh.top_radius = top
        mesh.bottom_radius = bottom
        mesh.height = height
        mesh.radial_segments = 8
        mesh.rings = 1
        _shared_meshes[key] = mesh
    return _shared_meshes[key] as CylinderMesh


func _create_boss_ui() -> void:
    var script := load(BOSS_UI_PATH) as Script
    if script == null:
        push_warning("Great Pumpkin: boss UI script could not be loaded.")
        return

    var ui = script.new()
    if ui == null:
        return

    ui.name = "GreatPumpkinHealthBar"
    get_tree().current_scene.add_child(ui)
    _boss_ui = ui
    if ui.has_method("bind_boss"):
        ui.bind_boss(self)


func _start_slam(target_position: Vector3) -> void:
    var impact_position: Vector3 = target_position
    impact_position.y = 0.04

    show_slam_visual(impact_position, SLAM_RADIUS, SLAM_TELEGRAPH_SECONDS)

    if NetManager.is_online and NetManager.is_host and has_meta("net_id"):
        var coop = get_tree().current_scene.get_node_or_null("CoopSync")
        if coop != null and coop.has_method("broadcast_pumpkin_slam"):
            coop.broadcast_pumpkin_slam(
                int(get_meta("net_id")),
                impact_position,
                SLAM_RADIUS,
                SLAM_TELEGRAPH_SECONDS
            )

    await get_tree().create_timer(SLAM_TELEGRAPH_SECONDS).timeout
    if not is_instance_valid(self) or _is_dead:
        return

    _damage_players(impact_position, SLAM_RADIUS, SLAM_DAMAGE)


func show_slam_visual(pos: Vector3, radius: float, duration: float) -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.88
    torus.outer_radius = 1.0
    torus.rings = 4
    torus.ring_segments = 16
    ring.mesh = torus

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0, 0.25, 0.015, 0.95)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring.material_override = mat
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    scene.add_child(ring)
    ring.global_position = pos
    ring.scale = Vector3(0.1, 1.0, 0.1)

    var tw := ring.create_tween()
    tw.set_parallel(true)
    tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), duration)
    tw.tween_property(mat, "albedo_color:a", 0.0, duration)
    tw.chain().tween_callback(ring.queue_free)


func _throw_bombs() -> void:
    var targets := PackedVector3Array()

    var players: Array = []
    for group_name in ["player", "remote_players"]:
        for node in get_tree().get_nodes_in_group(group_name):
            if not is_instance_valid(node) or _player_is_out(node):
                continue
            if node is Node3D:
                players.append(node)

    if players.is_empty():
        return

    players.shuffle()
    var count: int = mini(BOMBS_PER_VOLLEY, players.size())
    for i in range(count):
        var target: Vector3 = (players[i] as Node3D).global_position
        target.y = 0.05
        targets.append(target)

    var start: Vector3 = global_position + Vector3(0.0, 2.8, 0.0)
    _spawn_bombs(start, targets, false)

    if NetManager.is_online and NetManager.is_host and has_meta("net_id"):
        var coop = get_tree().current_scene.get_node_or_null("CoopSync")
        if coop != null and coop.has_method("broadcast_pumpkin_bombs"):
            coop.broadcast_pumpkin_bombs(int(get_meta("net_id")), start, targets)


func show_network_bombs(start: Vector3, targets: PackedVector3Array) -> void:
    _spawn_bombs(start, targets, true)


func _spawn_bombs(start: Vector3, targets: PackedVector3Array, visual_only: bool) -> void:
    var script := load(BOMB_SCRIPT_PATH) as Script
    if script == null:
        push_warning("Great Pumpkin: pumpkin_bomb.gd could not be loaded.")
        return

    for target in targets:
        var bomb = script.new()
        if bomb == null:
            continue
        bomb.setup(start, target, BOMB_DAMAGE, BOMB_RADIUS, BOMB_FLIGHT_SECONDS, visual_only)
        get_tree().current_scene.add_child(bomb)
        bomb.global_position = start


func _damage_players(center: Vector3, radius: float, damage: float) -> void:
    if NetManager.is_online and not NetManager.is_host:
        return

    for group_name in ["player", "remote_players"]:
        for node in get_tree().get_nodes_in_group(group_name):
            if not is_instance_valid(node) or _player_is_out(node):
                continue
            if not node is Node3D:
                continue

            var player := node as Node3D
            var player_center: Vector3 = player.global_position + Vector3(0.0, 0.9, 0.0)
            if player_center.distance_to(center) > radius:
                continue

            if player.has_method("take_damage"):
                player.take_damage(damage, center)
            elif player.has_meta("peer_id"):
                NetManager.damage_peer(int(player.get_meta("peer_id")), damage)


func _player_is_out(player: Node) -> bool:
    return (
        bool(player.get("is_downed"))
        or bool(player.get("is_dead"))
        or bool(player.get_meta("downed", false))
        or bool(player.get_meta("dead", false))
    )

func _spawn_corpse() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return

    if _boss_ui != null and is_instance_valid(_boss_ui):
        _boss_ui.queue_free()
        _boss_ui = null

    var orange := _chunk_material()
    var chunk_count: int = 9

    for i in range(chunk_count):
        var chunk := MeshInstance3D.new()
        chunk.mesh = _mesh_sphere(0.16 if i % 2 == 0 else 0.22)
        chunk.material_override = orange
        chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        scene.add_child(chunk)

        var offset := Vector3(
            randf_range(-0.8, 0.8),
            randf_range(0.4, 2.2),
            randf_range(-0.8, 0.8)
        )
        chunk.global_position = global_position + offset
        chunk.scale = Vector3.ONE * randf_range(0.7, 1.5)

        var tw := chunk.create_tween()
        tw.set_parallel(true)
        tw.tween_property(
            chunk,
            "global_position",
            chunk.global_position + Vector3(offset.x * 1.8, -randf_range(0.1, 0.8), offset.z * 1.8),
            0.65
        )
        tw.tween_property(
            chunk,
            "rotation",
            Vector3(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0), randf_range(-3.0, 3.0)),
            0.65
        )
        tw.chain().tween_interval(0.35)
        tw.tween_property(chunk, "scale", Vector3.ZERO, 0.3)
        tw.tween_callback(chunk.queue_free)

    _spawn_supplement_reward()


static func _chunk_material() -> StandardMaterial3D:
    if not _shared_materials.has("pumpkin_chunks"):
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.95, 0.28, 0.02)
        mat.roughness = 0.85
        _shared_materials["pumpkin_chunks"] = mat
    return _shared_materials["pumpkin_chunks"] as StandardMaterial3D


func _spawn_supplement_reward() -> void:
    var script := load(SUPPLEMENT_DROP_PATH) as Script
    if script == null:
        push_warning("Great Pumpkin: supplement reward script could not be loaded.")
        return

    var drop = script.new()
    if drop == null:
        return

    get_tree().current_scene.add_child(drop)
    drop.global_position = Vector3(global_position.x, 0.05, global_position.z)
