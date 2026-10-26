extends Node
## Round-based spawner. Place spawn points as Marker3D nodes in the
## "spawn_points" group, and set zombie_scene / roid_rager_scene.
## Tag a spawn point with metadata "zone" (metadata/zone = "hall") and it only
## spawns zombies once that zone is unlocked. Untagged points are always on.
## Drop this node into the main level scene.
##
## Leash: a zombie that stays far from every living player for a few seconds is
## moved to a spawn point near that player (same zombie, same health, and the
## round's zombie count is unchanged). Only real zombies are moved, not puppets.
##
## Power-ups: creates the power-up manager (scripts/powerups/powerup_manager.gd)
## and tells it when a round starts and when a zombie dies.

signal zombies_changed(remaining: int, total: int)

const POWERUP_MANAGER_PATH: String = "res://scripts/powerups/powerup_manager.gd"

@export var zombie_scene: PackedScene
@export var roid_rager_scene: PackedScene
@export var pumpkin_boss_scene: PackedScene
@export var base_zombies_per_round: int = 6
@export var zombies_per_round_growth: int = 3
@export var time_between_spawns: float = 1.2
@export var time_between_rounds: float = 8.0
@export var roid_rager_every_n_rounds: int = 3
@export var min_spawn_distance: float = 8.0  # don't spawn right on top of the player
@export var nearest_spawn_pool: int = 3      # pick randomly among this many closest points
@export var leash_distance: float = 45.0     # farther than this from every player = "too far"
@export var leash_seconds: float = 5.0       # how long it must stay too far before it is moved
@export var respawn_min_distance: float = 12.0  # moved zombies land at least this far from the player

var _spawn_points: Array = []
var _round_active: bool = false
var _round_total: int = 0
var _round_killed: int = 0
var _last_boss_spawn_round: int = -999
var _leash_timer: float = 1.0
var _powerups = null


func _ready() -> void:
    _spawn_points = get_tree().get_nodes_in_group("spawn_points")
    if _spawn_points.is_empty():
        push_warning("RoundManager: no nodes in group 'spawn_points' found.")
    _make_powerup_manager()
    # Deferred so main.gd has reset the run and hooked up the HUD first.
    _start_round.call_deferred()


func _make_powerup_manager() -> void:
    var script := load(POWERUP_MANAGER_PATH) as GDScript
    if script == null:
        push_warning("RoundManager: powerup_manager.gd is missing; no power-ups this run.")
        return
    _powerups = script.new()
    add_child(_powerups)


func _physics_process(delta: float) -> void:
    _leash_timer -= delta
    if _leash_timer > 0.0:
        return
    _leash_timer = 1.0
    _check_far_zombies()


func get_zombies_total() -> int:
    return _round_total


func get_zombies_remaining() -> int:
    return maxi(_round_total - _round_killed, 0)


func _start_round() -> void:
    _round_active = true
    _round_killed = 0

    var normal_count: int = base_zombies_per_round \
        + (GameManager.round_number - 1) * zombies_per_round_growth
    var spawn_boss: bool = _should_spawn_pumpkin()

    _round_total = normal_count + (1 if spawn_boss else 0)

    if _powerups != null:
        _powerups.on_round_start(_round_total)

    _emit_counts()
    _spawn_wave(normal_count, spawn_boss)


func _spawn_wave(count: int, spawn_boss: bool = false) -> void:
    if _spawn_points.is_empty() or not zombie_scene:
        push_warning("RoundManager: no spawn points or zombie_scene, nothing to spawn.")
        return

    for i in range(count):
        await get_tree().create_timer(time_between_spawns).timeout
        _spawn_one_zombie()

    if spawn_boss:
        _spawn_pumpkin_boss()

func _spawn_one_zombie() -> void:
    var scene_to_use: PackedScene = zombie_scene
    var is_special_round := GameManager.round_number % roid_rager_every_n_rounds == 0
    if is_special_round and roid_rager_scene and randf() < 0.25:
        scene_to_use = roid_rager_scene

    var point: Marker3D = _pick_spawn_point()
    var zombie: Zombie = scene_to_use.instantiate()
    get_tree().current_scene.add_child(zombie)
    zombie.global_position = point.global_position
    zombie.died.connect(_on_zombie_died)

func _should_spawn_pumpkin() -> bool:
    if pumpkin_boss_scene == null:
        return false

    var scene := get_tree().current_scene
    if scene == null or scene.scene_file_path.get_file() != "halloween_map.tscn":
        return false

    var round_num: int = GameManager.round_number
    if round_num < 5:
        return false

    if round_num - _last_boss_spawn_round < 5:
        return false

    for node in get_tree().get_nodes_in_group("great_pumpkin"):
        if is_instance_valid(node) and not node.is_queued_for_deletion():
            return false

    return randf() < 0.15


