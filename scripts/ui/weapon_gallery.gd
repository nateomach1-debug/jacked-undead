extends Control
## Weapon gallery: list of guns (left), spinning preview + attachment slots (middle),
## stat bars (right).

const GUN_PATHS: Array = [
	"res://resources/weapons/pistol.tres",
	"res://resources/weapons/rifle.tres",
	"res://resources/weapons/smg.tres",
	"res://resources/weapons/crossbow.tres",
	"res://resources/weapons/sniper.tres",
]
const LOCKER_PATH: String = "res://scripts/weapons/locker_weapons.gd"
const ATTACH_REGISTRY: String = "res://scripts/weapons/attachments.gd"
const ATTACH_MODELS: String = "res://scripts/weapons/attachment_models.gd"
const PROFILE_PATH: String = "res://scripts/managers/profile.gd"
const PREVIEW_FIT: float = 1.8
# Turns each model so the gun points along +X (what the attachment graphics expect).
const MODEL_YAW: float = 0.0          # .gltf guns
const PLACEHOLDER_YAW: float = -90.0  # procedural guns (they point toward -Z)
const BAR_HEADROOM: float = 1.5       # bar is full at (best gun's stat x this)

var _guns: Array = []          # {"w": WeaponData, "locker": bool}
var _index: int = 0
var _stage: Node3D
var _holder: Node3D = null
var _name_label: Label
var _stats_box: VBoxContainer
var _spin: bool = true
var _spin_button: Button
var _slot_buttons: Dictionary = {}   # slot name -> Button
var _max_scores: Dictionary = {}     # stat key -> best base score across all guns


## A horizontal stat bar: white = base, green = gained, red = lost.
class StatBar extends Control:
	var base_frac: float = 0.0
	var mod_frac: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 16)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.15, 0.18))
		var lo: float = minf(base_frac, mod_frac)
		var hi: float = maxf(base_frac, mod_frac)
		draw_rect(Rect2(0, 0, w * lo, h), Color(0.85, 0.85, 0.9))
		if hi > lo:
			var col: Color = Color(0.3, 0.85, 0.35) if mod_frac > base_frac else Color(0.9, 0.3, 0.25)
			draw_rect(Rect2(w * lo, 0, w * (hi - lo), h), col)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_guns()
	_compute_max_scores()
	_build_ui()
	if not _guns.is_empty():
		_select(0)


func _load_guns() -> void:
	for path in GUN_PATHS:
		var w = load(path)
		if w is WeaponData:
			_guns.append({"w": w, "locker": false})
	var script = load(LOCKER_PATH)
	if script != null:
		for entry in script.build_pool():
			var lw = entry["weapon"]
			# Wall-buy guns in the pool come from .tres files; skip them (already listed).
			if lw != null and lw.resource_path == "":
				_guns.append({"w": lw, "locker": true})


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	margin.add_child(outer)

	var title := Label.new()
	title.text = "WEAPON GALLERY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	outer.add_child(title)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	outer.add_child(main)

	# ---- left: gun list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var group := ButtonGroup.new()
	var locker_header_done: bool = false
	for i in range(_guns.size()):
		if bool(_guns[i]["locker"]) and not locker_header_done:
			locker_header_done = true
			var header := Label.new()
			header.text = "LOOT LOCKER"
			header.add_theme_font_size_override("font_size", 22)
			header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			list.add_child(header)
		var b := Button.new()
		b.text = (_guns[i]["w"] as WeaponData).weapon_name
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(0, 60)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_select.bind(i))
		list.add_child(b)

	# ---- middle: name + spinning preview + slots
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(mid)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 28)
	mid.add_child(_name_label)

	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(300, 200)
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.gui_input.connect(_on_preview_input)
	mid.add_child(container)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	container.add_child(vp)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.0, 3.6)
	cam.fov = 38.0
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.7
	cam.environment = env
	vp.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	light.light_energy = 1.3
	vp.add_child(light)

	_stage = Node3D.new()
	vp.add_child(_stage)

	_spin_button = Button.new()
	_spin_button.custom_minimum_size = Vector2(0, 56)
	_spin_button.add_theme_font_size_override("font_size", 20)
	_spin_button.pressed.connect(_toggle_spin)
	mid.add_child(_spin_button)
	_update_spin_button()

	var slot_grid := GridContainer.new()
	slot_grid.columns = 2
	slot_grid.add_theme_constant_override("h_separation", 8)
	slot_grid.add_theme_constant_override("v_separation", 8)
	mid.add_child(slot_grid)
	var reg_script = load(ATTACH_REGISTRY)
	if reg_script != null:
		for slot in reg_script.new().SLOTS:
			var sb := Button.new()
			sb.custom_minimum_size = Vector2(0, 56)
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.add_theme_font_size_override("font_size", 18)
			sb.pressed.connect(_on_slot_pressed.bind(str(slot)))
			slot_grid.add_child(sb)
			_slot_buttons[str(slot)] = sb
		    _add_reticle_button(slot_grid)
	# ---- right: stat bars
	_stats_box = VBoxContainer.new()
	_stats_box.custom_minimum_size = Vector2(400, 0)
	_stats_box.add_theme_constant_override("separation", 6)
	main.add_child(_stats_box)

	# ---- bottom: back
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 70)
	back.add_theme_font_size_override("font_size", 26)
	back.pressed.connect(queue_free)
	outer.add_child(back)


