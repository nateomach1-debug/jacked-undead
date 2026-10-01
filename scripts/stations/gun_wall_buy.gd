extends Area3D

@export var weapon: WeaponData
@export var display_model: PackedScene
@export var display_name: String = "Weapon"
@export var buy_cost: int = 3000
@export var ammo_cost: int = 500
@export var refill_amount: int = 60

@onready var mount: Node3D = $Mount
@onready var name_label: Label3D = $Label3D

var _player: Node


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	name_label.text = display_name
	if display_model:
		var model: Node3D = display_model.instantiate()
		mount.add_child(model)


func interact(player: Node) -> void:
	if not player.has_method("has_weapon"):
		return
	if not player.has_weapon(weapon):
		if GameManager.try_spend_gains(GameManager.wall_cost(buy_cost)):
			player.add_weapon_to_loadout(weapon)
	elif player.has_method("is_current_weapon") and player.is_current_weapon(weapon):
		if GameManager.try_spend_gains(GameManager.wall_cost(ammo_cost)):
			player.add_ammo_to_current_weapon(refill_amount)


func get_prompt_text() -> String:
	if not _player:
		_player = get_tree().get_first_node_in_group("player")
	if not _player or not _player.has_method("has_weapon"):
		return ""
	if not _player.has_weapon(weapon):
		return "Tap USE to buy %s - %d Gains" % [display_name, GameManager.wall_cost(buy_cost)]
	if _player.has_method("is_current_weapon") and _player.is_current_weapon(weapon):
		return "Tap USE to refill %s ammo - %d Gains" % [display_name, GameManager.wall_cost(ammo_cost)]
	return "Switch to %s to refill ammo here" % display_name
