extends "res://scripts/managers/compound_props.gd"
## Random Gym decor, part 1 of 2: reads the generated layout and dresses the
## floors, walls, props, posters, signs and wall lamps.
## Part 2 is gym_floor_dresser.gd (environment, lights, doors, blood, rings).

const H: float = 8.0   # wall height, same as map_gen_base WALL_H
const T: float = 1.0   # wall thickness, same as map_gen_base WALL_T

const ACCENTS: Array = [Color(0.95, 0.74, 0.06), Color(0.12, 0.55, 0.6), Color(0.85, 0.4, 0.1), Color(0.65, 0.09, 0.08)]
const PAPERS: Array = [Color(0.6, 0.1, 0.09), Color(0.9, 0.7, 0.08), Color(0.1, 0.45, 0.5), Color(0.85, 0.4, 0.1), Color(0.8, 0.8, 0.76), Color(0.15, 0.15, 0.2)]
const WORDS: Array = ["NO PAIN NO GAINS", "LEG DAY", "NEVER SKIP", "PR OR DIE", "DONT QUIT", "HYDRATE", "LIFT HEAVY", "PUSH", "PULL", "SQUAT", "EAT MEAT", "GRIND"]

# Which props each room type gets (picked at random, wall-hugging only).
const THEMES: Dictionary = {
    "Lobby": ["dbrack", "plates", "crates", "bench"],
    "Weights Room": ["rack", "dbrack", "plates", "bench"],
    "Cardio Zone": ["treadmill", "treadmill", "bench"],
    "Locker Room": ["lockers", "bench"],
    "Spin Studio": ["bench", "dbrack"],
    "Pool Deck": ["crates", "bench"],
    "Stretch Area": ["bench", "plates"],
    "Smoothie Bar": ["crates", "bench", "lockers"],
    "Boxing Ring": ["plates", "crates", "bench"],
    "Yoga Studio": ["plates", "bench"],
    "Free Weights": ["rack", "dbrack", "plates"],
    "Sauna": ["lockers", "bench"],
    "Squat Cage": ["rack", "rack", "plates"],
}
const MIRROR_ROOMS: Array = ["Spin Studio", "Yoga Studio", "Weights Room", "Stretch Area", "Cardio Zone"]

var _gen: Node
var _gw: int = 4
var _gh: int = 3
var _cs: float = 20.0
var _dw: float = 4.0
var _grp: PackedInt32Array = PackedInt32Array()
var _names: Array = []
var _door_off: Dictionary = {}
var _start_g: int = 0
var _sides: Array = []
var _first_cell: Dictionary = {}
var _first_side: Dictionary = {}
var _mirror_side: Dictionary = {}


func _load_layout() -> bool:
    _gen = get_parent().get_node_or_null("MapGen")
    if _gen == null:
        return false
    _gw = int(_gen.get("grid_w"))
    _gh = int(_gen.get("grid_h"))
    _cs = float(_gen.get("cell"))
    _dw = float(_gen.get("door_width"))
    _grp = _gen.get("_grp")
    _names = _gen.get("_names")
    _door_off = _gen.get("_door_off")
    _start_g = int(_gen.get("_start_g"))
    if _grp.is_empty() or _names.is_empty():
        return false
    _rng.seed = int(_gen.get("seed_used")) + 7
    return true


func _cell_pos(x: int, y: int) -> Vector3:
    return Vector3((float(x) - float(_gw) * 0.5 + 0.5) * _cs, 0.0, (float(y) - float(_gh) * 0.5 + 0.5) * _cs)


func _ekey(x: int, y: int, vert: bool) -> String:
    return "%d,%d,%s" % [x, y, "v" if vert else "h"]


## Every wall face of every cell (outer walls and walls between rooms).
func _collect_sides() -> void:
    var dirs: Array = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
    for y in _gh:
        for x in _gw:
            var g: int = _grp[y * _gw + x]
            var c: Vector3 = _cell_pos(x, y)
            if not _first_cell.has(g):
                _first_cell[g] = c
            for d in dirs:
                var nx: int = x + int(d.x)
                var ny: int = y + int(d.z)
                var door: float = INF
                if nx >= 0 and nx < _gw and ny >= 0 and ny < _gh:
                    if _grp[ny * _gw + nx] == g:
                        continue
                    var key: String = _ekey(mini(x, nx), mini(y, ny), d.x != 0.0)
                    if _door_off.has(key):
                        door = float(_door_off[key])
                var along: Vector3 = Vector3(0, 0, 1) if d.x != 0.0 else Vector3(1, 0, 0)
                _sides.append({"g": g, "c": c, "d": d, "face": c + d * (_cs * 0.5 - T * 0.5), "nrm": -d, "along": along, "door": door})
                if door == INF and not _first_side.has(g):
                    _first_side[g] = _sides.size() - 1
    for g in _first_side.keys():
        if str(_names[g]) in MIRROR_ROOMS:
            _mirror_side[_first_side[g]] = true


