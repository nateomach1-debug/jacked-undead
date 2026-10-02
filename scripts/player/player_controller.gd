extends CharacterBody3D
## First-person player controller: movement, shooting, ammo, health,
## perk (supplement) effects, and interacting with stations.

signal health_changed(current: float, max_hp: float)
signal ammo_changed(current_mag: int, reserve: int)
signal interact_prompt_changed(text: String)
signal perks_changed(owned: Array)
signal stamina_changed(current: float, max_stamina: float)

const STAMINA_MAX: float = 100.0
const STAMINA_DRAIN: float = 25.0        # per second while sprinting (4s of sprint)
const STAMINA_REGEN: float = 18.0        # per second while not sprinting
const STAMINA_REGEN_DELAY: float = 1.0   # seconds after sprinting before regen starts
const STAMINA_RECOVER_AT: float = 30.0   # after hitting 0, refill to this before sprinting again

var stamina: float = STAMINA_MAX
var max_stamina: float = STAMINA_MAX
var _stamina_delay: float = 0.0
var _stamina_exhausted: bool = false
var _last_stamina_sent: float = -1.0
const GRAVITY: float = 9.8
const JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.0025
const GAINS_PER_HIT: int = 10  # default; each WeaponData now has its own gains_per_hit
const HEADSHOT_MULTIPLIER: float = 2.0
const STICK_LOOK_SPEED: float = 480.0  # degrees/sec of turn at full shoot-stick deflection
const HIT_MARKER_SCENE: PackedScene = preload("res://scenes/effects/hit_marker.tscn")
const STEP_HEIGHT: float = 0.35  # max ledge height the player can walk straight up (real stairs)
const SHOT_MASK: int = 1 | 4     # world + zombies, same as the old muzzle ray
const DOWNED_SPEED_FACTOR: float = 0.3  # crawl speed while downed (co-op)
# Loaded only when needed, so a problem in these can never break the player itself.
const BURN_EFFECT_PATH: String = "res://scripts/effects/burn_effect.gd"
const PROJECTILE_PATH: String = "res://scripts/weapons/projectile.gd"
const DAMAGE_INDICATOR_PATH: String = "res://scripts/ui/damage_indicator.gd"
const DOWNED_STATE_PATH: String = "res://scripts/player/downed_state.gd"

@export var base_walk_speed: float = 5.0
@export var base_sprint_multiplier: float = 1.6
@export var base_max_health: float = 100.0
@export var interact_range: float = 4.5

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var muzzle_ray: RayCast3D = $Camera3D/MuzzleRay
@onready var weapon_mount: Node3D = $Camera3D/WeaponMount
@onready var fire_sound_player: AudioStreamPlayer = $FireSound

var _current_model: Node3D

var max_health: float = base_max_health
var current_health: float = base_max_health

# Set every frame by touch_controls.gd from the on-screen joystick.
# Vector2.ZERO means "no touch joystick input" -- keyboard/gamepad is used instead.
var touch_move_vector: Vector2 = Vector2.ZERO

# Set every frame by touch_controls.gd from the shoot-stick. Vector2.ZERO
# means the stick is centered/untouched -- drag-to-look still works normally.
var stick_look_vector: Vector2 = Vector2.ZERO

# --- Supplement (perk) state ---
var damage_multiplier: float = 1.0      # TRT
var speed_multiplier: float = 1.0       # Creatine
var melee_multiplier: float = 1.0       # Creatine
var reload_speed_multiplier: float = 1.0 # Pre-Workout
var regen_per_second: float = 0.0       # Fish Oil
var infinite_stamina: bool = false      # BCAAs
var owned_perks: Array = []             # supplement ids purchased so far, for the HUD perk bar

# --- Co-op downed state (driven by downed_state.gd) ---
var is_downed: bool = false             # at 0 HP in co-op: crawling, pistol only
var is_dead: bool = false               # bled out: spectating until the next round
var downed_bleed_left: float = 0.0
var downed_revive_progress: float = 0.0
var _downed_state: Node = null

# --- Weapon / ammo state ---
@export var current_weapon: WeaponData  # fallback single starting gun if weapon_loadout is empty
@export var weapon_loadout: Array = []  # assign multiple WeaponData .tres here to enable weapon switching
var current_weapon_index: int = 0
var current_mag_ammo: int = 0
var current_reserve_ammo: int = 0
var _saved_mag_ammo: Array = []
var _saved_reserve_ammo: Array = []
var owned_weapon_names: Array = []  # base weapon_name of each gun ever bought, for wall-buy stations
var _fire_cooldown: float = 0.0
var _regen_accum: float = 0.0

