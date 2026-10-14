extends Node3D
# Gym Compound decor kit: batching helpers, props, posters, signs, doors, blood.
# Standalone (does not need map_dress_base.gd). Used by gym_compound_dresser.gd.

const CELL := 27.0
const AX := Vector3(1, 0, 0)
const AY := Vector3(0, 1, 0)
const AZ := Vector3(0, 0, 1)

const STEEL := Color(0.55, 0.56, 0.6)
const DARK := Color(0.07, 0.07, 0.08)
const PLATE := Color(0.1, 0.1, 0.11)
const RED := Color(0.65, 0.09, 0.08)
const YELLOW := Color(0.95, 0.74, 0.06)
const TEAL := Color(0.12, 0.55, 0.6)
const ORANGE := Color(0.85, 0.4, 0.1)
const WOOD := Color(0.3, 0.2, 0.12)
const WHITE := Color(0.88, 0.88, 0.84)
const BLOOD := Color(0.26, 0.015, 0.02)

var _solid: Dictionary = {}
var _glow: Dictionary = {}
var _col_body: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _mats: Dictionary = {}


# ---------------------------------------------------------------- batching

func _bucket(store: Dictionary, p: Vector3) -> Dictionary:
    var k := Vector2i(int(floorf((p.x + 40.0) / CELL)), int(floorf((p.z + 40.0) / CELL)))
    if not store.has(k):
        store[k] = {"v": [], "n": [], "c": []}
    return store[k]


func _t(bk: Dictionary, a: Vector3, b: Vector3, c: Vector3, nrm: Vector3, col: Color) -> void:
    if (b - a).cross(c - a).dot(nrm) > 0.0:
        var tmp: Vector3 = b
        b = c
        c = tmp
    bk["v"].append(a)
    bk["v"].append(b)
    bk["v"].append(c)
    for i in 3:
        bk["n"].append(nrm)
        bk["c"].append(col)


func _q(a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, col: Color, glow: bool = false) -> void:
    var bk: Dictionary = _bucket(_glow if glow else _solid, (a + c) * 0.5)
    _t(bk, a, b, c, nrm, col)
    _t(bk, a, c, d, nrm, col)


func _fq(x0: float, z0: float, x1: float, z1: float, y: float, col: Color, glow: bool = false) -> void:
    _q(Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), AY, col, glow)


func _obox(c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, s: Vector3, col: Color, skip_top: bool = false, skip_bottom: bool = true, glow: bool = false) -> void:
    var hx: Vector3 = ax * (s.x * 0.5)
    var hy: Vector3 = ay * (s.y * 0.5)
    var hz: Vector3 = az * (s.z * 0.5)
    _q(c + hx - hy - hz, c + hx + hy - hz, c + hx + hy + hz, c + hx - hy + hz, ax, col, glow)
    _q(c - hx - hy + hz, c - hx + hy + hz, c - hx + hy - hz, c - hx - hy - hz, -ax, col, glow)
    if not skip_top:
        _q(c - hx + hy - hz, c - hx + hy + hz, c + hx + hy + hz, c + hx + hy - hz, ay, col, glow)
    if not skip_bottom:
        _q(c - hx - hy + hz, c - hx - hy - hz, c + hx - hy - hz, c + hx - hy + hz, -ay, col, glow)
    _q(c - hx - hy + hz, c + hx - hy + hz, c + hx + hy + hz, c - hx + hy + hz, az, col, glow)
    _q(c + hx - hy - hz, c - hx - hy - hz, c - hx + hy - hz, c + hx + hy - hz, -az, col, glow)


# wall quad: c is a point on the wall plane, nrm points into the room
func _wq(c: Vector3, nrm: Vector3, w: float, h: float, col: Color, glow: bool = false, off: float = 0.02) -> void:
    var r: Vector3 = AY.cross(nrm)
    var o: Vector3 = c + nrm * off
    var hw: Vector3 = r * (w * 0.5)
    var hh: Vector3 = AY * (h * 0.5)
    _q(o - hw - hh, o + hw - hh, o + hw + hh, o - hw + hh, nrm, col, glow)


