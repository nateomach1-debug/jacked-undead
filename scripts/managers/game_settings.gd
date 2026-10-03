extends RefCounted
## Player settings saved on the phone (user://settings.cfg).
## Other scripts load this with load() + a null check, so a problem here can't break the game.

const FILE: String = "user://settings.cfg"
const DEFAULTS: Dictionary = {
	"touch_look": 1.0,    # multiplier on touch look speed
	"pad_look": 200.0,    # gamepad look speed, degrees per second
	"fov": 80.0,          # field of view in degrees
	"sprint_hold": 0.0,   # 0 = toggle, 1 = hold
}

var values: Dictionary = DEFAULTS.duplicate()


func _init() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FILE) == OK:
		for key in DEFAULTS.keys():
			values[key] = float(cfg.get_value("settings", key, DEFAULTS[key]))


func get_value(key: String) -> float:
	return float(values.get(key, DEFAULTS.get(key, 0.0)))


func set_value(key: String, v: float) -> void:
	values[key] = v
	save()


func reset() -> void:
	values = DEFAULTS.duplicate()
	save()


func save() -> void:
	var cfg := ConfigFile.new()
	for key in values.keys():
		cfg.set_value("settings", key, values[key])
	cfg.save(FILE)
