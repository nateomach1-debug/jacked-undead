extends "res://scripts/mapgen/map_gen_base.gd"
## Gym floor generator: a grid of 20 m cells, some merged into bigger rooms.
## Every link between rooms is a buyable door that unlocks the deeper room's
## zone. Stations sit on solid wall slots, spawns are tagged per zone.

@export var map_seed: int = 0          # 0 = new random map every time
@export var grid_w: int = 4
@export var grid_h: int = 3
@export var cell: float = 20.0
@export var merge_chance: float = 0.35
@export var loop_chance: float = 0.25
@export var door_width: float = 4.0

# Flip these if a station faces the wall instead of the room.
const PR_FRONT_MINUS_Z: bool = false
const LOCKER_FRONT_MINUS_Z: bool = false
const WALLBUY_FRONT_MINUS_Z: bool = true
const WATER_FRONT_MINUS_Z: bool = true

const PATH_DOOR: String = "res://scenes/stations/buy_door.tscn"
const PATH_SUPP: String = "res://scenes/stations/supplement_station.tscn"
const PATH_PR: String = "res://scenes/stations/pr_rack.tscn"
const PATH_WATER: String = "res://scenes/stations/water_station.tscn"
const PATH_BUY: String = "res://scenes/stations/gun_wall_buy.tscn"
const PATH_LOCKER: String = "res://scenes/stations/loot_locker.tscn"

const WALL_COLOR: Color = Color(0.30, 0.30, 0.34)
const FLOOR_COLORS: Array = [Color(0.36, 0.30, 0.26), Color(0.26, 0.32, 0.36), Color(0.30, 0.36, 0.28), Color(0.38, 0.28, 0.34), Color(0.34, 0.34, 0.26), Color(0.28, 0.28, 0.38)]
const ROOM_NAMES: Array = ["Weights Room", "Cardio Zone", "Locker Room", "Spin Studio", "Pool Deck", "Stretch Area", "Smoothie Bar", "Boxing Ring", "Yoga Studio", "Free Weights", "Sauna", "Squat Cage"]

const SUPPS: Array = [
    {"id": "trt", "name": "TRT", "cost": 1500, "color": Color(0.1647, 0.4235, 0.6902), "icon": "res://resources/icons/trt.svg"},
    {"id": "creatine", "name": "Creatine", "cost": 2000, "color": Color(0.867, 0.4196, 0.1255), "icon": "res://resources/icons/creatine.svg"},
    {"id": "whey", "name": "Whey Protein", "cost": 2500, "color": Color(0.4196, 0.2745, 0.7569), "icon": "res://resources/icons/whey.svg"},
    {"id": "pre_workout", "name": "Pre-Workout", "cost": 2000, "color": Color(0.8392, 0.6196, 0.1804), "icon": "res://resources/icons/pre_workout.svg"},
    {"id": "fish_oil", "name": "Fish Oil", "cost": 3000, "color": Color(0.1922, 0.5922, 0.5843), "icon": "res://resources/icons/fish_oil.svg"},
    {"id": "bcaas", "name": "BCAAs", "cost": 1500, "color": Color(0.2196, 0.6314, 0.4118), "icon": "res://resources/icons/bcaas.svg"},
    {"id": "glutamine", "name": "GLUTAMINE", "cost": 3000, "color": Color(0.6, 0.25, 0.9, 1), "icon": "res://resources/icons/glutamine.svg"},
    {"id": "collagen", "name": "COLLAGEN", "cost": 2000, "color": Color(1.0, 0.2, 0.6, 1), "icon": "res://resources/icons/collagen.svg"},
]
const GUNS: Array = [
    {"w": "res://resources/weapons/smg.tres", "m": "res://resources/models/weapons/SMG_1.gltf", "name": "SMG", "buy": 1000, "ammo": 500},
    {"w": "res://resources/weapons/rifle.tres", "m": "res://resources/models/weapons/AR_1.gltf", "name": "Rifle", "buy": 3000, "ammo": 600},
    {"w": "res://resources/weapons/crossbow.tres", "m": "res://resources/models/weapons/Crossbow_1.gltf", "name": "Crossbow", "buy": 3500, "ammo": 400},
    {"w": "res://resources/weapons/sniper.tres", "m": "res://resources/models/weapons/Sniper_1.gltf", "name": "Sniper", "buy": 5000, "ammo": 500},
]

var _n: int = 0
var _grp: PackedInt32Array = PackedInt32Array()
var _g_count: int = 0
var _start_g: int = 0
var _depth: Array = []
var _names: Array = []
var _door_off: Dictionary = {}
var _door_info: Dictionary = {}
var _doors_node: Node3D
var _stations_node: Node3D
var _spawns_node: Node3D


