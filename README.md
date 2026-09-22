# Jacked Undead — Godot Project Skeleton

A playable gray-box prototype for a first-person, round-based zombie
survival game. Gym-parody skin over the classic "COD Zombies" loop:

- **Perk-a-Colas → Supplements**: TRT, Creatine, Whey Protein, Pre-Workout,
  Fish Oil, BCAAs — vending machines around the map.
- **Pack-a-Punch → PR Rack**: hold the interact key to load the bar, wait
  out the timed "deadlift", then interact again to rack your upgraded weapon.
- **Wall buys → Water Stations**: pay Gains to refill reserve ammo.

## Requirements
- **Godot 4.3+** (uses `CharacterBody3D`, typed GDScript, `class_name`).

## Opening the project
1. Open Godot, click **Import**, select `project.godot` in this folder.
2. Press **F5** (or the Play button) — `scenes/main/main.tscn` is set as
   the main scene and should run immediately: floor, player, 4 zombie
   spawn points, 6 supplement stations, a PR Rack, and 2 water stations.

## Controls
| Action | Key |
|---|---|
| Move | WASD |
| Look | Mouse |
| Jump | Space |
| Sprint | Shift |
| Shoot | Left Mouse |
| Reload | R |
| Interact (buy/lift) | F |

## Project layout
```
scripts/
  player/player_controller.gd   FPS movement, shooting, health, perks
  weapons/weapon_data.gd        Resource: weapon stats + PR-upgrade logic
  zombies/zombie.gd             Base "Gym Rat" chase-and-attack AI
  zombies/roid_rager.gd         Tankier/faster special variant
  managers/game_manager.gd      Autoload: Gains currency, round number
  managers/round_manager.gd     Wave spawning, round progression
  managers/main.gd              Wires HUD to player on level load
  stations/supplement_station.gd  Perk vending machine (generic, reused)
  stations/pr_rack.gd           Pack-a-Punch equivalent
  stations/water_station.gd     Wall-buy equivalent (ammo)
  ui/hud.gd                     HUD label bindings

scenes/
  player/player.tscn
  zombies/zombie.tscn, roid_rager.tscn
  stations/supplement_station.tscn, pr_rack.tscn, water_station.tscn
  main/hud.tscn, main.tscn       <- run this one

resources/weapons/pistol.tres   Starting weapon stat block
```

## How the systems fit together
- **GameManager** (autoload singleton) holds Gains and the round number
  so any script can read/spend them without node references.
- **RoundManager** spawns zombies from `Marker3D` nodes tagged in the
  `spawn_points` group, scaling count with `GameManager.round_number`,
  and calls `GameManager.start_next_round()` once a wave is cleared.
- **Zombie** is a simple direct-chase enemy (moves straight at the
  nearest player, no navmesh) — fine for an open arena. Swap in a
  `NavigationAgent3D` + baked `NavigationRegion3D` once you build real
  level geometry with obstacles.
- **SupplementStation** is one generic script reused six times in
  `main.tscn`, each instance overriding `supplement_id` / `display_name`
  / `cost` in the Inspector — no need for six separate scripts.
- **WeaponData** is a `Resource`, so new guns are just new `.tres` files
  (duplicate `pistol.tres`, tweak the stats) — no new scripts needed.

## Building an APK via GitHub Actions
This project can't be exported to APK from the Godot Android editor itself
(the Android SDK build tooling can't run on an Android device — that's a
hard Godot limitation, not a bug here). Instead, `.github/workflows/android-export.yml`
builds a debug APK in the cloud every time you push to `main`:

1. Push this project to a GitHub repo (see the chat for step-by-step).
2. Go to the repo's **Actions** tab → **Export Android APK** → wait for the
   green checkmark (a few minutes).
3. Open the finished run → under **Artifacts**, download `jacked-undead-apk`
   → unzip it → install the `.apk` on your phone (you may need to allow
   "install from unknown sources").

This is a **debug** build signed with a throwaway keystore generated fresh
on each run — fine for testing on your own device, not for a Play Store
release. If the workflow fails on its first run, open the failed job's log;
Android export pipelines are notoriously fiddly (keystore paths, SDK
versions) and the log will point at exactly which step needs a tweak.

## Known simplifications (next steps)
- No weapon viewmodel/animations yet — shooting is a raycast from the
  camera with a muzzle flash/sound left as a TODO.
- No arena walls — the floor is a 40×40 plane the player can walk off.
  Add `StaticBody3D` boundary walls once you block out the "Globo Gym" map.
- No downed/revive state — on death the run just ends
  (`GameManager.player_died` signal, handled in `main.gd`).
- Zombie death currently just `queue_free()`s — add a ragdoll or death
  animation once you have a rigged model.
- PR Rack's "deadlift" is a simple hold-timer, not a real QTE/mash-bar —
  swap in whatever input pattern feels best once you're playtesting.
