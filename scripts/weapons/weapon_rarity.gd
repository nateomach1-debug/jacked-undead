extends RefCounted
## Weapon rarity. The Loot Locker rolls a tier before it hands out a gun.
## A rarity gun is a copy of the gun with boosted damage plus fixed random
## attachments (meta "rarity", "rarity_slots"). attachments.gd applies those
## slots on top of the player's own picks, and they survive PR upgrades.
## Tune everything in TIERS: weight = roll odds, damage = multiplier,
## slots = how many attachment slots get a random attachment.

const ORDER: Array = ["common", "uncommon", "rare", "epic", "legendary"]

const TIERS: Dictionary = {
    "common": {"name": "Common", "weight": 55, "damage": 1.0, "slots": 0, "color": Color(1.0, 1.0, 1.0)},
    "uncommon": {"name": "Uncommon", "weight": 25, "damage": 1.1, "slots": 1, "color": Color(0.3, 1.0, 0.35)},
    "rare": {"name": "Rare", "weight": 12, "damage": 1.25, "slots": 2, "color": Color(0.3, 0.6, 1.0)},
    "epic": {"name": "Epic", "weight": 6, "damage": 1.45, "slots": 3, "color": Color(0.7, 0.35, 1.0)},
    "legendary": {"name": "Legendary", "weight": 2, "damage": 1.75, "slots": 4, "color": Color(1.0, 0.75, 0.15)},
}


func roll_tier() -> String:
    var total: int = 0
    for id in ORDER:
        total += int(TIERS[id]["weight"])
    var r: int = randi() % maxi(total, 1)
    for id in ORDER:
        r -= int(TIERS[id]["weight"])
        if r < 0:
            return str(id)
    return "common"


func tier_name(tier: String) -> String:
    if TIERS.has(tier):
        return str(TIERS[tier]["name"])
    return "Common"


func tier_color(tier: String) -> Color:
    if TIERS.has(tier):
        return TIERS[tier]["color"]
    return Color(1.0, 1.0, 1.0)


## Returns a rarity copy of w (w itself is never changed). Common returns w.
func apply(w: WeaponData, tier: String) -> WeaponData:
    if w == null or tier == "common" or not TIERS.has(tier):
        return w
    var t: Dictionary = TIERS[tier]
    var r: WeaponData = w.duplicate() as WeaponData
    if r == null:
        return w
    r.damage *= float(t["damage"])
    r.burn_damage_per_second *= float(t["damage"])
    r.set_meta("rarity", tier)
    r.set_meta("rarity_slots", _roll_slots(int(t["slots"])))
    return r


## Random attachments for `count` random slots, from ALL attachments of that
## slot (ignores ownership and level).
func _roll_slots(count: int) -> Dictionary:
    var out: Dictionary = {}
    if count <= 0:
        return out
    var script = load("res://scripts/weapons/attachments.gd")
    if script == null:
        return out
    var reg = script.new()
    var slots: Array = reg.SLOTS.duplicate()
    slots.shuffle()
    for i in range(mini(count, slots.size())):
        var slot: String = str(slots[i])
        var pool: Array = []
        for id in reg.ATTACHMENTS.keys():
            if str(reg.ATTACHMENTS[id]["slot"]) == slot:
                pool.append(str(id))
        if not pool.is_empty():
            out[slot] = pool[randi() % pool.size()]
    return out

# END OF FILE
