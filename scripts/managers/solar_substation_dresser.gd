extends "res://scripts/managers/solar_props.gd"
## Solar Substation visual dresser (cosmetic). Ramp and canopy decor reads the
## real node transforms at runtime, so it follows the geometry as it is.
## No navmesh on this map, so there are no top-face restrictions.

const WALL: float = 30.0
const WALL_H: float = 15.0
const CONCRETE := Color(0.36, 0.35, 0.34)
const SEAM := Color(0.10, 0.10, 0.11)
const PV_BLUE := Color(0.05, 0.15, 0.40)
const PV_LINE := Color(0.50, 0.62, 0.85)
const RAMP_DARK := Color(0.16, 0.16, 0.18)

var _rng := RandomNumberGenerator.new()
var _geo: Node
var _wn: Array = []
var _ws: Array = []
var _we: Array = []
var _ww: Array = []
var _wf: Array = []


func _ready() -> void:
    _rng.seed = 7777
    _geo = get_parent().get_node_or_null("Geometry")
    _init_props()
    _setup_outdoor()
    _make_frames()
    _do_floor()
    _do_walls()
    _do_pv()
    _do_banks()
    _do_canopy()
    _do_catwalk()
    _do_ramp()
    _do_stations()
    _do_props()
    _do_signs()
    _do_blood()
    _flush()


