extends Area3D

@export var supplement_id: String = "trt"   # trt | creatine | whey | pre_workout | fish_oil | bcaas | glutamine | collagen
@export var display_name: String = "TRT"
@export var cost: int = 2000
@export var body_color: Color = Color(0.85, 0.65, 0.1, 1)
@export var icon_texture: Texture2D
@export var description: String = ""  # leave empty to use the default below for this supplement_id
@export var is_extra: bool = false    # set by code on the auto-spawned stations

# Shown on the line above "Tap USE to buy ...". Edit the wording here.
const DESCRIPTIONS: Dictionary = {
    "trt": "+50% damage",
    "creatine": "+25% move speed, double melee damage",
    "whey": "+50% max health",
    "pre_workout": "50% faster reloads",
    "fish_oil": "Regenerate 2 HP per second",
    "bcaas": "Infinite stamina",
    "glutamine": "Longer downed time, faster revives, solo second chances",
    "collagen": "No fall damage, no explosion damage",
}

# Overrides the color set in the map scenes (so no map needs editing).
const COLOR_OVERRIDES: Dictionary = {
    "whey": Color(0.85, 0.12, 0.12, 1),
}

# Spawned automatically next to the first supplement station on every map.
const STATION_SCENE_PATH: String = "res://scenes/stations/supplement_station.tscn"
const EXTRAS: Array = [
    {"id": "glutamine", "name": "GLUTAMINE", "cost": 3000, "color": Color(0.6, 0.25, 0.9, 1), "icon": "res://resources/icons/glutamine.svg"},
    {"id": "collagen", "name": "COLLAGEN", "cost": 2000, "color": Color(1.0, 0.2, 0.6, 1), "icon": "res://resources/icons/collagen.svg"},
]
const SPOT_RADIUS: float = 1.8
const SPOT_MIN_GAP: float = 1.4

# Fixed spots for Glutamine (first) and Collagen (second), per map file.
# Positions are local to the same parent as the other stations.
const MAP_SPOTS: Dictionary = {
    "main.tscn": [Vector3(17, 0.9, 0), Vector3(19, 0.9, 0)],
    "building_map.tscn": [Vector3(17, -16.3, 29.8), Vector3(38, -16.3, 29.8)],
}

# Machine look: what shape of product each supplement shows in its window.
const PRODUCT_SHAPES: Dictionary = {
    "trt": "vial",
    "creatine": "tub",
    "whey": "tub",
    "glutamine": "tub",
    "pre_workout": "can",
    "fish_oil": "bottle",
    "bcaas": "bottle",
    "collagen": "bottle",
}
const PRODUCT_SCALE: Dictionary = {"vial": 1.5}
const FRONT_Z: float = 0.5     # how far the front panel face sits from the center
const WIN_X: float = -0.08     # window / slot / tray are centered here (coin slot is on the right)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var sign_sprite: Sprite3D = $SignSprite3D
@onready var name_label: Label3D = $Label3D

var _front: Node3D = null
var _mini: Node3D = null
var _mini_rest_y: float = 0.0
var _lamp_mat: StandardMaterial3D = null
var _lamp_on: bool = true
var _flash: float = 0.0
var _t: float = 0.0
var _player: Node = null


func _ready() -> void:
    if COLOR_OVERRIDES.has(supplement_id):
        body_color = COLOR_OVERRIDES[supplement_id]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = body_color.darkened(0.5)
    mat.emission_enabled = true
    mat.emission = body_color
    mat.emission_energy_multiplier = 0.15
    mesh_instance.set_surface_override_material(0, mat)
    if icon_texture:
        sign_sprite.texture = icon_texture
    name_label.text = display_name
    name_label.modulate = body_color.lightened(0.25)
    _build_machine()

    var others: Array = get_tree().get_nodes_in_group("supplement_station")
    add_to_group("supplement_station")
    if not is_extra and others.is_empty():
        _spawn_extras.call_deferred()


