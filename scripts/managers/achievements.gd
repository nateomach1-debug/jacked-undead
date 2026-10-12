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
    {"id": "gunslinger", "title": "Gunslinger", "desc": "Get 750 kills with the Pistol",
        "kind": "kills", "gun": "Pistol", "target": 750, "reticle": "gun_pistol"},
    {"id": "battle_ready", "title": "Battle Ready", "desc": "Get 800 kills with the Rifle",
        "kind": "kills", "gun": "Rifle", "target": 800, "reticle": "gun_rifle"},
    {"id": "bullet_hose", "title": "Bullet Hose", "desc": "Get 1500 kills with the SMG",
        "kind": "kills", "gun": "SMG", "target": 1500, "reticle": "gun_smg"},
    {"id": "quiver_full", "title": "Quiver Full", "desc": "Get 500 kills with the Crossbow",
        "kind": "kills", "gun": "Crossbow", "target": 500, "reticle": "gun_crossbow"},
    {"id": "long_shot", "title": "Long Shot", "desc": "Get 400 kills with the Sniper",
        "kind": "kills", "gun": "Sniper", "target": 400, "reticle": "gun_sniper"},
    {"id": "boomstick", "title": "Boomstick", "desc": "Get 400 kills with the Pump Shotgun",
        "kind": "kills", "gun": "Pump Shotgun", "target": 400, "reticle": "gun_shotgun"},
    {"id": "six_shooter", "title": "Six Shooter", "desc": "Get 300 kills with the Revolver",
        "kind": "kills", "gun": "Revolver", "target": 300, "reticle": "gun_revolver"},
    {"id": "make_my_day", "title": "Make My Day", "desc": "Get 100 headshot kills with the Magnum",
        "kind": "headshots", "gun": "Magnum", "target": 100, "reticle": "gun_magnum"},
    {"id": "both_barrels", "title": "Both Barrels", "desc": "Get 250 kills with the Double-Barrel",
        "kind": "kills", "gun": "Double-Barrel", "target": 250, "reticle": "gun_double_barrel"},
    {"id": "suppressing_fire", "title": "Suppressing Fire", "desc": "Get 1000 kills with the LMG",
        "kind": "kills", "gun": "LMG", "target": 1000, "reticle": "gun_lmg"},
    {"id": "triple_tap", "title": "Triple Tap", "desc": "Get 150 headshot kills with the Burst Rifle",
        "kind": "headshots", "gun": "Burst Rifle", "target": 150, "reticle": "gun_burst_rifle"},
    {"id": "pyromaniac", "title": "Pyromaniac", "desc": "Get 500 kills with the Flamethrower",
        "kind": "kills", "gun": "Flamethrower", "target": 500, "reticle": "gun_flamethrower"},
    {"id": "fire_in_the_hole", "title": "Fire in the Hole", "desc": "Get 300 kills with the Grenade Launcher",
        "kind": "kills", "gun": "Grenade Launcher", "target": 300, "reticle": "gun_grenade_launcher"},
    {"id": "rocket_man", "title": "Rocket Man", "desc": "Get 250 kills with the Rocket Launcher",
        "kind": "kills", "gun": "Rocket Launcher", "target": 250, "reticle": "gun_rocket_launcher"},
    {"id": "tactical_edge", "title": "Tactical Edge", "desc": "Get 400 kills with the Tactical .45",
        "kind": "kills", "gun": "Tactical .45", "target": 400, "reticle": "gun_tactical_45"},
    {"id": "quick_draw", "title": "Quick Draw", "desc": "Get 300 kills with the Speed Revolver",
        "kind": "kills", "gun": "Speed Revolver", "target": 300, "reticle": "gun_speed_revolver"},
    {"id": "hand_of_god", "title": "Hand of God", "desc": "Get 100 headshot kills with the Hand Cannon",
        "kind": "headshots", "gun": "Hand Cannon", "target": 100, "reticle": "gun_hand_cannon"},
    {"id": "designated", "title": "Designated Marksman", "desc": "Get 150 headshot kills with the Marksman DMR",
        "kind": "headshots", "gun": "Marksman DMR", "target": 150, "reticle": "gun_marksman_dmr"},
    {"id": "heavy_hitter", "title": "Heavy Hitter", "desc": "Get 500 kills with the Heavy Burst",
        "kind": "kills", "gun": "Heavy Burst", "target": 500, "reticle": "gun_heavy_burst"},
    {"id": "shell_shower", "title": "Shell Shower", "desc": "Get 600 kills with the Auto-Shotgun",
        "kind": "kills", "gun": "Auto-Shotgun", "target": 600, "reticle": "gun_auto_shotgun"},
    {"id": "pocket_rocket", "title": "Pocket Rocket", "desc": "Get 600 kills with the Micro SMG",
        "kind": "kills", "gun": "Micro SMG", "target": 600, "reticle": "gun_micro_smg"},
    {"id": "lead_storm", "title": "Lead Storm", "desc": "Get 2000 kills with the Chaingun",
        "kind": "kills", "gun": "Chaingun", "target": 2000, "reticle": "gun_chaingun"},
    {"id": "rapid_bolts", "title": "Rapid Bolts", "desc": "Get 100 headshot kills with the Repeater Crossbow",
        "kind": "headshots", "gun": "Repeater Crossbow", "target": 100, "reticle": "gun_repeater_crossbow"},
    {"id": "overwatch", "title": "Overwatch", "desc": "Get 150 headshot kills with the Semi-Auto Sniper",
        "kind": "headshots", "gun": "Semi-Auto Sniper", "target": 150, "reticle": "gun_semi_sniper"},
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
    "dumbbell": "Dumbbell",
    "skull": "Skull",
    "plate": "Barbell Plate",
    "bicep": "Bicep",
    "biohazard": "Biohazard",
    "bite": "Crosshair Bite",
    "blood_drip": "Blood Drip",
    "kettlebell": "Kettlebell",
    "brain": "Brain",
    "tombstone": "Tombstone",
    "bones": "Bones",
    "radar": "Radar",
    "lock_on": "Lock-On",
    "lightning": "Lightning",
    "flame": "Flame",
    "gun_pistol": "Pistol Sights",
    "gun_rifle": "Rifle Sights",
    "gun_smg": "SMG Sights",
    "gun_crossbow": "Crossbow Sights",
    "gun_sniper": "Sniper Sights",
    "gun_shotgun": "Shotgun Sights",
    "gun_revolver": "Revolver Sights",
    "gun_magnum": "Magnum Sights",
    "gun_double_barrel": "Double-Barrel Sights",
    "gun_lmg": "LMG Sights",
    "gun_burst_rifle": "Burst Rifle Sights",
    "gun_flamethrower": "Flamethrower Sights",
    "gun_grenade_launcher": "Grenade Launcher Sights",
    "gun_rocket_launcher": "Rocket Launcher Sights",
    "gun_tactical_45": "Tactical .45 Sights",
    "gun_speed_revolver": "Speed Revolver Sights",
    "gun_hand_cannon": "Hand Cannon Sights",
    "gun_marksman_dmr": "Marksman DMR Sights",
    "gun_heavy_burst": "Heavy Burst Sights",
    "gun_auto_shotgun": "Auto-Shotgun Sights",
    "gun_micro_smg": "Micro SMG Sights",
    "gun_chaingun": "Chaingun Sights",
    "gun_repeater_crossbow": "Repeater Crossbow Sights",
    "gun_semi_sniper": "Semi-Auto Sniper Sights",
    "prism_ring": "Prism Ring",
    "neon_diamond": "Neon Diamond",
    "toxic_zombie": "Toxic Zombie",
    "hazard_brackets": "Hazard Brackets",
    "ice_fire": "Ice & Fire",
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

const TEST_UNLOCK_ALL: bool = true


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