func _toggle_spin() -> void:
	_spin = not _spin
	if not _spin:
		_stage.rotation.y = 0.0   # clean side view
	_update_spin_button()


func _update_spin_button() -> void:
	_spin_button.text = "SPIN: ON" if _spin else "SPIN: OFF (drag to rotate)"


## Drag on the preview to turn the gun by hand (only while spin is off).
func _on_preview_input(event: InputEvent) -> void:
	if _spin or _stage == null:
		return
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_stage.rotation.y += event.relative.x * 0.01


func _select(i: int) -> void:
	_index = i
	var w: WeaponData = _guns[i]["w"]
	_name_label.text = w.weapon_name
	_rebuild_model(w)
	_refresh_stats(w)
	_update_slot_buttons()


# ------------------------------------------------------------------ slots

## Shows what's equipped in each slot on its button.
func _update_slot_buttons() -> void:
	if _guns.is_empty():
		return
	var w: WeaponData = _guns[_index]["w"]
	var reg_script = load(ATTACH_REGISTRY)
	if reg_script == null:
		return
	var reg = reg_script.new()
	var loadout: Dictionary = reg.get_loadout(w.get_base_name())
		_update_reticle_button()
	for slot in _slot_buttons.keys():
		var id: String = str(loadout.get(slot, ""))
		var label: String = "NONE"
		if id != "" and reg.ATTACHMENTS.has(id):
			label = str(reg.ATTACHMENTS[id]["name"])
		(_slot_buttons[slot] as Button).text = "%s: %s" % [str(slot).to_upper(), label]


## Tap a slot: cycles NONE -> each attachment for that slot -> NONE, and saves it.
func _on_slot_pressed(slot: String) -> void:
	var w: WeaponData = _guns[_index]["w"]
	var reg_script = load(ATTACH_REGISTRY)
	var profile_script = load(PROFILE_PATH)
	if reg_script == null or profile_script == null:
		return
	var reg = reg_script.new()
	var options: Array = [""]
	for id in reg.ATTACHMENTS.keys():
		if str(reg.ATTACHMENTS[id]["slot"]) == slot and _owns_attachment(str(id)):
			options.append(str(id))
	var loadout: Dictionary = reg.get_loadout(w.get_base_name())
	var current: String = str(loadout.get(slot, ""))
	var idx: int = maxi(options.find(current), 0)
	var next_id: String = str(options[(idx + 1) % options.size()])
	profile_script.new().set_attachment(w.get_base_name(), slot, next_id)

	var keep_rot: float = _stage.rotation.y
	_rebuild_model(w)
	_stage.rotation.y = keep_rot
	_refresh_stats(w)
	_update_slot_buttons()


func _rebuild_model(w: WeaponData) -> void:
	if _holder != null:
		_stage.remove_child(_holder)
		_holder.queue_free()
		_holder = null
	var model: Node3D = w.create_model()
	if model == null:
		return
	# Point the gun along +X, then scale it to PREVIEW_FIT and center it.
	model.rotation.y = deg_to_rad(MODEL_YAW if w.model_scene != null else PLACEHOLDER_YAW)
	var info: Dictionary = {"has": false, "box": AABB()}
	_collect_aabb(model, Transform3D.IDENTITY, info)
	if bool(info["has"]):
		var box: AABB = info["box"]
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		if longest > 0.0001:
			var s: float = PREVIEW_FIT / longest
			model.scale = Vector3.ONE * s
			model.position = -(box.position + box.size * 0.5) * s
	_holder = Node3D.new()
	_holder.add_child(model)
	_add_attachments(model, w)
	_stage.add_child(_holder)
	_stage.rotation.y = 0.0


## Draws the gun's equipped attachments (same builder the player uses).
func _add_attachments(model: Node3D, w: WeaponData) -> void:
	var reg_script = load(ATTACH_REGISTRY)
	var models_script = load(ATTACH_MODELS)
	if reg_script == null or models_script == null:
		return
	var loadout = reg_script.new().get_loadout(w.get_base_name())
	if not (loadout is Dictionary) or loadout.is_empty():
		return
	var root = models_script.new().build_for(model, loadout, w.get_base_name())
	if root != null:
		_holder.add_child(root)


