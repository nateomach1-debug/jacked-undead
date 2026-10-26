extends Node
## Halloween zombie costumes. Lives only inside the Halloween map (added by
## halloween_builder.gd), so gym-map zombies are never touched. Watches for new
## zombies and gives each a costume: pumpkin head, witch, mummy, ghost sheet,
## skeleton, devil, black cat, vampire, scarecrow or jester. The Roid Rager
## gets one too, sized up to fit him.
## Co-op: the pick is seeded from the zombie's net id, so the host and every
## joined phone choose the same costume for the same zombie. The host assigns
## net ids a fraction of a second after a zombie spawns, so it waits for one.
## Cheap: shared meshes and materials, no lights, no shadows, 7 to 14 small
## meshes per zombie.

const BASE_SCRIPT_END: String = "scripts/zombies/zombie.gd"
const RAGER_SCRIPT_END: String = "scripts/zombies/roid_rager.gd"
const COSTUME_COUNT: int = 10
const ID_WAIT_TRIES: int = 12      # host: how many times to wait for the net id
const ID_WAIT_TIME: float = 0.05   # seconds between those waits (12 x 0.05 = 0.6 s)

# Roid Rager fit: the costume is built for the normal zombie, and these resize it.
# Head pieces are scaled together; body pieces are wider (x) and thicker (z).
const RAGER_HEAD_POS: Vector3 = Vector3(0.0, -0.065, 0.0)
const RAGER_HEAD_SCALE: float = 1.1
const RAGER_BODY_POS: Vector3 = Vector3(0.0, 0.2, 0.0)
const RAGER_BODY_SCALE: Vector3 = Vector3(1.9, 1.0, 1.3)

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
    if bool(z.get("_is_dead")):
        return
    var s: Script = z.get_script() as Script
    if s == null:
        return
    var is_rager: bool = s.resource_path.ends_with(RAGER_SCRIPT_END)
    if not is_rager and not s.resource_path.ends_with(BASE_SCRIPT_END):
        return  # any other variant stays plain
    var head: Node3D = z._head
    var upper: Node3D = z._upper
    if head == null or upper == null:
        return

    var rng: RandomNumberGenerator = _make_rng(z)
    if rng == null:
        return  # host is waiting for this zombie's net id; _dress runs again soon
    z.set_meta("halloween_costume", true)

    # Mount points: the Roid Rager's mounts resize the costume.
    var hr := Node3D.new()
    head.add_child(hr)
    var ur := Node3D.new()
    upper.add_child(ur)
    if is_rager:
        hr.position = RAGER_HEAD_POS
        hr.scale = Vector3.ONE * RAGER_HEAD_SCALE
        ur.position = RAGER_BODY_POS
        ur.scale = RAGER_BODY_SCALE

    var orange_eye := _mat("hw_eye", Color(1.0, 0.45, 0.05), 0.5, 4.0)
    match rng.randi() % COSTUME_COUNT:
        0:
            _pumpkin(hr, rng)
        1:
            _witch(hr, rng)
            _head_eyes(head, is_rager, orange_eye)
        2:
            _mummy(hr, ur, rng)
            _head_eyes(head, is_rager, orange_eye)
        3:
            _ghost(hr, ur)
        4:
            _skeleton(hr, ur)
        5:
            _devil(hr, ur)
        6:
            _cat(hr, ur)
        7:
            _vampire(hr, ur)
            _head_eyes(head, is_rager, _mat("hw_eye_red", Color(1.0, 0.1, 0.05), 0.5, 4.0))
        8:
            _scarecrow(hr, ur, rng)
        _:
            _jester(hr, ur)


## Random numbers for this zombie's costume. Online, the seed comes from the
## net id so every phone gets the same result. Returns null when the host has
## not given the zombie an id yet (a retry is scheduled).
func _make_rng(z) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    if not NetManager.is_online:
        rng.randomize()
        return rng
    if z.has_meta("net_id"):
        rng.seed = int(z.get_meta("net_id")) * 2654435761 + 40503
        return rng
    if bool(z.get("is_puppet")):
        rng.randomize()
        return rng
    var tries: int = int(z.get_meta("hw_id_tries", 0))
    if tries >= ID_WAIT_TRIES:
        rng.randomize()
        return rng
    z.set_meta("hw_id_tries", tries + 1)
    get_tree().create_timer(ID_WAIT_TIME).timeout.connect(_dress.bind(z))
    return null