# wall box: sticks out of the wall plane by d
func _wb(c: Vector3, nrm: Vector3, w: float, h: float, d: float, col: Color) -> void:
    _obox(c + nrm * (d * 0.5), AY.cross(nrm), AY, nrm, Vector3(w, h, d), col, true, true)


func _stripes(c: Vector3, along: Vector3, up: Vector3, nrm: Vector3, length: float, height: float, seg: float, c1: Color, c2: Color) -> void:
    var count: int = int(ceil(length / seg))
    var start: Vector3 = c - along * (length * 0.5)
    var hh: Vector3 = up * (height * 0.5)
    for i in count:
        var s0: float = float(i) * seg
        var s1: float = minf(length, s0 + seg)
        var p0: Vector3 = start + along * s0
        var p1: Vector3 = start + along * s1
        _q(p0 - hh, p1 - hh, p1 + hh, p0 + hh, nrm, c1 if i % 2 == 0 else c2)


func _ring(c: Vector3, r0: float, r1: float, col: Color, segs: int = 20, glow: bool = false) -> void:
    for i in segs:
        var a0: float = TAU * float(i) / float(segs)
        var a1: float = TAU * float(i + 1) / float(segs)
        var d0 := Vector3(cos(a0), 0.0, sin(a0))
        var d1 := Vector3(cos(a1), 0.0, sin(a1))
        _q(c + d0 * r0, c + d0 * r1, c + d1 * r1, c + d1 * r0, AY, col, glow)


func _blob(x: float, z: float, r: float, y: float) -> void:
    var c := Vector3(x, y, z)
    var segs: int = 9
    var bk: Dictionary = _bucket(_solid, c)
    var rad: Array = []
    for i in segs:
        rad.append(r * _rng.randf_range(0.55, 1.15))
    for i in segs:
        var a0: float = TAU * float(i) / float(segs)
        var a1: float = TAU * float(i + 1) / float(segs)
        var r0: float = rad[i]
        var r1: float = rad[(i + 1) % segs]
        _t(bk, c, c + Vector3(cos(a0), 0.0, sin(a0)) * r0, c + Vector3(cos(a1), 0.0, sin(a1)) * r1, AY, BLOOD)
    for k in 3:
        var dx: float = _rng.randf_range(-1.6, 1.6) * r
        var dz: float = _rng.randf_range(-1.6, 1.6) * r
        var sz: float = _rng.randf_range(0.1, 0.22)
        _fq(x + dx, z + dz, x + dx + sz, z + dz + sz, y, BLOOD)


func _solid_box(c: Vector3, s: Vector3, nrm: Vector3 = AZ) -> void:
    if _col_body == null:
        _col_body = StaticBody3D.new()
        _col_body.name = "DecorCollision"
        add_child(_col_body)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = s
    cs.shape = sh
    cs.position = c
    cs.rotation.y = atan2(nrm.x, nrm.z)
    _col_body.add_child(cs)


func _flat(col: Color) -> StandardMaterial3D:
    var key: String = col.to_html()
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = col
    m.roughness = 0.9
    _mats[key] = m
    return m


func _node_box(parent: Node, c: Vector3, size: Vector3, col: Color, tilt: Vector3 = Vector3.ZERO) -> void:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = _flat(col)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mi.position = c
    mi.rotation_degrees = tilt
    parent.add_child(mi)


func _label(text: String, p: Vector3, nrm: Vector3, h: float, col: Color, outline: int = 10, parent: Node = null) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = 64
    l.pixel_size = h / 64.0
    l.modulate = col
    l.outline_size = outline
    l.outline_modulate = Color(0.02, 0.02, 0.03, 1.0)
    l.shaded = false
    l.visibility_range_end = 45.0
    l.position = p
    l.rotation.y = atan2(nrm.x, nrm.z)
    var host: Node = parent if parent != null else self
    host.add_child(l)


func _lamp(p: Vector3, col: Color, energy: float, rng: float) -> void:
    var o := OmniLight3D.new()
    o.position = p
    o.light_color = col
    o.light_energy = energy
    o.omni_range = rng
    o.shadow_enabled = false
    add_child(o)


