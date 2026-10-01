extends Control
## Co-op test screen (step 1): host or join a LAN game and show the status.

var _status: Label
var _ip_edit: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	_status = Label.new()
	_status.text = "Co-op (same Wi-Fi)"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 30)
	box.add_child(_status)

	box.add_child(_make_button("HOST GAME", _on_host))

	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "Host IP, e.g. 192.168.1.23"
	_ip_edit.custom_minimum_size = Vector2(420, 80)
	_ip_edit.add_theme_font_size_override("font_size", 28)
	box.add_child(_ip_edit)

	box.add_child(_make_button("JOIN GAME", _on_join))
	box.add_child(_make_button("BACK", _on_back))

	NetManager.status_changed.connect(_on_status)


func _make_button(label: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(420, 90)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(callback)
	return b


func _on_host() -> void:
	NetManager.host_game()


func _on_join() -> void:
	NetManager.join_game(_ip_edit.text)


func _on_back() -> void:
	NetManager.leave()
	queue_free()


func _on_status(text: String) -> void:
	_status.text = text