## Wall ranges (along the wall, from -half to +half) that are not the doorway.
func _pieces(s: Dictionary, margin: float) -> Array:
    var h: float = _cs * 0.5
    var door: float = s["door"]
    if door == INF:
        return [[-h, h]]
    var gap: float = (_dw + 0.3) * 0.5 + margin
    var out: Array = []
    if door - gap > -h + 0.4:
        out.append([-h, door - gap])
    if door + gap < h - 0.4:
        out.append([door + gap, h])
    return out


# ---------------------------------------------------------------- floors

func _dress_floors() -> void:
    var seam: Color = Color(0.09, 0.09, 0.1)
    var hc: float = _cs * 0.5
    for y in _gh:
        for x in _gw:
            var c: Vector3 = _cell_pos(x, y)
            for i in [-5.0, 0.0, 5.0]:
                _fq(c.x + i - 0.04, c.z - hc, c.x + i + 0.04, c.z + hc, 0.025, seam)
                _fq(c.x - hc, c.z + i - 0.04, c.x + hc, c.z + i + 0.04, 0.025, seam)
    # yellow edge tape along every solid wall piece
    for s in _sides:
        for p in _pieces(s, 0.25):
            var a: Vector3 = s["face"] + s["nrm"] * 0.35 + s["along"] * p[0]
            var b: Vector3 = s["face"] + s["nrm"] * 0.47 + s["along"] * p[1]
            _fq(minf(a.x, b.x), minf(a.z, b.z), maxf(a.x, b.x), maxf(a.z, b.z), 0.03, YELLOW)
    for g in _first_cell.keys():
        _room_floor(str(_names[g]), _first_cell[g], int(g))


func _room_floor(rname: String, c: Vector3, g: int) -> void:
    var acc: Color = ACCENTS[g % ACCENTS.size()]
    if rname == "Lobby":
        _ring(Vector3(c.x, 0.03, c.z), 5.5, 5.75, YELLOW)
        _ring(Vector3(c.x, 0.03, c.z), 2.4, 2.5, WHITE)
    elif rname == "Boxing Ring":
        _fq(c.x - 4.0, c.z - 4.0, c.x + 4.0, c.z - 3.85, 0.03, acc)
        _fq(c.x - 4.0, c.z + 3.85, c.x + 4.0, c.z + 4.0, 0.03, acc)
        _fq(c.x - 4.0, c.z - 4.0, c.x - 3.85, c.z + 4.0, 0.03, acc)
        _fq(c.x + 3.85, c.z - 4.0, c.x + 4.0, c.z + 4.0, 0.03, acc)
    elif rname == "Yoga Studio" or rname == "Stretch Area":
        var cols: Array = [TEAL, Color(0.45, 0.2, 0.6), ORANGE]
        for i in 3:
            var dx: float = (float(i) - 1.0) * 3.0
            _fq(c.x + dx - 0.5, c.z - 1.1, c.x + dx + 0.5, c.z + 1.1, 0.03, cols[i])
    elif rname == "Spin Studio":
        _ring(Vector3(c.x - 3.5, 0.03, c.z), 1.6, 1.75, acc)
        _ring(Vector3(c.x + 3.5, 0.03, c.z), 1.6, 1.75, acc)
    elif rname == "Pool Deck":
        _fq(c.x - 4.0, c.z - 2.5, c.x + 4.0, c.z + 2.5, 0.028, Color(0.1, 0.35, 0.4))
        _fq(c.x - 4.1, c.z - 2.6, c.x + 4.1, c.z - 2.5, 0.03, WHITE)
        _fq(c.x - 4.1, c.z + 2.5, c.x + 4.1, c.z + 2.6, 0.03, WHITE)
    else:
        _fq(c.x - 1.2, c.z - 7.5, c.x + 1.2, c.z + 7.5, 0.028, Color(0.32, 0.06, 0.06))
        _fq(c.x - 1.3, c.z - 7.5, c.x - 1.2, c.z + 7.5, 0.03, WHITE)
        _fq(c.x + 1.2, c.z - 7.5, c.x + 1.3, c.z + 7.5, 0.03, WHITE)


