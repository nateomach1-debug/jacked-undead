extends Control
## Co-op screen: host or join a LAN game. The host also gets MAP and START.
## Uses on-screen pads because the phone keyboard won't open here:
## a number pad for the host IP and a letter pad for your display name.

# Keep in sync with the maps listed in map_select.gd.
const MAPS: Array = [
	{"title": "GYM ARENA", "path": "res://scenes/main/main.tscn"},
	{"title": "BUILDING", "path": "res://scenes/main/building_map.tscn"},
	{"title": "MULTI-ROOM", "path": "res://scenes/main/multi_room_map.tscn"},
	{"title": "GYM COMPOUND", "path": "res://scenes/main/gym_compound.tscn"},
	{"title": "CHALLENGE MAP", "path": "res://scenes/main/challenge_map.tscn"},
]

const NAME_KEYS: Array = [
	"A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
	"K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
	"U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3",
	"4", "5", "6", "7", "8", "9", "SPACE", "DEL", "OK", "CANCEL",
]

var _status: Label
var _ip_label: Label
var _map_button: Button
var _start_button: Button
var _name_button: Button
var _name_pad: Control
var _name_display: Label
var _name_buffer: String = ""
var _ip: String = ""
var _map_index: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	center.add_child(row)

	# Left side: IP display + number pad
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)

	_ip_label = Label.new()
	_ip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ip_label.add_theme_font_size_override("font_size", 32)
	left.add_child(_ip_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	left.add_child(grid)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "DEL"]:
		var b := Button.new()
		b.text = key
		b.custom_minimum_size = Vector2(130, 76)
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(_on_key.bind(key))
		grid.add_child(b)

	# Right side: status + name / host / join / map / start / back
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)

	_status = Label.new()
	_status.text = "Co-op (same Wi-Fi)"
	_status.custom_minimum_size = Vector2(460, 100)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 26)
	right.add_child(_status)

	_name_button = _make_button("", _on_name)
	_name_button.custom_minimum_size = Vector2(460, 64)
	right.add_child(_name_button)

	right.add_child(_make_button("HOST GAME", _on_host))
	right.add_child(_make_button("JOIN GAME", _on_join))

	_map_button = _make_button("", _on_map)
	_map_button.visible = false
	right.add_child(_map_button)

	_start_button = _make_button("START GAME", _on_start)
	_start_button.visible = false
	right.add_child(_start_button)

	right.add_child(_make_button("BACK", _on_back))

	# Pre-fill the first three numbers from this phone's own Wi-Fi address.
	var mine: String = NetManager.get_local_ip()
	if mine != "unknown":
		_ip = mine.substr(0, mine.rfind(".") + 1)
	_refresh_ip()
	_refresh_map()
	_refresh_name_button()

	_build_name_pad()

	NetManager.status_changed.connect(_on_status)


func _make_button(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(460, 80)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(callback)
	return b


func _on_key(key: String) -> void:
	if key == "DEL":
		if _ip.length() > 0:
			_ip = _ip.substr(0, _ip.length() - 1)
	elif _ip.length() < 15:
		_ip += key
	_refresh_ip()


func _refresh_ip() -> void:
	_ip_label.text = "Host IP: " + (_ip if _ip != "" else "_")


func _refresh_map() -> void:
	_map_button.text = "MAP: " + str(MAPS[_map_index]["title"])


func _refresh_name_button() -> void:
	var n: String = NetManager.player_name
	_name_button.text = "NAME: " + (n if n != "" else "(auto)")


# ---------- name pad ----------

func _build_name_pad() -> void:
	_name_pad = Control.new()
	_name_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_pad.visible = false
	add_child(_name_pad)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.99)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_pad.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_name_pad.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	_name_display = Label.new()
	_name_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_display.add_theme_font_size_override("font_size", 40)
	box.add_child(_name_display)

	var keys := GridContainer.new()
	keys.columns = 10
	keys.add_theme_constant_override("h_separation", 6)
	keys.add_theme_constant_override("v_separation", 6)
	box.add_child(keys)
	for key in NAME_KEYS:
		var b := Button.new()
		b.text = str(key)
		b.custom_minimum_size = Vector2(96, 70)
		b.add_theme_font_size_override("font_size", 24 if str(key).length() > 2 else 30)
		b.pressed.connect(_on_name_key.bind(str(key)))
		keys.add_child(b)


func _on_name() -> void:
	_name_buffer = NetManager.player_name
	_refresh_name_display()
	_name_pad.visible = true


func _on_name_key(key: String) -> void:
	if key == "DEL":
		if _name_buffer.length() > 0:
			_name_buffer = _name_buffer.substr(0, _name_buffer.length() - 1)
	elif key == "SPACE":
		if _name_buffer.length() < NetManager.MAX_NAME_LENGTH:
			_name_buffer += " "
	elif key == "OK":
		NetManager.set_player_name(_name_buffer)
		_refresh_name_button()
		_name_pad.visible = false
		return
	elif key == "CANCEL":
		_name_pad.visible = false
		return
	elif _name_buffer.length() < NetManager.MAX_NAME_LENGTH:
		_name_buffer += key
	_refresh_name_display()


func _refresh_name_display() -> void:
	_name_display.text = "Name: " + (_name_buffer if _name_buffer != "" else "_")


# ---------- host / join ----------

func _on_host() -> void:
	if NetManager.host_game():
		_map_button.visible = true
		_start_button.visible = true


func _on_join() -> void:
	_map_button.visible = false
	_start_button.visible = false
	NetManager.join_game(_ip)


func _on_map() -> void:
	_map_index = (_map_index + 1) % MAPS.size()
	_refresh_map()


func _on_start() -> void:
	NetManager.start_game_on(str(MAPS[_map_index]["path"]))


func _on_back() -> void:
	NetManager.leave()
	queue_free()


func _on_status(text: String) -> void:
	_status.text = text