func _process(delta: float) -> void:
    if _front == null:
        return
    # Turn the front panel toward the local player (yaw only).
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player")
    if _player != null and _player is Node3D:
        var d: Vector3 = (_player as Node3D).global_position - global_position
        d.y = 0.0
        var d2: float = d.length_squared()
        if d2 > 0.01 and d2 < 400.0:
            var target: float = atan2(d.x, d.z)
            var cur: float = _front.global_rotation.y
            _front.global_rotation = Vector3(0.0, lerp_angle(cur, target, clampf(delta * 8.0, 0.0, 1.0)), 0.0)
    # Blinking coin lamp (steady for a moment after a purchase).
    _t += delta
    _flash = maxf(_flash - delta, 0.0)
    var on: bool = _flash > 0.0 or fmod(_t, 1.2) < 0.6
    if on != _lamp_on and _lamp_mat != null:
        _lamp_on = on
        _lamp_mat.emission_energy_multiplier = 2.5 if on else 0.15


# ---------- machine look (all built in code) ----------

func _mat(color: Color, glow: float = 0.0, metal: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metal
    m.roughness = rough
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = mat
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, along_z: bool = false) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var cm := CylinderMesh.new()
    cm.top_radius = radius
    cm.bottom_radius = radius
    cm.height = height
    cm.radial_segments = 16
    cm.rings = 1
    mi.mesh = cm
    mi.material_override = mat
    mi.position = pos
    if along_z:
        mi.rotation.x = PI / 2.0
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


func _build_product(root: Node3D, shape: String, prod: Material, white: Material, dark: Material) -> void:
    match shape:
        "tub":
            _cyl(root, 0.095, 0.2, Vector3(0.0, 0.1, 0.0), prod)
            _cyl(root, 0.098, 0.07, Vector3(0.0, 0.1, 0.0), white)
            _cyl(root, 0.1, 0.05, Vector3(0.0, 0.225, 0.0), dark)
        "can":
            _cyl(root, 0.075, 0.3, Vector3(0.0, 0.15, 0.0), prod)
            _cyl(root, 0.077, 0.12, Vector3(0.0, 0.17, 0.0), white)
            _cyl(root, 0.06, 0.02, Vector3(0.0, 0.31, 0.0), dark)
        "vial":
            _cyl(root, 0.045, 0.18, Vector3(0.0, 0.09, 0.0), prod)
            _cyl(root, 0.047, 0.08, Vector3(0.0, 0.09, 0.0), white)
            _cyl(root, 0.05, 0.04, Vector3(0.0, 0.2, 0.0), dark)
            _cyl(root, 0.052, 0.02, Vector3(0.0, 0.23, 0.0), white)
        _:
            _cyl(root, 0.07, 0.24, Vector3(0.0, 0.12, 0.0), prod)
            _cyl(root, 0.072, 0.1, Vector3(0.0, 0.12, 0.0), white)
            _cyl(root, 0.035, 0.05, Vector3(0.0, 0.265, 0.0), prod)
            _cyl(root, 0.04, 0.04, Vector3(0.0, 0.31, 0.0), white)


