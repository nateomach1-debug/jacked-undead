extends CanvasLayer

const LAYOUT_PATH: String = "res://scripts/managers/hud_layout.gd"
const AIM_ON_COLOR: Color = Color(1.0, 0.85, 0.3, 1.0)

@onready var joystick: Control = $Joystick
@onready var btn_jump: Button = $Cluster/Jump
@onready var btn_sprint: Button = $Cluster/Sprint
@onready var btn_reload: Button = $Cluster/Reload
@onready var btn_use: Button = $Cluster/Use
@onready var btn_switch: Button = $Cluster/Switch

var _player: Node
var _sprint_on: bool = false
var _aim_on: bool = false
var _aim_btn: Button = null
var _layout = null


func _ready() -> void:
    add_to_group("touch_ui")
    call_deferred("_maybe_show_tutorial")
    _bind(btn_jump, "jump")
    _bind(btn_reload, "reload")
    _bind(btn_use, "interact")
    _setup_sprint_button()
    btn_switch.pressed.connect(_on_switch_pressed)
    _add_aim_button()
    _player = get_tree().get_first_node_in_group("player")
    call_deferred("_apply_layout")
    get_viewport().size_changed.connect(_on_viewport_resized)


func _exit_tree() -> void:
    # Never leave aim stuck on after leaving a match.
    if _aim_on:
        Input.action_release("aim")


func _on_viewport_resized() -> void:
    call_deferred("_apply_layout")


func _on_sprint_pressed() -> void:
    _sprint_on = not _sprint_on
    if _sprint_on:
        Input.action_press("sprint")
    else:
        Input.action_release("sprint")


func _on_switch_pressed() -> void:
    _set_aim(false)
    if _player and _player.has_method("switch_weapon"):
        _player.switch_weapon(1)


func _process(_delta: float) -> void:
    # Aim turns off by itself when you sprint or reload.
    if _aim_on and (Input.is_action_pressed("sprint") or Input.is_action_just_pressed("reload")):
        _set_aim(false)

    if not _player:
        _player = get_tree().get_first_node_in_group("player")
        return
    _player.touch_move_vector = joystick.value


func _bind(button: Button, action: String) -> void:
    button.button_down.connect(func(): Input.action_press(action))
    button.button_up.connect(func(): Input.action_release(action))


## Aim button: tap to aim down sights, tap again to stop (CoD Zombies style).
func _add_aim_button() -> void:
    if not InputMap.has_action("aim"):
        InputMap.add_action("aim", 0.5)
    var aim := Button.new()
    aim.text = "AIM"
    aim.focus_mode = Control.FOCUS_NONE
    aim.add_theme_font_size_override("font_size", 28)
    aim.anchor_left = 1.0
    aim.anchor_top = 1.0
    aim.anchor_right = 1.0
    aim.anchor_bottom = 1.0
    aim.offset_left = -170.0
    aim.offset_top = -500.0
    aim.offset_right = -20.0
    aim.offset_bottom = -350.0
    aim.pressed.connect(_on_aim_pressed)
    btn_use.get_parent().add_child(aim)
    _aim_btn = aim


func _on_aim_pressed() -> void:
    _set_aim(not _aim_on)


func _set_aim(on: bool) -> void:
    if on == _aim_on:
        return
    _aim_on = on
    if on:
        Input.action_press("aim")
    else:
        Input.action_release("aim")
    if _aim_btn != null:
        _aim_btn.self_modulate = AIM_ON_COLOR if on else Color(1.0, 1.0, 1.0, 1.0)


## Applies the saved HUD layout (Settings > HUD LAYOUT). With nothing saved
## the scene is left exactly as it is.
func _apply_layout() -> void:
    var script = load(LAYOUT_PATH)
    if script == null:
        return
    _layout = script.new()
    if not _layout.has_group("touch"):
        return
    var vp: Vector2 = get_viewport().get_visible_rect().size
    var cluster = btn_use.get_parent()
    if cluster is Control:
        cluster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _place(joystick, "joystick", vp)
    _place(btn_use, "use", vp)
    _place(btn_reload, "reload", vp)
    _place(btn_jump, "jump", vp)
    _place(btn_sprint, "sprint", vp)
    _place(btn_switch, "switch", vp)
    if _aim_btn != null:
        _place(_aim_btn, "aim", vp)


func _place(node: Control, id: String, vp: Vector2) -> void:
    var info: Dictionary = _layout.info(id)
    if info.is_empty():
        return
    var sz := Vector2(float(info["w"]), float(info["h"]))
    var c: Vector2 = _layout.center(id, vp)
    node.set_anchors_preset(Control.PRESET_TOP_LEFT)
    node.offset_left = c.x - sz.x / 2.0
    node.offset_top = c.y - sz.y / 2.0
    node.offset_right = node.offset_left + sz.x
    node.offset_bottom = node.offset_top + sz.y
    node.pivot_offset = sz / 2.0
    node.scale = Vector2.ONE * _layout.scale_of(id)
    node.modulate.a = _layout.alpha_of(id)


## Sprint button: toggle (tap on/off) or hold, per the Settings screen.
func _setup_sprint_button() -> void:
    var hold: bool = false
    var script = load("res://scripts/managers/game_settings.gd")
    if script != null:
        var s = script.new()
        hold = s.get_value("sprint_hold") > 0.5
    if hold:
        _bind(btn_sprint, "sprint")
    else:
        btn_sprint.pressed.connect(_on_sprint_pressed)


## First time only: shows the tutorial overlay (skipped if its script is missing).
func _maybe_show_tutorial() -> void:
    var settings_script = load("res://scripts/managers/game_settings.gd")
    if settings_script == null:
        return
    var s = settings_script.new()
    if s.get_value("tutorial_seen") > 0.5:
        return
    var tutorial_script = load("res://scripts/ui/tutorial_overlay.gd")
    var scene: Node = get_tree().current_scene
    if tutorial_script == null or scene == null:
        return
    var overlay := CanvasLayer.new()
    overlay.set_script(tutorial_script)
    scene.add_child(overlay)

# END OF FILE
