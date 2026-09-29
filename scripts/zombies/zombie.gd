extends CharacterBody3D
class_name Zombie
## Base "Gym Rat" zombie. Chases the player, follows the navigation mesh
## around walls when the map has one, climbs stairs, slides off corners when
## stuck, and attacks on contact. Subclass (e.g. RoidRager) can override stats
## in _ready() or via exported values on a variant scene.
##
## Pathfinding: maps with a NavigationRegion3D (the Building map, via
## nav_baker.gd) give zombies a route around obstacles. On maps without one
## (the Gym Arena) they fall back to walking straight at the player.

signal died(zombie: Zombie)

const GRAVITY: float = 9.8
const HEADSHOT_KILL_GAINS: int = 175  # awarded instead of gains_on_death when the killing shot was a headshot
const MAX_ATTACK_HEIGHT_GAP: float = 2.2  # can't hit you through a floor or ceiling
const STUCK_CHECK_INTERVAL: float = 0.5   # how often to check whether we're making progress
const STUCK_MOVE_THRESHOLD: float = 0.25  # moved less than this (meters) in that time = stuck
const DETOUR_DURATION: float = 0.9        # seconds spent sliding sideways off a corner

@export var max_health: float = 100.0
@export var move_speed: float = 3.0
@export var attack_damage: float = 1.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0
@export var gains_on_death: int = 100
@export var head_height_threshold: float = 0.5  # local Y above which a hit counts as a headshot
@export var step_height: float = 0.55           # tallest stair step a zombie can walk straight up
@export var repath_interval: float = 0.5        # seconds between path refreshes
@export var waypoint_reach_distance: float = 0.4

var current_health: float
var _target: Node3D
var _attack_timer: float = 0.0
var _is_dead: bool = false
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _repath_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_check_position: Vector3 = Vector3.ZERO
var _detour_time: float = 0.0
var _detour_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	current_health = max_health
	add_to_group("zombies")
	_repath_timer = randf() * repath_interval  # stagger so zombies don't all repath on the same frame
	_find_target()


func _find_target() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0]


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	if _attack_timer > 0.0:
		_attack_timer -= delta

	if _target and is_instance_valid(_target):
		var to_target := _target.global_position - global_position
		var vertical_gap: float = absf(to_target.y)
		to_target.y = 0.0
		var distance := to_target.length()

		if distance > attack_range or vertical_gap > MAX_ATTACK_HEIGHT_GAP:
			var direction := _get_move_direction(to_target, delta)
			direction = _apply_unstuck(direction, delta)
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			if direction.length() > 0.01:
				look_at(global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_stuck_timer = 0.0
			_detour_time = 0.0
			if distance > 0.01:
				look_at(Vector3(_target.global_position.x, global_position.y, _target.global_position.z), Vector3.UP)
			_try_attack()
	else:
		_find_target()
		velocity.x = 0.0
		velocity.z = 0.0

	_step_up_if_blocked(delta)
	move_and_slide()


## Which way to walk this frame: along the navigation path if there is one,
## otherwise straight at the player.
func _get_move_direction(to_target: Vector3, delta: float) -> Vector3:
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer = repath_interval
		_refresh_path()

	while _path_index < _path.size():
		var point := _path[_path_index]
		var flat := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
		if flat.length() < waypoint_reach_distance:
			_path_index += 1
		else:
			return flat.normalized()

	return to_target.normalized()


func _refresh_path() -> void:
	_path = PackedVector3Array()
	_path_index = 0
	if _target == null or not is_instance_valid(_target):
		return
	var nav_map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_regions(nav_map).is_empty():
		return  # this map has no navigation mesh: walk straight at the player
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return  # navigation mesh not ready yet
	_path = NavigationServer3D.map_get_path(nav_map, global_position, _target.global_position, true)


## If we've barely moved for half a second while trying to chase, get a fresh
## route and slide sideways along the wall for a moment to clear the corner.
func _apply_unstuck(direction: Vector3, delta: float) -> Vector3:
	_stuck_timer += delta
	if _stuck_timer >= STUCK_CHECK_INTERVAL:
		_stuck_timer = 0.0
		var moved: float = global_position.distance_to(_last_check_position)
		_last_check_position = global_position
		if moved < STUCK_MOVE_THRESHOLD and _detour_time <= 0.0:
			_refresh_path()
			_start_detour(direction)

	if _detour_time > 0.0:
		_detour_time -= delta
		return _detour_direction
	return direction


func _start_detour(direction: Vector3) -> void:
	var tangent: Vector3 = Vector3.ZERO
	var away: Vector3 = Vector3.ZERO
	if is_on_wall():
		var normal: Vector3 = get_wall_normal()
		normal.y = 0.0
		if normal.length() > 0.01:
			normal = normal.normalized()
			tangent = normal.cross(Vector3.UP).normalized()
			var side: float = tangent.dot(direction)
			if absf(side) < 0.1:
				if randf() < 0.5:
					tangent = -tangent
			elif side < 0.0:
				tangent = -tangent
			away = normal * 0.3  # a little push off the wall so we clear the corner
	if tangent.length() < 0.01:
		tangent = Vector3(-direction.z, 0.0, direction.x)
		if randf() < 0.5:
			tangent = -tangent
	_detour_direction = (tangent + away).normalized()
	_detour_time = DETOUR_DURATION


## Same trick as the player: CharacterBody3D can't climb steps on its own, so
## if walking forward would hit something but stepping up clears it, nudge up.
func _step_up_if_blocked(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.001:
		return
	if not test_move(global_transform, motion):
		return
	var raised := global_transform
	raised.origin += Vector3(0.0, step_height, 0.0)
	if test_move(raised, motion):
		return  # still blocked even raised: a real wall, not a step
	global_position.y += step_height


func _try_attack() -> void:
	if _attack_timer <= 0.0 and _target and _target.has_method("take_damage"):
		_target.take_damage(attack_damage)
		_attack_timer = attack_cooldown


func is_headshot(world_hit_position: Vector3) -> bool:
	return (world_hit_position.y - global_position.y) >= head_height_threshold


func take_damage(amount: float, _source: Node = null, was_headshot: bool = false) -> void:
	if _is_dead:
		return
	current_health -= amount
	if current_health <= 0.0:
		_die(was_headshot)


func _die(was_headshot: bool = false) -> void:
	_is_dead = true
	GameManager.add_gains(HEADSHOT_KILL_GAINS if was_headshot else gains_on_death)
	GameManager.add_kill()
	died.emit(self)
	queue_free()
