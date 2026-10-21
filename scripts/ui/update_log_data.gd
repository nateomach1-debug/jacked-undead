extends RefCounted
## Update log entries. To announce a new update: copy an entry block, put it
## FIRST in the list, give it the next version number, and edit the lines.

static func entries() -> Array:
    return [
        {
            "version": 3,
            "date": "OCT 19-20",
            "title": "RARITY, CUSTOM MODE AND NEW LOOKS",
            "lines": [
                "Weapon rarity: Loot Locker guns roll a rarity, and a higher rarity swaps in for a gun you own",
                "Custom game mode: toggle PR Rack, Loot Locker, rarity, attachments, supplements, wall buys, and zombie health",
                "New zombie look: rounder body, gym gear, limp, hit stagger, rising from the ground, headshot gore",
                "New Loot Locker and Water Station looks",
                "Update log (this screen)",
                "On-screen keyboard in the Name menu",
            ],
        },
        {
            "version": 2,
            "date": "OCT 16-18",
            "title": "RANDOM GYM, LEADERBOARDS AND CONTROLS",
            "lines": [
                "Random Gym map with a new layout every run",
                "Online leaderboards",
                "HUD layout editor: move and resize buttons, joystick, status items and the shoot area",
                "Controller remap, deadzones, look curve and vibration",
                "Two-weapon limit: extra guns drop on the floor with a rarity ring",
                "Ammo costs scale with PR level",
            ],
        },
        {
            "version": 1,
            "date": "OCT 8-14",
            "title": "NEW LOOKS",
            "lines": [
                "All menus restyled in the gym-poster look",
                "15 new custom reticles plus a reticle for every gun",
                "Reticle outline setting",
                "New visuals for every map",
                "New app icon",
            ],
        },
    ]

# END OF FILE
