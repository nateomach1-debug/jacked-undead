extends Zombie
## Spitter ("Protein Shaker"): stops about 12 m from you (when it can see you)
## and lobs slow goo balls. It works by giving the base zombie a long
## attack_range, so the base AI stands still and calls _try_attack(), which
## spits here instead of hitting. Walks up to you again if a wall blocks sight.

const BALL_PATH: String = "res://scripts/zombies/goo_ball.gd"
const SPITTER_HEALTH: float = 60.0
const SPITTER_SPEED: float = 2.8
const SPITTER_DAMAGE: float = 9.0     # damage of one goo ball
const SPITTER_RANGE: float = 12.0     # distance it stops at and spits from
const SPITTER_COOLDOWN: float = 2.4   # seconds between spits
const SPITTER_GAINS: int = 120
const BALL_SPEED: float = 10.0        # lower = slower, easier to dodge
const BALL_GRAVITY: float = 6.0

const SKIN_COLOR: Color = Color(0.45, 0.70, 0.35)
const TANK_COLOR: Color = Color(0.30, 0.55, 0.15)
const SHORTS_COLOR: Color = Color(0.10, 0.12, 0.10)


func _ready() -> void:
    max_health = SPITTER_HEALTH
    move_speed = SPITTER_SPEED
    attack_damage = SPITTER_DAMAGE
    attack_range = SPITTER_RANGE
    attack_cooldown = SPITTER_COOLDOWN
    gains_on_death = SPITTER_GAINS
    add_to_group("spitters")
    super._ready()


func _build_visuals() -> void:
    var look: Script = _look()
    if look == null or not look.build(self):
        return  # the scene's old body stays visible
    for n in find_children("*", "MeshInstance3D", true, false):
        if _visual != null and _visual.is_ancestor_of(n):
            continue
        (n as MeshInstance3D).visible = false
    if _flash_mats.size() >= 3:
        _flash_mats[0].albedo_color = SKIN_COLOR
        _flash_mats[1].albedo_color = TANK_COLOR
        _flash_mats[2].albedo_color = SHORTS_COLOR
    # Glowing goo sac on the chest.
    if _upper != null:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.45, 0.85, 0.15)
        mat.emission_enabled = true
        mat.emission = Color(0.35, 0.9, 0.1)
        mat.emission_energy_multiplier = 2.0
        var sm := SphereMesh.new()
        sm.radius = 0.5
        sm.height = 1.0
        sm.radial_segments = 10
        sm.rings = 5
        var sac := MeshInstance3D.new()
        sac.mesh = sm
        sac.material_override = mat
        sac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        sac.scale = Vector3(0.26, 0.24, 0.16)
        sac.position = Vector3(0.0, 0.3, -0.17)
        _upper.add_child(sac)


## The base AI calls this when we are in range with a clear view: spit.
func _try_attack() -> void:
    if _attack_timer > 0.0 or _target == null or not is_instance_valid(_target):
        return
    _spit()
    _attack_timer = attack_cooldown


func _spit() -> void:
    var ball_script: Script = load(BALL_PATH) as Script
    if ball_script == null:
        push_warning("spitter.gd: goo_ball.gd is missing, so the Spitter can't shoot.")
        return
    var scene: Node = get_tree().current_scene
    if scene == null:
        return
    var ball: Node3D = ball_script.new()
    scene.add_child(ball)
    var start: Vector3 = global_position + Vector3(0.0, 0.55, 0.0) + (-global_transform.basis.z) * 0.5
    ball.global_position = start
    var to_aim: Vector3 = _target.global_position - start
    var t: float = clampf(to_aim.length() / BALL_SPEED, 0.35, 2.0)
    var vel: Vector3 = to_aim / t + Vector3(0.0, 0.5 * BALL_GRAVITY * t, 0.0)
    ball.launch(vel, attack_damage, BALL_GRAVITY)
