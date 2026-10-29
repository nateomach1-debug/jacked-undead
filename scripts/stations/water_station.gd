extends Area3D
## "Water Station" - the wall-buy equivalent. Refills the player's current
## weapon (magazine AND reserve) in exchange for Gains. Price rises with
## the weapon's PR level (see ammo_scaling.gd). Wonder weapons have their
## own fixed prices (WONDER_AMMO_PRICES); a PR-racked wonder gun costs
## WONDER_PR_MULTIPLIER times that.
## The look is built in code (rounded cooler with a big water jug, gym
## band, taps, buttons, drip tray). The old Base/Jug/Spigot meshes from the
## scene are hidden; collision and the WATER label stay as they are.

@export var cost: int = 500
## No longer used: buying ammo now fully refills the magazine and reserve.
@export var refill_amount: int = 60

const WONDER_AMMO_PRICES: Dictionary = {
    "Br-Nh": 5000,
    "Frenemy": 2000,
}
const WONDER_PR_MULTIPLIER: float = 2.5

static var _mat_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


func _ready() -> void:
    _build_look()


func _price(player: Node) -> int:
    if player == null:
        return cost
    var weapon = player.current_weapon
    if weapon != null and weapon is WeaponData and (weapon as WeaponData).is_wonder:
        var w: WeaponData = weapon
        var base_price: int = int(WONDER_AMMO_PRICES.get(w.get_base_name(), cost))
        if w.pr_level > 0:
            return int(round(float(base_price) * WONDER_PR_MULTIPLIER))
        return base_price
    var AS = load("res://scripts/stations/ammo_scaling.gd")
    if AS == null:
        return cost
    return AS.scaled(cost, weapon)


func interact(player: Node) -> void:
    if not player.current_weapon:
        return
    if GameManager.try_spend_gains(_price(player)):
        player.refill_current_weapon_ammo()


func get_prompt_text() -> String:
    var player := get_tree().get_first_node_in_group("player")
    return "Tap USE to refill water (ammo) - %d Gains" % _price(player)


# ---------- look ----------

func _build_look() -> void:
    for n in ["Base", "Jug", "Spigot"]:
        var old := get_node_or_null(n) as Node3D
        if old != null:
            old.visible = false
    var tag := get_node_or_null("Label3D") as Label3D
    if tag != null:
        tag.position = Vector3(0.0, 2.0, 0.0)
        tag.modulate = Color(0.55, 0.85, 1.0)

    var root := Node3D.new()
    root.name = "WaterLook"
    add_child(root)

    var white := Color(0.88, 0.90, 0.93)
    var steel := Color(0.62, 0.65, 0.70)
    var dark := Color(0.05, 0.06, 0.08)
    var yellow := Color(1.0, 0.77, 0.0)
    var blue := Color(0.2, 0.6, 0.95)
    var red := Color(0.9, 0.15, 0.12)
    var blood := Color(0.35, 0.02, 0.02)

    # Cabinet: plinth, body, rounded corner posts, rounded shoulder
    _box(root, Vector3(0.62, 0.06, 0.62), Vector3(0.0, 0.03, 0.0), dark, 0.8)
    _box(root, Vector3(0.54, 0.84, 0.54), Vector3(0.0, 0.48, 0.0), white, 0.45)
    for cx in [-0.27, 0.27]:
        for cz in [-0.27, 0.27]:
            _cyl(root, 0.03, 0.84, Vector3(cx, 0.48, cz), white, Vector3.ZERO, 0.45)
    _sph(root, Vector3(0.58, 0.16, 0.58), Vector3(0.0, 0.92, 0.0), steel, 0.35, 0.5)

    # Gym band with label
    _box(root, Vector3(0.54, 0.07, 0.012), Vector3(0.0, 0.85, 0.275), yellow, 0.5)
    var band := Label3D.new()
    band.text = "REFILL"
    band.font_size = 20
    band.pixel_size = 0.003
    band.modulate = dark
    band.outline_size = 0
    band.position = Vector3(0.0, 0.85, 0.284)
    root.add_child(band)

    # Front panel: taps, buttons, power light, drip tray
    _box(root, Vector3(0.4, 0.44, 0.01), Vector3(0.0, 0.58, 0.275), dark, 0.7)
    _cyl(root, 0.022, 0.1, Vector3(-0.08, 0.62, 0.32), steel, Vector3(PI * 0.5, 0.0, 0.0), 0.3, 0.8)
    _cyl(root, 0.022, 0.1, Vector3(0.08, 0.62, 0.32), steel, Vector3(PI * 0.5, 0.0, 0.0), 0.3, 0.8)
    _cyl(root, 0.026, 0.03, Vector3(-0.08, 0.62, 0.37), blue, Vector3(PI * 0.5, 0.0, 0.0), 0.4, 0.0, 1.0)
    _cyl(root, 0.026, 0.03, Vector3(0.08, 0.62, 0.37), red, Vector3(PI * 0.5, 0.0, 0.0), 0.4, 0.0, 1.0)
    _box(root, Vector3(0.07, 0.05, 0.02), Vector3(-0.08, 0.74, 0.285), blue, 0.4, 0.0, 1.2)
    _box(root, Vector3(0.07, 0.05, 0.02), Vector3(0.08, 0.74, 0.285), red, 0.4, 0.0, 1.2)
    _sph(root, Vector3(0.03, 0.03, 0.03), Vector3(0.17, 0.77, 0.283), Color(0.3, 1.0, 0.4), 0.4, 0.0, 2.0)
    _box(root, Vector3(0.3, 0.025, 0.14), Vector3(0.0, 0.43, 0.31), steel, 0.35, 0.6)
    for gx in [-0.09, -0.03, 0.03, 0.09]:
        _box(root, Vector3(0.02, 0.006, 0.1), Vector3(gx, 0.445, 0.31), dark, 0.9)

    # Wear: blood smears low on the front
    _box(root, Vector3(0.04, 0.16, 0.006), Vector3(0.2, 0.22, 0.273), blood, 0.4, 0.0, Vector3(0.0, 0.0, 0.1))
    _box(root, Vector3(0.012, 0.1, 0.006), Vector3(0.13, 0.14, 0.273), blood, 0.4)
    _box(root, Vector3(0.25, 0.03, 0.006), Vector3(-0.1, 0.1, 0.273), Color(0.35, 0.2, 0.08), 0.9)

    # Big water jug: body, rounded shoulder, neck, cap, water inside
    var glass := Color(0.55, 0.8, 1.0, 0.45)
    _cyl(root, 0.22, 0.5, Vector3(0.0, 1.25, 0.0), glass, Vector3.ZERO, 0.15, 0.0, 0.4, 0.26)
    _sph(root, Vector3(0.44, 0.3, 0.44), Vector3(0.0, 1.5, 0.0), glass, 0.15, 0.0, 0.4)
    _cyl(root, 0.07, 0.1, Vector3(0.0, 1.66, 0.0), glass, Vector3.ZERO, 0.15, 0.0, 0.4)
    _cyl(root, 0.095, 0.05, Vector3(0.0, 1.72, 0.0), blue, Vector3.ZERO, 0.4)
    _cyl(root, 0.19, 0.32, Vector3(0.0, 1.16, 0.0), Color(0.3, 0.7, 1.0), Vector3.ZERO, 0.2, 0.0, 1.0)
    _sph(root, Vector3(0.04, 0.04, 0.04), Vector3(0.05, 1.36, 0.08), Color(0.8, 0.95, 1.0), 0.2, 0.0, 1.5)
    _sph(root, Vector3(0.03, 0.03, 0.03), Vector3(-0.07, 1.27, -0.05), Color(0.8, 0.95, 1.0), 0.2, 0.0, 1.5)
    _sph(root, Vector3(0.035, 0.035, 0.035), Vector3(0.0, 1.43, 0.02), Color(0.8, 0.95, 1.0), 0.2, 0.0, 1.5)


