extends Area3D
## Loot Locker: the gym version of the mystery box. Pay Gains, the locker
## rattles while a random gun cycles by, then the door swings open and the
## gun floats out. Tap USE again within take_window seconds to grab it, or
## the locker closes and you lose it. Built entirely in code.
## Pulling a gun you already own gives it a full ammo refill (player.grant_weapon).
##
## Rarity: every roll also rolls a tier (weapon_rarity.gd) before the gun is shown.
## Higher tiers add damage and fixed random attachments to that gun.
##
## Several lockers on one map: only ONE is usable at a time (picked at random
## when the map loads); the rest show an OUT OF ORDER sign. Every roll also has
## a chance to lock the locker (same odds as one gun): you are refunded, the
## sign appears and a different locker becomes the usable one.
## Co-op: the host picks the first one, then every lock is sent to all phones.
##
## Custom game mode: Loot Locker off = the locker is hidden and unusable;
## weapon rarity off = every gun it gives is common.
##
## EASTER EGG: shoot the locker EASTER_HITS times (total per run, counted by
## player_controller._fire_shot -> easter_hit) and it opens by itself and offers
## the Locker Launcher (wonder_weapons.build_locker_launcher). Free, tap USE to
## grab it. This is the ONLY way to get that gun. Once grabbed it never repeats
## in the same run; if you miss the take window the next hit offers it again.

## TEST MODE for the rarity swap. Set to true to test, back to false when done.
## On: every pull gives the SAME gun, with the rarity stepping through TEST_TIERS
## (and looping). The locker never locks up while this is on.
const TEST_RARITY_SWAP: bool = false
## Gun to use in test mode (exact weapon name). Leave "" for a random gun.
const TEST_GUN_NAME: String = ""
## Rarity of each pull in test mode, in order, then it starts over.
const TEST_TIERS: Array = ["common", "uncommon", "rare", "rare", "common", "legendary"]

const DISPLAY_LENGTH: float = 0.9  # every gun shown in the locker is scaled to this length (meters)
const LABEL_HOME: Vector3 = Vector3(0, 2.6, 0)   # where the name sits when no gun is showing
const WONDER_PATH: String = "res://scripts/weapons/wonder_weapons.gd"
const WONDER_CHANCE: float = 0.02        # chance per pull to roll a wonder weapon
const WONDER_GUARANTEE_USE: int = 30     # the 30th pull of a run always gives one (once)
const EASTER_HITS: int = 25              # shots on the locker that unlock the Locker Launcher

enum State { IDLE, ROLLING, READY, LOCKED }

@export var cost: int = 950
@export var roll_time: float = 2.5
@export var take_window: float = 8.0

static var _test_gun: WeaponData = null
static var _test_step: int = 0

var _disabled: bool = false
var _state: int = State.IDLE
var _is_active: bool = true
var _will_lock: bool = false
var _pool: Array = []
var _total_weight: int = 0
var _rolled: WeaponData = null
var _tier: String = "common"
var _rarity = null
var _timer: float = 0.0
var _cycle_timer: float = 0.0
var _is_wonder: bool = false
var _is_easter: bool = false
var _rattle_tween: Tween = null

var _visual_root: Node3D
var _door_pivot: Node3D
var _label: Label3D
var _display_mount: Node3D
var _display_model: Node3D = null
var _sign: Node3D


func _ready() -> void:
    if not GameManager.custom_on("loot_locker"):
        # Custom game mode: this locker is not part of the run.
        _disabled = true
        visible = false
        monitoring = false
        monitorable = false
        set_process(false)
        _disable_shapes.call_deferred(self)
        return
    add_to_group("loot_lockers")
    _build_visuals()
    var locker_weapons = load("res://scripts/weapons/locker_weapons.gd")
    if locker_weapons:
        _pool = locker_weapons.build_pool()
    for entry in _pool:
        _total_weight += int(entry["weight"])
    var rarity_script = load("res://scripts/weapons/weapon_rarity.gd")
    if rarity_script and GameManager.custom_on("rarity"):
        _rarity = rarity_script.new()
    _set_idle_label()
    _init_active.call_deferred()


## Turns off every collision shape under this node (after the scene is fully built).
func _disable_shapes(node: Node) -> void:
    if node is CollisionShape3D:
        (node as CollisionShape3D).disabled = true
    for child in node.get_children():
        _disable_shapes(child)