func _make_frames() -> void:
    _wn = _fr(Vector3(0.0, 0.0, -WALL), Vector3(0.0, 0.0, 1.0))
    _ws = _fr(Vector3(0.0, 0.0, WALL), Vector3(0.0, 0.0, -1.0))
    _we = _fr(Vector3(WALL, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
    _ww = _fr(Vector3(-WALL, 0.0, 0.0), Vector3(1.0, 0.0, 0.0))
    _wf = [_wn, _ws, _we, _ww]


# ---------------------------------------------------------------- C sky, sun, fog

func _setup_outdoor() -> void:
    var p := get_parent()
    var we := p.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we != null and we.environment != null:
        var env: Environment = we.environment
        env.ssao_enabled = false
        env.glow_enabled = false
        env.ambient_light_energy = 0.55
        env.fog_enabled = true
        env.fog_light_color = Color(0.80, 0.60, 0.46)
        env.fog_density = 0.004
        env.fog_sky_affect = 0.35
        if env.sky != null:
            var sm := env.sky.sky_material as ProceduralSkyMaterial
            if sm != null:
                sm.sky_top_color = Color(0.16, 0.24, 0.44)
                sm.sky_horizon_color = Color(0.95, 0.62, 0.40)
                sm.ground_horizon_color = Color(0.70, 0.50, 0.38)
                sm.ground_bottom_color = Color(0.10, 0.09, 0.09)
    var sun := p.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
    if sun != null:
        sun.light_color = Color(1.0, 0.80, 0.58)
        sun.light_energy = 1.1
        sun.directional_shadow_max_distance = 90.0


# ---------------------------------------------------------------- A floor

func _crack(k: String, x: float, z: float) -> void:
    var p := Vector2(x, z)
    var ang: float = _rng.randf_range(0.0, TAU)
    for i in 5:
        var q := p + Vector2(cos(ang), sin(ang)) * _rng.randf_range(0.8, 1.8)
        var d := (q - p).normalized()
        var nr := Vector2(-d.y, d.x) * 0.03
        _quad(k, Vector3(p.x - nr.x, 0.05, p.y - nr.y), Vector3(q.x - nr.x, 0.05, q.y - nr.y), Vector3(q.x + nr.x, 0.05, q.y + nr.y), Vector3(p.x + nr.x, 0.05, p.y + nr.y), Vector3.UP)
        p = q
        ang += _rng.randf_range(-0.7, 0.7)


func _do_floor() -> void:
    var joint := _mk(Color(0.16, 0.16, 0.18), 0.0, false)
    var patch := _mk(Color(0.37, 0.37, 0.39), 0.0, false)
    var stain := _mk(Color(0.20, 0.20, 0.22), 0.0, false)
    var crack := _mk(Color(0.12, 0.12, 0.14), 0.0, false)
    var yel := _mk(C_YELLOW, 0.0, false)
    for i in 9:
        var c: float = -24.0 + 6.0 * float(i)
        _floor_rect(joint, c, 0.0, 0.07, 60.0, 0.02)
        _floor_rect(joint, 0.0, c, 60.0, 0.07, 0.02)
    for i in 10:
        _floor_disc(patch, _rng.randf_range(-26.0, 26.0), _rng.randf_range(-26.0, 26.0), _rng.randf_range(1.5, 3.5), 0.03, _rng.randf_range(0.8, 1.4), 9)
    for i in 12:
        _floor_disc(stain, _rng.randf_range(-26.0, 26.0), _rng.randf_range(-26.0, 26.0), _rng.randf_range(0.6, 2.0), 0.04, _rng.randf_range(0.8, 1.5), 9)
    for i in 8:
        _crack(crack, _rng.randf_range(-24.0, 24.0), _rng.randf_range(-24.0, 24.0))
    _floor_outline(yel, 0.0, 0.0, 52.0, 52.0, 0.06, 0.14)


# ---------------------------------------------------------------- B walls

func _do_walls() -> void:
    var conc := _mk(CONCRETE, 0.0, false, 0.0, 0.9)
    var seam := _mk(SEAM, 0.0, false)
    var blk := _mk(C_BLACK, 0.0, false)
    var yel := _mk(C_YELLOW, 0.0, false)
    var steel := _mk(C_STEEL, 0.0, true, 0.3, 0.5)
    var pipe := _mk(Color(0.55, 0.45, 0.20), 0.0, true, 0.3, 0.5)
    var porc := _mk(C_PORC, 0.0, true, 0.0, 0.5)
    for w in _wf:
        var f: Array = w
        var nrm: Vector3 = f[1]
        var along_x: bool = absf(nrm.z) > 0.5
        _wall_rect(conc, f, -WALL, WALL, 0.0, WALL_H, 0.02)
        for i in 11:
            var us: float = -30.0 + 6.0 * float(i)
            _wall_rect(seam, f, us - 0.04, us + 0.04, 0.0, WALL_H, 0.03)
        _wall_rect(seam, f, -WALL, WALL, 7.5, 7.58, 0.03)
        _wall_rect(blk, f, -WALL, WALL, 0.0, 0.6, 0.035)
        var hx: float = -WALL + 0.2
        while hx < WALL - 1.2:
            _wall_para(yel, f, hx, 0.55, 0.0, 0.6, 0.4, 0.045)
            hx += 1.2
        _wall_rect(yel, f, -WALL, WALL, 3.0, 3.08, 0.035)
        var pc: Vector3 = _wp(f, 0.0, 12.5, 0.25)
        if along_x:
            _cyl(pipe, pc, 0.18, 58.0, 0, 8)
        else:
            _cyl(pipe, pc, 0.18, 58.0, 2, 8)
        for i in 10:
            var ub: float = -27.0 + 6.0 * float(i)
            var bc: Vector3 = _wp(f, ub, 12.5, 0.12)
            if along_x:
                _box(steel, bc, Vector3(0.15, 0.4, 0.25))
            else:
                _box(steel, bc, Vector3(0.25, 0.4, 0.15))
        for i in 9:
            var ui: float = -24.0 + 6.0 * float(i)
            var pb: Vector3 = _wp(f, ui, WALL_H, -1.0)
            _cyl(porc, pb + Vector3(0.0, 0.45, 0.0), 0.06, 0.9, 1, 5)
            _cyl(porc, pb + Vector3(0.0, 0.35, 0.0), 0.17, 0.05, 1, 6)
            _cyl(porc, pb + Vector3(0.0, 0.62, 0.0), 0.15, 0.05, 1, 6)
        var wc: Vector3 = _wp(f, 0.0, WALL_H + 0.85, -1.0)
        if along_x:
            _box(blk, wc, Vector3(48.0, 0.03, 0.03))
        else:
            _box(blk, wc, Vector3(0.03, 0.03, 48.0))


func _pv_wall(f: Array, u: float, y: float, w: float, h: float) -> void:
    var frame := _mk(C_STEEL, 0.0, false, 0.3, 0.5)
    var cell := _mk(PV_BLUE, 0.0, false, 0.3, 0.25)
    var line := _mk(PV_LINE, 0.0, false)
    _wall_rect(frame, f, u - w * 0.5 - 0.1, u + w * 0.5 + 0.1, y - 0.1, y + h + 0.1, 0.04)
    _wall_rect(cell, f, u - w * 0.5, u + w * 0.5, y, y + h, 0.05)
    for i in range(1, int(w / 0.5)):
        var uu: float = u - w * 0.5 + 0.5 * float(i)
        _wall_rect(line, f, uu - 0.015, uu + 0.015, y, y + h, 0.055)
    for j in range(1, int(h / 0.5)):
        var yy: float = y + 0.5 * float(j)
        _wall_rect(line, f, u - w * 0.5, u + w * 0.5, yy - 0.015, yy + 0.015, 0.055)


func _do_pv() -> void:
    for i in 3:
        var xa: float = -24.0 + 6.0 * float(i)
        _pv_wall(_ws, _u(_ws, xa, 30.0), 7.0, 5.4, 3.6)
        _pv_wall(_ws, _u(_ws, -xa, 30.0), 7.0, 5.4, 3.6)
    for i in 5:
        var zc: float = -14.0 + 7.0 * float(i)
        _pv_wall(_we, _u(_we, 30.0, zc), 7.0, 6.0, 3.6)
        _pv_wall(_ww, _u(_ww, -30.0, zc), 7.0, 6.0, 3.6)


# ---------------------------------------------------------------- D batteries, canopy

func _do_banks() -> void:
    var vent := _mk(Color(0.04, 0.04, 0.05), 0.0, false)
    var slat := _mk(Color(0.24, 0.25, 0.28), 0.0, false, 0.3, 0.5)
    var led_g := _mk(C_GREEN, 1.6, false)
    var led_r := _mk(C_RED, 1.6, false)
    var yel := _mk(C_YELLOW, 0.0, false)
    var blk := _mk(C_BLACK, 0.0, false)
    var plate := _mk(Color(0.30, 0.31, 0.35), 0.0, false, 0.3, 0.5)
    var cabk := _mk(Color(0.03, 0.03, 0.03), 0.0, false)
    for b in 2:
        var cx: float = -12.0 if b == 0 else 12.0
        var defs: Array = [
            [Vector3(cx, 0.0, 6.0), Vector3(0.0, 0.0, 1.0), 8.0],
            [Vector3(cx, 0.0, -6.0), Vector3(0.0, 0.0, -1.0), 8.0],
            [Vector3(cx + 4.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), 12.0],
            [Vector3(cx - 4.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0), 12.0],
        ]
        for di in 4:
            var d: Array = defs[di]
            var o: Vector3 = d[0]
            var nm: Vector3 = d[1]
            var wd: float = d[2]
            var f: Array = _fr(o, nm)
            var hw: float = wd * 0.5 - 0.5
            _wall_rect(blk, f, -wd * 0.5, wd * 0.5, 0.0, 0.3, 0.03)
            var hu: float = -wd * 0.5 + 0.1
            while hu < wd * 0.5 - 0.9:
                _wall_para(yel, f, hu, 0.45, 0.0, 0.3, 0.3, 0.04)
                hu += 1.0
            _wall_rect(vent, f, -hw, 0.4, 0.8, 2.2, 0.035)
            for j in 7:
                var sy: float = 0.9 + 0.2 * float(j)
                _wall_rect(slat, f, -hw, 0.4, sy, sy + 0.04, 0.045)
            _wall_rect(led_g, f, -hw, hw - 0.6, 2.5, 2.58, 0.035)
            _wall_rect(led_r, f, hw - 0.5, hw, 2.5, 2.58, 0.035)
            var outer: bool = (cx < 0.0 and di == 3) or (cx > 0.0 and di == 2)
            var pu: float = hw - 1.4
            if outer:
                _poster(f, pu, 1.5, 2.4, 1.2, C_BLACK, "BANK %d" % (b + 1), C_GREEN)
            else:
                _poster(f, pu, 1.5, 2.4, 1.2, C_YELLOW, "DANGER\n48V DC", C_BLACK)
        _floor_rect(plate, cx, 0.0, 7.4, 11.4, 3.02)
        for fz in [-3.0, 3.0]:
            var fzf: float = fz
            _floor_disc(slat, cx, fzf, 1.15, 3.03, 1.0, 12)
            _floor_disc(vent, cx, fzf, 0.95, 3.04, 1.0, 12)
    _floor_rect(yel, 0.0, 2.0, 16.0, 0.5, 0.07)
    _floor_rect(cabk, 0.0, 2.0, 16.0, 0.14, 0.075)


func _do_canopy() -> void:
    var cn: Node3D = null
    if _geo != null:
        cn = _geo.get_node_or_null("Obstacles/Solar_Canopy") as Node3D
    if cn == null:
        return
    var tr: Transform3D = cn.global_transform
    var bx: Vector3 = tr.basis.x.normalized()
    var by: Vector3 = tr.basis.y.normalized()
    var bz: Vector3 = tr.basis.z.normalized()
    if by.y < 0.0:
        return
    var frame := _mk(C_STEEL, 0.0, false, 0.4, 0.4)
    var line := _mk(PV_LINE, 0.0, false)
    var under := _mk(Color(0.08, 0.08, 0.10), 0.0, false)
    var leg := _mk(C_STEEL, 0.0, true, 0.4, 0.5)
    var c: Vector3 = tr.origin + by * 0.12
    _surf(frame, c, bx, bz, by, -5.0, 5.0, -5.0, -4.8)
    _surf(frame, c, bx, bz, by, -5.0, 5.0, 4.8, 5.0)
    _surf(frame, c, bx, bz, by, -5.0, -4.8, -4.8, 4.8)
    _surf(frame, c, bx, bz, by, 4.8, 5.0, -4.8, 4.8)
    for i in range(1, 8):
        var g: float = -5.0 + 1.25 * float(i)
        _surf(line, c, bx, bz, by, g - 0.02, g + 0.02, -4.8, 4.8)
        _surf(line, c, bx, bz, by, -4.8, 4.8, g - 0.02, g + 0.02)
    _surf(under, tr.origin - by * 0.12, bx, bz, -by, -5.0, 5.0, -5.0, 5.0)
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var sxf: float = sx
            var szf: float = sz
            var q: Vector3 = tr.origin - by * 0.1 + bx * (sxf * 4.5) + bz * (szf * 4.5)
            if q.y > 0.3:
                _cyl(leg, Vector3(q.x, q.y * 0.5, q.z), 0.12, q.y, 1, 6)
                _box(leg, Vector3(q.x, 0.05, q.z), Vector3(0.5, 0.1, 0.5))


# ---------------------------------------------------------------- F catwalk, ramp

func _do_catwalk() -> void:
    var grate := _mk(Color(0.13, 0.13, 0.15), 0.0, false, 0.4, 0.5)
    var gl := _mk(Color(0.30, 0.31, 0.34), 0.0, false, 0.4, 0.5)
    var yel := _mk(C_YELLOW, 0.0, false)
    var blk := _mk(C_BLACK, 0.0, false)
    var steel := _mk(C_STEEL, 0.0, true, 0.4, 0.5)
    var under := _mk(Color(0.08, 0.08, 0.09), 0.0, false)
    var strip := _mk(Color(1.0, 0.92, 0.7), 1.6, false)
    var ff: Array = _fr(Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, 1.0))
    _floor_rect(grate, 0.0, -25.0, 60.0, 10.0, 6.02)
    for i in 30:
        _floor_rect(gl, -29.0 + 2.0 * float(i), -25.0, 0.06, 10.0, 6.03)
    for seg in [-1.0, 1.0]:
        var sg: float = seg
        var u0: float = 4.6
        var u1: float = 30.0
        if sg < 0.0:
            u0 = -30.0
            u1 = -4.6
        var cxm: float = sg * 17.3
        _floor_rect(yel, cxm, -20.35, 25.4, 0.5, 6.04)
        for i in 25:
            var xa: float = 4.6 + float(i)
            _quad(blk, Vector3(sg * xa, 6.045, -20.6), Vector3(sg * (xa + 0.4), 6.045, -20.6), Vector3(sg * (xa + 0.8), 6.045, -20.1), Vector3(sg * (xa + 0.4), 6.045, -20.1), Vector3.UP)
        _wall_rect(blk, ff, u0, u1, 5.0, 6.0, 0.02)
        var fu: float = u0 + 0.2
        while fu < u1 - 1.0:
            _wall_para(yel, ff, fu, 0.5, 5.02, 5.98, 0.35, 0.03)
            fu += 1.0
        _box(yel, Vector3(cxm, 7.05, -20.4), Vector3(25.4, 0.06, 0.06))
        _box(yel, Vector3(cxm, 6.55, -20.4), Vector3(25.4, 0.05, 0.05))
        var px: float = 4.7
        while px < 29.5:
            _box(yel, Vector3(sg * px, 6.55, -20.4), Vector3(0.08, 1.1, 0.08))
            px += 3.0
        _box(yel, Vector3(sg * 29.8, 6.55, -20.4), Vector3(0.08, 1.1, 0.08))
    _quad(under, Vector3(-30, 4.98, -30), Vector3(30, 4.98, -30), Vector3(30, 4.98, -20), Vector3(-30, 4.98, -20), Vector3.DOWN)
    for pxx in [-27.0, -19.0, -11.0, 11.0, 19.0, 27.0]:
        var pf: float = pxx
        _box(steel, Vector3(pf, 2.5, -20.7), Vector3(0.5, 5.0, 0.5))
        _box(yel, Vector3(pf, 0.3, -20.7), Vector3(0.54, 0.6, 0.54))
    _box(strip, Vector3(0.0, 4.9, -23.0), Vector3(56.0, 0.06, 0.25))
    _box(strip, Vector3(0.0, 4.9, -27.0), Vector3(56.0, 0.06, 0.25))


func _do_ramp() -> void:
    var rp: Node3D = null
    if _geo != null:
        rp = _geo.get_node_or_null("UpperLevel/Ramp") as Node3D
    if rp == null:
        return
    var tr: Transform3D = rp.global_transform
    var bx: Vector3 = tr.basis.x.normalized()
    var by: Vector3 = tr.basis.y.normalized()
    var bz: Vector3 = tr.basis.z.normalized()
    if by.y < 0.0:
        return
    var up: Vector3 = bz
    if up.y < 0.0:
        up = -bz
    var c0: Vector3 = tr.origin + by * 0.5
    var dark := _mk(RAMP_DARK, 0.0, false)
    var yel := _mk(C_YELLOW, 0.0, false)
    var t0: float = maxf(-9.0, (0.15 - c0.y) / up.y)
    var t1: float = 9.0
    var lift: Vector3 = by * 0.03
    var t: float = t0 + 0.6
    while t < t1 - 0.3:
        _surf(dark, c0 + lift, bx, up, by, -3.9, 3.9, t - 0.05, t + 0.05)
        t += 1.5
    t = t0 + 1.5
    while t < t1 - 1.0:
        var ca: Vector3 = c0 + by * 0.035 + up * t
        _tri(yel, ca + up * 0.7, ca - up * 0.4 - bx * 0.8, ca - up * 0.4 + bx * 0.8, by)
        t += 4.5
    _surf(yel, c0 + lift, bx, up, by, 3.7, 3.9, t0, t1)
    _surf(yel, c0 + lift, bx, up, by, -3.9, -3.7, t0, t1)
    for sg in [-1.0, 1.0]:
        var sgf: float = sg
        var prev: Vector3 = Vector3.ZERO
        var has_prev: bool = false
        var tt: float = t0 + 0.3
        while tt <= t1:
            var p: Vector3 = c0 + bx * (sgf * 4.05) + up * tt
            _box(yel, p + Vector3(0.0, 0.55, 0.0), Vector3(0.08, 1.1, 0.08))
            if has_prev:
                _ribbon(yel, prev + Vector3(0.0, 1.05, 0.0), p + Vector3(0.0, 1.05, 0.0), 0.08, bx)
                _ribbon(yel, prev + Vector3(0.0, 0.55, 0.0), p + Vector3(0.0, 0.55, 0.0), 0.08, bx)
            prev = p
            has_prev = true
            tt += 3.0


# ---------------------------------------------------------------- F station pads

func _do_stations() -> void:
    var pad := _mk(Color(0.07, 0.07, 0.08), 0.0, false)
    var glow := _mk(C_YELLOW, 1.0, false)
    var wglow := _mk(C_BLUE, 1.0, false)
    for z in [-15.0, -5.0, 5.0]:
        var zf: float = z
        _pad(pad, glow, -28.0, zf, 2.6, 2.6, 0.0)
        _pad(pad, glow, 28.0, zf, 2.6, 2.6, 0.0)
    _ring(glow, pad, 0.0, 0.08, 15.0, 2.2)
    _ring(wglow, pad, -28.0, 0.08, 28.0, 1.3)
    _ring(wglow, pad, 28.0, 0.08, 28.0, 1.3)
    _pad(pad, glow, -5.0, 28.2, 3.2, 1.8, 0.0)
    _pad(pad, glow, 5.0, 28.2, 3.2, 1.8, 0.0)
    _pad(pad, glow, -15.0, -28.2, 3.2, 1.8, 6.0)
    _pad(pad, glow, 15.0, -28.2, 3.2, 1.8, 6.0)
    _pad(pad, glow, 0.0, -26.8, 3.0, 1.8, 6.0)
    _floor_label("PR RACK", 0.0, 0.12, 11.5, 0.02, C_YELLOW)


# ---------------------------------------------------------------- E props

func _do_props() -> void:
    # west wall (front +x)
    _transformer(_ww, _u(_ww, -30.0, -25.0))
    _cabinet(_ww, _u(_ww, -30.0, -22.2))
    _floodlight(_ww, _u(_ww, -30.0, -18.5))
    _cabinet(_ww, _u(_ww, -30.0, 11.5))
    _cabinet(_ww, _u(_ww, -30.0, 13.0))
    _floodlight(_ww, _u(_ww, -30.0, 16.5))
    _barrels(_ww, _u(_ww, -30.0, 20.0))
    _crates(_ww, _u(_ww, -30.0, 23.5))
    # east wall (front -x)
    _transformer(_we, _u(_we, 30.0, -25.0))
    _cabinet(_we, _u(_we, 30.0, -22.2))
    _floodlight(_we, _u(_we, 30.0, -18.5))
    _reel(_we, _u(_we, 30.0, 12.0))
    _cabinet(_we, _u(_we, 30.0, 14.2))
    _floodlight(_we, _u(_we, 30.0, 16.5))
    _barrels(_we, _u(_we, 30.0, 20.0), 0.0, C_RED)
    _crates(_we, _u(_we, 30.0, 23.5))
    # south wall (front -z), wall buys sit at x = +-5
    _reel(_ws, _u(_ws, -22.0, 30.0))
    _crates(_ws, _u(_ws, -17.5, 30.0))
    _barrels(_ws, _u(_ws, -13.0, 30.0))
    _cabinet(_ws, _u(_ws, -9.8, 30.0))
    _cabinet(_ws, _u(_ws, 9.8, 30.0))
    _barrels(_ws, _u(_ws, 13.5, 30.0), 0.0, C_RED)
    _crates(_ws, _u(_ws, 18.0, 30.0))
    _reel(_ws, _u(_ws, 22.0, 30.0))
    # north wall under the catwalk (front +z)
    _transformer(_wn, _u(_wn, -20.0, -30.0))
    _transformer(_wn, _u(_wn, 20.0, -30.0))
    _cabinet(_wn, _u(_wn, -16.5, -30.0))
    _cabinet(_wn, _u(_wn, 16.5, -30.0))
    _barrels(_wn, _u(_wn, -10.5, -30.0))
    _crates(_wn, _u(_wn, 10.5, -30.0))
    # north wall on the catwalk deck
    _cabinet(_wn, _u(_wn, -24.0, -30.0), 6.0)
    _cabinet(_wn, _u(_wn, -22.6, -30.0), 6.0)
    _cabinet(_wn, _u(_wn, 22.6, -30.0), 6.0)
    _cabinet(_wn, _u(_wn, 24.0, -30.0), 6.0)


# ---------------------------------------------------------------- F wall signs

func _do_signs() -> void:
    _poster(_ws, _u(_ws, 0.0, 30.0), 9.5, 11.0, 2.4, C_BLACK, "SOLAR SUBSTATION", C_YELLOW)
    _poster(_ws, _u(_ws, -15.0, 30.0), 3.5, 3.2, 1.6, C_YELLOW, "DANGER\nHIGH VOLTAGE", C_BLACK)
    _poster(_ws, _u(_ws, 15.0, 30.0), 3.5, 3.2, 1.6, C_YELLOW, "DANGER\nHIGH VOLTAGE", C_BLACK)
    _poster(_wn, _u(_wn, 0.0, -30.0), 10.5, 9.0, 2.0, C_BLACK, "UPPER LEVEL", C_YELLOW)
    _poster(_wn, _u(_wn, -24.0, -30.0), 9.0, 3.2, 1.4, C_YELLOW, "DANGER\nHIGH VOLTAGE", C_BLACK)
    _poster(_wn, _u(_wn, 24.0, -30.0), 9.0, 3.2, 1.4, C_YELLOW, "DANGER\nHIGH VOLTAGE", C_BLACK)
    _poster(_we, _u(_we, 30.0, -24.0), 4.2, 3.0, 1.1, C_YELLOW, "DANGER\nHIGH VOLTAGE", C_BLACK)
    _poster(_ww, _u(_ww, -30.0, -24.0), 4.2, 3.0, 1.1, C_YELLOW, "DANGER\nHIGH VOLTAGE", C_BLACK)
    _poster(_we, _u(_we, 30.0, 0.0), 5.0, 4.0, 1.6, C_RED, "NO PAIN\nNO POWER", C_WHITE)
    _poster(_ww, _u(_ww, -30.0, 0.0), 5.0, 4.0, 1.6, C_RED, "NO PAIN\nNO POWER", C_WHITE)


# ---------------------------------------------------------------- G blood

func _do_blood() -> void:
    var b1 := _mk(C_BLOOD, 0.0, false)
    var b2 := _mk(C_BLOOD2, 0.0, false)
    var n: int = 0
    while n < 18:
        var x: float = _rng.randf_range(-26.0, 26.0)
        var z: float = _rng.randf_range(-18.0, 26.0)
        if absf(absf(x) - 12.0) < 5.5 and absf(z) < 7.5:
            continue
        _splat(_rng, b1, b2, x, z, 0.08)
        n += 1
    for i in 5:
        _splat(_rng, b1, b2, _rng.randf_range(-26.0, 26.0), _rng.randf_range(-29.0, -21.0), 6.05)
    for w in _wf:
        var wf: Array = w
        for i in 8:
            _drip(_rng, b1, wf, 29.0, 1.0, 5.0)


# END OF FILE
