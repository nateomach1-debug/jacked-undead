extends NavigationRegion3D
## Builds the zombie navigation mesh at runtime from the building model,
## since there's no editor to bake it in. Add this as a node to a map.
## A small label at the top of the screen shows whether it worked.

@export var source_path: NodePath = NodePath("../BuildingModel")
@export var show_debug_label: bool = true
@export var cell_size: float = 0.25
@export var cell_height: float = 0.25
@export var agent_radius: float = 0.7      # keeps paths this far from walls (Roid Rager is 0.6 wide)
@export var agent_height: float = 2.5
@export var agent_max_climb: float = 0.5   # tallest stair step the path may cross
@export var agent_max_slope: float = 45.0

var _label: Label


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
	_make_debug_label("NAV: baking...")
	bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	var polygons: int = 0
	if navigation_mesh:
		polygons = navigation_mesh.get_polygon_count()
	print("NavBaker: bake finished, polygons = ", polygons)
	if _label == null:
		return
	if polygons > 0:
		_label.text = "NAV: ready (%d polygons)" % polygons
	else:
		_label.text = "NAV: FAILED (0 polygons)"


func _make_debug_label(text: String) -> void:
	if not show_debug_label:
		return
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.text = text
	_label.position = Vector2(1000.0, 6.0)
	_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(_label)