func _flush() -> void:
    _emit_store(_solid, false)
    _emit_store(_glow, true)


func _emit_store(store: Dictionary, glow: bool) -> void:
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.vertex_color_is_srgb = true
    mat.roughness = 0.9
    if glow:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for k in store.keys():
        var bk: Dictionary = store[k]
        if bk["v"].is_empty():
            continue
        var arrays: Array = []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(bk["v"])
        arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(bk["n"])
        arrays[Mesh.ARRAY_COLOR] = PackedColorArray(bk["c"])
        var am := ArrayMesh.new()
        am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        am.surface_set_material(0, mat)
        var mi := MeshInstance3D.new()
        mi.mesh = am
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mi)
    store.clear()


# ------------------------------------------------------------------- props
# c = point on the floor at the wall plane, nrm = direction away from the wall

func _rack(c: Vector3, nrm: Vector3) -> void:
    var r: Vector3 = AY.cross(nrm)
    for sx: float in [-0.6, 0.6]:
        for sd: float in [0.12, 0.95]:
            _obox(c + r * sx + nrm * sd + AY * 1.1, r, AY, nrm, Vector3(0.1, 2.2, 0.1), DARK, true)
    for sd: float in [0.12, 0.95]:
        _obox(c + nrm * sd + AY * 2.15, r, AY, nrm, Vector3(1.3, 0.1, 0.1), DARK, true)
    for sx: float in [-0.6, 0.6]:
        _obox(c + r * sx + nrm * 0.535 + AY * 2.15, r, AY, nrm, Vector3(0.1, 0.1, 0.85), DARK, true)
    _obox(c + nrm * 0.55 + AY * 1.35, r, AY, nrm, Vector3(1.9, 0.05, 0.05), STEEL)
    for sx: float in [-0.8, 0.8]:
        _obox(c + r * sx + nrm * 0.55 + AY * 1.35, r, AY, nrm, Vector3(0.09, 0.5, 0.5), PLATE)
        _obox(c + r * (sx * 1.12) + nrm * 0.55 + AY * 1.35, r, AY, nrm, Vector3(0.07, 0.34, 0.34), RED)
    _solid_box(c + nrm * 0.55 + AY * 1.1, Vector3(1.9, 2.2, 1.1), nrm)


func _dbrack(c: Vector3, nrm: Vector3) -> void:
    var r: Vector3 = AY.cross(nrm)
    for sx: float in [-1.0, 1.0]:
        _obox(c + r * sx + nrm * 0.3 + AY * 0.55, r, AY, nrm, Vector3(0.06, 1.1, 0.5), DARK)
    for lvl: float in [0.45, 0.95]:
        _obox(c + nrm * 0.3 + AY * lvl, r, AY, nrm, Vector3(2.0, 0.05, 0.5), STEEL)
        for i in 8:
            var hx: float = -0.85 + 0.24 * float(i)
            var col: Color = [RED, PLATE, YELLOW, PLATE][i % 4]
            _obox(c + r * hx + nrm * 0.3 + AY * (lvl + 0.1), r, AY, nrm, Vector3(0.14, 0.14, 0.3), col)
    _solid_box(c + nrm * 0.3 + AY * 0.6, Vector3(2.1, 1.2, 0.55), nrm)


func _plates(c: Vector3, nrm: Vector3) -> void:
    var r: Vector3 = AY.cross(nrm)
    _obox(c + nrm * 0.35 + AY * 0.8, r, AY, nrm, Vector3(0.1, 1.6, 0.1), STEEL, true)
    _obox(c + nrm * 0.35 + AY * 0.04, r, AY, nrm, Vector3(0.7, 0.08, 0.5), DARK)
    for i in 4:
        var py: float = 0.3 + 0.35 * float(i)
        var col: Color = [RED, PLATE, YELLOW, PLATE][i]
        for sx: float in [-0.3, 0.3]:
            _obox(c + r * sx + nrm * 0.35 + AY * py, r, AY, nrm, Vector3(0.07, 0.46, 0.46), col)
    _solid_box(c + nrm * 0.35 + AY * 0.85, Vector3(0.9, 1.7, 0.6), nrm)


