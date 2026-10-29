extends Zombie
## Sprinter ("Cardio Bunny"): fast, lean, low health, weak hits.
## Same look builder as the normal zombie, recolored and slimmed down.
## Tune the numbers below.

const SPRINTER_HEALTH: float = 50.0
const SPRINTER_SPEED: float = 6.0
const SPRINTER_DAMAGE: float = 6.0
const SPRINTER_COOLDOWN: float = 0.8
const SPRINTER_GAINS: int = 100
const BODY_WIDTH: float = 0.8  # 1.0 = normal zombie width

const SKIN_COLOR: Color = Color(0.80, 0.76, 0.50)
const TANK_COLOR: Color = Color(0.95, 0.30, 0.60)
const SHORTS_COLOR: Color = Color(0.10, 0.10, 0.12)


func _ready() -> void:
    max_health = SPRINTER_HEALTH
    move_speed = SPRINTER_SPEED
    attack_damage = SPRINTER_DAMAGE
    attack_cooldown = SPRINTER_COOLDOWN
    gains_on_death = SPRINTER_GAINS
    super._ready()


func _build_visuals() -> void:
    var look: Script = _look()
    if look == null or not look.build(self):
        return  # the scene's old body stays visible
    for n in find_children("*", "MeshInstance3D", true, false):
        if _visual != null and _visual.is_ancestor_of(n):
            continue
        (n as MeshInstance3D).visible = false
    # The look builder makes skin, tank top, shorts in that order.
    if _flash_mats.size() >= 3:
        _flash_mats[0].albedo_color = SKIN_COLOR
        _flash_mats[1].albedo_color = TANK_COLOR
        _flash_mats[2].albedo_color = SHORTS_COLOR
    if _visual != null:
        var s: Vector3 = _visual.scale
        _visual.scale = Vector3(s.x * BODY_WIDTH, s.y, s.z * BODY_WIDTH)
