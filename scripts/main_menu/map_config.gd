extends RefCounted
## Which maps players can pick. Set a map to false below to hide it everywhere
## (Start menu and Co-op host screen) until it's fixed.
## "dlc": true = buyable map (shown in the DLC tab; rules live in market.gd).
## "limited": true = limited-time map (shown in the LIMITED TIME tab). It needs
## "ends" (last day it can be played, "YYYY-MM-DD", the phone's date) and can
## have "juice_mult" (Juice earned from kills is multiplied by it).

const MARKET_PATH: String = "res://scripts/managers/market.gd"
const PROFILE_PATH: String = "res://scripts/managers/profile.gd"

const ENABLED: Dictionary = {
    "arena": true,
    "building": true,
    "multi_room": true,
    "gym_compound": true,
    "challenge": true,
    "complex": false,
    "solar_substation": true,
    "cheese_cube": true,
    "random_gym": true,
    "swarm_underground": true,
    "halloween": true,   # set to true once scenes/main/halloween_map.tscn exists
}

# coop = also offered on the Co-op host screen.
const MAPS: Array = [
    {"id": "arena", "title": "GYM ARENA", "path": "res://scenes/main/main.tscn", "coop": true},
    {"id": "building", "title": "BUILDING", "path": "res://scenes/main/building_map.tscn", "coop": true},
    {"id": "multi_room", "title": "MULTI-ROOM", "path": "res://scenes/main/multi_room_map.tscn", "coop": true},
    {"id": "gym_compound", "title": "GYM COMPOUND", "path": "res://scenes/main/gym_compound.tscn", "coop": true, "dlc": true},
    {"id": "challenge", "title": "CHALLENGE MAP", "path": "res://scenes/main/challenge_map.tscn", "coop": true, "dlc": true},
    {"id": "complex", "title": "COMPLEX", "path": "res://scenes/main/complex.tscn", "coop": false},
    {"id": "solar_substation", "title": "SOLAR SUBSTATION", "path": "res://scenes/main/solar_substation.tscn", "coop": true, "dlc": true},
    {"id": "cheese_cube", "title": "CHEESE CUBE", "path": "res://scenes/main/cheese_cube_map.tscn", "coop": true, "dlc": true},
    {"id": "random_gym", "title": "RANDOM GYM", "path": "res://scenes/main/generated_gym_map.tscn", "coop": true},
    {"id": "swarm_underground", "title": "SWARM: UNDERGROUND", "path": "res://scenes/main/swarm_underground_map.tscn", "coop": true},
    {"id": "halloween", "title": "HALLOWEEN", "path": "res://scenes/main/halloween_map.tscn", "coop": true, "limited": true, "ends": "2026-11-30", "juice_mult": 2.0},
]


## The map entry with this id, or an empty dictionary.
func _find_map(id: String) -> Dictionary:
    for m in MAPS:
        if str(m["id"]) == id:
            return m
    return {}


## Today's date on the phone, as "YYYY-MM-DD".
func _today() -> String:
    return Time.get_date_string_from_system()


## True when a limited-time map is past its last day.
func is_expired(m: Dictionary) -> bool:
    if not bool(m.get("limited", false)):
        return false
    var ends: String = str(m.get("ends", ""))
    if ends == "":
        return false
    return _today() > ends   # "YYYY-MM-DD" strings compare in date order


## Whole days left including today (0 = last day). -1 if the map has no end date.
func days_left(m: Dictionary) -> int:
    var ends: String = str(m.get("ends", ""))
    if ends == "":
        return -1
    var end_unix: int = int(Time.get_unix_time_from_datetime_string(ends + "T00:00:00"))
    var today_unix: int = int(Time.get_unix_time_from_datetime_string(_today() + "T00:00:00"))
    return maxi(int((end_unix - today_unix) / 86400), 0)


## Juice multiplier for kills on this map (1.0 for every normal map).
func get_juice_multiplier(id: String) -> float:
    var m: Dictionary = _find_map(id)
    if m.is_empty() or is_expired(m):
        return 1.0
    return float(m.get("juice_mult", 1.0))


func is_enabled(id: String) -> bool:
    if not bool(ENABLED.get(id, true)):
        return false
    var m: Dictionary = _find_map(id)
    if not m.is_empty() and is_expired(m):
        return false
    return true


## Maps for the Co-op host screen (includes DLC maps, owned or not).
func get_enabled_maps() -> Array:
    var out: Array = []
    for m in MAPS:
        if is_enabled(str(m["id"])) and bool(m["coop"]):
            out.append(m)
    return out


## Co-op host list: enabled co-op maps, minus DLC maps the host doesn't own.
func get_owned_coop_maps() -> Array:
    var market = null
    var profile = null
    var market_script = load(MARKET_PATH)
    if market_script != null:
        market = market_script.new()
    var profile_script = load(PROFILE_PATH)
    if profile_script != null:
        profile = profile_script.new()
    var out: Array = []
    for m in get_enabled_maps():
        if market != null and not market.owns_map(profile, str(m["id"])):
            continue
        out.append(m)
    return out


## Maps for the Start menu's normal tab (Arena and Building have their own buttons).
func get_extra_maps() -> Array:
    var out: Array = []
    for m in MAPS:
        var id: String = str(m["id"])
        if id == "arena" or id == "building":
            continue
        if bool(m.get("dlc", false)) or bool(m.get("limited", false)):
            continue
        if is_enabled(id):
            out.append(m)
    return out


## Maps for the Start menu's DLC tab.
func get_dlc_maps() -> Array:
    var out: Array = []
    for m in MAPS:
        if bool(m.get("dlc", false)) and is_enabled(str(m["id"])):
            out.append(m)
    return out


## Maps for the Start menu's LIMITED TIME tab (only the ones still running).
func get_limited_maps() -> Array:
    var out: Array = []
    for m in MAPS:
        if bool(m.get("limited", false)) and is_enabled(str(m["id"])):
            out.append(m)
    return out
