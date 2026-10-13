extends "res://scripts/managers/map_dress_base.gd"
## Visual dressing for the Multi-Room map. Cosmetic only.
## Rooms: lobby (yellow), west wing (red), east wing (blue), upstairs loft (green).

const ACC_LOBBY := Color(1.0, 0.77, 0.0)
const ACC_WEST := Color(0.85, 0.12, 0.12)
const ACC_EAST := Color(0.22, 0.5, 0.95)
const ACC_UP := Color(0.2, 0.75, 0.38)
const CATWALK_Y := 5.25

var _f := {}


func _ready() -> void:
    _setup_environment(0.005, 1.0, 0.9)
    _restyle_base()
    _init_props()
    _make_frames()
    _build_floors()
    _build_ramps()
    _build_walls()
    _build_ceiling()
    _build_props()
    _build_doors()
    _build_zones()
    _build_blood()
    _build_rails()
    _flush()


func _restyle_base() -> void:
    var p := get_parent()
    var floor_mat := _std(C_FLOOR, 0.95)
    var wall_mat := _std(C_WALL, 0.95)
    var steel_mat := _std(Color(0.19, 0.20, 0.23), 0.8)
    for node in p.find_children("*", "MeshInstance3D", true, false):
        var mi := node as MeshInstance3D
        var par := mi.get_parent()
        if par == null:
            continue
        var pn := String(par.name)
        var mn := String(mi.name)
        if pn == "GroundFloor":
            mi.material_override = floor_mat
        elif pn == "UpperCatwalk" and mn == "MeshInstance3D":
            mi.material_override = steel_mat
        elif (pn == "WestRamp" or pn == "EastStairs") and mn == "MeshInstance3D":
            mi.material_override = steel_mat
        elif mn.begins_with("Ledge"):
            mi.material_override = wall_mat
        elif par.get_parent() != null and String(par.get_parent().name) == "Walls":
            mi.material_override = wall_mat


func _make_frames() -> void:
    _f["lobby_n"] = _fr(Vector3(0, 0, -4.5), Vector3(0, 0, 1))
    _f["west_n"] = _fr(Vector3(-19.75, 0, -4.5), Vector3(0, 0, 1))
    _f["east_n"] = _fr(Vector3(19.75, 0, -4.5), Vector3(0, 0, 1))
    _f["up_n"] = _fr(Vector3(0, 0, -29), Vector3(0, 0, 1))
    _f["up_w"] = _fr(Vector3(-29, 0, -17.05), Vector3(1, 0, 0))
    _f["up_e"] = _fr(Vector3(29, 0, -17.05), Vector3(-1, 0, 0))
    _f["lobby_s"] = _fr(Vector3(0, 0, 29), Vector3(0, 0, -1))
    _f["west_s"] = _fr(Vector3(-19.75, 0, 29), Vector3(0, 0, -1))
    _f["east_s"] = _fr(Vector3(19.75, 0, 29), Vector3(0, 0, -1))
    _f["west_w"] = _fr(Vector3(-29, 0, 12.25), Vector3(1, 0, 0))
    _f["east_e"] = _fr(Vector3(29, 0, 12.25), Vector3(-1, 0, 0))
    _f["dw_lobby_a"] = _fr(Vector3(-9.5, 0, 5.25), Vector3(1, 0, 0))
    _f["dw_lobby_b"] = _fr(Vector3(-9.5, 0, 24.5), Vector3(1, 0, 0))
    _f["dw_west_a"] = _fr(Vector3(-10.5, 0, 5.25), Vector3(-1, 0, 0))
    _f["dw_west_b"] = _fr(Vector3(-10.5, 0, 24.5), Vector3(-1, 0, 0))
    _f["de_lobby_a"] = _fr(Vector3(9.5, 0, 5.25), Vector3(-1, 0, 0))
    _f["de_lobby_b"] = _fr(Vector3(9.5, 0, 24.5), Vector3(-1, 0, 0))
    _f["de_east_a"] = _fr(Vector3(10.5, 0, 5.25), Vector3(1, 0, 0))
    _f["de_east_b"] = _fr(Vector3(10.5, 0, 24.5), Vector3(1, 0, 0))


# ---------------------------------------------------------------- floors

func _build_floors() -> void:
    _floor_rect(_mk(Color(0.14, 0.14, 0.16), 0.0, false), 0.0, 12.25, 19.0, 33.5, 0.012)
    _floor_rect(_mk(Color(0.17, 0.11, 0.11), 0.0, false), -19.75, 12.25, 18.5, 33.5, 0.012)
    _floor_rect(_mk(Color(0.10, 0.12, 0.18), 0.0, false), 19.75, 12.25, 18.5, 33.5, 0.012)
    _floor_rect(_mk(Color(0.11, 0.15, 0.12), 0.0, false), 0.0, -17.0, 58.0, 24.0, CATWALK_Y + 0.012)
    var seam := _mk(Color(0.05, 0.05, 0.06), 0.0, false)
    for i in range(-5, 6):
        _floor_rect(seam, float(i) * 5.0, 12.25, 0.06, 33.5, 0.02)
    for i in range(0, 6):
        _floor_rect(seam, 0.0, float(i) * 5.0, 58.0, 0.06, 0.02)
    _floor_outline(_mk(ACC_LOBBY, 0.0, false), 0.0, 12.25, 17.6, 32.1, 0.028, 0.28)
    _floor_outline(_mk(ACC_WEST, 0.0, false), -19.75, 12.25, 17.1, 32.1, 0.028, 0.28)
    _floor_outline(_mk(ACC_EAST, 0.0, false), 19.75, 12.25, 17.1, 32.1, 0.028, 0.28)
    _floor_outline(_mk(ACC_UP, 0.0, false), 0.0, -17.05, 56.4, 22.3, CATWALK_Y + 0.028, 0.28)
    var grate := _mk(Color(0.07, 0.08, 0.09), 0.0, false)
    var gy := CATWALK_Y + 0.02
    var gx := -28.0
    while gx <= 28.0:
        _floor_rect(grate, gx, -17.0, 0.05, 23.5, gy)
        gx += 2.0
    var gz := -28.0
    while gz <= -6.0:
        _floor_rect(grate, 0.0, gz, 57.5, 0.05, gy)
        gz += 2.0


func _ramp_rect(k: String, top: Vector3, xd: Vector3, zd: Vector3, yd: Vector3, a: float, b: float, w: float, d: float) -> void:
    var c := top + xd * a + zd * b
    var hw := xd * (w * 0.5)
    var hd := zd * (d * 0.5)
    _quad(k, c - hw - hd, c + hw - hd, c + hw + hd, c - hw + hd, yd)


func _build_ramps() -> void:
    var yel := _mk(C_YELLOW, 0.0, false)
    var grip := _mk(Color(0.05, 0.05, 0.06), 0.0, false)
    var xd := Vector3(-1.0, 0.0, 0.0)
    var yd := Vector3(0.0, 0.894427, 0.447214)
    var zd := Vector3(0.0, 0.447214, -0.894427)
    for cx in [-18.0, 18.0]:
        var top := Vector3(float(cx), 2.5, 0.0) + yd * 0.27
        for sx in [-1.0, 1.0]:
            _ramp_rect(yel, top, xd, zd, yd, float(sx) * 1.55, 0.0, 0.14, 12.3)
        var b := -5.8
        while b <= 5.8:
            _ramp_rect(grip, top, xd, zd, yd, 0.0, b, 3.0, 0.12)
            b += 0.7


# ---------------------------------------------------------------- walls

