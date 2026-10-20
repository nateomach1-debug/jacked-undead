extends RefCounted
## New zombie look for zombie.gd (NEW_LOOK = true there): rounded body, rot detail
## (ribs, torn flesh, bandages, hanging jaw), gym gear (towel, lifting belt,
## headphones, stuck plate), extra animation (limp, head twitch, hit stagger,
## rising from the ground) and gore (blood on hits, head pop on headshot kills).
## Everything here is static. zombie.gd calls it through a load()ed script,
## so if this file is missing the classic look is used instead.

const TOWEL_COLORS: Array = [
    Color(0.92, 0.92, 0.92),
    Color(0.55, 0.75, 0.95),
    Color(0.85, 0.20, 0.20),
    Color(0.30, 0.30, 0.34),
]
const CUP_COLORS: Array = [
    Color(0.90, 0.15, 0.15),
    Color(0.15, 0.40, 0.90),
    Color(0.95, 0.80, 0.10),
]

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}
static var _scene_id: int = 0
static var _blood_live: int = 0
static var _splat_live: int = 0


# ---------- shared meshes and materials ----------

static func _sphere() -> SphereMesh:
    var m = _meshes.get("sphere")
    if m != null:
        return m as SphereMesh
    var s := SphereMesh.new()
    s.radius = 0.5
    s.height = 1.0
    s.radial_segments = 12
    s.rings = 6
    _meshes["sphere"] = s
    return s


static func _capsule(radius: float, height: float) -> CapsuleMesh:
    var key: String = "cap_%.3f_%.3f" % [radius, height]
    var m = _meshes.get(key)
    if m != null:
        return m as CapsuleMesh
    var c := CapsuleMesh.new()
    c.radius = radius
    c.height = height
    c.radial_segments = 10
    c.rings = 3
    _meshes[key] = c
    return c


static func _boxm(size: Vector3) -> BoxMesh:
    var key: String = "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
    var m = _meshes.get(key)
    if m != null:
        return m as BoxMesh
    var b := BoxMesh.new()
    b.size = size
    _meshes[key] = b
    return b


static func _cylm(radius: float, height: float) -> CylinderMesh:
    var key: String = "cyl_%.3f_%.3f" % [radius, height]
    var m = _meshes.get(key)
    if m != null:
        return m as CylinderMesh
    var c := CylinderMesh.new()
    c.top_radius = radius
    c.bottom_radius = radius
    c.height = height
    c.radial_segments = 12
    c.rings = 1
    _meshes[key] = c
    return c


static func _torusm(inner: float, outer: float) -> TorusMesh:
    var key: String = "tor_%.3f_%.3f" % [inner, outer]
    var m = _meshes.get(key)
    if m != null:
        return m as TorusMesh
    var t := TorusMesh.new()
    t.inner_radius = inner
    t.outer_radius = outer
    t.rings = 14
    t.ring_segments = 6
    _meshes[key] = t
    return t


static func _smat(key: String, color: Color, rough: float = 0.8, glow: float = 0.0) -> StandardMaterial3D:
    var existing = _mats.get(key)
    if existing != null:
        return existing as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    _mats[key] = m
    return m


static func _eye_mat(green: bool) -> StandardMaterial3D:
    var key: String = "eye_green" if green else "eye_red"
    var existing = _mats.get(key)
    if existing != null:
        return existing as StandardMaterial3D
    var bright: Color = Color(0.85, 1.0, 0.2) if green else Color(1.0, 0.15, 0.1)
    var m := StandardMaterial3D.new()
    m.albedo_color = bright.darkened(0.4)
    m.emission_enabled = true
    m.emission = bright
    m.emission_energy_multiplier = 3.0
    _mats[key] = m
    return m


static func _inst(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    mi.rotation = rot
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


## Ellipsoid with the given full size (width, height, depth).
static func _ell(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _sphere(), pos, mat, size, rot)


static func _cap(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _capsule(radius, height), pos, mat, scl, rot)


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _boxm(size), pos, mat, Vector3.ONE, rot)


static func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _cylm(radius, height), pos, mat, scl, rot)


static func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, mat: Material, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _torusm(inner, outer), pos, mat, scl, rot)


# ---------- body parts ----------

