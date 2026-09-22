extends CanvasLayer
## Simple HUD. Wire up the @onready paths to match hud.tscn's node names,
## and call `bind_player(player)` from main.gd once the player exists.

@onready var health_label: Label = $Margin/VBox/HealthLabel
@onready var ammo_label: Label = $Margin/VBox/AmmoLabel
@onready var gains_label: Label = $Margin/VBox/GainsLabel
@onready var round_label: Label = $Margin/VBox/RoundLabel
@onready var prompt_label: Label = $Margin/PromptLabel


func _ready() -> void:
	GameManager.gains_changed.connect(_on_gains_changed)
	GameManager.round_changed.connect(_on_round_changed)
	_on_gains_changed(GameManager.gains)
	_on_round_changed(GameManager.round_number)


func bind_player(player: Node) -> void:
	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.interact_prompt_changed.connect(_on_prompt_changed)


func _on_health_changed(current: float, max_hp: float) -> void:
	health_label.text = "HP: %d / %d" % [int(current), int(max_hp)]


func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	ammo_label.text = "Ammo: %d / %d" % [current_mag, reserve]


func _on_gains_changed(amount: int) -> void:
	gains_label.text = "Gains: %d" % amount


func _on_round_changed(round_number: int) -> void:
	round_label.text = "Round: %d" % round_number


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""