func _bench(c: Vector3, nrm: Vector3) -> void:
    var r: Vector3 = AY.cross(nrm)
    _obox(c + nrm * 0.3 + AY * 0.44, r, AY, nrm, Vector3(1.3, 0.1, 0.4), Color(0.1, 0.1, 0.12))
    for sx: float in [-0.55, 0.55]:
        _obox(c + r * sx + nrm * 0.3 + AY * 0.2, r, AY, nrm, Vector3(0.07, 0.4, 0.34), STEEL)
    _solid_box(c + nrm * 0.3 + AY * 0.25, Vector3(1.3, 0.5, 0.4), nrm)


func _treadmill(c: Vector3, nrm: Vector3) -> void:
    var r: Vector3 = AY.cross(nrm)
    _obox(c + nrm * 1.35 + AY * 0.1, r, AY, nrm, Vector3(0.8, 0.14, 1.7), Color(0.08, 0.08, 0.09))
    for sx: float in [-0.44, 0.44]:
        _obox(c + r * sx + nrm * 1.35 + AY * 0.15, r, AY, nrm, Vector3(0.07, 0.2, 1.8), STEEL)
        _obox(c + r * (sx * 0.88) + nrm * 0.4 + AY * 0.65, r, AY, nrm, Vector3(0.05, 1.1, 0.05), STEEL, true)
    _obox(c + nrm * 0.4 + AY * 1.2, r, AY, nrm, Vector3(0.9, 0.3, 0.12), DARK, true)
    _wq(c + AY * 1.2 + nrm * 0.4, nrm, 0.6, 0.16, Color(0.3, 0.9, 1.0), true, 0.07)
    _solid_box(c + nrm * 1.1 + AY * 0.7, Vector3(0.95, 1.4, 2.1), nrm)


func _lockers(c: Vector3, nrm: Vector3, length: float) -> void:
    var r: Vector3 = AY.cross(nrm)
    var cnt: int = int(length / 0.5)
    for i in cnt:
        var x: float = (float(i) + 0.5) * 0.5 - length * 0.5
        var col: Color = Color(0.12, 0.3, 0.34) if i % 2 == 0 else Color(0.14, 0.17, 0.26)
        _obox(c + r * x + nrm * 0.3 + AY * 0.95, r, AY, nrm, Vector3(0.46, 1.9, 0.6), col, true)
        _wq(c + r * x + AY * 1.6 + nrm * 0.6, nrm, 0.26, 0.05, DARK, false, 0.01)
        _wq(c + r * x + AY * 1.5 + nrm * 0.6, nrm, 0.26, 0.05, DARK, false, 0.01)
    _solid_box(c + nrm * 0.3 + AY * 0.95, Vector3(length, 1.9, 0.6), nrm)


func _crates(c: Vector3, nrm: Vector3) -> void:
    var r: Vector3 = AY.cross(nrm)
    _obox(c + r * -0.5 + nrm * 0.5 + AY * 0.45, r, AY, nrm, Vector3(0.9, 0.9, 0.9), WOOD)
    _obox(c + r * 0.55 + nrm * 0.5 + AY * 0.4, r, AY, nrm, Vector3(0.8, 0.8, 0.8), Color(0.22, 0.28, 0.2))
    _obox(c + r * -0.4 + nrm * 0.5 + AY * 1.3, r, AY, nrm, Vector3(0.75, 0.75, 0.75), Color(0.35, 0.24, 0.14), true)
    _solid_box(c + nrm * 0.5 + AY * 0.8, Vector3(1.9, 1.6, 0.95), nrm)


