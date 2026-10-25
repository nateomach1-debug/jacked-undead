extends "res://scripts/managers/map_dress_base.gd"
## Challenge map visual dresser (cosmetic). No navmesh on this map.
## Also repairs the duplicated light fixtures at runtime (14 shadowed lights -> 8 plain).

const LIGHT_ENERGY: float = 3.2
const RED := Color(0.85, 0.22, 0.15)
const GOLD := Color(1.0, 0.82, 0.2)

var _rng := RandomNumberGenerator.new()
var _wn: Array = []
var _ws: Array = []
var _we: Array = []
var _ww: Array = []
var _wf: Array = []


func _ready() -> void:
    _rng.seed = 5150
    _init_props()
    _setup_gym_env()
    _fix_lights()
    _make_frames()
    _do_floor()
    _do_walls()
    _do_columns()
    _do_ceiling()
    _do_stations()
    _do_props()
    _do_signs()
    _do_blood()
    _flush()


func _make_frames() -> void:
    _wn = _fr(Vector3(0.0, 0.0, -20.0), Vector3(0.0, 0.0, 1.0))
    _ws = _fr(Vector3(0.0, 0.0, 20.0), Vector3(0.0, 0.0, -1.0))
    _we = _fr(Vector3(20.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0))
    _ww = _fr(Vector3(-20.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0))
    _wf = [_wn, _ws, _we, _ww]



# ---------------------------------------------------------------- C/H lights, env

func _setup_gym_env() -> void:
    var we := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we == null or we.environment == null:
        return
    var env: Environment = we.environment
    env.ssao_enabled = false
    env.glow_enabled = false
    env.fog_enabled = true
    env.fog_light_color = Color(0.40, 0.41, 0.46)
    env.fog_density = 0.003


func _fix_lights() -> void:
    var holder := get_parent().get_node_or_null("FluorescentLights")
    if holder == null:
        return
    var seen: Dictionary = {}
    for c in holder.get_children():
        var fx := c as Node3D
        if fx == null:
            continue
        var key: String = "%d_%d" % [roundi(fx.position.x), roundi(fx.position.z)]
        if seen.has(key):
            fx.queue_free()
            continue
        seen[key] = true
        for l in fx.get_children():
            if l is OmniLight3D:
                var ol: OmniLight3D = l
                ol.shadow_enabled = false
                ol.light_energy = LIGHT_ENERGY


# ---------------------------------------------------------------- A floor

func _do_floor() -> void:
    var grid := _mk(Color(0.09, 0.09, 0.10), 0.0, false)
    var wood := _mk(Color(0.45, 0.30, 0.15), 0.0, false, 0.0, 0.7)
    var rub := _mk(Color(0.05, 0.05, 0.06), 0.0, false)
    var yel := _mk(C_YELLOW, 0.0, false)
    var red := _mk(RED, 0.0, false)
    var blk := _mk(C_BLACK, 0.0, false)
    var gold := _mk(GOLD, 0.8, false)
    for i in 7:
        var c: float = -15.0 + 5.0 * float(i)
        _floor_rect(grid, c, 0.0, 0.06, 40.0, 0.02)
        _floor_rect(grid, 0.0, c, 40.0, 0.06, 0.02)
    for px in [-5.5, 5.5]:
        var pxf: float = px
        _floor_rect(wood, pxf, 3.0, 2.8, 2.8, 0.03)
        _floor_rect(rub, pxf, 3.0, 1.8, 1.8, 0.04)
        _floor_outline(yel, pxf, 3.0, 1.8, 1.8, 0.05, 0.06)
    _ring(red, blk, 0.0, 0.03, 0.0, 3.2)
    _floor_outline(yel, 0.0, 0.0, 36.4, 36.4, 0.06, 0.12)
    for i in 4:
        var z: float = 8.0 + 2.5 * float(i)
        _tri(gold, Vector3(0.0, 0.06, z + 0.9), Vector3(-0.9, 0.06, z - 0.6), Vector3(0.9, 0.06, z - 0.6), Vector3.UP)
    _floor_label("CHALLENGE", 0.0, 0.12, -4.6, 0.02, RED)


# ---------------------------------------------------------------- B walls

func _do_walls() -> void:
    var blk := _mk(C_BLACK, 0.0, false)
    for w in _wf:
        var f: Array = w
        _dress_wall(f, 20.0, 0.0, 6.15, RED)
    # frames around the red panels (north / south)
    for fx in [_wn, _ws]:
        var f1: Array = fx
        _wall_rect(blk, f1, -6.15, 6.15, 4.05, 4.2, 0.14)
        _wall_rect(blk, f1, -6.15, 6.15, 1.4, 1.55, 0.14)
        _wall_rect(blk, f1, -6.15, -6.0, 1.4, 4.2, 0.14)
        _wall_rect(blk, f1, 6.0, 6.15, 1.4, 4.2, 0.14)
    # frames and dividers on the mirrors (east / west)
    for fy in [_we, _ww]:
        var f2: Array = fy
        _wall_rect(blk, f2, -6.15, 6.15, 3.45, 3.6, 0.14)
        _wall_rect(blk, f2, -6.15, 6.15, 0.8, 0.95, 0.14)
        _wall_rect(blk, f2, -6.15, -6.0, 0.8, 3.6, 0.14)
        _wall_rect(blk, f2, 6.0, 6.15, 0.8, 3.6, 0.14)
        for mu in [-2.0, 2.0]:
            var muf: float = mu
            _wall_rect(blk, f2, muf - 0.04, muf + 0.04, 0.95, 3.45, 0.14)


# ---------------------------------------------------------------- D columns

func _do_columns() -> void:
    var blk := _mk(C_BLACK, 0.0, false)
    var yel := _mk(C_YELLOW, 0.0, false)
    var red := _mk(RED, 0.0, false)
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var sxf: float = sx
            var szf: float = sz
            var cx: float = 19.0 * sxf
            var cz: float = 19.0 * szf
            var faces: Array = [
                _fr(Vector3(cx - sxf * 0.75, 0.0, cz), Vector3(-sxf, 0.0, 0.0)),
                _fr(Vector3(cx, 0.0, cz - szf * 0.75), Vector3(0.0, 0.0, -szf)),
            ]
            var tag: String = "%s%d" % ["A" if szf < 0.0 else "B", 1 if sxf < 0.0 else 2]
            for fa in faces:
                var f: Array = fa
                _wall_rect(blk, f, -0.75, 0.75, 0.0, 0.6, 0.03)
                _wall_para(yel, f, -0.7, 0.45, 0.0, 0.6, 0.3, 0.04)
                _wall_para(yel, f, 0.0, 0.45, 0.0, 0.6, 0.3, 0.04)
                _wall_rect(red, f, -0.75, 0.75, 1.3, 1.4, 0.03)
                _wall_rect(blk, f, -0.75, 0.75, 5.5, 6.1, 0.03)
                _wall_rect(yel, f, -0.75, 0.75, 5.42, 5.5, 0.03)
                _poster(f, 0.0, 2.3, 0.9, 0.55, C_YELLOW, tag, C_BLACK)


# ---------------------------------------------------------------- C ceiling

func _do_ceiling() -> void:
    var line := _mk(Color(0.09, 0.09, 0.11), 0.0, false)
    var duct := _mk(Color(0.36, 0.37, 0.41), 0.0, true, 0.4, 0.5)
    var band := _mk(Color(0.18, 0.18, 0.20), 0.0, true, 0.4, 0.5)
    for i in 21:
        var c: float = -20.0 + 2.0 * float(i)
        _quad(line, Vector3(c - 0.03, 6.09, -20.0), Vector3(c + 0.03, 6.09, -20.0), Vector3(c + 0.03, 6.09, 20.0), Vector3(c - 0.03, 6.09, 20.0), Vector3.DOWN)
        _quad(line, Vector3(-20.0, 6.09, c - 0.03), Vector3(20.0, 6.09, c - 0.03), Vector3(20.0, 6.09, c + 0.03), Vector3(-20.0, 6.09, c + 0.03), Vector3.DOWN)
    for dx in [-15.0, 15.0]:
        var dxf: float = dx
        _box(duct, Vector3(dxf, 5.78, 0.0), Vector3(0.7, 0.5, 38.0), 0.0, true)
        for i in 7:
            _box(band, Vector3(dxf, 5.78, -18.0 + 6.0 * float(i)), Vector3(0.78, 0.56, 0.12), 0.0, true)


# ---------------------------------------------------------------- F station pads

func _do_stations() -> void:
    var pad := _mk(Color(0.07, 0.07, 0.08), 0.0, false)
    var glow := _mk(C_YELLOW, 1.0, false)
    var wglow := _mk(C_BLUE, 1.0, false)
    var gold := _mk(GOLD, 1.2, false)
    for z in [-12.0, -7.0, -2.0, 3.0, 8.0, 13.0]:
        var zf: float = z
        _pad(pad, glow, 18.5, zf, 2.4, 3.6, 0.0)
    for z in [-9.0, -3.0, 3.0, 9.0]:
        var zw: float = z
        _pad(pad, glow, -18.6, zw, 2.4, 4.0, 0.0)
    _ring(glow, pad, -12.0, 0.08, -16.0, 2.6)
    _ring(wglow, pad, -12.0, 0.08, 16.0, 1.3)
    _ring(wglow, pad, 12.0, 0.08, 16.0, 1.3)
    _pad(pad, glow, 0.0, -18.2, 3.2, 1.8, 0.0)
    _pad(pad, gold, 0.0, 18.2, 5.0, 2.6, 0.0)


