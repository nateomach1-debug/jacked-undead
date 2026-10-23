extends "res://scripts/managers/compound_props.gd"
# Building map visual upgrade (needs compound_props.gd from the Gym Compound upgrade).
# Lights, doors and blockers are made at once; wall decor is placed after a raycast scan.
# After the scan, 3 zombie spawn points are made behind each buyable door (zone spawns).

const AMBIENT_COLOR := Color(0.55, 0.58, 0.72)
const AMBIENT_ENERGY := 1.0
const MOON_COLOR := Color(0.65, 0.72, 1.0)
const MOON_ENERGY := 0.7
const LAMP_ENERGY := 1.6
const FOG_DENSITY := 0.003
const SHOW_BANDS := true
const FRONT_IS_MINUS_Z := true
const STEP_W := 2.5
const MAX_PROPS := 22
const MAX_POSTERS := 26
const MAX_MIRRORS := 6
const MAX_GLOW := 14
const SPAWNS_PER_ZONE := 3

const FACE_NODES: Array = ["PRRack", "LootLocker2"]
# name, floor y, sign text, zone unlocked when the door is bought
const DOORS: Array = [
    ["DoorMainRoom", -17.2, "MAIN ROOM\nCLOSED", "main_room"],
    ["DoorStaircase", -17.2, "STAIRS\nCLOSED", "stairs"],
    ["DoorPRRack", -14.0, "PR RACK\nCLOSED", "pr_rack"],
]
const BLOCKERS: Array = [
    ["BlockerSouth", Vector3(25.75, -17.2, 51.05), true, 6.2],
    ["BlockerEast", Vector3(44.2, -17.2, 35.6), false, 8.6],
]
const LAMPS: Array = [
    [Vector3(21.5, -14.9, 28.0), Color(1.0, 0.86, 0.68)],
    [Vector3(41.0, -14.9, 19.0), Color(1.0, 0.9, 0.7)],
    [Vector3(41.5, -14.9, 48.5), Color(0.6, 0.9, 1.0)],
    [Vector3(38.5, -11.8, 8.0), Color(1.0, 0.7, 0.45)],
    [Vector3(14.5, -11.8, 30.0), Color(1.0, 0.86, 0.68)],
    [Vector3(-14.0, -14.9, 20.0), Color(0.85, 0.9, 1.0)],
]

var _lines: Array = []
var _stations: Array = []
var _reserved: Array = []
var _segs: Array = []
var _used: Array = []
var _scan = null


func _ready() -> void:
    _rng.seed = 90210
    _setup_env()
    _build_lines()
    for ln in _lines:
        if ln["door"] != null:
            _deco_door(ln)
        else:
            _blocker(ln)
    for l in LAMPS:
        _lamp(l[0], l[1], LAMP_ENERGY, 16.0)
    _flush()
    _snap_doors.call_deferred()
    _run_scan.call_deferred()


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
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
        sun.directional_shadow_max_distance = 50.0


# ------------------------------------------------------ doors and blockers

func _build_lines() -> void:
    _lines.clear()
    var bd: Node = get_parent().get_node_or_null("BuyableDoors")
    if bd != null:
        for d in DOORS:
            var door := bd.get_node_or_null(str(d[0])) as Node3D
            if door == null:
                continue
            var sv: Variant = door.get("size")
            if typeof(sv) != TYPE_VECTOR3:
                continue
            var sz: Vector3 = sv
            var ax: bool = sz.x > sz.z
            var ln_len: float = sz.x if ax else sz.z
            var base := Vector3(door.global_position.x, float(d[1]), door.global_position.z)
            # the door unlocks its zone (spawn points tagged with that zone start spawning)
            var zone_name: String = str(d[3])
            var uz: Variant = door.get("unlocks_zones")
            var has_zone: bool = typeof(uz) == TYPE_PACKED_STRING_ARRAY and not (uz as PackedStringArray).is_empty()
            if has_zone:
                zone_name = (uz as PackedStringArray)[0]
            else:
                door.set("unlocks_zones", PackedStringArray([zone_name]))
            _lines.append({"c": base, "ax": ax, "len": ln_len, "fy": float(d[1]), "text": str(d[2]), "door": door, "name": str(d[0]), "zone": zone_name})
    for b in BLOCKERS:
        var bp: Vector3 = b[1]
        _lines.append({"c": bp, "ax": bool(b[2]), "len": float(b[3]), "fy": bp.y, "text": "BOARDED UP", "door": null, "name": str(b[0]), "zone": ""})


