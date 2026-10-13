extends Node3D
## Shared helpers for the map visual dressers (multi_room_dresser.gd and later maps).
## Cosmetic only. Everything is batched into one mesh per material.
## The runtime navmesh bake parses every mesh under the map, so ceilings, beams
## and light strips are built WITHOUT upward-facing surfaces.

const C_FLOOR := Color(0.12, 0.12, 0.14)
const C_WALL := Color(0.15, 0.15, 0.17)
const C_PANEL := Color(0.21, 0.21, 0.24)
const C_BLACK := Color(0.04, 0.04, 0.05)
const C_YELLOW := Color(1.0, 0.77, 0.0)
const C_RED := Color(0.75, 0.08, 0.08)
const C_STEEL := Color(0.30, 0.31, 0.35)
const C_WHITE := Color(0.90, 0.90, 0.86)
const C_BLOOD := Color(0.32, 0.02, 0.02)
const C_BLOOD2 := Color(0.20, 0.01, 0.01)
const C_BLUE := Color(0.25, 0.6, 0.9)
const C_GREEN := Color(0.2, 0.7, 0.35)

const BOX_FACES = [
    [Vector3(1, 0, 0), [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)]],
    [Vector3(-1, 0, 0), [Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1)]],
    [Vector3(0, 1, 0), [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
    [Vector3(0, -1, 0), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)]],
    [Vector3(0, 0, 1), [Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1)]],
    [Vector3(0, 0, -1), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
]

var _batches := {}
var _pm := {}


# ---------------------------------------------------------------- environment

func _std(color: Color, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    return m


func _setup_environment(fog_density: float, ambient: float, sun_energy: float) -> void:
    var p := get_parent()
    var we := p.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we != null and we.environment != null:
        var env := we.environment
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.03, 0.03, 0.04)
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.85, 0.86, 0.95)
        env.ambient_light_energy = ambient
        env.ssao_enabled = false
        env.glow_enabled = false
        env.fog_enabled = true
        env.fog_light_color = Color(0.07, 0.07, 0.09)
        env.fog_density = fog_density
    var sun := p.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
    if sun != null:
        sun.light_color = Color(1.0, 0.95, 0.85)
        sun.light_energy = sun_energy
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
        sun.directional_shadow_max_distance = 70.0


# ---------------------------------------------------------------- batching

func _mk(color: Color, emit: float = 0.0, cast: bool = true, metal: float = 0.0, rough: float = 0.9) -> String:
    var k := "%s|%s|%s|%s|%s" % [color.to_html(false), emit, cast, metal, rough]
    if not _batches.has(k):
        _batches[k] = {"color": color, "emit": emit, "cast": cast, "metal": metal, "rough": rough, "v": [], "n": []}
    return k


