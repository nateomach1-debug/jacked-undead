extends Area3D
## Loot Locker: the gym version of the mystery box. Pay Gains, the locker
## rattles while a random gun cycles by, then the door swings open and the
## gun floats out. Tap USE again within take_window seconds to grab it, or
## the locker closes and you lose it. Built entirely in code.

const LockerWeapons = preload("res://scripts/weapons/locker_weapons.gd")
const DISPLAY_LENGTH: float = 0.9  # every gun shown in the locker is scaled to this length (meters)

enum State { IDLE, ROLLING, READY }

@export var cost: int = 950
@export var roll_time: float = 2.5
@export var take_window: float = 8.0

var _state: int = State.IDLE
var _pool: Array = []
var _total_weight: int = 0
var _rolled: WeaponData = null
var _timer: float = 0.0
var _cycle_timer: float = 0.0

var _visual_root: Node3D
var _door_pivot: Node3D
var _label: Label3D
var _display_mount: Node3D
var _display_model: Node3D = null


func _ready() -> void:
	_pool = LockerWeapons.build_pool()
	for entry in _pool:
		_total_weight += int(entry["weight"])
	_build_visuals()
	_set_idle_label()


func _build_visuals() -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)

	# Locker body
	_add_box(_visual_root, Vector3(1.0, 2.0, 0.8), Vector3(0, 1.0, 0), Color(0.2, 0.35, 0.6))

	# Door, hinged on its left edge
	_door_pivot = Node3D.new()
	_door_pivot.position = Vector3(-0.5, 1.0, 0.42)
	_visual_root.add_child(_door_pivot)
	_add_box(_door_pivot, Vector3(1.0, 1.9, 0.05), Vector3(0.5, 0, 0), Color(0.3, 0.5, 0.8))
	_add_box(_door_pivot, Vector3(0.05, 0.25, 0.06), Vector3(0.85, 0, 0.04), Color(0.9, 0.9, 0.9))

	_label = Label3D.new()
	_label.font_size = 48
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 12
	_label.position = Vector3(0, 2.6, 0)
	add_child(_label)

	# Where the rolled gun floats
	_display_mount = Node3D.new()
	_display_mount.position = Vector3(0, 1.3, 0.9)
	add_child(_display_mount)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


func _process(delta: float) -> void:
	if _state == State.ROLLING:
		_timer -= delta
		# Rattle the whole locker a little
		_visual_root.position = Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(-0.03, 0.03))
		# Flip through random guns for suspense
		_cycle_timer -= delta
		if _cycle_timer <= 0.0:
			_cycle_timer = 0.2
			_show_model(_random_weapon())
		if _timer <= 0.0:
			_finish_roll()
	elif _state == State.READY:
		_timer -= delta
		if _display_model:
			_display_mount.rotate_y(delta * 1.5)
		if _timer <= 0.0:
			_close_locker()


func interact(player: Node) -> void:
	if _state == State.IDLE:
		if GameManager.try_spend_gains(GameManager.loot_locker_cost(cost)):
			_start_roll()
	elif _state == State.READY:
		if _rolled and player.has_method("grant_weapon"):
			player.grant_weapon(_rolled)
		_close_locker()


func get_prompt_text() -> String:
	if _state == State.IDLE:
		return "Tap USE to open Loot Locker - %d Gains" % cost
	if _state == State.READY and _rolled:
		return "Tap USE to open Loot Locker - %d Gains" % GameManager.loot_locker_cost(cost)
	return ""


func _start_roll() -> void:
	_rolled = _pick_weapon()
	_state = State.ROLLING
	_timer = roll_time
	_cycle_timer = 0.0
	_label.text = "..."


func _finish_roll() -> void:
	_visual_root.position = Vector3.ZERO
	_show_model(_rolled)
	_set_door_open(true)
	_state = State.READY
	_timer = take_window
	var kind_note: String = _rolled.placeholder_kind if _rolled else ""
	_label.text = ("%s\n[model: %s]" % [_rolled.weapon_name, kind_note]) if _rolled else "Empty"


func _close_locker() -> void:
	_state = State.IDLE
	_rolled = null
	_visual_root.position = Vector3.ZERO
	_clear_model()
	_set_door_open(false)
	_set_idle_label()


func _set_idle_label() -> void:
	var gm_ok: bool = load("res://scripts/weapons/gun_models.gd") != null
	_label.text = "LOOT LOCKER\n%d Gains\n[gun_models: %s]" % [GameManager.loot_locker_cost(cost), "ok" if gm_ok else "FAILED"]


func _set_door_open(open: bool) -> void:
	var tween := create_tween()
	tween.tween_property(_door_pivot, "rotation_degrees:y", -110.0 if open else 0.0, 0.3)


func _show_model(w: WeaponData) -> void:
	_clear_model()
	if w == null:
		return
	var model: Node3D = w.create_model()
	if model:
		_display_model = model
		if not w.model_scene:
			model.rotation_degrees.y = -90.0  # turn built-in guns side-on, like the asset guns
		_display_mount.add_child(model)
		_fit_model(model)


func _collect_meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


## Scales the shown gun so its longest side is DISPLAY_LENGTH, and centers it
## on the mount so it spins around its middle.
func _fit_model(model: Node3D) -> void:
	var meshes: Array = []
	_collect_meshes(model, meshes)
	var to_mount: Transform3D = _display_mount.global_transform.affine_inverse()
	var box := AABB()
	var found: bool = false
	for m in meshes:
		var mi: MeshInstance3D = m
		var local_box: AABB = (to_mount * mi.global_transform) * mi.get_aabb()
		if found:
			box = box.merge(local_box)
		else:
			box = local_box
			found = true
	if not found:
		return
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest <= 0.0001:
		return
	var factor: float = DISPLAY_LENGTH / longest
	model.scale = Vector3.ONE * factor
	model.position = -box.get_center() * factor


func _clear_model() -> void:
	if _display_model:
		_display_model.queue_free()
		_display_model = null
	_display_mount.rotation = Vector3.ZERO


func _pick_weapon() -> WeaponData:
	if _pool.is_empty():
		return null
	var roll: int = randi() % maxi(_total_weight, 1)
	for entry in _pool:
		roll -= int(entry["weight"])
		if roll < 0:
			return entry["weapon"]
	return _pool[0]["weapon"]


func _random_weapon() -> WeaponData:
	if _pool.is_empty():
		return null
	return _pool[randi() % _pool.size()]["weapon"]
