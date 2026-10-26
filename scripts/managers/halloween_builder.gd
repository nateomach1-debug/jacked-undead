extends Node3D
## Builds the limited-time Halloween map in code: a walled graveyard.
## South (z+): start plaza with a pumpkin patch. Middle: the graveyard.
## North: haunted house (west) and crypt maze (east), split by a mausoleum block.
## Everything under "Geometry" feeds the runtime nav bake (NavBaker).
## The map runs x/z -32..32 inside; z+ is "south" (where you start).

const HALF: float = 32.0
const WALL_H: float = 6.0
const INNER_H: float = 5.0
const WALL_T: float = 1.0
const GATE_Z: float = 8.0
const NORTH_Z: float = -12.0
const STATION_Y: float = 0.9

const GROUND_COL := Color(0.13, 0.15, 0.12)
const FENCE_COL := Color(0.10, 0.09, 0.12)
const WALL_COL := Color(0.19, 0.17, 0.22)
const PATH_COL := Color(0.30, 0.30, 0.32)
const STONE_COL := Color(0.42, 0.42, 0.45)
const TOMB_COL := Color(0.36, 0.37, 0.40)
const WOOD_COL := Color(0.30, 0.19, 0.10)
const CRYPT_FLOOR_COL := Color(0.17, 0.17, 0.21)
const ROOF_COL := Color(0.08, 0.07, 0.10)
const BARK_COL := Color(0.16, 0.11, 0.08)
const PUMPKIN_COL := Color(0.95, 0.42, 0.05)
const STEM_COL := Color(0.25, 0.35, 0.10)
const GLOW_COL := Color(1.0, 0.75, 0.2)
const HAY_COL := Color(0.72, 0.58, 0.22)
const COFFIN_COL := Color(0.22, 0.12, 0.08)
const DOOR_COL := Color(0.38, 0.10, 0.48)

var _geo: Node3D
var _decor: Node3D
var _mats: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
    _rng.seed = 1031   # same decor on every phone
    _geo = Node3D.new()
    _geo.name = "Geometry"
    add_child(_geo)
    _geo.add_to_group("navmesh_source")
    _decor = Node3D.new()
    _decor.name = "Decor"
    add_child(_decor)
    _build_shell()
    _build_dividers()
    _build_house()
    _build_crypt()
    _build_graveyard()
    _build_plaza()
    _build_doors()
    _build_stations()
    _build_signs()
    _build_lights()
    _build_costumes()


# ---------------------------------------------------------------- helpers

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
    var key: String = "%s_%.2f" % [color.to_html(), glow]
    if _mats.has(key):
        return _mats[key]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.9
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    _mats[key] = m
    return m


## Solid box (collision + mesh) under Geometry, so it is baked into the navmesh.
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


func _solid_cyl(center: Vector3, radius: float, height: float, color: Color) -> void:
    var body := StaticBody3D.new()
    body.position = center
    _geo.add_child(body)
    var shape := CollisionShape3D.new()
    var cyl := CylinderShape3D.new()
    cyl.radius = radius
    cyl.height = height
    shape.shape = cyl
    body.add_child(shape)
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = radius * 0.7
    cm.bottom_radius = radius
    cm.height = height
    cm.radial_segments = 8
    mi.mesh = cm
    mi.material_override = _material(color)
    body.add_child(mi)


func _wall_x(x0: float, x1: float, z: float, h: float, color: Color) -> void:
    _box(Vector3((x0 + x1) * 0.5, h * 0.5, z), Vector3(x1 - x0, h, WALL_T), color)


func _wall_z(z0: float, z1: float, x: float, h: float, color: Color) -> void:
    _box(Vector3(x, h * 0.5, (z0 + z1) * 0.5), Vector3(WALL_T, h, z1 - z0), color)


func _deco(mesh: Mesh, pos: Vector3, color: Color, glow: float, basis: Basis, parent: Node3D) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = _material(color, glow)
    mi.transform = Transform3D(basis, pos)
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    (parent if parent != null else _decor).add_child(mi)
    return mi


