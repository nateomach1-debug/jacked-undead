extends "res://scripts/managers/compound_props.gd"
# Gym Compound visual upgrade: dusk compound look, floors, walls, catwalk, ramps.
# Tuning knobs are the consts below (raise AMBIENT_ENERGY / MOON_ENERGY if too dark).

const AMBIENT_COLOR := Color(0.62, 0.65, 0.76)
const AMBIENT_ENERGY := 1.45
const MOON_COLOR := Color(0.72, 0.78, 1.0)
const MOON_ENERGY := 1.1
const MOON_SHADOWS := true
const LAMP_ENERGY := 2.2
const FOG_DENSITY := 0.0025


func _ready() -> void:
    _rng.seed = 424242
    _setup_env()
    _paint_base()
    _floors()
    _walls()
    _catwalk()
    _dress_ramp("WestRamp")
    _dress_ramp("EastStairs")
    _props()
    _posters()
    _signs()
    _fixtures()
    _blood()
    _doors()
    _lights()
    _flush()
    _late_rings.call_deferred()


func _setup_env() -> void:
    var root: Node = get_parent()
    var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
    if we != null and we.environment != null:
        var e: Environment = we.environment
        e.ssao_enabled = false
        e.glow_enabled = false
        e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        e.ambient_light_color = AMBIENT_COLOR
        e.ambient_light_energy = AMBIENT_ENERGY
        e.fog_enabled = true
        e.fog_light_color = Color(0.28, 0.25, 0.32)
        e.fog_density = FOG_DENSITY
        var sky: Sky = e.sky
        if sky != null and sky.sky_material is ProceduralSkyMaterial:
            var sm := sky.sky_material as ProceduralSkyMaterial
            sm.sky_top_color = Color(0.07, 0.09, 0.2)
            sm.sky_horizon_color = Color(0.5, 0.32, 0.3)
            sm.ground_horizon_color = Color(0.5, 0.32, 0.3)
            sm.ground_bottom_color = Color(0.05, 0.05, 0.07)
    var sun := root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
    if sun != null:
        sun.light_color = MOON_COLOR
        sun.light_energy = MOON_ENERGY
        sun.shadow_enabled = MOON_SHADOWS
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
        sun.directional_shadow_max_distance = 50.0


func _paint(path: String, col: Color) -> void:
    var mi := get_parent().get_node_or_null(path) as MeshInstance3D
    if mi != null:
        mi.material_override = _flat(col)


func _paint_base() -> void:
    _paint("GroundFloor/MeshInstance3D", Color(0.34, 0.34, 0.37))
    _paint("UpperCatwalk/MeshInstance3D", Color(0.17, 0.18, 0.2))
    for n in ["LedgeLeftMesh", "LedgeMidMesh", "LedgeRightMesh"]:
        _paint("UpperCatwalk/" + n, Color(0.3, 0.3, 0.34))
    for rn in ["WestRamp", "EastStairs"]:
        _paint(rn + "/MeshInstance3D", Color(0.2, 0.2, 0.23))
        _paint(rn + "/LedgeLeftMesh", Color(0.3, 0.3, 0.34))
        _paint(rn + "/LedgeRightMesh", Color(0.3, 0.3, 0.34))
    for n in ["PerimeterNorth", "PerimeterSouth", "PerimeterWest", "PerimeterEast"]:
        _paint("Walls/" + n + "/MeshInstance3D", Color(0.42, 0.42, 0.46))
    for n in ["ChokePointWest", "ChokePointEast", "FirstFloorWall", "SecondFloorWall"]:
        _paint("Walls/" + n + "/MeshInstance3D", Color(0.44, 0.2, 0.17))
    for n in ["DividerWestSouth", "DividerEastSouth", "DoorFrameWestNorth", "DoorFrameWestSouth", "DoorFrameEastNorth", "DoorFrameEastSouth"]:
        _paint("Walls/" + n + "/MeshInstance3D", Color(0.38, 0.38, 0.42))