func _build_visuals() -> void:
    _visual_root = Node3D.new()
    add_child(_visual_root)

    var paint := Color(0.16, 0.30, 0.55)
    var paint_dark := Color(0.10, 0.19, 0.36)
    var door_col := Color(0.24, 0.42, 0.72)
    var door_light := Color(0.30, 0.50, 0.80)
    var chrome := Color(0.78, 0.80, 0.84)
    var yellow := Color(1.0, 0.77, 0.0)
    var dark := Color(0.04, 0.04, 0.06)
    var blood := Color(0.35, 0.02, 0.02)

    # Body shell, rounded front/back corners, top cap and base plinth
    _add_box(_visual_root, Vector3(1.0, 2.0, 0.8), Vector3(0, 1.0, 0), paint)
    for cx in [-0.5, 0.5]:
        for cz in [-0.4, 0.4]:
            _add_cyl(_visual_root, 0.035, 2.0, Vector3(cx, 1.0, cz), paint_dark)
    _add_box(_visual_root, Vector3(1.06, 0.06, 0.86), Vector3(0, 2.03, 0), paint_dark, 0.45, 0.3)
    _add_box(_visual_root, Vector3(1.06, 0.12, 0.86), Vector3(0, 0.06, 0), dark, 0.8)
    for sx in [-0.506, 0.506]:
        for sz in [-0.2, 0.2]:
            _add_box(_visual_root, Vector3(0.012, 1.8, 0.04), Vector3(sx, 1.0, sz), paint_dark)

    # Inside (seen when the door is open): dark back, glow strip, hook, towel
    _add_box(_visual_root, Vector3(0.9, 1.9, 0.02), Vector3(0, 1.0, 0.402), Color(0.03, 0.04, 0.07), 0.9)
    _add_box(_visual_root, Vector3(0.8, 0.025, 0.01), Vector3(0, 1.88, 0.412), yellow, 0.4, 0.0, Vector3.ZERO, 1.5)
    _add_cyl(_visual_root, 0.012, 0.7, Vector3(0, 1.75, 0.42), chrome, Vector3(0, 0, PI * 0.5), 0.3, 0.8)
    _add_box(_visual_root, Vector3(0.28, 0.55, 0.015), Vector3(-0.2, 1.45, 0.42), Color(0.9, 0.9, 0.9), 0.95)
    _add_box(_visual_root, Vector3(0.28, 0.04, 0.016), Vector3(-0.2, 1.3, 0.42), Color(0.85, 0.15, 0.15), 0.95)

    # Door, hinged on its left edge (slightly smaller than the body so the frame shows)
    _door_pivot = Node3D.new()
    _door_pivot.position = Vector3(-0.47, 1.0, 0.42)
    _visual_root.add_child(_door_pivot)
    _add_box(_door_pivot, Vector3(0.94, 1.86, 0.05), Vector3(0.47, 0, 0), door_col, 0.5, 0.2)
    _add_box(_door_pivot, Vector3(0.80, 1.70, 0.012), Vector3(0.47, 0, 0.03), door_light, 0.55, 0.2)
    # Vent slots (top and bottom)
    for vy in [0.74, 0.66, 0.58, -0.72, -0.80, -0.88]:
        _add_box(_door_pivot, Vector3(0.5, 0.025, 0.012), Vector3(0.47, vy, 0.036), dark, 0.9)
    # Number plate
    _add_box(_door_pivot, Vector3(0.16, 0.09, 0.01), Vector3(0.47, 0.42, 0.038), yellow, 0.5)
    var num := Label3D.new()
    num.text = "%02d" % (1 + randi() % 98)
    num.font_size = 24
    num.pixel_size = 0.003
    num.modulate = dark
    num.outline_size = 0
    num.position = Vector3(0.47, 0.42, 0.046)
    _door_pivot.add_child(num)
    # Latch and handle
    _add_box(_door_pivot, Vector3(0.07, 0.32, 0.02), Vector3(0.82, 0.0, 0.042), chrome, 0.3, 0.8)
    _add_box(_door_pivot, Vector3(0.03, 0.22, 0.03), Vector3(0.82, 0.0, 0.066), chrome, 0.25, 0.9)
    # Hinges
    for hy in [0.7, 0.0, -0.7]:
        _add_cyl(_door_pivot, 0.018, 0.14, Vector3(0.0, hy, 0.0), chrome, Vector3.ZERO, 0.3, 0.8)
    # Gym sticker, scuffs, rust and blood
    _add_box(_door_pivot, Vector3(0.22, 0.12, 0.006), Vector3(0.3, 0.12, 0.037), Color(0.8, 0.08, 0.08), 0.6, 0.0, Vector3(0, 0, 0.15))
    var sticker := Label3D.new()
    sticker.text = "NO PAIN"
    sticker.font_size = 14
    sticker.pixel_size = 0.003
    sticker.outline_size = 0
    sticker.position = Vector3(0.3, 0.12, 0.042)
    sticker.rotation.z = 0.15
    _door_pivot.add_child(sticker)
    _add_box(_door_pivot, Vector3(0.18, 0.05, 0.006), Vector3(0.62, -0.25, 0.037), paint_dark, 0.8, 0.0, Vector3(0, 0, -0.4))
    _add_box(_door_pivot, Vector3(0.34, 0.04, 0.006), Vector3(0.4, -0.9, 0.037), Color(0.35, 0.2, 0.08), 0.9)
    _add_box(_door_pivot, Vector3(0.05, 0.2, 0.006), Vector3(0.2, -0.38, 0.037), blood, 0.4, 0.0, Vector3(0, 0, 0.1))
    _add_box(_door_pivot, Vector3(0.02, 0.14, 0.006), Vector3(0.12, -0.55, 0.037), blood, 0.4)
    _add_box(_door_pivot, Vector3(0.02, 0.09, 0.006), Vector3(0.27, -0.5, 0.037), blood, 0.4)

    # OUT OF ORDER sign, taped across the door
    _sign = Node3D.new()
    _sign.position = Vector3(0, 1.0, 0.5)
    _sign.rotation_degrees = Vector3(0, 0, 12)
    _sign.visible = false
    _visual_root.add_child(_sign)
    _add_box(_sign, Vector3(0.95, 0.32, 0.03), Vector3.ZERO, Color(0.8, 0.1, 0.1))
    var sign_text := Label3D.new()
    sign_text.text = "OUT OF ORDER"
    sign_text.font_size = 40
    sign_text.pixel_size = 0.004
    sign_text.outline_size = 6
    sign_text.position = Vector3(0, 0, 0.025)
    _sign.add_child(sign_text)

    _label = Label3D.new()
    _label.font_size = 48
    _label.pixel_size = 0.006
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.outline_size = 12
    _label.position = Vector3(0, 2.6, 0)
    add_child(_label)

    # Where the rolled gun floats
    _display_mount = Node3D.new()
    _display_mount.position = Vector3(0, 1.3, 0.9)
    add_child(_display_mount)


