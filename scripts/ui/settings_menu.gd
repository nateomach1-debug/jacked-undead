extends Control
## Settings screen opened from OPTIONS: look speeds, field of view, sprint mode.
## Values change with - / + buttons (easy on touch and with a controller).

const SETTINGS_PATH: String = "res://scripts/managers/game_settings.gd"
const ROWS: Array = [
	{"key": "touch_look", "title": "Touch look speed", "min": 0.5, "max": 2.0, "step": 0.1, "fmt": "x%.1f"},
	{"key": "pad_look", "title": "Gamepad look speed", "min": 90.0, "max": 400.0, "step": 20.0, "fmt": "%d deg/s"},
	{"key": "fov", "title": "Field of view", "min": 60.0, "max": 110.0, "step": 5.0, "fmt": "%d"},
]

var _settings = null
var _labels: Dictionary = {}
var _sprint_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var script = load(SETTINGS_PATH)
	if script != null:
		_settings = script.new()

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	if _settings == null:
		var err := Label.new()
		err.text = "SETTINGS FAILED TO LOAD"
		err.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		vbox.add_child(err)
	else:
		for row in ROWS:
			_add_stepper_row(vbox, row)
		_sprint_button = _make_button("", _on_sprint_mode)
		vbox.add_child(_sprint_button)
		_refresh_sprint_button()
		vbox.add_child(_make_button("RESET TO DEFAULTS", _on_reset))
		_replay_button = _make_button("REPLAY TUTORIAL", _on_replay_tutorial)
		vbox.add_child(_replay_button)
	vbox.add_child(_make_button("BACK", _on_back))


func _make_button(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(560, 70)
	b.add_theme_font_size_override("font_size", 26)
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
	name_label.add_theme_font_size_override("font_size", 26)
	box.add_child(name_label)

	box.add_child(_step_button("-", key, -1))

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(170, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 28)
	box.add_child(value_label)
	_labels[key] = value_label

	box.add_child(_step_button("+", key, 1))
	_update_label(key)


func _step_button(text: String, key: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(90, 70)
	b.add_theme_font_size_override("font_size", 36)
	b.pressed.connect(_on_step.bind(key, dir))
	return b


func _on_step(key: String, dir: int) -> void:
	for row in ROWS:
		if row["key"] == key:
			var step: float = float(row["step"])
			var v: float = _settings.get_value(key) + float(dir) * step
			v = snappedf(clampf(v, float(row["min"]), float(row["max"])), step / 10.0)
			_settings.set_value(key, v)
	_update_label(key)


func _update_label(key: String) -> void:
	for row in ROWS:
		if row["key"] == key:
			var v: float = _settings.get_value(key)
			var fmt: String = row["fmt"]
			var shown: String = (fmt % v) if fmt.contains("%.") else (fmt % int(v))
			(_labels[key] as Label).text = shown


func _on_sprint_mode() -> void:
	var hold: bool = _settings.get_value("sprint_hold") > 0.5
	_settings.set_value("sprint_hold", 0.0 if hold else 1.0)
	_refresh_sprint_button()


func _refresh_sprint_button() -> void:
	var hold: bool = _settings.get_value("sprint_hold") > 0.5
	_sprint_button.text = "SPRINT: " + ("HOLD" if hold else "TOGGLE")


func _on_reset() -> void:
	_settings.reset()
	for key in _labels.keys():
		_update_label(key)
	_refresh_sprint_button()


func _on_back() -> void:
	queue_free()


var _replay_button: Button


func _on_replay_tutorial() -> void:
	_settings.set_value("tutorial_seen", 0.0)
	_replay_button.text = "TUTORIAL SHOWS AT NEXT GAME"
