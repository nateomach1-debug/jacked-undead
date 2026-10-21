extends RefCounted
## Shared building blocks for the upgraded gun models (rounded boxes, ellipsoids,
## capsules, tapered cylinders). All meshes and materials are cached in static
## dictionaries, so every gun reuses the same resources.
## Guns point muzzle toward -Z, up is +Y, grip near the origin.

## Material table: name -> [color, metallic, roughness, (emission energy)]
const MATS: Dictionary = {
    &"steel": [Color(0.66, 0.67, 0.72), 0.8, 0.32],
    &"nickel": [Color(0.82, 0.83, 0.86), 0.85, 0.25],
    &"gunmetal": [Color(0.22, 0.23, 0.27), 0.7, 0.4],
    &"blued": [Color(0.1, 0.11, 0.14), 0.75, 0.3],
    &"black": [Color(0.07, 0.07, 0.08), 0.15, 0.7],
    &"rubber": [Color(0.04, 0.04, 0.045), 0.0, 0.9],
    &"wood": [Color(0.42, 0.26, 0.13), 0.0, 0.6],
    &"wood_dark": [Color(0.3, 0.18, 0.09), 0.0, 0.65],
    &"wood_light": [Color(0.55, 0.36, 0.18), 0.0, 0.55],
    &"brass": [Color(0.8, 0.6, 0.2), 0.9, 0.3],
    &"olive": [Color(0.27, 0.32, 0.2), 0.2, 0.65],
    &"olive_dark": [Color(0.2, 0.24, 0.15), 0.2, 0.7],
    &"red": [Color(0.7, 0.12, 0.1), 0.2, 0.6],
    &"white": [Color(0.92, 0.92, 0.9), 0.0, 0.6],
    &"glow_orange": [Color(1.0, 0.45, 0.05), 0.0, 0.5, 2.0],
}

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


static func mat(key: StringName) -> StandardMaterial3D:
    if _mats.has(key):
        return _mats[key]
    var d: Array = MATS.get(key, MATS[&"gunmetal"])
    var m := StandardMaterial3D.new()
    m.albedo_color = d[0]
    m.metallic = d[1]
    m.roughness = d[2]
    if d.size() > 3:
        m.emission_enabled = true
        m.emission = d[0]
        m.emission_energy_multiplier = d[3]
    _mats[key] = m
    return m


static func _segs(r: float) -> int:
    if r > 0.03:
        return 20
    if r > 0.012:
        return 14
    return 10