## Shared materials and meshes: all lockers reuse the same ones.
static var _mat_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func _mat(color: Color, rough: float, metal: float, glow: float) -> StandardMaterial3D:
    var key: String = "%s_%.2f_%.2f_%.2f" % [color.to_html(), rough, metal, glow]
    var cached = _mat_cache.get(key)
    if cached != null:
        return cached as StandardMaterial3D
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    m.metallic = metal
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = glow
    _mat_cache[key] = m
    return m


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rough: float = 0.6, metal: float = 0.0, rot: Vector3 = Vector3.ZERO, glow: float = 0.0) -> MeshInstance3D:
    var key: String = "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
    var mesh = _mesh_cache.get(key)
    if mesh == null:
        var box := BoxMesh.new()
        box.size = size
        _mesh_cache[key] = box
        mesh = box
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = mesh as Mesh
    mesh_instance.material_override = _mat(color, rough, metal, glow)
    mesh_instance.position = pos
    mesh_instance.rotation = rot
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh_instance)
    return mesh_instance


func _add_cyl(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, rough: float = 0.6, metal: float = 0.0) -> MeshInstance3D:
    var key: String = "cyl_%.3f_%.3f" % [radius, height]
    var mesh = _mesh_cache.get(key)
    if mesh == null:
        var c := CylinderMesh.new()
        c.top_radius = radius
        c.bottom_radius = radius
        c.height = height
        c.radial_segments = 10
        c.rings = 1
        _mesh_cache[key] = c
        mesh = c
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = mesh as Mesh
    mesh_instance.material_override = _mat(color, rough, metal, 0.0)
    mesh_instance.position = pos
    mesh_instance.rotation = rot
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mesh_instance)
    return mesh_instance


