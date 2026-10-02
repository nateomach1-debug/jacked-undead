extends Control
## Co-op screen: host or join a LAN game. The host also gets MAP and START.
## Uses an on-screen number pad because the phone keyboard won't open here.

# Keep in sync with the maps listed in map_select.gd.
const MAPS: Array = [
	{"title": "GYM ARENA", "path": "res://scenes/main/main.tscn"},
	{"title": "BUILDING", "path": "res://scenes/main/building_map.tscn"},
	{"title": "MULTI-ROOM", "path": "res://scenes/main/multi_room_map.tscn"},
	{"title": "GYM COMPOUND", "path": "res://scenes/main/gym_compound.tscn"},
	{"title": "CHALLENGE MAP", "path": "res://scenes/main/challenge_map.tscn"},
]

var _status: Label
var _ip_label: Label
var _map_button: Button
var _start_button: Button
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

	# Right side: status + host / join / map / start / back
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
