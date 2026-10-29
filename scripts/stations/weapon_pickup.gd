extends Area3D
## A gun dropped on the floor when you swap it out at the 2-weapon limit.
## Keeps the gun's ammo (and PR level / attachments, which live on the WeaponData).
## A glowing ring + light beam marks it; the color shows its rarity.
## If you already carry this gun, a higher-rarity version can swap in for your copy.
## You have to look at the ring on the floor to use it (so stations and
## loot lockers behind a dropped gun still work).
## Dropped guns spread out so they never sit on top of each other.
## Wonder weapons get a rainbow ring, beam and name.

## Rarity colors. A weapon's rarity is read from its "rarity" meta
## (weapon.set_meta("rarity", "rare")). No meta = common (white).
const RARITY_COLORS: Dictionary = {
    "common": Color(1.0, 1.0, 1.0),
    "uncommon": Color(0.3, 1.0, 0.35),
    "rare": Color(0.3, 0.6, 1.0),
    "epic": Color(0.7, 0.35, 1.0),
    "legendary": Color(1.0, 0.75, 0.15),
}

## Ring size (matches the torus below). The click area is a flat disc this wide.
const RING_INNER: float = 0.62
const RING_OUTER: float = 0.74

## Closest two dropped guns may be (center to center, meters). A bit more
## than the ring width (1.48) so the rings never overlap.
const MIN_SPACING: float = 1.7

## Names that count as wonder weapons (rainbow colors), on top of the
## is_wonder flag and the WONDER fire mode.
const WONDER_NAMES: Array = ["Br-Nh", "Frenemy", "Bombie"]

const RAINBOW_RING_SHADER: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float energy = 1.0;
varying vec3 lp;

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void vertex() {
    lp = VERTEX;
}

