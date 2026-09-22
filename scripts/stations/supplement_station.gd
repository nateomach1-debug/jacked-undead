extends Area3D
## A single "supplement" vending machine (perk-a-cola equivalent).
## Set supplement_id + cost + display_name per instance in the editor,
## and place one of these per perk around the map.

@export var supplement_id: String = "trt"   # trt | creatine | whey | pre_workout | fish_oil | bcaas
@export var display_name: String = "TRT"
@export var cost: int = 2000

var _purchased_by: Array = []


func interact(player: Node) -> void:
	if player in _purchased_by:
		return
	if GameManager.try_spend_gains(cost):
		player.apply_supplement(supplement_id)
		_purchased_by.append(player)


func get_prompt_text() -> String:
	if _purchased_by.size() > 0:
		return "%s (already stacked)" % display_name
	return "Hold F to buy %s - %d Gains" % [display_name, cost]