# Timed reload + burst state
var _reloading: bool = false
var _reload_timer: float = 0.0
var _burst_left: int = 0
var _burst_timer: float = 0.0
var _damage_indicator: Node = null
var _flame_marker_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("player")
	var indicator_script = load(DAMAGE_INDICATOR_PATH)
	if indicator_script:
		_damage_indicator = indicator_script.new()
		if _damage_indicator:
			add_child(_damage_indicator)
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	max_health = base_max_health
	current_health = max_health
	health_changed.emit(current_health, max_health)

	interact_ray.collide_with_areas = true
	interact_ray.collide_with_bodies = false
	interact_ray.collision_mask = 2   # stations live on layer 2
	interact_ray.target_position = Vector3(0, 0, -interact_range)

	muzzle_ray.collision_mask = 1 | 4  # world (layer 1) + zombies (layer 4)

	if not weapon_loadout.is_empty():
		current_weapon_index = 0
		current_weapon = weapon_loadout[0]
		_saved_mag_ammo.clear()
		_saved_reserve_ammo.clear()
		for w in weapon_loadout:
			_saved_mag_ammo.append(w.mag_size)
			_saved_reserve_ammo.append(w.max_reserve_ammo)
			if w.weapon_name not in owned_weapon_names:
				owned_weapon_names.append(w.weapon_name)
		current_mag_ammo = current_weapon.mag_size
		current_reserve_ammo = current_weapon.max_reserve_ammo
		ammo_changed.emit(current_mag_ammo, current_reserve_ammo)
		_update_weapon_model()
	elif current_weapon:
		current_mag_ammo = current_weapon.mag_size
		current_reserve_ammo = current_weapon.max_reserve_ammo
		ammo_changed.emit(current_mag_ammo, current_reserve_ammo)
		_update_weapon_model()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		apply_look_delta(event.relative, MOUSE_SENSITIVITY)


