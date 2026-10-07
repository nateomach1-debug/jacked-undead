extends RefCounted
## Achievements: lifetime per-gun stats, unlocked achievements, and their rewards.
## Saved in user://achievements.cfg. Loaded with load() + a null check.
## Gun names are the base weapon names (Pistol, Rifle, SMG, Crossbow, Sniper, ...).

const FILE: String = "user://achievements.cfg"
const PROFILE_PATH: String = "res://scripts/managers/profile.gd"

# kind: "kills" or "headshots" (gun "" = all guns), or "round" (best round reached).
# reticle: the reward (id from RETICLES), or "" for a trophy with no reward.
const ACHIEVEMENTS: Array = [
    {"id": "warm_up", "title": "Warm-Up", "desc": "Get 100 zombie kills",
        "kind": "kills", "gun": "", "target": 100, "reticle": "cross"},
    {"id": "head_hunter", "title": "Head Hunter", "desc": "Get 50 headshot kills",
        "kind": "headshots", "gun": "", "target": 50, "reticle": "chevron"},
    {"id": "dead_eye", "title": "Dead Eye", "desc": "Get 100 headshot kills with the Sniper",
        "kind": "headshots", "gun": "Sniper", "target": 100, "reticle": "ring"},
    {"id": "spray_master", "title": "Spray Master", "desc": "Get 500 kills with the SMG",
        "kind": "kills", "gun": "SMG", "target": 500, "reticle": "circle_dot"},
    {"id": "survivor", "title": "Survivor", "desc": "Reach round 10",
        "kind": "round", "gun": "", "target": 10, "reticle": "diamond"},
    {"id": "marathon", "title": "Marathon", "desc": "Reach round 20",
        "kind": "round", "gun": "", "target": 20, "reticle": "triangle"},
    {"id": "rifleman", "title": "Rifleman", "desc": "Get 300 kills with the Rifle",
        "kind": "kills", "gun": "Rifle", "target": 300, "reticle": "x_cross"},
    {"id": "sidearm", "title": "Sidearm", "desc": "Get 300 kills with the Pistol",
        "kind": "kills", "gun": "Pistol", "target": 300, "reticle": "corners"},
    {"id": "steady_aim", "title": "Steady Aim", "desc": "Get 150 headshot kills with the Rifle",
        "kind": "headshots", "gun": "Rifle", "target": 150, "reticle": "t_post"},
    {"id": "skull_collector", "title": "Skull Collector", "desc": "Get 250 headshot kills",
        "kind": "headshots", "gun": "", "target": 250, "reticle": "double_chevron"},
    {"id": "bolt_thrower", "title": "Bolt Thrower", "desc": "Get 150 kills with the Crossbow",
        "kind": "kills", "gun": "Crossbow", "target": 150, "reticle": "horseshoe"},
    {"id": "veteran", "title": "Veteran", "desc": "Reach round 15",
        "kind": "round", "gun": "", "target": 15, "reticle": "ring_cross"},
    {"id": "legend", "title": "Legend", "desc": "Reach round 30",
        "kind": "round", "gun": "", "target": 30, "reticle": "mil_dot"},
    {"id": "centurion", "title": "Centurion", "desc": "Get 1000 zombie kills",
        "kind": "kills", "gun": "", "target": 1000, "reticle": "zombie"},
]

const RETICLES: Dictionary = {
    "cross": "Cross",
    "chevron": "Chevron",
    "ring": "Ring",
    "circle_dot": "Circle-Dot",
    "diamond": "Diamond",
    "triangle": "Triangle",
    "x_cross": "X-Cross",
    "corners": "Corners",
    "t_post": "T-Post",
    "horseshoe": "Horseshoe",
    "mil_dot": "Mil-Dot",
    "bullseye": "Bullseye",
    "ring_cross": "Ring Cross",
    "double_chevron": "Double Chevron",
    "ladder": "Ladder",
    "brackets": "Brackets",
    "zombie": "Zombie",
}

var weapon_kills: Dictionary = {}
var weapon_headshots: Dictionary = {}
var best_round: int = 0
var unlocked: Array = []
var reticle_choice: Dictionary = {}   # optic id -> chosen reticle id ("" = the optic's default)
var bought_reticles: Array = []   # reticle ids bought in the Market (profile item "ret:<id>")


