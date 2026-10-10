extends Area3D
## Membership counter: a zombie gym employee behind a reception counter.
## Step 1: look + USE prompt. The transfer menu comes in step 2.

const SKIN: Color = Color(0.45, 0.58, 0.4, 1)
const SKIN_DARK: Color = Color(0.3, 0.4, 0.28, 1)
const POLO: Color = Color(0.95, 0.75, 0.1, 1)
const PANTS: Color = Color(0.15, 0.15, 0.18, 1)
const BLOOD: Color = Color(0.5, 0.03, 0.03, 1)
const TRIM: Color = Color(0.95, 0.75, 0.1, 1)
const LOOK_RANGE: float = 9.0
const SIGN_TEXT: String = "MEMBERSHIPS"

var _employee: Node3D = null
var _head: Node3D = null
var _sign: Label3D = null
var _t: float = 0.0
var _sign_reset: float = 0.0
var _player: Node = null


func _ready() -> void:
    collision_layer = 2
    add_to_group("membership_counter")
    _build_counter()
    _build_employee()
    _build_sign()
    _build_collision()


func _process(delta: float) -> void:
    _t += delta
    if _employee != null:
        _employee.rotation.z = sin(_t * 0.9) * 0.025
    if _head != null:
        var yaw: float = 0.0
        if _player == null or not is_instance_valid(_player):
            _player = get_tree().get_first_node_in_group("player")
        if _player is Node3D:
            var d: Vector3 = (_player as Node3D).global_position - _head.global_position
            if d.length() < LOOK_RANGE:
                var local: Vector3 = global_transform.basis.inverse() * d
                yaw = clampf(atan2(local.x, local.z), -1.0, 1.0)
        _head.rotation.y = lerp_angle(_head.rotation.y, yaw, clampf(delta * 3.0, 0.0, 1.0))
        _head.rotation.x = 0.2 + sin(_t * 1.3) * 0.04
    if _sign_reset > 0.0:
        _sign_reset -= delta
        if _sign_reset <= 0.0 and _sign != null:
            _sign.text = SIGN_TEXT


# ---------- station interface (same as the supplement stations) ----------

func interact(_player_node: Node) -> void:
    if _sign != null:
        _sign.text = "MENU COMES NEXT"
        _sign_reset = 2.0


func get_prompt_text() -> String:
    return "Buy a teammate a membership\nTap USE to open the counter"


func get_prompt_color() -> Color:
    return TRIM


# ---------- look (all built in code) ----------

func _mat(color: Color, glow: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.7
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = size
    mi.mesh = bm
    mi.material_override = _mat(color, glow)
    mi.position = pos
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)
    return mi


func _label(parent: Node3D, text: String, pos: Vector3, px: float, size: int, color: Color) -> Label3D:
    var l := Label3D.new()
    l.text = text
    l.position = pos
    l.pixel_size = px
    l.font_size = size
    l.modulate = color
    l.outline_size = 6
    l.outline_modulate = Color(0, 0, 0, 1)
    parent.add_child(l)
    return l


func _build_counter() -> void:
    _box(self, Vector3(2.3, 0.95, 0.7), Vector3(0.0, 0.475, 0.0), Color(0.12, 0.12, 0.15, 1))
    _box(self, Vector3(2.5, 0.07, 0.85), Vector3(0.0, 0.985, 0.02), Color(0.35, 0.22, 0.12, 1))
    _box(self, Vector3(2.3, 0.05, 0.02), Vector3(0.0, 0.82, 0.355), TRIM, 1.0)
    _box(self, Vector3(2.3, 0.05, 0.02), Vector3(0.0, 0.1, 0.355), TRIM, 1.0)
    var logo: Label3D = _label(self, "JACKED UNDEAD GYM", Vector3(0.0, 0.46, 0.362), 0.004, 48, TRIM)
    logo.outline_size = 0
    # Card terminal on the counter top.
    _box(self, Vector3(0.18, 0.06, 0.28), Vector3(0.7, 1.05, 0.1), Color(0.02, 0.02, 0.03, 1))
    _box(self, Vector3(0.12, 0.01, 0.1), Vector3(0.7, 1.085, 0.05), Color(0.2, 1.0, 0.3, 1), 1.5)