# ------------------------------------------------- which locker is usable

## Every locker on the map, in the same order on every phone.
func _all_lockers() -> Array:
    var all: Array = get_tree().get_nodes_in_group("loot_lockers")
    all.sort_custom(func(a, b): return str(a.get_path()) < str(b.get_path()))
    return all


## Runs once per locker right after the map loads. Maps with one locker keep
## the old behaviour (always usable, never locks).
func _init_active() -> void:
    var all: Array = _all_lockers()
    if all.size() <= 1:
        return
    var is_host: bool = (not NetManager.is_online) or multiplayer.is_server()
    if not is_host:
        # Wait for the host to say which locker is usable.
        _set_active(false)
        if all[0] == self:
            _net_request.rpc_id(1)
        return
    if all[0] == self:
        _apply_active(randi() % all.size())


## Makes locker number idx (in sorted order) the usable one, all others locked.
func _apply_active(idx: int) -> void:
    var all: Array = _all_lockers()
    for i in all.size():
        all[i]._set_active(i == idx)


func _set_active(on: bool) -> void:
    _is_active = on
    if on:
        if _state == State.LOCKED:
            _state = State.IDLE
            _sign.visible = false
            _set_idle_label()
    elif _state != State.LOCKED:
        _state = State.LOCKED
        _rolled = null
        _will_lock = false
        _tier = "common"
        _visual_root.position = Vector3.ZERO
        _clear_model()
        _set_door_open(false)
        _sign.visible = true
        _label.modulate = Color.WHITE
        _label.text = "OUT OF ORDER"


## Co-op: a client asks the host which locker is usable.
@rpc("any_peer", "call_remote", "reliable")
func _net_request() -> void:
    var sender: int = multiplayer.get_remote_sender_id()
    var all: Array = _all_lockers()
    for i in all.size():
        if all[i]._is_active:
            _net_active.rpc_id(sender, i)
            return


## Co-op: tells this phone which locker is now the usable one.
@rpc("any_peer", "call_remote", "reliable")
func _net_active(idx: int) -> void:
    _apply_active(idx)
# ------------------------------------------------------------- using it

func _process(delta: float) -> void:
    _update_label_spot()
    if _state == State.ROLLING:
        _timer -= delta
        # Rattle the whole locker a little
        _visual_root.position = Vector3(randf_range(-0.03, 0.03), 0.0, randf_range(-0.03, 0.03))
        # Flip through random guns for suspense
        _cycle_timer -= delta
        if _cycle_timer <= 0.0:
            _cycle_timer = 0.2
            _show_model(_random_weapon())
        if _timer <= 0.0:
            _finish_roll()
    elif _state == State.READY:
        _timer -= delta
        if _is_wonder and _rolled != null:
            # Rainbow name for wonder weapons (slow hue cycle).
            _label.modulate = Color.from_hsv(
                fposmod(float(Time.get_ticks_msec()) * 0.0003, 1.0), 0.65, 1.0
            )
        if _display_model:
            _display_mount.rotate_y(delta * 1.5)
        if _timer <= 0.0:
            _close_locker()


## Keeps the name directly above the gun that is showing. With no gun showing,
## it goes back to its normal spot above the locker.
func _update_label_spot() -> void:
    if _label == null or _display_mount == null:
        return
    if _display_model == null:
        _label.position = LABEL_HOME
        return
    var lines: int = _label.text.count("\n") + 1
    _label.position = _display_mount.position + Vector3(0.0, 0.32 + 0.17 * float(lines), 0.0)


func interact(player: Node) -> void:
    if _disabled:
        return
    if _state == State.IDLE:
        if GameManager.try_spend_gains(GameManager.loot_locker_cost(cost)):
            _start_roll(player)
    elif _state == State.READY:
        if _rolled and player.has_method("grant_weapon"):
            player.grant_weapon(_rolled)
            if _is_easter:
                player.set_meta("locker_launcher_given", true)
        _close_locker()


func get_prompt_text() -> String:
    if _disabled:
        return ""
    if _state == State.IDLE:
        return "Tap USE to open Loot Locker - %d Gains" % GameManager.loot_locker_cost(cost)
    if _state == State.READY and _rolled:
        return "Tap USE to grab %s%s" % [_rarity_prefix(), _rolled.weapon_name]
    if _state == State.LOCKED:
        return "Out of order"
    return ""