static func _make_leg(z: Zombie, x: float, skin: Material, shorts: Material, wound_mat: Material, bandaged: bool, wounded: bool) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = Vector3(x, 0.9, 0.0)
    z._visual.add_child(pivot)
    _cap(pivot, 0.085, 0.9, Vector3(0.0, -0.45, 0.0), skin)
    _cap(pivot, 0.105, 0.4, Vector3(0.0, -0.15, 0.0), shorts)
    _box(pivot, Vector3(0.14, 0.09, 0.28), Vector3(0.0, -0.865, -0.05), _smat("shoe", Color(0.06, 0.06, 0.07), 0.7))
    if bandaged:
        _cyl(pivot, 0.098, 0.18, Vector3(0.0, -0.62, 0.0), _smat("bandage", Color(0.82, 0.78, 0.66), 0.9))
        _box(pivot, Vector3(0.05, 0.05, 0.01), Vector3(0.02, -0.62, -0.098), _smat("blood_dark", Color(0.35, 0.02, 0.02), 0.4))
    if wounded:
        var side: float = 1.0 if x > 0.0 else -1.0
        _ell(pivot, Vector3(0.1, 0.16, 0.07), Vector3(side * 0.03, -0.42, -0.06), wound_mat)
        _box(pivot, Vector3(0.025, 0.09, 0.02), Vector3(side * 0.03, -0.42, -0.095), _smat("bone", Color(0.86, 0.83, 0.72), 0.6))
    return pivot


static func _make_arm(z: Zombie, x: float, skin: Material, wound_mat: Material, bandaged: bool, wounded: bool) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = Vector3(x, 0.55, 0.0)
    z._upper.add_child(pivot)
    _cap(pivot, 0.055, 0.64, Vector3(0.0, -0.30, 0.0), skin)
    _ell(pivot, Vector3(0.11, 0.15, 0.10), Vector3(0.0, -0.66, 0.0), skin)
    if bandaged:
        _cyl(pivot, 0.066, 0.17, Vector3(0.0, -0.45, 0.0), _smat("bandage", Color(0.82, 0.78, 0.66), 0.9))
        _box(pivot, Vector3(0.04, 0.04, 0.01), Vector3(0.0, -0.45, -0.066), _smat("blood_dark", Color(0.35, 0.02, 0.02), 0.4))
    if wounded:
        _ell(pivot, Vector3(0.09, 0.15, 0.07), Vector3(0.0, -0.26, -0.035), wound_mat)
        _box(pivot, Vector3(0.025, 0.1, 0.025), Vector3(0.01, -0.28, -0.06), _smat("bone", Color(0.86, 0.83, 0.72), 0.6))
    return pivot


## Red neck stump shown after a head pop (hidden until then).
static func _make_stump(parent: Node3D, pos: Vector3) -> Node3D:
    var stump := Node3D.new()
    stump.position = pos
    stump.rotation.x = -0.18
    stump.visible = false
    parent.add_child(stump)
    _cyl(stump, 0.055, 0.1, Vector3(0.0, 0.02, 0.0), _smat("flesh", Color(0.5, 0.06, 0.08), 0.35))
    _cyl(stump, 0.02, 0.12, Vector3(0.0, 0.04, 0.0), _smat("bone", Color(0.86, 0.83, 0.72), 0.6))
    return stump


# ---------- build ----------

