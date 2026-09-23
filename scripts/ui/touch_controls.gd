extends CanvasLayer

@onready var btn_up: Button = $DPad/Up
@onready var btn_down: Button = $DPad/Down
@onready var btn_left: Button = $DPad/Left
@onready var btn_right: Button = $DPad/Right
@onready var btn_jump: Button = $Actions/Jump
@onready var btn_sprint: Button = $Actions/Sprint
@onready var btn_shoot: Button = $Actions/Shoot
@onready var btn_reload: Button = $Actions/Reload
@onready var btn_interact: Button = $Interact


func _ready() -> void:
	_bind(btn_up, "move_forward")
	_bind(btn_down, "move_back")
	_bind(btn_left, "move_left")
	_bind(btn_right, "move_right")
	_bind(btn_jump, "jump")
	_bind(btn_sprint, "sprint")
	_bind(btn_shoot, "shoot")
	_bind(btn_reload, "reload")
	_bind(btn_interact, "interact")


func _bind(button: Button, action: String) -> void:
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))