func _build_machine() -> void:
    var f: float = FRONT_Z
    var dark := _mat(body_color.darkened(0.8), 0.0, 0.4, 0.45)
    var black := _mat(Color(0.02, 0.02, 0.03), 0.0, 0.0, 0.8)
    var trim := _mat(body_color, 1.0)
    var pane := _mat(body_color.darkened(0.45), 1.2)
    var white := _mat(Color(0.95, 0.95, 0.95), 0.25)
    var prod := _mat(body_color.lightened(0.15), 0.9)
    _lamp_mat = _mat(body_color.lightened(0.3), 2.5)

    # Glowing top rim and a dark base ring, all the way round.
    _cyl(self, 0.45, 0.03, Vector3(0.0, 0.9, 0.0), trim)
    _cyl(self, 0.53, 0.08, Vector3(0.0, -0.86, 0.0), dark)

    # Everything below turns to face the player.
    _front = Node3D.new()
    _front.name = "Machine"
    add_child(_front)

    # Front panel and glowing header sign with a dumbbell.
    _box(_front, Vector3(0.72, 1.26, 0.26), Vector3(0.0, 0.01, f - 0.13), dark)
    _box(_front, Vector3(0.74, 0.15, 0.26), Vector3(0.0, 0.72, f - 0.12), trim)
    var dz: float = f + 0.015
    _box(_front, Vector3(0.24, 0.02, 0.01), Vector3(0.0, 0.72, dz), black)
    for sx: float in [-1.0, 1.0]:
        _box(_front, Vector3(0.025, 0.1, 0.01), Vector3(0.085 * sx, 0.72, dz), black)
        _box(_front, Vector3(0.025, 0.07, 0.01), Vector3(0.12 * sx, 0.72, dz), black)

    # Lit window: glowing pane, raised frame, shelf.
    var wy: float = 0.34
    _box(_front, Vector3(0.46, 0.5, 0.01), Vector3(WIN_X, wy, f + 0.002), pane)
    _box(_front, Vector3(0.52, 0.03, 0.04), Vector3(WIN_X, wy + 0.265, f + 0.02), trim)
    _box(_front, Vector3(0.52, 0.03, 0.04), Vector3(WIN_X, wy - 0.265, f + 0.02), trim)
    _box(_front, Vector3(0.03, 0.5, 0.04), Vector3(WIN_X - 0.245, wy, f + 0.02), trim)
    _box(_front, Vector3(0.03, 0.5, 0.04), Vector3(WIN_X + 0.245, wy, f + 0.02), trim)
    _box(_front, Vector3(0.46, 0.03, 0.09), Vector3(WIN_X, 0.105, f + 0.045), dark)

    # The supplement on display in the window.
    var shape: String = str(PRODUCT_SHAPES.get(supplement_id, "bottle"))
    var shape_scale: float = float(PRODUCT_SCALE.get(shape, 1.0))
    var big := Node3D.new()
    big.position = Vector3(WIN_X, 0.12, f + 0.035)
    big.scale = Vector3.ONE * shape_scale
    _front.add_child(big)
    _build_product(big, shape, prod, white, dark)

    # Dispensing slot, flap and accent bar.
    _box(_front, Vector3(0.34, 0.07, 0.03), Vector3(WIN_X, -0.12, f + 0.012), black)
    _box(_front, Vector3(0.36, 0.015, 0.05), Vector3(WIN_X, -0.075, f + 0.03), dark)
    _box(_front, Vector3(0.34, 0.012, 0.02), Vector3(WIN_X, -0.175, f + 0.01), trim)

    # Tray with a small bottle resting in it.
    _box(_front, Vector3(0.4, 0.035, 0.14), Vector3(WIN_X, -0.31, f + 0.07), dark)
    _box(_front, Vector3(0.4, 0.05, 0.02), Vector3(WIN_X, -0.285, f + 0.135), trim)
    _mini_rest_y = -0.2925
    _mini = Node3D.new()
    _mini.position = Vector3(WIN_X, _mini_rest_y, f + 0.07)
    _mini.scale = Vector3.ONE * shape_scale * 0.4
    _front.add_child(_mini)
    _build_product(_mini, shape, prod, white, dark)

    # Coin slot strip on the right: plate, slot, round button, blinking lamp.
    var cx: float = 0.275
    _box(_front, Vector3(0.14, 0.34, 0.03), Vector3(cx, 0.36, f + 0.015), dark)
    _box(_front, Vector3(0.016, 0.1, 0.01), Vector3(cx, 0.44, f + 0.032), black)
    _cyl(_front, 0.03, 0.02, Vector3(cx, 0.34, f + 0.035), trim, true)
    _box(_front, Vector3(0.07, 0.025, 0.01), Vector3(cx, 0.26, f + 0.032), _lamp_mat)

    # Vents at the bottom of the panel.
    for vy: float in [-0.5, -0.55, -0.6]:
        _box(_front, Vector3(0.44, 0.02, 0.015), Vector3(0.0, vy, f + 0.007), black)