## Builds the new body under the zombie. Returns false if it could not.
static func build(z: Zombie) -> bool:
    var h: float = Zombie.MODEL_HEIGHT
    var shape_node := z.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if shape_node and shape_node.shape is CapsuleShape3D:
        h = (shape_node.shape as CapsuleShape3D).height

    var skin_col: Color = Zombie.SKIN_COLORS[randi() % Zombie.SKIN_COLORS.size()]
    skin_col = skin_col.lerp(Color(0.5, 0.5, 0.45), randf_range(0.0, 0.3)).darkened(randf_range(0.0, 0.25))
    var tank_col: Color = Zombie.TANK_COLORS[randi() % Zombie.TANK_COLORS.size()]
    tank_col = tank_col.darkened(randf_range(0.1, 0.4))
    var shorts_col: Color = Zombie.SHORTS_COLORS[randi() % Zombie.SHORTS_COLORS.size()]

    var skin := z._make_mat(skin_col)
    var tank := z._make_mat(tank_col)
    var shorts := z._make_mat(shorts_col)
    var wound := z._make_mat(skin_col.darkened(0.5).lerp(Color(0.4, 0.06, 0.08), 0.6), 0.45, false)
    var flesh := _smat("flesh", Color(0.5, 0.06, 0.08), 0.35)
    var bone := _smat("bone", Color(0.86, 0.83, 0.72), 0.6)
    var bandage := _smat("bandage", Color(0.82, 0.78, 0.66), 0.9)
    var mouth := _smat("mouth", Color(0.08, 0.01, 0.01), 0.9)
    var blood := _smat("blood_dark", Color(0.35, 0.02, 0.02), 0.4)
    var eye := _eye_mat(randf() < 0.7)

    z._idle_seed = randf() * TAU
    var vis := Node3D.new()
    vis.name = "ZombieVisual"
    z._visual_base_y = -h * 0.5
    vis.position = Vector3(0.0, z._visual_base_y, 0.0)
    vis.scale = Vector3.ONE * ((h / Zombie.MODEL_HEIGHT) * randf_range(0.93, 1.07))
    z.add_child(vis)
    z._visual = vis

    var limp: float = 0.0
    if randf() < 0.3:
        limp = randf_range(0.6, 1.0)

    # Legs and hips (the front of the zombie is -Z).
    z._leg_l = _make_leg(z, -0.12, skin, shorts, wound, randf() < 0.15, randf() < 0.12)
    z._leg_r = _make_leg(z, 0.12, skin, shorts, wound, limp > 0.0 or randf() < 0.2, limp > 0.0 and randf() < 0.6)
    _ell(vis, Vector3(0.5, 0.2, 0.28), Vector3(0.0, 0.93, 0.0), shorts)

    # Upper body leans forward.
    var upper := Node3D.new()
    upper.position = Vector3(0.0, 0.9, 0.0)
    upper.rotation.x = -0.22
    vis.add_child(upper)
    z._upper = upper
    _ell(upper, Vector3(0.5, 0.7, 0.29), Vector3(0.0, 0.33, 0.0), skin)
    _ell(upper, Vector3(0.53, 0.46, 0.31), Vector3(0.0, 0.26, 0.0), tank)
    _ell(upper, Vector3(0.2, 0.14, 0.03), Vector3(0.09, 0.22, -0.14), blood)

    # Torn tank top with exposed ribs on one side.
    if randf() < 0.6:
        var side: float = 1.0 if randf() < 0.5 else -1.0
        _ell(upper, Vector3(0.2, 0.22, 0.04), Vector3(side * 0.1, 0.34, -0.148), flesh)
        for i in range(4):
            _box(upper, Vector3(0.17, 0.018, 0.02), Vector3(side * 0.1, 0.26 + float(i) * 0.055, -0.172), bone, Vector3(0.0, 0.0, side * 0.15))

    # Torn flesh patches.
    if randf() < 0.7:
        _ell(upper, Vector3(0.14, 0.16, 0.05), Vector3(randf_range(-0.12, 0.12), randf_range(0.2, 0.5), 0.14), wound)
    if randf() < 0.4:
        _ell(upper, Vector3(0.11, 0.09, 0.04), Vector3(randf_range(-0.1, 0.1), 0.52, -0.125), wound)

    # Gym gear: lifting belt.
    if randf() < 0.35:
        _ell(upper, Vector3(0.40, 0.12, 0.25), Vector3(0.0, 0.08, 0.0), _smat("belt", Color(0.07, 0.06, 0.06), 0.6))
        _box(upper, Vector3(0.07, 0.07, 0.02), Vector3(0.0, 0.08, -0.125), _smat("buckle", Color(0.8, 0.65, 0.15), 0.3))

    # Gym gear: towel around the neck.
    if randf() < 0.35:
        var towel := _smat("towel_%d" % (randi() % TOWEL_COLORS.size()), TOWEL_COLORS[randi() % TOWEL_COLORS.size()], 0.9)
        _torus(upper, 0.09, 0.15, Vector3(0.0, 0.64, 0.0), towel, Vector3(1.0, 1.0, 0.8))
        _box(upper, Vector3(0.07, 0.32, 0.015), Vector3(-0.05, 0.47, -0.16), towel, Vector3(-0.1, 0.0, 0.05))
        _box(upper, Vector3(0.07, 0.26, 0.015), Vector3(0.06, 0.5, -0.155), towel, Vector3(-0.1, 0.0, -0.05))

    # Gym gear: a weight plate stuck in the back.
    if randf() < 0.2:
        var plate := _smat("plate", Color(0.18, 0.18, 0.2), 0.5)
        var plate_root := Node3D.new()
        plate_root.position = Vector3(0.08, 0.38, 0.25)
        plate_root.rotation = Vector3(0.3, 0.0, PI * 0.5)
        upper.add_child(plate_root)
        _cyl(plate_root, 0.22, 0.035, Vector3.ZERO, plate)
        _cyl(plate_root, 0.07, 0.05, Vector3.ZERO, _smat("plate_hub", Color(0.45, 0.45, 0.5), 0.4))
        _ell(upper, Vector3(0.12, 0.12, 0.03), Vector3(0.08, 0.38, 0.14), blood)

    # Neck stump (hidden until a head pop).
    var d: Dictionary = {}
    d["stump"] = _make_stump(upper, Vector3(0.0, 0.64, 0.0))

    # Head: skull, hanging jaw, glowing eyes.
    var head := Node3D.new()
    head.position = Vector3(0.0, 0.64, 0.0)
    head.rotation.x = -0.18
    upper.add_child(head)
    z._head = head
    _ell(head, Vector3(0.27, 0.29, 0.27), Vector3(0.0, 0.15, 0.0), skin)
    _ell(head, Vector3(0.14, 0.06, 0.04), Vector3(0.0, 0.08, -0.115), mouth)
    _box(head, Vector3(0.055, 0.04, 0.02), Vector3(-0.065, 0.19, -0.118), eye)
    _box(head, Vector3(0.055, 0.04, 0.02), Vector3(0.065, 0.19, -0.118), eye)

    var jaw := Node3D.new()
    jaw.position = Vector3(0.0, 0.075, 0.04)
    head.add_child(jaw)
    _ell(jaw, Vector3(0.2, 0.075, 0.2), Vector3(0.0, -0.035, -0.09), skin)
    _box(jaw, Vector3(0.03, 0.03, 0.015), Vector3(-0.05, 0.0, -0.14), bone)
    _box(jaw, Vector3(0.03, 0.03, 0.015), Vector3(0.05, 0.0, -0.14), bone)
    d["jaw"] = jaw

    if randf() < 0.4:
        _ell(head, Vector3(0.08, 0.05, 0.08), Vector3(0.07, 0.26, -0.04), wound)
    if randf() < 0.25:
        _cyl(head, 0.1, 0.05, Vector3(0.0, 0.26, 0.0), bandage)

    # Gym gear: headphones.
    if randf() < 0.3:
        var band := _smat("phone_black", Color(0.05, 0.05, 0.06), 0.5)
        for k in range(7):
            var a: float = lerpf(-1.45, 1.45, float(k) / 6.0)
            _box(head, Vector3(0.035, 0.03, 0.045), Vector3(sin(a) * 0.155, 0.15 + cos(a) * 0.155, 0.0), band, Vector3(0.0, 0.0, -a))
        var ci: int = randi() % CUP_COLORS.size()
        var cup := _smat("cup_%d" % ci, CUP_COLORS[ci], 0.5)
        for sx in [-1.0, 1.0]:
            _cyl(head, 0.065, 0.05, Vector3(sx * 0.165, 0.13, 0.0), cup, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.5))

    # Arms.
    z._arm_l = _make_arm(z, -0.32, skin, wound, randf() < 0.25, randf() < 0.3)
    z._arm_r = _make_arm(z, 0.32, skin, wound, randf() < 0.25, randf() < 0.3)
    z._arm_base_l = 1.25 + randf_range(-0.2, 0.2)
    z._arm_base_r = 1.25 + randf_range(-0.2, 0.2)
    if randf() < 0.25:  # one arm hangs down instead of reaching
        if randf() < 0.5:
            z._arm_base_l = 0.35
        else:
            z._arm_base_r = 0.35

    d["limp"] = limp
    d["twitch_wait"] = randf_range(0.5, 3.0)
    d["twitch_t"] = 0.0
    d["twitch_dir"] = 1.0
    z._look_data = d
    return true


