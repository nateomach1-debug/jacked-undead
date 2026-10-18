extends Area3D
## A gun dropped on the floor when you swap it out at the 2-weapon limit.
## Keeps the gun's ammo (and PR level / attachments, which live on the WeaponData).

var weapon: WeaponData
var mag_ammo: int = 0
var reserve_ammo: int = 0

var _model_root: Node3D
var _label: Label3D
var _t: float = 0.0
var _player: Node


func setup(w: WeaponData, mag: int, reserve: int) -> void:
    weapon = w
    mag_ammo = mag
    reserve_ammo = reserve


func _ready() -> void:
    collision_layer = 2
    collision_mask = 0
    monitoring = false
    _player = get_tree().get_first_node_in_group("player")

    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.8
    shape.shape = sphere
    shape.position = Vector3(0.0, 0.5, 0.0)
    add_child(shape)

    _model_root = Node3D.new()
    _model_root.position = Vector3(0.0, 0.5, 0.0)
    add_child(_model_root)
    if weapon != null:
        var model: Node3D = weapon.create_model()
        if model != null:
            _model_root.add_child(model)

    _label = Label3D.new()
    _label.text = weapon.get_base_name() if weapon != null else "Weapon"
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.font_size = 48
    _label.pixel_size = 0.004
    _label.outline_size = 12
    _label.modulate = Color(1.0, 0.9, 0.2)
    _label.position = Vector3(0.0, 1.2, 0.0)
    add_child(_label)

    _drop_to_floor()


func _drop_to_floor() -> void:
    await get_tree().physics_frame
    if not is_inside_tree():
        return
    var space := get_world_3d().direct_space_state
    var from: Vector3 = global_position + Vector3(0.0, 1.5, 0.0)
    var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -8.0, 0.0), 1)
    var hit: Dictionary = space.intersect_ray(query)
    if not hit.is_empty():
        global_position.y = hit["position"].y + 0.1


func _process(delta: float) -> void:
    _t += delta
    if _model_root != null:
        _model_root.rotation.y += delta * 1.2
        _model_root.position.y = 0.5 + sin(_t * 2.0) * 0.06


func _owns_base(player: Node) -> bool:
    if weapon == null or not ("weapon_loadout" in player):
        return false
    for owned in player.weapon_loadout:
        if owned != null and owned.get_base_name() == weapon.get_base_name():
            return true
    return false


func interact(player: Node) -> void:
    if weapon == null or not player.has_method("pickup_weapon"):
        return
    if _owns_base(player):
        return
    player.pickup_weapon(weapon, mag_ammo, reserve_ammo)
    queue_free()


func get_prompt_text() -> String:
    if weapon == null:
        return ""
    if not _player:
        _player = get_tree().get_first_node_in_group("player")
    if not _player or not ("weapon_loadout" in _player):
        return ""
    var wname: String = weapon.get_base_name()
    if _owns_base(_player):
        return "You already carry %s" % wname
    if _player.weapon_loadout.size() >= 2 and _player.current_weapon != null:
        return "Tap USE to swap %s for %s" % [_player.current_weapon.get_base_name(), wname]
    return "Tap USE to pick up %s" % wname

# END OF FILE
