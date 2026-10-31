extends Node
## Easter egg: PROTEIN RAIN. Standing still for 60 seconds makes protein
## shakes rain down on the player and pays out Juice (the permanent profile
## currency, NOT Gains) while it lasts.
## Once per game: this node stays in the scene after the rain ends, and the
## player also remembers it already triggered. Local only (no co-op sync).

const GROUP: String = "protein_rain_fx"
const PROFILE_PATH: String = "res://scripts/managers/profile.gd"
const RAIN_SECONDS: float = 10.0
const TICK_SECONDS: float = 1.0
const JUICE_PER_TICK: int = 5
const RAIN_HEIGHT: float = 7.0

var _player: Node3D = null
var _particles: CPUParticles3D = null
var _label: Label = null
var _time_left: float = 0.0
var _tick_left: float = 0.0
var _paid: int = 0


## Returns true if the rain started, false if it already ran this game.
static func start(tree: SceneTree, player: Node3D) -> bool:
    if tree == null or tree.current_scene == null or player == null:
        return false
    if tree.get_first_node_in_group(GROUP) != null:
        return false
    var cls = load("res://scripts/effects/protein_rain.gd")
    if cls == null:
        return false
    var fx: Node = cls.new()
    fx.name = "ProteinRainFx"
    fx._player = player
    tree.current_scene.add_child(fx)
    return true


func _ready() -> void:
    add_to_group(GROUP)
    _time_left = RAIN_SECONDS
    _tick_left = TICK_SECONDS
    _particles = _make_particles()
    add_child(_particles)
    _particles.emitting = true
    _make_label()
    _follow_player()


func _process(delta: float) -> void:
    if _player == null or not is_instance_valid(_player):
        _finish()
        return
    _follow_player()
    _time_left -= delta
    _tick_left -= delta
    if _tick_left <= 0.0:
        _tick_left += TICK_SECONDS
        _pay_juice()
    if _time_left <= 0.0:
        _finish()


## Loads a fresh Profile each time so we never overwrite other saves.
func _pay_juice() -> void:
    var cls = load(PROFILE_PATH)
    if cls == null:
        return
    var profile = cls.new()
    if profile == null or not profile.has_method("add_juice"):
        return
    profile.add_juice(JUICE_PER_TICK)
    _paid += JUICE_PER_TICK
    if _label != null:
        _label.text = "PROTEIN RAIN!  +%d JUICE" % _paid


func _follow_player() -> void:
    if _particles != null and _player != null and is_instance_valid(_player):
        _particles.global_position = _player.global_position + Vector3(0.0, RAIN_HEIGHT, 0.0)


func _finish() -> void:
    set_process(false)
    if _particles != null and is_instance_valid(_particles):
        _particles.emitting = false
        _particles.queue_free()
    _particles = null
    if _label != null and is_instance_valid(_label):
        var tw: Tween = create_tween()
        tw.tween_interval(1.5)
        tw.tween_property(_label, "modulate:a", 0.0, 0.8)
        tw.tween_callback(_label.queue_free)
    _label = null


func _make_label() -> void:
    var layer := CanvasLayer.new()
    layer.layer = 50
    add_child(layer)
    _label = Label.new()
    _label.text = "PROTEIN RAIN!  +0 JUICE"
    _label.add_theme_font_size_override("font_size", 32)
    _label.add_theme_color_override("font_color", Color(0.85, 0.5, 1.0))
    _label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
    _label.add_theme_constant_override("outline_size", 8)
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _label.offset_top = 120.0
    _label.offset_left = -300.0
    _label.offset_right = 300.0
    layer.add_child(_label)


func _make_particles() -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.amount = 120
    p.lifetime = 1.1
    p.one_shot = false
    p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    p.emission_box_extents = Vector3(3.0, 0.1, 3.0)
    p.direction = Vector3(0.0, -1.0, 0.0)
    p.spread = 3.0
    p.initial_velocity_min = 8.0
    p.initial_velocity_max = 10.0
    p.gravity = Vector3(0.0, -9.8, 0.0)
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.12, 0.22, 0.12)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.7, 0.3, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.7, 0.3, 1.0)
    mat.emission_energy_multiplier = 1.5
    mesh.material = mat
    p.mesh = mesh
    return p