func _spawn_pumpkin_boss() -> void:
    if pumpkin_boss_scene == null:
        return

    var candidates: Array[Marker3D] = []
    for point in _spawn_points:
        if not is_instance_valid(point):
            continue

        if str(point.get_meta("zone", "")) == "graveyard" \
                and absf(point.global_position.x) >= 6.0:
            candidates.append(point as Marker3D)

    var spawn_position: Vector3 = Vector3(-7.0, 2.2, -4.0)
    if not candidates.is_empty():
        var point: Marker3D = candidates[randi_range(0, candidates.size() - 1)]
        spawn_position = point.global_position + Vector3(0.0, 1.2, 0.0)

    var boss := pumpkin_boss_scene.instantiate() as Zombie
    if boss == null:
        push_warning("RoundManager: Great Pumpkin scene is not a Zombie.")
        return

    get_tree().current_scene.add_child(boss)
    boss.global_position = spawn_position
    boss.died.connect(_on_zombie_died)

    _last_boss_spawn_round = GameManager.round_number

## Only unlocked zones, not too close to the player, random among the nearest few.
func _pick_spawn_point() -> Marker3D:
    var eligible: Array = []
    for p in _spawn_points:
        var zone: String = str(p.get_meta("zone", ""))
        if GameManager.is_zone_unlocked(zone):
            eligible.append(p)
    if eligible.is_empty():
        eligible = _spawn_points.duplicate()

    var player := get_tree().get_first_node_in_group("player") as Node3D
    if player == null:
        return eligible[randi() % eligible.size()]

    var player_pos: Vector3 = player.global_position
    var candidates: Array = []
    for p in eligible:
        if p.global_position.distance_to(player_pos) >= min_spawn_distance:
            candidates.append(p)
    if candidates.is_empty():
        candidates = eligible

    candidates.sort_custom(func(a, b): return a.global_position.distance_to(player_pos) < b.global_position.distance_to(player_pos))
    var pool_size: int = mini(nearest_spawn_pool, candidates.size())
    return candidates[randi() % pool_size]


# ---------------------------------------------------------------- leash

## Runs once a second: counts how long each zombie has been far from everyone.
func _check_far_zombies() -> void:
    var players: Array = []
    for group_name in ["player", "remote_players"]:
        for n in get_tree().get_nodes_in_group(group_name):
            var p := n as Node3D
            if p != null and is_instance_valid(p) and not _player_is_out(p):
                players.append(p)
    if players.is_empty():
        return

    for n in get_tree().get_nodes_in_group("zombies"):
        var z := n as Zombie
        if z == null or not is_instance_valid(z) or z.is_puppet:
            continue
        var nearest: Node3D = null
        var best: float = INF
        for q in players:
            var pn: Node3D = q
            var d: float = z.global_position.distance_to(pn.global_position)
            if d < best:
                best = d
                nearest = pn
        if best <= leash_distance:
            z.set_meta("far_time", 0.0)
            continue
        var far_time: float = float(z.get_meta("far_time", 0.0)) + 1.0
        z.set_meta("far_time", far_time)
        if far_time >= leash_seconds and nearest != null:
            if _relocate_zombie(z, nearest, best):
                z.set_meta("far_time", 0.0)


## Moves a far zombie to an unlocked spawn point near the player.
## Prefers points the player can't see. Returns false if nothing suitable.
func _relocate_zombie(z: Zombie, player: Node3D, current_dist: float) -> bool:
    var pos: Vector3 = player.global_position
    var near: Array = []
    for p in _spawn_points:
        var zone: String = str(p.get_meta("zone", ""))
        if not GameManager.is_zone_unlocked(zone):
            continue
        var d: float = p.global_position.distance_to(pos)
        if d >= respawn_min_distance and d <= leash_distance * 0.8 and d < current_dist:
            near.append(p)
    if near.is_empty():
        return false

    var hidden: Array = []
    for p in near:
        if not _player_can_see(player, p.global_position):
            hidden.append(p)
    var pool: Array = near
    if not hidden.is_empty():
        pool = hidden
    pool.sort_custom(func(a, b): return a.global_position.distance_to(pos) < b.global_position.distance_to(pos))
    var pick: Node3D = pool[randi() % mini(nearest_spawn_pool, pool.size())]
    z.global_position = pick.global_position
    z.velocity = Vector3.ZERO
    return true


func _player_can_see(player: Node3D, point: Vector3) -> bool:
    var from_pos: Vector3 = player.global_position + Vector3(0.0, 0.6, 0.0)
    var query := PhysicsRayQueryParameters3D.create(from_pos, point + Vector3(0.0, 1.0, 0.0))
    query.collision_mask = 1
    if player is CollisionObject3D:
        query.exclude = [(player as CollisionObject3D).get_rid()]
    return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## True for a co-op player who is downed or dead: they don't count for the leash.
func _player_is_out(p: Node) -> bool:
    return bool(p.get("is_downed")) or bool(p.get("is_dead")) or bool(p.get_meta("downed", false)) or bool(p.get_meta("dead", false))


# ---------------------------------------------------------------- rounds

func _on_zombie_died(zombie: Zombie) -> void:
    _round_killed += 1
    if _powerups != null and is_instance_valid(zombie):
        _powerups.on_zombie_killed(zombie, _round_killed, _round_total)
    _emit_counts()
    if _round_killed >= _round_total and _round_active:
        _round_active = false
        _end_round()


func _emit_counts() -> void:
    zombies_changed.emit(get_zombies_remaining(), _round_total)


func _end_round() -> void:
    await get_tree().create_timer(time_between_rounds).timeout
    GameManager.start_next_round()
    _start_round()
