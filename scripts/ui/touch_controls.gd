extends CanvasLayer

@onready var joystick: Control = $Joystick
@onready var shoot_stick: Control = $ShootStick
@onready var btn_jump: Button = $Cluster/Jump
@onready var btn_sprint: Button = $Cluster/Sprint
@onready var btn_reload: Button = $Cluster/Reload
@onready var btn_use: Button = $Cluster/Use
@onready var btn_switch: Button = $Cluster/Switch

var _player: Node
var _sprint_on: bool = false


func _ready() -> void:
	_bind(btn_jump, "jump")
	_bind(btn_reload, "reload")
	_bind(btn_use, "interact")
	btn_sprint.pressed.connect(_on_sprint_pressed)
	btn_switch.pressed.connect(_on_switch_pressed)
	shoot_stick.fire_pressed.connect(_on_shoot_stick_pressed)
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


func _on_shoot_stick_pressed() -> void:
	if _player and _player.has_method("fire_once_if_ready"):
		_player.fire_once_if_ready()


func _process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return
	_player.touch_move_vector = joystick.value
	_player.stick_look_vector = shoot_stick.value


func _bind(button: Button, action: String) -> void:
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))