func _floors() -> void:
    var y: float = 0.02
    var seam := Color(0.09, 0.09, 0.1)
    # start yard: rubber mat, tape border, seams, rings
    _fq(-30.0, -8.5, 30.0, 8.0, y, Color(0.16, 0.16, 0.18))
    _fq(-30.0, -8.5, 30.0, -8.35, 0.025, YELLOW)
    _fq(-30.0, 7.85, 30.0, 8.0, 0.025, YELLOW)
    _fq(-30.0, -8.5, -29.85, 8.0, 0.025, YELLOW)
    _fq(29.85, -8.5, 30.0, 8.0, 0.025, YELLOW)
    for i in range(-24, 25, 6):
        _fq(float(i) - 0.04, -8.35, float(i) + 0.04, 7.85, 0.025, seam)
    _fq(-29.85, -0.04, 29.85, 0.04, 0.025, seam)
    _ring(Vector3(0, 0.03, -1.0), 5.5, 5.75, YELLOW)
    _ring(Vector3(0, 0.03, -1.0), 2.4, 2.5, WHITE)
    # south hall: polished floor, red runner, lane dashes
    _fq(-14.5, 11.0, 14.5, 39.0, y, Color(0.27, 0.27, 0.3))
    _fq(-1.2, 11.5, 1.2, 38.5, 0.025, Color(0.32, 0.06, 0.06))
    _fq(-1.3, 11.5, -1.2, 38.5, 0.03, WHITE)
    _fq(1.2, 11.5, 1.3, 38.5, 0.03, WHITE)
    for z in range(13, 38, 3):
        _fq(-6.05, float(z), -5.95, float(z) + 1.5, 0.03, WHITE)
        _fq(5.95, float(z), 6.05, float(z) + 1.5, 0.03, WHITE)
    # wings: coloured rubber, seams, edge tape
    _fq(-38.5, 11.5, -16.0, 38.5, y, Color(0.07, 0.19, 0.21))
    _fq(16.0, 11.5, 38.5, 38.5, y, Color(0.2, 0.11, 0.07))
    for i in range(-34, -17, 4):
        _fq(float(i) - 0.04, 11.5, float(i) + 0.04, 38.5, 0.025, Color(0.04, 0.1, 0.12))
    for i in range(18, 37, 4):
        _fq(float(i) - 0.04, 11.5, float(i) + 0.04, 38.5, 0.025, Color(0.12, 0.06, 0.04))
    for z in range(15, 38, 4):
        _fq(-38.5, float(z) - 0.04, -16.0, float(z) + 0.04, 0.025, Color(0.04, 0.1, 0.12))
        _fq(16.0, float(z) - 0.04, 38.5, float(z) + 0.04, 0.025, Color(0.12, 0.06, 0.04))
    _fq(-16.15, 11.5, -16.0, 38.5, 0.03, TEAL)
    _fq(16.0, 11.5, 16.15, 38.5, 0.03, ORANGE)
    # lifting platforms in front of the east racks
    for z: float in [17.5, 21.0, 31.0]:
        _fq(35.4, z - 1.2, 37.8, z + 1.2, 0.03, Color(0.4, 0.28, 0.16))
        _fq(35.4, z - 0.6, 37.8, z + 0.6, 0.035, Color(0.08, 0.08, 0.09))
    # stair feet, choke gate, door thresholds
    for sx: float in [-25.0, 25.0]:
        _stripes(Vector3(sx, 0.03, 4.3), AX, AZ, AY, 4.0, 0.6, 0.5, YELLOW, DARK)
    _stripes(Vector3(0, 0.03, 8.3), AX, AZ, AY, 5.0, 0.4, 0.4, YELLOW, DARK)
    _stripes(Vector3(0, 0.03, 11.7), AX, AZ, AY, 5.0, 0.4, 0.4, YELLOW, DARK)
    for sx: float in [-14.0, 14.0]:
        _stripes(Vector3(sx, 0.03, 17.5), AZ, AX, AY, 5.0, 0.5, 0.5, YELLOW, DARK)