# ------------------------------------------------------------------ stats

func _ones() -> Dictionary:
	return {
		"damage_mult": 1.0, "range_mult": 1.0, "spread_mult": 1.0, "fire_rate_mult": 1.0,
		"mag_mult": 1.0, "reserve_mult": 1.0, "reload_speed_mult": 1.0,
	}


## Multiplies together the mods of every equipped attachment.
func _totals(reg, loadout: Dictionary) -> Dictionary:
	var total: Dictionary = _ones()
	for slot in reg.SLOTS:
		var id: String = str(loadout.get(slot, ""))
		if id == "" or not reg.ATTACHMENTS.has(id):
			continue
		var entry: Dictionary = reg.ATTACHMENTS[id]
		if str(entry["slot"]) != slot:
			continue
		var mods: Dictionary = entry["mods"]
		for key in mods.keys():
			total[key] = float(total.get(key, 1.0)) * float(mods[key])
	return total


## The 7 gallery stats for a gun with the given multipliers. "score" is higher-is-better
## (used for the bars); "text" is what's shown.
func _calc(w: WeaponData, t: Dictionary) -> Array:
	var damage: float = w.damage * float(maxi(w.pellets, 1)) * float(t["damage_mult"])
	var rng: float = w.range * float(t["range_mult"])
	var spread: float = w.spread_degrees * float(t["spread_mult"])
	var accuracy: float = 100.0 / (1.0 + spread * 0.25)
	var fr_mult: float = maxf(float(t["fire_rate_mult"]), 0.1)
	var bursts: int = maxi(w.burst_count, 1)
	var cycle: float = w.fire_rate / fr_mult + float(bursts - 1) * w.burst_interval / fr_mult
	var rate: float = float(bursts) / maxf(cycle, 0.01)
	var mag: int = maxi(1, int(round(float(w.mag_size) * float(t["mag_mult"]))))
	var reload: float = 0.0
	var reload_speed: float = 0.0
	if w.reload_time > 0.0:
		reload = w.reload_time / maxf(float(t["reload_speed_mult"]), 0.1)
		reload_speed = 1.0 / reload
	var reserve: int = maxi(0, int(round(float(w.max_reserve_ammo) * float(t["reserve_mult"]))))
	return [
		{"key": "damage", "label": "DAMAGE", "score": damage, "text": "%d" % int(round(damage))},
		{"key": "range", "label": "RANGE", "score": rng, "text": "%dm" % int(round(rng))},
		{"key": "accuracy", "label": "ACCURACY", "score": accuracy, "text": "%d%%" % int(round(accuracy))},
		{"key": "rate", "label": "FIRE RATE", "score": rate, "text": "%.1f/s" % rate},
		{"key": "mag", "label": "MAGAZINE", "score": float(mag), "text": "%d" % mag},
		{"key": "reload", "label": "RELOAD", "score": reload_speed, "text": "%.1fs" % reload},
		{"key": "reserve", "label": "RESERVE", "score": float(reserve), "text": "%d" % reserve},
	]


func _compute_max_scores() -> void:
	_max_scores.clear()
	for g in _guns:
		for s in _calc(g["w"], _ones()):
			var k: String = str(s["key"])
			_max_scores[k] = maxf(float(_max_scores.get(k, 0.0)), float(s["score"]))


func _bar_frac(key: String, score: float) -> float:
	var best: float = float(_max_scores.get(key, 1.0)) * BAR_HEADROOM
	if best <= 0.0:
		return 0.0
	return sqrt(clampf(score / best, 0.0, 1.0))


func _refresh_stats(w: WeaponData) -> void:
	for c in _stats_box.get_children():
		_stats_box.remove_child(c)
		c.queue_free()

	var total: Dictionary = _ones()
	var reg_script = load(ATTACH_REGISTRY)
	if reg_script != null:
		var reg = reg_script.new()
		var l = reg.get_loadout(w.get_base_name())
		if l is Dictionary:
			total = _totals(reg, l)

	var base: Array = _calc(w, _ones())
	var mod: Array = _calc(w, total)
	for i in range(base.size()):
		var key: String = str(base[i]["key"])
		var base_score: float = float(base[i]["score"])
		var mod_score: float = float(mod[i]["score"])

		var head := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = str(base[i]["label"])
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_font_size_override("font_size", 18)
		head.add_child(name_l)

		var val_l := Label.new()
		var txt: String = str(mod[i]["text"])
		var color: Color = Color(1, 1, 1)
		if base_score > 0.0:
			var pct: int = int(round((mod_score / base_score - 1.0) * 100.0))
			if pct != 0:
				txt += " (%+d%%)" % pct
				color = Color(0.4, 0.9, 0.4) if pct > 0 else Color(0.95, 0.4, 0.35)
		val_l.text = txt
		val_l.add_theme_font_size_override("font_size", 18)
		val_l.add_theme_color_override("font_color", color)
		head.add_child(val_l)
		_stats_box.add_child(head)

		var bar := StatBar.new()
		bar.base_frac = _bar_frac(key, base_score)
		bar.mod_frac = _bar_frac(key, mod_score)
		_stats_box.add_child(bar)

	var note := Label.new()
	note.text = "Bars show the gun before PR upgrades. Attachments only work after a PR Rack upgrade."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	_stats_box.add_child(note)


