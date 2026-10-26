
extends Node3D

const PICKUP_RADIUS: float = 1.7
const SUPPLEMENTS: Array[Dictionary] = [
    {"id": "trt", "name": "TRT", "color": Color(0.95, 0.65, 0.08)},
    {"id": "creatine", "name": "CREATINE", "color": Color(0.2, 0.85, 0.3)},
    {"id": "whey", "name": "WHEY", "color": Color(0.9, 0.15, 0.15)},
    {"id": "pre_workout", "name": "PRE-WORKOUT", "color": Color(1.0, 0.45, 0.05)},
    {"id": "fish_oil", "name": "FISH OIL", "color": Color(0.15, 0.65, 0.95)},
    {"id": "bcaas", "name": "BCAAS", "color": Color(0.75, 0.25, 0.95)},
    {"id": "glutamine", "name": "GLUTAMINE", "color": Color(0.6, 0.25, 0.9)},
    {"id": "collagen", "name": "COLLAGEN", "color": Color(1.0, 0.2, 0.6)}
]

var supplement_id: String = ""
var supplement_name: String = ""
var supplement_color: Color = Color.ORANGE

var _time: float = 0.0
var _collected: bool = false
var _label: Label3D


func _ready() -> void:
    if not _choose_supplement():
        queue_free()
        return

    _build_visual()


func _choose_supplement() -> bool:
    var player := get_tree().get_first_node_in_group("player")
    if player == null:
        return false

    var owned = player.get("owned_perks")
    var available: Array[Dictionary] = []

    for entry in SUPPLEMENTS:
        var id: String = str(entry["id"])
        if not (owned is Array and id in owned):
            available.append(entry)

    if available.is_empty():
        return false

    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var chosen: Dictionary = available[rng.randi_range(0, available.size() - 1)]

    supplement_id = str(chosen["id"])
    supplement_name = str(chosen["name"])
    supplement_color = chosen["color"]
    return true


func _build_visual() -> void:
    var ring_instance := MeshInstance3D.new()
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.48
    ring_mesh.outer_radius = 0.65
    ring_mesh.rings = 4
    ring_mesh.ring_segments = 12
    ring_instance.mesh = ring_mesh
    ring_instance.material_override = _make_material(supplement_color, 1.0)
    ring_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ring_instance)

    var item := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.28
    sphere.height = 0.56
    sphere.radial_segments = 8
    sphere.rings = 4
    item.mesh = sphere
    item.material_override = _make_material(supplement_color.lightened(0.15), 0.8)
    item.position.y = 0.65
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(item)

    _label = Label3D.new()
    _label.text = supplement_name
    _label.font_size = 32
    _label.pixel_size = 0.006
    _label.outline_size = 8
    _label.modulate = supplement_color
    _label.outline_modulate = Color.BLACK
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.position.y = 1.25
    add_child(_label)


func _make_material(color: Color, glow: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.8
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = glow
    return mat


func _process(delta: float) -> void:
    if _collected:
        return

    _time += delta
    rotation.y += delta * 0.8
    position.y = 0.05 + sin(_time * 2.5) * 0.08

    var player := get_tree().get_first_node_in_group("player")
    if player == null or not is_instance_valid(player) or not player is Node3D:
        return

    if bool(player.get("is_downed")) or bool(player.get("is_dead")):
        return

    var player_node := player as Node3D
    var distance: float = Vector2(
        player_node.global_position.x - global_position.x,
        player_node.global_position.z - global_position.z
    ).length()

    if distance > PICKUP_RADIUS or absf(player_node.global_position.y - global_position.y) > 2.2:
        return

    _collect(player)


func _collect(player: Node) -> void:
    if _collected:
        return

    var owned = player.get("owned_perks")
if owned is Array and supplement_id in owned:
    queue_free()
    return
    if not player.has_method("apply_supplement"):
        return

    _collected = true
    player.apply_supplement(supplement_id)

    if player.has_method("play_supplement_drink"):
        player.play_supplement_drink(supplement_id, supplement_color)

    queue_free()
