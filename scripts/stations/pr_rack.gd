extends Area3D
## "PR Rack" - the Pack-a-Punch equivalent. Each tap pays the Gains cost for
## the weapon's next PR level (3 levels max) and upgrades the weapon in your
## hands: more damage, faster fire rate, faster reloads, bigger mags.
## The Developer menu's PR Rack cost overrides all three prices.

@export var cost: int = 5000           # level 1
@export var cost_tier_2: int = 15000   # level 2
@export var cost_tier_3: int = 25000   # level 3


func _next_cost(weapon: WeaponData) -> int:
	var base_cost: int = cost
	if weapon.pr_level == 1:
		base_cost = cost_tier_2
	elif weapon.pr_level >= 2:
		base_cost = cost_tier_3
	return GameManager.pr_rack_cost(base_cost)


func interact(player: Node) -> void:
	var weapon: WeaponData = player.current_weapon
	if weapon == null or weapon.pr_level >= WeaponData.PR_MAX_LEVEL:
		return
	if GameManager.try_spend_gains(_next_cost(weapon)):
		player.apply_pr_upgrade()


func get_prompt_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.current_weapon == null:
		return ""
	var weapon: WeaponData = player.current_weapon
	if weapon.pr_level >= WeaponData.PR_MAX_LEVEL:
		return "%s is at max PR" % weapon.weapon_name
	return "Tap USE to rack PR %d/%d - %d Gains" % [weapon.pr_level + 1, WeaponData.PR_MAX_LEVEL, _next_cost(weapon)]
