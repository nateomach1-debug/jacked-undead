extends Node3D
## Visual dressing for the Training Gym (main.tscn). Cosmetic only.
## Builds batched meshes at runtime (one mesh per material) so it stays cheap.
## Only a few wall-hugging props get collision; the open floor is untouched.

const HALF := 20.0
const CEIL_Y := 10.0
const USE_GLOW := false
const AMBIENT := 1.0
const SUN := 0.9

const C_FLOOR := Color(0.14, 0.14, 0.16)
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

# Wall frames: [inward normal, tangent (viewer's right when facing the wall)]
# 0 = north, 1 = east, 2 = south, 3 = west
const WALLS = [
    [Vector3(0, 0, 1), Vector3(1, 0, 0)],
    [Vector3(-1, 0, 0), Vector3(0, 0, 1)],
    [Vector3(0, 0, -1), Vector3(-1, 0, 0)],
    [Vector3(1, 0, 0), Vector3(0, 0, -1)],
]

const BOX_FACES = [
    [Vector3(1, 0, 0), [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)]],
    [Vector3(-1, 0, 0), [Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1)]],
    [Vector3(0, 1, 0), [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
    [Vector3(0, -1, 0), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)]],
    [Vector3(0, 0, 1), [Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1)]],
    [Vector3(0, 0, -1), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
]

var _batches := {}


func _ready() -> void:
    _setup_environment()
    _restyle_base()
    _build_floor()
    _build_walls()
    _build_ceiling()
    _build_zones()
    _build_props()
    _build_blood()
    _build_signs()
    _flush()


# ---------------------------------------------------------------- environment

func _setup_environment() -> void:
    var p := get_parent()
    var we := p.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we != null and we.environment != null:
        var env := we.environment
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.03, 0.03, 0.04)
        env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        env.ambient_light_color = Color(0.85, 0.86, 0.95)
        env.ambient_light_energy = AMBIENT
        env.ssao_enabled = false
        env.glow_enabled = USE_GLOW
        env.fog_enabled = true
        env.fog_light_color = Color(0.07, 0.07, 0.09)
        env.fog_density = 0.006
    var sun := p.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
    if sun != null:
        sun.light_color = Color(1.0, 0.95, 0.85)
        sun.light_energy = SUN
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
        sun.directional_shadow_max_distance = 45.0


