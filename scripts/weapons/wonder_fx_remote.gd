extends RefCounted
## Visual-only copy of the Br-Nh ring + spikes, played on the OTHER players'
## phones. No damage, no targeting: the shooter's phone does all of that.

const RING_TIME: float = 0.6
const SPIKE_TIME: float = 0.3
const SPIKE_COUNT: int = 10
const COLOR: Color = Color(0.65, 0.3, 1.0)


static func play_ring(scene: Node, pos: Vector3, face: Vector3, radius: float) -> void:
    if scene == null:
        return
    var fx := Node3D.new()
    scene.add_child(fx)
    var f := Vector3(face.x, 0.0, face.z)
    if f.length() < 0.01:
        f = Vector3(0, 0, 1)
    f = f.normalized()
    var side: Vector3 = Vector3.UP.cross(f).normalized()
    var up: Vector3 = side.cross(f).normalized()
    fx.global_transform = Transform3D(Basis(side, f, up), pos)

    var ring := MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = radius - 0.06
    torus.outer_radius = radius + 0.06
    ring.mesh = torus
    ring.material_override = _glow_mat(0.85, 3.0)
    fx.add_child(ring)
    ring.scale = Vector3.ONE * 1.6

    var spikes: Array = []
    for i in range(SPIKE_COUNT):
        var ang: float = TAU * float(i) / float(SPIKE_COUNT)
        var dir := Vector3(cos(ang), 0.0, sin(ang))
        var pivot := Node3D.new()
        var cone_mi := MeshInstance3D.new()
        var cone := CylinderMesh.new()
        cone.top_radius = 0.0
        cone.bottom_radius = 0.07
        cone.height = 0.9
        cone_mi.mesh = cone
        cone_mi.rotation_degrees = Vector3(-90, 0, 0)
        cone_mi.material_override = _glow_mat(1.0, 2.5)
        pivot.add_child(cone_mi)
        pivot.visible = false
        fx.add_child(pivot)
        pivot.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), dir * radius)
        spikes.append({"node": pivot, "dir": dir})

    var tween := fx.create_tween()
    tween.tween_property(ring, "scale", Vector3.ONE, RING_TIME).from(Vector3.ONE * 1.6)
    tween.tween_callback(func() -> void:
        for s in spikes:
            (s["node"] as Node3D).visible = true
    )
    tween.tween_method(func(t: float) -> void:
        var r: float = lerpf(radius, 0.2, t * t)
        for s in spikes:
            (s["node"] as Node3D).position = (s["dir"] as Vector3) * r
    , 0.0, 1.0, SPIKE_TIME)
    tween.tween_callback(func() -> void:
        _flash(scene, pos, 1.8)
        fx.queue_free()
    )


static func _flash(scene: Node, at: Vector3, radius: float) -> void:
    var fx := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    fx.mesh = sphere
    var mat: StandardMaterial3D = _glow_mat(0.6, 2.0)
    fx.material_override = mat
    scene.add_child(fx)
    fx.global_position = at
    fx.scale = Vector3.ONE * radius * 0.2
    var tween := fx.create_tween()
    tween.set_parallel(true)
    tween.tween_property(fx, "scale", Vector3.ONE * radius, 0.25)
    tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
    tween.chain().tween_callback(fx.queue_free)


static func _glow_mat(alpha: float, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, alpha)
    if alpha < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.emission_enabled = true
    m.emission = COLOR
    m.emission_energy_multiplier = energy
    return m