# Little dispense animation on a purchase: bottle drops from the slot into the tray.
func _play_dispense() -> void:
    _flash = 1.5
    if _mini == null:
        return
    _mini.position.y = -0.12
    var tw := create_tween()
    tw.tween_property(_mini, "position:y", _mini_rest_y, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# True if this player currently owns this supplement (cleared on strip / revive).
func _player_owns(p: Node) -> bool:
    if p == null:
        return false
    var perks = p.get("owned_perks")
    if perks is Array:
        return supplement_id in perks
    return false


func interact(player: Node) -> void:
    if _player_owns(player):
        return
    if GameManager.try_spend_gains(GameManager.supplement_cost(cost)):
        player.apply_supplement(supplement_id)
        _play_dispense()


func get_prompt_color() -> Color:
    return body_color.lightened(0.25)


func _get_description() -> String:
    if description != "":
        return description
    return DESCRIPTIONS.get(supplement_id, "")


func get_prompt_text() -> String:
    var me: Node = get_tree().get_first_node_in_group("player")
    if _player_owns(me):
        return "%s (already stacked)" % display_name
    var buy_line: String = "Tap USE to buy %s - %d Gains" % [display_name, GameManager.supplement_cost(cost)]
    var desc: String = _get_description()
    if desc == "":
        return buy_line
    return "%s\n%s" % [desc, buy_line]


# ---------- auto-spawn of the extra supplements ----------

func _spawn_extras() -> void:
    await get_tree().physics_frame
    await get_tree().physics_frame
    if not is_inside_tree():
        return
    var parent: Node = get_parent()
    var packed: PackedScene = null
    if scene_file_path != "":
        packed = load(scene_file_path) as PackedScene
    if packed == null:
        packed = load(STATION_SCENE_PATH) as PackedScene
    if packed == null or parent == null:
        push_warning("Extra supplements: station scene not found")
        return

    var stations: Array = []
    var taken: Array = []
    var existing_ids: Array = []
    for n in get_tree().get_nodes_in_group("supplement_station"):
        if is_instance_valid(n):
            stations.append(n)
            taken.append(n.global_position)
            existing_ids.append(n.supplement_id)

    var index: int = 0
    for extra in EXTRAS:
        index += 1
        if extra["id"] in existing_ids:
            continue
        var spot: Vector3 = _find_spot(stations, taken)
        if spot == Vector3.INF:
            spot = global_position + Vector3(SPOT_RADIUS * float(index), 0.0, 0.0)
            push_warning("Extra supplements: no clear spot, using fallback for " + str(extra["id"]))
        var s = packed.instantiate()
        s.supplement_id = extra["id"]
        s.display_name = extra["name"]
        s.cost = extra["cost"]
        s.body_color = extra["color"]
        s.is_extra = true
        if ResourceLoader.exists(extra["icon"]):
            s.icon_texture = load(extra["icon"]) as Texture2D
        parent.add_child(s)
        var fixed: Array = _map_spots()
        if fixed.size() >= index:
            s.position = fixed[index - 1]
            spot = s.global_position
        else:
            s.global_position = spot
        s.global_rotation = global_rotation
        taken.append(spot)


func _map_spots() -> Array:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return []
    var file: String = scene.scene_file_path.get_file()
    if MAP_SPOTS.has(file):
        return MAP_SPOTS[file]
    return []


func _find_spot(stations: Array, taken: Array) -> Vector3:
    for st in stations:
        if not is_instance_valid(st):
            continue
        for k in range(12):
            var ang: float = float(k) * TAU / 12.0
            var pos: Vector3 = st.global_position + Vector3(cos(ang), 0.0, sin(ang)) * SPOT_RADIUS
            var too_close: bool = false
            for t in taken:
                var flat: Vector3 = Vector3(pos.x - t.x, 0.0, pos.z - t.z)
                if flat.length() < SPOT_MIN_GAP:
                    too_close = true
                    break
            if too_close:
                continue
            if _is_clear(pos):
                return pos
    return Vector3.INF


func _is_clear(pos: Vector3) -> bool:
    var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var shape := SphereShape3D.new()
    shape.radius = 0.5
    var q := PhysicsShapeQueryParameters3D.new()
    q.shape = shape
    q.transform = Transform3D(Basis.IDENTITY, pos + Vector3(0.0, 0.9, 0.0))
    q.collision_mask = 1
    if not space.intersect_shape(q, 1).is_empty():
        return false
    var ray := PhysicsRayQueryParameters3D.create(pos + Vector3(0.0, 0.5, 0.0), pos + Vector3(0.0, -3.0, 0.0), 1)
    return not space.intersect_ray(ray).is_empty()
