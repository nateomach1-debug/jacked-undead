extends RefCounted
## Every Loot Locker gun lives in this one file so balancing is a single
## place to edit. Each new gun uses a colored placeholder box until a real
## model exists (set model_scene on it later).
##
## Balance reference (damage per second, ignoring reloads):
##   Rifle ~233, SMG ~150, Pistol ~80. Locker guns stay under the Rifle
##   for sustained single-target damage and win on niche instead.

const FIRE_SOUND_PATH: String = "res://resources/audio/weapons/impactPlate_medium_002.ogg"

# Wall-buy guns that can also roll from the locker (weight 1 each).
const COMMON_GUN_PATHS: Array = [
	"res://resources/weapons/smg.tres",
	"res://resources/weapons/rifle.tres",
	"res://resources/weapons/crossbow.tres",
	"res://resources/weapons/sniper.tres",
]


## Returns an Array of {"weapon": WeaponData, "weight": int}.
## Higher weight = rolls more often.
static func build_pool() -> Array:
	var pool: Array = []
	for path in COMMON_GUN_PATHS:
		var w: WeaponData = load(path)
		if w:
			pool.append({"weapon": w, "weight": 1})
	pool.append({"weapon": _pump_shotgun(), "weight": 3})
	pool.append({"weapon": _double_barrel(), "weight": 3})
	pool.append({"weapon": _revolver(), "weight": 3})
	pool.append({"weapon": _magnum(), "weight": 3})
	pool.append({"weapon": _lmg(), "weight": 2})
	pool.append({"weapon": _burst_rifle(), "weight": 3})
	pool.append({"weapon": _flamethrower(), "weight": 2})
	pool.append({"weapon": _grenade_launcher(), "weight": 2})
	pool.append({"weapon": _rocket_launcher(), "weight": 1})
	return pool


static func _make(weapon_name: String, damage: float, fire_rate: float, mag: int, reserve: int, range_m: float, reload: float, size: Vector3, color: Color) -> WeaponData:
	var w := WeaponData.new()
	w.weapon_name = weapon_name
	w.damage = damage
	w.fire_rate = fire_rate
	w.mag_size = mag
	w.max_reserve_ammo = reserve
	w.range = range_m
	w.reload_time = reload
	w.placeholder_kind = weapon_name
	w.placeholder_size = size
	w.placeholder_color = color
	w.fire_sound = load(FIRE_SOUND_PATH)
	return w


# Close-range crowd control: 8 pellets x 14 = 112 point blank.
static func _pump_shotgun() -> WeaponData:
	var w := _make("Pump Shotgun", 14.0, 0.9, 6, 48, 20.0, 1.8, Vector3(0.08, 0.10, 0.8), Color(0.45, 0.3, 0.15))
	w.pellets = 8
	w.spread_degrees = 4.0
	return w


# Two huge blasts then a long reload: 10 pellets x 16 = 160 point blank.
static func _double_barrel() -> WeaponData:
	var w := _make("Double-Barrel", 16.0, 0.3, 2, 24, 15.0, 2.4, Vector3(0.09, 0.10, 0.7), Color(0.35, 0.2, 0.1))
	w.pellets = 10
	w.spread_degrees = 6.0
	return w


# Steady, accurate, good for headshots.
static func _revolver() -> WeaponData:
	return _make("Revolver", 55.0, 0.45, 6, 48, 70.0, 1.6, Vector3(0.05, 0.13, 0.3), Color(0.7, 0.7, 0.75))


# Slow heavy hitter.
static func _magnum() -> WeaponData:
	return _make("Magnum", 100.0, 0.9, 6, 36, 60.0, 2.0, Vector3(0.06, 0.15, 0.4), Color(0.15, 0.15, 0.18))


# Huge mag, lower damage per bullet, slow reload.
static func _lmg() -> WeaponData:
	var w := _make("LMG", 20.0, 0.1, 100, 300, 60.0, 3.5, Vector3(0.09, 0.12, 1.0), Color(0.25, 0.3, 0.25))
	w.spread_degrees = 1.5
	return w


# 3-round bursts, accurate at mid range. fire_rate = pause between bursts.
static func _burst_rifle() -> WeaponData:
	var w := _make("Burst Rifle", 30.0, 0.5, 30, 150, 90.0, 1.6, Vector3(0.07, 0.12, 0.85), Color(0.3, 0.35, 0.5))
	w.burst_count = 3
	w.burst_interval = 0.06
	return w


# Short range stream of fire plus burn damage over time.
static func _flamethrower() -> WeaponData:
	var w := _make("Flamethrower", 3.0, 0.05, 100, 300, 8.0, 2.5, Vector3(0.12, 0.14, 0.9), Color(0.85, 0.35, 0.1))
	w.fire_mode = WeaponData.FireMode.FLAME
	w.pellets = 3
	w.spread_degrees = 8.0
	w.burn_damage_per_second = 10.0
	w.burn_duration = 3.0
	w.gains_per_hit = 2
	return w


# Arcing splash grenade. Small self-damage if you stand too close.
static func _grenade_launcher() -> WeaponData:
	var w := _make("Grenade Launcher", 150.0, 1.2, 4, 20, 60.0, 2.5, Vector3(0.1, 0.14, 0.7), Color(0.3, 0.45, 0.25))
	w.fire_mode = WeaponData.FireMode.EXPLOSIVE
	w.splash_radius = 5.0
	w.projectile_speed = 20.0
	w.projectile_gravity = 9.8
	w.self_damage_multiplier = 0.2
	return w


# The jackpot: huge straight-flying blast, very little ammo.
static func _rocket_launcher() -> WeaponData:
	var w := _make("Rocket Launcher", 400.0, 2.0, 1, 6, 80.0, 3.0, Vector3(0.14, 0.14, 1.1), Color(0.5, 0.15, 0.15))
	w.fire_mode = WeaponData.FireMode.EXPLOSIVE
	w.splash_radius = 7.0
	w.projectile_speed = 32.0
	w.projectile_gravity = 0.0
	w.self_damage_multiplier = 0.2
	return w
