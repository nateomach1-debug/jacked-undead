extends Node3D
## One Locker Launcher shot: a random Loot Locker gun flies out of the barrel,
## tumbling. It hits the first zombie or wall in its path for damage, plus a
## small splash on nearby zombies. Created by player_controller._launch_locker_shot().

const SPEED: float = 30.0
const GRAVITY: float = 6.0
const LIFETIME: float = 4.0
const HIT_MASK: int = 1 | 4            # world + zombies, same as the player's shots
const GUN_SCALE: float = 0.8           # size of the flying gun
const SPLASH_FACTOR: float = 0.6       # splash damage as a share of the direct hit
const HEADSHOT_MULTIPLIER: float = 2.0
const POOL_PATH: String = "res://scripts/weapons/locker_weapons.gd"

static var _pool: Array = []

var _player: Node = null
var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 0.0
var _gains: int = 0
var _splash: float = 0.0
var _life: float = LIFETIME
var _model: Node3D = null
var _done: bool = false


func launch(player: Node, direction: Vector3, damage: float, gains: int, splash: float) -> void:
    _player = player
    _velocity = direction.normalized() * SPEED
    _damage = damage
    _gains = gains
    _splash = splash
    _build_model()
    if absf(direction.normalized().dot(Vector3.UP)) < 0.99:
        look_at(global_position + direction, Vector3.UP)


func _build_model() -> void:
    if _pool.is_empty():
        var script = load(POOL_PATH)
        if script != null:
            for entry in script.build_pool():
                _pool.append(entry["weapon"])
    var model: Node3D = null
    if not _pool.is_empty():
        var w: WeaponData = _pool[randi() % _pool.size()]
        model = w.create_model()
    if model == null:
        var mi := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(0.1, 0.12, 0.5)
        mi.mesh = box
        model = mi
    model.scale = Vector3.ONE * GUN_SCALE
    add_child(model)
    _model = model


func _physics_process(delta: float) -> void:
    if _done:
        return
    _life -= delta
    if _life <= 0.0:
        queue_free()
        return
    _velocity.y -= GRAVITY * delta
    var from: Vector3 = global_position
    var to: Vector3 = from + _velocity * delta
    var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
    if _player != null and is_instance_valid(_player):
        query.exclude = [_player.get_rid()]
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        global_position = hit["position"]
        _impact(hit["collider"], hit["position"])
        return
    global_position = to
    if _model != null:
        _model.rotate_z(delta * 14.0)


func _impact(collider: Object, point: Vector3) -> void:
    _done = true
    var attacker = _player if (_player != null and is_instance_valid(_player)) else null

    # Direct hit
    if collider != null and collider is Node and (collider as Node).is_in_group("zombies") and collider.has_method("take_damage"):
        var head: bool = collider.has_method("is_headshot") and collider.is_headshot(point)
        var dmg: float = _damage * (HEADSHOT_MULTIPLIER if head else 1.0)
        collider.take_damage(dmg, attacker, head)
        GameManager.add_gains(_gains)

    # Splash on every other living zombie near the impact
    if _splash > 0.0:
        for z in get_tree().get_nodes_in_group("zombies"):
            if z == collider or not is_instance_valid(z) or not (z is Node3D):
                continue
            if bool(z.get("_is_dead")):
                continue
            if (z as Node3D).global_position.distance_to(point) > _splash:
                continue
            if z.has_method("take_damage"):
                z.take_damage(_damage * SPLASH_FACTOR, attacker, false)
                GameManager.add_gains(_gains)

    _spawn_flash(point)
    queue_free()


## Quick orange burst where the gun lands.
func _spawn_flash(point: Vector3) -> void:
    var scene: Node = get_tree().current_scene
    if scene == null:
        return
    var mi := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.3
    sphere.height = 0.6
    mi.mesh = sphere
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(1.0, 0.6, 0.15, 0.8)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.emission_enabled = true
    mat.emission = Color(1.0, 0.5, 0.1)
    mat.emission_energy_multiplier = 2.0
    mi.material_override = mat
    scene.add_child(mi)
    mi.global_position = point
    var grow: float = maxf(_splash, 1.0) * 2.0
    var tween := mi.create_tween()
    tween.set_parallel(true)
    tween.tween_property(mi, "scale", Vector3.ONE * grow, 0.25)
    tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
    tween.chain().tween_callback(mi.queue_free)