# one wall run: wainscot, accent stripe, cornice, pipe
func _run(r: Array) -> void:
    var a := Vector3(r[0], 0.0, r[1])
    var b := Vector3(r[2], 0.0, r[3])
    var nrm := Vector3(r[4], 0.0, r[5])
    var y0: float = r[6]
    var top: float = r[7]
    var wain: Color = r[8]
    var acc: Color = r[9]
    var mid: Vector3 = (a + b) * 0.5
    var w: float = a.distance_to(b)
    _wq(mid + AY * (y0 + 0.7), nrm, w, 1.4, wain)
    _wq(mid + AY * (y0 + 1.45), nrm, w, 0.1, acc, false, 0.035)
    _wq(mid + AY * (top - 0.45), nrm, w, 0.7, DARK, false, 0.03)
    _wq(mid + AY * (top - 0.95), nrm, w, 0.08, acc, false, 0.04)
    if top >= 10.0 and w > 6.0:
        _wb(mid + AY * (top - 1.7), nrm, w, 0.16, 0.16, Color(0.45, 0.2, 0.15))


func _walls() -> void:
    var per := Color(0.2, 0.2, 0.23)
    var brick := Color(0.27, 0.11, 0.1)
    # x0, z0, x1, z1, nx, nz, y0, top, wainscot, accent
    var runs: Array = [
        [-39.0, -10.5, -39.0, 9.0, 1.0, 0.0, 0.0, 10.0, per, YELLOW],
        [-39.0, 11.0, -39.0, 39.0, 1.0, 0.0, 0.0, 10.0, per, TEAL],
        [39.0, -10.5, 39.0, 9.0, -1.0, 0.0, 0.0, 10.0, per, YELLOW],
        [39.0, 11.0, 39.0, 39.0, -1.0, 0.0, 0.0, 10.0, per, ORANGE],
        [-39.0, 39.0, -15.5, 39.0, 0.0, -1.0, 0.0, 10.0, per, TEAL],
        [-14.5, 39.0, 14.5, 39.0, 0.0, -1.0, 0.0, 10.0, per, YELLOW],
        [15.5, 39.0, 39.0, 39.0, 0.0, -1.0, 0.0, 10.0, per, ORANGE],
        [-39.0, 9.0, -2.5, 9.0, 0.0, -1.0, 0.0, 10.0, brick, YELLOW],
        [2.5, 9.0, 39.0, 9.0, 0.0, -1.0, 0.0, 10.0, brick, YELLOW],
        [-39.0, 11.0, -15.5, 11.0, 0.0, 1.0, 0.0, 10.0, brick, TEAL],
        [-14.5, 11.0, -2.5, 11.0, 0.0, 1.0, 0.0, 10.0, brick, YELLOW],
        [2.5, 11.0, 14.5, 11.0, 0.0, 1.0, 0.0, 10.0, brick, YELLOW],
        [15.5, 11.0, 39.0, 11.0, 0.0, 1.0, 0.0, 10.0, brick, ORANGE],
        [-39.0, -10.5, 39.0, -10.5, 0.0, 1.0, 0.0, 5.0, brick, YELLOW],
        [-39.0, -19.0, -39.0, -8.5, 1.0, 0.0, 5.25, 10.0, per, YELLOW],
        [39.0, -19.0, 39.0, -8.5, -1.0, 0.0, 5.25, 10.0, per, YELLOW],
        [-39.0, -19.0, 39.0, -19.0, 0.0, 1.0, 5.25, 10.0, brick, YELLOW],
    ]
    # dividers: wing face points away from the hall, hall face points to the hall
    for s: float in [-1.0, 1.0]:
        var wing: Color = TEAL if s < 0.0 else ORANGE
        runs.append([s * 15.5, 11.0, s * 15.5, 15.0, s, 0.0, 0.0, 10.0, per, wing])
        runs.append([s * 15.5, 20.0, s * 15.5, 39.0, s, 0.0, 0.0, 10.0, per, wing])
        runs.append([s * 14.5, 11.0, s * 14.5, 15.0, -s, 0.0, 0.0, 10.0, per, YELLOW])
        runs.append([s * 14.5, 20.0, s * 14.5, 39.0, -s, 0.0, 0.0, 10.0, per, YELLOW])
    for r in runs:
        _run(r)


