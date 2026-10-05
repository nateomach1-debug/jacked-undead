extends Control
## Settings screen opened from OPTIONS: look speeds, field of view, ADS, reticle, sprint mode.
## Each value has a slider plus - / + buttons (the buttons also work great with a controller).

const SETTINGS_PATH: String = "res://scripts/managers/game_settings.gd"
const SLIDER_PATH: String = "res://scripts/ui/touch_slider.gd"
const ROWS: Array = [
	{"key": "touch_look", "title": "Touch look speed", "min": 0.5, "max": 2.0, "step": 0.1, "fmt": "x%.1f"},
	{"key": "pad_look", "title": "Gamepad look speed", "min": 100.0, "max": 400.0, "step": 20.0, "fmt": "%d deg/s"},
	{"key": "fov", "title": "Field of view", "min": 60.0, "max": 110.0, "step": 5.0, "fmt": "%d"},
	{"key": "ads_sens", "title": "ADS sensitivity", "min": 25.0, "max": 150.0, "step": 5.0, "fmt": "%d%%"},
	{"key": "ads_zoom", "title": "ADS zoom", "min": 50.0, "max": 150.0, "step": 5.0, "fmt": "%d%%"},
	{"key": "reticle_size", "title": "Reticle size", "min": 50.0, "max": 200.0, "step": 5.0, "fmt": "%d%%"},
]

var _settings = null
var _slider_script = null
var _labels: Dictionary = {}
var _sliders: Dictionary = {}
var _sprint_button: Button
var _color_button: Button
var _hit_button: Button
var _replay_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var script = load(SETTINGS_PATH)
	if script != null:
		_settings = script.new()
	_slider_script = load(SLIDER_PATH)

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
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	outer.add_child(title)

	# The list scrolls by dragging; BACK stays pinned at the bottom.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	if _settings == null:
		var err := Label.new()
		err.text = "SETTINGS FAILED TO LOAD"
		err.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		vbox.add_child(err)
	else:
		for row in ROWS:
			_add_stepper_row(vbox, row)
		_color_button = _make_button("", _on_reticle_color)
		vbox.add_child(_color_button)
		_hit_button = _make_button("", _on_hit_markers)
		vbox.add_child(_hit_button)
		_sprint_button = _make_button("", _on_sprint_mode)
		vbox.add_child(_sprint_button)
		_refresh_buttons()
		vbox.add_child(_make_button("RESET TO DEFAULTS", _on_reset))
		_replay_button = _make_button("REPLAY TUTORIAL", _on_replay_tutorial)
		vbox.add_child(_replay_button)

	var back := _make_button("BACK", _on_back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(back)


func _make_button(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(560, 60)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(callback)
	return b


func _add_stepper_row(parent: Control, row: Dictionary) -> void:
	var key: String = row["key"]
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)

	var name_label := Label.new()
	name_label.text = str(row["title"])
	name_label.custom_minimum_size = Vector2(300, 0)
	name_label.add_theme_font_size_override("font_size", 24)
	box.add_child(name_label)

	box.add_child(_step_button("-", key, -1))

	if _slider_script != null:
		var slider = Control.new()
		slider.set_script(_slider_script)
		slider.custom_minimum_size = Vector2(320, 60)
		slider.setup(float(row["min"]), float(row["max"]), float(row["step"]), _settings.get_value(key))
		slider.value_changed.connect(_on_slider.bind(key))
		box.add_child(slider)
		_sliders[key] = slider

	box.add_child(_step_button("+", key, 1))

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(150, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 26)
	box.add_child(value_label)
	_labels[key] = value_label
	_update_label(key)


func _step_button(text: String, key: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(90, 60)
	b.add_theme_font_size_override("font_size", 34)
	b.pressed.connect(_on_step.bind(key, dir))
	return b


func _row_for(key: String) -> Dictionary:
	for row in ROWS:
		if row["key"] == key:
			return row
	return {}


func _on_step(key: String, dir: int) -> void:
	var row: Dictionary = _row_for(key)
	if row.is_empty():
		return
	var step: float = float(row["step"])
	var v: float = _settings.get_value(key) + float(dir) * step
	v = snappedf(clampf(v, float(row["min"]), float(row["max"])), step / 10.0)
	_settings.set_value(key, v)
	_update_label(key)
	_sync_slider(key)


## Dragging a slider changes the setting (it snaps to the same steps as - / +).
func _on_slider(v: float, key: String) -> void:
	_settings.set_value(key, v)
	_update_label(key)


func _sync_slider(key: String) -> void:
	if _sliders.has(key):
		_sliders[key].set_value_silent(_settings.get_value(key))


func _update_label(key: String) -> void:
	var row: Dictionary = _row_for(key)
	if row.is_empty():
		return
	var v: float = _settings.get_value(key)
	var fmt: String = row["fmt"]
	var shown: String = (fmt % v) if fmt.contains("%.") else (fmt % int(v))
	(_labels[key] as Label).text = shown


## Cycles the reticle color through the list.
func _on_reticle_color() -> void:
	var count: int = _settings.RETICLE_COLORS.size()
	var idx: int = (int(_settings.get_value("reticle_color")) + 1) % count
	_settings.set_value("reticle_color", float(idx))
	_refresh_buttons()


func _on_hit_markers() -> void:
	var on: bool = _settings.get_value("hit_markers") > 0.5
	_settings.set_value("hit_markers", 0.0 if on else 1.0)
	_refresh_buttons()


func _on_sprint_mode() -> void:
	var hold: bool = _settings.get_value("sprint_hold") > 0.5
	_settings.set_value("sprint_hold", 0.0 if hold else 1.0)
	_refresh_buttons()


func _refresh_buttons() -> void:
	var count: int = _settings.RETICLE_COLORS.size()
	var idx: int = clampi(int(_settings.get_value("reticle_color")), 0, count - 1)
	var entry: Dictionary = _settings.RETICLE_COLORS[idx]
	_color_button.text = "RETICLE COLOR: " + str(entry["name"])
	_color_button.add_theme_color_override("font_color", entry["color"])
	_color_button.add_theme_color_override("font_hover_color", entry["color"])
	_color_button.add_theme_color_override("font_pressed_color", entry["color"])
	_hit_button.text = "HIT MARKERS: " + ("ON" if _settings.get_value("hit_markers") > 0.5 else "OFF")
	_sprint_button.text = "SPRINT: " + ("HOLD" if _settings.get_value("sprint_hold") > 0.5 else "TOGGLE")


func _on_reset() -> void:
	_settings.reset()
	for key in _labels.keys():
		_update_label(key)
		_sync_slider(key)
	_refresh_buttons()


func _on_back() -> void:
	queue_free()


func _on_replay_tutorial() -> void:
	_settings.set_value("tutorial_seen", 0.0)
	_replay_button.text = "TUTORIAL SHOWS AT NEXT GAME"