# ---------- animation (called at the end of Zombie._process) ----------

static func animate(z: Zombie, delta: float, amp: float) -> void:
    if z._visual == null:
        return

    # Rising from the ground right after spawning.
    if z._rise_left > 0.0:
        z._rise_left = maxf(z._rise_left - delta, 0.0)
        var p: float = 1.0 - z._rise_left / Zombie.RISE_TIME
        var e: float = 1.0 - pow(1.0 - p, 3.0)
        z._visual.position.y -= (1.0 - e) * 1.2
        if z._upper != null:
            z._upper.rotation.x += (1.0 - e) * 0.6

    # Stagger after being hit.
    if z._stagger > 0.0:
        z._stagger = maxf(z._stagger - delta, 0.0)
        var k: float = z._stagger / Zombie.STAGGER_TIME
        if z._upper != null:
            z._upper.rotation.x += k * 0.4
        if z._head != null:
            z._head.rotation.x += k * 0.5

    var d: Dictionary = z._look_data
    if d.is_empty():
        return

    # Limp: the right leg barely swings and the body dips on that step.
    var limp: float = float(d.get("limp", 0.0))
    if limp > 0.0:
        var s: float = sin(z._anim_phase)
        z._leg_r.rotation.x *= 0.45
        z._visual.position.y -= 0.05 * limp * maxf(0.0, s) * amp
        z._visual.rotation.z = sin(z._anim_phase) * 0.05 * amp * limp
        if z._upper != null:
            z._upper.rotation.x -= 0.1 * limp
            z._upper.rotation.z += 0.08 * limp * amp

    # Head twitch every few seconds.
    var tw: float = float(d.get("twitch_t", 0.0))
    var wait: float = float(d.get("twitch_wait", 2.0))
    var k_tw: float = 0.0
    if tw > 0.0:
        tw -= delta
        k_tw = sin(clampf(1.0 - tw / 0.22, 0.0, 1.0) * PI)
    else:
        wait -= delta
        if wait <= 0.0:
            tw = 0.22
            wait = randf_range(1.5, 4.5)
            d["twitch_dir"] = -1.0 if randf() < 0.5 else 1.0
    d["twitch_t"] = tw
    d["twitch_wait"] = wait
    var tdir: float = float(d.get("twitch_dir", 1.0))
    if z._head != null:
        z._head.rotation.z += k_tw * 0.55 * tdir
        z._head.rotation.x += k_tw * 0.2

    # Hanging jaw: loose, chewing a little, snaps open on a twitch.
    var jaw = d.get("jaw")
    if jaw != null and is_instance_valid(jaw):
        jaw.rotation.x = -(0.22 + 0.12 * sin(z._anim_time * 2.3 + z._idle_seed) + 0.5 * k_tw)