## Decoration only (no collision, not baked into the navmesh).
func _deco_box(pos: Vector3, size: Vector3, color: Color, glow: float = 0.0, basis: Basis = Basis.IDENTITY, parent: Node3D = null) -> MeshInstance3D:
    var bm := BoxMesh.new()
    bm.size = size
    return _deco(bm, pos, color, glow, basis, parent)


func _deco_cyl(pos: Vector3, top_r: float, bottom_r: float, height: float, color: Color, glow: float = 0.0, basis: Basis = Basis.IDENTITY, parent: Node3D = null) -> MeshInstance3D:
    var cm := CylinderMesh.new()
    cm.top_radius = top_r
    cm.bottom_radius = bottom_r
    cm.height = height
    cm.radial_segments = 10
    cm.rings = 1
    return _deco(cm, pos, color, glow, basis, parent)


func _deco_sphere(pos: Vector3, radius: float, color: Color, glow: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
    var sm := SphereMesh.new()
    sm.radius = radius
    sm.height = radius * 2.0
    sm.radial_segments = 12
    sm.rings = 6
    return _deco(sm, pos, color, glow, Basis.IDENTITY, parent)


func _yaw_front_pos_z(dir: Vector2) -> float:
    return atan2(dir.x, dir.y)


func _yaw_front_neg_z(dir: Vector2) -> float:
    return atan2(-dir.x, -dir.y)


func _place(path: String, node_name: String, pos: Vector3, yaw: float, props: Dictionary) -> void:
    var scene: PackedScene = load(path) as PackedScene
    if scene == null:
        push_warning("Halloween: could not load " + path)
        return
    var node: Node3D = scene.instantiate() as Node3D
    if node == null:
        return
    node.name = node_name
    for key in props.keys():
        node.set(key, props[key])
    node.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
    add_child(node)


# ---------------------------------------------------------------- shell

func _build_shell() -> void:
    var span: float = HALF * 2.0 + WALL_T * 2.0
    var off: float = HALF + WALL_T * 0.5
    _box(Vector3(0, -0.5, 0), Vector3(span, 1.0, span), GROUND_COL)
    _box(Vector3(0, WALL_H * 0.5, off), Vector3(span, WALL_H, WALL_T), FENCE_COL)
    _box(Vector3(0, WALL_H * 0.5, -off), Vector3(span, WALL_H, WALL_T), FENCE_COL)
    _box(Vector3(off, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, span), FENCE_COL)
    _box(Vector3(-off, WALL_H * 0.5, 0), Vector3(WALL_T, WALL_H, span), FENCE_COL)

    # Iron spikes along the top of the outer fence
    var i: float = -31.0
    while i <= 31.0:
        for p in [Vector3(i, WALL_H + 0.4, off), Vector3(i, WALL_H + 0.4, -off),
                Vector3(off, WALL_H + 0.4, i), Vector3(-off, WALL_H + 0.4, i)]:
            _deco_box(p, Vector3(0.14, 0.8, 0.14), FENCE_COL)
        i += 3.0

    # Stone path from the plaza to the mausoleum
    _deco_box(Vector3(0, 0.03, 10.25), Vector3(4.5, 0.06, 43.5), PATH_COL)

    # The moon
    _deco_sphere(Vector3(-30, 42, -75), 7.0, Color(1.0, 0.95, 0.7), 2.0)


func _build_dividers() -> void:
    # Gate wall between the plaza and the graveyard (gap x -6..6 is the gate)
    _wall_x(-HALF, -6.0, GATE_Z, INNER_H, WALL_COL)
    _wall_x(6.0, HALF, GATE_Z, INNER_H, WALL_COL)
    # North wall of the graveyard (gaps x -20..-12 house door, x 12..20 crypt door)
    _wall_x(-HALF, -20.0, NORTH_Z, INNER_H, WALL_COL)
    _wall_x(-12.0, -6.0, NORTH_Z, INNER_H, WALL_COL)
    _wall_x(6.0, 12.0, NORTH_Z, INNER_H, WALL_COL)
    _wall_x(20.0, HALF, NORTH_Z, INNER_H, WALL_COL)
    # Mausoleum block between the house and the crypt
    _box(Vector3(0, 3.5, -21.75), Vector3(12.0, 7.0, 20.5), WALL_COL)
    for x in [-5.5, 5.5]:
        _deco_box(Vector3(x, 3.5, -11.35), Vector3(0.8, 7.0, 0.3), STONE_COL)
    _deco_box(Vector3(0, 7.3, -11.6), Vector3(12.6, 0.6, 0.9), STONE_COL)


# ---------------------------------------------------------------- haunted house

func _build_house() -> void:
    # Inner wall with a doorway (x -24..-16)
    _wall_x(-HALF, -24.0, -22.0, INNER_H, WALL_COL)
    _wall_x(-16.0, -6.0, -22.0, INNER_H, WALL_COL)
    # Floor, roof, chimney
    _deco_box(Vector3(-19, 0.03, -22), Vector3(26, 0.06, 20), WOOD_COL)
    _deco_box(Vector3(-19, 5.5, -22), Vector3(26, 1.0, 20), ROOF_COL)
    _deco_box(Vector3(-10, 7.5, -26), Vector3(1.4, 3.0, 1.4), WALL_COL)
    # Bookshelves
    _box(Vector3(-10, 1.5, -21.1), Vector3(4.0, 3.0, 0.6), WOOD_COL)
    _box(Vector3(-28, 1.5, -22.7), Vector3(4.0, 3.0, 0.6), WOOD_COL)
    # Tables with candles
    for z in [-17.0, -27.0]:
        _box(Vector3(-14, 0.45, z), Vector3(3.0, 0.9, 1.5), WOOD_COL)
        _deco_cyl(Vector3(-14, 1.05, z), 0.05, 0.05, 0.3, Color(0.95, 0.9, 0.7), 0.0)
        _deco_sphere(Vector3(-14, 1.27, z), 0.07, GLOW_COL, 4.0)


# ---------------------------------------------------------------- crypt

func _build_crypt() -> void:
    # S-shaped maze: in at x 12..20, east gap at z -18, west gap at z -24
    _wall_x(6.0, 24.0, -18.0, INNER_H, WALL_COL)
    _wall_x(14.0, HALF, -24.0, INNER_H, WALL_COL)
    _deco_box(Vector3(19, 0.03, -22), Vector3(26, 0.06, 20), CRYPT_FLOOR_COL)
    _deco_box(Vector3(19, 5.5, -22), Vector3(26, 1.0, 20), ROOF_COL)
    # Coffins and candles
    _box(Vector3(9, 0.35, -15.2), Vector3(1.0, 0.7, 2.4), COFFIN_COL)
    _box(Vector3(28, 0.35, -21.0), Vector3(1.0, 0.7, 2.4), COFFIN_COL)
    _deco_sphere(Vector3(9, 0.85, -14.2), 0.07, GLOW_COL, 4.0)
    _deco_sphere(Vector3(28, 0.85, -20.0), 0.07, GLOW_COL, 4.0)
    # Skull pile in the last chamber
    for p in [Vector3(8, 0.15, -30.5), Vector3(9.2, 0.15, -29.8), Vector3(8.6, 0.4, -30.1)]:
        _deco_sphere(p, 0.22, Color(0.88, 0.86, 0.78))


# ---------------------------------------------------------------- graveyard

func _build_graveyard() -> void:
    # Tombstone rows (the middle walkway stays open)
    for z in [-6.5, -1.0, 4.5]:
        for x in [-27.0, -21.0, -15.0, -9.0, 9.0, 15.0, 21.0, 27.0]:
            _tombstone(Vector3(x + _rng.randf_range(-0.8, 0.8), 0.0, z + _rng.randf_range(-0.5, 0.5)),
                    _rng.randf_range(-0.2, 0.2))
    # Dead trees
    for p in [Vector3(-29, 0, 6.5), Vector3(29, 0, 6.5), Vector3(-29, 0, -8), Vector3(-12, 0, 6.5),
            Vector3(12, 0, 6.5), Vector3(-19, 0, -9), Vector3(19, 0, -9)]:
        _tree(p, _rng.randf_range(4.5, 6.5))
    # Lantern posts along the path
    for z in [24.0, 14.0, 3.0, -6.0]:
        for x in [-3.8, 3.8]:
            _lantern(Vector3(x, 0, z))


func _tombstone(pos: Vector3, yaw: float) -> void:
    var b := Basis(Vector3.UP, yaw)
    _solid(Transform3D(b, pos + Vector3(0, 0.8, 0)), Vector3(1.1, 1.6, 0.35), TOMB_COL)
    var cap_basis: Basis = b * Basis(Vector3.RIGHT, PI * 0.5)
    _deco_cyl(pos + Vector3(0, 1.6, 0), 0.55, 0.55, 0.35, TOMB_COL, 0.0, cap_basis)


func _tree(pos: Vector3, h: float) -> void:
    _solid_cyl(Vector3(pos.x, h * 0.5, pos.z), 0.3, h, BARK_COL)
    for i in range(4):
        var a: float = float(i) * TAU / 4.0 + _rng.randf_range(0.0, 1.0)
        var dir := Vector3(cos(a), 0.9, sin(a)).normalized()
        var start := Vector3(pos.x, h * (0.6 + 0.1 * float(i)), pos.z)
        var length: float = _rng.randf_range(1.6, 2.6)
        var y_axis: Vector3 = dir
        var x_axis: Vector3 = y_axis.cross(Vector3.FORWARD).normalized()
        var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
        _deco_cyl(start + dir * length * 0.5, 0.03, 0.12, length, BARK_COL, 0.0, Basis(x_axis, y_axis, z_axis))


func _lantern(pos: Vector3) -> void:
    _deco_cyl(pos + Vector3(0, 1.2, 0), 0.06, 0.09, 2.4, FENCE_COL)
    _deco_sphere(pos + Vector3(0, 2.55, 0), 0.2, GLOW_COL, 3.5)


# ---------------------------------------------------------------- plaza

func _build_plaza() -> void:
    # Pumpkin patch
    for i in range(16):
        var r: float = _rng.randf_range(0.35, 0.7)
        _pumpkin(Vector3(_rng.randf_range(10.0, 30.0), 0.0, _rng.randf_range(18.0, 30.0)), r, i % 3 == 0)
    for p in [Vector3(14, 0, 22), Vector3(25, 0, 27), Vector3(19, 0, 19)]:
        _pumpkin(p, 0.95, true)
    # Hay bales
    for p in [Vector3(-27, 0.45, 26), Vector3(-25.5, 0.45, 27.3), Vector3(-27.5, 0.45, 24.6)]:
        _deco_box(p, Vector3(1.4, 0.9, 1.0), HAY_COL)
    # A few dead trees
    for p in [Vector3(-29, 0, 12), Vector3(29, 0, 11.5), Vector3(-10, 0, 29)]:
        _tree(p, _rng.randf_range(4.5, 6.0))


func _pumpkin(pos: Vector3, r: float, lit: bool) -> void:
    var root := Node3D.new()
    root.position = pos + Vector3(0, r * 0.8, 0)
    root.rotation.y = _rng.randf_range(0.0, TAU)
    root.scale = Vector3(1.0, 0.8, 1.0)
    _decor.add_child(root)
    _deco_sphere(Vector3.ZERO, r, PUMPKIN_COL, 0.6 if lit else 0.0, root)
    _deco_box(Vector3(0, r * 0.98, 0), Vector3(r * 0.18, r * 0.35, r * 0.18), STEM_COL, 0.0, Basis.IDENTITY, root)
    if lit:
        var eye_basis := Basis(Vector3(0, 0, 1), PI * 0.25)
        for side in [-1.0, 1.0]:
            _deco_box(Vector3(side * r * 0.35, r * 0.2, r * 0.88), Vector3(r * 0.28, r * 0.28, r * 0.12), GLOW_COL, 3.0, eye_basis, root)
        _deco_box(Vector3(0, -r * 0.3, r * 0.88), Vector3(r * 0.8, r * 0.18, r * 0.12), GLOW_COL, 3.0, Basis.IDENTITY, root)


# ---------------------------------------------------------------- doors and stations

func _build_doors() -> void:
    _door("Cemetery Gate", 750, "graveyard", "DoorGraveyard", Vector3(0, 0, GATE_Z), 12.0)
    _door("Haunted House", 1500, "house", "DoorHouse", Vector3(-16, 0, NORTH_Z), 8.0)
    _door("The Crypt", 2500, "crypt", "DoorCrypt", Vector3(16, 0, NORTH_Z), 8.0)


func _door(label: String, cost: int, zone: String, node_name: String, pos: Vector3, width: float) -> void:
    _place("res://scenes/stations/buy_door.tscn", node_name, pos, 0.0, {
        "size": Vector3(width, 5.0, 0.4),
        "cost": cost,
        "display_name": label,
        "unlocks_zones": PackedStringArray([zone]),
        "color": DOOR_COL,
    })


func _supplement(id: String, label: String, cost: int, color: Color, pos: Vector3, face: Vector2) -> void:
    var tex: Texture2D = load("res://resources/icons/%s.svg" % id) as Texture2D
    _place("res://scenes/stations/supplement_station.tscn", "Sup_" + id,
        pos, _yaw_front_pos_z(face), {
            "supplement_id": id,
            "display_name": label,
            "cost": cost,
            "body_color": color,
            "icon_texture": tex,
        })


func _build_stations() -> void:
    # Start plaza
    _place("res://scenes/stations/water_station.tscn", "WaterFloor", Vector3(24, 0, 14), 0.0, {})
    _place("res://scenes/stations/loot_locker.tscn", "LootLocker", Vector3(-20, 0, 9.4), 0.0, {})
    _place("res://scenes/stations/gun_wall_buy.tscn", "SMGWallBuy", Vector3(-31.8, 1.0, 20.0),
        _yaw_front_neg_z(Vector2(1, 0)), {
            "weapon": load("res://resources/weapons/smg.tres"),
            "display_model": load("res://resources/models/weapons/SMG_1.gltf"),
            "display_name": "SMG",
            "buy_cost": 1000,
            "ammo_cost": 500,
        })
    _place("res://scenes/stations/gun_wall_buy.tscn", "RifleWallBuy", Vector3(-20, 1.0, 31.8),
        _yaw_front_neg_z(Vector2(0, -1)), {
            "weapon": load("res://resources/weapons/rifle.tres"),
            "display_model": load("res://resources/models/weapons/AR_1.gltf"),
            "display_name": "Rifle",
            "buy_cost": 3000,
            "ammo_cost": 600,
        })
    # Graveyard
    _supplement("trt", "TRT", 1500, Color(0.1647, 0.4235, 0.6902), Vector3(-31.2, STATION_Y, -4), Vector2(1, 0))
    _supplement("creatine", "Creatine", 2000, Color(0.867, 0.4196, 0.1255), Vector3(31.2, STATION_Y, -4), Vector2(-1, 0))
    _place("res://scenes/stations/pr_rack.tscn", "PRRack", Vector3(3.2, 0, -11.0), 0.0, {})
    _place("res://scenes/stations/loot_locker.tscn", "LootLockerGrave", Vector3(-3.2, 0, -11.0), 0.0, {})
    _place("res://scenes/stations/water_station.tscn", "WaterGrave", Vector3(27, 0, -10.8), 0.0, {})
    # Haunted house
    _supplement("pre_workout", "Pre-Workout", 2000, Color(0.8392, 0.6196, 0.1804), Vector3(-31.2, STATION_Y, -17), Vector2(1, 0))
    _supplement("bcaas", "BCAAs", 1500, Color(0.2196, 0.6314, 0.4118), Vector3(-31.2, STATION_Y, -28), Vector2(1, 0))
    # Crypt
    _supplement("whey", "Whey Protein", 2500, Color(0.4196, 0.2745, 0.7569), Vector3(31.2, STATION_Y, -14.5), Vector2(-1, 0))
    _supplement("fish_oil", "Fish Oil", 3000, Color(0.1922, 0.5922, 0.5843), Vector3(31.2, STATION_Y, -28.5), Vector2(-1, 0))
    _place("res://scenes/stations/loot_locker.tscn", "LootLockerCrypt", Vector3(18, 0, -31.4), 0.0, {})


# ---------------------------------------------------------------- signs and lights

func _build_signs() -> void:
    _sign("CEMETERY GATE", Vector3(0, 4.7, GATE_Z + 0.6))
    _sign("HAUNTED HOUSE", Vector3(-16, 4.7, NORTH_Z + 0.6))
    _sign("THE CRYPT", Vector3(16, 4.7, NORTH_Z + 0.6))
    _sign("HAPPY HALLOWEEN", Vector3(0, 4.6, HALF - 0.4), true)


func _sign(text: String, pos: Vector3, face_north: bool = false) -> void:
    var l := Label3D.new()
    l.text = text
    l.font_size = 64
    l.pixel_size = 0.012
    l.modulate = Color(1.0, 0.55, 0.1)
    l.outline_size = 12
    l.outline_modulate = Color(0.08, 0.02, 0.1)
    l.position = pos
    if face_north:
        l.rotation.y = PI
    _decor.add_child(l)


## Only 6 real lights (phones are slow with more); everything else glows by itself.
func _build_lights() -> void:
    _light(Vector3(20, 3.0, 24), Color(1.0, 0.6, 0.2), 14.0, 1.5)    # pumpkin patch
    _light(Vector3(-16, 3.5, 18), Color(1.0, 0.65, 0.3), 14.0, 1.3)  # plaza lockers / wall buys
    _light(Vector3(0, 3.5, -1), Color(0.5, 1.0, 0.55), 18.0, 1.1)    # graveyard fog glow
    _light(Vector3(0, 4.0, -9), Color(1.0, 0.6, 0.2), 8.0, 1.2)      # PR Rack
    _light(Vector3(-19, 3.5, -20), Color(1.0, 0.6, 0.2), 14.0, 1.5)  # house
    _light(Vector3(19, 3.5, -22), Color(0.7, 0.35, 1.0), 14.0, 1.5)  # crypt
    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-50, 30, 0)
    moon.light_color = Color(0.55, 0.6, 0.9)
    moon.light_energy = 0.45
    moon.shadow_enabled = false
    add_child(moon)


func _light(pos: Vector3, color: Color, light_range: float, energy: float) -> void:
    var l := OmniLight3D.new()
    l.position = pos
    l.light_color = color
    l.omni_range = light_range
    l.light_energy = energy
    l.shadow_enabled = false
    add_child(l)


# ---------------------------------------------------------------- zombie costumes

## Switches on Halloween zombie costumes (halloween_costume.gd). The costume
## node only exists inside this map, so gym-map zombies stay as they are.
func _build_costumes() -> void:
    var s: Script = load("res://scripts/zombies/halloween_costume.gd") as Script
    if s == null:
        push_warning("Halloween: halloween_costume.gd is missing, zombies stay plain.")
        return
    var n: Node = s.new() as Node
    if n == null:
        return
    n.name = "ZombieCostumes"
    add_child(n)