func _init() -> void:
    _load_bought_reticles()
    var cfg := ConfigFile.new()
    if cfg.load(FILE) != OK:
        return
    var k = cfg.get_value("stats", "weapon_kills", {})
    if k is Dictionary:
        weapon_kills = k
    var h = cfg.get_value("stats", "weapon_headshots", {})
    if h is Dictionary:
        weapon_headshots = h
    best_round = int(cfg.get_value("stats", "best_round", 0))
    var u = cfg.get_value("stats", "unlocked", [])
    if u is Array:
        unlocked = u
    var rc = cfg.get_value("stats", "reticle_choice", {})
    if rc is Dictionary:
        reticle_choice = rc


func _load_bought_reticles() -> void:
    var script = load(PROFILE_PATH)
    if script == null:
        return
    var profile = script.new()
    for item in profile.owned:
        var s: String = str(item)
        if s.begins_with("ret:"):
            bought_reticles.append(s.substr(4))


func save() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("stats", "weapon_kills", weapon_kills)
    cfg.set_value("stats", "weapon_headshots", weapon_headshots)
    cfg.set_value("stats", "best_round", best_round)
    cfg.set_value("stats", "unlocked", unlocked)
    cfg.set_value("stats", "reticle_choice", reticle_choice)
    cfg.save(FILE)


## Adds one finished run's numbers, saves, and returns the ids unlocked by it.
func record_run(kills_by_gun: Dictionary, headshots_by_gun: Dictionary, round_reached: int) -> Array:
    for gun in kills_by_gun.keys():
        weapon_kills[gun] = int(weapon_kills.get(gun, 0)) + int(kills_by_gun[gun])
    for gun in headshots_by_gun.keys():
        weapon_headshots[gun] = int(weapon_headshots.get(gun, 0)) + int(headshots_by_gun[gun])
    best_round = maxi(best_round, round_reached)
    var newly: Array = []
    for a in ACHIEVEMENTS:
        var id: String = str(a["id"])
        if not unlocked.has(id) and progress(id) >= int(a["target"]):
            unlocked.append(id)
            newly.append(id)
    save()
    return newly


func _find(id: String) -> Dictionary:
    for a in ACHIEVEMENTS:
        if str(a["id"]) == id:
            return a
    return {}


func ids() -> Array:
    var out: Array = []
    for a in ACHIEVEMENTS:
        out.append(str(a["id"]))
    return out


func title(id: String) -> String:
    return str(_find(id).get("title", id))


func description(id: String) -> String:
    return str(_find(id).get("desc", ""))


func target(id: String) -> int:
    return int(_find(id).get("target", 1))


func is_unlocked(id: String) -> bool:
    return unlocked.has(id)


## Current progress toward the achievement's target.
func progress(id: String) -> int:
    var a: Dictionary = _find(id)
    if a.is_empty():
        return 0
    var kind: String = str(a["kind"])
    var gun: String = str(a["gun"])
    if kind == "round":
        return best_round
    var source: Dictionary = weapon_kills if kind == "kills" else weapon_headshots
    if gun != "":
        return int(source.get(gun, 0))
    var total: int = 0
    for v in source.values():
        total += int(v)
    return total


func reward_text(id: String) -> String:
    var r: String = str(_find(id).get("reticle", ""))
    if r == "" or not RETICLES.has(r):
        return ""
    return "Unlocks the %s reticle" % str(RETICLES[r])


## Reticle ids available: earned from achievements plus bought in the Market.

const TEST_UNLOCK_ALL: bool = false


func unlocked_reticles() -> Array: return RETICLES.keys() if TEST_UNLOCK_ALL else _earned_reticles()


func _earned_reticles() -> Array:
    var out: Array = []
    for a in ACHIEVEMENTS:
        var r: String = str(a["reticle"])
        if r != "" and unlocked.has(str(a["id"])):
            out.append(r)
    for r in bought_reticles:
        if RETICLES.has(r) and not out.has(r):
            out.append(r)
    return out


## The reticle chosen for an optic ("" = use the optic's default). Only unlocked ones count.
func get_reticle(optic_id: String) -> String:
    var r: String = str(reticle_choice.get(optic_id, ""))
    if r != "" and unlocked_reticles().has(r):
        return r
    return ""


## Saves the reticle for an optic ("" = back to the optic's default).
func set_reticle(optic_id: String, reticle_id: String) -> void:
    if reticle_id == "":
        reticle_choice.erase(optic_id)
    elif unlocked_reticles().has(reticle_id):
        reticle_choice[optic_id] = reticle_id
    save()
