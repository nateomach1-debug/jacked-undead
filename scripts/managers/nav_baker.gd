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
	_make_debug_label()
	bake_navigation_mesh(true)


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
	if nearest != null:
		var path = nearest.get("_path")
		var pts: int = -1
		if path != null:
			pts = path.size()
		line2 = "nearest zombie %.0fm away, path points: %d" % [best, pts]
	_label.text = _base_text + "\n" + line2


func _make_debug_label() -> void:
	if not show_debug_label:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.text = _base_text
	_label.position = Vector2(900.0, 6.0)
	_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_label)