func _deco_door(ln: Dictionary) -> void:
    var door := ln["door"] as Node3D
    var c: Vector3 = ln["c"]
    var ax: bool = ln["ax"]
    var length: float = ln["len"]
    var holder := Node3D.new()
    holder.name = "Deco"
    holder.top_level = true
    door.add_child(holder)
    var nrm: Vector3 = AZ if ax else AX
    for side: float in [-1.0, 1.0]:
        var nn: Vector3 = nrm * side
        var tape: Vector3 = Vector3(length, 0.28, 0.05) if ax else Vector3(0.05, 0.28, length)
        for y: float in [0.9, 1.45]:
            _node_box(holder, c + Vector3(0, y, 0) + nn * 0.23, tape, YELLOW)
        var pw: float = minf(length * 0.8, 3.2)
        var panel: Vector3 = Vector3(pw, 0.8, 0.05) if ax else Vector3(0.05, 0.8, pw)
        _node_box(holder, c + Vector3(0, 2.2, 0) + nn * 0.23, panel, DARK)
        _label(str(ln["text"]), c + Vector3(0, 2.2, 0) + nn * 0.27, nn, 0.28, YELLOW, 6, holder)


func _blocker(ln: Dictionary) -> void:
    var c: Vector3 = ln["c"]
    var ax: bool = ln["ax"]
    var length: float = ln["len"]
    var h: float = 3.4
    var body := StaticBody3D.new()
    body.name = str(ln["name"])
    add_child(body)
    # the nav bake treats the boarded opening as a wall, like a closed door
    body.add_to_group("navmesh_source")
    body.position = Vector3(c.x, c.y - 0.3 + h * 0.5, c.z)
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(length, h, 0.5) if ax else Vector3(0.5, h, length)
    cs.shape = sh
    body.add_child(cs)
    var back: Vector3 = Vector3(length, h, 0.36) if ax else Vector3(0.36, h, length)
    _node_box(body, Vector3.ZERO, back, Color(0.16, 0.11, 0.07))
    var y: float = -1.3
    var i: int = 0
    while y < 1.4:
        var bl: float = length * _rng.randf_range(0.94, 0.99)
        var bs: Vector3 = Vector3(bl, 0.28, 0.46) if ax else Vector3(0.46, 0.28, bl)
        var tilt: Vector3 = Vector3(0, 0, _rng.randf_range(-3.0, 3.0)) if ax else Vector3(_rng.randf_range(-3.0, 3.0), 0, 0)
        var col: Color = WOOD.lerp(Color(0.18, 0.12, 0.08), _rng.randf())
        _node_box(body, Vector3(0, y, 0), bs, col, tilt)
        y += 0.52
        i += 1
    var nrm: Vector3 = AZ if ax else AX
    for side: float in [-1.0, 1.0]:
        var nn: Vector3 = nrm * side
        _label("BOARDED UP", Vector3(0, 0.3, 0) + nn * 0.3, nn, 0.4, YELLOW, 8, body)


# door boxes can be bottom- or centre-origin: shift so the solid's bottom sits on the floor
func _snap_doors() -> void:
    for ln in _lines:
        var door := ln["door"] as Node3D
        if door == null:
            continue
        var lows: Array = []
        _collect_bottoms(door, lows)
        if lows.is_empty():
            continue
        var bottom: float = 1000000.0
        for v in lows:
            bottom = minf(bottom, float(v))
        var fy: float = ln["fy"]
        if absf(bottom - fy) > 0.08:
            door.global_position.y += fy - bottom


func _collect_bottoms(n: Node, out: Array) -> void:
    for c in n.get_children():
        var cs := c as CollisionShape3D
        if cs != null and cs.get_parent() is StaticBody3D:
            var bx := cs.shape as BoxShape3D
            if bx != null:
                out.append(cs.global_position.y - bx.size.y * 0.5 * cs.global_transform.basis.y.length())
        _collect_bottoms(c, out)