## Easter egg: called by player_controller for every shot that lands on this
## locker. Counts hits for the whole run; at EASTER_HITS the locker opens by
## itself and offers the Locker Launcher.
func easter_hit(player: Node) -> void:
    if _disabled or not _is_active or player == null:
        return
    if bool(player.get_meta("locker_launcher_given", false)):
        return
    var hits: int = int(player.get_meta("locker_hits", 0)) + 1
    player.set_meta("locker_hits", hits)
    _rattle()
    if hits >= EASTER_HITS and _state == State.IDLE:
        _start_easter_roll()


## The locker shakes for a moment when it is shot.
func _rattle() -> void:
    if _visual_root == null or _state != State.IDLE:
        return
    if _rattle_tween != null and _rattle_tween.is_valid():
        _rattle_tween.kill()
    _visual_root.position = Vector3.ZERO
    _rattle_tween = create_tween()
    for i in range(4):
        var shake := Vector3(randf_range(-0.04, 0.04), 0.0, randf_range(-0.04, 0.04))
        _rattle_tween.tween_property(_visual_root, "position", shake, 0.03)
    _rattle_tween.tween_property(_visual_root, "position", Vector3.ZERO, 0.03)


## Free forced roll that ends on the Locker Launcher.
func _start_easter_roll() -> void:
    var script = load(WONDER_PATH)
    if script == null:
        return
    var launcher: WeaponData = script.build_locker_launcher()
    if launcher == null:
        return
    if _rattle_tween != null and _rattle_tween.is_valid():
        _rattle_tween.kill()
    _tier = "common"
    _is_wonder = true
    _is_easter = true
    _will_lock = false
    _rolled = launcher
    _state = State.ROLLING
    _timer = roll_time
    _cycle_timer = 0.0
    _label.modulate = Color.WHITE
    _label.text = "..."


func _start_roll(player: Node = null) -> void:
    _tier = "common"
    _is_wonder = false
    _is_easter = false
    var wonder: WeaponData = _roll_wonder(player)
    if wonder != null:
        # Wonder weapon: never locks up, no rarity.
        _is_wonder = true
        _will_lock = false
        _rolled = wonder
    elif TEST_RARITY_SWAP:
        # Test mode: same gun every pull, rarity steps through TEST_TIERS, no lock-up.
        _will_lock = false
        _rolled = _test_weapon()
        _tier = str(TEST_TIERS[_test_step % TEST_TIERS.size()])
        _test_step += 1
        if _rarity != null and _rolled != null:
            _rolled = _rarity.apply(_rolled, _tier)
    else:
        _will_lock = _roll_lock()
        _rolled = _pick_weapon()
        if _rarity != null and _rolled != null:
            _tier = _rarity.roll_tier()
            _rolled = _rarity.apply(_rolled, _tier)
    _state = State.ROLLING
    _timer = roll_time
    _cycle_timer = 0.0
    _label.modulate = Color.WHITE
    _label.text = "..."


## Wonder weapon roll. Counts this player's pulls (resets every run): a low chance
## each pull, and the 30th pull always gives one. Which wonder weapon it is gets
## picked at random (wonder_weapons.random_wonder). Returns null for a normal roll.
func _roll_wonder(player: Node) -> WeaponData:
    if player == null or TEST_RARITY_SWAP:
        return null
    var script = load(WONDER_PATH)
    if script == null:
        return null
    var uses: int = int(player.get_meta("locker_uses", 0)) + 1
    player.set_meta("locker_uses", uses)
    if uses == WONDER_GUARANTEE_USE or randf() < WONDER_CHANCE:
        return script.random_wonder()
    return null


## Test mode gun: TEST_GUN_NAME if set and found, otherwise one random gun that
## is then kept for every later pull.
func _test_weapon() -> WeaponData:
    if _test_gun == null:
        if TEST_GUN_NAME != "":
            for entry in _pool:
                if entry["weapon"].weapon_name == TEST_GUN_NAME:
                    _test_gun = entry["weapon"]
                    break
        if _test_gun == null:
            _test_gun = _pick_weapon()
    return _test_gun