# ---------- costumes ----------

static func _pumpkin(head: Node3D, r: RandomNumberGenerator) -> void:
    var orange := _mat("pumpkin", Color(0.95, 0.45, 0.05), 0.7, 0.0)
    var dark := _mat("pumpkin_dark", Color(0.78, 0.33, 0.03), 0.75, 0.0)
    var stem := _mat("pumpkin_stem", Color(0.2, 0.4, 0.1), 0.8, 0.0)
    var glow := _mat("pumpkin_glow", Color(1.0, 0.65, 0.1), 0.5, 3.0)
    _put(head, _sphere(), Vector3(0.0, 0.16, 0.0), orange, Vector3(0.44, 0.38, 0.44))
    # Side lobes give the ribbed pumpkin look.
    _put(head, _sphere(), Vector3(-0.14, 0.16, 0.0), dark, Vector3(0.2, 0.36, 0.4))
    _put(head, _sphere(), Vector3(0.14, 0.16, 0.0), dark, Vector3(0.2, 0.36, 0.4))
    _put(head, _box_mesh(Vector3(0.05, 0.09, 0.05)), Vector3(0.0, 0.37, 0.0), stem, Vector3.ONE, Vector3(0.0, 0.0, r.randf_range(0.1, 0.35)))
    # Carved face: diamond eyes, diamond nose, mouth with two teeth.
    var eye_mesh := _box_mesh(Vector3(0.07, 0.07, 0.03))
    _put(head, eye_mesh, Vector3(-0.09, 0.21, -0.195), glow, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.25))
    _put(head, eye_mesh, Vector3(0.09, 0.21, -0.195), glow, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.25))
    _put(head, _box_mesh(Vector3(0.04, 0.04, 0.03)), Vector3(0.0, 0.15, -0.205), glow, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.25))
    _put(head, _box_mesh(Vector3(0.2, 0.05, 0.03)), Vector3(0.0, 0.09, -0.19), glow)
    var tooth := _box_mesh(Vector3(0.04, 0.04, 0.035))
    _put(head, tooth, Vector3(-0.05, 0.105, -0.19), orange)
    _put(head, tooth, Vector3(0.05, 0.075, -0.19), orange)


static func _witch(head: Node3D, r: RandomNumberGenerator) -> void:
    var felt := _mat("witch_felt", Color(0.12, 0.07, 0.16), 0.8, 0.0)
    var band := _mat("witch_band", Color(0.5, 0.15, 0.7), 0.6, 0.0)
    var gold := _mat("witch_gold", Color(0.9, 0.75, 0.15), 0.4, 0.0)
    var green := _mat("witch_green", Color(0.3, 0.55, 0.2), 0.85, 0.0)
    var hat := Node3D.new()
    hat.position = Vector3(0.0, 0.27, 0.0)
    hat.rotation.z = r.randf_range(-0.15, 0.15)
    head.add_child(hat)
    _put(hat, _cyl_mesh(0.2, 0.2, 0.015), Vector3.ZERO, felt)
    _put(hat, _cyl_mesh(0.0, 0.12, 0.34), Vector3(0.0, 0.17, 0.0), felt)
    _put(hat, _cyl_mesh(0.1, 0.118, 0.05), Vector3(0.0, 0.05, 0.0), band)
    _put(hat, _box_mesh(Vector3(0.045, 0.04, 0.012)), Vector3(0.0, 0.05, -0.115), gold)
    var tip := Node3D.new()
    tip.position = Vector3(0.0, 0.33, 0.0)
    tip.rotation.z = -0.8
    hat.add_child(tip)
    _put(tip, _cyl_mesh(0.0, 0.04, 0.14), Vector3(0.0, 0.07, 0.0), felt)
    # Green hair hanging at the sides and a long hooked nose.
    var hair := _box_mesh(Vector3(0.05, 0.2, 0.05))
    _put(head, hair, Vector3(-0.135, 0.07, 0.02), green, Vector3.ONE, Vector3(0.0, 0.0, 0.12))
    _put(head, hair, Vector3(0.135, 0.07, 0.02), green, Vector3.ONE, Vector3(0.0, 0.0, -0.12))
    _put(head, _box_mesh(Vector3(0.035, 0.035, 0.08)), Vector3(0.0, 0.135, -0.15), green, Vector3.ONE, Vector3(-0.4, 0.0, 0.0))


