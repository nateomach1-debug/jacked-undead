extends RefCounted
## Weapon levels: XP per weapon type (base name), saved in user://weapon_levels.cfg.
## 1 XP per kill, +1 for a headshot kill. XP to go from level n to n+1 = 20 + 10n.
## Each attachment has a required weapon level (REQUIRED). Loaded with load() + null check.

const FILE_PATH: String = "user://weapon_levels.cfg"
const MAX_LEVEL: int = 40

# attachment id -> weapon level needed to use it (you must also own it from the Market).
const REQUIRED: Dictionary = {
    "angled_grip": 2,
    "red_dot": 3,
    "ext_mag": 4,
    "compensator": 5,
    "foregrip": 8,
    "fast_mag": 10,
    "holo": 12,
    "ammo_pouch": 15,
    "suppressor": 16,
    "ergo_grip": 18,
    "long_barrel": 22,
    "scope_4x": 24,
    "vertical_grip": 26,
    "drum_mag": 28,
    "heavy_barrel": 32,
    "scope_8x": 36,
}


func _load_all() -> Dictionary:
    var cfg := ConfigFile.new()
    if cfg.load(FILE_PATH) != OK:
        return {}
    var d = cfg.get_value("weapons", "xp", {})
    if d is Dictionary:
        return d.duplicate()
    return {}


func _save_all(d: Dictionary) -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("weapons", "xp", d)
    cfg.save(FILE_PATH)


## Total XP needed to reach a level (level 1 = 0).
func xp_for_level(level: int) -> int:
    return (level - 1) * (20 + 5 * level)


func level_for_xp(xp: int) -> int:
    var lv: int = 1
    while lv < MAX_LEVEL and xp >= xp_for_level(lv + 1):
        lv += 1
    return lv


func get_saved_xp(base_name: String) -> int:
    return int(_load_all().get(base_name, 0))


## XP this gun has earned so far in the current run (0 once the run is over,
## because the game over screen has already saved it).
func run_xp(base_name: String) -> int:
    if GameManager.is_game_over:
        return 0
    var k = GameManager.get("weapon_kills")
    var h = GameManager.get("weapon_headshots")
    var xp: int = 0
    if k is Dictionary:
        xp += int(k.get(base_name, 0))
    if h is Dictionary:
        xp += int(h.get(base_name, 0))
    return xp


## Level of a gun. include_run = true counts this run's XP too (live level-ups).
func get_level(base_name: String, include_run: bool = true) -> int:
    var xp: int = get_saved_xp(base_name)
    if include_run:
        xp += run_xp(base_name)
    return level_for_xp(xp)


## {level, xp, into, need, frac}: need = XP for the next level (0 at max level).
func progress(base_name: String, include_run: bool = true) -> Dictionary:
    var xp: int = get_saved_xp(base_name)
    if include_run:
        xp += run_xp(base_name)
    var lv: int = level_for_xp(xp)
    if lv >= MAX_LEVEL:
        return {"level": lv, "xp": xp, "into": 0, "need": 0, "frac": 1.0}
    var start: int = xp_for_level(lv)
    var need: int = xp_for_level(lv + 1) - start
    var into: int = xp - start
    return {"level": lv, "xp": xp, "into": into, "need": need, "frac": float(into) / float(need)}


func required_level(attachment_id: String) -> int:
    return int(REQUIRED.get(attachment_id, 1))


func can_use(base_name: String, attachment_id: String) -> bool:
    return get_level(base_name) >= required_level(attachment_id)


## Saves a finished run's XP. Returns display lines like "PISTOL +45 XP (LV 3 > 4)".
func record_run(run_kills: Dictionary, run_heads: Dictionary) -> Array:
    var all: Dictionary = _load_all()
    var lines: Array = []
    for gun in run_kills.keys():
        var gun_name: String = str(gun)
        if gun_name == "Unknown" or gun_name == "":
            continue
        var gained: int = int(run_kills[gun]) + int(run_heads.get(gun, 0))
        if gained <= 0:
            continue
        var old_xp: int = int(all.get(gun_name, 0))
        all[gun_name] = old_xp + gained
        var from_lv: int = level_for_xp(old_xp)
        var to_lv: int = level_for_xp(old_xp + gained)
        var line: String = "%s +%d XP  (LV %d" % [gun_name, gained, to_lv]
        if to_lv > from_lv:
            line += ", UP FROM %d" % from_lv
        line += ")"
        lines.append(line)
    if not lines.is_empty():
        _save_all(all)
    return lines

# END OF FILE
