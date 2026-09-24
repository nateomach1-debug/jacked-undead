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

@export var base_walk_speed: float = 5.0
@export var base_sprint_multiplier: float = 1.6
@export var base_max_health: float = 100.0
@export var interact_range: float = 4.5

@onready var camera: Camera3D = $Camera3D
@onready var interact_ray: RayCast3D = $Camera3D/InteractRay
@onready var muzzle_ray: RayCast3D = $Camera3D/MuzzleRay

var max_health: float = base_max_health
var current_health: float = base_max_health

# Set every frame by touch_controls.gd from the on-screen joystick.
# Vector2.ZERO means "no touch joystick input" -- keyboard/gamepad is used instead.
var touch_move_vector: Vector2 = Vector2.ZERO

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
		current_mag_ammo = current_weapon.mag_size
		current_reserve_ammo = current_weapon.max_reserve_ammo
		ammo_changed.emit(current_mag_ammo, current_reserve_ammo)
	elif current_weapon:
		current_mag_ammo = current_weapon.mag_size
		current_reserve_ammo = current_weapon.max_reserve_ammo
		ammo_changed.emit(current_mag_ammo, current_reserve_ammo)

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

	move_and_slide()


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

	muzzle_ray.force_raycast_update()
	if muzzle_ray.is_colliding():
		var target := muzzle_ray.get_collider()
		if target and target.has_method("take_damage"):
			target.take_damage(current_weapon.damage * damage_multiplier, self)
			if target.is_in_group("zombies"):
				GameManager.add_gains(GAINS_PER_HIT)

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

## Called by the PR Rack (Pack-a-Punch) station.
func apply_pr_upgrade() -> void:
	if current_weapon and not current_weapon.is_pr_upgraded:
		equip_weapon(current_weapon.get_pr_upgraded_copy())


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
