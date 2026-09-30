extends Node
## Round-based spawner. Place spawn points as Marker3D nodes in the
## "spawn_points" group, and set zombie_scene / roid_rager_scene.
## Tag a spawn point with metadata "zone" (metadata/zone = "hall") and it only
## spawns zombies once that zone is unlocked. Untagged points are always on.
## Drop this node into the main level scene.

signal zombies_changed(remaining: int, total: int)

@export var zombie_scene: PackedScene
@export var roid_rager_scene: PackedScene
@export var base_zombies_per_round: int = 6
@export var zombies_per_round_growth: int = 3
@export var time_between_spawns: float = 1.2
@export var time_between_rounds: float = 8.0
@export var roid_rager_every_n_rounds: int = 3
@export var min_spawn_distance: float = 8.0  # don't spawn right on top of the player
@export var nearest_spawn_pool: int = 3      # pick randomly among this many closest points

var _spawn_points: Array = []
var _round_active: bool = false
var _round_total: int = 0
var _round_killed: int = 0


func _ready() -> void:
	_spawn_points = get_tree().get_nodes_in_group("spawn_points")
	if _spawn_points.is_empty():
		push_warning("RoundManager: no nodes in group 'spawn_points' found.")
	# Deferred so main.gd has reset the run and hooked up the HUD first.
	_start_round.call_deferred()


func get_zombies_total() -> int:
	return _round_total


func get_zombies_remaining() -> int:
	return maxi(_round_total - _round_killed, 0)


func _start_round() -> void:
	_round_active = true
	_round_killed = 0
	_round_total = base_zombies_per_round + (GameManager.round_number - 1) * zombies_per_round_growth
	_emit_counts()
	_spawn_wave(_round_total)


func _spawn_wave(count: int) -> void:
	if _spawn_points.is_empty() or not zombie_scene:
		push_warning("RoundManager: no spawn points or zombie_scene, nothing to spawn.")
		return
	for i in range(count):
		await get_tree().create_timer(time_between_spawns).timeout
		_spawn_one_zombie()


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


func _on_zombie_died(_zombie: Zombie) -> void:
	_round_killed += 1
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