static func _mummy(head: Node3D, upper: Node3D, r: RandomNumberGenerator) -> void:
    var wrap := _mat("mummy_wrap", Color(0.84, 0.8, 0.68), 0.9, 0.0)
    # Head wraps: rings hugging the skull, leaving a slit for the eyes.
    for y in [0.07, 0.115, 0.25, 0.29]:
        var t: float = (float(y) - 0.15) / 0.145
        var rad: float = 0.135 * sqrt(maxf(1.0 - t * t, 0.0)) + 0.012
        _put(head, _cyl_mesh(rad, rad, 0.03), Vector3(0.0, y, 0.0), wrap, Vector3.ONE, Vector3(0.0, 0.0, r.randf_range(-0.08, 0.08)))
    # Loose strips hanging from the head.
    _put(head, _box_mesh(Vector3(0.035, 0.28, 0.01)), Vector3(0.12, 0.02, -0.06), wrap, Vector3.ONE, Vector3(0.0, 0.0, 0.12))
    _put(head, _box_mesh(Vector3(0.03, 0.2, 0.01)), Vector3(-0.1, 0.05, -0.1), wrap, Vector3.ONE, Vector3(0.0, 0.0, -0.1))
    # Crossing strips on the chest.
    var strip := _box_mesh(Vector3(0.44, 0.035, 0.02))
    var dir: float = 1.0 if r.randf() < 0.5 else -1.0
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
    # Wavy hem: round bumps around the bottom edge of the sheet.
    for i in range(5):
        var a: float = float(i) * TAU / 5.0 + 0.3
        _put(upper, _sphere(), Vector3(cos(a) * 0.38, -0.5, sin(a) * 0.38), sheet, Vector3(0.24, 0.16, 0.24))
    # Cut-out eyes and mouth.
    for sx in [-1.0, 1.0]:
        _put(head, _sphere(), Vector3(sx * 0.075, 0.18, -0.178), black, Vector3(0.08, 0.12, 0.03))
        _put(head, _sphere(), Vector3(sx * 0.075, 0.18, -0.188), glow, Vector3(0.045, 0.065, 0.02))
    _put(head, _sphere(), Vector3(0.0, 0.07, -0.185), black, Vector3(0.07, 0.1, 0.03))


static func _skeleton(head: Node3D, upper: Node3D) -> void:
    var bone := _mat("bone", Color(0.9, 0.88, 0.78), 0.8, 0.0)
    var black := _mat("ghost_black", Color(0.02, 0.02, 0.03), 0.9, 0.0)
    # Skull over the head: dark sockets, nose hole, grinning teeth.
    _put(head, _sphere(), Vector3(0.0, 0.15, 0.0), bone, Vector3(0.3, 0.31, 0.3))
    for sx in [-1.0, 1.0]:
        _put(head, _sphere(), Vector3(sx * 0.065, 0.185, -0.138), black, Vector3(0.075, 0.09, 0.03))
    _put(head, _box_mesh(Vector3(0.035, 0.035, 0.02)), Vector3(0.0, 0.12, -0.145), black, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.25))
    _put(head, _box_mesh(Vector3(0.11, 0.05, 0.02)), Vector3(0.0, 0.065, -0.13), black)
    var tooth := _box_mesh(Vector3(0.012, 0.05, 0.022))
    for x in [-0.03, 0.0, 0.03]:
        _put(head, tooth, Vector3(x, 0.065, -0.132), bone)
    # Ribcage over a dark chest: four ribs and a breastbone.
    _put(upper, _box_mesh(Vector3(0.4, 0.36, 0.012)), Vector3(0.0, 0.27, -0.155), black)
    var ys: Array[float] = [0.36, 0.29, 0.22, 0.15]
    var ws: Array[float] = [0.3, 0.34, 0.32, 0.26]
    for i in range(4):
        _put(upper, _box_mesh(Vector3(ws[i], 0.028, 0.02)), Vector3(0.0, ys[i], -0.165), bone)
    _put(upper, _box_mesh(Vector3(0.03, 0.3, 0.02)), Vector3(0.0, 0.255, -0.168), bone)