func _catwalk() -> void:
    var y: float = 5.265
    var x: float = -38.5
    while x < 38.6:
        _fq(x, -18.8, x + 0.12, -8.7, y, Color(0.3, 0.31, 0.34))
        x += 1.5
    var segs: Array = [[-39.0, -27.4], [-22.6, 22.6], [27.4, 39.0]]
    for sg in segs:
        var x0: float = sg[0]
        var x1: float = sg[1]
        _stripes(Vector3((x0 + x1) * 0.5, 5.275, -9.1), AX, AZ, AY, x1 - x0, 0.35, 0.7, YELLOW, DARK)
    # light strips under the overhang
    for sg in [[-30.0, -6.0], [6.0, 30.0]]:
        var x0: float = sg[0]
        var x1: float = sg[1]
        _q(Vector3(x0, 4.72, -9.65), Vector3(x1, 4.72, -9.65), Vector3(x1, 4.72, -9.35), Vector3(x0, 4.72, -9.35), -AY, Color(1.0, 0.95, 0.8), true)


# reads the real node transform, so a mirrored scene transform cannot flip it
func _dress_ramp(node_name: String) -> void:
    var rn := get_parent().get_node_or_null(node_name) as Node3D
    if rn == null:
        return
    var xf: Transform3D = rn.global_transform
    var up: Vector3 = xf.basis.y.normalized()
    var along: Vector3 = xf.basis.z.normalized()
    for i in 10:
        var t0: float = -4.9 + float(i)
        var a: Vector3 = xf * Vector3(-1.6, 0.275, t0)
        var b: Vector3 = xf * Vector3(1.6, 0.275, t0)
        var c: Vector3 = xf * Vector3(1.6, 0.275, t0 + 0.18)
        var d: Vector3 = xf * Vector3(-1.6, 0.275, t0 + 0.18)
        _q(a, b, c, d, up, YELLOW if i % 3 == 0 else Color(0.09, 0.09, 0.1))
    for sx: float in [-1.0, 1.0]:
        var cc: Vector3 = xf * Vector3(sx * 1.63, 0.6, 0.0)
        var inward: Vector3 = (xf.basis * Vector3(-sx, 0.0, 0.0)).normalized()
        _stripes(cc, along, up, inward, 10.8, 0.3, 0.6, YELLOW, DARK)


# only 6 real lights (phone limit per mesh); everything else is fake glow
func _lights() -> void:
    _lamp(Vector3(-26, 7.5, 0), Color(1.0, 0.86, 0.68), LAMP_ENERGY, 30.0)
    _lamp(Vector3(26, 7.5, 0), Color(1.0, 0.86, 0.68), LAMP_ENERGY, 30.0)
    _lamp(Vector3(0, 7.5, 25), Color(1.0, 0.9, 0.7), LAMP_ENERGY, 28.0)
    _lamp(Vector3(-27, 7.5, 25), Color(0.6, 0.9, 1.0), LAMP_ENERGY, 26.0)
    _lamp(Vector3(27, 7.5, 25), Color(1.0, 0.7, 0.45), LAMP_ENERGY, 26.0)
    _lamp(Vector3(0, 8.5, -14), Color(0.85, 0.9, 1.0), LAMP_ENERGY, 26.0)

# END OF FILE