func _collect_aabb(node: Node, parent_xf: Transform3D, info: Dictionary) -> void:
	var xf: Transform3D = parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var local: AABB = (node as MeshInstance3D).get_aabb()
		if local.size.length() > 0.0:
			var box: AABB = xf * local
			if bool(info["has"]):
				info["box"] = (info["box"] as AABB).merge(box)
			else:
				info["box"] = box
				info["has"] = true
	for c in node.get_children():
		_collect_aabb(c, xf, info)


func _process(delta: float) -> void:
	if _spin and _stage != null and is_visible_in_tree():
		_stage.rotation.y += delta * 0.9


## True if the attachment is a starter or has been bought in the Market.
func _owns_attachment(id: String) -> bool:
	var market_script = load("res://scripts/managers/market.gd")
	var profile_script = load(PROFILE_PATH)
	if market_script == null or profile_script == null:
		return true
	return market_script.new().owns_attachment(profile_script.new(), id)


# ---------- reticle picker ----------

const ACH_PATH: String = "res://scripts/managers/achievements.gd"
const RETICLES_LIB_PATH: String = "res://scripts/ui/reticles.gd"

var _reticle_button: Button = null
var _reticle_preview = null


func _add_reticle_button(slot_grid: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	slot_grid.get_parent().add_child(row)
	_reticle_button = Button.new()
	_reticle_button.custom_minimum_size = Vector2(0, 56)
	_reticle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reticle_button.add_theme_font_size_override("font_size", 18)
	_reticle_button.pressed.connect(_on_reticle_pressed)
	row.add_child(_reticle_button)
	var preview := ReticlePreview.new()
	var lib_script = load(RETICLES_LIB_PATH)
	if lib_script != null:
		preview.lib = lib_script.new()
	row.add_child(preview)
	_reticle_preview = preview


## The optic equipped on the selected gun ("" if none).
func _current_optic() -> String:
	if _guns.is_empty():
		return ""
	var w: WeaponData = _guns[_index]["w"]
	var reg_script = load(ATTACH_REGISTRY)
	if reg_script == null:
		return ""
	var loadout: Dictionary = reg_script.new().get_loadout(w.get_base_name())
	return str(loadout.get("optic", ""))


func _update_reticle_button() -> void:
	if _reticle_button == null or _reticle_preview == null:
		return
	var optic: String = _current_optic()
	var ach_script = load(ACH_PATH)
	if optic == "" or ach_script == null:
		_reticle_button.text = "RETICLE: (equip an optic)"
		_reticle_button.disabled = true
		_reticle_preview.kind = ""
		_reticle_preview.queue_redraw()
		return
	var ach = ach_script.new()
	var chosen: String = ach.get_reticle(optic)
	_reticle_button.disabled = false
	if chosen == "":
		_reticle_button.text = "RETICLE: Default"
		var shown: String = "dot"
		if _reticle_preview.lib != null:
			shown = _reticle_preview.lib.default_for(optic)
		_reticle_preview.kind = shown
	else:
		_reticle_button.text = "RETICLE: %s" % str(ach.RETICLES.get(chosen, chosen))
		_reticle_preview.kind = chosen
	_reticle_preview.queue_redraw()


## Tap: cycles Default -> each unlocked reticle -> Default, saved for this optic.
func _on_reticle_pressed() -> void:
	var optic: String = _current_optic()
	var ach_script = load(ACH_PATH)
	if optic == "" or ach_script == null:
		return
	var ach = ach_script.new()
	var options: Array = [""]
	options.append_array(ach.unlocked_reticles())
	var idx: int = maxi(options.find(ach.get_reticle(optic)), 0)
	ach.set_reticle(optic, str(options[(idx + 1) % options.size()]))
	_update_reticle_button()


## A small box that draws a reticle so you can see what you picked.
class ReticlePreview extends Control:
	var kind: String = ""
	var lib = null

	func _init() -> void:
		custom_minimum_size = Vector2(70, 56)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.15))
		if lib != null and kind != "":
			lib.draw_reticle(self, size * 0.5, kind, 18.0, Color(1.0, 0.2, 0.2))
