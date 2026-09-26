extends CharacterBody3D
class_name Zombie
## Base "Gym Rat" zombie. Chases the player in a straight line and
## attacks on contact. Subclass (e.g. RoidRager) can override stats
## in _ready() or via exported values on a variant scene.
##
## NOTE: this is a simple direct-chase prototype (no navmesh required),
## fine for an open gray-box arena. Swap in a NavigationAgent3D + baked
## NavigationRegion3D later for obstacle avoidance on real levels.

signal died(zombie: Zombie)

const GRAVITY: float = 9.8

@export var max_health: float = 100.0
@export var move_speed: float = 3.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0
@export var gains_on_death: int = 100

var current_health: float
var _target: Node3D
var _attack_timer: float = 0.0


func _ready() -> void:
	current_health = max_health
	add_to_group("zombies")
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
		to_target.y = 0.0
		var distance := to_target.length()

		if distance > attack_range:
			var direction := to_target.normalized()
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
			look_at(Vector3(_target.global_position.x, global_position.y, _target.global_position.z), Vector3.UP)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			_try_attack()
	else:
		_find_target()
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()


func _try_attack() -> void:
	if _attack_timer <= 0.0 and _target and _target.has_method("take_damage"):
		_target.take_damage(attack_damage)
		_attack_timer = attack_cooldown


func take_damage(amount: float, _source: Node = null) -> void:
	current_health -= amount
	if current_health <= 0.0:
		_die()


func _die() -> void:
	GameManager.add_gains(gains_on_death)
	GameManager.add_kill()
	died.emit(self)
	queue_free()
