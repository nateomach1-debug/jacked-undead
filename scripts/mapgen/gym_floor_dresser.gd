extends "res://scripts/mapgen/gym_floor_decor.gd"
## Random Gym decor, part 2 of 2: dusk environment, blood, door tape and signs,
## 6 real lights, station rings. Tuning knobs are the consts below.

const AMBIENT_COLOR := Color(0.5, 0.55, 0.68)
const AMBIENT_ENERGY := 1.2
const MOON_COLOR := Color(0.65, 0.72, 1.0)
const MOON_ENERGY := 1.0
const MOON_SHADOWS := true
const LAMP_ENERGY := 2.0
const LAMP_RANGE := 20.0
const FOG_DENSITY := 0.0035


func _ready() -> void:
    if not _load_layout():
        push_warning("GymFloorDresser: MapGen not found")
        return
    _collect_sides()
    _dress_env()
    _dress_floors()
    _dress_walls()
    _dress_props()
    _dress_posters()
    _dress_signs()
    _dress_fixtures()
    _dress_floor_labels()
    _dress_blood()
    _dress_doors()
    _dress_lights()
    _flush()
    _dress_rings.call_deferred()


func _dress_env() -> void:
    var root: Node = get_parent()
    var we: WorldEnvironment = root.get_node_or_null("WorldEnvironment") as WorldEnvironment
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
            var sm: ProceduralSkyMaterial = sky.sky_material as ProceduralSkyMaterial
            sm.sky_top_color = Color(0.07, 0.09, 0.2)
            sm.sky_horizon_color = Color(0.5, 0.32, 0.3)
            sm.ground_horizon_color = Color(0.5, 0.32, 0.3)
            sm.ground_bottom_color = Color(0.05, 0.05, 0.07)
    var sun: DirectionalLight3D = root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
    if sun != null:
        sun.light_color = MOON_COLOR
        sun.light_energy = MOON_ENERGY
        sun.shadow_enabled = MOON_SHADOWS
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
        sun.directional_shadow_max_distance = 60.0


func _dress_blood() -> void:
    for y in _gh:
        for x in _gw:
            var c: Vector3 = _cell_pos(x, y)
            var n: int = 1
            if _rng.randf() < 0.4:
                n = 2
            for k in n:
                _blob(c.x + _rng.randf_range(-6.0, 6.0), c.z + _rng.randf_range(-6.0, 6.0), _rng.randf_range(0.8, 1.3), 0.035)
    for s in _sides:
        if s["door"] != INF or _rng.randf() > 0.35:
            continue
        _smear(s["face"] + s["along"] * _rng.randf_range(-7.0, 7.0) + AY * 2.3, s["nrm"], 1.2, 0.8)


# Door decor lives under each door node, so it disappears when the door is bought.
func _dress_doors() -> void:
    var holder: Node = _gen.get_node_or_null("BuyableDoors")
    if holder == null:
        return
    for door in holder.get_children():
        var d3: Node3D = door as Node3D
        if d3 == null:
            continue
        var sz: Variant = door.get("size")
        if typeof(sz) != TYPE_VECTOR3:
            continue
        var szv: Vector3 = sz
        var along_z: bool = szv.z > szv.x
        var w: float = szv.z if along_z else szv.x
        var label: String = str(door.get("display_name")).to_upper()
        var c: Vector3 = Vector3(d3.global_position.x, 0.0, d3.global_position.z)
        if along_z:
            _stripes(c + AY * 0.03, AZ, AX, AY, w, 0.6, 0.5, YELLOW, DARK)
            _door_tape(d3, c, AX, w, label + "\nCLOSED")
            _door_tape(d3, c, -AX, w, label + "\nCLOSED")
        else:
            _stripes(c + AY * 0.03, AX, AZ, AY, w, 0.6, 0.5, YELLOW, DARK)
            _door_tape(d3, c, AZ, w, label + "\nCLOSED")
            _door_tape(d3, c, -AZ, w, label + "\nCLOSED")


func _door_tape(door: Node3D, c: Vector3, nrm: Vector3, w: float, text: String) -> void:
    var holder: Node3D = Node3D.new()
    holder.name = "Deco"
    holder.top_level = true
    door.add_child(holder)
    var along_x: bool = absf(nrm.x) > 0.5
    var tape: Vector3 = Vector3(0.05, 0.28, w) if along_x else Vector3(w, 0.28, 0.05)
    var base: Vector3 = c + nrm * 0.24
    for y: float in [1.0, 1.55]:
        _node_box(holder, base + Vector3(0.0, y, 0.0), tape, YELLOW)
    var panel: Vector3 = Vector3(0.06, 1.1, w * 0.9) if along_x else Vector3(w * 0.9, 1.1, 0.06)
    _node_box(holder, base + Vector3(0.0, 3.4, 0.0), panel, DARK)
    var longest: int = 0.5
    for ln in text.split("\n"):
        longest = maxi(longest, ln.length())
    var th: float = minf(0.42, (w * 0.8) / (float(longest) * 0.85)) * 0.8
    _label(text, base + Vector3(0.0, 3.4, 0.0) + nrm * 0.05, nrm, th, YELLOW, 8, holder)


# Only 6 real lights (phone limit per mesh); everything else is fake glow.
func _dress_lights() -> void:
    var ids: Array = [_start_g]
    var others: Array = []
    for g in _first_cell.keys():
        if int(g) != _start_g:
            others.append(g)
    for i in range(others.size() - 1, 0, -1):
        var j: int = _rng.randi() % (i + 1)
        var tmp = others[i]
        others[i] = others[j]
        others[j] = tmp
    ids.append_array(others.slice(0, 5))
    var cols: Array = [Color(1.0, 0.86, 0.68), Color(0.6, 0.9, 1.0), Color(1.0, 0.7, 0.45), Color(1.0, 0.9, 0.7), Color(0.85, 0.9, 1.0), Color(1.0, 0.8, 0.8)]
    var n: int = 0
    for g in ids:
        var c: Vector3 = _first_cell[g]
        _lamp(Vector3(c.x, 6.5, c.z), cols[n % cols.size()], LAMP_ENERGY, LAMP_RANGE)
        n += 1


func _dress_rings() -> void:
    await get_tree().process_frame
    if not is_inside_tree():
        return
    var st: Node = _gen.get_node_or_null("Stations")
    if st == null:
        return
    for s in st.get_children():
        var s3: Node3D = s as Node3D
        if s3 == null:
            continue
        var nm: String = str(s3.name)
        if "WallBuy" in nm:
            continue
        var p: Vector3 = s3.global_position
        var col: Color = YELLOW
        var bc: Variant = s3.get("body_color")
        if typeof(bc) == TYPE_COLOR:
            col = bc
        var big: bool = nm.begins_with("PRRack") or nm.begins_with("LootLocker")
        var r0: float = 1.7 if big else 1.05
        _ring(Vector3(p.x, 0.04, p.z), r0, r0 + 0.18, col.darkened(0.2), 24, true)
    _flush()

# END OF FILE