# ----------------------------------------------------------- scan sequence

func _space() -> PhysicsDirectSpaceState3D:
    return get_world_3d().direct_space_state


func _run_scan() -> void:
    _collect_reserved()
    var script := load("res://scripts/managers/building_scan.gd") as GDScript
    if script == null:
        push_warning("building_scan.gd not found, skipping wall decor")
        _marks(null)
        _flush()
        return
    _scan = script.new()
    var ok: bool = false
    for i in 240:
        await get_tree().physics_frame
        if not is_inside_tree():
            return
        if _scan.probe(_space()):
            ok = true
            break
    if not ok:
        push_warning("Building collision never became ready, skipping wall decor")
        _marks(null)
        _flush()
        return
    _marks(_space())
    _flush()
    while not _scan.step(_space(), 50):
        await get_tree().physics_frame
        if not is_inside_tree():
            return
    _face_stations()
    await _place_props()
    await _place_posters()
    await _place_bands()
    await _place_blood()
    _place_glow()
    _make_zone_spawns()


func _collect_reserved() -> void:
    _reserved.clear()
    _stations.clear()
    _segs.clear()
    var root: Node = get_parent()
    var st: Node = root.get_node_or_null("Stations")
    if st != null:
        for s in st.get_children():
            var s3 := s as Node3D
            if s3 != null:
                _reserved.append([s3.global_position, 3.2])
                _stations.append(s3.global_position)
    var sp: Node = root.get_node_or_null("SpawnPoints")
    if sp != null:
        for s in sp.get_children():
            var m := s as Node3D
            if m != null:
                _reserved.append([m.global_position, 4.0])
    var pl := root.get_node_or_null("Player") as Node3D
    if pl != null:
        _reserved.append([pl.global_position, 4.0])
    for ln in _lines:
        var c: Vector3 = ln["c"]
        var ax: bool = ln["ax"]
        var half: float = float(ln["len"]) * 0.5
        var along: Vector3 = AX if ax else AZ
        _segs.append([c - along * half, c + along * half, 3.0])


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
    var pa := Vector2(p.x - a.x, p.z - a.z)
    var ba := Vector2(b.x - a.x, b.z - a.z)
    var l2: float = ba.length_squared()
    var t: float = 0.0
    if l2 > 0.0001:
        t = clampf(pa.dot(ba) / l2, 0.0, 1.0)
    return (pa - ba * t).length()


func _blocked(p: Vector3, own_r: float) -> bool:
    for r in _reserved:
        var rp: Vector3 = r[0]
        if absf(p.y - rp.y) < 1.6 and Vector2(p.x - rp.x, p.z - rp.z).length() < float(r[1]):
            return true
    for sg in _segs:
        var a: Vector3 = sg[0]
        var b: Vector3 = sg[1]
        if absf(p.y - a.y) < 1.6 and _seg_dist(p, a, b) < float(sg[2]):
            return true
    for u in _used:
        var ub: Vector3 = u[0]
        if absf(p.y - ub.y) < 1.6 and Vector2(p.x - ub.x, p.z - ub.z).length() < maxf(own_r, float(u[1])):
            return true
    return false


# true when p is within r of any door or blocker line (same floor level)
func _near_line(p: Vector3, r: float) -> bool:
    for sg in _segs:
        var a: Vector3 = sg[0]
        var b: Vector3 = sg[1]
        if absf(p.y - a.y) < 1.6 and _seg_dist(p, a, b) < r:
            return true
    return false


func _near_station(p: Vector3, r: float) -> bool:
    for s in _stations:
        var sp: Vector3 = s
        if absf(p.y - sp.y) < 1.6 and Vector2(p.x - sp.x, p.z - sp.z).length() < r:
            return true
    return false


func _shuffled(a: Array) -> Array:
    var r: Array = a.duplicate()
    for i in range(r.size() - 1, 0, -1):
        var j: int = _rng.randi_range(0, i)
        var t: Variant = r[i]
        r[i] = r[j]
        r[j] = t
    return r


