extends CanvasLayer

@onready var health_label: Label = $Margin/VBox/HealthLabel
@onready var ammo_label: Label = $Margin/VBox/AmmoLabel
@onready var weapon_label: Label = $Margin/VBox/WeaponLabel
@onready var gains_label: Label = $Margin/VBox/GainsLabel
@onready var round_label: Label = $Margin/VBox/RoundLabel
@onready var prompt_label: Label = $Margin/PromptLabel
@onready var coords_label: Label = $CoordsLabel

@onready var perk_trt: TextureRect = $PerkBar/TRT
@onready var perk_creatine: TextureRect = $PerkBar/Creatine
@onready var perk_whey: TextureRect = $PerkBar/Whey
@onready var perk_pre_workout: TextureRect = $PerkBar/PreWorkout
@onready var perk_fish_oil: TextureRect = $PerkBar/FishOil
@onready var perk_bcaas: TextureRect = $PerkBar/BCAAs

const EXTRA_PERKS_PATH: String = "res://scripts/ui/hud_extra_perks.gd"
var _player: Node
var _perk_icons: Dictionary = {}
var _blood_counter = null   # blood_counter.gd instance (untyped on purpose)
var _fallback_zombie_label: Label = null


func _ready() -> void:
	_build_top_center()

	for label in [health_label, ammo_label, weapon_label, gains_label, round_label]:
		label.add_theme_font_size_override("font_size", 32)
	prompt_label.add_theme_font_size_override("font_size", 38)
	prompt_label.add_theme_constant_override("outline_size", 8)
	prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	coords_label.add_theme_font_size_override("font_size", 24)
	call_deferred("_enlarge_world_labels")
	GameManager.gains_changed.connect(_on_gains_changed)
	GameManager.round_changed.connect(_on_round_changed)
	_on_gains_changed(GameManager.gains)
	_on_round_changed(GameManager.round_number)

	_perk_icons = {
		"trt": perk_trt,
		"creatine": perk_creatine,
		"whey": perk_whey,
		"pre_workout": perk_pre_workout,
		"fish_oil": perk_fish_oil,
		"bcaas": perk_bcaas, "glutamine": load(EXTRA_PERKS_PATH).make_icon($PerkBar, perk_whey, "glutamine") if load(EXTRA_PERKS_PATH) != null else TextureRect.new(), "collagen": load(EXTRA_PERKS_PATH).make_icon($PerkBar, perk_whey, "collagen") if load(EXTRA_PERKS_PATH) != null else TextureRect.new(),
	}


## Round counter + zombie counter, centered at the top of the screen.
func _build_top_center() -> void:
	var top_box := VBoxContainer.new()
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(top_box)

	# Move the existing round label out of the top-left stack.
	round_label.get_parent().remove_child(round_label)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.88, 1.0))
	round_label.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.02, 1.0))
	round_label.add_theme_constant_override("outline_size", 8)
	top_box.add_child(round_label)

	# Blood-drip counter; if the script is missing, fall back to a plain red number.
	var counter_script = load("res://scripts/ui/blood_counter.gd")
	if counter_script:
		var counter := Control.new()
		counter.set_script(counter_script)
		top_box.add_child(counter)
		_blood_counter = counter
	else:
		_fallback_zombie_label = Label.new()
		_fallback_zombie_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fallback_zombie_label.add_theme_font_size_override("font_size", 64)
		_fallback_zombie_label.add_theme_color_override("font_color", Color(0.74, 0.03, 0.06, 1.0))
		_fallback_zombie_label.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.02, 1.0))
		_fallback_zombie_label.add_theme_constant_override("outline_size", 10)
		_fallback_zombie_label.text = "0"
		top_box.add_child(_fallback_zombie_label)

	top_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	top_box.grow_horizontal = Control.GROW_DIRECTION_BOTH


func bind_player(player: Node) -> void:
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.interact_prompt_changed.connect(_on_prompt_changed)
	player.perks_changed.connect(_on_perks_changed)
	_on_perks_changed(player.owned_perks)
	_build_stamina_bar()
	player.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(player.stamina, player.max_stamina)


func bind_round_manager(round_manager: Node) -> void:
	if round_manager == null or not round_manager.has_signal("zombies_changed"):
		return
	round_manager.zombies_changed.connect(_on_zombies_changed)
	_on_zombies_changed(round_manager.get_zombies_remaining(), round_manager.get_zombies_total())


func _process(_delta: float) -> void:
	if _player:
		var pos: Vector3 = _player.global_position
		coords_label.text = "X: %.1f  Y: %.1f  Z: %.1f" % [pos.x, pos.y, pos.z]
		_update_prompt_color()


## Colors the "Tap USE to..." prompt to match whatever station you're looking at
## (stations that have a get_prompt_color() method). Everything else stays white.
func _update_prompt_color() -> void:
	var color := Color(1, 1, 1, 1)
	if _player and _player.interact_ray and _player.interact_ray.is_colliding():
		var target = _player.interact_ray.get_collider()
		if target and target.has_method("get_prompt_color"):
			color = target.get_prompt_color()
	prompt_label.add_theme_color_override("font_color", color)


## Makes every floating 3D label in the level (station names, the locker sign) bigger.
func _enlarge_world_labels() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var grow: float = 1.6
	for node in scene.find_children("*", "Label3D", true, false):
		var label3d := node as Label3D
		if label3d:
			label3d.pixel_size *= grow


func _on_health_changed(current: float, max_hp: float) -> void:
	health_label.text = "HP: %d / %d" % [int(current), int(max_hp)]


func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	ammo_label.text = "Ammo: %d / %d" % [current_mag, reserve]
	if _player and _player.current_weapon:
		weapon_label.text = _player.current_weapon.weapon_name


func _on_gains_changed(amount: int) -> void:
	gains_label.text = "Gains: %d" % amount


func _on_round_changed(round_number: int) -> void:
	round_label.text = "Round: %d" % round_number


func _on_zombies_changed(remaining: int, _total: int) -> void:
	if _blood_counter != null:
		_blood_counter.set_value(remaining)
	elif _fallback_zombie_label != null:
		_fallback_zombie_label.text = str(remaining)


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


func _on_perks_changed(owned: Array) -> void:
	for id in _perk_icons.keys():
		var icon: TextureRect = _perk_icons[id]
		icon.modulate.a = 1.0 if id in owned else 0.25


var _stamina_bar: ProgressBar = null


## Chalk-white bar under the Gains label; hidden while stamina is full.
func _build_stamina_bar() -> void:
	if _stamina_bar != null:
		return
	_stamina_bar = ProgressBar.new()
	_stamina_bar.custom_minimum_size = Vector2(280, 22)
	_stamina_bar.show_percentage = false
	_stamina_bar.min_value = 0.0
	_stamina_bar.max_value = 100.0
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.93, 0.93, 0.88, 1.0)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.06, 0.02, 0.02, 0.7)
	_stamina_bar.add_theme_stylebox_override("fill", fill)
	_stamina_bar.add_theme_stylebox_override("background", back)
	health_label.get_parent().add_child(_stamina_bar)
	_stamina_bar.visible = false


func _on_stamina_changed(current: float, max_stamina: float) -> void:
	if _stamina_bar == null:
		return
	_stamina_bar.max_value = max_stamina
	_stamina_bar.value = current
	_stamina_bar.visible = current < max_stamina - 0.1
