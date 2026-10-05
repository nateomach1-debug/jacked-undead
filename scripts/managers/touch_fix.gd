extends Node
## Touch fixes for the whole game, installed by GameManager:
##  - dragging a finger on any ScrollContainer scrolls it (even when the finger starts on a button)
##  - dragging on any slider (HSlider/VSlider) moves it
## A quick tap still presses buttons. Loaded with load() + a null check.

const DEADZONE: float = 14.0   # pixels a finger must move before it counts as a scroll

var _scrolls: Array = []       # ScrollContainers in the tree
var _sliders: Array = []       # Sliders in the tree
var _scroll: ScrollContainer = null
var _slider: Slider = null
var _finger: int = -1
var _press_pos: Vector2 = Vector2.ZERO
var _last_pos: Vector2 = Vector2.ZERO
var _scroll_f: float = 0.0
var _dragging: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("touch_fix")
	_scan(get_tree().root)
	get_tree().node_added.connect(_on_node_added)


func _scan(node: Node) -> void:
	_on_node_added(node)
	for c in node.get_children():
		_scan(c)


func _on_node_added(n: Node) -> void:
	if n is ScrollContainer:
		_scrolls.append(n)
	elif n is Slider:
		_sliders.append(n)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin(event.index, event.position)
		elif event.index == _finger:
			var was_active: bool = _dragging or _slider != null
			_end()
			if was_active:
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _finger:
		if _slider != null and is_instance_valid(_slider):
			_set_slider(_slider, event.position)
			get_viewport().set_input_as_handled()
		elif _scroll != null and is_instance_valid(_scroll):
			_drag_scroll(event.position)
		else:
			_end()


func _end() -> void:
	_scroll = null
	_slider = null
	_finger = -1
	_dragging = false


func _begin(index: int, pos: Vector2) -> void:
	if _finger != -1 and index != _finger:
		return   # already following one finger
	_end()
	if _touch_slider_at(pos):
		return   # a TouchSlider handles its own touches
	var s: Slider = _slider_at(pos)
	if s != null:
		_slider = s
		_finger = index
		_set_slider(s, pos)
		return
	var sc: ScrollContainer = _scroll_at(pos)
	if sc != null:
		var bar: ScrollBar = sc.get_v_scroll_bar()
		if bar.max_value - bar.page > 1.0:   # only if there is something to scroll
			_scroll = sc
			_finger = index
			_press_pos = pos
			_last_pos = pos
			_scroll_f = float(sc.scroll_vertical)
			_dragging = false


func _drag_scroll(pos: Vector2) -> void:
	if not _dragging:
		if pos.distance_to(_press_pos) < DEADZONE:
			return
		_dragging = true
		# Cancels a button the finger started on, so a scroll never presses it.
		get_viewport().gui_release_focus()
	var bar: ScrollBar = _scroll.get_v_scroll_bar()
	var max_v: float = maxf(0.0, bar.max_value - bar.page)
	_scroll_f = clampf(_scroll_f - (pos.y - _last_pos.y), 0.0, max_v)
	_last_pos = pos
	_scroll.scroll_vertical = int(_scroll_f)
	get_viewport().set_input_as_handled()


func _set_slider(s: Slider, pos: Vector2) -> void:
	var r: Rect2 = s.get_global_rect()
	var ratio: float = 0.0
	if s is VSlider:
		ratio = 1.0 - (pos.y - r.position.y) / maxf(r.size.y, 1.0)
	else:
		ratio = (pos.x - r.position.x) / maxf(r.size.x, 1.0)
	s.value = lerpf(s.min_value, s.max_value, clampf(ratio, 0.0, 1.0))


func _slider_at(pos: Vector2) -> Slider:
	for i in range(_sliders.size() - 1, -1, -1):
		var s = _sliders[i]
		if not is_instance_valid(s):
			_sliders.remove_at(i)
			continue
		if s.is_visible_in_tree() and s.editable and s.get_global_rect().has_point(pos):
			return s
	return null


func _scroll_at(pos: Vector2) -> ScrollContainer:
	for i in range(_scrolls.size() - 1, -1, -1):
		var sc = _scrolls[i]
		if not is_instance_valid(sc):
			_scrolls.remove_at(i)
			continue
		if sc.is_visible_in_tree() and sc.get_global_rect().has_point(pos):
			return sc
	return null


func _touch_slider_at(pos: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("touch_slider"):
		if n is Control and (n as Control).is_visible_in_tree() and (n as Control).get_global_rect().has_point(pos):
			return true
	return false