func _rids(n: Node, out: Array[RID]) -> void:
    var co := n as CollisionObject3D
    if co != null:
        out.append(co.get_rid())
    for c in n.get_children():
        _rids(c, out)


func _fy(space: PhysicsDirectSpaceState3D, x: float, y: float, z: float, ex: Array[RID]) -> float:
    if space == null or _scan == null:
        return y
    _scan.set_exclude(ex)
    var r: float = _scan.floor_y(space, x, y, z)
    var none: Array[RID] = []
    _scan.set_exclude(none)
    return r


# rings under stations and hazard stripes along every blocker line
# (door lines get no floor stripes: they would stay in the opening after the door is bought)
func _marks(space: PhysicsDirectSpaceState3D) -> void:
    var st: Node = get_parent().get_node_or_null("Stations")
    if st != null:
        for s in st.get_children():
            var s3 := s as Node3D
            if s3 == null:
                continue
            var p: Vector3 = s3.global_position
            var is_sup: bool = s3.get("supplement_id") != null
            var base_y: float = p.y - 0.9 if is_sup else p.y
            var ex: Array[RID] = []
            _rids(s3, ex)
            var fy: float = _fy(space, p.x, base_y, p.z, ex)
            var col: Color = YELLOW
            var bc: Variant = s3.get("body_color")
            if typeof(bc) == TYPE_COLOR:
                col = bc
            var r0: float = 1.05 if is_sup else 1.7
            _ring(Vector3(p.x, fy + 0.05, p.z), r0, r0 + 0.18, col.darkened(0.2), 24, true)
    for ln in _lines:
        if ln["door"] != null:
            continue
        var c: Vector3 = ln["c"]
        var ax: bool = ln["ax"]
        var length: float = ln["len"]
        var along: Vector3 = AX if ax else AZ
        var perp: Vector3 = AZ if ax else AX
        for side: float in [-1.0, 1.0]:
            var sp: Vector3 = c + perp * (0.75 * side)
            var none: Array[RID] = []
            var fy2: float = _fy(space, sp.x, c.y, sp.z, none)
            _stripes(Vector3(sp.x, fy2 + 0.04, sp.z), along, perp, AY, length, 0.45, 0.5, YELLOW, DARK)


# PR Rack and the 2nd locker turn to face away from the nearest wall
func _face_stations() -> void:
    var st: Node = get_parent().get_node_or_null("Stations")
    if st == null:
        return
    for nm in FACE_NODES:
        var s3 := st.get_node_or_null(str(nm)) as Node3D
        if s3 == null:
            continue
        var ex: Array[RID] = []
        _rids(s3, ex)
        _scan.set_exclude(ex)
        var wd: Vector3 = _scan.nearest_wall_dir(_space(), s3.global_position)
        var none: Array[RID] = []
        _scan.set_exclude(none)
        if wd == Vector3.ZERO:
            continue
        var dir: Vector3 = -wd
        var yaw: float = atan2(dir.x, dir.z)
        if FRONT_IS_MINUS_Z:
            yaw = atan2(-dir.x, -dir.z)
        s3.rotation = Vector3(0.0, yaw, 0.0)


