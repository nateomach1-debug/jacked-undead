extends RefCounted
## Attachment registry + stat application. To add an attachment: add one entry to
## ATTACHMENTS and a graphic in attachment_models.gd. The player, and later the weapon
## gallery and market, all read this. Loaded with load() + a null check.

const SLOTS: Array = ["optic", "barrel", "magazine", "grip"]

# TEST MODE: until the weapon gallery exists, every PR-upgraded gun gets this loadout.
# Set TEST_MODE to false once attachments can be equipped from the gallery.
const TEST_MODE: bool = false
const TEST_LOADOUT: Dictionary = {"optic": "red_dot", "barrel": "long_barrel", "magazine": "ext_mag", "grip": "foregrip"}

# mods (all multipliers): damage_mult, range_mult, spread_mult (lower = tighter),
# fire_rate_mult (higher = faster), mag_mult, reserve_mult, reload_speed_mult, ads_zoom_mult.
# cost = Juice price (used by the market later).
const ATTACHMENTS: Dictionary = {
	"red_dot": {"name": "Red Dot", "slot": "optic", "cost": 150, "mods": {"ads_zoom_mult": 1.15}},
	"scope_4x": {"name": "4x Scope", "slot": "optic", "cost": 400, "mods": {"ads_zoom_mult": 1.6}},
	"long_barrel": {"name": "Long Barrel", "slot": "barrel", "cost": 300, "mods": {"range_mult": 1.2, "damage_mult": 1.1, "fire_rate_mult": 0.9}},
	"suppressor": {"name": "Suppressor", "slot": "barrel", "cost": 350, "mods": {"damage_mult": 0.9, "spread_mult": 0.8}},
	"ext_mag": {"name": "Extended Mag", "slot": "magazine", "cost": 250, "mods": {"mag_mult": 1.4}},
	"fast_mag": {"name": "Fast Mag", "slot": "magazine", "cost": 250, "mods": {"reload_speed_mult": 1.25}},
	"foregrip": {"name": "Foregrip", "slot": "grip", "cost": 200, "mods": {"spread_mult": 0.75}},
	"angled_grip": {"name": "Angled Grip", "slot": "grip", "cost": 200, "mods": {"fire_rate_mult": 1.08}},
}


## The equipped attachments for a gun: {slot: id}. Saved loadout first, test loadout otherwise.
func get_loadout(base_name: String) -> Dictionary:
	var profile_script = load("res://scripts/managers/profile.gd")
	if profile_script != null:
		var profile = profile_script.new()
		var saved: Dictionary = profile.get_loadout(base_name)
		if not saved.is_empty():
			return saved
	return TEST_LOADOUT.duplicate() if TEST_MODE else {}


## Applies the gun's attachments to w (a PR-upgraded copy). Un-upgraded guns are untouched:
## attachments only work after the PR Rack.
func apply_to(w: WeaponData) -> void:
	if w == null or w.pr_level < 1:
		return
	var loadout: Dictionary = get_loadout(w.get_base_name())
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