func _build_employee() -> void:
    _employee = Node3D.new()
    _employee.name = "Employee"
    _employee.position = Vector3(0.0, 0.0, -0.85)
    add_child(_employee)

    # Legs and torso (yellow staff polo, bloody hem).
    for sx: float in [-1.0, 1.0]:
        _box(_employee, Vector3(0.17, 0.8, 0.2), Vector3(0.12 * sx, 0.4, 0.0), PANTS)
    _box(_employee, Vector3(0.5, 0.62, 0.28), Vector3(0.0, 1.1, 0.0), POLO)
    _box(_employee, Vector3(0.51, 0.12, 0.29), Vector3(0.0, 0.84, 0.0), BLOOD)
    _box(_employee, Vector3(0.2, 0.2, 0.29), Vector3(-0.12, 1.2, 0.0), BLOOD)
    # Name tag.
    _box(_employee, Vector3(0.15, 0.07, 0.01), Vector3(0.14, 1.28, 0.146), Color(0.95, 0.95, 0.95, 1))
    var tag: Label3D = _label(_employee, "STAFF", Vector3(0.14, 1.28, 0.153), 0.0018, 32, Color(0.1, 0.1, 0.1, 1))
    tag.outline_size = 0

    # Arms reaching forward, holding a clipboard.
    for sx: float in [-1.0, 1.0]:
        var arm := Node3D.new()
        arm.position = Vector3(0.33 * sx, 1.4, 0.0)
        arm.rotation.x = -1.2
        _employee.add_child(arm)
        _box(arm, Vector3(0.13, 0.55, 0.13), Vector3(0.0, -0.275, 0.0), SKIN)
        _box(arm, Vector3(0.15, 0.18, 0.15), Vector3(0.0, -0.09, 0.0), POLO)
        _box(arm, Vector3(0.14, 0.14, 0.14), Vector3(0.0, -0.57, 0.0), SKIN_DARK)
    _box(_employee, Vector3(0.3, 0.38, 0.03), Vector3(0.0, 1.2, 0.5), Color(0.35, 0.22, 0.12, 1))
    _box(_employee, Vector3(0.26, 0.32, 0.01), Vector3(0.0, 1.2, 0.52), Color(0.95, 0.95, 0.9, 1))

    # Head: hunched forward, glowing eyes, open mouth, staff visor.
    _head = Node3D.new()
    _head.name = "Head"
    _head.position = Vector3(0.0, 1.45, 0.02)
    _head.rotation.x = 0.2
    _employee.add_child(_head)
    _box(_head, Vector3(0.3, 0.3, 0.3), Vector3(0.0, 0.17, 0.0), SKIN)
    _box(_head, Vector3(0.34, 0.03, 0.22), Vector3(0.0, 0.27, 0.1), TRIM, 0.4)
    for sx: float in [-1.0, 1.0]:
        _box(_head, Vector3(0.05, 0.04, 0.01), Vector3(0.07 * sx, 0.19, 0.151), Color(1.0, 0.85, 0.2, 1), 2.5)
    _box(_head, Vector3(0.16, 0.05, 0.01), Vector3(0.0, 0.07, 0.151), Color(0.05, 0.0, 0.0, 1))
    _box(_head, Vector3(0.1, 0.015, 0.01), Vector3(0.0, 0.088, 0.152), Color(0.9, 0.9, 0.8, 1))


func _build_sign() -> void:
    _sign = _label(self, SIGN_TEXT, Vector3(0.0, 2.25, -0.85), 0.006, 56, TRIM)
    _sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _sign.outline_size = 8


func _build_collision() -> void:
    # Solid counter and employee (layer 1, like the other stations).
    var body := StaticBody3D.new()
    body.collision_layer = 1
    add_child(body)
    var cs := CollisionShape3D.new()
    var bs := BoxShape3D.new()
    bs.size = Vector3(2.5, 1.0, 0.85)
    cs.shape = bs
    cs.position = Vector3(0.0, 0.5, 0.02)
    body.add_child(cs)
    var es := CollisionShape3D.new()
    var ebs := BoxShape3D.new()
    ebs.size = Vector3(0.6, 1.8, 0.4)
    es.shape = ebs
    es.position = Vector3(0.0, 0.9, -0.85)
    body.add_child(es)
    # USE trigger in front of the counter (layer 2, like the supplement stations).
    var tc := CollisionShape3D.new()
    var ts := BoxShape3D.new()
    ts.size = Vector3(3.4, 2.4, 3.2)
    tc.shape = ts
    tc.position = Vector3(0.0, 1.2, 1.1)
    add_child(tc)