# 3 zombie spawn points on the far side of each buyable door (the side away from the
# player start). They are tagged with the door's zone, so they only spawn zombies once
# that door is bought. RoundManager copied its spawn list in _ready, so add to it here.
func _make_zone_spawns() -> void:
    var root: Node = get_parent()
    var rm: Node = root.get_node_or_null("RoundManager")
    if rm == null:
        return
    var pts: Variant = rm.get("_spawn_points")
    if typeof(pts) != TYPE_ARRAY:
        push_warning("RoundManager has no _spawn_points list, zone spawns skipped")
        return
    var spawn_list: Array = pts
    var pl := root.get_node_or_null("Player") as Node3D
    var start: Vector3 = Vector3.ZERO
    if pl != null:
        start = pl.global_position
    var holder := Node3D.new()
    holder.name = "ZoneSpawns"
    root.add_child(holder)
    for ln in _lines:
        if ln["door"] == null:
            continue
        var zone: String = str(ln["zone"])
        if zone == "":
            continue
        var c: Vector3 = ln["c"]
        var fy: float = ln["fy"]
        var nrm: Vector3 = AZ if bool(ln["ax"]) else AX
        if (start - c).dot(nrm) > 0.0:
            nrm = -nrm
        var cands: Array = []
        for f in _scan.floors:
            var fp: Vector3 = f
            var rel: Vector3 = fp - c
            if rel.dot(nrm) < 3.0:
                continue
            if Vector2(rel.x, rel.z).length() > 18.0:
                continue
            if fp.y < fy - 1.0 or fp.y > fy + 4.0:
                continue
            if _blocked(fp, 2.5):
                continue
            cands.append(fp)
        var picked: Array = []
        for f in _shuffled(cands):
            var fp2: Vector3 = f
            var far_enough: bool = true
            for q in picked:
                var qp: Vector3 = q
                if Vector2(fp2.x - qp.x, fp2.z - qp.z).length() < 6.0:
                    far_enough = false
                    break
            if far_enough:
                picked.append(fp2)
                if picked.size() >= SPAWNS_PER_ZONE:
                    break
        if picked.is_empty():
            push_warning("No spawn spots found behind %s (zone %s)" % [str(ln["name"]), zone])
            continue
        var idx: int = 0
        for q in picked:
            var qp2: Vector3 = q
            var m := Marker3D.new()
            m.name = "Spawn_%s_%d" % [zone, idx]
            m.add_to_group("spawn_points")
            m.set_meta("zone", zone)
            holder.add_child(m)
            m.global_position = Vector3(qp2.x, qp2.y + 0.8, qp2.z)
            spawn_list.append(m)
            idx += 1
# ---------------------------------------------------------------- placement

func _dims(kind: String) -> Vector2:
    match kind:
        "rack":
            return Vector2(1.9, 1.2)
        "dbrack":
            return Vector2(2.1, 0.6)
        "plates":
            return Vector2(0.9, 0.7)
        "bench":
            return Vector2(1.3, 0.5)
        "crates":
            return Vector2(1.9, 1.0)
        _:
            return Vector2(2.0, 0.6)


func _add_prop(kind: String, p: Vector3, n: Vector3) -> void:
    match kind:
        "rack":
            _rack(p, n)
        "dbrack":
            _dbrack(p, n)
        "plates":
            _plates(p, n)
        "bench":
            _bench(p, n)
        "crates":
            _crates(p, n)
        _:
            _lockers(p, n, 2.0)


func _place_props() -> void:
    var cand: Array = _shuffled(_scan.walls)
    var kinds: Array = ["dbrack", "plates", "bench", "crates", "lockers", "rack", "dbrack", "plates"]
    var placed: int = 0
    var tries: int = 0
    for w in cand:
        if placed >= MAX_PROPS:
            break
        tries += 1
        if tries % 10 == 0:
            await get_tree().physics_frame
            if not is_inside_tree():
                return
        var p: Vector3 = w["p"]
        var n: Vector3 = w["n"]
        if _blocked(p, 3.2):
            continue
        var kind: String = str(kinds[placed % kinds.size()])
        var dims: Vector2 = _dims(kind)
        var sp: PhysicsDirectSpaceState3D = _space()
        if not _scan.wall_flat(sp, p, n, dims.x * 0.5 + 0.8, [0.4, 1.2, 2.0]):
            continue
        if not _scan.footprint_free(sp, p, n, dims.x, dims.y):
            continue
        _add_prop(kind, p, n)
        _used.append([p, 3.2])
        placed += 1
    _flush()