func _dress_floor_labels() -> void:
    for g in _first_cell.keys():
        var c: Vector3 = _first_cell[g]
        var l: Label3D = Label3D.new()
        l.text = str(_names[g]).to_upper()
        l.font_size = 64
        l.pixel_size = 1.3 / 64.0
        l.modulate = ACCENTS[int(g) % ACCENTS.size()]
        l.outline_size = 8
        l.outline_modulate = Color(0.02, 0.02, 0.03, 1.0)
        l.shaded = false
        l.visibility_range_end = 40.0
        l.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
        l.position = Vector3(c.x, 0.05, c.z + 7.5)
        add_child(l)


# ----------------------------------------------------------------- walls

func _dress_walls() -> void:
    for s in _sides:
        var g: int = s["g"]
        var acc: Color = ACCENTS[g % ACCENTS.size()]
        var wain: Color = Color(0.2, 0.2, 0.23) if g % 2 == 0 else Color(0.27, 0.11, 0.1)
        for p in _pieces(s, 0.0):
            var mid: Vector3 = s["face"] + s["along"] * ((p[0] + p[1]) * 0.5)
            var w: float = p[1] - p[0]
            var nrm: Vector3 = s["nrm"]
            _wq(mid + AY * 0.7, nrm, w, 1.4, wain)
            _wq(mid + AY * 1.45, nrm, w, 0.1, acc, false, 0.035)
            _wq(mid + AY * (H - 0.45), nrm, w, 0.7, DARK, false, 0.03)
            _wq(mid + AY * (H - 0.95), nrm, w, 0.08, acc, false, 0.04)


# ----------------------------------------------------------------- props

func _put_prop(kind: String, c: Vector3, nrm: Vector3) -> void:
    if kind == "rack":
        _rack(c, nrm)
    elif kind == "dbrack":
        _dbrack(c, nrm)
    elif kind == "plates":
        _plates(c, nrm)
    elif kind == "bench":
        _bench(c, nrm)
    elif kind == "treadmill":
        _treadmill(c, nrm)
    elif kind == "crates":
        _crates(c, nrm)
    elif kind == "lockers":
        _lockers(c, nrm, 2.0)


## Props sit only on solid wall sides, at +-3 m (between the station slots).
func _dress_props() -> void:
    for s in _sides:
        if s["door"] != INF:
            continue
        var kinds: Array = THEMES.get(str(_names[s["g"]]), ["bench", "crates"])
        for t in [-3.0, 3.0]:
            if _rng.randf() < 0.18:
                continue
            var kind: String = kinds[_rng.randi() % kinds.size()]
            _put_prop(kind, s["face"] + s["along"] * t, s["nrm"])


func _dress_posters() -> void:
    var i: int = 0
    for idx in _sides.size():
        var s: Dictionary = _sides[idx]
        if s["door"] != INF:
            continue
        if _mirror_side.has(idx):
            _mirror(s["face"] + AY * 3.0, s["nrm"], 8.0, 1.6)
            continue
        for t in [-3.0, 3.0]:
            _poster(s["face"] + s["along"] * t + AY * 3.5, s["nrm"], 1.4, 2.0, PAPERS[i % PAPERS.size()], WORDS[i % WORDS.size()])
            i += 1


func _dress_signs() -> void:
    for g in _first_side.keys():
        var s: Dictionary = _sides[_first_side[g]]
        if int(g) == _start_g:
            _sign("JACKED UNDEAD", s["face"] + AY * 6.0, s["nrm"], 1.1, YELLOW)
        else:
            _sign(str(_names[g]).to_upper(), s["face"] + AY * 6.0, s["nrm"], 0.9, ACCENTS[int(g) % ACCENTS.size()])


func _dress_fixtures() -> void:
    for s in _sides:
        if s["door"] != INF:
            continue
        _fixture(s["face"] + s["along"] * 6.0 + AY * (H - 0.4), s["nrm"])

# END OF FILE
