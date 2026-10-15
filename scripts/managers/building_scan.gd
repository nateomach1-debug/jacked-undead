extends RefCounted
# Raycast scan of the Building model (collision only), a few cells per physics frame.
# Finds flat interior wall spots, floor spots and ceiling spots for building_dresser.gd.

const FLOORS: Array = [-17.2, -14.0]
const X_MIN := -32.0
const X_MAX := 52.0
const Z_MIN := -4.0
const Z_MAX := 58.0
const STEP := 2.5
const REACH := 2.8

var walls: Array = []
var floors: Array = []
var ceils: Array = []

var _cells: Array = []
var _i: int = 0
var _q := PhysicsRayQueryParameters3D.new()
var _seen: Dictionary = {}


func _init() -> void:
    var x: float = X_MIN
    while x <= X_MAX:
        var z: float = Z_MIN
        while z <= Z_MAX:
            for fy: float in FLOORS:
                _cells.append(Vector3(x, fy, z))
            z += STEP
        x += STEP


func set_exclude(arr: Array[RID]) -> void:
    _q.exclude = arr


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
    _q.from = a
    _q.to = b
    return space.intersect_ray(_q)


# true once the building collision exists (floor near the player start)
func probe(space: PhysicsDirectSpaceState3D) -> bool:
    var h: Dictionary = _ray(space, Vector3(38.9, -15.0, 15.7), Vector3(38.9, -19.0, 15.7))
    if h.is_empty():
        return false
    var hp: Vector3 = h["position"]
    return hp.y > -17.8


# returns true when every cell has been scanned
func step(space: PhysicsDirectSpaceState3D, budget: int) -> bool:
    var n: int = 0
    while _i < _cells.size() and n < budget:
        var c: Vector3 = _cells[_i]
        _scan_cell(space, c)
        _i += 1
        n += 1
    return _i >= _cells.size()


func _scan_cell(space: PhysicsDirectSpaceState3D, c: Vector3) -> void:
    var fy: float = c.y
    var hf: Dictionary = _ray(space, Vector3(c.x, fy + 0.5, c.z), Vector3(c.x, fy - 0.6, c.z))
    if hf.is_empty():
        return
    var fp: Vector3 = hf["position"]
    if absf(fp.y - fy) > 0.1:
        return
    var hc: Dictionary = _ray(space, Vector3(c.x, fy + 0.3, c.z), Vector3(c.x, fy + 6.0, c.z))
    if hc.is_empty():
        return
    var cp: Vector3 = hc["position"]
    if cp.y - fy < 2.0:
        return
    floors.append(Vector3(c.x, fp.y, c.z))
    ceils.append(Vector3(c.x, cp.y, c.z))
    for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
        var o := Vector3(c.x, fy + 1.0, c.z)
        var hw: Dictionary = _ray(space, o, o + d * REACH)
        if hw.is_empty():
            continue
        var nrm: Vector3 = hw["normal"]
        if absf(nrm.y) > 0.15 or nrm.dot(-d) < 0.85:
            continue
        var wp: Vector3 = hw["position"]
        var plane: float = wp.dot(d)
        var flat: bool = true
        for hy: float in [0.4, 2.0]:
            var o2 := Vector3(c.x, fy + hy, c.z)
            var h2: Dictionary = _ray(space, o2, o2 + d * (REACH + 0.4))
            if h2.is_empty():
                flat = false
                break
            var p2: Vector3 = h2["position"]
            if absf(p2.dot(d) - plane) > 0.12:
                flat = false
                break
        if not flat:
            continue
        var tang: float = c.z if absf(d.x) > 0.5 else c.x
        var side: int = 1 if (d.x + d.z) > 0.0 else 0
        var key: String = "%d|%d|%d|%d" % [int(round(plane * 10.0)), int(round(tang * 4.0)), int(round(fy * 10.0)), side]
        if _seen.has(key):
            continue
        _seen[key] = true
        walls.append({"p": Vector3(wp.x, fp.y, wp.z), "n": -d, "ceil": cp.y, "fy": fp.y})


# true if the wall plane is flat for +-half along its length at the given heights
func wall_flat(space: PhysicsDirectSpaceState3D, p: Vector3, n: Vector3, half: float, heights: Array) -> bool:
    var t: Vector3 = Vector3.UP.cross(n)
    var plane: float = p.dot(-n)
    for off: float in [-half, -half * 0.5, 0.0, half * 0.5, half]:
        for hy: float in heights:
            var o: Vector3 = p + n * 0.5 + t * off + Vector3.UP * hy
            var h: Dictionary = _ray(space, o, o - n * 1.0)
            if h.is_empty():
                return false
            var hp: Vector3 = h["position"]
            if absf(hp.dot(-n) - plane) > 0.12:
                return false
    return true


# true if a w x d footprint in front of the wall has flat floor and nothing in the way
func footprint_free(space: PhysicsDirectSpaceState3D, p: Vector3, n: Vector3, w: float, d: float) -> bool:
    var t: Vector3 = Vector3.UP.cross(n)
    for ox: float in [-w * 0.5, 0.0, w * 0.5]:
        for od: float in [0.1, d]:
            var o: Vector3 = p + t * ox + n * od + Vector3.UP * 1.2
            var h: Dictionary = _ray(space, o, o - Vector3.UP * 1.6)
            if h.is_empty():
                return false
            var hp: Vector3 = h["position"]
            if absf(hp.y - p.y) > 0.06:
                return false
    for ox: float in [-w * 0.5, 0.0, w * 0.5]:
        for hy: float in [0.3, 1.0, 1.8]:
            var o2: Vector3 = p + t * ox + n * 0.12 + Vector3.UP * hy
            var h2: Dictionary = _ray(space, o2, o2 + n * (d + 0.5))
            if not h2.is_empty():
                return false
    return true


func floor_y(space: PhysicsDirectSpaceState3D, x: float, y: float, z: float) -> float:
    var h: Dictionary = _ray(space, Vector3(x, y + 0.7, z), Vector3(x, y - 0.7, z))
    if h.is_empty():
        return y
    var hp: Vector3 = h["position"]
    return hp.y


# direction (+-X / +-Z) from p to the nearest wall within 6 m, or ZERO
func nearest_wall_dir(space: PhysicsDirectSpaceState3D, p: Vector3) -> Vector3:
    var best: float = 1000000.0
    var bd := Vector3.ZERO
    for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
        var o: Vector3 = p + Vector3.UP * 1.0
        var h: Dictionary = _ray(space, o, o + d * 6.0)
        if h.is_empty():
            continue
        var hp: Vector3 = h["position"]
        var dist: float = o.distance_to(hp)
        if dist < best:
            best = dist
            bd = d
    return bd

# END OF FILE