static func _devil(head: Node3D, upper: Node3D) -> void:
    var skin := _mat("devil_skin", Color(0.7, 0.08, 0.06), 0.6, 0.0)
    var horn := _mat("devil_horn", Color(0.3, 0.03, 0.03), 0.5, 0.0)
    var glow := _mat("hw_eye_devil", Color(1.0, 0.9, 0.2), 0.5, 4.0)
    # Red face, two horns, glowing yellow eyes.
    _put(head, _sphere(), Vector3(0.0, 0.15, 0.0), skin, Vector3(0.29, 0.3, 0.29))
    var horn_mesh := _cyl_mesh(0.0, 0.035, 0.17)
    _put(head, horn_mesh, Vector3(-0.109, 0.37, 0.0), horn, Vector3.ONE, Vector3(0.0, 0.0, 0.35))
    _put(head, horn_mesh, Vector3(0.109, 0.37, 0.0), horn, Vector3.ONE, Vector3(0.0, 0.0, -0.35))
    _eye_pair(head, 0.065, 0.19, -0.128, glow)
    # Tail with a spade tip, out the back (+Z).
    _put(upper, _box_mesh(Vector3(0.03, 0.03, 0.2)), Vector3(0.0, -0.008, 0.228), skin, Vector3.ONE, Vector3(0.5, 0.0, 0.0))
    _put(upper, _box_mesh(Vector3(0.03, 0.03, 0.2)), Vector3(0.0, 0.022, 0.378), skin, Vector3.ONE, Vector3(-0.9, 0.0, 0.0))
    _put(upper, _box_mesh(Vector3(0.012, 0.07, 0.07)), Vector3(0.0, 0.14, 0.47), skin, Vector3.ONE, Vector3(PI * 0.25, 0.0, 0.0))


static func _cat(head: Node3D, upper: Node3D) -> void:
    var fur := _mat("cat_fur", Color(0.03, 0.03, 0.04), 0.9, 0.0)
    var pink := _mat("cat_pink", Color(0.9, 0.5, 0.6), 0.7, 0.0)
    var glow := _mat("hw_eye_cat", Color(0.95, 0.85, 0.1), 0.5, 4.0)
    # Black hood over the head, pointed ears, pink nose, whiskers, yellow eyes.
    _put(head, _sphere(), Vector3(0.0, 0.15, 0.0), fur, Vector3(0.3, 0.31, 0.3))
    var ear := _cyl_mesh(0.0, 0.055, 0.13)
    var inner := _cyl_mesh(0.0, 0.035, 0.09)
    _put(head, ear, Vector3(-0.088, 0.334, 0.0), fur, Vector3.ONE, Vector3(0.0, 0.0, 0.2))
    _put(head, ear, Vector3(0.088, 0.334, 0.0), fur, Vector3.ONE, Vector3(0.0, 0.0, -0.2))
    _put(head, inner, Vector3(-0.088, 0.325, -0.022), pink, Vector3.ONE, Vector3(0.0, 0.0, 0.2))
    _put(head, inner, Vector3(0.088, 0.325, -0.022), pink, Vector3.ONE, Vector3(0.0, 0.0, -0.2))
    _eye_pair(head, 0.065, 0.19, -0.128, glow)
    _put(head, _box_mesh(Vector3(0.035, 0.025, 0.02)), Vector3(0.0, 0.135, -0.146), pink)
    var whisker := _box_mesh(Vector3(0.34, 0.008, 0.008))
    _put(head, whisker, Vector3(0.0, 0.115, -0.146), fur, Vector3.ONE, Vector3(0.0, 0.0, 0.1))
    _put(head, whisker, Vector3(0.0, 0.105, -0.146), fur, Vector3.ONE, Vector3(0.0, 0.0, -0.1))
    # Tail curling up behind.
    _put(upper, _box_mesh(Vector3(0.035, 0.035, 0.2)), Vector3(0.0, 0.074, 0.234), fur, Vector3.ONE, Vector3(-0.35, 0.0, 0.0))
    _put(upper, _box_mesh(Vector3(0.035, 0.28, 0.035)), Vector3(0.0, 0.242, 0.287), fur, Vector3.ONE, Vector3(-0.3, 0.0, 0.0))


