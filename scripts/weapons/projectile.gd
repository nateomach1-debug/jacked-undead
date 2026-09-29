extends Node3D
## Grenade / rocket projectile. Built entirely in code (no scene needed).
## The player spawns one, calls launch(), and it flies until it hits the
## world or a zombie, then explodes for splash damage.

const HIT_MASK: int = 1 | 4  # world + zombies
const MAX_LIFETIME: float = 6.0

var _velocity: Vector3 = Vector3.ZERO
var _gravity: float = 0.0
var _damage: float = 0.0
var _radius: float = 4.0
var _self_damage_multiplier: float = 0.0
var _gains_per_hit: int = 10
var _shooter: Node = null
var _age: float = 0.0
var _exploded: bool = false


func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh_instance.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.0)
	mesh_instance.material_override = mat
	add_child(mesh_instance)


func launch(shooter: Node, velocity: Vector3, gravity: float, damage: float, radius: float, self_damage_multiplier: float, gains_per_hit: int) -> void:
	_shooter = shooter
	_velocity = velocity
	_gravity = gravity
	_damage = damage
	_radius = radius
	_self_damage_multiplier = self_damage_multiplier
	_gains_per_hit = gains_per_hit


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	if _age > MAX_LIFETIME:
		_explode(global_position)
		return

	var from: Vector3 = global_position
	_velocity.y -= _gravity * delta
	var to: Vector3 = from + _velocity * delta

	# Ray from last position to next position so fast rockets can't tunnel through walls.
	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	if _shooter is CollisionObject3D:
		query.exclude = [(_shooter as CollisionObject3D).get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_explode(hit["position"])
		return
	global_position = to


func _explode(at: Vector3) -> void:
	_exploded = true
	global_position = at
	_spawn_explosion_visual(at)

	# Zombies: full damage at the center, fading to 25% at the edge.
	for node in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(node):
			continue
		var zombie := node as Node3D
		if zombie == null or not zombie.has_method("take_damage"):
			continue
		var center: Vector3 = zombie.global_position + Vector3(0, 1.0, 0)
		var dist: float = center.distance_to(at)
		if dist > _radius:
			continue
		var factor: float = clampf(1.0 - dist / _radius, 0.25, 1.0)
		zombie.take_damage(_damage * factor, _shooter, false)
		GameManager.add_gains(_gains_per_hit)

	# The shooter can hurt themselves if they stand too close.
	if _self_damage_multiplier > 0.0 and is_instance_valid(_shooter) and _shooter is Node3D:
		var shooter_center: Vector3 = (_shooter as Node3D).global_position + Vector3(0, 1.0, 0)
		var shooter_dist: float = shooter_center.distance_to(at)
		if shooter_dist <= _radius and _shooter.has_method("take_damage"):
			var self_factor: float = clampf(1.0 - shooter_dist / _radius, 0.0, 1.0)
			_shooter.take_damage(_damage * self_factor * _self_damage_multiplier)

	queue_free()


func _spawn_explosion_visual(at: Vector3) -> void:
	var fx := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	fx.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.55, 0.1, 0.6)
	fx.material_override = mat
	get_tree().current_scene.add_child(fx)
	fx.global_position = at
	fx.scale = Vector3.ONE * 0.3
	var tween := fx.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fx, "scale", Vector3.ONE * _radius, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callba
  ck(fx.queue_free)
