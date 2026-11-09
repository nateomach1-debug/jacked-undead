extends RefCounted
## Cheap one-shot CPU particle effects: muzzle flash, hit sparks, blood puffs.
## No lights, no textures. Counts are halved on web and a cap limits how many
## effects can be alive at once.

const GROUP: String = "fx_particles"
const CAP_NATIVE: int = 24
const CAP_WEB: int = 10

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _curve: Curve = null


static func _is_web() -> bool:
    return OS.has_feature("web")


static func _cap_ok(ctx: Node) -> bool:
    if ctx == null or not ctx.is_inside_tree():
        return false
    var cap: int = CAP_WEB if _is_web() else CAP_NATIVE
    return ctx.get_tree().get_node_count_in_group(GROUP) < cap


static func _mat(key: String, color: Color, energy: float) -> StandardMaterial3D:
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = color
    if energy > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = energy
    _mats[key] = m
    return m


static func _sphere(key: String, radius: float) -> SphereMesh:
    if _meshes.has(key):
        return _meshes[key]
    var s := SphereMesh.new()
    s.radius = radius
    s.height = radius * 2.0
    s.radial_segments = 6
    s.rings = 3
    _meshes[key] = s
    return s


static func _shrink() -> Curve:
    if _curve == null:
        _curve = Curve.new()
        _curve.add_point(Vector2(0.0, 1.0))
        _curve.add_point(Vector2(1.0, 0.0))
    return _curve


## parent + pos: a world-space position when local is false, a position local to parent when true.
static func _burst(ctx: Node, parent: Node, pos: Vector3, local: bool, dir: Vector3, amount: int, life: float, vmin: float, vmax: float, spread: float, gravity: Vector3, mesh: Mesh, mat: Material, smin: float, smax: float) -> void:
    if parent == null or not parent.is_inside_tree():
        return
    var p := CPUParticles3D.new()
    p.one_shot = true
    p.emitting = false
    p.amount = maxi(amount, 1)
    p.lifetime = life
    p.explosiveness = 1.0
    p.local_coords = local
    p.direction = dir.normalized() if dir.length() > 0.001 else Vector3.UP
    p.spread = spread
    p.initial_velocity_min = vmin
    p.initial_velocity_max = vmax
    p.gravity = gravity
    p.scale_amount_min = smin
    p.scale_amount_max = smax
    p.scale_amount_curve = _shrink()
    p.mesh = mesh
    p.material_override = mat
    p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    p.add_to_group(GROUP)
    parent.add_child(p)
    if local:
        p.position = pos
    else:
        p.global_position = pos
    p.emitting = true
    ctx.get_tree().create_timer(life + 0.3).timeout.connect(func() -> void:
        if is_instance_valid(p):
            p.queue_free())


## Short bright puff at the barrel. mount = weapon_mount, local_pos = barrel spot relative to it.
static func muzzle_flash(mount: Node3D, local_pos: Vector3) -> void:
    if mount == null or not _cap_ok(mount):
        return
    var amt: int = 2 if _is_web() else 3
    _burst(mount, mount, local_pos, true, Vector3(0, 0, -1), amt, 0.07, 0.5, 1.5, 25.0,
        Vector3.ZERO, _sphere("flash", 0.07), _mat("flash", Color(1.0, 0.8, 0.35), 3.0), 0.8, 1.4)


## Yellow-white sparks bouncing off a wall or floor.
static func sparks(ctx: Node, at: Vector3, normal: Vector3) -> void:
    if not _cap_ok(ctx):
        return
    var amt: int = 3 if _is_web() else 6
    var scene := ctx.get_tree().current_scene
    _burst(ctx, scene, at + normal * 0.03, false, normal, amt, 0.25, 2.5, 5.0, 55.0,
        Vector3(0, -9.0, 0), _sphere("spark", 0.015), _mat("spark", Color(1.0, 0.85, 0.4), 2.5), 0.8, 1.4)


## Dark red puff on a zombie. back = direction from the zombie toward the shooter.
static func blood(ctx: Node, at: Vector3, back: Vector3, headshot: bool) -> void:
    if not _cap_ok(ctx):
        return
    var amt: int = 4 if _is_web() else 8
    if headshot:
        amt = int(float(amt) * 1.5)
    var scene := ctx.get_tree().current_scene
    _burst(ctx, scene, at, false, back + Vector3(0, 0.3, 0), amt, 0.45, 1.5, 3.5, 60.0,
        Vector3(0, -7.0, 0), _sphere("blood", 0.035), _mat("blood", Color(0.55, 0.02, 0.04), 0.0), 0.7, 1.3)

# END OF FILE
