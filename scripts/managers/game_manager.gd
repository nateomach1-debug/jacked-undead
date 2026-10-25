extends Node
## GameManager (autoload singleton)
## Tracks "Gains" (currency), the current round, kill count, unlocked zones,
## global run state, the developer-menu settings and the custom game mode.
## Access from anywhere as: GameManager.add_gains(50)

signal gains_changed(new_amount: int)
signal round_changed(new_round: int)
signal kills_changed(new_amount: int)
signal player_died
signal zone_unlocked(zone: String)
signal barrier_opened
signal dev_settings_changed

const DEV_FILE: String = "user://dev_settings.cfg"
const DEV_DEFAULTS: Dictionary = {
    "zombie_damage": -1.0,  # flat HP per zombie hit; negative = the zombie's own value
    "locker_cost": -1.0,    # flat Gains; negative = the scene's value
    "pr_cost": -1.0,        # flat Gains; negative = the scene's value
    "ending_cost": -1.0,
    "wall_scale": 1.0,      # multiplier on wall buy + ammo prices
    "supp_scale": 1.0,      # multiplier on supplement prices
    "show_nav": 0.0,        # 1.0 = nav polygons + NAV label visible
    "start_wonder": 0.0,    # 1.0 = start the run with a wonder gun next to the pistol
    "wonder_index": 0.0,    # which wonder gun (position in wonder_weapons.build_all())
}

## Custom game mode: true = the feature is in the run (normal game), zombie_hp is a multiplier.
const CUSTOM_DEFAULTS: Dictionary = {
    "pr_rack": true,
    "loot_locker": true,
    "rarity": true,
    "attachments": true,
    "supplements": true,
    "wall_buys": true,
    "powerups": true,
    "zombie_hp": 1.0,
}
## Short leaderboard code for each feature that is switched off.
const CUSTOM_CODES: Dictionary = {
    "pr_rack": "nopr",
    "loot_locker": "noloot",
    "rarity": "norarity",
    "attachments": "noatt",
    "supplements": "nosupp",
    "wall_buys": "nowall",
    "powerups": "nopow",
}

var gains: int = 500
var round_number: int = 1
var kills: int = 0
var gains_earned: int = 0     # Gains from kills/damage only; refunds don't count
var headshot_kills: int = 0
var revives: int = 0          # co-op: teammates you revived
var deaths: int = 0           # co-op: times you went down
var last_weapon: String = ""  # base name of the gun this player fired last (set by the player)
var weapon_kills: Dictionary = {}       # base gun name -> kills this run
var weapon_headshots: Dictionary = {}   # base gun name -> headshot kills this run
var is_game_over: bool = false
var unlocked_zones: Array = ["start"]
var dev: Dictionary = DEV_DEFAULTS.duplicate()
var dev_override: Dictionary = {}   # co-op: the host's dev settings, used while online
var custom: Dictionary = CUSTOM_DEFAULTS.duplicate()   # this phone's custom game mode choices
var custom_override: Dictionary = {}   # co-op: the host's custom mode, used while online


func _ready() -> void:
    _load_dev_settings()
    _apply_nav_debug()
    _install_touch_fix()


## Adds the touch fixes (drag-to-scroll lists and sliders) to the whole game.
func _install_touch_fix() -> void:
    var script = load("res://scripts/managers/touch_fix.gd")
    if script == null:
        push_warning("touch_fix.gd is missing or broken.")
        return
    var node := Node.new()
    node.set_script(script)
    node.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(node)


## earned = false for refunds (like the co-op revive bonus): they add Gains
## but don't count toward the "Gains earned" score, and power-ups don't touch them.
## earned = true (kills/damage) is doubled while PRE-WORKOUT SURGE is active.
func add_gains(amount: int, earned: bool = true) -> void:
    if earned and amount > 0:
        amount = int(round(amount * _gain_multiplier()))
        gains_earned += amount
    gains += amount
    gains_changed.emit(gains)


## 2.0 while the Pre-Workout Surge power-up is running on this phone, else 1.0.
func _gain_multiplier() -> float:
    var pm = get_tree().get_first_node_in_group("powerup_manager")
    if pm != null and pm.has_method("has_effect") and pm.has_effect("pre_workout"):
        return 2.0
    return 1.0


func try_spend_gains(amount: int) -> bool:
    if gains >= amount:
        gains -= amount
        gains_changed.emit(gains)
        return true
    return false


func add_kill(headshot: bool = false) -> void:
    kills += 1
    _track_weapon_kill(headshot)
    if headshot:
        headshot_kills += 1
    kills_changed.emit(kills)


## Credits the kill (and headshot) to the gun this player fired last.
func _track_weapon_kill(headshot: bool) -> void:
    var gun: String = last_weapon if last_weapon != "" else "Unknown"
    weapon_kills[gun] = int(weapon_kills.get(gun, 0)) + 1
    if headshot:
        weapon_headshots[gun] = int(weapon_headshots.get(gun, 0)) + 1


