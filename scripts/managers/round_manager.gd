extends Node
## Round-based spawner. Place spawn points as Marker3D nodes in the
## "spawn_points" group, and set zombie_scene / roid_rager_scene.
## Drop this node into the main level scene.

@export var zombie_scene: PackedScene
@export var roid_rager_scene: PackedScene
@export var base_zombies_per_round: int = 6
@export var zombies_per_round_growth: int = 3
@export var time_between_spawns: float = 1.2
@export var time_between_rounds: float = 8.0
@export var roid_rager_every_n_rounds: int = 3

var _alive_zombies: int = 0
var _spawn_points: Array = []
var _round_active: bool = false


func _ready() -> void:
	_spawn_points = get_tree().get_nodes_in_group("spawn_points")
	if _spawn_points.is_empty():
		push_warning("RoundManager: no nodes in group 'spawn_points' found.")
	_start_round()


func _start_round() -> void:
	_round_active = true
	var count := base_zombies_per_round + (GameManager.round_number - 1) * zombies_per_round_growth
	_spawn_wave(count)


func _spawn_wave(count: int) -> void:
	for i in range(count):
		await get_tree().create_timer(time_between_spawns).timeout
		_spawn_one_zombie()


func _spawn_one_zombie() -> void:
	if _spawn_points.is_empty() or not zombie_scene:
		return

	var scene_to_use: PackedScene = zombie_scene
	var is_special_round := GameManager.round_number % roid_rager_every_n_rounds == 0
	if is_special_round and roid_rager_scene and randf() < 0.25:
		scene_to_use = roid_rager_scene

	var point: Marker3D = _spawn_points[randi() % _spawn_points.size()]
	var zombie: Zombie = scene_to_use.instantiate()
	get_tree().current_scene.add_child(zombie)
	zombie.global_position = point.global_position
	zombie.died.connect(_on_zombie_died)
	_alive_zombies += 1


func _on_zombie_died(_zombie: Zombie) -> void:
	_alive_zombies -= 1
	if _alive_zombies <= 0 and _round_active:
		_round_active = false
		_end_round()


func _end_round() -> void:
	await get_tree().create_timer(time_between_rounds).timeout
	GameManager.start_next_round()
	_start_round()
