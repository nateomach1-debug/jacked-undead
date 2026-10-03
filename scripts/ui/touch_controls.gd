extends CanvasLayer

@onready var joystick: Control = $Joystick
@onready var btn_jump: Button = $Cluster/Jump
@onready var btn_sprint: Button = $Cluster/Sprint
@onready var btn_reload: Button = $Cluster/Reload
@onready var btn_use: Button = $Cluster/Use
@onready var btn_switch: Button = $Cluster/Switch

var _player: Node
var _sprint_on: bool = false


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


func _on_sprint_pressed() -> void:
	_sprint_on = not _sprint_on
	if _sprint_on:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _on_switch_pressed() -> void:
	if _player and _player.has_method("switch_weapon"):
		_player.switch_weapon(1)


func _process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return
	_player.touch_move_vector = joystick.value


func _bind(button: Button, action: String) -> void:
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))


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
	_bind(aim, "aim")
	btn_use.get_parent().add_child(aim)


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
