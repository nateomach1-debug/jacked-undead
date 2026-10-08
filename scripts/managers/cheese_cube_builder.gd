extends Node3D
## Builds the Cheese Cube map in code: a sealed square room with a staircase
## spiralling up the inside of the walls, buyable doors, perks and the PR Rack.
## Everything under "Geometry" feeds the runtime nav bake (NavBaker).
## Room runs x/z -20..20 inside; z+ is "south". Landing k is at height 3*k.

const HALF: float = 20.0
const WALL_H: float = 32.0
const WALL_T: float = 1.0
const LANE: float = 4.0
const RISE: float = 3.0
const SLAB: float = 0.5
const RAIL_H: float = 1.4
const RAIL_T: float = 0.4
const STATION_Y: float = 0.9
const FLIGHTS: int = 8

# Stair corners in order: SW, SE, NE, NW (x sign, z sign)
const CORNERS: Array = [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]
# Landing sizes for landings 0..8 (0 = floor start, 5 = PR platform, 8 = summit)
const LANDING_SIZE: Array = [8.0, 4.0, 4.0, 4.0, 4.0, 8.0, 4.0, 4.0, 8.0]

const FLOOR_COL := Color(0.35, 0.35, 0.38)
const WALL_COL := Color(0.8, 0.8, 0.76)
const CHEESE := Color(0.96, 0.78, 0.22)
const TREAD_COL := Color(0.75, 0.5, 0.1)
const RAIL_COL := Color(0.2, 0.2, 0.24)
const DOOR_COL := Color(0.5, 0.15, 0.12)

var _geo: Node3D
var _decor: Node3D
var _mats: Dictionary = {}
var _f_start: Array[Vector3] = []
var _f_end: Array[Vector3] = []
var _f_in: Array[Vector2] = []


func _ready() -> void:
    _geo = Node3D.new()
    _geo.name = "Geometry"
    add_child(_geo)
    _geo.add_to_group("navmesh_source")
    _decor = Node3D.new()
    _decor.name = "Decor"
    add_child(_decor)
    _build_shell()
    _build_stairs()
    _build_doors()
    _build_stations()
    _build_lights()


# ---------------------------------------------------------------- helpers

func _material(color: Color) -> StandardMaterial3D:
    var key: String = color.to_html()
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.9
    _mats[key] = m
    return m


func _solid(xform: Transform3D, size: Vector3, color: Color) -> void:
    var body := StaticBody3D.new()
    body.transform = xform
    _geo.add_child(body)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = _material(color)
    body.add_child(mi)


func _box(center: Vector3, size: Vector3, color: Color) -> void:
    _solid(Transform3D(Basis.IDENTITY, center), size, color)


func _flight_basis(a: Vector3, b: Vector3) -> Basis:
    var x_axis: Vector3 = (b - a).normalized()
    var z_axis: Vector3 = x_axis.cross(Vector3.UP).normalized()
    var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
    return Basis(x_axis, y_axis, z_axis)


## Tilted slab whose TOP surface runs from a to b.
func _slab(a: Vector3, b: Vector3, width: float, color: Color) -> void:
    var basis: Basis = _flight_basis(a, b)
    var center: Vector3 = (a + b) * 0.5 - basis.y * (SLAB * 0.5)
    _solid(Transform3D(basis, center), Vector3(a.distance_to(b), SLAB, width), color)


## Thin tread lines across a flight (visual only, not baked).
func _treads(a: Vector3, b: Vector3) -> void:
    var basis: Basis = _flight_basis(a, b)
    var count: int = int(a.distance_to(b))
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var bm := BoxMesh.new()
    bm.size = Vector3(0.12, 0.03, LANE - 0.6)
    mm.mesh = bm
    mm.instance_count = count
    for i in range(count):
        var p: Vector3 = a + basis.x * (float(i) + 0.5) + basis.y * 0.015
        mm.set_instance_transform(i, Transform3D(basis, p))
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = _material(TREAD_COL)
    _decor.add_child(mmi)


func _yaw_front_pos_z(dir: Vector2) -> float:
    return atan2(dir.x, dir.y)


func _yaw_front_neg_z(dir: Vector2) -> float:
    return atan2(-dir.x, -dir.y)


func _corner_pos(k: int, extra_y: float) -> Vector3:
    var c: Vector2 = CORNERS[k % 4]
    return Vector3(c.x * 18.8, RISE * float(k) + extra_y, c.y * 18.8)


func _corner_face(k: int) -> Vector2:
    var c: Vector2 = CORNERS[k % 4]
    return Vector2(-c.x, -c.y)


func _place(path: String, node_name: String, pos: Vector3, yaw: float, props: Dictionary) -> void:
    var scene: PackedScene = load(path) as PackedScene
    if scene == null:
        push_warning("CheeseCube: could not load " + path)
        return
    var node: Node3D = scene.instantiate() as Node3D
    if node == null:
        return
    node.name = node_name
    for key in props.keys():
        node.set(key, props[key])
    node.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
    add_child(node)