# ---------- gore ----------

## Called for every hit that does not kill.
static func hit_gore(z: Zombie, headshot: bool) -> void:
    z._stagger = Zombie.STAGGER_TIME
    _burst(z, headshot, false)


## Called when the zombie dies, before its body is handed to the scene.
static func death_gore(z: Zombie, headshot: bool) -> void:
    _burst(z, headshot, true)
    var scene: Node = z.get_tree().current_scene
    if scene != null:
        _sync_scene(scene)
        _splat(scene, Vector3(z.global_position.x, z._feet_y() + 0.02, z.global_position.z))
    if headshot:
        pop_head(z)


static func _sync_scene(scene: Node) -> void:
    var id: int = scene.get_instance_id()
    if id != _scene_id:
        _scene_id = id
        _blood_live = 0
        _splat_live = 0


static func _burst(z: Zombie, headshot: bool, killed: bool) -> void:
    if z._visual == null or not z.is_inside_tree():
        return
    var scene: Node = z.get_tree().current_scene
    if scene == null:
        return
    _sync_scene(scene)
    if _blood_live > 90:
        return

    var count: int = 4
    if headshot:
        count = 7
    if killed:
        count += 7

    var origin: Vector3 = z.global_position + Vector3(0.0, 0.3, 0.0)
    if headshot and z._head != null and is_instance_valid(z._head):
        origin = z._head.to_global(Vector3(0.0, 0.15, 0.0))
    elif z._upper != null and is_instance_valid(z._upper):
        origin = z._upper.to_global(Vector3(0.0, 0.35, -0.1))

    # Spray away from whoever shot (if known).
    var away: Vector3 = Vector3.ZERO
    var src = z._last_source
    if src != null and is_instance_valid(src) and src is Node3D:
        away = origin - (src as Node3D).global_position
        away.y = 0.0
        if away.length() > 0.01:
            away = away.normalized()
        else:
            away = Vector3.ZERO

    var floor_y: float = z._feet_y() + 0.03
    var mat := _smat("blood_fx", Color(0.55, 0.03, 0.03), 0.25)
    var parts: Array = []
    var vels: Array = []
    for i in range(count):
        var mi := MeshInstance3D.new()
        mi.mesh = _boxm(Vector3.ONE)
        mi.material_override = mat
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        mi.scale = Vector3.ONE * randf_range(0.035, 0.08)
        scene.add_child(mi)
        mi.global_position = origin
        var spread := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 1.3
        vels.append(away * randf_range(1.0, 2.5) + spread + Vector3(0.0, randf_range(1.2, 3.2), 0.0))
        parts.append(mi)
    _blood_live += count

    var tw := scene.create_tween()
    tw.tween_method(_step_blood.bind(parts, vels, origin, floor_y), 0.0, 0.8, 0.8)
    tw.tween_callback(_free_blood.bind(parts))


