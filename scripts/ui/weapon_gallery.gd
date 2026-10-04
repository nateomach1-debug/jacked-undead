extends Control
## Weapon gallery: list of guns (left), spinning preview (middle), stats (right, next step).

const GUN_PATHS: Array = [
	"res://resources/weapons/pistol.tres",
	"res://resources/weapons/rifle.tres",
	"res://resources/weapons/smg.tres",
	"res://resources/weapons/crossbow.tres",
	"res://resources/weapons/sniper.tres",
]
const LOCKER_PATH: String = "res://scripts/weapons/locker_weapons.gd"
const ATTACH_REGISTRY: String = "res://scripts/weapons/attachments.gd"
const ATTACH_MODELS: String = "res://scripts/weapons/attachment_models.gd"
const PREVIEW_FIT: float = 1.8
# Turns each model so the gun points along +X (what the attachment graphics expect).
# If attachments look sideways/backwards, try 90, -90 or 180 here.
const MODEL_YAW: float = 0.0          # .gltf guns
const PLACEHOLDER_YAW: float = -90.0  # procedural guns (they point toward -Z)

var _guns: Array = []          # {"w": WeaponData, "locker": bool}
var _index: int = 0
var _stage: Node3D
var _holder: Node3D = null
var _name_label: Label
var _stats_box: VBoxContainer
var _spin: bool = true
var _spin_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_guns()
	_build_ui()
	if not _guns.is_empty():
		_select(0)


func _load_guns() -> void:
	for path in GUN_PATHS:
		var w = load(path)
		if w is WeaponData:
			_guns.append({"w": w, "locker": false})
	var script = load(LOCKER_PATH)
	if script != null:
		for entry in script.build_pool():
			var lw = entry["weapon"]
			# Wall-buy guns in the pool come from .tres files; skip them (already listed).
			if lw != null and lw.resource_path == "":
				_guns.append({"w": lw, "locker": true})


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "WEAPON GALLERY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	outer.add_child(title)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	outer.add_child(main)

	# ---- left: gun list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var group := ButtonGroup.new()
	var locker_header_done: bool = false
	for i in range(_guns.size()):
		if bool(_guns[i]["locker"]) and not locker_header_done:
			locker_header_done = true
			var header := Label.new()
			header.text = "LOOT LOCKER"
			header.add_theme_font_size_override("font_size", 22)
			header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			list.add_child(header)
		var b := Button.new()
		b.text = (_guns[i]["w"] as WeaponData).weapon_name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_select.bind(i))
		list.add_child(b)

	# ---- middle: name + spinning preview
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(mid)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 28)
	mid.add_child(_name_label)

	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(300, 300)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_preview_input)
	mid.add_child(container)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	container.add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 3.6)
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

	_spin_button = Button.new()
	_spin_button.custom_minimum_size = Vector2(0, 60)
	_spin_button.add_theme_font_size_override("font_size", 22)
	_spin_button.pressed.connect(_toggle_spin)
	mid.add_child(_spin_button)
	_update_spin_button()

	# ---- right: stats (filled in the next step)
	_stats_box = VBoxContainer.new()
	_stats_box.custom_minimum_size = Vector2(320, 0)
	main.add_child(_stats_box)
	var soon := Label.new()
	soon.text = "STATS COMING NEXT"
	soon.add_theme_font_size_override("font_size", 22)
	_stats_box.add_child(soon)

	# ---- bottom: back
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 70)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(queue_free)
	outer.add_child(back)


func _toggle_spin() -> void:
	_spin = not _spin
	if not _spin:
		_stage.rotation.y = 0.0   # clean side view
	_update_spin_button()


func _update_spin_button() -> void:
	_spin_button.text = "SPIN: ON" if _spin else "SPIN: OFF (drag to rotate)"


## Drag on the preview to turn the gun by hand (only while spin is off).
func _on_preview_input(event: InputEvent) -> void:
	if _spin or _stage == null:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_stage.rotation.y += event.relative.x * 0.01


func _select(i: int) -> void:
	_index = i
	var w: WeaponData = _guns[i]["w"]
	_name_label.text = w.weapon_name
	_rebuild_model(w)


func _rebuild_model(w: WeaponData) -> void:
	if _holder != null:
		_stage.remove_child(_holder)
		_holder.queue_free()
		_holder = null
	var model: Node3D = w.create_model()
	if model == null:
		return
	# Point the gun along +X, then scale it to PREVIEW_FIT and center it.
	model.rotation.y = deg_to_rad(MODEL_YAW if w.model_scene != null else PLACEHOLDER_YAW)
	var info: Dictionary = {"has": false, "box": AABB()}
	_collect_aabb(model, Transform3D.IDENTITY, info)
	if bool(info["has"]):
		var box: AABB = info["box"]
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		if longest > 0.0001:
			var s: float = PREVIEW_FIT / longest
			model.scale = Vector3.ONE * s
			model.position = -(box.position + box.size * 0.5) * s
	_holder = Node3D.new()
	_holder.add_child(model)
	_add_attachments(model, w)
	_stage.add_child(_holder)
	_stage.rotation.y = 0.0


## Draws the gun's equipped attachments (same builder the player uses).
func _add_attachments(model: Node3D, w: WeaponData) -> void:
	var reg_script = load(ATTACH_REGISTRY)
	var models_script = load(ATTACH_MODELS)
	if reg_script == null or models_script == null:
		return
	var loadout = reg_script.new().get_loadout(w.get_base_name())
	if not (loadout is Dictionary) or loadout.is_empty():
		return
	var root = models_script.new().build_for(model, loadout, w.get_base_name())
	if root != null:
		_holder.add_child(root)


func _collect_aabb(node: Node, parent_xf: Transform3D, info: Dictionary) -> void:
	var xf: Transform3D = parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var local: AABB = (node as MeshInstance3D).get_aabb()
		if local.size.length() > 0.0:
			var box: AABB = xf * local
			if bool(info["has"]):
				info["box"] = (info["box"] as AABB).merge(box)
			else:
				info["box"] = box
				info["has"] = true
	for c in node.get_children():
		_collect_aabb(c, xf, info)


func _process(delta: float) -> void:
	if _spin and _stage != null and is_visible_in_tree():
		_stage.rotation.y += delta * 0.9