static func _inst(parent: Node3D, mesh: Mesh, key: StringName, pos: Vector3, rot: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = mesh
    mi.material_override = mat(key)
    mi.position = pos
    mi.rotation_degrees = rot
    if scl != Vector3.ONE:
        mi.scale = scl
    parent.add_child(mi)
    return mi


## Empty node with its own position/rotation. Parts added to it use its local
## space (handy for tilted grips and magazines).
static func pivot(parent: Node3D, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    n.rotation_degrees = rot_deg
    parent.add_child(n)
    return n


# ------------------------------------------------------------ rounded box

static func _axis_coords(h: float, r: float) -> Array:
    return [-h, -h + r * 0.5, -h + r, h - r, h - r * 0.5, h]


static func _rbox_mesh(size: Vector3, radius: float) -> ArrayMesh:
    var h: Vector3 = size * 0.5
    var r: float = maxf(minf(radius, minf(h.x, minf(h.y, h.z))), 0.0005)
    var cache_key: String = "rb|%.5f|%.5f|%.5f|%.5f" % [size.x, size.y, size.z, r]
    if _meshes.has(cache_key):
        return _meshes[cache_key]
    var coords: Array = [_axis_coords(h.x, r), _axis_coords(h.y, r), _axis_coords(h.z, r)]
    var inner := Vector3(h.x - r, h.y - r, h.z - r)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var base: int = 0
    for axis in range(3):
        var ua: int = (axis + 1) % 3
        var va: int = (axis + 2) % 3
        var us: Array = coords[ua]
        var vs: Array = coords[va]
        var w: int = us.size()
        for sgn in [-1.0, 1.0]:
            for j in range(vs.size()):
                for i in range(w):
                    var v := Vector3.ZERO
                    v[axis] = sgn * h[axis]
                    v[ua] = us[i]
                    v[va] = vs[j]
                    var c := Vector3(clampf(v.x, -inner.x, inner.x), clampf(v.y, -inner.y, inner.y), clampf(v.z, -inner.z, inner.z))
                    var n: Vector3 = (v - c).normalized()
                    st.set_normal(n)
                    st.add_vertex(c + n * r)
            for j in range(vs.size() - 1):
                for i in range(w - 1):
                    var a: int = base + j * w + i
                    var b: int = a + 1
                    var c2: int = a + w
                    var d: int = c2 + 1
                    if sgn < 0.0:
                        st.add_index(a)
                        st.add_index(b)
                        st.add_index(d)
                        st.add_index(a)
                        st.add_index(d)
                        st.add_index(c2)
                    else:
                        st.add_index(a)
                        st.add_index(d)
                        st.add_index(b)
                        st.add_index(a)
                        st.add_index(c2)
                        st.add_index(d)
            base += vs.size() * w
    var mesh: ArrayMesh = st.commit()
    _meshes[cache_key] = mesh
    return mesh


## Box with rounded edges and corners.
static func rb(parent: Node3D, size: Vector3, pos: Vector3, key: StringName, radius: float = 0.004, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _rbox_mesh(size, radius), key, pos, rot)


# ------------------------------------------------------------ ellipsoid

static func _unit_sphere() -> SphereMesh:
    if _meshes.has("sphere"):
        return _meshes["sphere"]
    var m := SphereMesh.new()
    m.radius = 0.5
    m.height = 1.0
    m.radial_segments = 14
    m.rings = 7
    _meshes["sphere"] = m
    return m


## Ellipsoid given its three half-sizes (a ball when they are equal).
static func ell(parent: Node3D, half: Vector3, pos: Vector3, key: StringName, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _unit_sphere(), key, pos, rot, half * 2.0)


# ------------------------------------------------------------ cylinders

static func _cyl_mesh(r_top: float, r_bottom: float, length: float) -> CylinderMesh:
    var cache_key: String = "cy|%.5f|%.5f|%.5f" % [r_top, r_bottom, length]
    if _meshes.has(cache_key):
        return _meshes[cache_key]
    var m := CylinderMesh.new()
    m.top_radius = r_top
    m.bottom_radius = r_bottom
    m.height = length
    m.radial_segments = _segs(maxf(r_top, r_bottom))
    m.rings = 1
    _meshes[cache_key] = m
    return m


## Cylinder along Z. r_front is the muzzle (-Z) end.
static func cylz(parent: Node3D, r_front: float, r_back: float, length: float, pos: Vector3, key: StringName) -> MeshInstance3D:
    return _inst(parent, _cyl_mesh(r_back, r_front, length), key, pos, Vector3(90, 0, 0))


## Cylinder along X.
static func cylx(parent: Node3D, radius: float, length: float, pos: Vector3, key: StringName) -> MeshInstance3D:
    return _inst(parent, _cyl_mesh(radius, radius, length), key, pos, Vector3(0, 0, 90))


## Upright cylinder.
static func cyly(parent: Node3D, radius: float, length: float, pos: Vector3, key: StringName) -> MeshInstance3D:
    return _inst(parent, _cyl_mesh(radius, radius, length), key, pos, Vector3.ZERO)


# ------------------------------------------------------------ capsules

static func _cap_mesh(radius: float, length: float) -> CapsuleMesh:
    var h: float = maxf(length, radius * 2.0 + 0.0001)
    var cache_key: String = "ca|%.5f|%.5f" % [radius, h]
    if _meshes.has(cache_key):
        return _meshes[cache_key]
    var m := CapsuleMesh.new()
    m.radius = radius
    m.height = h
    m.radial_segments = _segs(radius)
    m.rings = 4
    _meshes[cache_key] = m
    return m


## Capsule along Z (rounded-end barrel, tube). length includes both end caps.
## tilt_deg adds extra pitch/yaw.
static func capz(parent: Node3D, radius: float, length: float, pos: Vector3, key: StringName, tilt_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _cap_mesh(radius, length), key, pos, Vector3(90.0 + tilt_deg.x, tilt_deg.y, tilt_deg.z))


## Capsule along X.
static func capx(parent: Node3D, radius: float, length: float, pos: Vector3, key: StringName, tilt_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _cap_mesh(radius, length), key, pos, Vector3(tilt_deg.x, tilt_deg.y, 90.0 + tilt_deg.z))


## Upright capsule (grips, triggers, posts). tilt_deg leans it.
static func capy(parent: Node3D, radius: float, length: float, pos: Vector3, key: StringName, tilt_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _inst(parent, _cap_mesh(radius, length), key, pos, tilt_deg)


# ------------------------------------------------------------ torus + guard

## Ring standing upright, seen as a loop from the side (rot (0,0,90) default).
static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, key: StringName, rot: Vector3 = Vector3(0, 0, 90)) -> MeshInstance3D:
    var cache_key: String = "to|%.5f|%.5f" % [inner, outer]
    var m: TorusMesh
    if _meshes.has(cache_key):
        m = _meshes[cache_key]
    else:
        m = TorusMesh.new()
        m.inner_radius = inner
        m.outer_radius = outer
        m.rings = 18
        m.ring_segments = 8
        _meshes[cache_key] = m
    return _inst(parent, m, key, pos, rot)


## Trigger guard ring with a curved trigger.
static func guard(parent: Node3D, pos: Vector3, scale_mult: float = 1.0, key: StringName = &"gunmetal") -> void:
    torus(parent, 0.014 * scale_mult, 0.022 * scale_mult, pos, key)
    capy(parent, 0.0042, 0.026 * scale_mult, pos + Vector3(0, 0.012, 0.004), &"steel", Vector3(-12, 0, 0))

# END OF FILE
