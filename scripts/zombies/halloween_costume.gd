extends Node
## Halloween zombie costumes. Lives only inside the Halloween map (added by
## halloween_builder.gd), so gym-map zombies are never touched. Watches for new
## zombies and gives each a random costume: pumpkin head, witch hat, mummy
## wraps or ghost sheet. Cheap: shared meshes and materials, no lights, no
## shadows, 3 to 10 small meshes per zombie.

const BASE_SCRIPT_END: String = "scripts/zombies/zombie.gd"

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}


func _ready() -> void:
    get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
    if n is Zombie:
        # Wait until the zombie has finished building its body in _ready().
        call_deferred("_dress", n)


func _dress(z) -> void:
    if not is_instance_valid(z):
        return
    if z.has_meta("halloween_costume"):
        return
    z.set_meta("halloween_costume", true)
    var s: Script = z.get_script() as Script
    if s == null or not s.resource_path.ends_with(BASE_SCRIPT_END):
        return  # Roid Rager and other subclasses are dressed separately
    var head: Node3D = z._head
    var upper: Node3D = z._upper
    if head == null or upper == null:
        return
    match randi() % 4:
        0:
            _pumpkin(head)
        1:
            _witch(head)
            _eyes(head)
        2:
            _mummy(head, upper)
            _eyes(head)
        _:
            _ghost(head, upper)


# ---------- costumes ----------

static func _pumpkin(head: Node3D) -> void:
    var orange := _mat("pumpkin", Color(0.95, 0.45, 0.05), 0.7, 0.0)
    var stem := _mat("pumpkin_stem", Color(0.2, 0.4, 0.1), 0.8, 0.0)
    var glow := _mat("pumpkin_glow", Color(1.0, 0.65, 0.1), 0.5, 3.0)
    _put(head, _sphere(), Vector3(0.0, 0.16, 0.0), orange, Vector3(0.44, 0.38, 0.44))
    _put(head, _box_mesh(Vector3(0.05, 0.09, 0.05)), Vector3(0.0, 0.37, 0.0), stem, Vector3.ONE, Vector3(0.0, 0.0, 0.25))
    var eye_mesh := _box_mesh(Vector3(0.07, 0.07, 0.03))
    _put(head, eye_mesh, Vector3(-0.09, 0.21, -0.195), glow, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.25))
    _put(head, eye_mesh, Vector3(0.09, 0.21, -0.195), glow, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.25))
    _put(head, _box_mesh(Vector3(0.2, 0.05, 0.03)), Vector3(0.0, 0.09, -0.19), glow)


static func _witch(head: Node3D) -> void:
    var felt := _mat("witch_felt", Color(0.12, 0.07, 0.16), 0.8, 0.0)
    var band := _mat("witch_band", Color(0.5, 0.15, 0.7), 0.6, 0.0)
    var hat := Node3D.new()
    hat.position = Vector3(0.0, 0.27, 0.0)
    hat.rotation.z = randf_range(-0.15, 0.15)
    head.add_child(hat)
    _put(hat, _cyl_mesh(0.2, 0.2, 0.015), Vector3.ZERO, felt)
    _put(hat, _cyl_mesh(0.0, 0.12, 0.34), Vector3(0.0, 0.17, 0.0), felt)
    _put(hat, _cyl_mesh(0.1, 0.118, 0.05), Vector3(0.0, 0.05, 0.0), band)
    var tip := Node3D.new()
    tip.position = Vector3(0.0, 0.33, 0.0)
    tip.rotation.z = -0.8
    hat.add_child(tip)
    _put(tip, _cyl_mesh(0.0, 0.04, 0.14), Vector3(0.0, 0.07, 0.0), felt)