func _build_walls() -> void:
    var segs := [
        ["lobby_n", 9.5, 0.0, 5.0, ACC_LOBBY],
        ["west_n", 9.25, 0.0, 5.0, ACC_WEST],
        ["east_n", 9.25, 0.0, 5.0, ACC_EAST],
        ["up_n", 29.0, CATWALK_Y, 10.0, ACC_UP],
        ["up_w", 11.95, CATWALK_Y, 10.0, ACC_UP],
        ["up_e", 11.95, CATWALK_Y, 10.0, ACC_UP],
        ["lobby_s", 9.5, 0.0, 10.0, ACC_LOBBY],
        ["west_s", 9.25, 0.0, 10.0, ACC_WEST],
        ["east_s", 9.25, 0.0, 10.0, ACC_EAST],
        ["west_w", 16.75, 0.0, 10.0, ACC_WEST],
        ["east_e", 16.75, 0.0, 10.0, ACC_EAST],
        ["dw_lobby_a", 9.75, 0.0, 10.0, ACC_LOBBY],
        ["dw_lobby_b", 4.5, 0.0, 10.0, ACC_LOBBY],
        ["de_lobby_a", 9.75, 0.0, 10.0, ACC_LOBBY],
        ["de_lobby_b", 4.5, 0.0, 10.0, ACC_LOBBY],
        ["dw_west_a", 9.75, 0.0, 10.0, ACC_WEST],
        ["dw_west_b", 4.5, 0.0, 10.0, ACC_WEST],
        ["de_east_a", 9.75, 0.0, 10.0, ACC_EAST],
        ["de_east_b", 4.5, 0.0, 10.0, ACC_EAST],
    ]
    for s in segs:
        _dress_wall(_f[s[0]], float(s[1]), float(s[2]), float(s[3]), s[4])
    _mirror(_f["west_w"], 8.25, 15.25)
    _mirror(_f["east_e"], -15.25, -8.25)
    # lobby
    _poster(_f["lobby_n"], 0.0, 3.6, 8.0, 1.2, C_YELLOW, "JACKED UNDEAD GYM", C_BLACK)
    _poster(_f["lobby_s"], 0.0, 6.4, 12.0, 2.2, C_BLACK, "WELCOME TO THE GRIND", C_YELLOW)
    _poster(_f["lobby_s"], 0.0, 3.7, 3.6, 0.9, C_BLACK, "ARMORY", C_YELLOW)
    _poster(_f["dw_lobby_a"], 0.0, 5.8, 8.0, 3.0, C_RED, "NO PAIN\nNO GAINS", C_WHITE)
    _poster(_f["de_lobby_a"], 0.0, 5.8, 8.0, 3.0, C_YELLOW, "LEG DAY IS\nEVERY DAY", C_BLACK)
    _poster(_f["dw_lobby_b"], 0.0, 5.8, 6.0, 3.0, C_BLUE, "STAY\nHYDRATED", C_WHITE)
    _poster(_f["de_lobby_b"], 0.0, 5.8, 6.0, 3.0, C_WHITE, "FEED THE\nGAINS", C_BLACK)
    # west wing
    _poster(_f["west_w"], 10.25, 6.2, 7.0, 2.6, C_RED, "WEST WING\nFREE WEIGHTS", C_WHITE)
    _poster(_f["west_w"], -11.75, 6.2, 7.0, 2.6, C_BLACK, "NO\nEXCUSES", C_YELLOW)
    _poster(_f["west_w"], -7.75, 3.7, 3.6, 0.9, C_BLACK, "ARMORY", C_YELLOW)
    _poster(_f["west_s"], 0.0, 5.8, 8.0, 3.0, C_YELLOW, "DEADLIFT OR\nDIE TRYING", C_BLACK)
    _poster(_f["dw_west_a"], 0.0, 5.8, 8.0, 3.0, C_WHITE, "CHALK UP.\nLOCK IN.", C_BLACK)
    # east wing
    _poster(_f["east_e"], -10.25, 6.2, 7.0, 2.6, ACC_EAST, "EAST WING\nCARDIO ZONE", C_WHITE)
    _poster(_f["east_e"], 11.75, 6.2, 7.0, 2.6, C_BLACK, "RUN FROM\nTHE DEAD", C_YELLOW)
    _poster(_f["east_e"], 7.75, 3.7, 3.6, 0.9, C_BLACK, "ARMORY", C_YELLOW)
    _poster(_f["east_s"], 0.0, 5.8, 8.0, 3.0, C_RED, "ONE MORE\nREP", C_WHITE)
    _poster(_f["de_east_a"], 0.0, 5.8, 8.0, 3.0, C_YELLOW, "SWEAT NOW.\nSHINE LATER.", C_BLACK)
    # upstairs loft
    _poster(_f["up_n"], 0.0, 8.0, 10.0, 1.6, ACC_UP, "THE LOFT", C_BLACK)
    _poster(_f["up_n"], -20.0, 7.4, 8.0, 2.4, C_BLACK, "PR OR\nNOTHING", ACC_UP)
    _poster(_f["up_n"], 20.0, 7.4, 8.0, 2.4, C_WHITE, "TOP OF THE\nFOOD CHAIN", C_BLACK)
    _poster(_f["up_w"], 0.0, 7.2, 8.0, 2.4, ACC_UP, "STRONGER THAN\nYESTERDAY", C_BLACK)
    _poster(_f["up_e"], 0.0, 7.2, 8.0, 2.4, ACC_UP, "TRAIN LIKE\nA BEAST", C_BLACK)


# ---------------------------------------------------------------- ceiling
# No upward-facing surfaces up here, so the navmesh bake ignores all of it.

func _build_ceiling() -> void:
    var ceil_k := _mk(Color(0.07, 0.07, 0.08), 0.0, false)
    _quad(ceil_k, Vector3(-29, 10, -29), Vector3(29, 10, -29), Vector3(29, 10, 29), Vector3(-29, 10, 29), Vector3.DOWN)
    var beam := _mk(Color(0.22, 0.23, 0.26), 0.0, false)
    for z in [-24.0, -14.0, 0.0, 10.0, 20.0]:
        _box(beam, Vector3(0.0, 9.6, float(z)), Vector3(58.0, 0.5, 0.35), 0.0, true)
    for x in [-19.75, 0.0, 19.75]:
        _box(beam, Vector3(float(x), 9.75, 0.0), Vector3(0.35, 0.3, 58.0), 0.0, true)
    var strip := _mk(Color(1.0, 0.96, 0.82), 2.5, false)
    for z in [0.0, 10.0, 20.0]:
        for x in [-19.75, 0.0, 19.75]:
            _box(strip, Vector3(float(x), 9.22, float(z)), Vector3(3.2, 0.1, 0.28), 0.0, true)
    for z in [-24.0, -14.0]:
        for x in [-20.0, -7.0, 7.0, 20.0]:
            _box(strip, Vector3(float(x), 9.22, float(z)), Vector3(3.2, 0.1, 0.28), 0.0, true)


# ---------------------------------------------------------------- props

func _desk(f: Array, u: float) -> void:
    var black: String = _pm["black"]
    var yel := _mk(C_YELLOW, 0.0, true, 0.0, 0.5)
    var pos := _wp(f, u, 0.0, 0.02)
    var yaw := _wyaw(f)
    _lbox(black, pos, yaw, Vector3(0.0, 0.55, 0.7), Vector3(5.0, 1.1, 1.0))
    _lbox(yel, pos, yaw, Vector3(0.0, 1.13, 0.75), Vector3(5.2, 0.06, 1.2))
    _lbox(yel, pos, yaw, Vector3(0.0, 0.3, 1.21), Vector3(4.6, 0.08, 0.02))
    _label("FRONT DESK", _wp(f, u, 0.7, 1.26), yaw, 0.007, C_YELLOW, C_BLACK, 8, false)
    _solid(pos, yaw, Vector3(0.0, 0.57, 0.75), Vector3(5.2, 1.14, 1.2))


func _build_props() -> void:
    _desk(_f["lobby_n"], 0.0)
    var dla: Array = _f["dw_lobby_a"]
    var dra: Array = _f["de_lobby_a"]
    _dumbbell_rack(dla, _u(dla, -9.5, 9.0))
    _dumbbell_rack(dra, _u(dra, 9.5, 9.0))
    # west wing
    var ww: Array = _f["west_w"]
    _dumbbell_rack(ww, _u(ww, -29.0, 1.0))
    _dumbbell_rack(ww, _u(ww, -29.0, 26.0))
    var ws: Array = _f["west_s"]
    _barbell_rack(ws, _u(ws, -24.0, 29.0))
    _bench_press(ws, _u(ws, -14.0, 29.0))
    var dwa: Array = _f["dw_west_a"]
    _dumbbell_rack(dwa, _u(dwa, -10.5, 11.0))
    _bench_press(dwa, _u(dwa, -10.5, 1.0))
    var dwb: Array = _f["dw_west_b"]
    _dumbbell_rack(dwb, _u(dwb, -10.5, 24.5))
    _plate_stack(-27.9, 0.0, -3.4)
    _plate_stack(-27.9, 0.0, 27.9)
    # east wing (cardio)
    var ee: Array = _f["east_e"]
    _dumbbell_rack(ee, _u(ee, 29.0, 1.0))
    _dumbbell_rack(ee, _u(ee, 29.0, 26.0))
    var es: Array = _f["east_s"]
    for x in [14.75, 17.75, 20.75, 23.75]:
        _treadmill(es, _u(es, float(x), 29.0))
    var dea: Array = _f["de_east_a"]
    _dumbbell_rack(dea, _u(dea, 10.5, 11.0))
    _bench_press(dea, _u(dea, 10.5, 1.0))
    var deb: Array = _f["de_east_b"]
    _dumbbell_rack(deb, _u(deb, 10.5, 24.5))
    _plate_stack(27.9, 0.0, -3.4)
    _plate_stack(27.9, 0.0, 27.9)
    # upstairs loft
    var un: Array = _f["up_n"]
    _dumbbell_rack(un, -16.0, CATWALK_Y)
    _dumbbell_rack(un, 16.0, CATWALK_Y)
    _barbell_rack(un, -25.0, CATWALK_Y)
    _barbell_rack(un, 25.0, CATWALK_Y)
    var uw: Array = _f["up_w"]
    var ue: Array = _f["up_e"]
    _bench_press(uw, _u(uw, -29.0, -12.0), CATWALK_Y)
    _bench_press(ue, _u(ue, 29.0, -12.0), CATWALK_Y)
    _plate_stack(-27.9, CATWALK_Y, -27.9)
    _plate_stack(27.9, CATWALK_Y, -27.9)


# ---------------------------------------------------------------- doors

func _build_doors() -> void:
    var lintel := _mk(Color(0.10, 0.10, 0.12), 0.0, true)
    for s in [[-10.0, "WEST WING", ACC_WEST], [10.0, "EAST WING", ACC_EAST]]:
        var x := float(s[0])
        var col: Color = s[2]
        _box(lintel, Vector3(x, 8.9, 17.5), Vector3(0.9, 2.2, 5.2), 0.0, true)
        _box(_mk(col, 0.0, true), Vector3(x, 7.85, 17.5), Vector3(0.95, 0.1, 5.25), 0.0, true)
        _label(String(s[1]), Vector3(x + 0.47, 8.9, 17.5), PI * 0.5, 0.0105, C_WHITE, C_WHITE, 6, false)
        _label(String(s[1]), Vector3(x - 0.47, 8.9, 17.5), -PI * 0.5, 0.0105, C_WHITE, C_WHITE, 6, false)
    # caution tape + CLOSED on the debris doors; these are children of the door
    # node, so they disappear when the door is bought
    var tape := _std(C_YELLOW, 0.6)
    for dn in ["DebrisWestStairs", "DebrisEastStairs"]:
        var d := get_parent().get_node_or_null("BuyableDoors/%s" % dn)
        if d == null:
            continue
        for side in [-1.0, 1.0]:
            var sz := float(side) * 0.26
            for yy in [1.0, 2.2]:
                var bar := MeshInstance3D.new()
                var bm := BoxMesh.new()
                bm.size = Vector3(4.2, 0.18, 0.04)
                bar.mesh = bm
                bar.material_override = tape
                bar.position = Vector3(0.0, float(yy), sz)
                bar.rotation.z = deg_to_rad(-6.0 if yy == 1.0 else 6.0)
                d.add_child(bar)
            var lab := Label3D.new()
            lab.text = "CLOSED"
            lab.font_size = 64
            lab.pixel_size = 0.012
            lab.modulate = C_YELLOW
            lab.outline_modulate = C_BLACK
            lab.outline_size = 10
            lab.shaded = false
            lab.double_sided = true
            lab.position = Vector3(0.0, 1.6, sz + float(side) * 0.02)
            lab.rotation.y = 0.0 if side > 0.0 else PI
            d.add_child(lab)


# ---------------------------------------------------------------- zones + signs

