extends CharacterBody3D
## First-person player controller: movement, shooting, ammo, health,
## perk (supplement) effects, and interacting with stations.

signal health_changed(current: float, max_hp: float)
signal ammo_changed(current_mag: int, reserve: int)
signal interact_prompt_changed(text: String)
signal perks_changed(owned: Array)

const GRAVITY: float = 9.8
const JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.0025
const GAINS_PER_HIT: int = 10  # awarded for every bullet that hits a zombie
const HEADSHOT_MULTIPLIER: float = 2.0
const STICK_LOOK_SPEED: float = 480.0  # degrees/sec of turn at full shoot-stick deflection
const HIT_MARKER_SCENE: PackedScene = preload("res://scenes/effects/hit_marker.tscn")
const STEP_HEIGHT: float = 0.35  # max ledge height the player can walk straight up (real stairs)

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

func _ready() -> void:
	add_to_group("player")
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
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
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
	if Input.is_action_pressed("sprint"):
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

	if not current_weapon:
		return

	if Input.is_action_pressed("shoot") and _fire_cooldown <= 0.0:
		if current_mag_ammo > 0:
			_fire_shot()
			_fire_cooldown = current_weapon.fire_rate
		else:
			_reload()


func _fire_shot() -> void:
	current_mag_ammo -= 1
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)

	if current_weapon.fire_sound:
		fire_sound_player.stream = current_weapon.fire_sound
		fire_sound_player.play()
	muzzle_ray.force_raycast_update()
	if muzzle_ray.is_colliding():
		var target := muzzle_ray.get_collider()
		if target and target.has_method("take_damage"):
			var damage: float = current_weapon.damage * damage_multiplier
			var is_head: bool = target.has_method("is_headshot") and target.is_headshot(muzzle_ray.get_collision_point())
			if is_head:
				damage *= HEADSHOT_MULTIPLIER
			target.take_damage(damage, self, is_head)
			if target.is_in_group("zombies"):
				GameManager.add_gains(GAINS_PER_HIT)
				_spawn_hit_marker(muzzle_ray.get_collision_point(), is_head)

## Fires a single shot right now if the weapon is ready, bypassing the
## per-frame is_action_pressed() poll. Called directly on stick touch-down
## so a fast tap can't land between two physics frames and get missed.
func fire_once_if_ready() -> void:
	if not current_weapon or _fire_cooldown > 0.0:
		return
	if current_mag_ammo > 0:
		_fire_shot()
		_fire_cooldown = current_weapon.fire_rate
	else:
		_reload()


func _spawn_hit_marker(at_position: Vector3, is_headshot: bool = false) -> void:
	var marker: Node3D = HIT_MARKER_SCENE.instantiate()
	if is_headshot and marker.has_method("set_headshot"):
		marker.set_headshot()
	get_tree().current_scene.add_child(marker)
	marker.global_position = at_position


func _reload() -> void:
	if not current_weapon:
		return
	var needed := current_weapon.mag_size - current_mag_ammo
	var available: int = min(needed, current_reserve_ammo)
	current_mag_ammo += available
	current_reserve_ammo -= available
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)


func _handle_regen(delta: float) -> void:
	if regen_per_second <= 0.0 or current_health >= max_health:
		return
	_regen_accum += regen_per_second * delta
	if _regen_accum >= 1.0:
		var whole: float = floor(_regen_accum)
		heal(whole)
		_regen_accum -= whole


func take_damage(amount: float) -> void:
	current_health = max(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		GameManager.report_player_death()


func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func add_reserve_ammo(amount: int) -> void:
	if not current_weapon:
		return
	current_reserve_ammo = min(current_reserve_ammo + amount, current_weapon.max_reserve_ammo)
	ammo_changed.emit(current_mag_ammo, current_reserve_ammo)


func equip_weapon(weapon: WeaponData) -> void:
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
## weapon's own ammo counts across switches.
func switch_weapon(direction: int = 1) -> void:
	if weapon_loadout.size() < 2:
		return

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
	if current_weapon and not current_weapon.is_pr_upgraded:
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
		if owned.weapon_name == w.weapon_name or owned.weapon_name == w.weapon_name + " - 1RM":
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
	return w != null and current_weapon != null and current_weapon.weapon_name == w.weapon_name


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
	interact_ray.force_raycast_update()
	if interact_ray.is_colliding():
		var target := interact_ray.get_collider()
		if target and target.has_method("interact"):
			target.interact(self)


func _update_interact_prompt() -> void:
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
