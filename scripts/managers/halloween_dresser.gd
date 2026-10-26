extends Node3D
## Visual dressing for the Halloween map (decoration only: no collision, no
## real lights, nothing is baked into the navmesh). Added to the map scene as
## the "HalloweenDresser" node. Everything uses shared meshes and materials, and
## the many small things (stars, grass, corn) are MultiMeshes (one draw call each).
## Set any of the switches below to false/0 to drop that part.

const LIGHTNING: bool = true      # rare flash of the ambient light
const AMBIENT_BASE: float = 0.9   # must match ambient_light_energy in halloween_map.tscn
const STAR_COUNT: int = 90
const STAR_RADIUS: float = 85.0
const TUFT_COUNT: int = 260
const CORN_COUNT: int = 56
const BAT_COUNT: int = 8

const STONE := Color(0.42, 0.42, 0.45)
const IRON := Color(0.10, 0.09, 0.12)
const WOOD := Color(0.30, 0.19, 0.10)
const DIRT := Color(0.16, 0.11, 0.07)
const PUMPKIN := Color(0.95, 0.42, 0.05)
const GLOW := Color(1.0, 0.75, 0.2)
const CREAM := Color(0.9, 0.86, 0.7)
const WEB := Color(0.62, 0.62, 0.72)
const RUNE := Color(0.65, 0.3, 1.0)
const GREEN_FLAME := Color(0.45, 1.0, 0.55)

var _mats: Dictionary = {}
var _meshes: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _bats: Array = []
var _fog: Array = []
var _env: Environment = null
var _time: float = 0.0
var _bolt_wait: float = 15.0
var _bolt_t: float = -1.0


func _ready() -> void:
    _rng.seed = 2026   # same dressing on every phone
    _build_stars()
    _build_gate()
    _build_graveyard_extras()
    _build_tufts()
    _build_plaza_extras()
    _build_house_extras()
    _build_crypt_extras()
    _build_webs()
    _build_bats()
    _build_fog()
    var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we != null:
        _env = we.environment


func _exit_tree() -> void:
    if _env != null:
        _env.ambient_light_energy = AMBIENT_BASE


func _process(delta: float) -> void:
    _time += delta
    _update_bats(delta)
    _update_fog()
    if LIGHTNING:
        _update_lightning(delta)


# ---------------------------------------------------------------- helpers

func _mat(color: Color, glow: float = 0.0, unshaded: bool = false, alpha: float = 1.0) -> StandardMaterial3D:
    var key: String = "%s_%.2f_%s_%.2f" % [color.to_html(false), glow, str(unshaded), alpha]
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(color.r, color.g, color.b, alpha)
    m.roughness = 0.9
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    if unshaded:
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    if alpha < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mats[key] = m
    return m


## Unit meshes (size 1): box, ball (diameter 1), cyl (diameter 1, height 1), cone.
func _unit(kind: String) -> Mesh:
    var existing = _meshes.get(kind)
    if existing != null:
        return existing as Mesh
    var made: Mesh = null
    if kind == "box":
        var b := BoxMesh.new()
        b.size = Vector3.ONE
        made = b
    elif kind == "ball":
        var s := SphereMesh.new()
        s.radius = 0.5
        s.height = 1.0
        s.radial_segments = 12
        s.rings = 6
        made = s
    elif kind == "cyl":
        var c := CylinderMesh.new()
        c.top_radius = 0.5
        c.bottom_radius = 0.5
        c.height = 1.0
        c.radial_segments = 10
        c.rings = 1
        made = c
    else:
        var k := CylinderMesh.new()
        k.top_radius = 0.0
        k.bottom_radius = 0.5
        k.height = 1.0
        k.radial_segments = 8
        k.rings = 1
        made = k
    _meshes[kind] = made
    return made