func _place_posters() -> void:
    var cand: Array = _shuffled(_scan.walls)
    var papers: Array = [Color(0.6, 0.1, 0.09), Color(0.9, 0.7, 0.08), Color(0.1, 0.45, 0.5), Color(0.85, 0.4, 0.1), Color(0.8, 0.8, 0.76), Color(0.15, 0.15, 0.2)]
    var words: Array = ["NO PAIN NO GAINS", "LEG DAY", "NEVER SKIP", "PR OR DIE", "DONT QUIT", "HYDRATE", "LIFT HEAVY", "PUSH", "PULL", "SQUAT", "EAT MEAT", "GRIND"]
    var placed: int = 0
    var mirrors: int = 0
    var tries: int = 0
    for w in cand:
        if placed >= MAX_POSTERS:
            break
        tries += 1
        if tries % 10 == 0:
            await get_tree().physics_frame
            if not is_inside_tree():
                return
        var p: Vector3 = w["p"]
        var n: Vector3 = w["n"]
        if float(w["ceil"]) - p.y < 2.6:
            continue
        if _blocked(p, 2.4):
            continue
        var as_mirror: bool = mirrors < MAX_MIRRORS and placed % 4 == 3
        var half: float = 1.3 if as_mirror else 0.8
        if not _scan.wall_flat(_space(), p, n, half, [0.4, 1.0, 2.0]):
            continue
        if as_mirror:
            _mirror(p + AY * 1.5, n, 2.2, 1.4)
            mirrors += 1
        else:
            _poster(p + AY * 1.6, n, 1.1, 1.5, papers[placed % papers.size()], words[placed % words.size()])
        _used.append([p, 2.4])
        placed += 1
    _flush()


func _place_bands() -> void:
    if not SHOW_BANDS:
        return
    var count: int = 0
    for w in _scan.walls:
        count += 1
        if count % 8 == 0:
            await get_tree().physics_frame
            if not is_inside_tree():
                return
        var p: Vector3 = w["p"]
        var n: Vector3 = w["n"]
        # no wall bands on or next to a buyable door / blocker (they would stay after the door is bought)
        if _near_line(p, 1.6):
            continue
        if not _scan.wall_flat(_space(), p, n, 1.2, [0.3, 1.0]):
            continue
        var upper: bool = p.y > -15.5
        var wain: Color = Color(0.17, 0.13, 0.12) if upper else Color(0.13, 0.15, 0.17)
        var trim: Color = ORANGE if upper else TEAL
        _wq(p + AY * 0.55, n, STEP_W, 1.1, wain, false, 0.015)
        _wq(p + AY * 1.13, n, STEP_W, 0.07, trim, false, 0.02)
    _flush()


func _place_blood() -> void:
    var fl: Array = _shuffled(_scan.floors)
    var count: int = 0
    for f in fl:
        if count >= 16:
            break
        var fp: Vector3 = f
        if _near_station(fp, 1.8):
            continue
        _blob(fp.x, fp.z, _rng.randf_range(0.7, 1.4), fp.y + 0.035)
        count += 1
    var cand: Array = _shuffled(_scan.walls)
    var smears: int = 0
    var tries: int = 0
    for w in cand:
        if smears >= 8:
            break
        tries += 1
        if tries % 10 == 0:
            await get_tree().physics_frame
            if not is_inside_tree():
                return
        var p: Vector3 = w["p"]
        var n: Vector3 = w["n"]
        if _blocked(p, 2.0):
            continue
        if not _scan.wall_flat(_space(), p, n, 0.7, [0.4, 1.5]):
            continue
        _smear(p + AY * 1.3, n, 1.1, 0.8)
        _used.append([p, 2.0])
        smears += 1
    _flush()


func _place_glow() -> void:
    var cl: Array = _shuffled(_scan.ceils)
    var done: Array = []
    for c in cl:
        if done.size() >= MAX_GLOW:
            break
        var p: Vector3 = c
        var near: bool = false
        for d in done:
            var dp: Vector3 = d
            if absf(p.y - dp.y) < 1.6 and Vector2(p.x - dp.x, p.z - dp.z).length() < 6.5:
                near = true
                break
        if near:
            continue
        done.append(p)
        var y: float = p.y - 0.04
        _q(Vector3(p.x - 0.9, y, p.z - 0.15), Vector3(p.x + 0.9, y, p.z - 0.15), Vector3(p.x + 0.9, y, p.z + 0.15), Vector3(p.x - 0.9, y, p.z + 0.15), -AY, Color(1.0, 0.95, 0.8), true)
    _flush()

# END OF FILE
