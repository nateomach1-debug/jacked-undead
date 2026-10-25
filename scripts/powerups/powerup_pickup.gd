extends Node3D
## A floating gym power-up on the floor: colored ring, light beam, spinning
## weight plate and a name label. Walk over it to collect (no USE tap).
## Blinks for the last seconds, then disappears.
## Co-op: a joiner's pickup waits for the host's answer after being touched.

const PICKUP_RADIUS: float = 1.6
const MAX_HEIGHT_GAP: float = 2.2
const SPIN_SPEED: float = 2.2
const HOST_WAIT: float = 2.0   # seconds a joiner waits for the host before trying again

var type_id: String = ""
var drop_id: int = 0
var label_text: String = ""
var color: Color = Color.WHITE
var life: float = 30.0
var blink_time: float = 8.0
var manager: Node = null

var _t: float = 0.0
var _taken: bool = false
var _wait_left: float = 0.0
var _pivot: Node3D = null
var _text: Label3D = null


func setup(m: Node, id: String, text: String, col: Color, despawn: float, blink: float) -> void:
    manager = m
    type_id = id
    label_text = text
    color = col
    life = despawn
    blink_time = blink


## Joiner: asked the host to collect this; keep the pickup until the host answers.
func wait_for_host() -> void:
    _wait_left = HOST_WAIT


func _ready() -> void:
    _build()


func _flat(col: Color, alpha: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = Color(col.r, col.g, col.b, alpha)
    if alpha < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m


func _build() -> void:
    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.55
    torus.outer_radius = 0.72
    ring.mesh = torus
    ring.material_override = _flat(color, 1.0)
    ring.position = Vector3(0.0, 0.03, 0.0)
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(ring)

    var beam := MeshInstance3D.new()
    var cyl := CylinderMesh.new()
    cyl.top_radius = 0.07
    cyl.bottom_radius = 0.07
    cyl.height = 6.0
    cyl.radial_segments = 8
    cyl.rings = 1
    beam.mesh = cyl
    beam.material_override = _flat(color, 0.22)
    beam.position = Vector3(0.0, 3.0, 0.0)
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(beam)

    _pivot = Node3D.new()
    _pivot.position = Vector3(0.0, 1.0, 0.0)
    add_child(_pivot)

    var glow := StandardMaterial3D.new()
    glow.albedo_color = color
    glow.emission_enabled = true
    glow.emission = color
    glow.emission_energy_multiplier = 1.6
    glow.roughness = 0.4

    var plate := MeshInstance3D.new()
    var plate_mesh := CylinderMesh.new()
    plate_mesh.top_radius = 0.34
    plate_mesh.bottom_radius = 0.34
    plate_mesh.height = 0.08
    plate.mesh = plate_mesh
    plate.material_override = glow
    plate.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _pivot.add_child(plate)

    var hub_mat := StandardMaterial3D.new()
    hub_mat.albedo_color = Color(0.12, 0.12, 0.14)
    hub_mat.roughness = 0.6
    var hub := MeshInstance3D.new()
    var hub_mesh := CylinderMesh.new()
    hub_mesh.top_radius = 0.09
    hub_mesh.bottom_radius = 0.09
    hub_mesh.height = 0.12
    hub.mesh = hub_mesh
    hub.material_override = hub_mat
    hub.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _pivot.add_child(hub)

    _text = Label3D.new()
    _text.text = label_text
    _text.font_size = 56
    _text.pixel_size = 0.005
    _text.outline_size = 14
    _text.modulate = color
    _text.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
    _text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _text.position = Vector3(0.0, 1.8, 0.0)
    add_child(_text)

    var light := OmniLight3D.new()
    light.light_color = color
    light.light_energy = 1.0
    light.omni_range = 4.0
    light.shadow_enabled = false
    light.position = Vector3(0.0, 1.0, 0.0)
    add_child(light)


func _process(delta: float) -> void:
    if _pivot == null:
        return
    if _taken:
        # Joiner waiting for the host: if no answer comes, allow another try.
        if _wait_left > 0.0:
            _wait_left -= delta
            if _wait_left <= 0.0:
                _taken = false
        return
    _t += delta
    life -= delta
    if life <= 0.0:
        if manager != null and is_instance_valid(manager) and manager.has_method("on_pickup_expired"):
            manager.call("on_pickup_expired", self)
        queue_free()
        return
    _pivot.rotation.y += delta * SPIN_SPEED
    _pivot.position.y = 1.0 + sin(_t * 2.5) * 0.12
    if life < blink_time:
        var rate: float = 6.0 if life > 3.0 else 12.0
        var on: bool = int(_t * rate) % 2 == 0
        _pivot.visible = on
        _text.visible = on
    _check_pickup()


func _check_pickup() -> void:
    for n in get_tree().get_nodes_in_group("player"):
        var p := n as Node3D
        if p == null or not is_instance_valid(p):
            continue
        if bool(p.get("is_downed")) or bool(p.get("is_dead")):
            continue
        var d: Vector3 = p.global_position - global_position
        if absf(d.y) > MAX_HEIGHT_GAP:
            continue
        if Vector2(d.x, d.z).length() <= PICKUP_RADIUS:
            _taken = true
            if manager != null and is_instance_valid(manager):
                manager.call("collect", self)
            # A joiner keeps the pickup until the host answers.
            if _wait_left <= 0.0:
                queue_free()
            return