func _build_zones() -> void:
    var yel := _mk(C_YELLOW, 0.0, false)
    var red := _mk(C_RED, 0.0, false)
    var blue := _mk(C_BLUE, 0.0, false)
    var green := _mk(ACC_UP, 0.0, false)
    var up := CATWALK_Y + 0.03
    _floor_outline(yel, -27.2, 10.0, 3.2, 7.4)
    _floor_outline(yel, 27.2, 10.0, 3.2, 7.4)
    _floor_outline(red, -24.0, 5.0, 5.5, 5.5)
    _floor_outline(yel, 24.0, 5.0, 3.4, 3.4)
    _floor_outline(blue, -3.0, 2.0, 2.6, 2.6)
    _floor_outline(blue, 0.0, -15.0, 2.6, 2.6, up)
    _floor_outline(red, -27.3, 20.0, 3.0, 4.5)
    _floor_outline(red, 27.3, 20.0, 3.0, 4.5)
    _floor_outline(red, 0.0, 27.3, 5.0, 3.0)
    _floor_outline(green, -10.0, -27.4, 3.0, 3.2, up)
    _floor_outline(green, 0.0, -27.4, 3.0, 3.2, up)
    _floor_outline(green, 10.0, -27.4, 3.0, 3.2, up)
    var black := Color(0, 0, 0)
    _label("SUPPLEMENT ROW", Vector3(-27.5, 3.6, 10.0), 0.0, 0.008, C_YELLOW, black, 12, true)
    _label("SUPPLEMENT ROW", Vector3(27.5, 3.6, 10.0), 0.0, 0.008, C_YELLOW, black, 12, true)
    _label("PR ZONE", Vector3(-24.0, 3.9, 5.0), 0.0, 0.008, Color(1.0, 0.3, 0.25), black, 12, true)
    _label("HYDRATION", Vector3(-3.0, 3.0, 2.0), 0.0, 0.006, C_BLUE, black, 12, true)
    _label("HYDRATION", Vector3(0.0, CATWALK_Y + 3.0, -15.0), 0.0, 0.006, C_BLUE, black, 12, true)


# ---------------------------------------------------------------- blood

func _build_blood() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261013
    var k1 := _mk(C_BLOOD, 0.0, false, 0.0, 0.35)
    var k2 := _mk(C_BLOOD2, 0.0, false, 0.0, 0.35)
    for i in 18:
        _splat(rng, k1, k2, rng.randf_range(-27.0, 27.0), rng.randf_range(-3.0, 27.0), 0.0)
    for i in 8:
        _splat(rng, k1, k2, rng.randf_range(-27.0, 27.0), rng.randf_range(-27.0, -7.0), CATWALK_Y)
    var drips := [
        ["west_w", 16.75, 2.5, 6.0], ["east_e", 16.75, 2.5, 6.0],
        ["west_s", 9.25, 2.5, 6.0], ["east_s", 9.25, 2.5, 6.0],
        ["lobby_s", 9.5, 2.5, 6.0], ["dw_west_a", 9.75, 2.5, 6.0],
        ["de_east_a", 9.75, 2.5, 6.0], ["dw_lobby_a", 9.75, 2.5, 6.0],
        ["de_lobby_a", 9.75, 2.5, 6.0], ["up_n", 29.0, 6.8, 9.0],
    ]
    for e in drips:
        for j in 3:
            _drip(rng, k1, _f[e[0]], float(e[1]), float(e[2]), float(e[3]))


# ---------------------------------------------------------------- catwalk rail (visual only)

func _build_rails() -> void:
    var yel := _mk(C_YELLOW, 0.0, true, 0.0, 0.5)
    var z := -5.1
    for seg in [[-29.0, -20.0], [-16.0, 16.0], [20.0, 29.0]]:
        var a := float(seg[0])
        var b := float(seg[1])
        _box(yel, Vector3((a + b) * 0.5, 7.0, z), Vector3(b - a, 0.07, 0.07), 0.0, true)
        var px := a
        while px <= b + 0.01:
            _box(yel, Vector3(px, 6.88, z), Vector3(0.07, 0.25, 0.07), 0.0, true)
            px += 4.0


# END OF FILE