static func _mummy(head: Node3D, upper: Node3D) -> void:
    var wrap := _mat("mummy_wrap", Color(0.84, 0.8, 0.68), 0.9, 0.0)
    # Head wraps: rings hugging the skull, leaving a slit for the eyes.
    for y in [0.07, 0.12, 0.25, 0.29]:
        var t: float = (float(y) - 0.15) / 0.145
        var r: float = 0.135 * sqrt(maxf(1.0 - t * t, 0.0)) + 0.012
        _put(head, _cyl_mesh(r, r, 0.03), Vector3(0.0, y, 0.0), wrap, Vector3.ONE, Vector3(0.0, 0.0, randf_range(-0.08, 0.08)))
    # A loose strip hanging from the head.
    _put(head, _box_mesh(Vector3(0.035, 0.28, 0.01)), Vector3(0.12, 0.02, -0.06), wrap, Vector3.ONE, Vector3(0.0, 0.0, 0.12))
    # Crossing strips on the chest.
    var strip := _box_mesh(Vector3(0.44, 0.035, 0.02))
    var dir: float = 1.0 if randf() < 0.5 else -1.0
    for y in [0.16, 0.28, 0.4]:
        _put(upper, strip, Vector3(0.0, y, -0.16), wrap, Vector3.ONE, Vector3(0.0, 0.0, dir * 0.3))
        dir = -dir


static func _ghost(head: Node3D, upper: Node3D) -> void:
    var sheet := _mat("ghost_sheet", Color(0.92, 0.94, 1.0), 0.9, 0.35)
    var black := _mat("ghost_black", Color(0.02, 0.02, 0.03), 0.9, 0.0)
    var glow := _mat("hw_eye", Color(1.0, 0.45, 0.05), 0.5, 4.0)
    # Sheet over the head and body.
    _put(head, _sphere(), Vector3(0.0, 0.12, 0.0), sheet, Vector3(0.4, 0.48, 0.4))
    _put(upper, _cyl_mesh(0.27, 0.4, 1.1), Vector3(0.0, 0.05, 0.0), sheet)
    # Cut-out eyes and mouth.
    for sx in [-1.0, 1.0]:
        _put(head, _sphere(), Vector3(sx * 0.075, 0.18, -0.178), black, Vector3(0.08, 0.12, 0.03))
        _put(head, _sphere(), Vector3(sx * 0.075, 0.18, -0.188), glow, Vector3(0.045, 0.065, 0.02))
    _put(head, _sphere(), Vector3(0.0, 0.07, -0.185), black, Vector3(0.07, 0.1, 0.03))


## Glowing orange eyes laid over the normal ones.
static func _eyes(head: Node3D) -> void:
    var glow := _mat("hw_eye", Color(1.0, 0.45, 0.05), 0.5, 4.0)
    var m := _box_mesh(Vector3(0.06, 0.045, 0.02))
    for sx in [-1.0, 1.0]:
        _put(head, m, Vector3(sx * 0.065, 0.19, -0.123), glow)


# ---------- shared meshes and materials ----------

static func _sphere() -> SphereMesh:
    var m = _meshes.get("sphere")
    if m == null:
        var s := SphereMesh.new()
        s.radius = 0.5
        s.height = 1.0
        s.radial_segments = 10
        s.rings = 5
        _meshes["sphere"] = s
        m = s
    return m as SphereMesh


static func _box_mesh(size: Vector3) -> BoxMesh:
    var key: String = "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
    var m = _meshes.get(key)
    if m == null:
        var b := BoxMesh.new()
        b.size = size
        _meshes[key] = b
        m = b
    return m as BoxMesh


static func _cyl_mesh(top: float, bottom: float, height: float) -> CylinderMesh:
    var key: String = "cyl_%.3f_%.3f_%.3f" % [top, bottom, height]
    var m = _meshes.get(key)
    if m == null:
        var c := CylinderMesh.new()
        c.top_radius = top
        c.bottom_radius = bottom
        c.height = height
        c.radial_segments = 10
        c.rings = 1
        _meshes[key] = c
        m = c
    return m as CylinderMesh


static func _mat(key: String, color: Color, rough: float, glow: float) -> StandardMaterial3D:
    var existing = _mats.get(key)
    if existing != null:
        return existing as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    _mats[key] = m
    return m


static func _put(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, scl: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat
    mi.position = pos
    mi.scale = scl
    mi.rotation = rot
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi
