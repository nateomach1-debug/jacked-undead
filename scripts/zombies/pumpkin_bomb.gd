
extends Node3D

const GRAVITY_ARC_HEIGHT: float = 4.0
const EXPLOSION_VISUAL_SECONDS: float = 0.25

var start_position: Vector3 = Vector3.ZERO
var target_position: Vector3 = Vector3.ZERO
var damage: float = 25.0
var radius: float = 3.5
var flight_seconds: float = 1.3
var visual_only: bool = false

var _elapsed: float = 0.0
var _exploded: bool = false
var _material: StandardMaterial3D


func setup(
    start: Vector3,
    target: Vector3,
    hit_damage: float,
    blast_radius: float,
    flight_time: float,
    only_visual: bool
) -> void:
    start_position = start
    target_position = target
    damage = hit_damage
    radius = blast_radius
    flight_seconds = maxf(flight_time, 0.1)
    visual_only = only_visual


func _ready() -> void:
    var mesh_instance := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.22
    sphere.height = 0.44
    sphere.radial_segments = 8
    sphere.rings = 4
    mesh_instance.mesh = sphere

    _material = StandardMaterial3D.new()
    _material.albedo_color = Color(1.0, 0.28, 0.015)
    _material.roughness = 0.8
    mesh_instance.material_override = _material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh_instance)

    global_position = start_position


func _process(delta: float) -> void:
    if _exploded:
        return

    _elapsed += delta
    var t: float = clampf(_elapsed / flight_seconds, 0.0, 1.0)
    global_position = start_position.lerp(target_position, t)
    global_position.y += sin(t * PI) * GRAVITY_ARC_HEIGHT

    if t >= 1.0:
        _explode()


func _explode() -> void:
    if _exploded:
        return

    _exploded = true
    global_position = target_position

    if not visual_only and (not NetManager.is_online or NetManager.is_host):
        _damage_players()

    var blast := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 1.0
    sphere.height = 2.0
    sphere.radial_segments = 8
    sphere.rings = 4
    blast.mesh = sphere

    var blast_material := StandardMaterial3D.new()
    blast_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    blast_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    blast_material.albedo_color = Color(1.0, 0.3, 0.015, 0.7)
    blast.material_override = blast_material
    blast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    get_tree().current_scene.add_child(blast)
    blast.global_position = target_position
    blast.scale = Vector3.ONE * 0.15

    var tw := blast.create_tween()
    tw.set_parallel(true)
    tw.tween_property(blast, "scale", Vector3.ONE * radius, EXPLOSION_VISUAL_SECONDS)
    tw.tween_property(blast_material, "albedo_color:a", 0.0, EXPLOSION_VISUAL_SECONDS)
    tw.chain().tween_callback(blast.queue_free)

    queue_free()


func _damage_players() -> void:
    for group_name in ["player", "remote_players"]:
        for node in get_tree().get_nodes_in_group(group_name):
            if not is_instance_valid(node) or _player_is_out(node):
                continue
            if not node is Node3D:
                continue

            var player := node as Node3D
            var center: Vector3 = player.global_position + Vector3(0.0, 0.9, 0.0)
            if center.distance_to(target_position) > radius:
                continue

            if player.has_method("take_damage"):
                player.take_damage(damage, target_position)
            elif player.has_meta("peer_id"):
                NetManager.damage_peer(int(player.get_meta("peer_id")), damage)


func _player_is_out(player: Node) -> bool:
    return (
        bool(player.get("is_downed"))
        or bool(player.get("is_dead"))
        or bool(player.get_meta("downed", false))
        or bool(player.get_meta("dead", false))
    )