func _put(parent: Node3D, kind: String, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = _unit(kind)
    mi.material_override = mat
    mi.position = pos
    mi.scale = size
    mi.rotation = rot
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


func _node_at(pos: Vector3, yaw: float = 0.0) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    n.rotation.y = yaw
    add_child(n)
    return n


# ---------------------------------------------------------------- sky

func _build_stars() -> void:
    var sm := SphereMesh.new()
    sm.radius = 0.5
    sm.height = 1.0
    sm.radial_segments = 4
    sm.rings = 2
    var mat := _mat(Color(1.0, 0.97, 0.85), 0.0, true)
    mat.disable_fog = true
    var moon := Vector3(-30.0, 42.0, -75.0)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = sm
    mm.instance_count = STAR_COUNT
    var n: int = 0
    var tries: int = 0
    while n < STAR_COUNT and tries < STAR_COUNT * 5:
        tries += 1
        var a: float = _rng.randf_range(0.0, TAU)
        var e: float = _rng.randf_range(0.2, 1.25)
        var p := Vector3(cos(e) * cos(a), sin(e), cos(e) * sin(a)) * STAR_RADIUS
        if p.distance_to(moon) < 14.0:
            continue
        var s: float = _rng.randf_range(0.9, 2.0)
        mm.set_instance_transform(n, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))
        n += 1
    mm.visible_instance_count = n
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = mat
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)


func _update_lightning(delta: float) -> void:
    if _env == null:
        return
    if _bolt_t >= 0.0:
        _bolt_t += delta
        var on: bool = _bolt_t < 0.07 or (_bolt_t >= 0.15 and _bolt_t < 0.27)
        _env.ambient_light_energy = 2.2 if on else AMBIENT_BASE
        if _bolt_t > 0.4:
            _bolt_t = -1.0
            _env.ambient_light_energy = AMBIENT_BASE
            _bolt_wait = randf_range(18.0, 40.0)
    else:
        _bolt_wait -= delta
        if _bolt_wait <= 0.0:
            _bolt_t = 0.0


# ---------------------------------------------------------------- gate and doors

func _build_gate() -> void:
    var iron := _mat(IRON)
    # Cemetery gate: two pillars, an iron crossbar and spikes.
    _pillar(-6.6, 8.8)
    _pillar(6.6, 8.8)
    _put(self, "box", Vector3(0.0, 5.3, 8.8), Vector3(13.4, 0.15, 0.15), iron)
    var x: float = -6.0
    while x <= 6.01:
        _put(self, "cone", Vector3(x, 5.6, 8.8), Vector3(0.12, 0.5, 0.12), iron)
        x += 1.5
    # House door and crypt door pillars (on the graveyard side of the north wall).
    _pillar(-20.6, -11.1)
    _pillar(-11.4, -11.1)
    _pillar(11.4, -11.1)
    _pillar(20.6, -11.1)


func _pillar(x: float, z: float) -> void:
    var stone := _mat(STONE)
    var lit := _mat(PUMPKIN, 2.5)
    var glow := _mat(GLOW, 4.0)
    _put(self, "box", Vector3(x, 2.3, z), Vector3(1.1, 4.6, 1.1), stone)
    _put(self, "box", Vector3(x, 4.72, z), Vector3(1.4, 0.25, 1.4), stone)
    _put(self, "ball", Vector3(x, 5.2, z), Vector3(0.8, 0.7, 0.8), lit)
    for sx in [-1.0, 1.0]:
        _put(self, "box", Vector3(x + float(sx) * 0.15, 5.25, z + 0.36), Vector3(0.12, 0.12, 0.05), glow, Vector3(0.0, 0.0, PI * 0.25))
    _put(self, "box", Vector3(x, 5.08, z + 0.36), Vector3(0.3, 0.07, 0.05), glow)


# ---------------------------------------------------------------- graveyard

func _build_graveyard_extras() -> void:
    for z in [-3.75, 1.75]:
        for x in [-28.5, -18.0, -12.5, 12.5, 18.0, 28.5]:
            _cross(Vector3(float(x) + _rng.randf_range(-0.6, 0.6), 0.0, float(z) + _rng.randf_range(-0.3, 0.3)),
                    _rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.12, 0.12))