# ---------------------------------------------------------------- E props

func _do_props() -> void:
    # north wall (u = x); locker sits at x = 0, PR Rack is out at x = -12
    _dumbbell_rack(_wn, _u(_wn, 8.5, -20.0))
    _barbell_rack(_wn, _u(_wn, 12.3, -20.0))
    _bench_press(_wn, _u(_wn, 16.0, -20.0))
    _plate_stack(-16.5, 0.0, -19.3)
    # south wall (u = -x); Ending Station sits at x = 0
    for tx in [-17.0, -15.8, -14.6]:
        var txf: float = tx
        _treadmill(_ws, _u(_ws, txf, 20.0))
    _dumbbell_rack(_ws, _u(_ws, 7.5, 20.0))
    _barbell_rack(_ws, _u(_ws, 11.0, 20.0))
    _bench_press(_ws, _u(_ws, 15.5, 20.0))
    # west wall (u = -z); wall buys sit at z = -9..9
    _dumbbell_rack(_ww, _u(_ww, -20.0, -15.0))
    _plate_stack(-19.3, 0.0, 11.4)
    _barbell_rack(_ww, _u(_ww, -20.0, 13.8))
    _dumbbell_rack(_ww, _u(_ww, -20.0, 16.8))
    # east wall (u = z); supplements sit at z = -12..13
    _dumbbell_rack(_we, _u(_we, 20.0, -16.5))
    _barbell_rack(_we, _u(_we, 20.0, 16.3))


# ---------------------------------------------------------------- F signs

func _do_signs() -> void:
    _poster(_ws, _u(_ws, 0.0, 20.0), 4.85, 9.0, 0.9, C_BLACK, "ESCAPE: 50,000", GOLD)
    _label("NO PAIN  NO GAINS", _wp(_wn, 0.0, 3.55, 0.15), _wyaw(_wn), 0.014, C_WHITE, C_BLACK, 6, false)
    # north
    _poster(_wn, _u(_wn, 9.5, -20.0), 3.2, 3.0, 1.5, C_BLACK, "SWEAT NOW\nSHINE LATER", C_YELLOW)
    _poster(_wn, _u(_wn, 14.5, -20.0), 3.2, 3.0, 1.5, RED, "BEAST\nMODE", C_WHITE)
    _poster(_wn, _u(_wn, -8.0, -20.0), 3.2, 3.0, 1.5, C_YELLOW, "PR DAY\nEVERY DAY", C_BLACK)
    _poster(_wn, _u(_wn, -15.0, -20.0), 3.2, 3.0, 1.5, C_BLACK, "DEAD\nLIFT", C_YELLOW)
    # south
    _poster(_ws, _u(_ws, -11.0, 20.0), 3.4, 3.4, 1.5, C_BLACK, "NEVER SKIP\nLEG DAY", C_YELLOW)
    _poster(_ws, _u(_ws, 11.0, 20.0), 3.4, 3.4, 1.5, RED, "RISE AND\nGRIND", C_WHITE)
    _poster(_ws, _u(_ws, -16.0, 20.0), 3.4, 2.6, 1.5, C_YELLOW, "CARDIO\nIS KEY", C_BLACK)
    # east (above the supplement stations)
    _poster(_we, _u(_we, 20.0, 0.0), 4.5, 6.4, 1.1, C_BLACK, "SUPPLEMENT BAR", C_YELLOW)
    _poster(_we, _u(_we, 20.0, -12.0), 4.5, 3.4, 1.1, RED, "TAKE YOUR\nSUPPLEMENTS", C_WHITE)
    _poster(_we, _u(_we, 20.0, 11.0), 4.5, 3.4, 1.1, C_BLACK, "HYDRATE OR\nDIE-DRATE", C_YELLOW)
    # west (above the wall buys)
    _poster(_ww, _u(_ww, -20.0, 0.0), 4.5, 5.0, 1.1, C_BLACK, "GUN WALL", C_YELLOW)
    _poster(_ww, _u(_ww, -20.0, -13.0), 4.5, 3.8, 1.1, RED, "LIFT HEAVY\nSHOOT HEAVIER", C_WHITE)
    _poster(_ww, _u(_ww, -20.0, 13.0), 4.5, 3.4, 1.1, C_YELLOW, "NO\nEXCUSES", C_BLACK)


# ---------------------------------------------------------------- G blood

func _do_blood() -> void:
    var b1 := _mk(C_BLOOD, 0.0, false)
    var b2 := _mk(C_BLOOD2, 0.0, false)
    for i in 16:
        _splat(_rng, b1, b2, _rng.randf_range(-17.0, 17.0), _rng.randf_range(-17.0, 17.0), 0.08)
    for w in _wf:
        var wf: Array = w
        for i in 8:
            _drip(_rng, b1, wf, 18.0, 1.0, 5.0)


# END OF FILE