static func _vampire(head: Node3D, upper: Node3D) -> void:
    var black := _mat("vamp_black", Color(0.05, 0.02, 0.07), 0.8, 0.0)
    var red := _mat("vamp_red", Color(0.5, 0.04, 0.08), 0.7, 0.0)
    var fang := _mat("vamp_fang", Color(0.95, 0.95, 0.9), 0.6, 0.0)
    # Slicked-back hair and two fangs (red eyes are added by _dress).
    _put(head, _sphere(), Vector3(0.0, 0.25, 0.0), black, Vector3(0.3, 0.17, 0.3))
    var f := _box_mesh(Vector3(0.02, 0.045, 0.015))
    _put(head, f, Vector3(-0.035, 0.05, -0.128), fang)
    _put(head, f, Vector3(0.035, 0.05, -0.128), fang)
    # Cape from the shoulders, swept back, with a red trim and a high collar.
    var cape := Node3D.new()
    cape.position = Vector3(0.0, 0.58, 0.14)
    cape.rotation.x = -0.12
    upper.add_child(cape)
    _put(cape, _box_mesh(Vector3(0.5, 0.95, 0.02)), Vector3(0.0, -0.475, 0.0), black)
    _put(cape, _box_mesh(Vector3(0.55, 0.98, 0.012)), Vector3(0.0, -0.49, -0.012), red)
    var collar := _box_mesh(Vector3(0.03, 0.2, 0.16))
    _put(upper, collar, Vector3(-0.16, 0.7, 0.07), black, Vector3.ONE, Vector3(0.0, 0.0, 0.4))
    _put(upper, collar, Vector3(0.16, 0.7, 0.07), black, Vector3.ONE, Vector3(0.0, 0.0, -0.4))


static func _scarecrow(head: Node3D, upper: Node3D, r: RandomNumberGenerator) -> void:
    var burlap := _mat("burlap", Color(0.72, 0.6, 0.38), 0.95, 0.0)
    var straw := _mat("straw", Color(0.85, 0.72, 0.3), 0.9, 0.0)
    var crown := _mat("straw_hat", Color(0.62, 0.5, 0.2), 0.9, 0.0)
    var brown := _mat("straw_band", Color(0.3, 0.17, 0.08), 0.9, 0.0)
    var black := _mat("ghost_black", Color(0.02, 0.02, 0.03), 0.9, 0.0)
    var patch := _mat("scarecrow_patch", Color(0.55, 0.2, 0.2), 0.9, 0.0)
    # Burlap sack head, button eyes, stitched mouth.
    _put(head, _sphere(), Vector3(0.0, 0.15, 0.0), burlap, Vector3(0.3, 0.31, 0.3))
    for sx in [-1.0, 1.0]:
        _put(head, _sphere(), Vector3(sx * 0.065, 0.19, -0.128), black, Vector3(0.055, 0.055, 0.03))
    _put(head, _box_mesh(Vector3(0.14, 0.014, 0.02)), Vector3(0.0, 0.08, -0.134), black)
    var stitch := _box_mesh(Vector3(0.012, 0.045, 0.02))
    for x in [-0.05, 0.0, 0.05]:
        _put(head, stitch, Vector3(x, 0.08, -0.134), black)
    # Straw poking out at the sides.
    var tuft := _box_mesh(Vector3(0.025, 0.13, 0.025))
    _put(head, tuft, Vector3(-0.18, 0.16, 0.0), straw, Vector3.ONE, Vector3(0.0, 0.0, 1.2))
    _put(head, tuft, Vector3(0.18, 0.16, 0.0), straw, Vector3.ONE, Vector3(0.0, 0.0, -1.2))
    # Floppy straw hat.
    var hat := Node3D.new()
    hat.position = Vector3(0.0, 0.27, 0.0)
    hat.rotation = Vector3(-0.1, 0.0, r.randf_range(-0.18, 0.18))
    head.add_child(hat)
    _put(hat, _cyl_mesh(0.21, 0.21, 0.015), Vector3.ZERO, straw)
    _put(hat, _cyl_mesh(0.1, 0.115, 0.11), Vector3(0.0, 0.06, 0.0), crown)
    _put(hat, _cyl_mesh(0.118, 0.118, 0.03), Vector3(0.0, 0.03, 0.0), brown)
    # A patch on the chest.
    _put(upper, _box_mesh(Vector3(0.13, 0.13, 0.012)), Vector3(0.1, 0.28, -0.16), patch, Vector3.ONE, Vector3(0.0, 0.0, 0.1))


