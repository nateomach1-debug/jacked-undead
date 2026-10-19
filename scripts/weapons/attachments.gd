extends RefCounted
## Attachment registry + stat application. To add an attachment: add one entry to
## ATTACHMENTS and a graphic in attachment_models.gd. The player, and later the weapon
## gallery and market, all read this. Loaded with load() + a null check.
## Weapon level requirements live in weapon_levels.gd (REQUIRED).

const SLOTS: Array = ["optic", "barrel", "magazine", "grip"]

# TEST MODE: every gun gets this loadout when none is saved. Keep false.
const TEST_MODE: bool = false
const TEST_LOADOUT: Dictionary = {"optic": "red_dot", "barrel": "long_barrel", "magazine": "ext_mag", "grip": "foregrip"}

# mods (all multipliers): damage_mult, range_mult, spread_mult (lower = tighter),
# fire_rate_mult (higher = faster), mag_mult, reserve_mult, reload_speed_mult, ads_zoom_mult.
# cost = Juice price (used by the market).
const ATTACHMENTS: Dictionary = {
    "red_dot": {"name": "Red Dot", "slot": "optic", "cost": 150, "mods": {"ads_zoom_mult": 1.15}},
    "holo": {"name": "Holo Sight", "slot": "optic", "cost": 300, "mods": {"ads_zoom_mult": 1.25}},
    "scope_4x": {"name": "4x Scope", "slot": "optic", "cost": 400, "mods": {"ads_zoom_mult": 1.6}},
    "scope_8x": {"name": "8x Scope", "slot": "optic", "cost": 800, "mods": {"ads_zoom_mult": 2.4, "fire_rate_mult": 0.95}},
    "long_barrel": {"name": "Long Barrel", "slot": "barrel", "cost": 300, "mods": {"range_mult": 1.2, "damage_mult": 1.1, "fire_rate_mult": 0.9}},
    "suppressor": {"name": "Suppressor", "slot": "barrel", "cost": 350, "mods": {"damage_mult": 0.9, "spread_mult": 0.8}},
    "compensator": {"name": "Compensator", "slot": "barrel", "cost": 300, "mods": {"spread_mult": 0.85, "fire_rate_mult": 1.05}},
    "heavy_barrel": {"name": "Heavy Barrel", "slot": "barrel", "cost": 450, "mods": {"damage_mult": 1.2, "fire_rate_mult": 0.85, "spread_mult": 1.1}},
    "ext_mag": {"name": "Extended Mag", "slot": "magazine", "cost": 250, "mods": {"mag_mult": 1.4}},
    "fast_mag": {"name": "Fast Mag", "slot": "magazine", "cost": 250, "mods": {"reload_speed_mult": 1.25}},
    "drum_mag": {"name": "Drum Mag", "slot": "magazine", "cost": 450, "mods": {"mag_mult": 1.8, "reload_speed_mult": 0.8}},
    "ammo_pouch": {"name": "Ammo Pouch", "slot": "magazine", "cost": 300, "mods": {"reserve_mult": 1.5}},
    "foregrip": {"name": "Foregrip", "slot": "grip", "cost": 200, "mods": {"spread_mult": 0.75}},
    "angled_grip": {"name": "Angled Grip", "slot": "grip", "cost": 200, "mods": {"fire_rate_mult": 1.08}},
    "vertical_grip": {"name": "Vertical Grip", "slot": "grip", "cost": 250, "mods": {"spread_mult": 0.7, "fire_rate_mult": 0.95}},
    "ergo_grip": {"name": "Ergo Grip", "slot": "grip", "cost": 250, "mods": {"reload_speed_mult": 1.15, "spread_mult": 0.9}},
}


## The equipped attachments for a gun: {slot: id}. Saved loadout (minus anything the
## gun's level hasn't unlocked yet) first, test loadout otherwise.
func get_loadout(base_name: String) -> Dictionary:
    var profile_script = load("res://scripts/managers/profile.gd")
    if profile_script != null:
        var profile = profile_script.new()
        var saved: Dictionary = profile.get_loadout(base_name)
        if not saved.is_empty():
            return _level_filtered(base_name, saved)
    return TEST_LOADOUT.duplicate() if TEST_MODE else {}