func apply_look_delta(delta: Vector2, sensitivity: float = MOUSE_SENSITIVITY) -> void:
	rotate_y(-delta.x * sensitivity)
	camera.rotate_x(-delta.y * sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_handle_shooting(delta)
	_handle_regen(delta)
	_update_interact_prompt()

	if stick_look_vector.length() > 0.01:
		rotate_y(-stick_look_vector.x * deg_to_rad(STICK_LOOK_SPEED) * delta)
		camera.rotate_x(-stick_look_vector.y * deg_to_rad(STICK_LOOK_SPEED) * delta)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if Input.is_action_just_pressed("reload"):
		_reload()

	if Input.is_action_just_pressed("interact"):
		_try_interact()


func _handle_movement(delta: float) -> void:
	# Bled out in co-op: no body movement, downed_state.gd carries us along.
	if is_dead:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump") and not is_downed:
		velocity.y = JUMP_VELOCITY

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if touch_move_vector.length() > 0.01:
		input_dir = touch_move_vector

	var raw_dir := Vector3(input_dir.x, 0, input_dir.y)
	if raw_dir.length() > 1.0:
		raw_dir = raw_dir.normalized()
	var direction := transform.basis * raw_dir
	var speed := base_walk_speed * speed_multiplier
	if is_downed:
		speed = base_walk_speed * DOWNED_SPEED_FACTOR
	elif _wants_sprint(delta, direction):
		speed *= base_sprint_multiplier

	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	_step_up_if_blocked(delta)
	move_and_slide()


## CharacterBody3D has no built-in stair-climbing: a step taller than a
## tiny lip acts like a wall. If moving forward this frame would hit
## something, and stepping up by STEP_HEIGHT would clear it, nudge the
## body up first so move_and_slide() carries it up and over instead of
## stopping dead. Leaves genuine walls (still blocked even after the
## step up) alone.
func _step_up_if_blocked(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0, velocity.z) * delta
	if motion.length() < 0.001:
		return
	if not test_move(global_transform, motion):
		return
	var raised_transform := global_transform
	raised_transform.origin += Vector3(0, STEP_HEIGHT, 0)
	if test_move(raised_transform, motion):
		return  # still blocked even raised -- a real wall, not a step
	global_position.y += STEP_HEIGHT


func _handle_shooting(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	_flame_marker_cooldown = maxf(_flame_marker_cooldown - delta, 0.0)

	if is_dead:
		return

	# Timed reload: no shooting until it finishes.
	if _reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	if not current_weapon:
		return

	# Rounds 2..N of a burst fire on their own, no input needed.
	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			if current_mag_ammo > 0:
				_fire_shot()
				_burst_left -= 1
				_burst_timer = current_weapon.burst_interval
				if _burst_left == 0:
					_fire_cooldown = current_weapon.fire_rate
			else:
				_burst_left = 0
				_fire_cooldown = current_weapon.fire_rate
		return

	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		_try_trigger()


## One trigger pull: fires the first (or only) round, sets up the rest of
## a burst if the weapon has one, or auto-reloads if the mag is empty.
func _try_trigger() -> void:
	if current_mag_ammo > 0:
		_fire_shot()
		if current_weapon.burst_count > 1:
			_burst_left = current_weapon.burst_count - 1
			_burst_timer = current_weapon.burst_interval
		else:
			_fire_cooldown = current_weapon.fire_rate
	else:
		_reload()


func _fire_shot() -> void:
	current_mag_ammo -= 1
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)

	if current_weapon.fire_sound:
		fire_sound_player.stream = current_weapon.fire_sound
		fire_sound_player.play()

	if current_weapon.fire_mode == WeaponData.FireMode.EXPLOSIVE:
		_launch_projectile()
		return

	# Cast every pellet, then add the damage up per target so each zombie
	# takes ONE take_damage() call per shot (no double-kill / double-pay).
	var base_damage: float = current_weapon.damage * damage_multiplier
	var hits: Dictionary = {}
	for i in range(maxi(current_weapon.pellets, 1)):
		var direction: Vector3 = _spread_direction(current_weapon.spread_degrees)
		var result: Dictionary = _cast_ray(direction, current_weapon.range)
		if result.is_empty():
			continue
		var target = result["collider"]
		if target == null or not target.has_method("take_damage"):
			continue
		var point: Vector3 = result["position"]
		var pellet_head: bool = target.has_method("is_headshot") and target.is_headshot(point)
		var pellet_damage: float = base_damage
		if pellet_head:
			pellet_damage *= HEADSHOT_MULTIPLIER
		if not hits.has(target):
			hits[target] = {"damage": 0.0, "hits": 0, "head_hits": 0, "point": point}
		var info: Dictionary = hits[target]
		info["damage"] = float(info["damage"]) + pellet_damage
		info["hits"] = int(info["hits"]) + 1
		if pellet_head:
			info["head_hits"] = int(info["head_hits"]) + 1
			info["point"] = point

	var show_markers: bool = current_weapon.fire_mode != WeaponData.FireMode.FLAME or _flame_marker_cooldown <= 0.0
	if show_markers and current_weapon.fire_mode == WeaponData.FireMode.FLAME:
		_flame_marker_cooldown = 0.2
	for victim in hits.keys():
		if not is_instance_valid(victim):
			continue
		var victim_info: Dictionary = hits[victim]
		# Counts as a headshot if at least half the pellets that landed were head hits.
		var is_head: bool = int(victim_info["head_hits"]) * 2 >= int(victim_info["hits"])
		victim.take_damage(float(victim_info["damage"]), self, is_head)
		if victim.is_in_group("zombies"):
			GameManager.add_gains(current_weapon.gains_per_hit)
			if show_markers:
				_spawn_hit_marker(victim_info["point"], is_head)
			if current_weapon.burn_damage_per_second > 0.0 and is_instance_valid(victim):
				_apply_burn(victim)


## Random direction inside a cone around where the camera is looking.
func _spread_direction(spread_deg: float) -> Vector3:
	var b: Basis = camera.global_transform.basis
	var forward: Vector3 = -b.z
	if spread_deg <= 0.0:
		return forward
	var spread: float = deg_to_rad(spread_deg)
	forward = forward.rotated(b.y, randf_range(-spread, spread))
	forward = forward.rotated(b.x, randf_range(-spread, spread))
	return forward.normalized()


## Straight ray from the camera; respects the weapon's range.
func _cast_ray(direction: Vector3, max_range: float) -> Dictionary:
	var from: Vector3 = camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * max_range, SHOT_MASK)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


func _apply_burn(target: Node) -> void:
	var burn_dps: float = current_weapon.burn_damage_per_second * damage_multiplier
	var existing = target.get_node_or_null("BurnEffect")
	if existing:
		existing.refresh(burn_dps, current_weapon.burn_duration)
		return
	var burn_script = load(BURN_EFFECT_PATH)
	if burn_script == null:
		return
	var burn = burn_script.new()
	burn.name = "BurnEffect"
	target.add_child(burn)
	burn.setup(self, burn_dps, current_weapon.burn_duration)