## Shared materials and meshes: all water stations reuse the same ones.
static func _mat(color: Color, rough: float, metal: float, glow: float) -> StandardMaterial3D:
    var key: String = "%s_%.2f_%.2f_%.2f" % [color.to_html(), rough, metal, glow]
    var cached = _mat_cache.get(key)
    if cached != null:
        return cached as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metal
    if color.a < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = Color(color.r, color.g, color.b, 1.0)
        m.emission_energy_multiplier = glow
    _mat_cache[key] = m
    return m


func _put(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, scl: Vector3, rot: Vector3) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    mi.rotation = rot
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rough: float = 0.6, metal: float = 0.0, glow_or_rot = 0.0, rot_arg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var glow: float = 0.0
    var rot: Vector3 = rot_arg
    if glow_or_rot is Vector3:
        rot = glow_or_rot
    else:
        glow = float(glow_or_rot)
    var key: String = "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
    var mesh = _mesh_cache.get(key)
    if mesh == null:
        var b := BoxMesh.new()
        b.size = size
        _mesh_cache[key] = b
        mesh = b
    return _put(parent, mesh as Mesh, pos, _mat(color, rough, metal, glow), Vector3.ONE, rot)


func _cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, rough: float = 0.6, metal: float = 0.0, glow: float = 0.0, bottom_radius: float = -1.0) -> MeshInstance3D:
    var br: float = radius if bottom_radius < 0.0 else bottom_radius
    var key: String = "cyl_%.3f_%.3f_%.3f" % [radius, br, height]
    var mesh = _mesh_cache.get(key)
    if mesh == null:
        var c := CylinderMesh.new()
        c.top_radius = radius
        c.bottom_radius = br
        c.height = height
        c.radial_segments = 14
        c.rings = 1
        _mesh_cache[key] = c
        mesh = c
    return _put(parent, mesh as Mesh, pos, _mat(color, rough, metal, glow), Vector3.ONE, rot)


## Ellipsoid with the given full size (width, height, depth).
func _sph(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rough: float = 0.6, metal: float = 0.0, glow: float = 0.0) -> MeshInstance3D:
    var mesh = _mesh_cache.get("sphere")
    if mesh == null:
        var s := SphereMesh.new()
        s.radius = 0.5
        s.height = 1.0
        s.radial_segments = 14
        s.rings = 7
        _mesh_cache["sphere"] = s
        mesh = s
    return _put(parent, mesh as Mesh, pos, _mat(color, rough, metal, glow), size, Vector3.ZERO)

# END OF FILE