static func _step_blood(t: float, parts: Array, vels: Array, origin: Vector3, floor_y: float) -> void:
    for i in range(parts.size()):
        if not is_instance_valid(parts[i]):
            continue
        var v: Vector3 = vels[i]
        var drop: float = maxf(origin.y - floor_y, 0.0)
        var t_land: float = (v.y + sqrt(v.y * v.y + 19.6 * drop)) / 9.8
        var tt: float = minf(t, t_land)
        var p: Vector3 = origin + v * tt + Vector3(0.0, -4.9 * tt * tt, 0.0)
        (parts[i] as Node3D).global_position = p


static func _free_blood(parts: Array) -> void:
    for mi in parts:
        if is_instance_valid(mi):
            (mi as Node).queue_free()
    _blood_live = maxi(_blood_live - parts.size(), 0)


## Flat blood puddle on the floor under a dead zombie (fades out by itself).
static func _splat(scene: Node, pos: Vector3) -> void:
    if _splat_live > 30:
        return
    var mi := MeshInstance3D.new()
    mi.mesh = _cylm(0.5, 0.01)
    mi.material_override = _smat("splat", Color(0.32, 0.02, 0.02), 0.3)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var r: float = randf_range(0.3, 0.55)
    mi.scale = Vector3(r, 1.0, r * randf_range(0.7, 1.1))
    scene.add_child(mi)
    mi.global_position = pos
    mi.rotation.y = randf() * TAU
    _splat_live += 1
    var tw := scene.create_tween()
    tw.tween_interval(20.0)
    tw.tween_callback(_free_splat.bind(mi))


static func _free_splat(mi: Node) -> void:
    if is_instance_valid(mi):
        mi.queue_free()
    _splat_live = maxi(_splat_live - 1, 0)


## Headshot kill: the head flies off, a red stump is left on the neck.
static func pop_head(z: Zombie) -> void:
    if z._head == null or not is_instance_valid(z._head) or not z.is_inside_tree():
        return
    var scene: Node = z.get_tree().current_scene
    if scene == null:
        return
    var xf: Transform3D = z._head.global_transform
    z._head.visible = false
    var stump = z._look_data.get("stump")
    if stump != null and is_instance_valid(stump):
        (stump as Node3D).visible = true

    var flying := Node3D.new()
    scene.add_child(flying)
    flying.global_transform = xf
    _ell(flying, Vector3(0.27, 0.29, 0.27), Vector3(0.0, 0.15, 0.0), _smat("head_pop", Color(0.55, 0.62, 0.45), 0.8))
    _ell(flying, Vector3(0.12, 0.1, 0.04), Vector3(0.0, 0.15, -0.13), _smat("flesh", Color(0.5, 0.06, 0.08), 0.35))

    var start: Vector3 = flying.global_position
    var vel := Vector3(randf_range(-1.5, 1.5), randf_range(2.5, 3.5), randf_range(-1.5, 1.5))
    var floor_y: float = z._feet_y() + 0.15
    var tw := scene.create_tween()
    tw.tween_method(_step_head.bind(flying, start, vel, floor_y), 0.0, 1.0, 1.0)
    tw.tween_interval(2.5)
    tw.tween_callback(flying.queue_free)


static func _step_head(t: float, flying: Node3D, start: Vector3, vel: Vector3, floor_y: float) -> void:
    if not is_instance_valid(flying):
        return
    var p: Vector3 = start + vel * t + Vector3(0.0, -4.9 * t * t, 0.0)
    if p.y < floor_y:
        p.y = floor_y
    flying.global_position = p
    flying.rotate_x(0.15)