# ---------------------------------------------------------------- room

func _build_shell() -> void:
    var span: float = HALF * 2.0 + WALL_T * 2.0
    var off: float = HALF + WALL_T * 0.5
    _box(Vector3(0, -0.5, 0), Vector3(span, 1.0, span), FLOOR_COL)
    _box(Vector3(0, WALL_H * 0.5, off), Vector3(span, WALL_H, WALL_T), WALL_COL)
    _box(Vector3(0, WALL_H * 0.5, -off), Vector3(span, WALL_H, WALL_T), WALL_COL)
    _box(Vector3(off, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, span), WALL_COL)
    _box(Vector3(-off, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, span), WALL_COL)
    # ceiling: visual only, kept out of the nav bake
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(span, WALL_T, span)
    mi.mesh = bm
    mi.material_override = _material(WALL_COL)
    mi.position = Vector3(0, WALL_H + WALL_T * 0.5, 0)
    _decor.add_child(mi)


func _build_lights() -> void:
    for y in [6.0, 14.0, 22.0, 29.0]:
        var l := OmniLight3D.new()
        l.position = Vector3(0.0, y, 0.0)
        l.omni_range = 34.0
        l.light_energy = 1.6
        l.shadow_enabled = false
        add_child(l)


# ---------------------------------------------------------------- stairs

func _build_stairs() -> void:
    for k in range(FLIGHTS + 1):
        _landing(k)
    for k in range(FLIGHTS):
        _compute_flight(k)
    for k in range(FLIGHTS):
        _slab(_f_start[k], _f_end[k], LANE, CHEESE)
        _treads(_f_start[k], _f_end[k])
        _rails(k)
    _landing_rails()


func _landing(k: int) -> void:
    if k == 0:
        return  # landing 0 is just the floor
    var s: float = LANDING_SIZE[k]
    var c: Vector2 = CORNERS[k % 4]
    var cx: float = c.x * (HALF - s * 0.5)
    var cz: float = c.y * (HALF - s * 0.5)
    _box(Vector3(cx, RISE * float(k) - SLAB * 0.5, cz), Vector3(s, SLAB, s), CHEESE)


func _compute_flight(k: int) -> void:
    var a: Vector2 = CORNERS[k % 4]
    var b: Vector2 = CORNERS[(k + 1) % 4]
    var dir: Vector2 = (b - a) * 0.5
    var lane: float = HALF - LANE * 0.5
    var sa: float = LANDING_SIZE[k]
    var sb: float = LANDING_SIZE[k + 1]
    var p0: Vector2 = a * lane + dir * (sa - LANE * 0.5)
    var p1: Vector2 = b * lane - dir * (sb - LANE * 0.5)
    var inward: Vector2 = Vector2(-dir.y, dir.x)
    if inward.dot(a) > 0.0:
        inward = -inward
    _f_start.append(Vector3(p0.x, RISE * float(k), p0.y))
    _f_end.append(Vector3(p1.x, RISE * float(k + 1), p1.y))
    _f_in.append(inward)


## Inner-edge railing. Lap 1 (flights 0-3) is a solid wall down to the floor
## so nobody can hide under the stairs; lap 2 is a plain railing.
func _rails(k: int) -> void:
    var s: Vector3 = _f_start[k]
    var e: Vector3 = _f_end[k]
    var n: Vector2 = _f_in[k]
    var along_x: bool = absf(n.y) > 0.5
    var run: float = Vector2(e.x - s.x, e.z - s.z).length()
    var segs: int = int(ceil(run / 2.0))
    var seg_len: float = run / float(segs)
    for i in range(segs):
        var p0: Vector3 = s.lerp(e, float(i) / float(segs))
        var p1: Vector3 = s.lerp(e, float(i + 1) / float(segs))
        var mid: Vector3 = (p0 + p1) * 0.5
        var top: float = maxf(p0.y, p1.y) + RAIL_H
        var bottom: float = minf(p0.y, p1.y) - 0.3
        if k < 4 and not (k == 3 and mid.z > 12.0):
            bottom = 0.0
        var h: float = top - bottom
        var cx: float = mid.x + n.x * (LANE * 0.5 - RAIL_T * 0.5)
        var cz: float = mid.z + n.y * (LANE * 0.5 - RAIL_T * 0.5)
        var size: Vector3 = Vector3(RAIL_T, h, seg_len + 0.02)
        if along_x:
            size = Vector3(seg_len + 0.02, h, RAIL_T)
        _box(Vector3(cx, bottom + h * 0.5, cz), size, RAIL_COL)


