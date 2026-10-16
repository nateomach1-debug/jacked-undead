extends Node3D
## Shared toolkit for generated maps: seeded random numbers, one batched
## vertex-colour mesh for all walls and floors, wall colliders, scene helpers.

const WALL_H: float = 8.0
const WALL_T: float = 1.0

## Set this (via load("res://scripts/mapgen/map_gen_base.gd").next_seed = N)
## before loading a generated map to force a seed (co-op, replays).
static var next_seed: int = 0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var seed_used: int = 0

var _st: SurfaceTool
var _body: StaticBody3D


func init_seed(requested: int) -> void:
    var s: int = requested
    if next_seed != 0:
        s = next_seed
        next_seed = 0
    if s == 0:
        s = randi_range(100000, 999999)
    seed_used = s
    rng.seed = s
    print("MapGen seed: ", s)


func shuffled(src: Array) -> Array:
    var a: Array = src.duplicate()
    for i in range(a.size() - 1, 0, -1):
        var j: int = rng.randi() % (i + 1)
        var t = a[i]
        a[i] = a[j]
        a[j] = t
    return a


func make_scene(path: String) -> Node3D:
    var ps = load(path)
    if ps == null:
        push_warning("MapGen: missing scene " + path)
        return null
    return ps.instantiate() as Node3D


## Rotation (yaw) that turns a station's front toward dir.
func yaw_facing(dir: Vector3, front_is_minus_z: bool) -> float:
    if front_is_minus_z:
        return atan2(-dir.x, -dir.z)
    return atan2(dir.x, dir.z)


func begin_geometry() -> void:
    _st = SurfaceTool.new()
    _st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _body = StaticBody3D.new()
    _body.name = "Walls"
    add_child(_body)


func end_geometry() -> void:
    var mesh: ArrayMesh = _st.commit()
    var mi: MeshInstance3D = MeshInstance3D.new()
    mi.name = "WallMesh"
    mi.mesh = mesh
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 1.0
    mi.material_override = mat
    add_child(mi)


## A solid box: visible, and (optionally) with a collider.
func add_solid(center: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
    _add_box_mesh(center, size, color)
    if collide:
        add_collider(center, size)


func add_collider(center: Vector3, size: Vector3) -> void:
    var cs: CollisionShape3D = CollisionShape3D.new()
    var bs: BoxShape3D = BoxShape3D.new()
    bs.size = size
    cs.shape = bs
    cs.position = center
    _body.add_child(cs)


func _shade(col: Color, f: float) -> Color:
    return Color(col.r * f, col.g * f, col.b * f, 1.0)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
    for v in [a, c, b, a, d, c]:
        _st.set_normal(n)
        _st.set_color(col)
        _st.add_vertex(v)


func _add_box_mesh(c: Vector3, s: Vector3, col: Color) -> void:
    var h: Vector3 = s * 0.5
    var cz: Color = _shade(col, 0.85)
    var cx: Color = _shade(col, 0.92)
    _quad(c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z), Vector3(0, 0, 1), cz)
    _quad(c + Vector3(h.x, -h.y, -h.z), c + Vector3(-h.x, -h.y, -h.z), c + Vector3(-h.x, h.y, -h.z), c + Vector3(h.x, h.y, -h.z), Vector3(0, 0, -1), cz)
    _quad(c + Vector3(h.x, -h.y, h.z), c + Vector3(h.x, -h.y, -h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(h.x, h.y, h.z), Vector3(1, 0, 0), cx)
    _quad(c + Vector3(-h.x, -h.y, -h.z), c + Vector3(-h.x, -h.y, h.z), c + Vector3(-h.x, h.y, h.z), c + Vector3(-h.x, h.y, -h.z), Vector3(-1, 0, 0), cx)
    _quad(c + Vector3(-h.x, h.y, h.z), c + Vector3(h.x, h.y, h.z), c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z), Vector3(0, 1, 0), col)

# END OF FILE