## This player's numbers for the game over screen / co-op scoreboard.
func get_stats() -> Dictionary:
    return {
        "kills": kills,
        "gains_earned": gains_earned,
        "headshots": headshot_kills,
        "revives": revives,
        "deaths": deaths,
    }


func start_next_round() -> void:
    round_number += 1
    round_changed.emit(round_number)


## A spawn point with no zone tag is always active.
func is_zone_unlocked(zone: String) -> bool:
    return zone == "" or unlocked_zones.has(zone)


## Called by a bought door: unlocks its zones, then announces the opening
## (the nav baker listens to rebake the walkable area).
func open_barrier(zones: PackedStringArray) -> void:
    for zone in zones:
        if zone != "" and not unlocked_zones.has(zone):
            unlocked_zones.append(zone)
            zone_unlocked.emit(zone)
    barrier_opened.emit()


func report_player_death() -> void:
    if is_game_over:
        return
    is_game_over = true
    player_died.emit()


func reset_run() -> void:
    gains = 500
    round_number = 1
    kills = 0
    gains_earned = 0
    headshot_kills = 0
    revives = 0
    deaths = 0
    last_weapon = ""
    weapon_kills.clear()
    weapon_headshots.clear()
    is_game_over = false
    unlocked_zones = ["start"]
    gains_changed.emit(gains)
    round_changed.emit(round_number)
    kills_changed.emit(kills)


# ---------- developer settings ----------

func dev_get(key: String) -> float:
    if dev_override.has(key) and _online():
        return float(dev_override[key])
    return float(dev.get(key, DEV_DEFAULTS.get(key, 0.0)))


func dev_set(key: String, value: float) -> void:
    dev[key] = value
    _save_dev_settings()
    if key == "show_nav":
        _apply_nav_debug()
    dev_settings_changed.emit()


func dev_reset() -> void:
    dev = DEV_DEFAULTS.duplicate()
    _save_dev_settings()
    _apply_nav_debug()
    dev_settings_changed.emit()


func dev_show_nav() -> bool:
    return dev_get("show_nav") > 0.5


func get_zombie_damage(base: float) -> float:
    var v: float = dev_get("zombie_damage")
    return base if v < 0.0 else v


func wall_cost(base: int) -> int:
    return int(round(base * dev_get("wall_scale")))


func supplement_cost(base: int) -> int:
    return int(round(base * dev_get("supp_scale")))


func loot_locker_cost(base: int) -> int:
    var v: float = dev_get("locker_cost")
    return base if v < 0.0 else int(v)


func pr_rack_cost(base: int) -> int:
    var v: float = dev_get("pr_cost")
    return base if v < 0.0 else int(v)


func _apply_nav_debug() -> void:
    NavigationServer3D.set_debug_enabled(dev_show_nav())


func _load_dev_settings() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(DEV_FILE) != OK:
        return
    for key in DEV_DEFAULTS.keys():
        dev[key] = float(cfg.get_value("dev", key, DEV_DEFAULTS[key]))


func _save_dev_settings() -> void:
    var cfg := ConfigFile.new()
    for key in dev.keys():
        cfg.set_value("dev", key, dev[key])
    cfg.save(DEV_FILE)


## Co-op: called when the host starts a game, so every phone uses the host's settings.
func dev_apply_override(settings: Dictionary) -> void:
    dev_override = settings.duplicate()
    _apply_nav_debug()
    dev_settings_changed.emit()


# ---------- custom game mode ----------

## The value in force right now. Online it comes from the host (custom_override,
## filled in by the co-op step); offline it is this phone's own choice.
func custom_get(key: String):
    var def = CUSTOM_DEFAULTS.get(key)
    if _online():
        return custom_override.get(key, def)
    return custom.get(key, def)


## True when the feature is part of this run (the normal game has everything on).
func custom_on(key: String) -> bool:
    return bool(custom_get(key))


func custom_set(key: String, value) -> void:
    custom[key] = value


func custom_reset() -> void:
    custom = CUSTOM_DEFAULTS.duplicate()


## True when this run is a normal run (nothing changed).
func custom_is_default() -> bool:
    for key in CUSTOM_DEFAULTS.keys():
        if custom_get(key) != CUSTOM_DEFAULTS[key]:
            return false
    return true


## Leaderboard tag for this combination, e.g. "nopr-noloot". Empty = normal run.
func custom_code() -> String:
    var parts: Array = []
    for key in CUSTOM_CODES.keys():
        if not custom_on(key):
            parts.append(CUSTOM_CODES[key])
    var hp: float = float(custom_get("zombie_hp"))
    if absf(hp - 1.0) > 0.01:
        parts.append("hp%d" % int(round(hp * 10.0)))
    return "-".join(PackedStringArray(parts))


## Co-op: called when the host starts a game, so every phone uses the host's custom mode.
func custom_apply_override(settings: Dictionary) -> void:
    custom_override = settings.duplicate()


## True only while connected through a real network peer (not the default offline one).
func _online() -> bool:
    var peer: MultiplayerPeer = multiplayer.multiplayer_peer
    return peer != null and not (peer is OfflineMultiplayerPeer)
