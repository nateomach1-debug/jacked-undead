extends Zombie
## "Roid Rager" - a special variant zombie. Tankier, faster, hits harder.
## Look: built in code like the normal zombie (see Zombie._build_visuals),
## but bigger, with huge arms/shoulders, purple-red veiny skin and red eyes.
## It reuses the base zombie's walk/arm animation, hit flash and death fall.

const RAGER_SKINS: Array = [
    Color(0.52, 0.13, 0.30),
    Color(0.46, 0.12, 0.36),
    Color(0.58, 0.15, 0.26),
]


func _ready() -> void:
    max_health = 300.0
    move_speed = 3.0
    attack_damage = 35.0
    gains_on_death = 100
    head_height_threshold = 0.9
    super._ready()


func _rager_leg(x: float, skin: Material, shorts: Material, vein: Material) -> Node3D:
    var pivot := Node3D.new()
    pivot.position = Vector3(x, 0.9, 0.0)
    _visual.add_child(pivot)
    _part(pivot, Vector3(0.26, 0.9, 0.28), Vector3(0.0, -0.45, 0.0), skin)
    _part(pivot, Vector3(0.30, 0.42, 0.32), Vector3(0.0, -0.16, 0.0), shorts)
    _part(pivot, Vector3(0.05, 0.36, 0.03), Vector3(0.06, -0.58, -0.145), vein)
    return pivot


func _rager_arm(x: float, skin: Material, vein: Material) -> Node3D:
    # Shoulder (delt) stays on the body; the arm pivot swings.
    _part(_upper, Vector3(0.34, 0.32, 0.34), Vector3(x, 0.64, 0.0), skin)
    var pivot := Node3D.new()
    pivot.position = Vector3(x, 0.62, 0.0)
    _upper.add_child(pivot)
    _part(pivot, Vector3(0.26, 0.38, 0.26), Vector3(0.0, -0.19, 0.0), skin)
    _part(pivot, Vector3(0.31, 0.36, 0.31), Vector3(0.0, -0.56, 0.0), skin)
    _part(pivot, Vector3(0.27, 0.22, 0.27), Vector3(0.0, -0.80, 0.0), skin)
    _part(pivot, Vector3(0.05, 0.34, 0.03), Vector3(0.0, -0.19, -0.145), vein)
    _part(pivot, Vector3(0.05, 0.32, 0.03), Vector3(0.07, -0.56, -0.17), vein)
    _part(pivot, Vector3(0.04, 0.28, 0.03), Vector3(-0.08, -0.54, -0.17), vein)
    return pivot