func _props() -> void:
    # start yard walls
    _plates(Vector3(-39, 0, -3), AX)
    _bench(Vector3(-39, 0, 3), AX)
    _dbrack(Vector3(39, 0, -3), -AX)
    _crates(Vector3(39, 0, 3), -AX)
    for x: float in [-9.0, 9.0]:
        _dbrack(Vector3(x, 0, 9), -AZ)
    for x: float in [-22.0, 22.0]:
        _crates(Vector3(x, 0, 9), -AZ)
    _lockers(Vector3(-33, 0, 9), -AZ, 4.0)
    _lockers(Vector3(33, 0, 9), -AZ, 4.0)
    # under the catwalk wall
    for x: float in [-30.0, -19.0, 19.0, 30.0]:
        _rack(Vector3(x, 0, -10.5), AZ)
    for x: float in [-12.0, 12.0]:
        _dbrack(Vector3(x, 0, -10.5), AZ)
    # south hall
    for x: float in [-11.0, 11.0]:
        _crates(Vector3(x, 0, 39), -AZ)
    for x: float in [-8.0, 8.0]:
        _dbrack(Vector3(x, 0, 11), AZ)
    # west wing (cardio)
    for z: float in [17.5, 20.5, 30.5, 33.5, 36.5]:
        _treadmill(Vector3(-39, 0, z), AX)
    for x: float in [-33.0, -27.0]:
        _dbrack(Vector3(x, 0, 39), -AZ)
    _plates(Vector3(-21, 0, 39), -AZ)
    _lockers(Vector3(-15.5, 0, 33), -AX, 6.0)
    for x: float in [-30.0, -24.0]:
        _bench(Vector3(x, 0, 11), AZ)
    # east wing (free weights)
    for z: float in [17.5, 21.0, 31.0]:
        _rack(Vector3(39, 0, z), -AX)
    _plates(Vector3(39, 0, 35.5), -AX)
    for x: float in [21.0, 27.0]:
        _dbrack(Vector3(x, 0, 39), -AZ)
    _plates(Vector3(33, 0, 39), -AZ)
    _lockers(Vector3(15.5, 0, 33), AX, 6.0)
    for x: float in [24.0, 30.0]:
        _bench(Vector3(x, 0, 11), AZ)
    # catwalk
    var cy: float = 5.25
    for x: float in [-33.0, 33.0]:
        _plates(Vector3(x, cy, -19), AZ)
    for x: float in [-8.0, 8.0]:
        _crates(Vector3(x, cy, -19), AZ)
    for x: float in [-24.0, 24.0]:
        _dbrack(Vector3(x, cy, -19), AZ)
    _bench(Vector3(-39, cy, -13.5), AX)
    _bench(Vector3(39, cy, -13.5), -AX)


# ------------------------------------------------- posters, mirrors, signs

func _poster(c: Vector3, nrm: Vector3, w: float, h: float, paper: Color, text: String) -> void:
    _wb(c, nrm, w + 0.16, h + 0.16, 0.05, DARK)
    _wq(c, nrm, w, h, paper, false, 0.06)
    _wq(c - AY * (h * 0.38), nrm, w, h * 0.2, DARK, false, 0.075)
    var tcol: Color = Color(0.06, 0.06, 0.07) if paper.get_luminance() > 0.35 else Color(0.95, 0.95, 0.9)
    var th: float = minf(h * 0.22, (w * 0.86) / (maxf(1.0, float(text.length())) * 0.62))
    _label(text, c + AY * (h * 0.1) + nrm * 0.09, nrm, th, tcol, 3)


func _mirror(c: Vector3, nrm: Vector3, w: float, h: float) -> void:
    _wb(c, nrm, w + 0.2, h + 0.2, 0.06, DARK)
    _wq(c, nrm, w, h, Color(0.38, 0.46, 0.52), true, 0.07)
    _wq(c + AY.cross(nrm) * (w * 0.22), nrm, w * 0.07, h, Color(0.55, 0.64, 0.7), true, 0.075)