func _launch_projectile() -> void:
	var projectile_script = load(PROJECTILE_PATH)
	if projectile_script == null:
		return
	var forward: Vector3 = _spread_direction(current_weapon.spread_degrees)
	var proj = projectile_script.new()
	get_tree().current_scene.add_child(proj)
	proj.global_position = camera.global_position + forward * 0.3
	proj.launch(
		self,
		forward * current_weapon.projectile_speed,
		current_weapon.projectile_gravity,
		current_weapon.damage * damage_multiplier,
		current_weapon.splash_radius,
		current_weapon.self_damage_multiplier,
		current_weapon.gains_per_hit
	)


## Fires a single shot right now if the weapon is ready, bypassing the
## per-frame is_action_pressed() poll. Called directly on stick touch-down
## so a fast tap can't land between two physics frames and get missed.
func fire_once_if_ready() -> void:
	if is_dead or not current_weapon or _fire_cooldown > 0.0 or _reloading or _burst_left > 0:
		return
	_try_trigger()


func _spawn_hit_marker(at_position: Vector3, is_headshot: bool = false) -> void:
	var marker: Node3D = HIT_MARKER_SCENE.instantiate()
	if is_headshot and marker.has_method("set_headshot"):
		marker.set_headshot()
	get_tree().current_scene.add_child(marker)
	marker.global_position = at_position


## Starts a reload. Guns with reload_time = 0 refill instantly (the old
## behaviour); others take reload_time seconds (faster with Pre-Workout).
func _reload() -> void:
	if not current_weapon or _reloading:
		return
	var needed: int = current_weapon.mag_size - current_mag_ammo
	if needed <= 0 or current_reserve_ammo <= 0:
		return
	if current_weapon.reload_time <= 0.0:
		_finish_reload()
		return
	_reloading = true
	_reload_timer = current_weapon.reload_time / maxf(reload_speed_multiplier, 0.1)


func _finish_reload() -> void:
	_reloading = false
	if not current_weapon:
		return
	var needed: int = current_weapon.mag_size - current_mag_ammo
	var available: int = min(needed, current_reserve_ammo)
	current_mag_ammo += available
	current_reserve_ammo -= available
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)


## Stops any in-progress reload or burst (weapon swapped, new gun, etc).
func _cancel_actions() -> void:
	_reloading = false
	_burst_left = 0


func _handle_regen(delta: float) -> void:
	if regen_per_second <= 0.0 or current_health >= max_health:
		return
	_regen_accum += regen_per_second * delta
	if _regen_accum >= 1.0:
		var whole: float = floor(_regen_accum)
		heal(whole)
		_regen_accum -= whole


func take_damage(amount: float, from_position: Vector3 = Vector3.INF) -> void:
	if is_downed or is_dead:
		return  # a downed or bled-out player can't be hurt further
	_show_damage_indicator(amount, from_position)
	current_health = max(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		# Co-op: go down instead of dying. Solo (or if the script is missing): game over.
		if NetManager.is_online and _go_down():
			return
		GameManager.report_player_death()


## Co-op: hands over to downed_state.gd. Returns false if that script can't load.
func _go_down() -> bool:
	if _downed_state == null:
		var state_script = load(DOWNED_STATE_PATH)
		if state_script == null:
			return false
		_downed_state = state_script.new()
		add_child(_downed_state)
		_downed_state.setup(self)
	_downed_state.go_down()
	return true


## Co-op downed penalty (called by downed_state.gd): lose all supplements and
## every gun except the pistol (slot 1) and your second gun (slot 2), both
## back at base level with no PR upgrades. You hold the pistol while downed.
func strip_for_downed() -> void:
	_cancel_actions()
	clear_supplements()
	owned_perks.clear()
	perks_changed.emit(owned_perks)
	if weapon_loadout.is_empty():
		return
	var keep: Array = []
	for i in range(mini(2, weapon_loadout.size())):
		var kept: WeaponData = weapon_loadout[i]
		if kept.pr_base != null:
			kept = kept.pr_base
		keep.append(kept)
	weapon_loadout = keep
	owned_weapon_names.clear()
	_saved_mag_ammo.clear()
	_saved_reserve_ammo.clear()
	for w in weapon_loadout:
		owned_weapon_names.append(w.weapon_name)
		_saved_mag_ammo.append(w.mag_size)
		_saved_reserve_ammo.append(w.max_reserve_ammo)
	current_weapon_index = 0
	current_weapon = weapon_loadout[0]
	current_mag_ammo = current_weapon.mag_size
	current_reserve_ammo = current_weapon.max_reserve_ammo
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)
	_update_weapon_model()