func _cross(pos: Vector3, yaw: float, tilt: float) -> void:
    var wood := _mat(WOOD)
    var root := _node_at(pos, yaw)
    _put(root, "ball", Vector3(0.0, 0.0, 0.9), Vector3(1.3, 0.4, 2.0), _mat(DIRT))
    var post := Node3D.new()
    post.rotation.z = tilt
    root.add_child(post)
    _put(post, "box", Vector3(0.0, 0.7, 0.0), Vector3(0.14, 1.4, 0.14), wood)
    _put(post, "box", Vector3(0.0, 1.0, 0.0), Vector3(0.7, 0.14, 0.14), wood)


func _build_tufts() -> void:
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = 0.09
    cone.height = 0.5
    cone.radial_segments = 5
    cone.rings = 1
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = cone
    mm.instance_count = TUFT_COUNT
    var n: int = 0
    var tries: int = 0
    while n < TUFT_COUNT and tries < TUFT_COUNT * 6:
        tries += 1
        var x: float = _rng.randf_range(-31.0, 31.0)
        var z: float = _rng.randf_range(-11.0, 31.0)
        if absf(x) < 2.8:
            continue   # keep the stone path clear
        if absf(z - 8.0) < 1.0:
            continue   # gate wall
        var sy: float = _rng.randf_range(0.6, 1.7)
        var b := Basis.from_euler(Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.2, 0.2)))
        b = b.scaled(Vector3(1.0, sy, 1.0))
        mm.set_instance_transform(n, Transform3D(b, Vector3(x, 0.25 * sy, z)))
        n += 1
    mm.visible_instance_count = n
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = _mat(Color(0.27, 0.24, 0.11))
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)


func _build_fog() -> void:
    var fog_mat := _mat(Color(0.55, 0.65, 0.6), 0.0, true, 0.14)
    var spots: Array = [
        Vector3(-16, 0.3, 2), Vector3(16, 0.3, 0), Vector3(0, 0.3, -6), Vector3(-22, 0.3, -8),
        Vector3(22, 0.3, -8), Vector3(-10, 0.3, 20), Vector3(10, 0.3, 14), Vector3(22, 0.3, 24),
    ]
    for p in spots:
        var d: float = _rng.randf_range(7.0, 10.0)
        var mi := _put(self, "cyl", p, Vector3(d, 0.02, d), fog_mat)
        _fog.append({"node": mi, "base": p, "ph": _rng.randf_range(0.0, TAU)})


func _update_fog() -> void:
    for f in _fog:
        var base: Vector3 = f["base"]
        var ph: float = float(f["ph"])
        var node: Node3D = f["node"]
        node.position = base + Vector3(sin(_time * 0.12 + ph) * 1.8, 0.0, cos(_time * 0.1 + ph) * 1.2)


# ---------------------------------------------------------------- plaza

func _build_plaza_extras() -> void:
    _scarecrow(Vector3(8.5, 0.0, 24.0))
    # Corn stalks along the east fence.
    var corn := CylinderMesh.new()
    corn.top_radius = 0.01
    corn.bottom_radius = 0.07
    corn.height = 2.0
    corn.radial_segments = 5
    corn.rings = 1
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = corn
    mm.instance_count = CORN_COUNT
    for i in range(CORN_COUNT):
        var b := Basis.from_euler(Vector3(_rng.randf_range(-0.1, 0.1), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.1, 0.1)))
        b = b.scaled(Vector3(1.0, _rng.randf_range(0.8, 1.2), 1.0))
        var p := Vector3(_rng.randf_range(29.4, 31.5), 1.0, _rng.randf_range(14.5, 31.5))
        mm.set_instance_transform(i, Transform3D(b, p))
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = _mat(Color(0.55, 0.5, 0.2))
    mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mmi)


