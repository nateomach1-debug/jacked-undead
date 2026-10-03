extends CanvasLayer
## One-time tutorial, shown the first time a map loads (started by touch_controls.gd).
## Dims the screen, outlines the controls / HUD being explained, 4 short pages.

const SETTINGS_PATH: String = "res://scripts/managers/game_settings.gd"
const GOLD: Color = Color(1.0, 0.85, 0.2, 1.0)

var _settings = null
var _pages: Array = []
var _page: int = 0
var _boxes: Array = []
var _use_pad: bool = false
var _paused_by_me: bool = false

var _canvas: Control
var _counter: Label
var _title: Label
var _body: Label
var _next_button: Button


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var script = load(SETTINGS_PATH)
	if script != null:
		_settings = script.new()
	var gm = get_tree().root.get_node_or_null("GamepadManager")
	_use_pad = gm != null and bool(gm.get("gamepad_active"))
	_build_pages()
	_build_ui()
	# Solo play pauses behind the tutorial; in co-op the game can't wait.
	if not multiplayer.has_multiplayer_peer():
		get_tree().paused = true
		_paused_by_me = true
	await get_tree().process_frame
	await get_tree().process_frame
	_show_page(0)


func _build_pages() -> void:
	_pages = [
		{
			"title": "MOVE & LOOK",
			"touch": "Left thumb: drag the stick to move.\nRight thumb: drag anywhere else to look around.",
			"pad": "Left stick: move.\nRight stick: look around.\nA: jump.",
			"touch_boxes": ["joystick"],
			"pad_boxes": [],
		},
		{
			"title": "SHOOT & AIM",
			"touch": "Touch and hold the bottom-right area to fire. Keep holding and drag to aim while you shoot.\nTap AIM to zoom in; tap it again to zoom out.",
			"pad": "RT (R2): shoot.\nLT (L2): zoom in / out.\nX: reload.",
			"touch_boxes": ["shoot_zone", "aim"],
			"pad_boxes": [],
		},
		{
			"title": "BUTTONS",
			"touch": "SWAP: change weapon.\nSPRINT: run (uses stamina).\nRELOAD and JUMP.\nUSE: open doors and buy from stations.\nAIM: zoom in.",
			"pad": "B: use (doors and stations).\nY or RB: next weapon.   LB: previous weapon.\nL3 (click the left stick): sprint.",
			"touch_boxes": ["cluster"],
			"pad_boxes": [],
		},
		{
			"title": "STATUS",
			"touch": "Top left: health, ammo, your weapon and Gains (money).\nA white stamina bar appears under Gains when you sprint.\nTop middle: round and zombies left.\nSupplements you own light up along the bottom.",
			"pad": "Top left: health, ammo, your weapon and Gains (money).\nA white stamina bar appears under Gains when you sprint.\nTop middle: round and zombies left.\nSupplements you own light up along the bottom.",
			"touch_boxes": ["hud_stats", "round", "perks"],
			"pad_boxes": ["hud_stats", "round", "perks"],
		},
	]


func _build_ui() -> void:
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_canvas)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.07, 0.94)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_counter)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(820, 0)
	_body.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	vbox.add_child(row)

	var skip := Button.new()
	skip.text = "SKIP"
	skip.custom_minimum_size = Vector2(220, 70)
	skip.add_theme_font_size_override("font_size", 26)
	skip.pressed.connect(_finish)
	row.add_child(skip)

	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(260, 70)
	_next_button.add_theme_font_size_override("font_size", 26)
	_next_button.pressed.connect(_next)
	row.add_child(_next_button)


func _draw_canvas() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, _canvas.size), Color(0.0, 0.0, 0.0, 0.6))
	for r in _boxes:
		var rect: Rect2 = r
		_canvas.draw_rect(rect, Color(1.0, 0.85, 0.2, 0.15), true)
		_canvas.draw_rect(rect, GOLD, false, 4.0)


func _show_page(i: int) -> void:
	_page = i
	var page: Dictionary = _pages[i]
	_counter.text = "%d / %d" % [i + 1, _pages.size()]
	_title.text = str(page["title"])
	_body.text = str(page["pad"] if _use_pad else page["touch"])
	_next_button.text = "GOT IT" if i == _pages.size() - 1 else "NEXT"
	var keys: Array = page["pad_boxes"] if _use_pad else page["touch_boxes"]
	_boxes.clear()
	for k in keys:
		var r = _rect_for(str(k))
		if r != null:
			_boxes.append(r)
	_canvas.queue_redraw()


func _next() -> void:
	if _page >= _pages.size() - 1:
		_finish()
	else:
		_show_page(_page + 1)


func _finish() -> void:
	if _settings != null:
		_settings.set_value("tutorial_seen", 1.0)
	if _paused_by_me:
		get_tree().paused = false
	queue_free()


## Controller: A = next, B = skip.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			get_viewport().set_input_as_handled()
			_next()
		elif event.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			_finish()


func _control_rect(node: Node):
	if node is Control:
		return (node as Control).get_global_rect().grow(8.0)
	return null


func _rect_for(kind: String):
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	var vp: Vector2 = get_viewport().get_visible_rect().size
	match kind:
		"joystick":
			return _control_rect(scene.find_child("Joystick", true, false))
		"cluster":
			return _control_rect(scene.find_child("Cluster", true, false))
		"aim":
			var cluster: Node = scene.find_child("Cluster", true, false)
			if cluster != null:
				for c in cluster.get_children():
					if c is Button and (c as Button).text == "AIM":
						return _control_rect(c)
			return null
		"shoot_zone":
			var left: float = vp.x * 0.5 + 164.0
			return Rect2(left, vp.y - 330.0, vp.x - left, 330.0)
		"round":
			return _control_rect(scene.find_child("RoundLabel", true, false))
		"perks":
			return _control_rect(scene.find_child("PerkBar", true, false))
		"hud_stats":
			var found: bool = false
			var merged: Rect2 = Rect2()
			for n in ["HealthLabel", "AmmoLabel", "WeaponLabel", "GainsLabel"]:
				var node: Node = scene.find_child(n, true, false)
				if node is Control:
					var ctrl := node as Control
					var r := Rect2(ctrl.global_position, ctrl.get_minimum_size())
					merged = r if not found else merged.merge(r)
					found = true
			if found:
				return merged.grow(10.0)
	return null
