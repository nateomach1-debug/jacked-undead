extends RefCounted
## Market rules: what's free and what's owned. Purchases are saved in profile.owned as
## "att:<id>" (attachments), "char:<id>" (characters), later "badge:<id>".
## Loaded with load() + a null check.

const STARTER_ATTACHMENTS: Array = ["red_dot", "long_barrel", "ext_mag", "foregrip"]

# Reticles sold for Juice (the rest are earned from achievements). Saved as "ret:<id>".
const RETICLE_COSTS: Dictionary = {
    "bullseye": 250,
    "brackets": 250,
    "ladder": 350,
    "dumbbell": 300,
    "kettlebell": 300,
    "lightning": 350,
    "tombstone": 350,
    "skull": 400,
    "bicep": 400,
    "bones": 400,
    "plate": 450,
    "biohazard": 500,
    "bite": 500,
    "flame": 500,
    "blood_drip": 550,
    "brain": 550,
    "radar": 600,
    "lock_on": 600,
}

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


func reticle_key(id: String) -> String:
    return "ret:" + id


func owns_reticle(profile, id: String) -> bool:
    return profile != null and profile.has_item(reticle_key(id))
