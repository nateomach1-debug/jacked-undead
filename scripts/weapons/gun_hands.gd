extends RefCounted
## First-person hand + forearm that holds the equipped gun.
## Built by player_controller._update_weapon_model(). Right hand only.

# Radius of the grip the fingers wrap around. Raise for a bigger grip.
const GRIP_R: float = 0.04

# Rotates the hand around the grip (degrees). Try 20 or -20 if the
# fingers look wrong from behind.
const GRIP_YAW_DEG: float = 0.0

# Per-gun grip nudges, in camera-aligned space (x right, y up, z back).
# Example: "Revolver": Vector3(0.0, 0.01, 0.02)
const GRIP_OFFSETS: Dictionary = {
}


static func build(model: Node3D, camera: Node3D, kind: String) -> Node3D:
    if model == null or camera == null:
        return null
    var parent: Node = model.get_parent()
    if parent == null or not (parent is Node3D):
        return null

    var root := Node3D.new()
    root.name = "GunHands"
    parent.add_child(root)
    # Align with the camera so -z is always straight ahead, and cancel any
    # scale on the weapon mount.
    root.global_transform = Transform3D(
        camera.global_transform.basis.orthonormalized(),
        (parent as Node3D).global_position
    )

    var box: Array = [AABB(), false]
    _collect(model, root.global_transform.affine_inverse(), box)
    if not bool(box[1]):
        root.queue_free()
        return null
    var bounds: AABB = box[0]

    # Guess where the grip is: centred, near the back, low on the model.
    var mn: Vector3 = bounds.position
    var mx: Vector3 = bounds.end
    var length: float = mx.z - mn.z
    var back_frac: float = 0.28 if length < 0.45 else 0.2
    var grip_pos := Vector3(
        (mn.x + mx.x) * 0.5,
        mn.y + minf(bounds.size.y * 0.28, 0.09),
        mx.z - length * back_frac
    )
    var offset: Vector3 = GRIP_OFFSETS.get(kind, Vector3.ZERO)
    grip_pos += offset

    var skin := _mat(Color(0.72, 0.46, 0.31))
    var skin_dark := _mat(Color(0.62, 0.38, 0.25))
    var cloth := _mat(Color(0.13, 0.13, 0.15))
    var white := _mat(Color(0.95, 0.95, 0.95))
    var band_dark := _mat(Color(0.1, 0.1, 0.1))

    var held := Node3D.new()
    held.name = "RightHand"
    held.position = grip_pos
    held.rotation.y = deg_to_rad(GRIP_YAW_DEG)
    root.add_child(held)

    _build_hand(held, GRIP_R, skin, skin_dark)

    # Forearm runs from the wrist back toward the lower right (off screen).
    var wrist := Vector3(GRIP_R + 0.04, -0.06, 0.0)
    var back_dir: Vector3 = Vector3(0.5, -0.45, 0.75).normalized()
    var elbow: Vector3 = wrist + back_dir * 0.42
    _arm_piece(held, wrist, elbow, 0.042, 0.064, skin)
    # Muscle near the elbow end.
    _arm_piece(held, wrist + back_dir * 0.18, elbow, 0.058, 0.066, skin)
    # Wristband.
    _arm_piece(
        held, wrist + back_dir * 0.015, wrist + back_dir * 0.065,
        0.05, 0.052, white
    )
    _arm_piece(
        held, wrist + back_dir * 0.036, wrist + back_dir * 0.044,
        0.0535, 0.0535, band_dark
    )
    # Sleeve at the far end of the arm.
    _arm_piece(
        held, wrist + back_dir * 0.3, elbow + back_dir * 0.05,
        0.075, 0.08, cloth
    )
    return root


static func _collect(node: Node, to_local: Transform3D, box: Array) -> void:
    if node is MeshInstance3D:
        var mi: MeshInstance3D = node
        if mi.mesh != null and mi.is_visible_in_tree():
            var aabb: AABB = mi.mesh.get_aabb()
            var xf: Transform3D = to_local * mi.global_transform
            for i in range(8):
                var p: Vector3 = xf * aabb.get_endpoint(i)
                if bool(box[1]):
                    var cur: AABB = box[0]
                    box[0] = cur.expand(p)
                else:
                    box[0] = AABB(p, Vector3.ZERO)
                    box[1] = true
    for child in node.get_children():
        _collect(child, to_local, box)


static func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.6
    return m


static func _blob(
    parent: Node3D,
    radius: float,
    pos: Vector3,
    blob_scale: Vector3,
    material: Material
) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    item.mesh = mesh
    item.material_override = material
    item.position = pos
    item.scale = blob_scale
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)
    return item


static func _segment(
    parent: Node3D,
    from_pt: Vector3,
    to_pt: Vector3,
    radius: float,
    material: Material
) -> void:
    var dir: Vector3 = to_pt - from_pt
    var item := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = dir.length() + radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 4
    item.mesh = mesh
    item.material_override = material
    item.position = (from_pt + to_pt) * 0.5
    item.quaternion = Quaternion(Vector3.UP, dir.normalized())
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)


