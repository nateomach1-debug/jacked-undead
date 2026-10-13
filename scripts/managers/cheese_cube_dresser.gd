extends "res://scripts/managers/map_dress_base.gd"
## Cheese Cube visual dresser (cosmetic only).
## Lives OUTSIDE CheeseCubeBuilder/Geometry, so the nav bake never sees it.
## Must sit AFTER CheeseCubeBuilder and BEFORE NavBaker in the scene.

const HALF: float = 20.0
const RISE: float = 3.0
const FACE: float = 15.95
const LSIZE: Array = [8.0, 4.0, 4.0, 4.0, 4.0, 8.0, 4.0, 4.0, 8.0]
const CORNERS: Array = [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]
const TRIM: Array = [Vector2(-11.9, 15.9), Vector2(-15.9, 15.9), Vector2(-15.9, 15.9), Vector2(-15.9, 11.9)]
const WALL_DARK := Color(0.20, 0.19, 0.17)
const CHEESE := Color(0.96, 0.78, 0.22)
const RIM := Color(0.50, 0.40, 0.08)
const RAMP_DARK := Color(0.30, 0.22, 0.05)

var _bld: Node
var _rng := RandomNumberGenerator.new()
var _fs: Array = []
var _fe: Array = []
var _fn: Array = []
var _fw: Array = []
var _faces: Array = []
var _walls: Array = []
var _face_x: Array = [true, false, true, false]


func _ready() -> void:
    _rng.seed = 4242
    _bld = get_parent().get_node_or_null("CheeseCubeBuilder")
    if _bld == null:
        push_warning("CheeseCubeDresser: CheeseCubeBuilder not found")
        return
    _init_props()
    _setup_environment(0.006, 0.55, 0.0)
    _tint_lights()
    _make_frames()
    _do_floor()
    _do_walls()
    _do_ceiling()
    _do_stairs()
    _do_props()
    _do_signs()
    _do_blood()
    _flush()
    _door_tape()


func _tint_lights() -> void:
    for c in _bld.get_children():
        if c is OmniLight3D:
            var l: OmniLight3D = c
            l.light_color = Color(1.0, 0.9, 0.7)
            l.light_energy = 1.4


