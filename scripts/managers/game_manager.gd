extends Node
## GameManager (autoload singleton)
## Tracks "Gains" (currency), the current round, kill count, unlocked zones,
## global run state, and the developer-menu settings.
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
	"wall_scale": 1.0,      # multiplier on wall buy + ammo prices
	"supp_scale": 1.0,      # multiplier on supplement prices
	"show_nav": 0.0,        # 1.0 = nav polygons + NAV label visible
}

var gains: int = 500
var round_number: int = 1
var kills: int = 0
var gains_earned: int = 0     # Gains from kills/damage only; refunds don't count
var headshot_kills: int = 0
var revives: int = 0          # co-op: teammates you revived
var deaths: int = 0           # co-op: times you went down
var is_game_over: bool = false
var unlocked_zones: Array = ["start"]
var dev: Dictionary = DEV_DEFAULTS.duplicate()
var dev_override: Dictionary = {}   # co-op: the host's dev settings, used while online

func _ready() -> void:
	_load_dev_settings()
	_apply_nav_debug()


## earned = false for refunds (like the co-op revive bonus): they add Gains
## but don't count toward the "Gains earned" score.
func add_gains(amount: int, earned: bool = true) -> void:
	gains += amount
	if earned and amount > 0:
		gains_earned += amount
	gains_changed.emit(gains)


func try_spend_gains(amount: int) -> bool:
	if gains >= amount:
		gains -= amount
		gains_changed.emit(gains)
		return true
	return false


func add_kill(headshot: bool = false) -> void:
	kills += 1
	if headshot:
		headshot_kills += 1
	kills_changed.emit(kills)


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


## True only while connected through a real network peer (not the default offline one).
func _online() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	return peer != null and not (peer is OfflineMultiplayerPeer)
