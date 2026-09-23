extends CanvasLayer

@onready var joystick: Control = $Joystick
@onready var btn_jump: Button = $Actions/Jump
@onready var btn_sprint: Button = $Actions/Sprint
@onready var btn_shoot: Button = $Shoot
@onready var btn_reload: Button = $Actions/Reload
@onready var btn_interact: Button = $Interact

var _player: Node


func _ready() -> void:
	_bind(btn_jump, "jump")
	_bind(btn_sprint, "sprint")
	_bind(btn_shoot, "shoot")
	_bind(btn_reload, "reload")
	_bind(btn_interact, "interact")
	_player = get_tree().get_first_node_in_group("player")


func _process(_delta: float) -> void:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
		return
	_player.touch_move_vector = joystick.value


func _bind(button: Button, action: String) -> void:
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))