func _posters() -> void:
    var papers: Array = [Color(0.6, 0.1, 0.09), Color(0.9, 0.7, 0.08), Color(0.1, 0.45, 0.5), Color(0.85, 0.4, 0.1), Color(0.8, 0.8, 0.76), Color(0.15, 0.15, 0.2)]
    var words: Array = ["NO PAIN NO GAINS", "LEG DAY", "NEVER SKIP", "PR OR DIE", "DONT QUIT", "HYDRATE", "LIFT HEAVY", "PUSH", "PULL", "SQUAT", "EAT MEAT", "GRIND"]
    # x, y, z, nx, nz, w, h
    var spots: Array = [
        [-39.0, 3.2, -6.5, 1, 0, 1.4, 2.0], [-39.0, 3.2, 3.0, 1, 0, 1.4, 2.0],
        [39.0, 3.2, -6.5, -1, 0, 1.4, 2.0], [39.0, 3.2, 3.0, -1, 0, 1.4, 2.0],
        [-27.0, 3.4, 9.0, 0, -1, 1.4, 2.0], [-15.0, 3.4, 9.0, 0, -1, 1.4, 2.0],
        [15.0, 3.4, 9.0, 0, -1, 1.4, 2.0], [27.0, 3.4, 9.0, 0, -1, 1.4, 2.0],
        [-30.0, 3.4, -10.5, 0, 1, 1.3, 1.4], [-19.0, 3.4, -10.5, 0, 1, 1.3, 1.4],
        [19.0, 3.4, -10.5, 0, 1, 1.3, 1.4], [30.0, 3.4, -10.5, 0, 1, 1.3, 1.4],
        [-9.0, 3.4, 39.0, 0, -1, 1.4, 2.0], [9.0, 3.4, 39.0, 0, -1, 1.4, 2.0],
        [-14.5, 3.4, 32.0, 1, 0, 1.4, 2.0], [-14.5, 3.4, 22.5, 1, 0, 1.4, 2.0],
        [14.5, 3.4, 32.0, -1, 0, 1.4, 2.0], [14.5, 3.4, 22.5, -1, 0, 1.4, 2.0],
        [-8.0, 3.4, 11.0, 0, 1, 1.4, 2.0], [8.0, 3.4, 11.0, 0, 1, 1.4, 2.0],
        [-39.0, 3.4, 28.0, 1, 0, 1.4, 2.0], [-21.0, 3.4, 39.0, 0, -1, 1.4, 2.0],
        [-30.0, 3.4, 11.0, 0, 1, 1.4, 2.0], [-24.0, 3.4, 11.0, 0, 1, 1.4, 2.0],
        [-15.5, 3.6, 33.0, -1, 0, 1.4, 2.0], [-15.5, 3.4, 22.5, -1, 0, 1.4, 2.0],
        [39.0, 3.4, 28.0, -1, 0, 1.4, 2.0], [33.0, 3.4, 39.0, 0, -1, 1.4, 2.0],
        [24.0, 3.4, 11.0, 0, 1, 1.4, 2.0], [30.0, 3.4, 11.0, 0, 1, 1.4, 2.0],
        [15.5, 3.6, 33.0, 1, 0, 1.4, 2.0], [15.5, 3.4, 22.5, 1, 0, 1.4, 2.0],
        [-33.0, 6.9, -19.0, 0, 1, 1.4, 1.6], [-24.0, 6.9, -19.0, 0, 1, 1.4, 1.6],
        [-8.0, 6.9, -19.0, 0, 1, 1.4, 1.6], [8.0, 6.9, -19.0, 0, 1, 1.4, 1.6],
        [24.0, 6.9, -19.0, 0, 1, 1.4, 1.6], [33.0, 6.9, -19.0, 0, 1, 1.4, 1.6],
        [-39.0, 6.9, -13.5, 1, 0, 1.4, 1.6], [39.0, 6.9, -13.5, -1, 0, 1.4, 1.6],
    ]
    var i: int = 0
    for s in spots:
        _poster(Vector3(s[0], s[1], s[2]), Vector3(s[3], 0, s[4]), s[5], s[6], papers[i % papers.size()], words[i % words.size()])
        i += 1
    # x, y, z, nx, nz, w, h
    var mirrors: Array = [
        [-12.0, 2.3, -10.5, 0, 1, 2.6, 1.8], [12.0, 2.3, -10.5, 0, 1, 2.6, 1.8],
        [-39.0, 2.4, 19.0, 1, 0, 5.0, 1.8], [-39.0, 2.4, 33.25, 1, 0, 7.5, 1.8],
        [-30.0, 2.4, 39.0, 0, -1, 6.5, 1.8],
        [39.0, 2.4, 19.25, -1, 0, 5.5, 1.8], [39.0, 2.4, 31.0, -1, 0, 3.5, 1.8],
        [24.0, 2.4, 39.0, 0, -1, 8.0, 1.8],
    ]
    for m in mirrors:
        _mirror(Vector3(m[0], m[1], m[2]), Vector3(m[3], 0, m[4]), m[5], m[6])