func _ready() -> void:
    init_seed(map_seed)
    _make_groups()
    _make_doors()
    _doors_node = _container("BuyableDoors")
    _stations_node = _container("Stations")
    _spawns_node = _container("SpawnPoints")
    begin_geometry()
    _build_floors()
    _build_walls()
    end_geometry()
    _place_player()
    _place_spawns()
    _place_stations()


func _container(node_name: String) -> Node3D:
    var c: Node3D = Node3D.new()
    c.name = node_name
    add_child(c)
    return c


func _idx(x: int, y: int) -> int:
    return y * grid_w + x


func _cell_pos(x: int, y: int) -> Vector3:
    return Vector3((x - grid_w * 0.5 + 0.5) * cell, 0.0, (y - grid_h * 0.5 + 0.5) * cell)


func _edge_key(x: int, y: int, vert: bool) -> String:
    return "%d,%d,%s" % [x, y, "v" if vert else "h"]


func _group_size(g: int) -> int:
    var k: int = 0
    for i in _n:
        if _grp[i] == g:
            k += 1
    return k


# ---------- layout ----------

func _make_groups() -> void:
    _n = grid_w * grid_h
    _grp.resize(_n)
    for i in _n:
        _grp[i] = i
    for y in grid_h:
        for x in grid_w:
            if rng.randf() >= merge_chance:
                continue
            var nx: int = x + 1
            var ny: int = y
            if rng.randf() < 0.5:
                nx = x
                ny = y + 1
            if nx >= grid_w or ny >= grid_h:
                continue
            var a: int = _grp[_idx(x, y)]
            var b: int = _grp[_idx(nx, ny)]
            if a == b or _group_size(a) + _group_size(b) > 3:
                continue
            for i in _n:
                if _grp[i] == b:
                    _grp[i] = a
    var remap: Dictionary = {}
    for i in _n:
        var old: int = _grp[i]
        if not remap.has(old):
            remap[old] = remap.size()
        _grp[i] = remap[old]
    _g_count = remap.size()
    _start_g = _grp[_idx(int(grid_w / 2.0), int(grid_h / 2.0))]
    var pool: Array = shuffled(ROOM_NAMES)
    _names = []
    for g in _g_count:
        _names.append(pool[g % pool.size()])
    _names[_start_g] = "Lobby"


func _add_pair(pairs: Dictionary, x: int, y: int, vert: bool, ga: int, gb: int) -> void:
    if ga == gb:
        return
    var lo: int = mini(ga, gb)
    var hi: int = maxi(ga, gb)
    var k: String = "%d-%d" % [lo, hi]
    if not pairs.has(k):
        pairs[k] = {"a": lo, "b": hi, "edges": []}
    pairs[k]["edges"].append([x, y, vert])


func _put_door(pair: Dictionary, g: int) -> void:
    var edges: Array = pair["edges"]
    var e: Array = edges[rng.randi() % edges.size()]
    var key: String = _edge_key(e[0], e[1], e[2])
    _door_off[key] = rng.randf_range(-4.5, 4.5)
    _door_info[key] = {"g": g, "depth": _depth[g]}


func _make_doors() -> void:
    var pairs: Dictionary = {}
    for y in grid_h:
        for x in grid_w:
            if x + 1 < grid_w:
                _add_pair(pairs, x, y, true, _grp[_idx(x, y)], _grp[_idx(x + 1, y)])
            if y + 1 < grid_h:
                _add_pair(pairs, x, y, false, _grp[_idx(x, y)], _grp[_idx(x, y + 1)])
    _depth = []
    for g in _g_count:
        _depth.append(-1)
    _depth[_start_g] = 0
    var used: Dictionary = {}
    var keys: Array = pairs.keys()
    while true:
        var cands: Array = []
        for k in keys:
            var p: Dictionary = pairs[k]
            if (_depth[p["a"]] >= 0) != (_depth[p["b"]] >= 0):
                cands.append(k)
        if cands.is_empty():
            break
        var pick: String = cands[rng.randi() % cands.size()]
        var pp: Dictionary = pairs[pick]
        var known: int = pp["a"] if _depth[pp["a"]] >= 0 else pp["b"]
        var fresh: int = pp["b"] if known == pp["a"] else pp["a"]
        _depth[fresh] = _depth[known] + 1
        _put_door(pp, fresh)
        used[pick] = true
    for k in keys:
        if used.has(k):
            continue
        if rng.randf() < loop_chance:
            var q: Dictionary = pairs[k]
            var deeper: int = q["a"] if _depth[q["a"]] >= _depth[q["b"]] else q["b"]
            _put_door(q, deeper)


