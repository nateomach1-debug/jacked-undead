extends Area3D
## A gun dropped on the floor when you swap it out at the 2-weapon limit.
## Keeps the gun's ammo (and PR level / attachments, which live on the WeaponData).
## A glowing ring + light beam marks it; the color shows its rarity.
## If you already carry this gun, a higher-rarity version can swap in for your copy.

## Rarity colors. A weapon's rarity is read from its "rarity" meta
## (weapon.set_meta("rarity", "rare")). No meta = common (white).
const RARITY_COLORS: Dictionary = {
    "common": Color(1.0, 1.0, 1.0),
    "uncommon": Color(0.3, 1.0, 0.35),
    "rare": Color(0.3, 0.6, 1.0),
    "epic": Color(0.7, 0.35, 1.0),
    "legendary": Color(1.0, 0.75, 0.15),
}

var weapon: WeaponData
var mag_ammo: int = 0
var reserve_ammo: int = 0

var _model_root: Node3D
var _label: Label3D
var _ring_mat: StandardMaterial3D
var _t: float = 0.0
var _player: Node


func setup(w: WeaponData, mag: int, reserve: int) -> void:
    weapon = w
    mag_ammo = mag
    reserve_ammo = reserve


func _rarity_color() -> Color:
    var key: String = "common"
    if weapon != null:
        key = str(weapon.get_meta("rarity", "common"))
    return RARITY_COLORS.get(key, RARITY_COLORS["common"])


func _rarity_name(w: WeaponData) -> String:
    var key: String = "common"
    if w != null:
        key = str(w.get_meta("rarity", "common"))
    return key.capitalize()


func _ready() -> void:
    collision_layer = 2
    collision_mask = 0
    monitoring = false
    _player = get_tree().get_first_node_in_group("player")
    var col: Color = _rarity_color()

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

    _build_ring(col)

    _label = Label3D.new()
    _label.text = weapon.get_base_name() if weapon != null else "Weapon"
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.font_size = 48
    _label.pixel_size = 0.004
    _label.outline_size = 12
    _label.modulate = col
    _label.position = Vector3(0.0, 1.2, 0.0)
    add_child(_label)

    _drop_to_floor()


func _build_ring(col: Color) -> void:
    # Glowing ring flat on the floor (the node sits about 0.1 above the floor).
    var torus := TorusMesh.new()
    torus.inner_radius = 0.62
    torus.outer_radius = 0.74
    torus.rings = 32
    torus.ring_segments = 8
    _ring_mat = StandardMaterial3D.new()
    _ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _ring_mat.albedo_color = col
    _ring_mat.emission_enabled = true
    _ring_mat.emission = col
    _ring_mat.emission_energy_multiplier = 2.5
    var ring := MeshInstance3D.new()
    ring.mesh = torus
    ring.material_override = _ring_mat
    ring.position = Vector3(0.0, -0.07, 0.0)
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ring)

    # Faint vertical beam so the gun can be spotted from far away.
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.3
    cyl.bottom_radius = 0.3
    cyl.height = 2.6
    cyl.radial_segments = 16
    var beam_mat := StandardMaterial3D.new()
    beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    beam_mat.albedo_color = Color(col.r, col.g, col.b, 0.12)
    var beam := MeshInstance3D.new()
    beam.mesh = cyl
    beam.material_override = beam_mat
    beam.position = Vector3(0.0, 1.2, 0.0)
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(beam)


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
    if _ring_mat != null:
        _ring_mat.emission_energy_multiplier = 2.4 + sin(_t * 3.0) * 0.8


func _owns_base(player: Node) -> bool:
    if weapon == null or not ("weapon_loadout" in player):
        return false
    for owned in player.weapon_loadout:
        if owned != null and owned.get_base_name() == weapon.get_base_name():
            return true
    return false


func _owned_copy(player: Node) -> WeaponData:
    if weapon == null or not ("weapon_loadout" in player):
        return null
    for owned in player.weapon_loadout:
        if owned != null and owned.get_base_name() == weapon.get_base_name():
            return owned
    return null


func _is_upgrade(player: Node) -> bool:
    if weapon == null or not player.has_method("is_rarity_upgrade"):
        return false
    return player.is_rarity_upgrade(weapon)


func interact(player: Node) -> void:
    if weapon == null or not player.has_method("pickup_weapon"):
        return
    if _owns_base(player) and not _is_upgrade(player):
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
        if _is_upgrade(_player):
            return "Tap USE to swap your %s (%s) for %s (%s)" % [wname, _rarity_name(_owned_copy(_player)), wname, _rarity_name(weapon)]
        return "You already carry %s" % wname
    if _player.weapon_loadout.size() >= 2 and _player.current_weapon != null:
        return "Tap USE to swap %s for %s" % [_player.current_weapon.get_base_name(), wname]
    return "Tap USE to pick up %s" % wname

# END OF FILE