static func _jester(head: Node3D, upper: Node3D) -> void:
    var purple := _mat("jester_purple", Color(0.45, 0.12, 0.6), 0.7, 0.0)
    var green := _mat("jester_green", Color(0.1, 0.6, 0.25), 0.7, 0.0)
    var gold := _mat("jester_gold", Color(0.95, 0.8, 0.1), 0.4, 0.0)
    var red := _mat("jester_red", Color(0.85, 0.1, 0.15), 0.6, 0.0)
    var white := _mat("jester_white", Color(0.95, 0.95, 0.95), 0.9, 0.0)
    # Two-horned hat with gold bells.
    _put(head, _cyl_mesh(0.15, 0.15, 0.05), Vector3(0.0, 0.275, 0.0), purple)
    var horn := _cyl_mesh(0.02, 0.055, 0.2)
    _put(head, horn, Vector3(-0.158, 0.362, 0.0), purple, Vector3.ONE, Vector3(0.0, 0.0, 0.9))
    _put(head, horn, Vector3(0.158, 0.362, 0.0), green, Vector3.ONE, Vector3(0.0, 0.0, -0.9))
    _put(head, _sphere(), Vector3(-0.24, 0.41, 0.0), gold, Vector3(0.07, 0.07, 0.07))
    _put(head, _sphere(), Vector3(0.24, 0.41, 0.0), gold, Vector3(0.07, 0.07, 0.07))
    # Red cheeks and a red clown nose.
    _put(head, _sphere(), Vector3(-0.085, 0.125, -0.108), red, Vector3(0.05, 0.05, 0.02))
    _put(head, _sphere(), Vector3(0.085, 0.125, -0.108), red, Vector3(0.05, 0.05, 0.02))
    _put(head, _sphere(), Vector3(0.0, 0.13, -0.145), red, Vector3(0.055, 0.055, 0.055))
    # Ruffled collar and two diamonds on the chest.
    _put(upper, _cyl_mesh(0.22, 0.17, 0.07), Vector3(0.0, 0.62, 0.0), white)
    var dia := _box_mesh(Vector3(0.16, 0.16, 0.012))
    _put(upper, dia, Vector3(0.0, 0.4, -0.162), purple, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.25))
    _put(upper, dia, Vector3(0.0, 0.2, -0.162), green, Vector3.ONE, Vector3(0.0, 0.0, PI * 0.25))


## Glowing eyes laid over the zombie's own eyes (the Roid Rager's sit lower).
## Used by costumes that do not cover the head.
static func _head_eyes(head: Node3D, rager: bool, mat: Material) -> void:
    var y: float = 0.19
    var z: float = -0.123
    var x: float = 0.065
    if rager:
        y = 0.12
        z = -0.132
        x = 0.06
    _eye_pair(head, x, y, z, mat)


static func _eye_pair(parent: Node3D, x: float, y: float, z: float, mat: Material) -> void:
    var m := _box_mesh(Vector3(0.065, 0.05, 0.02))
    for sx in [-1.0, 1.0]:
        _put(parent, m, Vector3(sx * x, y, z), mat)


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