## Faces +Z (south), toward the player's start.
func _scarecrow(pos: Vector3) -> void:
    var wood := _mat(WOOD)
    var hay := _mat(Color(0.72, 0.58, 0.22))
    var shirt := _mat(Color(0.30, 0.12, 0.38))
    var hat := _mat(Color(0.08, 0.06, 0.1))
    var glow := _mat(GLOW, 3.5)
    var root := _node_at(pos, 0.3)
    _put(root, "box", Vector3(0.0, 1.1, 0.0), Vector3(0.12, 2.2, 0.12), wood)
    _put(root, "box", Vector3(0.0, 1.6, 0.0), Vector3(1.7, 0.12, 0.12), wood)
    _put(root, "box", Vector3(0.0, 1.35, 0.0), Vector3(0.55, 0.8, 0.3), shirt)
    for sx in [-1.0, 1.0]:
        _put(root, "box", Vector3(float(sx) * 0.9, 1.5, 0.0), Vector3(0.25, 0.3, 0.1), hay, Vector3(0.0, 0.0, float(sx) * 0.4))
    _put(root, "ball", Vector3(0.0, 2.0, 0.0), Vector3(0.5, 0.45, 0.5), _mat(PUMPKIN, 0.8))
    for sx in [-1.0, 1.0]:
        _put(root, "box", Vector3(float(sx) * 0.11, 2.03, 0.22), Vector3(0.09, 0.09, 0.05), glow, Vector3(0.0, 0.0, PI * 0.25))
    _put(root, "box", Vector3(0.0, 1.9, 0.23), Vector3(0.22, 0.06, 0.05), glow)
    _put(root, "cyl", Vector3(0.0, 2.25, 0.0), Vector3(0.75, 0.05, 0.75), hat)
    _put(root, "cone", Vector3(0.0, 2.5, 0.0), Vector3(0.4, 0.5, 0.4), hat)


# ---------------------------------------------------------------- haunted house

func _build_house_extras() -> void:
    _chandelier(Vector3(-22.0, 5.0, -17.0))
    _chandelier(Vector3(-22.0, 5.0, -27.0))
    _portrait(Vector3(-28.0, 2.6, -21.43), 0.0)
    _portrait(Vector3(-20.0, 2.6, -22.57), PI)
    _portrait(Vector3(-6.06, 2.6, -27.0), -PI * 0.5)
    _portrait(Vector3(-31.94, 2.6, -24.5), PI * 0.5)
    _spider(Vector3(-12.0, 5.0, -15.0))
    _spider(Vector3(-27.0, 5.0, -25.0))


## pos = where the chain meets the ceiling.
func _chandelier(pos: Vector3) -> void:
    var iron := _mat(IRON)
    var wax := _mat(CREAM)
    var flame := _mat(GLOW, 4.0)
    var ring_y: float = pos.y - 0.9
    _put(self, "box", pos + Vector3(0.0, -0.45, 0.0), Vector3(0.05, 0.9, 0.05), iron)
    _put(self, "cyl", Vector3(pos.x, ring_y, pos.z), Vector3(1.3, 0.07, 1.3), iron)
    for i in range(6):
        var a: float = float(i) / 6.0 * TAU
        var p := Vector3(pos.x + cos(a) * 0.5, ring_y, pos.z + sin(a) * 0.5)
        _put(self, "cyl", p + Vector3(0.0, 0.14, 0.0), Vector3(0.08, 0.22, 0.08), wax)
        _put(self, "ball", p + Vector3(0.0, 0.31, 0.0), Vector3(0.09, 0.14, 0.09), flame)


## A framed portrait with glowing eyes. Its front faces +Z turned by yaw.
func _portrait(pos: Vector3, yaw: float) -> void:
    var root := _node_at(pos, yaw)
    _put(root, "box", Vector3.ZERO, Vector3(1.3, 1.8, 0.1), _mat(Color(0.35, 0.25, 0.08)))
    _put(root, "box", Vector3(0.0, 0.0, 0.03), Vector3(1.1, 1.6, 0.1), _mat(Color(0.04, 0.07, 0.05)))
    var eye := _mat(Color(1.0, 0.7, 0.1), 3.5)
    for sx in [-1.0, 1.0]:
        _put(root, "ball", Vector3(float(sx) * 0.2, 0.3, 0.09), Vector3(0.14, 0.07, 0.03), eye)