func _sign(text: String, p: Vector3, nrm: Vector3, h: float, col: Color) -> void:
    var w: float = float(text.length()) * 0.62 * h + 0.6
    _wb(p, nrm, w, h + 0.35, 0.07, DARK)
    _label(text, p + nrm * 0.1, nrm, h, col, 8)


func _signs() -> void:
    _sign("GYM COMPOUND", Vector3(-12, 6.5, 9.0), -AZ, 1.3, YELLOW)
    _sign("NO PAIN NO GAINS", Vector3(14, 6.5, 9.0), -AZ, 0.9, WHITE)
    _sign("ARMORY", Vector3(0, 4.7, 39.0), -AZ, 0.9, YELLOW)
    _sign("CARDIO", Vector3(-39, 6.3, 22.0), AX, 1.3, Color(0.4, 0.9, 1.0))
    _sign("FREE WEIGHTS", Vector3(39, 6.3, 22.0), -AX, 1.0, ORANGE)
    _sign("LEVEL 2", Vector3(0, 7.6, -19.0), AZ, 0.9, YELLOW)


func _fixture(p: Vector3, nrm: Vector3) -> void:
    _wb(p, nrm, 0.7, 0.4, 0.28, DARK)
    _wq(p, nrm, 0.5, 0.2, Color(1.0, 0.92, 0.75), true, 0.29)


func _fixtures() -> void:
    var y: float = 7.6
    for z: float in [-6.0, 4.0, 22.5, 34.0]:
        _fixture(Vector3(-39.0, y, z), AX)
        _fixture(Vector3(39.0, y, z), -AX)
    for x: float in [-28.0, -12.0, 12.0, 28.0]:
        _fixture(Vector3(x, y, 9.0), -AZ)
    for x: float in [-30.0, -22.0, -8.0, 8.0, 22.0, 30.0]:
        _fixture(Vector3(x, y, 39.0), -AZ)
    for x: float in [-30.0, -12.0, 12.0, 30.0]:
        _fixture(Vector3(x, y, -19.0), AZ)
    _fixture(Vector3(-39.0, y, -13.5), AX)
    _fixture(Vector3(39.0, y, -13.5), -AX)


# ------------------------------------------------------------------- blood

func _smear(c: Vector3, nrm: Vector3, w: float, h: float) -> void:
    var r: Vector3 = AY.cross(nrm)
    _wq(c, nrm, w, h, BLOOD, false, 0.03)
    for i in 3:
        var dx: float = (float(i) - 1.0) * w * 0.3
        var ln: float = _rng.randf_range(0.5, 1.2)
        _wq(c + r * dx - AY * (h * 0.5 + ln * 0.5), nrm, 0.07, ln, BLOOD, false, 0.03)


func _blood() -> void:
    var floor_spots: Array = [
        [-8, 5, 1.1], [10, 2, 0.9], [-20, -4, 1.4], [18, -6, 1.0], [-3, 20, 1.2],
        [6, 30, 1.0], [-12, 16, 0.9], [-27, 20, 1.2], [-33, 33, 1.0], [26, 18, 1.1],
        [31, 34, 1.3], [22, 26, 0.8], [-24, 6, 1.0], [24, 6, 1.0], [0, 13, 1.3],
        [-25, 5, 0.8], [25, 5, 0.8],
    ]
    for s in floor_spots:
        _blob(float(s[0]), float(s[1]), float(s[2]), 0.035)
    var cat_spots: Array = [[-10, -14, 1.1], [12, -12, 1.3], [-30, -15, 0.9], [28, -16, 1.0]]
    for s in cat_spots:
        _blob(float(s[0]), float(s[1]), float(s[2]), 5.285)
    _smear(Vector3(-39, 2.3, -2.0), AX, 1.2, 0.9)
    _smear(Vector3(39, 2.3, -1.0), -AX, 1.2, 0.9)
    _smear(Vector3(-20, 2.0, 9.0), -AZ, 1.4, 0.9)
    _smear(Vector3(22, 2.4, 9.0), -AZ, 1.2, 0.8)
    _smear(Vector3(-39, 2.6, 27.5), AX, 1.2, 0.8)
    _smear(Vector3(39, 2.6, 27.5), -AX, 1.2, 0.8)
    _smear(Vector3(-21, 6.6, -19.0), AZ, 1.3, 0.9)


