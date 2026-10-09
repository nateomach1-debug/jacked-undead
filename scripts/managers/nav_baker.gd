extends NavigationRegion3D
## Builds the zombie navigation mesh at runtime from the building model,
## since there's no editor to bake it in. Add this as a node to a map.
## A label at the top of the screen shows whether it worked, plus how many
## path points the nearest zombie currently has (0 = it's walking blind).

@export var source_path: NodePath = NodePath("../BuildingModel")
@export var show_debug_label: bool = true
@export var cell_size: float = 0.25
@export var cell_height: float = 0.25
@export var agent_radius: float = 0.5      # keeps paths this far from walls; bigger erases narrow stairs
@export var agent_height: float = 2.0
@export var agent_max_climb: float = 0.5   # tallest stair step the path may cross
@export var agent_max_slope: float = 60.0
@export var rebake_on_barrier: bool = true  # off for maps that join areas with NavigationLink3D instead

# Temporary Cheese Cube probes: label + a point on that flight/landing surface.
const PROBES: Array = [
    ["F0", Vector3(2, 1.5, 18)],
    ["F1", Vector3(18, 4.5, 0)],
    ["F2", Vector3(0, 7.5, -18)],
    ["F3", Vector3(-18, 10.5, 0)],
    ["F4", Vector3(-2, 13.5, 18)],
    ["F5", Vector3(18, 16.5, -2)],
    ["F6", Vector3(0, 19.5, -18)],
    ["F7", Vector3(-18, 22.5, -2)],
    ["L1", Vector3(18, 3, 18)],
    ["L2", Vector3(18, 6, -18)],
    ["L3", Vector3(-18, 9, -18)],
    ["L4", Vector3(-18, 12, 18)],
    ["L5", Vector3(16, 15, 16)],
    ["L6", Vector3(18, 18, -18)],
    ["L7", Vector3(-18, 21, -18)],
    ["L8", Vector3(-16, 24, 16)],
    ["F2w", Vector3(-12, 8.6, -18)],
    ["F3s", Vector3(-18, 11.5, 12)],
    ["F4e", Vector3(10, 14.8, 18)],
    ["F5s", Vector3(18, 15.2, 10)],
    ["F6w", Vector3(-12, 20.6, -18)],
]

var _label: Label
var _base_text: String = "NAV: baking..."
var _debug_timer: float = 0.0


func _ready() -> void:
    var nav := NavigationMesh.new()
    nav.cell_size = cell_size
    nav.cell_height = cell_height
    nav.agent_radius = agent_radius
    nav.agent_height = agent_height
    nav.agent_max_climb = agent_max_climb
    nav.agent_max_slope = agent_max_slope
    # Build from the meshes of the group below (the building model).
    nav.set("geometry_parsed_geometry_type", 0)
    nav.set("geometry_source_geometry_mode", 1)
    nav.set("geometry_source_group_name", &"navmesh_source")
    navigation_mesh = nav

    var source := get_node_or_null(source_path)
    if source:
        source.add_to_group("navmesh_source")

    bake_finished.connect(_on_bake_finished)
    GameManager.barrier_opened.connect(_on_barrier_opened)
    GameManager.dev_settings_changed.connect(_on_dev_settings_changed)
    _make_debug_label()
    bake_navigation_mesh(true)


## A bought door frees itself: wait for that to finish, then rebake so the
## opening becomes walkable for zombies.
func _on_barrier_opened() -> void:
    if not rebake_on_barrier:
        return
    await get_tree().process_frame
    await get_tree().process_frame
    _base_text = "NAV: rebaking..."
    bake_navigation_mesh(true)


## Dev menu toggle: the NAV label only shows when "Nav data" is on.
func _on_dev_settings_changed() -> void:
    if _label:
        _label.visible = GameManager.dev_show_nav()


func _on_bake_finished() -> void:
    var polygons: int = 0
    if navigation_mesh:
        polygons = navigation_mesh.get_polygon_count()
    print("NavBaker: bake finished, polygons = ", polygons)
    if polygons > 0:
        _base_text = "NAV: ready (%d polygons)" % polygons
    else:
        _base_text = "NAV: FAILED (0 polygons)"


func _process(delta: float) -> void:
    if _label == null:
        return
    _debug_timer -= delta
    if _debug_timer > 0.0:
        return
    _debug_timer = 0.5

    var nav_map: RID = get_world_3d().navigation_map
    var player := get_tree().get_first_node_in_group("player") as Node3D
    var nearest = null
    var best: float = INF
    for z in get_tree().get_nodes_in_group("zombies"):
        var zn := z as Node3D
        if zn == null or player == null:
            continue
        var d: float = zn.global_position.distance_to(player.global_position)
        if d < best:
            best = d
            nearest = zn

    var line2: String = "no zombies"
    var line3: String = ""
    if nearest != null:
        var path = nearest.get("_path")
        var pts: int = -1
        var end_gap: float = -1.0
        var my_feet: Vector3 = player.global_position - Vector3(0.0, 0.9, 0.0)
        if path != null:
            pts = path.size()
            if pts > 0:
                end_gap = (path[pts - 1] as Vector3).distance_to(my_feet)
        var speed: float = 0.0
        var vel = nearest.get("velocity")
        if vel != null:
            speed = Vector2(vel.x, vel.z).length()
        var you_gap: float = NavigationServer3D.map_get_closest_point(nav_map, my_feet).distance_to(my_feet)
        var z_feet: Vector3 = nearest.global_position - Vector3(0.0, 0.95, 0.0)
        var z_gap: float = NavigationServer3D.map_get_closest_point(nav_map, z_feet).distance_to(z_feet)
        line2 = "nearest zombie %.0fm away at (%.0f, %.0f, %.0f), path points: %d" % [best, nearest.global_position.x, nearest.global_position.y, nearest.global_position.z, pts]
        line3 = "you off nav: %.1fm | zombie off nav: %.1fm | path end to you: %.1fm | zombie speed: %.1f" % [you_gap, z_gap, end_gap, speed]

    var probe_text: String = "off nav:"
    for pr in PROBES:
        var pv: Vector3 = pr[1]
        var g: float = NavigationServer3D.map_get_closest_point(nav_map, pv).distance_to(pv)
        probe_text += " %s %.1f" % [pr[0], g]
    _label.text = _base_text + "\n" + line2 + "\n" + line3 + "\n" + probe_text


func _make_debug_label() -> void:
    if not show_debug_label:
        return
    var layer := CanvasLayer.new()
    add_child(layer)
    _label = Label.new()
    _label.text = _base_text
    _label.position = Vector2(900.0, 6.0)
    _label.add_theme_font_size_override("font_size", 20)
    _label.visible = GameManager.dev_show_nav()
    layer.add_child(_label)