## pos = where its thread is tied to the ceiling.
func _spider(pos: Vector3) -> void:
    var black := _mat(Color(0.04, 0.03, 0.05))
    var red := _mat(Color(1.0, 0.1, 0.05), 4.0)
    var root := _node_at(pos, _rng.randf_range(0.0, TAU))
    _put(root, "box", Vector3(0.0, -0.6, 0.0), Vector3(0.012, 1.2, 0.012), _mat(WEB, 0.0, true))
    var body := Node3D.new()
    body.position = Vector3(0.0, -1.25, 0.0)
    root.add_child(body)
    _put(body, "ball", Vector3.ZERO, Vector3(0.3, 0.24, 0.38), black)
    _put(body, "ball", Vector3(0.0, 0.0, -0.22), Vector3(0.18, 0.16, 0.18), black)
    for sx in [-1.0, 1.0]:
        var side: float = float(sx)
        _put(body, "ball", Vector3(side * 0.04, 0.03, -0.3), Vector3(0.04, 0.04, 0.04), red)
        for i in range(4):
            _put(body, "box", Vector3(side * 0.24, -0.04, (float(i) - 1.5) * 0.1), Vector3(0.4, 0.025, 0.025), black, Vector3(0.0, (float(i) - 1.5) * 0.25 * side, -side * 0.5))


# ---------------------------------------------------------------- crypt

func _build_crypt_extras() -> void:
    # Green torches on the maze walls.
    _torch(Vector3(10.0, 2.8, -17.5), 1.0)
    _torch(Vector3(20.0, 2.8, -17.5), 1.0)
    _torch(Vector3(9.0, 2.8, -18.5), -1.0)
    _torch(Vector3(19.0, 2.8, -18.5), -1.0)
    _torch(Vector3(21.0, 2.8, -23.5), 1.0)
    _torch(Vector3(30.0, 2.8, -23.5), 1.0)
    _torch(Vector3(18.0, 2.8, -24.5), -1.0)
    _torch(Vector3(28.0, 2.8, -24.5), -1.0)
    # Rune circles on the floor.
    _rune(Vector3(20.5, 0.08, -14.8))
    _rune(Vector3(19.0, 0.08, -28.0))
    _spider(Vector3(14.0, 5.0, -22.0))


## A wall torch. dir_z = +1 if the wall face looks toward +Z, -1 toward -Z.
func _torch(pos: Vector3, dir_z: float) -> void:
    var iron := _mat(IRON)
    var wood := _mat(WOOD)
    var flame := _mat(GREEN_FLAME, 4.5)
    _put(self, "box", pos + Vector3(0.0, 0.0, dir_z * 0.12), Vector3(0.1, 0.1, 0.3), iron)
    _put(self, "cyl", pos + Vector3(0.0, 0.25, dir_z * 0.25), Vector3(0.08, 0.6, 0.08), wood)
    _put(self, "ball", pos + Vector3(0.0, 0.65, dir_z * 0.25), Vector3(0.22, 0.32, 0.22), flame)


func _rune(pos: Vector3) -> void:
    var glow := _mat(RUNE, 2.0)
    var ring := TorusMesh.new()
    ring.inner_radius = 1.78
    ring.outer_radius = 1.9
    ring.rings = 20
    ring.ring_segments = 4
    var mi := MeshInstance3D.new()
    mi.mesh = ring
    mi.material_override = glow
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mi)
    # Pentagram: 5 thin bars joining every second point of a pentagon.
    var pts: Array = []
    for k in range(5):
        var a: float = float(k) / 5.0 * TAU + PI * 0.5
        pts.append(Vector3(cos(a), 0.0, sin(a)) * 1.8)
    for k in range(5):
        var p0: Vector3 = pts[k]
        var p1: Vector3 = pts[(k + 2) % 5]
        var d: Vector3 = p1 - p0
        _put(self, "box", pos + (p0 + p1) * 0.5, Vector3(d.length(), 0.02, 0.07), glow, Vector3(0.0, atan2(-d.z, d.x), 0.0))


# ---------------------------------------------------------------- cobwebs

func _web_mesh() -> ArrayMesh:
    var pts := PackedVector3Array()
    var rays: int = 6
    for i in range(rays):
        var a: float = float(i) / float(rays - 1) * PI * 0.5
        pts.append(Vector3.ZERO)
        pts.append(Vector3(cos(a), 0.0, sin(a)) * 1.5)
    for r in [0.45, 0.8, 1.15, 1.5]:
        var rr: float = float(r)
        for i in range(rays - 1):
            var a0: float = float(i) / float(rays - 1) * PI * 0.5
            var a1: float = float(i + 1) / float(rays - 1) * PI * 0.5
            pts.append(Vector3(cos(a0), -0.04 * rr, sin(a0)) * rr)
            pts.append(Vector3(cos(a1), -0.04 * rr, sin(a1)) * rr)
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = pts
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
    return mesh