func _tri(k: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
    var bb := b
    var cc := c
    if (b - a).cross(c - a).dot(n) > 0.0:
        bb = c
        cc = b
    var bt: Dictionary = _batches[k]
    var v: Array = bt["v"]
    var nn: Array = bt["n"]
    v.append(a)
    v.append(bb)
    v.append(cc)
    nn.append(n)
    nn.append(n)
    nn.append(n)


func _quad(k: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
    _tri(k, a, b, c, n)
    _tri(k, a, c, d, n)


func _box(k: String, c: Vector3, size: Vector3, yaw: float = 0.0, skip_top: bool = false) -> void:
    var bs := Basis(Vector3.UP, yaw)
    var h := size * 0.5
    var skip_bottom := (c.y - h.y) < 0.02
    for f in BOX_FACES:
        var nrm: Vector3 = f[0]
        if skip_bottom and nrm.y < -0.5:
            continue
        if skip_top and nrm.y > 0.5:
            continue
        var pts: Array = f[1]
        var p: Array = []
        for s in pts:
            var sv: Vector3 = s
            p.append(c + bs * Vector3(sv.x * h.x, sv.y * h.y, sv.z * h.z))
        _quad(k, p[0], p[1], p[2], p[3], bs * nrm)


func _cp(axis: int, ang: float, along: float, r: float) -> Vector3:
    var px := cos(ang) * r
    var py := sin(ang) * r
    if axis == 0:
        return Vector3(along, px, py)
    if axis == 2:
        return Vector3(px, py, along)
    return Vector3(px, along, py)


func _cyl(k: String, c: Vector3, r: float, h: float, axis: int = 1, seg: int = 8, yaw: float = 0.0) -> void:
    var bs := Basis(Vector3.UP, yaw)
    var hh := h * 0.5
    var ax := bs * _cp(axis, 0.0, 1.0, 0.0)
    for i in seg:
        var a0 := TAU * float(i) / float(seg)
        var a1 := TAU * float(i + 1) / float(seg)
        var am := (a0 + a1) * 0.5
        var p00 := c + bs * _cp(axis, a0, -hh, r)
        var p10 := c + bs * _cp(axis, a1, -hh, r)
        var p11 := c + bs * _cp(axis, a1, hh, r)
        var p01 := c + bs * _cp(axis, a0, hh, r)
        _quad(k, p00, p10, p11, p01, bs * _cp(axis, am, 0.0, 1.0))
        _tri(k, c + bs * _cp(axis, 0.0, hh, 0.0), p01, p11, ax)
        _tri(k, c + bs * _cp(axis, 0.0, -hh, 0.0), p10, p00, -ax)


func _floor_rect(k: String, cx: float, cz: float, w: float, d: float, y: float = 0.02) -> void:
    var hw := w * 0.5
    var hd := d * 0.5
    _quad(k, Vector3(cx - hw, y, cz - hd), Vector3(cx + hw, y, cz - hd), Vector3(cx + hw, y, cz + hd), Vector3(cx - hw, y, cz + hd), Vector3.UP)


func _floor_disc(k: String, cx: float, cz: float, r: float, y: float, sx: float = 1.0, seg: int = 8) -> void:
    var c := Vector3(cx, y, cz)
    for i in seg:
        var a0 := TAU * float(i) / float(seg)
        var a1 := TAU * float(i + 1) / float(seg)
        _tri(k, c, c + Vector3(cos(a0) * r * sx, 0.0, sin(a0) * r), c + Vector3(cos(a1) * r * sx, 0.0, sin(a1) * r), Vector3.UP)


func _floor_outline(k: String, cx: float, cz: float, w: float, d: float, y: float = 0.03, t: float = 0.14) -> void:
    _floor_rect(k, cx, cz - d * 0.5, w, t, y)
    _floor_rect(k, cx, cz + d * 0.5, w, t, y)
    _floor_rect(k, cx - w * 0.5, cz, t, d, y)
    _floor_rect(k, cx + w * 0.5, cz, t, d, y)


# ---------------------------------------------------------------- wall frames
# A frame = [origin on the wall plane, inward normal, tangent]. u runs along
# the tangent (the viewer's right when facing the wall).

func _fr(origin: Vector3, n: Vector3) -> Array:
    return [origin, n, Vector3(n.z, 0.0, -n.x)]


func _wp(f: Array, u: float, y: float, off: float = 0.0) -> Vector3:
    var o: Vector3 = f[0]
    var n: Vector3 = f[1]
    var t: Vector3 = f[2]
    return o + t * u + Vector3(0.0, y, 0.0) + n * off


func _wyaw(f: Array) -> float:
    var n: Vector3 = f[1]
    return atan2(n.x, n.z)


func _u(f: Array, x: float, z: float) -> float:
    var o: Vector3 = f[0]
    var t: Vector3 = f[2]
    return (Vector3(x, 0.0, z) - o).dot(t)


func _wall_rect(k: String, f: Array, u0: float, u1: float, y0: float, y1: float, off: float = 0.03) -> void:
    var n: Vector3 = f[1]
    _quad(k, _wp(f, u0, y0, off), _wp(f, u1, y0, off), _wp(f, u1, y1, off), _wp(f, u0, y1, off), n)


func _wall_para(k: String, f: Array, u: float, wd: float, y0: float, y1: float, slant: float, off: float) -> void:
    var n: Vector3 = f[1]
    _quad(k, _wp(f, u, y0, off), _wp(f, u + wd, y0, off), _wp(f, u + wd + slant, y1, off), _wp(f, u + slant, y1, off), n)


func _dress_wall(f: Array, half: float, y0: float, y1: float, accent: Color) -> void:
    var dark := _mk(C_BLACK, 0.0, false)
    var panel := _mk(C_PANEL, 0.0, false)
    var acc := _mk(accent, 0.0, false)
    _wall_rect(dark, f, -half, half, y0, y0 + 0.5, 0.03)
    _wall_rect(panel, f, -half, half, y0 + 0.5, minf(y0 + 3.0, y1 - 1.0), 0.02)
    var u := -half + 0.1
    while u < half - 0.9:
        _wall_para(acc, f, u, 0.5, y0, y0 + 0.5, 0.35, 0.04)
        u += 1.1
    _wall_rect(acc, f, -half, half, y0 + 3.0, y0 + 3.08, 0.03)
    _wall_rect(acc, f, -half, half, y1 - 0.9, y1 - 0.65, 0.03)


func _mirror(f: Array, u0: float, u1: float, y0: float = 0.9, y1: float = 4.6) -> void:
    var frame := _mk(C_BLACK, 0.0, false)
    var glass := _mk(Color(0.55, 0.68, 0.80), 0.3, false)
    _wall_rect(frame, f, u0 - 0.15, u1 + 0.15, y0 - 0.15, y1 + 0.15, 0.04)
    _wall_rect(glass, f, u0, u1, y0, y1, 0.05)
    var u := u0 + 3.0
    while u < u1 - 0.5:
        _wall_rect(frame, f, u - 0.04, u + 0.04, y0, y1, 0.06)
        u += 3.0


func _poster(f: Array, u: float, y: float, wd: float, ht: float, bg: Color, text: String, fg: Color) -> void:
    _wall_rect(_mk(C_BLACK, 0.0, false), f, u - wd * 0.5 - 0.15, u + wd * 0.5 + 0.15, y - ht * 0.5 - 0.15, y + ht * 0.5 + 0.15, 0.04)
    _wall_rect(_mk(bg, 0.0, false), f, u - wd * 0.5, u + wd * 0.5, y - ht * 0.5, y + ht * 0.5, 0.05)
    var lines := text.split("\n")
    var longest := 1
    for ln in lines:
        longest = maxi(longest, ln.length())
    var ps := minf((wd * 0.82) / (float(longest) * 64.0 * 0.66), (ht * 0.78) / (float(lines.size()) * 64.0 * 1.25))
    _label(text, _wp(f, u, y, 0.075), _wyaw(f), ps, fg, fg, 6, false)


func _label(text: String, pos: Vector3, yaw: float, ps: float, col: Color, ocol: Color, osize: int, billboard: bool) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = 64
    l.pixel_size = ps
    l.modulate = col
    l.outline_modulate = ocol
    l.outline_size = osize
    l.shaded = false
    l.double_sided = true
    l.position = pos
    l.rotation.y = yaw
    if billboard:
        l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(l)


# ---------------------------------------------------------------- local-space helpers

func _lbox(k: String, pos: Vector3, yaw: float, lc: Vector3, size: Vector3) -> void:
    _box(k, pos + Basis(Vector3.UP, yaw) * lc, size, yaw)


func _lcyl(k: String, pos: Vector3, yaw: float, lc: Vector3, r: float, h: float, axis: int, seg: int = 8) -> void:
    _cyl(k, pos + Basis(Vector3.UP, yaw) * lc, r, h, axis, seg, yaw)


func _solid(pos: Vector3, yaw: float, lc: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = size
    cs.shape = sh
    body.add_child(cs)
    body.position = pos + Basis(Vector3.UP, yaw) * lc
    body.rotation.y = yaw
    add_child(body)


# ---------------------------------------------------------------- props
# Props stand against a wall frame at position u. yb = floor height (5.25 on a catwalk).

func _init_props() -> void:
    _pm = {
        "steel": _mk(C_STEEL, 0.0, true, 0.0, 0.5),
        "black": _mk(Color(0.06, 0.06, 0.07), 0.0, true, 0.0, 0.6),
        "chrome": _mk(Color(0.72, 0.72, 0.76), 0.0, true, 0.0, 0.35),
        "red": _mk(C_RED, 0.0, true, 0.0, 0.6),
        "pad": _mk(Color(0.10, 0.10, 0.13), 0.0, true, 0.0, 0.7),
    }


func _dumbbell_rack(f: Array, u: float, yb: float = 0.0) -> void:
    var steel: String = _pm["steel"]
    var black: String = _pm["black"]
    var chrome: String = _pm["chrome"]
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    _lbox(steel, pos, yaw, Vector3(0.0, 0.5, 0.04), Vector3(2.4, 1.0, 0.05))
    for sx in [-1.0, 1.0]:
        _lbox(steel, pos, yaw, Vector3(float(sx) * 1.16, 0.5, 0.28), Vector3(0.08, 1.0, 0.5))
    for ty in [0.38, 0.78]:
        var tier := float(ty)
        _lbox(steel, pos, yaw, Vector3(0.0, tier, 0.28), Vector3(2.4, 0.05, 0.5))
        for i in 6:
            var dx := -0.95 + float(i) * 0.38
            var r := 0.055 + 0.009 * float(i)
            var cy := tier + 0.025 + r
            _lbox(chrome, pos, yaw, Vector3(dx, cy, 0.28), Vector3(0.03, 0.03, 0.30))
            _lcyl(black, pos, yaw, Vector3(dx, cy, 0.15), r, 0.06, 2, 6)
            _lcyl(black, pos, yaw, Vector3(dx, cy, 0.41), r, 0.06, 2, 6)
    _solid(pos, yaw, Vector3(0.0, 0.55, 0.28), Vector3(2.4, 1.1, 0.56))


func _barbell_rack(f: Array, u: float, yb: float = 0.0) -> void:
    var steel: String = _pm["steel"]
    var black: String = _pm["black"]
    var chrome: String = _pm["chrome"]
    var red: String = _pm["red"]
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    for sx in [-1.0, 1.0]:
        _lbox(steel, pos, yaw, Vector3(float(sx) * 0.85, 0.75, 0.25), Vector3(0.08, 1.5, 0.5))
    var i := 0
    for by in [0.45, 0.9, 1.35]:
        _lcyl(chrome, pos, yaw, Vector3(0.0, float(by), 0.25), 0.025, 2.1, 0, 6)
        for sx in [-1.0, 1.0]:
            var pk: String = black if i % 2 == 0 else red
            _lcyl(pk, pos, yaw, Vector3(float(sx) * 0.95, float(by), 0.25), 0.2, 0.05, 0, 10)
        i += 1
    _solid(pos, yaw, Vector3(0.0, 0.8, 0.28), Vector3(2.2, 1.6, 0.55))


func _bench_press(f: Array, u: float, yb: float = 0.0) -> void:
    var steel: String = _pm["steel"]
    var black: String = _pm["black"]
    var chrome: String = _pm["chrome"]
    var red: String = _pm["red"]
    var pad: String = _pm["pad"]
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    _lbox(pad, pos, yaw, Vector3(0.0, 0.45, 1.0), Vector3(0.42, 0.12, 1.3))
    _lbox(steel, pos, yaw, Vector3(0.0, 0.22, 0.5), Vector3(0.5, 0.45, 0.08))
    _lbox(steel, pos, yaw, Vector3(0.0, 0.22, 1.5), Vector3(0.5, 0.45, 0.08))
    for sx in [-1.0, 1.0]:
        _lbox(steel, pos, yaw, Vector3(float(sx) * 0.55, 0.57, 0.5), Vector3(0.07, 1.15, 0.07))
        _lcyl(black, pos, yaw, Vector3(float(sx) * 0.95, 1.05, 0.5), 0.24, 0.06, 0, 10)
        _lcyl(red, pos, yaw, Vector3(float(sx) * 1.03, 1.05, 0.5), 0.2, 0.05, 0, 10)
    _lcyl(chrome, pos, yaw, Vector3(0.0, 1.05, 0.5), 0.025, 2.2, 0, 6)
    _solid(pos, yaw, Vector3(0.0, 0.6, 0.95), Vector3(2.4, 1.2, 1.5))


func _treadmill(f: Array, u: float, yb: float = 0.0) -> void:
    var steel: String = _pm["steel"]
    var black: String = _pm["black"]
    var pad: String = _pm["pad"]
    var screen := _mk(C_BLUE, 1.2, false)
    var pos := _wp(f, u, yb, 0.02)
    var yaw := _wyaw(f)
    _lbox(pad, pos, yaw, Vector3(0.0, 0.14, 1.15), Vector3(0.8, 0.2, 1.9))
    _lbox(black, pos, yaw, Vector3(0.0, 0.25, 1.2), Vector3(0.6, 0.02, 1.5))
    for sx in [-1.0, 1.0]:
        _lbox(steel, pos, yaw, Vector3(float(sx) * 0.42, 0.3, 1.15), Vector3(0.05, 0.3, 1.9))
        _lbox(steel, pos, yaw, Vector3(float(sx) * 0.38, 0.8, 0.35), Vector3(0.05, 1.2, 0.05))
    _lbox(black, pos, yaw, Vector3(0.0, 1.3, 0.35), Vector3(0.85, 0.3, 0.18))
    _lbox(screen, pos, yaw, Vector3(0.0, 1.31, 0.45), Vector3(0.5, 0.14, 0.02))
    _solid(pos, yaw, Vector3(0.0, 0.75, 1.0), Vector3(0.95, 1.5, 2.0))


func _plate_stack(x: float, yb: float, z: float) -> void:
    var black: String = _pm["black"]
    var red: String = _pm["red"]
    var chrome: String = _pm["chrome"]
    for i in 7:
        var pk: String = red if i % 3 == 1 else black
        _cyl(pk, Vector3(x, yb + 0.03 + float(i) * 0.06, z), 0.30 - 0.004 * float(i), 0.06, 1, 10)
    _cyl(chrome, Vector3(x, yb + 0.55, z), 0.03, 0.3, 1, 6)
    _solid(Vector3(x, yb, z), 0.0, Vector3(0.0, 0.3, 0.0), Vector3(0.7, 0.6, 0.7))


# ---------------------------------------------------------------- blood

func _splat(rng: RandomNumberGenerator, k1: String, k2: String, cx: float, cz: float, y: float) -> void:
    for j in rng.randi_range(4, 7):
        var kk: String = k1 if j % 2 == 0 else k2
        _floor_disc(kk, cx + rng.randf_range(-0.7, 0.7), cz + rng.randf_range(-0.7, 0.7), rng.randf_range(0.08, 0.5), y + 0.034 + 0.002 * float(j), rng.randf_range(0.7, 1.5))
    _floor_rect(k2, cx + 0.6, cz, rng.randf_range(0.8, 1.8), 0.07, y + 0.04)


func _drip(rng: RandomNumberGenerator, k: String, f: Array, half: float, ymin: float, ymax: float) -> void:
    var u := rng.randf_range(-half + 1.0, half - 1.0)
    var y0 := rng.randf_range(ymin, ymax)
    var d := rng.randf_range(0.5, 2.0)
    _wall_rect(k, f, u - 0.05, u + 0.05, y0 - d, y0, 0.07)
    _wall_rect(k, f, u - 0.18, u + 0.18, y0 - 0.15, y0 + 0.15, 0.068)


# ---------------------------------------------------------------- flush

func _flush() -> void:
    for k in _batches:
        var bt: Dictionary = _batches[k]
        var v: Array = bt["v"]
        if v.is_empty():
            continue
        var arrays := []
        arrays.resize(Mesh.ARRAY_MAX)
        arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(v)
        arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(bt["n"])
        var mesh := ArrayMesh.new()
        mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = bt["color"]
        mat.roughness = bt["rough"]
        mat.metallic = bt["metal"]
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        if float(bt["emit"]) > 0.0:
            mat.emission_enabled = true
            mat.emission = bt["color"]
            mat.emission_energy_multiplier = bt["emit"]
        mesh.surface_set_material(0, mat)
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        if not bool(bt["cast"]):
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(mi)


# END OF FILE
