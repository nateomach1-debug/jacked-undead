extends RefCounted
## Which maps players can pick. Set a map to false below to hide it everywhere
## (Start menu and Co-op host screen) until it's fixed.

const ENABLED: Dictionary = {
	"arena": true,
	"building": true,
	"multi_room": true,
	"gym_compound": true,
	"challenge": true,
	"complex": true,
    "solar_substation": true,
    "cheese_cube": true,
}

# coop = also offered on the Co-op host screen.
const MAPS: Array = [
	{"id": "arena", "title": "GYM ARENA", "path": "res://scenes/main/main.tscn", "coop": true},
	{"id": "building", "title": "BUILDING", "path": "res://scenes/main/building_map.tscn", "coop": true},
	{"id": "multi_room", "title": "MULTI-ROOM", "path": "res://scenes/main/multi_room_map.tscn", "coop": true},
	{"id": "gym_compound", "title": "GYM COMPOUND", "path": "res://scenes/main/gym_compound.tscn", "coop": true},
	{"id": "challenge", "title": "CHALLENGE MAP", "path": "res://scenes/main/challenge_map.tscn", "coop": true},
	{"id": "complex", "title": "COMPLEX", "path": "res://scenes/main/complex.tscn", "coop": true},
    {"id": "solar_substation", "title": "SOLAR SUBSTATION", "path": "res://scenes/main/solar_substation.tscn", "coop": true},
    {"id": "cheese_cube", "title": "CHEESE CUBE", "path": "res://scenes/main/cheese_cube_map.tscn", "coop": true},
]


func is_enabled(id: String) -> bool:
	return bool(ENABLED.get(id, true))


## Maps for the Co-op host screen.
func get_enabled_maps() -> Array:
	var out: Array = []
	for m in MAPS:
		if is_enabled(str(m["id"])) and bool(m["coop"]):
			out.append(m)
	return out


## Maps for the Start menu's extra buttons (Arena and Building have their own buttons).
func get_extra_maps() -> Array:
	var out: Array = []
	for m in MAPS:
		var id: String = str(m["id"])
		if id == "arena" or id == "building":
			continue
		if is_enabled(id):
			out.append(m)
	return out