## Tells the red damage indicator which way the hit came from. If the
## attacker's position isn't passed in, the closest zombie counts as the source.
func _show_damage_indicator(amount: float, from_position: Vector3) -> void:
	if _damage_indicator == null or amount <= 0.0:
		return
	var source: Vector3 = from_position
	var has_source: bool = from_position.is_finite()
	if not has_source:
		var best_dist: float = 4.5
		for z in get_tree().get_nodes_in_group("zombies"):
			var zombie := z as Node3D
			if zombie == null or not is_instance_valid(zombie):
				continue
			var d: float = zombie.global_position.distance_to(global_position)
			if d < best_dist:
				best_dist = d
				source = zombie.global_position
				has_source = true
	var angle: float = 0.0
	if has_source:
		var local_pos: Vector3 = global_transform.affine_inverse() * source
		angle = atan2(local_pos.x, -local_pos.z)
	_damage_indicator.show_hit(angle, has_source)


func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func add_reserve_ammo(amount: int) -> void:
	if not current_weapon:
		return
	current_reserve_ammo = min(current_reserve_ammo + amount, current_weapon.max_reserve_ammo)
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)


func equip_weapon(weapon: WeaponData) -> void:
	_cancel_actions()
	current_weapon = weapon
	current_mag_ammo = weapon.mag_size
	current_reserve_ammo = weapon.max_reserve_ammo
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)
	_update_weapon_model()
	if current_weapon_index < weapon_loadout.size():
		weapon_loadout[current_weapon_index] = weapon
		if current_weapon_index < _saved_mag_ammo.size():
			_saved_mag_ammo[current_weapon_index] = current_mag_ammo
			_saved_reserve_ammo[current_weapon_index] = current_reserve_ammo


## Cycles to the next (or previous, with direction = -1) weapon in
## weapon_loadout. Called by the on-screen SWAP button. Remembers each
## weapon's own ammo counts across switches. Blocked while downed (pistol only).
func switch_weapon(direction: int = 1) -> void:
	if is_downed or is_dead:
		return
	if weapon_loadout.size() < 2:
		return

	_cancel_actions()

	if current_weapon_index < _saved_mag_ammo.size():
		_saved_mag_ammo[current_weapon_index] = current_mag_ammo
		_saved_reserve_ammo[current_weapon_index] = current_reserve_ammo

	current_weapon_index = wrapi(current_weapon_index + direction, 0, weapon_loadout.size())
	current_weapon = weapon_loadout[current_weapon_index]
	current_mag_ammo = _saved_mag_ammo[current_weapon_index]
	current_reserve_ammo = _saved_reserve_ammo[current_weapon_index]
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)
	_update_weapon_model()


## Called by the PR Rack (Pack-a-Punch) station.
func apply_pr_upgrade() -> void:
	if current_weapon and current_weapon.pr_level < WeaponData.PR_MAX_LEVEL:
		equip_weapon(current_weapon.get_pr_upgraded_copy())


## True once this weapon (by base name, so PR-upgraded copies still
## count) has ever been bought. Used by wall-buy stations to decide
## between "buy" and "refill ammo".
func has_weapon(w: WeaponData) -> bool:
	return w != null and w.weapon_name in owned_weapon_names


## Called by a GunWallBuy station the first time that gun is purchased.
## Adds it to the loadout and immediately equips it.
func add_weapon_to_loadout(w: WeaponData) -> void:
	if has_weapon(w):
		return
	_cancel_actions()
	owned_weapon_names.append(w.weapon_name)
	weapon_loadout.append(w)
	_saved_mag_ammo.append(w.mag_size)
	_saved_reserve_ammo.append(w.max_reserve_ammo)
	current_weapon_index = weapon_loadout.size() - 1
	current_weapon = w
	current_mag_ammo = w.mag_size
	current_reserve_ammo = w.max_reserve_ammo
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)
	_update_weapon_model()