func _landing_rails() -> void:
    # corner posts on the small landings so there is no diagonal gap
    for k in [1, 2, 3, 4, 6, 7]:
        var kk: int = k
        var c: Vector2 = CORNERS[kk % 4]
        var y: float = RISE * float(kk)
        _box(Vector3(c.x * 16.2, y + RAIL_H * 0.5, c.y * 16.2), Vector3(RAIL_T, RAIL_H, RAIL_T), RAIL_COL)
    # PR platform (landing 5): open inner edges
    var y5: float = RISE * 5.0
    _box(Vector3(12.2, y5 + RAIL_H * 0.5, 14.2), Vector3(RAIL_T, RAIL_H, 4.4), RAIL_COL)
    _box(Vector3(14.2, y5 + RAIL_H * 0.5, 12.2), Vector3(4.4, RAIL_H, RAIL_T), RAIL_COL)
    # summit (landing 8): open inner edges
    var y8: float = RISE * 8.0
    _box(Vector3(-14.2, y8 + RAIL_H * 0.5, 12.2), Vector3(4.4, RAIL_H, RAIL_T), RAIL_COL)
    _box(Vector3(-12.2, y8 + RAIL_H * 0.5, 16.0), Vector3(RAIL_T, RAIL_H, 8.0), RAIL_COL)
    # closes the gap under the end of flight 3, next to the start landing
    _box(Vector3(-18.0, 5.8, 12.2), Vector3(4.0, 11.6, RAIL_T), RAIL_COL)


# ---------------------------------------------------------------- doors

func _build_doors() -> void:
    _door(0, 0.07, "Gym Gate", 750, "lap1", "DoorLap1")
    _door(3, 0.93, "Locker Room Gate", 1500, "lap2", "DoorLap2")
    _door(6, 0.93, "Summit Gate", 2500, "summit", "DoorSummit")


func _door(k: int, t: float, label: String, cost: int, zone: String, node_name: String) -> void:
    var p: Vector3 = _f_start[k].lerp(_f_end[k], t)
    var along_x: bool = absf(_f_in[k].y) > 0.5
    var size: Vector3 = Vector3(LANE, 5.0, 0.4)
    if along_x:
        size = Vector3(0.4, 5.0, LANE)
    _place("res://scenes/stations/buy_door.tscn", node_name, p, 0.0, {
        "size": size,
        "cost": cost,
        "display_name": label,
        "unlocks_zones": PackedStringArray([zone]),
        "color": DOOR_COL,
    })


# ---------------------------------------------------------------- stations

func _supplement(k: int, id: String, label: String, cost: int, color: Color) -> void:
    var tex: Texture2D = load("res://resources/icons/%s.svg" % id) as Texture2D
    _place("res://scenes/stations/supplement_station.tscn", "Sup_" + id,
        _corner_pos(k, STATION_Y), _yaw_front_pos_z(_corner_face(k)), {
            "supplement_id": id,
            "display_name": label,
            "cost": cost,
            "body_color": color,
            "icon_texture": tex,
        })


func _build_stations() -> void:
    # start floor
    _place("res://scenes/stations/water_station.tscn", "WaterFloor", Vector3(6, 0, 6), 0.0, {})
    _place("res://scenes/stations/loot_locker.tscn", "LootLocker", Vector3(0, 0, -15.3), 0.0, {})
    _place("res://scenes/stations/gun_wall_buy.tscn", "SMGWallBuy", Vector3(-19.8, 1.0, 14.0),
        _yaw_front_neg_z(Vector2(1, 0)), {
            "weapon": load("res://resources/weapons/smg.tres"),
            "display_model": load("res://resources/models/weapons/SMG_1.gltf"),
            "display_name": "SMG",
            "buy_cost": 1000,
            "ammo_cost": 500,
        })
    _place("res://scenes/stations/gun_wall_buy.tscn", "RifleWallBuy", Vector3(-15.0, 1.0, 19.8),
        _yaw_front_neg_z(Vector2(0, -1)), {
            "weapon": load("res://resources/weapons/rifle.tres"),
            "display_model": load("res://resources/models/weapons/AR_1.gltf"),
            "display_name": "Rifle",
            "buy_cost": 3000,
            "ammo_cost": 600,
        })
    # perks up the stairs
    _supplement(1, "trt", "TRT", 1500, Color(0.1647, 0.4235, 0.6902))
    _supplement(2, "creatine", "Creatine", 2000, Color(0.867, 0.4196, 0.1255))
    _place("res://scenes/stations/water_station.tscn", "WaterL3", _corner_pos(3, 0.0),
        _yaw_front_pos_z(_corner_face(3)), {})
    _supplement(4, "pre_workout", "Pre-Workout", 2000, Color(0.8392, 0.6196, 0.1804))
    _place("res://scenes/stations/pr_rack.tscn", "PRRack", Vector3(14.0, RISE * 5.0, 14.0),
        _yaw_front_pos_z(Vector2(1, 1)), {})
    _supplement(6, "whey", "Whey Protein", 2500, Color(0.4196, 0.2745, 0.7569))
    _supplement(7, "bcaas", "BCAAs", 1500, Color(0.2196, 0.6314, 0.4118))
    _supplement(8, "fish_oil", "Fish Oil", 3000, Color(0.1922, 0.5922, 0.5843))
