extends RefCounted
## Saved player profile (user://profile.cfg): Juice, lifetime stats, owned items.
## Other scripts load this with load() + a null check, so a problem here can't break the game.

const FILE: String = "user://profile.cfg"
const JUICE_PER_KILL: int = 1

var juice: int = 0
var total_kills: int = 0
var total_headshots: int = 0
var best_round: int = 0
var runs: int = 0
var owned: Array = []   # ids of bought / unlocked items (used by the market later)


func _init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) != OK:
		return
	juice = int(cfg.get_value("profile", "juice", 0))
	total_kills = int(cfg.get_value("profile", "total_kills", 0))
	total_headshots = int(cfg.get_value("profile", "total_headshots", 0))
	best_round = int(cfg.get_value("profile", "best_round", 0))
	runs = int(cfg.get_value("profile", "runs", 0))
	var saved = cfg.get_value("profile", "owned", [])
	if saved is Array:
		owned = saved


func get_juice() -> int:
	return juice


func add_juice(amount: int) -> void:
	juice = maxi(0, juice + amount)
	save()


## Returns false (and spends nothing) if you can't afford it.
func spend_juice(amount: int) -> bool:
	if juice < amount:
		return false
	juice -= amount
	save()
	return true


## Called once at the end of a run. Returns the Juice earned.
func record_run(kills: int, headshots: int, round_reached: int) -> int:
	var earned: int = maxi(0, kills) * JUICE_PER_KILL
	juice += earned
	total_kills += kills
	total_headshots += headshots
	best_round = maxi(best_round, round_reached)
	runs += 1
	save()
	return earned


func has_item(id: String) -> bool:
	return owned.has(id)


func add_item(id: String) -> void:
	if not owned.has(id):
		owned.append(id)
		save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "juice", juice)
	cfg.set_value("profile", "total_kills", total_kills)
	cfg.set_value("profile", "total_headshots", total_headshots)
	cfg.set_value("profile", "best_round", best_round)
	cfg.set_value("profile", "runs", runs)
	cfg.set_value("profile", "owned", owned)
	cfg.save(FILE)