func _build_visuals() -> void:
    if HIDE_OLD_MESHES:
        for n in find_children("*", "MeshInstance3D", true, false):
            (n as MeshInstance3D).visible = false

    var h: float = MODEL_HEIGHT
    var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
    if shape_node and shape_node.shape is CapsuleShape3D:
        h = (shape_node.shape as CapsuleShape3D).height

    var skin_col: Color = RAGER_SKINS[randi() % RAGER_SKINS.size()]
    skin_col = skin_col.darkened(randf_range(0.0, 0.12))
    var skin := _make_mat(skin_col)
    var dark_skin := _make_mat(skin_col.darkened(0.35))
    var vein := _make_mat(Color(0.25, 0.03, 0.22), 0.5, false)
    var tank := _make_mat(Color(0.09, 0.09, 0.11))
    var shorts := _make_mat(Color(0.10, 0.04, 0.10))
    var mouth := _make_mat(Color(0.08, 0.01, 0.01), 0.9, false)
    var teeth := _make_mat(Color(0.9, 0.88, 0.8), 0.7, false)
    var blood := _make_mat(Color(0.35, 0.02, 0.02), 0.4, false)
    var eye_col := Color(1.0, 0.05, 0.05)
    var eye := StandardMaterial3D.new()
    eye.albedo_color = eye_col.darkened(0.4)
    eye.emission_enabled = true
    eye.emission = eye_col
    eye.emission_energy_multiplier = 4.0

    _idle_seed = randf() * TAU
    _visual = Node3D.new()
    _visual.name = "ZombieVisual"
    _visual_base_y = -h * 0.5
    _visual.position = Vector3(0.0, _visual_base_y, 0.0)
    _visual.scale = Vector3.ONE * ((h / MODEL_HEIGHT) * randf_range(0.97, 1.03))
    add_child(_visual)

    # Legs and hips (front is -Z).
    _leg_l = _rager_leg(-0.17, skin, shorts, vein)
    _leg_r = _rager_leg(0.17, skin, shorts, vein)
    _part(_visual, Vector3(0.7, 0.16, 0.34), Vector3(0.0, 0.92, 0.0), shorts)

    # Upper body: hunched, wide V-shaped chest.
    _upper = Node3D.new()
    _upper.position = Vector3(0.0, 0.9, 0.0)
    _upper.rotation.x = -0.3
    _visual.add_child(_upper)
    _part(_upper, Vector3(0.6, 0.3, 0.3), Vector3(0.0, 0.15, 0.0), skin)
    _part(_upper, Vector3(0.9, 0.46, 0.38), Vector3(0.0, 0.53, 0.0), skin)
    _part(_upper, Vector3(0.92, 0.28, 0.4), Vector3(0.0, 0.38, 0.0), tank)
    _part(_upper, Vector3(0.2, 0.12, 0.01), Vector3(0.12, 0.34, -0.205), blood)
    _part(_upper, Vector3(0.05, 0.28, 0.03), Vector3(0.1, 0.62, -0.2), vein)
    _part(_upper, Vector3(0.04, 0.24, 0.03), Vector3(-0.22, 0.58, -0.2), vein)
    _part(_upper, Vector3(0.04, 0.22, 0.03), Vector3(0.28, 0.6, -0.2), vein)

    # Traps (slope down toward the shoulders).
    var trap_l := _part(_upper, Vector3(0.34, 0.16, 0.3), Vector3(-0.2, 0.78, 0.0), skin)
    trap_l.rotation.z = 0.45
    var trap_r := _part(_upper, Vector3(0.34, 0.16, 0.3), Vector3(0.2, 0.78, 0.0), skin)
    trap_r.rotation.z = -0.45
    _part(_upper, Vector3(0.04, 0.2, 0.03), Vector3(-0.12, 0.8, -0.16), vein)
    _part(_upper, Vector3(0.04, 0.2, 0.03), Vector3(0.12, 0.8, -0.16), vein)

    # Small head sunk between the shoulders.
    _head = Node3D.new()
    _head.position = Vector3(0.0, 0.72, -0.1)
    _head.rotation.x = -0.25
    _upper.add_child(_head)
    _part(_head, Vector3(0.24, 0.24, 0.24), Vector3(0.0, 0.1, 0.0), skin)
    _part(_head, Vector3(0.26, 0.05, 0.06), Vector3(0.0, 0.15, -0.12), dark_skin)
    _part(_head, Vector3(0.06, 0.04, 0.02), Vector3(-0.06, 0.12, -0.125), eye)
    _part(_head, Vector3(0.06, 0.04, 0.02), Vector3(0.06, 0.12, -0.125), eye)
    _part(_head, Vector3(0.15, 0.07, 0.02), Vector3(0.0, 0.03, -0.125), mouth)
    _part(_head, Vector3(0.025, 0.035, 0.015), Vector3(-0.05, 0.045, -0.135), teeth)
    _part(_head, Vector3(0.025, 0.035, 0.015), Vector3(0.0, 0.045, -0.135), teeth)
    _part(_head, Vector3(0.025, 0.035, 0.015), Vector3(0.05, 0.045, -0.135), teeth)
    _part(_head, Vector3(0.03, 0.12, 0.02), Vector3(0.1, 0.12, -0.1), vein)

    # Huge arms reaching forward.
    _arm_l = _rager_arm(-0.52, skin, vein)
    _arm_r = _rager_arm(0.52, skin, vein)
    _arm_base_l = 1.15 + randf_range(-0.15, 0.15)
    _arm_base_r = 1.15 + randf_range(-0.15, 0.15)


func _process(delta: float) -> void:
    super._process(delta)
    if _visual == null or _is_dead or _upper == null:
        return
    # Heavier look on top of the base animation: deeper hunch, arms held wide,
    # a stomp bob while walking and a slow chest heave.
    var amp: float = clampf(_anim_speed / 2.5, 0.0, 1.0)
    _upper.rotation.x -= 0.08
    _arm_l.rotation.z = -0.22
    _arm_r.rotation.z = 0.22
    _visual.position.y += absf(sin(_anim_phase)) * 0.03 * amp
    var heave: float = sin(_anim_time * 2.4 + _idle_seed)
    _upper.scale = Vector3(1.0 + heave * 0.012, 1.0 + heave * 0.02, 1.0)