## Drops saved attachments the gun's level hasn't reached.
func _level_filtered(base_name: String, loadout: Dictionary) -> Dictionary:
    var script = load("res://scripts/managers/weapon_levels.gd")
    if script == null:
        return loadout
    var wl = script.new()
    var level: int = wl.get_level(base_name)
    var out: Dictionary = {}
    for slot in loadout.keys():
        var id: String = str(loadout[slot])
        if level >= wl.required_level(id):
            out[slot] = id
    return out


## PR Rack roll: every slot the player left empty gets a random attachment from ALL
## attachments of that slot (ignores ownership and level). Chosen slots are untouched.
## Rolled fresh on every PR Rack use and never saved.
func _with_random_slots(chosen: Dictionary) -> Dictionary:
    var out: Dictionary = chosen.duplicate()
    for slot in SLOTS:
        if str(out.get(slot, "")) != "":
            continue
        var pool: Array = []
        for id in ATTACHMENTS.keys():
            if str(ATTACHMENTS[id]["slot"]) == slot:
                pool.append(str(id))
        if not pool.is_empty():
            out[slot] = pool[randi() % pool.size()]
    return out


## PR Rack: applies the chosen attachments + random ones for empty slots to a freshly
## PR-upgraded copy.
func apply_to(w: WeaponData) -> void:
    if w == null or w.pr_level < 1:
        return
    _apply_loadout(w, _with_random_slots(get_loadout(w.get_base_name())))


## For guns that are not PR-upgraded: a copy of w with the player's chosen attachments
## applied. w itself is never changed. Returns w if nothing is chosen. The copy remembers
## the original in meta "attach_base" so a later PR upgrade starts from the original
## stats (bonuses never stack twice).
func attached_copy(w: WeaponData) -> WeaponData:
    if w == null or w.pr_level > 0 or w.pr_base != null or w.has_meta("attach_base"):
        return w
    var loadout: Dictionary = get_loadout(w.get_base_name())
    if loadout.is_empty():
        return w
    var c: WeaponData = w.duplicate() as WeaponData
    if c == null:
        return w
    c.set_meta("attach_base", w)
    _apply_loadout(c, loadout)
    return c


func _apply_loadout(w: WeaponData, loadout: Dictionary) -> void:
    var total: Dictionary = {
        "damage_mult": 1.0, "range_mult": 1.0, "spread_mult": 1.0, "fire_rate_mult": 1.0,
        "mag_mult": 1.0, "reserve_mult": 1.0, "reload_speed_mult": 1.0, "ads_zoom_mult": 1.0,
    }
    var applied: Dictionary = {}
    for slot in SLOTS:
        var id: String = str(loadout.get(slot, ""))
        if id == "" or not ATTACHMENTS.has(id):
            continue
        var entry: Dictionary = ATTACHMENTS[id]
        if str(entry["slot"]) != slot:
            continue
        applied[slot] = id
        var mods: Dictionary = entry["mods"]
        for key in mods.keys():
            total[key] = float(total.get(key, 1.0)) * float(mods[key])
    if applied.is_empty():
        return

    w.damage *= total["damage_mult"]
    w.burn_damage_per_second *= total["damage_mult"]
    w.range *= total["range_mult"]
    w.spread_degrees *= total["spread_mult"]
    w.fire_rate /= maxf(total["fire_rate_mult"], 0.1)       # fire_rate is the gap between shots
    w.burst_interval /= maxf(total["fire_rate_mult"], 0.1)
    w.mag_size = maxi(1, int(round(w.mag_size * total["mag_mult"])))
    w.max_reserve_ammo = maxi(0, int(round(w.max_reserve_ammo * total["reserve_mult"])))
    if w.reload_time > 0.0:
        w.reload_time /= maxf(total["reload_speed_mult"], 0.1)
    w.set_meta("attachments", applied)
    w.set_meta("ads_zoom_mult", total["ads_zoom_mult"])

# END OF FILE