func _build_webs() -> void:
    var mesh: ArrayMesh = _web_mesh()
    var mat := _mat(WEB, 0.0, true)
    # [corner x, corner z, direction into the room along x, direction along z]
    var corners: Array = [
        # house, south room
        [-31.6, -12.6, 1.0, -1.0], [-6.6, -12.6, -1.0, -1.0], [-31.6, -21.4, 1.0, 1.0], [-6.6, -21.4, -1.0, 1.0],
        # house, north room
        [-31.6, -22.6, 1.0, -1.0], [-6.6, -22.6, -1.0, -1.0], [-31.6, -31.6, 1.0, 1.0], [-6.6, -31.6, -1.0, 1.0],
        # crypt
        [6.6, -12.6, 1.0, -1.0], [6.6, -17.4, 1.0, 1.0], [6.6, -18.6, 1.0, -1.0], [31.6, -23.4, -1.0, 1.0],
        [6.6, -31.6, 1.0, 1.0], [31.6, -31.6, -1.0, 1.0], [31.6, -24.6, -1.0, -1.0],
    ]
    for c in corners:
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        mi.material_override = mat
        mi.position = Vector3(float(c[0]), 4.97, float(c[1]))
        mi.scale = Vector3(float(c[2]), 1.0, float(c[3]))
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mi)


# ---------------------------------------------------------------- bats

func _build_bats() -> void:
    var dark := _mat(Color(0.06, 0.04, 0.08))
    var centers: Array = [Vector2(0, 0), Vector2(-18, -2), Vector2(18, -2), Vector2(0, 22),
            Vector2(-20, 22), Vector2(20, 22), Vector2(0, -4), Vector2(-8, 14)]
    for i in range(BAT_COUNT):
        var root := Node3D.new()
        add_child(root)
        _put(root, "ball", Vector3.ZERO, Vector3(0.12, 0.1, 0.22), dark)
        var wl := Node3D.new()
        wl.position = Vector3(-0.06, 0.02, 0.0)
        root.add_child(wl)
        _put(wl, "box", Vector3(-0.22, 0.0, 0.0), Vector3(0.44, 0.02, 0.2), dark)
        var wr := Node3D.new()
        wr.position = Vector3(0.06, 0.02, 0.0)
        root.add_child(wr)
        _put(wr, "box", Vector3(0.22, 0.0, 0.0), Vector3(0.44, 0.02, 0.2), dark)
        var c: Vector2 = centers[i % centers.size()]
        var spd: float = randf_range(0.45, 0.9)
        if randf() < 0.5:
            spd = -spd
        _bats.append({
            "root": root, "wl": wl, "wr": wr, "cx": c.x, "cz": c.y,
            "r": randf_range(5.0, 12.0), "y": randf_range(6.2, 9.0),
            "a": randf_range(0.0, TAU), "spd": spd, "ph": randf_range(0.0, TAU),
        })


func _update_bats(delta: float) -> void:
    for b in _bats:
        var spd: float = float(b["spd"])
        var a: float = float(b["a"]) + spd * delta
        b["a"] = a
        var r: float = float(b["r"])
        var ph: float = float(b["ph"])
        var root: Node3D = b["root"]
        root.position = Vector3(float(b["cx"]) + cos(a) * r, float(b["y"]) + sin(_time * 1.7 + ph) * 0.6, float(b["cz"]) + sin(a) * r)
        var v := Vector3(-sin(a), 0.0, cos(a)) * signf(spd)
        root.rotation.y = atan2(-v.x, -v.z)
        var flap: float = sin(_time * 14.0 + ph) * 0.7
        var wl: Node3D = b["wl"]
        var wr: Node3D = b["wr"]
        wl.rotation.z = flap
        wr.rotation.z = -flap
