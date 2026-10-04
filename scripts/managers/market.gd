extends RefCounted
## Market rules: what's free and what's owned. Purchases are saved in profile.owned as
## "att:<id>" (attachments), "char:<id>" (characters), later "badge:<id>".
## Loaded with load() + a null check.

const STARTER_ATTACHMENTS: Array = ["red_dot", "long_barrel", "ext_mag", "foregrip"]

const CHARACTER_REGISTRY: String = "res://scripts/managers/character_registry.gd"
const DEFAULT_CHARACTER_COST: int = 500
# Juice price per character id. The first character in the registry is always free.
const CHARACTER_COSTS: Dictionary = {
	"Beach": 400,
	"Casual_2": 400,
	"Casual_Hoodie": 400,
	"Farmer": 500,
	"Worker": 500,
	"Punk": 600,
	"Suit": 600,
	"Spacesuit": 800,
	"Swat": 800,
}


func attachment_key(id: String) -> String:
	return "att:" + id


func owns_attachment(profile, id: String) -> bool:
	if STARTER_ATTACHMENTS.has(id):
		return true
	return profile != null and profile.has_item(attachment_key(id))


func character_key(id: String) -> String:
	return "char:" + id


func character_cost(id: String) -> int:
	return int(CHARACTER_COSTS.get(id, DEFAULT_CHARACTER_COST))


## The first character listed in the registry is free.
func free_character() -> String:
	var script = load(CHARACTER_REGISTRY)
	if script != null:
		return script.new().id_at(0)
	return "Adventurer"


func owns_character(profile, id: String) -> bool:
	if id == free_character():
		return true
	return profile != null and profile.has_item(character_key(id))


func badge_key(id: String) -> String:
	return "badge:" + id


func owns_badge(profile, id: String) -> bool:
	return profile != null and profile.has_item(badge_key(id))
