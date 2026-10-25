extends Node
## Gym power-up manager. Created by round_manager.gd (host only).
## Other scripts find it with get_tree().get_first_node_in_group("powerup_manager")
## and ask has_effect("max_lift") / time_left("max_lift").
##
## Handles drops, pickups and the active timers. The on-screen display
## lives in scripts/ui/hud_powerups.gd (it listens to powerup_started).

signal powerup_started(id: String, duration: float)
signal powerup_ended(id: String)

const ENABLED: bool = true
const TEST_ALWAYS_DROP: bool = false   # true = every kill drops one (testing only)
const KILL_DROP_CHANCE: float = 0.04
const RAGER_DROP_CHANCE: float = 0.25
const GUARANTEE_MIN: float = 0.30      # guaranteed drop lands between 30% and 80% of the round's kills
const GUARANTEE_MAX: float = 0.80
const MAX_ON_FLOOR: int = 2
const DESPAWN_TIME: float = 30.0
const BLINK_TIME: float = 8.0
const PICKUP_PATH: String = "res://scripts/powerups/powerup_pickup.gd"

const ORDER: Array = ["max_lift", "pre_workout", "full_rack", "pr_day", "hot_yoga", "ice_bath", "cardio_kick", "spotter"]
const TYPES: Dictionary = {
    "max_lift": {"name": "MAX LIFT", "color": Color(1.0, 0.15, 0.1), "duration": 20.0},
    "pre_workout": {"name": "PRE-WORKOUT SURGE", "color": Color(1.0, 0.85, 0.1), "duration": 30.0},
    "full_rack": {"name": "FULL RACK", "color": Color(0.2, 1.0, 0.3), "duration": 0.0},
    "pr_day": {"name": "PR DAY", "color": Color(0.7, 0.3, 1.0), "duration": 45.0},
    "hot_yoga": {"name": "HOT YOGA", "color": Color(1.0, 0.5, 0.05), "duration": 20.0},
    "ice_bath": {"name": "ICE BATH", "color": Color(0.3, 0.9, 1.0), "duration": 20.0},
    "cardio_kick": {"name": "CARDIO KICK", "color": Color(0.3, 0.55, 1.0), "duration": 20.0},
    "spotter": {"name": "SPOTTER", "color": Color(1.0, 0.45, 0.7), "duration": 20.0},
}

var _active: Dictionary = {}
var _drops: Array = []
var _last_type: String = ""
var _guar_kill: int = 1
var _guar_done: bool = false
var _pickup_script: GDScript = null


func _ready() -> void:
    add_to_group("powerup_manager")
    _pickup_script = load(PICKUP_PATH) as GDScript
    if _pickup_script == null:
        push_warning("powerup_pickup.gd is missing; power-ups will not drop.")


func _process(delta: float) -> void:
    for id in _active.keys():
        var sid: String = str(id)
        _active[sid] = float(_active[sid]) - delta
        if float(_active[sid]) <= 0.0:
            _active.erase(sid)
            powerup_ended.emit(sid)


# ---------------------------------------------------------------- queries

func has_effect(id: String) -> bool:
    return _active.has(id)


func time_left(id: String) -> float:
    return float(_active.get(id, 0.0))


# ---------------------------------------------------------------- drops

## Called by round_manager at the start of each round.
func on_round_start(total: int) -> void:
    _guar_done = false
    var lo: int = maxi(1, int(ceil(total * GUARANTEE_MIN)))
    var hi: int = maxi(lo, int(floor(total * GUARANTEE_MAX)))
    _guar_kill = randi_range(lo, hi)


## Called by round_manager after every zombie death (killed = kills so far this round).
func on_zombie_killed(z: Node3D, killed: int, _total: int) -> void:
    if not ENABLED or _pickup_script == null:
        return
    var forced: bool = false
    var drop: bool = false
    if not _guar_done and killed >= _guar_kill:
        _guar_done = true
        forced = true
        drop = true
    elif TEST_ALWAYS_DROP:
        drop = true
    else:
        var chance: float = RAGER_DROP_CHANCE if _is_rager(z) else KILL_DROP_CHANCE
        drop = randf() < chance
    if not drop:
        return
    _clean_drops()
    if _drops.size() >= MAX_ON_FLOOR:
        if not forced:
            return
        var oldest = _drops[0]
        if is_instance_valid(oldest):
            oldest.queue_free()
        _drops.remove_at(0)
    spawn_drop(_roll_type(), _floor_pos(z))


func spawn_drop(id: String, pos: Vector3) -> Node3D:
    if _pickup_script == null or not TYPES.has(id):
        return null
    var info: Dictionary = TYPES[id]
    var p := _pickup_script.new() as Node3D
    if p == null:
        return null
    p.call("setup", self, id, str(info["name"]), info["color"], DESPAWN_TIME, BLINK_TIME)
    get_tree().current_scene.add_child(p)
    p.global_position = pos + Vector3(0.0, 0.05, 0.0)
    _drops.append(p)
    return p


## Called by a pickup when a player walks over it.
func collect(p: Node) -> void:
    var id: String = str(p.get("type_id"))
    _drops.erase(p)
    activate(id)


func activate(id: String) -> void:
    if not TYPES.has(id):
        return
    var info: Dictionary = TYPES[id]
    var dur: float = float(info["duration"])
    if dur > 0.0:
        _active[id] = dur  # picking up the same type again refreshes it
    powerup_started.emit(id, dur)


func _is_rager(z: Node) -> bool:
    var s: Script = z.get_script() as Script
    return s != null and s.resource_path.contains("roid_rager")


func _roll_type() -> String:
    var pool: Array = []
    for id in ORDER:
        if str(id) != _last_type:
            pool.append(id)
    var pick: String = str(pool[randi() % pool.size()])
    _last_type = pick
    return pick


func _clean_drops() -> void:
    var keep: Array = []
    for d in _drops:
        if is_instance_valid(d):
            keep.append(d)
    _drops = keep


## Floor under the dying zombie (falls back to about its feet).
func _floor_pos(z: Node3D) -> Vector3:
    var from_pos: Vector3 = z.global_position
    var query := PhysicsRayQueryParameters3D.create(from_pos, from_pos + Vector3(0.0, -3.0, 0.0))
    query.collision_mask = 1
    if z is CollisionObject3D:
        query.exclude = [(z as CollisionObject3D).get_rid()]
    var hit: Dictionary = z.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return from_pos - Vector3(0.0, 0.9, 0.0)
    return hit["position"]