## Called by the Loot Locker. A gun you don't own is added and equipped;
## a gun you already own (including its PR-upgraded copy) gets a full refill.
func grant_weapon(w: WeaponData) -> void:
	if w == null:
		return
	if not has_weapon(w):
		add_weapon_to_loadout(w)
		return
	for i in range(weapon_loadout.size()):
		var owned: WeaponData = weapon_loadout[i]
		if owned.get_base_name() == w.get_base_name():
			if i == current_weapon_index:
				current_mag_ammo = owned.mag_size
				current_reserve_ammo = owned.max_reserve_ammo
				ammo_changed.emit(current_mag_ammo, current_reserve_ammo)
			elif i < _saved_mag_ammo.size():
				_saved_mag_ammo[i] = owned.mag_size
				_saved_reserve_ammo[i] = owned.max_reserve_ammo
			return


## True if w (by base name) is the weapon currently in the player's hands.
func is_current_weapon(w: WeaponData) -> bool:
	return w != null and current_weapon != null and current_weapon.get_base_name() == w.get_base_name()


## Called by a GunWallBuy station on repeat visits. Only ever touches
## the currently-equipped weapon's reserve ammo -- the station itself
## checks is_current_weapon() first, so this should never be called
## for a gun that isn't the one you're holding.
func add_ammo_to_current_weapon(amount: int) -> void:
	if not current_weapon:
		return
	current_reserve_ammo = min(current_reserve_ammo + amount, current_weapon.max_reserve_ammo)
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)


## Swaps the visible first-person model to match current_weapon. Call this
## anywhere current_weapon changes (initial equip, PR upgrade, switching).
func _update_weapon_model() -> void:
	if _current_model:
		_current_model.queue_free()
		_current_model = null
	if current_weapon:
		var model: Node3D = current_weapon.create_model()
		if model:
			_current_model = model
			weapon_mount.add_child(_current_model)
			if not current_weapon.model_scene:
				# Placeholder guns are built pointing straight ahead, so cancel the mount's rotation
				_current_model.transform.basis = weapon_mount.transform.basis.orthonormalized().inverse()


func _try_interact() -> void:
	if is_downed or is_dead:
		return
	interact_ray.force_raycast_update()
	if interact_ray.is_colliding():
		var target := interact_ray.get_collider()
		if target and target.has_method("interact"):
			target.interact(self)


func _update_interact_prompt() -> void:
	if is_downed or is_dead:
		interact_prompt_changed.emit("")
		return
	interact_ray.force_raycast_update()
	if interact_ray.is_colliding():
		var target := interact_ray.get_collider()
		if target and target.has_method("get_prompt_text"):
			interact_prompt_changed.emit(target.get_prompt_text())
			return
	interact_prompt_changed.emit("")


# --- Supplement (perk-a-cola) effect hooks, called by SupplementStation ---
func apply_supplement(id: String) -> void:
	match id:
		"trt":
			damage_multiplier = 1.5
		"creatine":
			speed_multiplier = 1.25
			melee_multiplier = 2.0
		"whey":
			max_health = base_max_health * 1.5
			current_health = max_health
			health_changed.emit(current_health, max_health)
		"pre_workout":
			reload_speed_multiplier = 1.5
		"fish_oil":
			regen_per_second = 2.0
		"bcaas":
			infinite_stamina = true

	if id not in owned_perks:
		owned_perks.append(id)
		perks_changed.emit(owned_perks)


## Called on death (or by a future "downed" system) to strip perks,
## mirroring the classic "lose your perks when you go down" rule.
func clear_supplements() -> void:
	damage_multiplier = 1.0
	speed_multiplier = 1.0
	melee_multiplier = 1.0
	reload_speed_multiplier = 1.0
	regen_per_second = 0.0
	infinite_stamina = false
	max_health = base_max_health
	current_health = max_health


func _wants_sprint(delta: float, direction: Vector3) -> bool:
	var wants: bool = Input.is_action_pressed("sprint") and direction.length() > 0.1
	if infinite_stamina:
		_set_stamina(max_stamina)
		_stamina_exhausted = false
		return wants
	if wants and not _stamina_exhausted:
		_set_stamina(stamina - STAMINA_DRAIN * delta)
		_stamina_delay = STAMINA_REGEN_DELAY
		if stamina <= 0.0:
			_stamina_exhausted = true
		return true
	if _stamina_delay > 0.0:
		_stamina_delay -= delta
	else:
		_set_stamina(stamina + STAMINA_REGEN * delta)
		if _stamina_exhausted and stamina >= STAMINA_RECOVER_AT:
			_stamina_exhausted = false
	return false


func _set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina)
	if stamina != _last_stamina_sent:
		_last_stamina_sent = stamina
		stamina_changed.emit(stamina, max_stamina)
