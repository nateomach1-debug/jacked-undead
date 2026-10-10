extends RefCounted
## Newer Loot Locker guns (4-space file). locker_weapons.gd appends these to its pool.
## Stats: damage, fire_rate, mag, reserve, range, reload, spread.

const FIRE_SOUND_PATH: String = "res://resources/audio/weapons/impactPlate_medium_002.ogg"


## Returns an Array of {"weapon": WeaponData, "weight": int}.
static func build_pool() -> Array:
    return [
        {"weapon": _tactical_45(), "weight": 3},
        {"weapon": _speed_revolver(), "weight": 3},
        {"weapon": _hand_cannon(), "weight": 2},
    ]


static func _make(weapon_name: String, damage: float, fire_rate: float, mag: int, reserve: int, range_m: float, reload: float, spread: float, size: Vector3, color: Color) -> WeaponData:
    var w := WeaponData.new()
    w.weapon_name = weapon_name
    w.damage = damage
    w.fire_rate = fire_rate
    w.mag_size = mag
    w.max_reserve_ammo = reserve
    w.range = range_m
    w.reload_time = reload
    w.placeholder_kind = weapon_name
    w.spread_degrees = spread
    w.placeholder_size = size
    w.placeholder_color = color
    w.fire_sound = load(FIRE_SOUND_PATH)
    return w


static func _tactical_45() -> WeaponData:
    return _make("Tactical .45", 28.0, 0.28, 10, 80, 55.0, 1.3, 0.4, Vector3(0.05, 0.12, 0.3), Color(0.1, 0.1, 0.12))


static func _speed_revolver() -> WeaponData:
    return _make("Speed Revolver", 28.0, 0.22, 6, 60, 50.0, 1.2, 0.8, Vector3(0.05, 0.12, 0.25), Color(0.9, 0.45, 0.1))


static func _hand_cannon() -> WeaponData:
    return _make("Hand Cannon", 160.0, 1.3, 4, 24, 55.0, 2.6, 0.4, Vector3(0.07, 0.16, 0.4), Color(0.8, 0.8, 0.85))
