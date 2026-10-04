extends RefCounted
## Badge registry. A badge is cosmetic: a colored name + icon on the name tag plus one
## effect (visible to others unless noted).
##   effect "flash" = muzzle flash tint, "aura" = glow at the feet, "hit" = your own hit-marker color
## Loaded with load() + a null check.

const BADGES: Dictionary = {
	"iron_pumper": {
		"name": "Iron Pumper", "icon": "*", "color": Color(1.0, 0.82, 0.2),
		"cost": 300, "effect": "flash", "desc": "Gold name and gold muzzle flash",
	},
	"gym_rat": {
		"name": "Gym Rat", "icon": "+", "color": Color(0.35, 0.9, 0.4),
		"cost": 400, "effect": "hit", "desc": "Green name and green hit markers (only you see them)",
	},
	"cardio_king": {
		"name": "Cardio King", "icon": "~", "color": Color(0.35, 0.65, 1.0),
		"cost": 600, "effect": "aura", "desc": "Blue name and a blue aura at your feet",
	},
	"roid_rage": {
		"name": "Roid Rage", "icon": "!", "color": Color(1.0, 0.3, 0.25),
		"cost": 800, "effect": "flash", "desc": "Red name and red muzzle flash",
	},
	"swole": {
		"name": "Swole", "icon": "#", "color": Color(0.7, 0.4, 1.0),
		"cost": 1000, "effect": "aura", "desc": "Purple name and a purple aura at your feet",
	},
	"legend": {
		"name": "Legend", "icon": "$", "color": Color(1.0, 0.85, 0.3),
		"cost": 1500, "effect": "aura", "rainbow": true, "desc": "Rainbow name and a golden aura",
	},
}


func ids() -> Array:
	return BADGES.keys()


func has_badge(id: String) -> bool:
	return BADGES.has(id)


func title(id: String) -> String:
	return str(BADGES[id]["name"]) if BADGES.has(id) else ""


func icon(id: String) -> String:
	return str(BADGES[id]["icon"]) if BADGES.has(id) else ""


func color(id: String) -> Color:
	return BADGES[id]["color"] if BADGES.has(id) else Color(1, 1, 1)


func cost(id: String) -> int:
	return int(BADGES[id]["cost"]) if BADGES.has(id) else 0


func effect(id: String) -> String:
	return str(BADGES[id]["effect"]) if BADGES.has(id) else ""


func is_rainbow(id: String) -> bool:
	return BADGES.has(id) and bool(BADGES[id].get("rainbow", false))


func description(id: String) -> String:
	return str(BADGES[id]["desc"]) if BADGES.has(id) else ""
