extends Node
## Touch aim assist. Child of look_area.gd.
## While aiming (AIM on) or holding FIRE, gently turns the camera toward the
## zombie closest to the crosshair. It aims at the HEAD if your crosshair is
## already near the head, otherwise at the chest, so it never drags a
## headshot aim down. It backs off while you turn fast.
## Perk hook: if the player has a has_headshot_assist() function that returns
## true (future Deadshot-style perk), it always aims at the head with a wider
## cone, even when the setting is OFF.

const DEFAULT_LEVEL: int = 2   # 0 OFF, 1 LOW, 2 MED, 3 HIGH (settings row comes next)

# Indexed by level (0 = off).
const CONE_DEG: Array = [0.0, 3.5, 5.5, 8.0]        # how close to the crosshair a zombie must be
const PULL_RATE: Array = [0.0, 2.0, 3.5, 5.5]       # pull strength per second
const MAX_TURN_DEG: Array = [0.0, 25.0, 40.0, 60.0]  # cap on how fast it may turn

const MAX_RANGE: float = 35.0
const MIN_DIST: float = 0.6
const HIP_FACTOR: float = 0.6          # weaker pull when firing without aiming
const AIMING_CONE_BONUS: float = 1.25  # wider cone while aiming
const PERK_CONE_BONUS: float = 1.4     # wider cone with the headshot perk
const HEAD_BIAS: float = 1.25          # favors the head when the crosshair is between head and chest
const LOCK_BONUS: float = 0.6          # sticks to the current target
const LOCK_KEEP: float = 1.3           # a locked target may leave the cone by this much
const DEADZONE_DEG: float = 0.25
const FADE_START: float = 250.0        # look speed (px/s) where the pull starts to fade
const FADE_END: float = 900.0          # look speed where it is fully off
const CHEST_Y: float = 0.15            # chest height above the zombie's middle
const LOS_MASK: int = 1                # world layer, blocks line of sight
const MAX_LOS_TESTS: int = 3

var _look_area: Control = null
var _player: Node = null
var _target: Node = null


func setup(look_area: Control) -> void:
    _look_area = look_area


func _physics_process(delta: float) -> void:
    if _look_area == null or not is_instance_valid(_look_area):
        return
    if not _look_area.is_visible_in_tree():
        return
    if _player == null or not is_instance_valid(_player):
        _player = get_tree().get_first_node_in_group("player")
        if _player == null:
            return
    var cam: Camera3D = _player.get("camera") as Camera3D
    if cam == null:
        return
    if bool(_player.get("is_downed")) or bool(_player.get("is_dead")):
        _target = null
        return
    if _player.get("current_weapon") == null:
        _target = null
        return

    var aiming: bool = bool(_player.get("is_aiming"))
    var firing: bool = bool(_player.get("touch_shooting"))
    if not aiming and not firing:
        _target = null
        return

    var perk: bool = _has_perk()
    var level: int = _level()
    if perk and level < 1:
        level = 1
    if level <= 0:
        _target = null
        return

    var fade: float = 1.0 - smoothstep(FADE_START, FADE_END, float(_look_area.get("drag_speed")))
    if fade <= 0.01:
        return

    var cone: float = deg_to_rad(CONE_DEG[level])
    if aiming:
        cone *= AIMING_CONE_BONUS
    if perk:
        cone *= PERK_CONE_BONUS

    var pick: Dictionary = _pick_target(cam, cone, perk)
    if pick.is_empty():
        _target = null
        return
    _target = pick["zombie"]
    var point: Vector3 = pick["point"]

    var d: Vector3 = (point - cam.global_position).normalized()
    var want_yaw: float = atan2(-d.x, -d.z)
    var yaw_err: float = wrapf(want_yaw - _player.rotation.y, -PI, PI)
    var want_pitch: float = asin(clampf(d.y, -1.0, 1.0))
    var pitch_err: float = want_pitch - cam.rotation.x
    if sqrt(yaw_err * yaw_err + pitch_err * pitch_err) < deg_to_rad(DEADZONE_DEG):
        return

    var strength: float = fade * (1.0 if aiming else HIP_FACTOR)
    var k: float = clampf(PULL_RATE[level] * strength * delta, 0.0, 1.0)
    var max_step: float = deg_to_rad(MAX_TURN_DEG[level]) * strength * delta
    var dyaw: float = clampf(yaw_err * k, -max_step, max_step)
    var dpitch: float = clampf(pitch_err * k, -max_step, max_step)
    _player.rotate_y(dyaw)
    cam.rotation.x = clampf(cam.rotation.x + dpitch, deg_to_rad(-89.0), deg_to_rad(89.0))


