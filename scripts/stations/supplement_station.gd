extends Area3D

@export var supplement_id: String = "trt"   # trt | creatine | whey | pre_workout | fish_oil | bcaas
@export var display_name: String = "TRT"
@export var cost: int = 2000
@export var body_color: Color = Color(0.85, 0.65, 0.1, 1)
@export var icon_texture: Texture2D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var sign_sprite: Sprite3D = $SignSprite3D

var _purchased_by: Array = []


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.emission_enabled = true
	mat.emission = body_color
	mat.emission_energy_multiplier = 0.4
	mesh_instance.set_surface_override_material(0, mat)
	if icon_texture:
		sign_sprite.texture = icon_texture


func interact(player: Node) -> void:
	if player in _purchased_by:
		return
	if GameManager.try_spend_gains(cost):
		player.apply_supplement(supplement_id)
		_purchased_by.append(player)


func get_prompt_text() -> String:
	if _purchased_by.size() > 0:
		return "%s (already stacked)" % display_name
	return "Tap USE to buy %s - %d Gains" % [display_name, cost]
