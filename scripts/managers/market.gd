extends RefCounted
## Market rules: what's free and what's owned. Purchases are saved in profile.owned as
## "att:<id>" (attachments), "char:<id>" (characters), "badge:<id>", "ret:<id>"
## and "map:<id>" (DLC maps).
## Loaded with load() + a null check.

const STARTER_ATTACHMENTS: Array = ["red_dot", "long_barrel", "ext_mag", "foregrip"]

# THE SWITCH: true = every DLC map is owned by everyone.
# Set to false later and players must buy each DLC map with Juice.
const DLC_FREE_FOR_ALL: bool = false

# DLC maps (ids match map_config.gd). desc = few words shown in the market, price = Juice.
const DLC_MAPS: Dictionary = {
    "cheese_cube": {"desc": "Climb the stairs around a cheesy cube", "price": 800},
    "solar_substation": {"desc": "Humming power yard under the panels", "price": 800},
    "challenge": {"desc": "Hard mode with a buyable escape", "price": 1000},
    "gym_compound": {"desc": "Fenced gym grounds, many rooms", "price": 600},
}

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


## DLC map ids, in market order.
func dlc_map_ids() -> Array:
    return DLC_MAPS.keys()


func is_dlc_map(id: String) -> bool:
    return DLC_MAPS.has(id)


func map_key(id: String) -> String:
    return "map:" + id


func map_cost(id: String) -> int:
    return int(DLC_MAPS.get(id, {}).get("price", 0))


func map_desc(id: String) -> String:
    return str(DLC_MAPS.get(id, {}).get("desc", ""))


## Normal maps are always owned. DLC maps follow the switch, then saved purchases.
func owns_map(profile, id: String) -> bool:
    if not DLC_MAPS.has(id):
        return true
    if DLC_FREE_FOR_ALL:
        return true
    return profile != null and profile.has_item(map_key(id))
