extends VBoxContainer
## Options-menu character picker: < NAME > with a small spinning 3D preview.

const REGISTRY_PATH: String = "res://scripts/managers/character_registry.gd"
const PREVIEW_SIZE: Vector2 = Vector2(180, 210)

var _reg = null
var _index: int = 0
var _title: Label
var _stage: Node3D
var _model: Node3D = null


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	var script = load(REGISTRY_PATH)
	if script == null:
		add_child(_error_label("CHARACTER LIST FAILED TO LOAD"))
		return
	_reg = script.new()
	_index = _reg.index_of(NetManager.character_id)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	row.add_child(_make_arrow("<", -1))
	_title = Label.new()
	_title.custom_minimum_size = Vector2(220, 0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	row.add_child(_title)
	row.add_child(_make_arrow(">", 1))

	var holder := CenterContainer.new()
	add_child(holder)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = PREVIEW_SIZE
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(container)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	container.add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.95, 3.4)
	cam.fov = 38.0
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.7
	cam.environment = env
	vp.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	light.light_energy = 1.3
	vp.add_child(light)

	_stage = Node3D.new()
	vp.add_child(_stage)

	_refresh()


func _make_arrow(label: String, dir: int) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(70, 60)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(_step.bind(dir))
	return b


func _step(dir: int) -> void:
	if _reg == null:
		return
	_index = posmod(_index + dir, _reg.count())
	NetManager.set_character(_reg.id_at(_index))
	_refresh()


func _refresh() -> void:
	_title.text = _reg.title_at(_index)
	if _model != null:
		_stage.remove_child(_model)
		_model.queue_free()
		_model = null
	_model = _reg.build_fitted(_reg.id_at(_index), 1.8)
	if _model != null:
		_stage.add_child(_model)
	_stage.rotation.y = PI  # start facing the camera


func _process(delta: float) -> void:
	if _stage != null and is_visible_in_tree():
		_stage.rotation.y += delta * 0.9


func _error_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	return l
