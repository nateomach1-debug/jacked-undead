class_name AmmoScaling
extends RefCounted
## Ammo refill price multiplier by PR level of the weapon.

const ENABLED: bool = true
const MULTIPLIERS: Array = [1.0, 5.0, 10.0, 15.0]  # PR 0, 1, 2, 3


static func multiplier(weapon) -> float:
    if not ENABLED or weapon == null:
        return 1.0
    var lvl: int = clampi(int(weapon.pr_level), 0, MULTIPLIERS.size() - 1)
    return float(MULTIPLIERS[lvl])


static func scaled(base_cost: int, weapon) -> int:
    return int(round(float(base_cost) * multiplier(weapon)))

# END OF FILE