void fragment() {
    float hue = fract(atan(lp.z, lp.x) / 6.2831853 + TIME * 0.25);
    vec3 c = hsv2rgb(vec3(hue, 0.85, 1.0));
    ALBEDO = c * energy;
    EMISSION = c * energy;
}
"""

var weapon: WeaponData
var mag_ammo: int = 0
var reserve_ammo: int = 0

var _model_root: Node3D
var _label: Label3D
var _ring_mat: StandardMaterial3D
var _ring_shader_mat: ShaderMaterial
var _beam_mat: StandardMaterial3D
var _t: float = 0.0
var _player: Node


func setup(w: WeaponData, mag: int, reserve: int) -> void:
    weapon = w
    mag_ammo = mag
    reserve_ammo = reserve


func _is_wonder_weapon() -> bool:
    if weapon == null:
        return false
    if weapon.is_wonder:
        return true
    if weapon.fire_mode == WeaponData.FireMode.WONDER:
        return true
    return WONDER_NAMES.has(weapon.get_base_name()) or WONDER_NAMES.has(weapon.weapon_name)


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
    add_to_group("weapon_pickups")
    _player = get_tree().get_first_node_in_group("player")
    var col: Color = _rarity_color()

    # Flat disc on the floor, same size as the ring. Only aiming at the ring
    # selects this gun; the floating model and beam do not block anything.
    var shape := CollisionShape3D.new()
    var disc := CylinderShape3D.new()
    disc.radius = RING_OUTER
    disc.height = 0.12
    shape.shape = disc
    shape.position = Vector3(0.0, -0.07, 0.0)
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
    torus.inner_radius = RING_INNER
    torus.outer_radius = RING_OUTER
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

    # Wonder weapons: swap in the rainbow gradient shader for the ring.
    if _is_wonder_weapon():
        var shader := Shader.new()
        shader.code = RAINBOW_RING_SHADER
        _ring_shader_mat = ShaderMaterial.new()
        _ring_shader_mat.shader = shader
        ring.material_override = _ring_shader_mat

    # Faint vertical beam so the gun can be spotted from far away.
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.3
    cyl.bottom_radius = 0.3
    cyl.height = 2.6
    cyl.radial_segments = 16
    _beam_mat = StandardMaterial3D.new()
    _beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    _beam_mat.albedo_color = Color(col.r, col.g, col.b, 0.12)
    var beam := MeshInstance3D.new()
    beam.mesh = cyl
    beam.material_override = _beam_mat
    beam.position = Vector3(0.0, 1.2, 0.0)
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(beam)


## Straight down from above a point to find the floor (layer 1). Empty if none.
func _floor_hit(at: Vector3) -> Dictionary:
    var space := get_world_3d().direct_space_state
    var from: Vector3 = at + Vector3(0.0, 1.5, 0.0)
    var query := PhysicsRayQueryParameters3D.create(from, from + Vector3(0.0, -8.0, 0.0), 1)
    return space.intersect_ray(query)


func _drop_to_floor() -> void:
    await get_tree().physics_frame
    if not is_inside_tree():
        return
    var hit: Dictionary = _floor_hit(global_position)
    if not hit.is_empty():
        global_position.y = hit["position"].y + 0.1
    _spread_from_others()


## True if another dropped gun is too close to point p (flat distance).
func _is_crowded(p: Vector3) -> bool:
    for other in get_tree().get_nodes_in_group("weapon_pickups"):
        if other == self or not is_instance_valid(other):
            continue
        var o := other as Node3D
        if o == null:
            continue
        var dx: float = o.global_position.x - p.x
        var dz: float = o.global_position.z - p.z
        if Vector2(dx, dz).length() < MIN_SPACING:
            return true
    return false


## True if a wall or prop blocks the straight path between two points.
func _blocked_between(a: Vector3, b: Vector3) -> bool:
    var space := get_world_3d().direct_space_state
    var lift := Vector3(0.0, 0.5, 0.0)
    var query := PhysicsRayQueryParameters3D.create(a + lift, b + lift, 1)
    return not space.intersect_ray(query).is_empty()


## If this gun landed on top of another one, slide it to the nearest free
## spot on the floor (widening circles around where it landed). First pass
## avoids spots behind walls; if none is found, the second pass allows them.
func _spread_from_others() -> void:
    if not _is_crowded(global_position):
        return
    var origin: Vector3 = global_position
    for check_walls in [true, false]:
        for ring in range(1, 7):
            var dist: float = MIN_SPACING * float(ring)
            var count: int = 6 * ring
            for i in range(count):
                var a: float = TAU * float(i) / float(count)
                var cand: Vector3 = origin + Vector3(cos(a) * dist, 0.0, sin(a) * dist)
                var hit: Dictionary = _floor_hit(cand)
                if hit.is_empty():
                    continue
                var fy: float = float(hit["position"].y) + 0.1
                # Same floor level only (not up on a ledge or down a drop).
                if absf(fy - origin.y) > 0.4:
                    continue
                cand.y = fy
                if check_walls and _blocked_between(origin, cand):
                    continue
                if _is_crowded(cand):
                    continue
                global_position = cand
                return


func _process(delta: float) -> void:
    _t += delta
    if _model_root != null:
        _model_root.rotation.y += delta * 1.2
        _model_root.position.y = 0.5 + sin(_t * 2.0) * 0.06

    if _is_wonder_weapon():
        # Rainbow name, beam and ring.
        var hue: float = fposmod(_t * 0.3, 1.0)
        if _label != null:
            _label.modulate = Color.from_hsv(hue, 0.65, 1.0)
        if _beam_mat != null:
            var bc: Color = Color.from_hsv(hue, 0.8, 1.0)
            _beam_mat.albedo_color = Color(bc.r, bc.g, bc.b, 0.12)
        if _ring_shader_mat != null:
            _ring_shader_mat.set_shader_parameter("energy", 1.2 + sin(_t * 3.0) * 0.3)
    elif _ring_mat != null:
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