func _std(color: Color, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    return m


func _restyle_base() -> void:
    var p := get_parent()
    var fm := p.get_node_or_null("Floor/MeshInstance3D") as MeshInstance3D
    if fm != null:
        fm.material_override = _std(C_FLOOR, 0.95)
    for n in ["WallNorth", "WallSouth", "WallEast", "WallWest"]:
        var wm := p.get_node_or_null("Walls/%s/MeshInstance3D" % n) as MeshInstance3D
        if wm != null:
            wm.material_override = _std(C_WALL, 0.95)


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


func _box(k: String, c: Vector3, size: Vector3, yaw: float = 0.0) -> void:
    var bs := Basis(Vector3.UP, yaw)
    var h := size * 0.5
    var skip_bottom := (c.y - h.y) < 0.02
    for f in BOX_FACES:
        var nrm: Vector3 = f[0]
        if skip_bottom and nrm.y < -0.5:
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


func _wp(w: int, u: float, y: float, off: float = 0.0) -> Vector3:
    var n: Vector3 = WALLS[w][0]
    var t: Vector3 = WALLS[w][1]
    return -n * HALF + t * u + Vector3(0.0, y, 0.0) + n * off


func _wyaw(w: int) -> float:
    var n: Vector3 = WALLS[w][0]
    return atan2(n.x, n.z)


func _wall_rect(k: String, w: int, u0: float, u1: float, y0: float, y1: float, off: float = 0.03) -> void:
    var n: Vector3 = WALLS[w][0]
    _quad(k, _wp(w, u0, y0, off), _wp(w, u1, y0, off), _wp(w, u1, y1, off), _wp(w, u0, y1, off), n)


func _wall_para(k: String, w: int, u: float, wd: float, y0: float, y1: float, slant: float, off: float) -> void:
    var n: Vector3 = WALLS[w][0]
    _quad(k, _wp(w, u, y0, off), _wp(w, u + wd, y0, off), _wp(w, u + wd + slant, y1, off), _wp(w, u + slant, y1, off), n)


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


# ---------------------------------------------------------------- floor (A)

func _build_floor() -> void:
    var seam := _mk(Color(0.07, 0.07, 0.08), 0.0, false)
    for i in range(-3, 4):
        var s := float(i) * 5.0
        _floor_rect(seam, s, 0.0, 0.06, 40.0, 0.02)
        _floor_rect(seam, 0.0, s, 40.0, 0.06, 0.02)
    var white := _mk(C_WHITE, 0.0, false)
    for z in [-10.0, 10.0]:
        for i in range(-4, 5):
            _floor_rect(white, float(i) * 3.6, float(z), 2.0, 0.12, 0.024)
    var tape := _mk(C_YELLOW, 0.0, false)
    _floor_rect(tape, 0.0, -19.2, 38.4, 0.28, 0.028)
    _floor_rect(tape, 0.0, 19.2, 38.4, 0.28, 0.028)
    _floor_rect(tape, 19.2, 0.0, 0.28, 38.4, 0.028)
    # west side leaves a gap in front of the gun wall buys (z 3.8 .. 17)
    _floor_rect(tape, -19.2, -7.7, 0.28, 23.0, 0.028)
    _floor_rect(tape, -19.2, 18.1, 0.28, 2.2, 0.028)


# ---------------------------------------------------------------- walls (B)

func _build_walls() -> void:
    var dark := _mk(C_BLACK, 0.0, false)
    var panel := _mk(C_PANEL, 0.0, false)
    var yel := _mk(C_YELLOW, 0.0, false)
    for w in 4:
        _wall_rect(panel, w, -19.9, 19.9, 0.5, 3.0, 0.02)
        _wall_rect(dark, w, -19.9, 19.9, 0.0, 0.5, 0.03)
        var u := -19.8
        while u < 19.0:
            _wall_para(yel, w, u, 0.5, 0.0, 0.5, 0.35, 0.04)
            u += 1.1
        _wall_rect(yel, w, -19.9, 19.9, 3.0, 3.08, 0.03)
        _wall_rect(yel, w, -19.9, 19.9, 8.9, 9.15, 0.03)
    # mirror walls: south (u -9..9) and west north half (u 4..16)
    _mirror(2, -9.0, 9.0)
    _mirror(3, 4.0, 16.0)
    # posters
    _poster(0, 0.0, 6.3, 15.0, 2.6, C_YELLOW, "JACKED UNDEAD GYM", C_BLACK)
    _poster(0, -14.5, 5.8, 7.0, 3.0, C_RED, "NO PAIN\nNO GAINS", C_WHITE)
    _poster(0, 14.5, 5.8, 7.0, 3.0, C_WHITE, "DON'T SKIP\nLEG DAY", C_BLACK)
    _poster(1, -10.0, 5.8, 8.0, 3.0, C_YELLOW, "LEG DAY IS\nEVERY DAY", C_BLACK)
    _poster(1, 10.0, 5.8, 8.0, 3.0, C_RED, "ONE MORE\nREP", C_WHITE)
    _poster(2, 0.0, 6.6, 12.0, 2.0, C_BLACK, "FEED THE GAINS", C_YELLOW)
    _poster(2, -14.0, 5.8, 7.0, 3.0, C_YELLOW, "STRONGER THAN\nYESTERDAY", C_BLACK)
    _poster(2, 14.0, 5.8, 7.0, 3.0, C_RED, "NO\nEXCUSES", C_WHITE)
    _poster(3, 10.0, 6.4, 8.0, 2.8, C_YELLOW, "CHALK UP.\nLOCK IN.", C_BLACK)
    _poster(3, -10.5, 4.3, 8.0, 1.1, C_BLACK, "ARMORY", C_YELLOW)
    _poster(3, -10.5, 6.9, 8.0, 2.6, C_RED, "DEADLIFT OR\nDIE TRYING", C_WHITE)


func _mirror(w: int, u0: float, u1: float) -> void:
    var frame := _mk(C_BLACK, 0.0, false)
    var glass := _mk(Color(0.55, 0.68, 0.80), 0.3, false)
    _wall_rect(frame, w, u0 - 0.15, u1 + 0.15, 0.75, 4.75, 0.04)
    _wall_rect(glass, w, u0, u1, 0.9, 4.6, 0.05)
    var u := u0 + 3.0
    while u < u1 - 0.5:
        _wall_rect(frame, w, u - 0.04, u + 0.04, 0.9, 4.6, 0.06)
        u += 3.0


func _poster(w: int, u: float, y: float, wd: float, ht: float, bg: Color, text: String, fg: Color) -> void:
    _wall_rect(_mk(C_BLACK, 0.0, false), w, u - wd * 0.5 - 0.15, u + wd * 0.5 + 0.15, y - ht * 0.5 - 0.15, y + ht * 0.5 + 0.15, 0.04)
    _wall_rect(_mk(bg, 0.0, false), w, u - wd * 0.5, u + wd * 0.5, y - ht * 0.5, y + ht * 0.5, 0.05)
    var lines := text.split("\n")
    var longest := 1
    for ln in lines:
        longest = maxi(longest, ln.length())
    var ps := minf((wd * 0.82) / (float(longest) * 64.0 * 0.66), (ht * 0.78) / (float(lines.size()) * 64.0 * 1.25))
    _label(text, _wp(w, u, y, 0.075), _wyaw(w), ps, fg, fg, 6, false)


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


# ---------------------------------------------------------------- ceiling (C)

func _build_ceiling() -> void:
    var ceil_k := _mk(Color(0.07, 0.07, 0.08), 0.0, false)
    _box(ceil_k, Vector3(0.0, CEIL_Y + 0.2, 0.0), Vector3(42.0, 0.4, 42.0))
    var beam := _mk(Color(0.22, 0.23, 0.26), 0.0, false)
    for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
        _box(beam, Vector3(0.0, 9.6, float(z)), Vector3(40.0, 0.5, 0.35))
    for x in [-12.0, 0.0, 12.0]:
        _box(beam, Vector3(float(x), 9.75, 0.0), Vector3(0.35, 0.3, 40.0))
    var strip := _mk(Color(1.0, 0.96, 0.82), 2.5, false)
    for x in [-8.0, 8.0]:
        for z in [-16.0, -8.0, 0.0, 8.0, 16.0]:
            _box(strip, Vector3(float(x), 9.22, float(z)), Vector3(3.2, 0.1, 0.28))


# ---------------------------------------------------------------- zones + signs (E)

func _build_zones() -> void:
    var yel := _mk(C_YELLOW, 0.0, false)
    var red := _mk(C_RED, 0.0, false)
    var blue := _mk(C_BLUE, 0.0, false)
    _floor_outline(yel, 10.0, 0.0, 13.6, 3.6)
    _floor_outline(red, 0.0, 8.0, 5.5, 5.5)
    _floor_outline(blue, -6.0, 6.0, 2.6, 2.6)
    _floor_outline(blue, 6.0, -6.0, 2.6, 2.6)
    _floor_outline(red, -18.35, 10.5, 2.9, 12.2)


func _build_signs() -> void:
    var black := Color(0, 0, 0)
    _label("SUPPLEMENT BAR", Vector3(10.0, 3.3, 0.0), 0.0, 0.008, C_YELLOW, black, 12, true)
    _label("PR ZONE", Vector3(0.0, 3.9, 8.0), 0.0, 0.008, Color(1.0, 0.3, 0.25), black, 12, true)
    _label("HYDRATION", Vector3(-6.0, 3.0, 6.0), 0.0, 0.006, C_BLUE, black, 12, true)
    _label("HYDRATION", Vector3(6.0, 3.0, -6.0), 0.0, 0.006, C_BLUE, black, 12, true)


# ---------------------------------------------------------------- props (D)

func _build_props() -> void:
    var steel := _mk(C_STEEL, 0.0, true, 0.0, 0.5)
    var black := _mk(Color(0.06, 0.06, 0.07), 0.0, true, 0.0, 0.6)
    var chrome := _mk(Color(0.72, 0.72, 0.76), 0.0, true, 0.0, 0.35)
    var red := _mk(C_RED, 0.0, true, 0.0, 0.6)
    var pad := _mk(Color(0.10, 0.10, 0.13), 0.0, true, 0.0, 0.7)
    for spec in [[0, 6.0], [0, 10.5], [1, -12.0], [1, -7.0], [1, 12.0], [2, 13.0], [2, -13.0]]:
        _dumbbell_rack(int(spec[0]), float(spec[1]), steel, black, chrome)
    for spec in [[0, -14.0], [1, -3.0]]:
        _barbell_rack(int(spec[0]), float(spec[1]), steel, black, red, chrome)
    for spec in [[1, 2.0], [0, 16.0]]:
        _bench_press(int(spec[0]), float(spec[1]), steel, black, red, chrome, pad)
    for c in [Vector2(-18.8, -18.8), Vector2(18.8, -18.8), Vector2(18.8, 18.8), Vector2(-18.8, 18.8)]:
        _plate_stack(c.x, c.y, black, red, chrome)


func _dumbbell_rack(w: int, u: float, steel: String, black: String, chrome: String) -> void:
    var pos := _wp(w, u, 0.0, 0.02)
    var yaw := _wyaw(w)
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


func _barbell_rack(w: int, u: float, steel: String, black: String, red: String, chrome: String) -> void:
    var pos := _wp(w, u, 0.0, 0.02)
    var yaw := _wyaw(w)
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


func _bench_press(w: int, u: float, steel: String, black: String, red: String, chrome: String, pad: String) -> void:
    var pos := _wp(w, u, 0.0, 0.02)
    var yaw := _wyaw(w)
    _lbox(pad, pos, yaw, Vector3(0.0, 0.45, 1.0), Vector3(0.42, 0.12, 1.3))
    _lbox(steel, pos, yaw, Vector3(0.0, 0.22, 0.5), Vector3(0.5, 0.45, 0.08))
    _lbox(steel, pos, yaw, Vector3(0.0, 0.22, 1.5), Vector3(0.5, 0.45, 0.08))
    for sx in [-1.0, 1.0]:
        _lbox(steel, pos, yaw, Vector3(float(sx) * 0.55, 0.57, 0.5), Vector3(0.07, 1.15, 0.07))
        _lcyl(black, pos, yaw, Vector3(float(sx) * 0.95, 1.05, 0.5), 0.24, 0.06, 0, 10)
        _lcyl(red, pos, yaw, Vector3(float(sx) * 1.03, 1.05, 0.5), 0.2, 0.05, 0, 10)
    _lcyl(chrome, pos, yaw, Vector3(0.0, 1.05, 0.5), 0.025, 2.2, 0, 6)
    _solid(pos, yaw, Vector3(0.0, 0.6, 0.95), Vector3(2.4, 1.2, 1.5))


func _plate_stack(x: float, z: float, black: String, red: String, chrome: String) -> void:
    for i in 7:
        var pk: String = red if i % 3 == 1 else black
        _cyl(pk, Vector3(x, 0.03 + float(i) * 0.06, z), 0.30 - 0.004 * float(i), 0.06, 1, 10)
    _cyl(chrome, Vector3(x, 0.55, z), 0.03, 0.3, 1, 6)
    _solid(Vector3(x, 0.0, z), 0.0, Vector3(0.0, 0.3, 0.0), Vector3(0.7, 0.6, 0.7))


# ---------------------------------------------------------------- blood (F)

func _build_blood() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261012
    var k1 := _mk(C_BLOOD, 0.0, false, 0.0, 0.35)
    var k2 := _mk(C_BLOOD2, 0.0, false, 0.0, 0.35)
    for i in 14:
        var cx := rng.randf_range(-17.0, 17.0)
        var cz := rng.randf_range(-17.0, 17.0)
        for j in rng.randi_range(4, 7):
            var kk: String = k1 if j % 2 == 0 else k2
            _floor_disc(kk, cx + rng.randf_range(-0.7, 0.7), cz + rng.randf_range(-0.7, 0.7), rng.randf_range(0.08, 0.5), 0.034 + 0.002 * float(j), rng.randf_range(0.7, 1.5))
        _floor_rect(k2, cx + 0.6, cz, rng.randf_range(0.8, 1.8), 0.07, 0.04)
    for i in 26:
        var w := rng.randi_range(0, 3)
        var u := rng.randf_range(-18.0, 18.0)
        var y0 := rng.randf_r