# ---------- geometry ----------

func _build_floors() -> void:
    for y in grid_h:
        for x in grid_w:
            var c: Vector3 = _cell_pos(x, y)
            var col: Color = FLOOR_COLORS[_grp[_idx(x, y)] % FLOOR_COLORS.size()]
            add_solid(Vector3(c.x, -0.25, c.z), Vector3(cell, 0.5, cell), col, false)
    add_collider(Vector3(0.0, -0.5, 0.0), Vector3(grid_w * cell + 4.0, 1.0, grid_h * cell + 4.0))


func _build_walls() -> void:
    var tw: float = grid_w * cell
    var td: float = grid_h * cell
    var hh: float = WALL_H * 0.5
    add_solid(Vector3(0.0, hh, -td * 0.5), Vector3(tw + WALL_T, WALL_H, WALL_T), WALL_COLOR)
    add_solid(Vector3(0.0, hh, td * 0.5), Vector3(tw + WALL_T, WALL_H, WALL_T), WALL_COLOR)
    add_solid(Vector3(-tw * 0.5, hh, 0.0), Vector3(WALL_T, WALL_H, td + WALL_T), WALL_COLOR)
    add_solid(Vector3(tw * 0.5, hh, 0.0), Vector3(WALL_T, WALL_H, td + WALL_T), WALL_COLOR)
    for y in grid_h:
        for x in grid_w:
            var a: Vector3 = _cell_pos(x, y)
            if x + 1 < grid_w and _grp[_idx(x, y)] != _grp[_idx(x + 1, y)]:
                _wall_seg(Vector3(a.x + cell * 0.5, 0.0, a.z), true, _edge_key(x, y, true))
            if y + 1 < grid_h and _grp[_idx(x, y)] != _grp[_idx(x, y + 1)]:
                _wall_seg(Vector3(a.x, 0.0, a.z + cell * 0.5), false, _edge_key(x, y, false))


## vert = the wall runs along Z.
func _wall_seg(c: Vector3, vert: bool, key: String) -> void:
    var half: float = cell * 0.5 + WALL_T * 0.5
    if not _door_off.has(key):
        _wall_piece(c, vert, -half, half)
        return
    var off: float = _door_off[key]
    _wall_piece(c, vert, -half, off - door_width * 0.5)
    _wall_piece(c, vert, off + door_width * 0.5, half)
    var info: Dictionary = _door_info[key]
    _spawn_door(c, vert, off, info["g"], info["depth"])


func _wall_piece(c: Vector3, vert: bool, a: float, b: float) -> void:
    var seg: float = b - a
    var mid: float = (a + b) * 0.5
    if vert:
        add_solid(Vector3(c.x, WALL_H * 0.5, c.z + mid), Vector3(WALL_T, WALL_H, seg), WALL_COLOR)
    else:
        add_solid(Vector3(c.x + mid, WALL_H * 0.5, c.z), Vector3(seg, WALL_H, WALL_T), WALL_COLOR)


func _spawn_door(c: Vector3, vert: bool, off: float, g: int, depth: int) -> void:
    var d: Node3D = make_scene(PATH_DOOR)
    if d == null:
        return
    var w: float = door_width + 0.3
    if vert:
        d.set("size", Vector3(0.4, WALL_H, w))
        d.position = Vector3(c.x, 0.0, c.z + off)
    else:
        d.set("size", Vector3(w, WALL_H, 0.4))
        d.position = Vector3(c.x + off, 0.0, c.z)
    var cost: int = int(round((700.0 + depth * 450.0 + rng.randf() * 200.0) / 50.0)) * 50
    d.set("cost", cost)
    d.set("display_name", _names[g])
    d.set("unlocks_zones", PackedStringArray(["z%d" % g]))
    _doors_node.add_child(d)


# ---------- player, spawns ----------

func _place_player() -> void:
    var p: Node3D = get_node_or_null("../Player") as Node3D
    if p == null:
        return
    var c: Vector3 = _cell_pos(int(grid_w / 2.0), int(grid_h / 2.0))
    p.position = Vector3(c.x, 1.0, c.z)


func _place_spawns() -> void:
    var n: int = 0
    for y in grid_h:
        for x in grid_w:
            var g: int = _grp[_idx(x, y)]
            var c: Vector3 = _cell_pos(x, y)
            for i in 2:
                var off: Vector3
                if g == _start_g:
                    off = Vector3(6.5 if i == 0 else -6.5, 0.0, 6.5 if rng.randf() < 0.5 else -6.5)
                else:
                    off = Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(-6.0, 6.0))
                var m: Marker3D = Marker3D.new()
                m.name = "Spawn%d" % n
                n += 1
                m.position = c + off + Vector3(0.0, 1.0, 0.0)
                m.add_to_group("spawn_points")
                if g != _start_g:
                    m.set_meta("zone", "z%d" % g)
                _spawns_node.add_child(m)