# ------------------------------------------------------- doors and rings

func _door_deco(door_name: String, c: Vector3, nrm: Vector3, w: float, text: String, rubble: bool) -> void:
    var door: Node = get_parent().get_node_or_null("BuyableDoors/" + door_name)
    if door == null:
        return
    var holder := Node3D.new()
    holder.name = "Deco"
    holder.top_level = true
    door.add_child(holder)
    var along_x: bool = absf(nrm.x) > 0.5
    var tape := Vector3(0.05, 0.28, w) if along_x else Vector3(w, 0.28, 0.05)
    for y: float in [1.0, 1.55]:
        _node_box(holder, c + Vector3(0, y, 0) + nrm * 0.03, tape, YELLOW)
    var panel := Vector3(0.06, 1.1, w * 0.9) if along_x else Vector3(w * 0.9, 1.1, 0.06)
    _node_box(holder, c + Vector3(0, 3.4, 0) + nrm * 0.04, panel, DARK)
    _label(text, c + Vector3(0, 3.4, 0) + nrm * 0.09, nrm, 0.42, YELLOW, 8, holder)
    if rubble:
        var rv: Vector3 = AY.cross(nrm)
        for i in 7:
            var s: float = _rng.randf_range(0.3, 0.7)
            var off: Vector3 = rv * _rng.randf_range(-w * 0.45, w * 0.45) + nrm * _rng.randf_range(0.25, 0.55)
            var col: Color = Color(0.3, 0.27, 0.23).lerp(Color(0.16, 0.15, 0.14), _rng.randf())
            var tilt := Vector3(_rng.randf_range(-12.0, 12.0), _rng.randf_range(0.0, 80.0), _rng.randf_range(-12.0, 12.0))
            _node_box(holder, c + off + Vector3(0, s * 0.4, 0), Vector3(s, s * 0.8, s), col, tilt)


func _doors() -> void:
    _door_deco("DoorWestWing", Vector3(-14.8, 0, 17.5), AX, 5.0, "WEST WING\nCLOSED", false)
    _door_deco("DoorEastWing", Vector3(14.8, 0, 17.5), -AX, 5.0, "EAST WING\nCLOSED", false)
    _door_deco("DebrisWestStairs", Vector3(-25, 0, 3.4), AZ, 4.0, "STAIRS\nBLOCKED", true)
    _door_deco("DebrisEastStairs", Vector3(25, 0, 3.4), AZ, 4.0, "STAIRS\nBLOCKED", true)


func _late_rings() -> void:
    await get_tree().process_frame
    if not is_inside_tree():
        return
    var st: Node = get_parent().get_node_or_null("Stations")
    if st == null:
        return
    for s in st.get_children():
        var s3 := s as Node3D
        if s3 == null:
            continue
        var p: Vector3 = s3.global_position
        var fy: float = 5.25 if p.y > 3.0 else 0.0
        var col: Color = YELLOW
        var bc: Variant = s3.get("body_color")
        if typeof(bc) == TYPE_COLOR:
            col = bc
        var nm: String = str(s3.name)
        var big: bool = nm.begins_with("PRRack") or nm.begins_with("LootLocker")
        var r0: float = 1.7 if big else 1.05
        _ring(Vector3(p.x, fy + 0.04, p.z), r0, r0 + 0.18, col.darkened(0.2), 24, true)
    _flush()

# END OF FILE
