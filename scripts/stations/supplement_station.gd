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

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var sign_sprite: Sprite3D = $SignSprite3D
@onready var name_label: Label3D = $Label3D

var _purchased_by: Array = []


func _ready() -> void:
    if COLOR_OVERRIDES.has(supplement_id):
        body_color = COLOR_OVERRIDES[supplement_id]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = body_color
    mat.emission_enabled = true
    mat.emission = body_color
    mat.emission_energy_multiplier = 0.4
    mesh_instance.set_surface_override_material(0, mat)
    if icon_texture:
        sign_sprite.texture = icon_texture
    name_label.text = display_name
    name_label.modulate = body_color.lightened(0.25)

    var others: Array = get_tree().get_nodes_in_group("supplement_station")
    add_to_group("supplement_station")
    if not is_extra and others.is_empty():
        _spawn_extras.call_deferred()


func interact(player: Node) -> void:
    if player in _purchased_by:
        return
    if GameManager.try_spend_gains(GameManager.supplement_cost(cost)):
        player.apply_supplement(supplement_id)
        _purchased_by.append(player)


func get_prompt_color() -> Color:
    return body_color.lightened(0.25)


func _get_description() -> String:
    if description != "":
        return description
    return DESCRIPTIONS.get(supplement_id, "")


func get_prompt_text() -> String:
    if _purchased_by.size() > 0:
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
        s.global_position = spot
        s.global_rotation = global_rotation
        taken.append(spot)


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