## Aim assist strength: 0 OFF, 1 LOW, 2 MED, 3 HIGH. Settings row comes later.
func _level() -> int:
    return DEFAULT_LEVEL


func _has_perk() -> bool:
    return _player.has_method("has_headshot_assist") and bool(_player.has_headshot_assist())


## Best zombie near the crosshair with a clear line of sight.
## Returns {"zombie": node, "point": world position to aim at}, or {} for none.
func _pick_target(cam: Camera3D, cone: float, perk: bool) -> Dictionary:
    var cands: Array = []
    for z in get_tree().get_nodes_in_group("zombies"):
        if not is_instance_valid(z) or not (z is Node3D):
            continue
        if bool(z.get("_is_dead")):
            continue
        var pts: Array = _points_of(z)
        var head: Vector3 = pts[0]
        var chest: Vector3 = pts[1]
        var ah: float = _angle_to(cam, head)
        var ac: float = _angle_to(cam, chest)
        var use_head: bool = perk or ah <= ac * HEAD_BIAS
        var pt: Vector3 = head if use_head else chest
        var a: float = ah if use_head else ac
        var dist: float = cam.global_position.distance_to(pt)
        if dist > MAX_RANGE or dist < MIN_DIST:
            continue
        var locked: bool = (z == _target)
        if a > cone * (LOCK_KEEP if locked else 1.0):
            continue
        cands.append([a * (LOCK_BONUS if locked else 1.0), z, pt])

    if cands.is_empty():
        return {}
    cands.sort_custom(func(x, y): return x[0] < y[0])
    var tests: int = mini(cands.size(), MAX_LOS_TESTS)
    for i in range(tests):
        var c: Array = cands[i]
        if _clear_line(cam, c[2]):
            return {"zombie": c[1], "point": c[2]}
    return {}


## [head point, chest point] for a zombie. The head point sits in the middle of
## the zombie's own headshot zone (above head_height_threshold).
func _points_of(z: Node3D) -> Array:
    var half: float = 0.95
    var shape_node := z.get_node_or_null("CollisionShape3D") as CollisionShape3D
    if shape_node != null and shape_node.shape is CapsuleShape3D:
        half = (shape_node.shape as CapsuleShape3D).height * 0.5
    var thr: float = 0.5
    var t = z.get("head_height_threshold")
    if t != null:
        thr = float(t)
    var head_y: float = lerpf(thr, half, 0.5)
    var chest_y: float = minf(CHEST_Y, thr * 0.4)
    var o: Vector3 = z.global_position
    return [Vector3(o.x, o.y + head_y, o.z), Vector3(o.x, o.y + chest_y, o.z)]


func _angle_to(cam: Camera3D, point: Vector3) -> float:
    var forward: Vector3 = -cam.global_transform.basis.z
    return forward.angle_to((point - cam.global_position).normalized())


func _clear_line(cam: Camera3D, point: Vector3) -> bool:
    var query := PhysicsRayQueryParameters3D.create(cam.global_position, point, LOS_MASK)
    query.exclude = [_player.get_rid()]
    var hit: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(query)
    return hit.is_empty()

# END OF FILE