# Tapered cylinder from p_from (radius r_from) to p_to (radius r_to).
static func _arm_piece(
    parent: Node3D,
    p_from: Vector3,
    p_to: Vector3,
    r_from: float,
    r_to: float,
    material: Material
) -> void:
    var dir: Vector3 = p_to - p_from
    var item := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = r_from
    mesh.bottom_radius = r_to
    mesh.height = dir.length()
    mesh.radial_segments = 16
    mesh.rings = 1
    item.mesh = mesh
    item.material_override = material
    item.position = (p_from + p_to) * 0.5
    item.quaternion = Quaternion(Vector3.UP, (-dir).normalized())
    item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(item)


# Point on a circle around the grip. 0 deg = arm side (+x),
# 90 deg = front (away from player), -90 deg = toward player.
static func _wrap_pt(rr: float, deg: float, y: float) -> Vector3:
    var a: float = deg_to_rad(deg)
    return Vector3(rr * cos(a), y, -rr * sin(a))


static func _nail(
    parent: Node3D,
    p_from: Vector3,
    p_to: Vector3,
    finger_r: float,
    nail_len: float,
    nail_w: float,
    material: Material
) -> void:
    var d: Vector3 = (p_to - p_from).normalized()
    var mid: Vector3 = (p_from + p_to) * 0.5
    var n := Vector3(mid.x, 0.0, mid.z).normalized()
    var bx: Vector3 = (n - d * n.dot(d)).normalized()
    var bz: Vector3 = d
    var by: Vector3 = bz.cross(bx)

    var nail := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 1.0
    mesh.height = 2.0
    mesh.radial_segments = 12
    mesh.rings = 6
    nail.mesh = mesh
    nail.material_override = material
    nail.basis = Basis(bx * 0.0035, by * nail_w, bz * nail_len)
    nail.position = p_to - d * (nail_len * 0.55) + bx * (finger_r - 0.0008)
    nail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(nail)


static func _build_hand(
    parent: Node3D,
    r: float,
    skin_mat: Material,
    skin_dark: Material
) -> void:
    var rr: float = r + 0.014
    var nail_mat := _mat(Color(0.80, 0.58, 0.48))
    nail_mat.roughness = 0.3

    # Palm on the arm side, plus the heel that meets the wrist.
    var palm_hz: float = (r + 0.042) / 2.0 + 0.004
    var palm := _blob(
        parent, 1.0,
        Vector3(r + 0.03, 0.0, (0.018 - r) / 2.0),
        Vector3(0.028, 0.062, palm_hz), skin_mat
    )
    palm.name = "Palm"
    _blob(
        parent, 0.04,
        Vector3(r + 0.032, -0.05, -0.012),
        Vector3(0.9, 1.0, 1.1), skin_mat
    )

    # Four fingers, three segments each, wrapping the front of the grip.
    var finger_y: Array = [0.045, 0.015, -0.015, -0.045]
    var finger_scale: Array = [1.0, 1.08, 1.0, 0.85]
    var seg_len: Array = [0.048, 0.034, 0.028]

    for i in range(4):
        var fy: float = float(finger_y[i])
        var fscale: float = float(finger_scale[i])
        var base: float = 0.0145 if i < 3 else 0.0125

        var ang: float = 22.0
        var pts: Array = [_wrap_pt(rr, ang, fy)]
        for k in range(3):
            var step: float = rad_to_deg(float(seg_len[k]) * fscale / rr)
            ang += step
            pts.append(_wrap_pt(rr, ang, fy))

        var p0: Vector3 = pts[0]
        _blob(
            parent, base * 1.12,
            Vector3(p0.x * (1.0 + 0.002 / rr), fy, p0.z),
            Vector3.ONE, skin_dark
        )

        for k in range(3):
            var seg_r: float = base * (1.0 - 0.07 * float(k))
            var a_pt: Vector3 = pts[k]
            var b_pt: Vector3 = pts[k + 1]
            _segment(parent, a_pt, b_pt, seg_r, skin_mat)

        var tip_r: float = base * (1.0 - 0.07 * 2.0)
        var nail_len: float = 0.011 if i < 3 else 0.0095
        var nail_w: float = 0.0085 if i < 3 else 0.0075
        var n_from: Vector3 = pts[2]
        var n_to: Vector3 = pts[3]
        _nail(parent, n_from, n_to, tip_r, nail_len, nail_w, nail_mat)

    # Thumb on the player side: base pad + two segments.
    _blob(
        parent, 0.026,
        _wrap_pt(rr * 0.95, -6.0, -0.01),
        Vector3(1.0, 1.3, 1.0), skin_mat
    )
    var t0: Vector3 = _wrap_pt(rr, -10.0, 0.0)
    var t1: Vector3 = _wrap_pt(rr, -42.0, 0.02)
    var t2: Vector3 = _wrap_pt(rr, -72.0, 0.03)
    _segment(parent, t0, t1, 0.0185, skin_mat)
    _segment(parent, t1, t2, 0.0165, skin_mat)
    _nail(parent, t1, t2, 0.0165, 0.012, 0.0105, nail_mat)