## The lock outcome has the same weight as one gun (the average gun weight).
## Only possible when the map has more than one locker.
func _roll_lock() -> bool:
    if _pool.is_empty() or _all_lockers().size() <= 1:
        return false
    var avg: int = maxi(int(float(_total_weight) / float(_pool.size())), 1)
    return randi() % (_total_weight + avg) < avg


func _finish_roll() -> void:
    _visual_root.position = Vector3.ZERO
    if _will_lock:
        _will_lock = false
        _lock_up()
        return
    _show_model(_rolled)
    _set_door_open(true)
    _state = State.READY
    _timer = take_window
    if _rolled:
        _label.text = "%s%s" % [_rarity_prefix(), _rolled.weapon_name]
        if _is_easter:
            _label.text = "SECRET WEAPON\n%s" % _rolled.weapon_name
            _label.modulate = Color(1.0, 0.85, 0.2)
        elif _is_wonder:
            _label.text = "WONDER WEAPON\n%s" % _rolled.weapon_name
            _label.modulate = Color(0.75, 0.45, 1.0)
        elif _rarity != null:
            _label.modulate = _rarity.tier_color(_tier)
    else:
        _label.text = "Empty"


## Out of order: refund the roll, show the sign, and move to another locker.
func _lock_up() -> void:
    GameManager.add_gains(GameManager.loot_locker_cost(cost))
    var all: Array = _all_lockers()
    var me: int = all.find(self)
    var next: int = randi() % (all.size() - 1)
    if next >= me:
        next += 1
    _apply_active(next)
    if NetManager.is_online:
        _net_active.rpc(next)


func _close_locker() -> void:
    _state = State.IDLE
    _rolled = null
    _tier = "common"
    _is_wonder = false
    _is_easter = false
    _visual_root.position = Vector3.ZERO
    _clear_model()
    _set_door_open(false)
    _set_idle_label()


## "Epic " for non-common tiers, "" for common.
func _rarity_prefix() -> String:
    if _rarity == null or _tier == "common":
        return ""
    return _rarity.tier_name(_tier) + " "


func _set_idle_label() -> void:
    _label.modulate = Color.WHITE
    _label.text = "LOOT LOCKER\n%d Gains" % GameManager.loot_locker_cost(cost)


func _set_door_open(open: bool) -> void:
    var tween := create_tween()
    tween.tween_property(_door_pivot, "rotation_degrees:y", -110.0 if open else 0.0, 0.3)


func _show_model(w: WeaponData) -> void:
    _clear_model()
    if w == null:
        return
    var model: Node3D = w.create_model()
    if model:
        _display_model = model
        if not w.model_scene:
            model.rotation_degrees.y = -90.0  # turn built-in guns side-on, like the asset guns
        _display_mount.add_child(model)
        _fit_model(model)


func _collect_meshes(node: Node, out: Array) -> void:
    if node is MeshInstance3D:
        out.append(node)
    for child in node.get_children():
        _collect_meshes(child, out)


## Scales the shown gun so its longest side is DISPLAY_LENGTH, and centers it
## on the mount so it spins around its middle.
func _fit_model(model: Node3D) -> void:
    var meshes: Array = []
    _collect_meshes(model, meshes)
    var to_mount: Transform3D = _display_mount.global_transform.affine_inverse()
    var box := AABB()
    var found: bool = false
    for m in meshes:
        var mi: MeshInstance3D = m
        var local_box: AABB = (to_mount * mi.global_transform) * mi.get_aabb()
        if found:
            box = box.merge(local_box)
        else:
            box = local_box
            found = true
    if not found:
        return
    var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
    if longest <= 0.0001:
        return
    var factor: float = DISPLAY_LENGTH / longest
    model.scale = Vector3.ONE * factor
    model.position = -box.get_center() * factor


func _clear_model() -> void:
    if _display_model:
        _display_model.queue_free()
        _display_model = null
    _display_mount.rotation = Vector3.ZERO


func _pick_weapon() -> WeaponData:
    if _pool.is_empty():
        return null
    var roll: int = randi() % maxi(_total_weight, 1)
    for entry in _pool:
        roll -= int(entry["weight"])
        if roll < 0:
            return entry["weapon"]
    return _pool[0]["weapon"]


func _random_weapon() -> WeaponData:
    if _pool.is_empty():
        return null
    return _pool[randi() % _pool.size()]["weapon"]

# END OF FILE