# ---------- stations ----------

func _collect_slots() -> Array:
    var slots: Array = []
    for g in _g_count:
        slots.append([])
    var dirs: Array = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
    for y in grid_h:
        for x in grid_w:
            var g: int = _grp[_idx(x, y)]
            var c: Vector3 = _cell_pos(x, y)
            for d in dirs:
                var nx: int = x + int(d.x)
                var ny: int = y + int(d.z)
                if nx >= 0 and nx < grid_w and ny >= 0 and ny < grid_h:
                    if _grp[_idx(nx, ny)] == g:
                        continue
                    if _door_off.has(_edge_key(mini(x, nx), mini(y, ny), d.x != 0.0)):
                        continue
                for t in [-6.0, 0.0, 6.0]:
                    slots[g].append({"c": c, "d": d, "t": t})
    return slots


func _pop_slot(g: int, slots: Array) -> Dictionary:
    if not slots[g].is_empty():
        return slots[g].pop_back()
    for h in _g_count:
        if not slots[h].is_empty():
            return slots[h].pop_back()
    return {}


func _put(kind: String, i: int, g: int, slots: Array) -> void:
    var s: Dictionary = _pop_slot(g, slots)
    if s.is_empty():
        push_warning("MapGen: no free wall slot for " + kind)
        return
    var n: Node3D = null
    var inset: float = 0.5
    var y: float = 0.0
    var minus_z: bool = true
    if kind == "supp":
        var sp: Dictionary = SUPPS[i]
        n = make_scene(PATH_SUPP)
        if n == null:
            return
        n.set("supplement_id", sp["id"])
        n.set("display_name", sp["name"])
        n.set("cost", sp["cost"])
        n.set("body_color", sp["color"])
        n.set("icon_texture", load(sp["icon"]))
        y = 0.9
    elif kind == "gun":
        var gd: Dictionary = GUNS[i]
        n = make_scene(PATH_BUY)
        if n == null:
            return
        n.set("weapon", load(gd["w"]))
        n.set("display_model", load(gd["m"]))
        n.set("display_name", gd["name"])
        n.set("buy_cost", gd["buy"])
        n.set("ammo_cost", gd["ammo"])
        inset = 0.0
        y = 1.0
        minus_z = WALLBUY_FRONT_MINUS_Z
    elif kind == "pr":
        n = make_scene(PATH_PR)
        inset = 1.0
        minus_z = PR_FRONT_MINUS_Z
    elif kind == "locker":
        n = make_scene(PATH_LOCKER)
        minus_z = LOCKER_FRONT_MINUS_Z
    elif kind == "water":
        n = make_scene(PATH_WATER)
        minus_z = WATER_FRONT_MINUS_Z
    if n == null:
        return
    var d: Vector3 = s["d"]
    var tangent: Vector3 = Vector3(d.z, 0.0, d.x)
    var pos: Vector3 = s["c"] + tangent * float(s["t"]) + d * (cell * 0.5 - WALL_T * 0.5 - inset)
    pos.y = y
    n.position = pos
    n.rotation.y = yaw_facing(-d, minus_z)
    _stations_node.add_child(n)


func _place_stations() -> void:
    var slots: Array = _collect_slots()
    for g in _g_count:
        slots[g] = shuffled(slots[g])
    var order: Array = []
    for g in _g_count:
        if g != _start_g:
            order.append(g)
    order.sort_custom(func(a, b): return _depth[a] > _depth[b])
    if order.is_empty():
        return
    # Lobby: an SMG and water so the first rounds are playable.
    _put("gun", 0, _start_g, slots)
    _put("water", 0, _start_g, slots)
    # The two deepest rooms get the PR Rack and the sniper.
    _put("pr", 0, order[0], slots)
    _put("gun", 3, order[1 % order.size()], slots)
    var pool: Array = [{"k": "locker", "i": 0}, {"k": "gun", "i": 1}, {"k": "gun", "i": 2}, {"k": "water", "i": 0}]
    for i in SUPPS.size():
        pool.append({"k": "supp", "i": i})
    pool = shuffled(pool)
    var rooms: Array = shuffled(order)
    var r: int = 0
    for it in pool:
        _put(it["k"], it["i"], rooms[r % rooms.size()], slots)
        r += 1

# END OF FILE