func _make_frames() -> void:
    # rail inner faces (lap 1 blocks): south, east, north, west
    _fs = _fr(Vector3(0.0, 0.0, FACE), Vector3(0.0, 0.0, -1.0))
    _fe = _fr(Vector3(FACE, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
    _fn = _fr(Vector3(0.0, 0.0, -FACE), Vector3(0.0, 0.0, 1.0))
    _fw = _fr(Vector3(-FACE, 0.0, 0.0), Vector3(1.0, 0.0, 0.0))
    _faces = [_fs, _fe, _fn, _fw]
    # real walls, same order
    _walls = [
        _fr(Vector3(0.0, 0.0, HALF), Vector3(0.0, 0.0, -1.0)),
        _fr(Vector3(HALF, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)),
        _fr(Vector3(0.0, 0.0, -HALF), Vector3(0.0, 0.0, 1.0)),
        _fr(Vector3(-HALF, 0.0, 0.0), Vector3(1.0, 0.0, 0.0)),
    ]


## position along a frame for a world coordinate c (x if ax is true, else z)
func _pu(f: Array, ax: bool, c: float) -> float:
    if ax:
        return _u(f, c, 0.0)
    return _u(f, 0.0, c)


func _mir(f: Array, ax: bool, c0: float, c1: float) -> void:
    var ua: float = _pu(f, ax, c0)
    var ub: float = _pu(f, ax, c1)
    _mirror(f, minf(ua, ub), maxf(ua, ub), 0.8, 2.3)


func _ring(ko: String, ki: String, x: float, y: float, z: float, r: float) -> void:
    _floor_disc(ko, x, z, r, y, 1.0, 14)
    _floor_disc(ki, x, z, r - 0.18, y + 0.01, 1.0, 14)


func _wall_disc(k: String, f: Array, u: float, y: float, r: float, off: float, seg: int = 10) -> void:
    var n: Vector3 = f[1]
    var t: Vector3 = f[2]
    var c: Vector3 = _wp(f, u, y, off)
    for i in seg:
        var a0: float = TAU * float(i) / float(seg)
        var a1: float = TAU * float(i + 1) / float(seg)
        _tri(k, c, c + t * cos(a0) * r + Vector3(0.0, sin(a0) * r, 0.0), c + t * cos(a1) * r + Vector3(0.0, sin(a1) * r, 0.0), n)


func _floor_label(text: String, x: float, y: float, z: float, ps: float, col: Color) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = 64
    l.pixel_size = ps
    l.modulate = col
    l.outline_modulate = C_BLACK
    l.outline_size = 6
    l.shaded = false
    l.double_sided = false
    l.position = Vector3(x, y, z)
    l.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
    add_child(l)


# ---------------------------------------------------------------- A floor

func _do_floor() -> void:
    var base := _mk(C_FLOOR, 0.0, false, 0.0, 0.85)
    var tile := _mk(Color(0.17, 0.17, 0.20), 0.0, false, 0.0, 0.8)
    var yel := _mk(C_YELLOW, 0.0, false)
    var blk := _mk(C_BLACK, 0.0, false)
    var chz := _mk(CHEESE, 0.0, false)
    var glow := _mk(C_YELLOW, 1.0, false)
    _floor_rect(base, 0.0, 0.0, 40.0, 40.0, 0.02)
    for i in 10:
        for j in 10:
            if (i + j) % 2 == 0:
                _floor_rect(tile, -18.0 + 4.0 * float(i), -18.0 + 4.0 * float(j), 4.0, 4.0, 0.03)
    _floor_outline(yel, 0.0, 0.0, 30.0, 30.0, 0.04, 0.14)
    # cheese wheel in the middle
    _floor_disc(blk, 0.0, 0.0, 5.4, 0.045, 1.0, 20)
    _floor_disc(chz, 0.0, 0.0, 5.0, 0.055, 1.0, 20)
    for p in [Vector2(-1.8, 1.2), Vector2(2.0, -1.5), Vector2(0.8, 2.7), Vector2(-2.4, -2.2)]:
        var pv: Vector2 = p
        _floor_disc(blk, pv.x, pv.y, 0.7, 0.065, 1.0, 10)
    # station markers on the floor
    _ring(glow, blk, 6.0, 0.05, 6.0, 1.3)
    _floor_outline(glow, 0.0, -14.4, 3.4, 1.8, 0.05, 0.1)
    _floor_outline(glow, -18.4, 14.0, 1.8, 3.0, 0.05, 0.1)
    _floor_outline(glow, -15.0, 18.4, 3.0, 1.8, 0.05, 0.1)
    _floor_label("START", -15.5, 0.08, 14.2, 0.012, C_YELLOW)
    # station markers on the landings
    for k in [1, 2, 3, 4, 6, 7, 8]:
        var kk: int = k
        var c: Vector2 = CORNERS[kk % 4]
        _ring(glow, blk, c.x * 18.8, RISE * float(kk) + 0.05, c.y * 18.8, 1.0)
    _ring(glow, blk, 14.0, RISE * 5.0 + 0.05, 14.0, 1.7)
    _ring(glow, blk, 18.8, RISE * 5.0 + 0.05, 18.8, 0.9)
    _ring(glow, blk, -14.5, RISE * 8.0 + 0.05, 19.4, 0.9)


# ---------------------------------------------------------------- B walls

func _do_walls() -> void:
    var wall := _mk(WALL_DARK, 0.0, false, 0.0, 0.9)
    var yel := _mk(C_YELLOW, 0.0, false)
    var rim := _mk(RIM, 0.0, false)
    var hole := _mk(C_BLACK, 0.0, false)
    for w in _walls:
        var f: Array = w
        _wall_rect(wall, f, -HALF, HALF, 0.0, 32.0, 0.01)
        for j in 10:
            var y0: float = 3.0 * float(j) + 2.9
            _wall_rect(yel, f, -HALF, HALF, y0, y0 + 0.1, 0.03)
        for i in 12:
            var u: float = _rng.randf_range(-17.0, 17.0)
            var y: float = _rng.randf_range(6.0, 30.0)
            var r: float = _rng.randf_range(0.5, 1.5)
            _wall_disc(rim, f, u, y, r + 0.14, 0.035)
            _wall_disc(hole, f, u, y, r, 0.045)
    # start bay walls
    _dress_wall(_fr(Vector3(-16.0, 0.0, HALF), Vector3(0.0, 0.0, -1.0)), 3.9, 0.0, 4.5, C_YELLOW)
    _dress_wall(_fr(Vector3(-HALF, 0.0, 16.0), Vector3(1.0, 0.0, 0.0)), 3.9, 0.0, 4.5, C_YELLOW)
    var cf: Array = _fr(Vector3(-17.975, 0.0, 12.4), Vector3(0.0, 0.0, 1.0))
    _poster(cf, 0.0, 3.2, 3.4, 1.8, C_RED, "WELCOME TO\nTHE CUBE", C_WHITE)


# ---------------------------------------------------------------- C ceiling

func _do_ceiling() -> void:
    var dark := _mk(Color(0.07, 0.07, 0.08), 0.0, false)
    var beam := _mk(Color(0.12, 0.12, 0.14), 0.0, false)
    var strip := _mk(Color(1.0, 0.92, 0.7), 1.6, false)
    _quad(dark, Vector3(-20, 31.97, -20), Vector3(20, 31.97, -20), Vector3(20, 31.97, 20), Vector3(-20, 31.97, 20), Vector3.DOWN)
    for x in [-12.0, 0.0, 12.0]:
        var xf: float = x
        _box(beam, Vector3(xf, 31.55, 0.0), Vector3(0.9, 0.8, 40.0), 0.0, true)
        _box(strip, Vector3(xf, 31.1, 0.0), Vector3(0.3, 0.08, 34.0), 0.0, true)
    for z in [-12.0, 12.0]:
        var zf: float = z
        _box(beam, Vector3(0.0, 31.7, zf), Vector3(40.0, 0.5, 0.8), 0.0, true)


# ---------------------------------------------------------------- D stairs

func _do_stairs() -> void:
    var starts: Array = _bld._f_start
    var ends: Array = _bld._f_end
    var ins: Array = _bld._f_in
    var dark := _mk(RAMP_DARK, 0.0, false)
    var yel := _mk(C_YELLOW, 0.0, false)
    var blk := _mk(C_BLACK, 0.0, false)
    var under := _mk(Color(0.12, 0.10, 0.05), 0.0, false)
    for k in 8:
        var s: Vector3 = starts[k]
        var e: Vector3 = ends[k]
        var n2: Vector2 = ins[k]
        var bs: Basis = _bld._flight_basis(s, e)
        var bx: Vector3 = bs.x
        var by: Vector3 = bs.y
        var bz: Vector3 = bs.z
        var length: float = s.distance_to(e)
        # tread stripes
        var i: int = 1
        while float(i) * 2.0 < length - 1.0:
            var c: Vector3 = s + bx * (2.0 * float(i)) + by * 0.03
            _quad(dark, c - bz * 1.95 - bx * 0.05, c + bz * 1.95 - bx * 0.05, c + bz * 1.95 + bx * 0.05, c - bz * 1.95 + bx * 0.05, by)
            i += 1
        # climb arrows
        var d: float = 3.0
        while d < length - 1.0:
            var c2: Vector3 = s + bx * d + by * 0.035
            _tri(dark, c2 + bx * 0.7, c2 - bx * 0.4 - bz * 0.8, c2 - bx * 0.4 + bz * 0.8, by)
            d += 6.0
        # dark edge strips
        for sg in [-1.0, 1.0]:
            var sgf: float = sg
            var eo: Vector3 = bz * (sgf * 1.9)
            _quad(blk, s + eo - bz * 0.08 + by * 0.03, e + eo - bz * 0.08 + by * 0.03, e + eo + bz * 0.08 + by * 0.03, s + eo + bz * 0.08 + by * 0.03, by)
        # yellow/black rail cap stripes on the inner rail face
        var nn := Vector3(n2.x, 0.0, n2.y)
        var fo: Vector3 = nn * 2.07
        var ra: Vector3 = s + fo
        var rb: Vector3 = e + fo
        _quad(yel, ra + by * 2.2, rb + by * 2.2, rb + by * 2.35, ra + by * 2.35, nn)
        _quad(blk, ra + by * 2.35, rb + by * 2.35, rb + by * 2.5, ra + by * 2.5, nn)
        # darker undersides on the open upper flights
        if k >= 4:
            var lo: Vector3 = by * 0.53
            _quad(under, s + bz * 2.0 - lo, e + bz * 2.0 - lo, e - bz * 2.0 - lo, s - bz * 2.0 - lo, -by)
    # landings: dark border on top, dark underside
    for k in range(1, 9):
        var sz: float = LSIZE[k]
        var cc: Vector2 = CORNERS[k % 4]
        var cx: float = cc.x * (HALF - sz * 0.5)
        var cz: float = cc.y * (HALF - sz * 0.5)
        var y: float = RISE * float(k)
        var h: float = sz * 0.5
        _floor_outline(blk, cx, cz, sz - 0.4, sz - 0.4, y + 0.03, 0.12)
        _quad(under, Vector3(cx - h, y - 0.53, cz - h), Vector3(cx + h, y - 0.53, cz - h), Vector3(cx + h, y - 0.53, cz + h), Vector3(cx - h, y - 0.53, cz + h), Vector3.DOWN)


# ---------------------------------------------------------------- E props, posters

func _face_trim(f: Array, ax: bool, c0: float, c1: float) -> void:
    var yel := _mk(C_YELLOW, 0.0, false)
    var blk := _mk(C_BLACK, 0.0, false)
    var ua: float = _pu(f, ax, c0)
    var ub: float = _pu(f, ax, c1)
    var u0: float = minf(ua, ub)
    var u1: float = maxf(ua, ub)
    _wall_rect(blk, f, u0, u1, 0.0, 0.4, 0.03)
    var u: float = u0
    while u < u1 - 0.9:
        _wall_para(yel, f, u, 0.5, 0.0, 0.4, 0.3, 0.04)
        u += 1.1
    _wall_rect(yel, f, u0, u1, 2.0, 2.07, 0.03)


func _do_props() -> void:
    for i in 4:
        var f: Array = _faces[i]
        var tr: Vector2 = TRIM[i]
        _face_trim(f, _face_x[i], tr.x, tr.y)
    # south face (x)
    _mir(_fs, true, -11.0, -3.5)
    _dumbbell_rack(_fs, _pu(_fs, true, -7.0))
    _poster(_fs, _pu(_fs, true, -1.5), 1.55, 2.3, 1.2, C_RED, "NO PAIN\nNO CHEESE", C_WHITE)
    _plate_stack(2.6, 0.0, 15.55)
    _barbell_rack(_fs, _pu(_fs, true, 6.5))
    _bench_press(_fs, _pu(_fs, true, 11.8))
    # east face (z)
    _mir(_fe, false, -9.0, -4.0)
    _dumbbell_rack(_fe, _pu(_fe, false, 11.0))
    _poster(_fe, _pu(_fe, false, 6.0), 1.55, 2.3, 1.2, C_BLACK, "CHEESE\nDAY", C_YELLOW)
    _barbell_rack(_fe, _pu(_fe, false, 1.0))
    _plate_stack(15.55, 0.0, -12.5)
    # north face (x), loot locker sits at x = 0
    _mir(_fn, true, 4.0, 9.0)
    _barbell_rack(_fn, _pu(_fn, true, -9.0))
    _dumbbell_rack(_fn, _pu(_fn, true, 12.0))
    _poster(_fn, _pu(_fn, true, -5.0), 1.55, 2.3, 1.2, C_YELLOW, "SWISS\nGAINS", C_BLACK)
    _poster(_fn, _pu(_fn, true, -13.0), 1.55, 2.3, 1.2, C_RED, "HOLEY\nGAINS", C_WHITE)
    # west face (z)
    _mir(_fw, false, -2.0, 3.0)
    _dumbbell_rack(_fw, _pu(_fw, false, -10.0))
    _poster(_fw, _pu(_fw, false, -5.0), 1.55, 2.3, 1.2, C_BLACK, "NEVER SKIP\nLEG DAY", C_YELLOW)
    _bench_press(_fw, _pu(_fw, false, 8.0))
    # summit corner plate stack
    _plate_stack(-19.0, RISE * 8.0, 14.0)


# ---------------------------------------------------------------- F signs

func _do_signs() -> void:
    var starts: Array = _bld._f_start
    var ends: Array = _bld._f_end
    for k in 8:
        var s: Vector3 = starts[k]
        var e: Vector3 = ends[k]
        var dir: Vector3 = Vector3(e.x - s.x, 0.0, e.z - s.z).normalized()
        var w: Array = _walls[k % 4]
        var p: Vector3 = s + dir * 5.0
        _poster(w, _u(w, p.x, p.z), RISE * float(k) + 5.0, 5.0, 1.5, C_BLACK, "LEVEL %d" % (k + 1), C_YELLOW)
    var s4: Vector3 = starts[4]
    var e4: Vector3 = ends[4]
    var d4: Vector3 = Vector3(e4.x - s4.x, 0.0, e4.z - s4.z).normalized()
    var p4: Vector3 = e4 - d4 * 6.0
    var w4: Array = _walls[0]
    _poster(w4, _u(w4, p4.x, p4.z), RISE * 4.0 + 5.0, 5.0, 1.5, C_RED, "PR RACK\nAHEAD", C_WHITE)
    var s7: Vector3 = starts[7]
    var e7: Vector3 = ends[7]
    var d7: Vector3 = Vector3(e7.x - s7.x, 0.0, e7.z - s7.z).normalized()
    var p7: Vector3 = e7 - d7 * 5.0
    var w7: Array = _walls[3]
    _poster(w7, _u(w7, p7.x, p7.z), RISE * 7.0 + 5.0, 5.0, 1.5, C_YELLOW, "SUMMIT", C_BLACK)


## CLOSED tape + sign as children of each door, so they vanish when it is bought.
func _door_tape() -> void:
    var ym := StandardMaterial3D.new()
    ym.albedo_color = C_YELLOW
    ym.roughness = 0.7
    for nm in ["DoorLap1", "DoorLap2", "DoorSummit"]:
        var door: Node3D = _bld.get_node_or_null(String(nm)) as Node3D
        if door == null:
            continue
        var sz := Vector3(4.0, 5.0, 0.4)
        var szv: Variant = door.get("size")
        if szv is Vector3:
            sz = szv
        var title: String = "GATE"
        var tv: Variant = door.get("display_name")
        if tv != null:
            title = String(tv).to_upper()
        var wide_x: bool = sz.x > sz.z
        var holder := Node3D.new()
        holder.name = "TapeDecor"
        door.add_child(holder)
        for ty in [0.9, 1.7]:
            var mi := MeshInstance3D.new()
            var bm := BoxMesh.new()
            if wide_x:
                bm.size = Vector3(sz.x, 0.18, sz.z + 0.08)
            else:
                bm.size = Vector3(sz.x + 0.08, 0.18, sz.z)
            mi.mesh = bm
            mi.material_override = ym
            mi.position = Vector3(0.0, float(ty), 0.0)
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            holder.add_child(mi)
        var half_d: float = (sz.z if wide_x else sz.x) * 0.5 + 0.06
        for sd in [1.0, -1.0]:
            var sdf: float = sd
            var l := Label3D.new()
            l.text = title + "\nCLOSED"
            l.font_size = 64
            l.pixel_size = 0.005
            l.modulate = C_YELLOW
            l.outline_modulate = C_BLACK
            l.outline_size = 8
            l.shaded = false
            l.double_sided = false
            if wide_x:
                l.position = Vector3(0.0, 2.4, half_d * sdf)
                l.rotation.y = 0.0 if sdf > 0.0 else PI
            else:
                l.position = Vector3(half_d * sdf, 2.4, 0.0)
                l.rotation.y = PI * 0.5 * sdf
            holder.add_child(l)


# ---------------------------------------------------------------- G blood

func _do_blood() -> void:
    var b1 := _mk(C_BLOOD, 0.0, false)
    var b2 := _mk(C_BLOOD2, 0.0, false)
    for i in 14:
        _splat(_rng, b1, b2, _rng.randf_range(-13.0, 13.0), _rng.randf_range(-13.0, 13.0), 0.03)
    var starts: Array = _bld._f_start
    var ends: Array = _bld._f_end
    for k in 8:
        var s: Vector3 = starts[k]
        var e: Vector3 = ends[k]
        var bz: Vector3 = _bld._flight_basis(s, e).z
        for j in 2:
            var p: Vector3 = s.lerp(e, _rng.randf_range(0.15, 0.85)) + bz * _rng.randf_range(-1.2, 1.2)
            _splat(_rng, b1, b2, p.x, p.z, p.y + 0.06)
    # heavier near the gates
    for g in [Vector2(0, 0.03), Vector2(0, 0.12), Vector2(3, 0.85), Vector2(3, 0.89), Vector2(6, 0.85), Vector2(6, 0.89)]:
        var gv: Vector2 = g
        var gk: int = int(gv.x)
        var gs: Vector3 = starts[gk]
        var ge: Vector3 = ends[gk]
        var gp: Vector3 = gs.lerp(ge, gv.y)
        _splat(_rng, b1, b2, gp.x, gp.z, gp.y + 0.06)
    for k in range(1, 9):
        var sz: float = LSIZE[k]
        var cc: Vector2 = CORNERS[k % 4]
        _splat(_rng, b1, b2, cc.x * (HALF - sz * 0.5) + _rng.randf_range(-1.0, 1.0), cc.y * (HALF - sz * 0.5) + _rng.randf_range(-1.0, 1.0), RISE * float(k) + 0.02)
    for w in _walls:
        var wf: Array = w
        for i in 10:
            _drip(_rng, b1, wf, 18.0, 6.0, 30.0)
    for f in _faces:
        var ff: Array = f
        for i in 4:
            _drip(_rng, b1, ff, 12.0, 2.0, 2.3)


# END OF FILE
