extends CanvasLayer

@onready var health_label: Label = $Margin/VBox/HealthLabel
@onready var ammo_label: Label = $Margin/VBox/AmmoLabel
@onready var weapon_label: Label = $Margin/VBox/WeaponLabel
@onready var gains_label: Label = $Margin/VBox/GainsLabel
@onready var round_label: Label = $Margin/VBox/RoundLabel
@onready var prompt_label: Label = $Margin/PromptLabel

@onready var perk_trt: TextureRect = $PerkBar/TRT
@onready var perk_creatine: TextureRect = $PerkBar/Creatine
@onready var perk_whey: TextureRect = $PerkBar/Whey
@onready var perk_pre_workout: TextureRect = $PerkBar/PreWorkout
@onready var perk_fish_oil: TextureRect = $PerkBar/FishOil
@onready var perk_bcaas: TextureRect = $PerkBar/BCAAs

var _player: Node
var _perk_icons: Dictionary = {}


func _ready() -> void:
	GameManager.gains_changed.connect(_on_gains_changed)
	GameManager.round_changed.connect(_on_round_changed)
	_on_gains_changed(GameManager.gains)
	_on_round_changed(GameManager.round_number)

	_perk_icons = {
		"trt": perk_trt,
		"creatine": perk_creatine,
		"whey": perk_whey,
		"pre_workout": perk_pre_workout,
		"fish_oil": perk_fish_oil,
		"bcaas": perk_bcaas,
	}


func bind_player(player: Node) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.interact_prompt_changed.connect(_on_prompt_changed)
	player.perks_changed.connect(_on_perks_changed)
	_on_perks_changed(player.owned_perks)


func _on_health_changed(current: float, max_hp: float) -> void:
	health_label.text = "HP: %d / %d" % [int(current), int(max_hp)]


func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	ammo_label.text = "Ammo: %d / %d" % [current_mag, reserve]
	if _player and _player.current_weapon:
		weapon_label.text = _player.current_weapon.weapon_name


func _on_gains_changed(amount: int) -> void:
	gains_label.text = "Gains: %d" % amount


func _on_round_changed(round_number: int) -> void:
	round_label.text = "Round: %d" % round_number


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


func _on_perks_changed(owned: Array) -> void:
	for id in _perk_icons.keys():
		var icon: TextureRect = _perk_icons[id]
		icon.modulate.a = 1.0 if id in owned else 0.25
