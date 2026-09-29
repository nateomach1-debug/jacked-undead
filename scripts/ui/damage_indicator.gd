extends CanvasLayer
## Red damage-taken indicator: a brief red flash on the screen edges plus an
## arc around the crosshair pointing toward whatever hit you. Built entirely
## in code. The player calls show_hit(angle_radians, has_direction).
## Angle 0 = straight ahead, +90 degrees (PI/2) = your right.

const HIT_LIFETIME: float = 1.2     # seconds a hit stays on screen
const ARC_HALF_WIDTH: float = 0.5   # radians each side of the hit direction
const ARC_SEGMENTS: int = 14
const MAX_HITS: int = 6

var _canvas: Control
var _hits: Array = []  # each: {"angle": float, "has_dir": bool, "time": float}


func _ready() -> void:
	layer = 0  # under the HUD so it never covers your buttons
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	_canvas.draw.connect(_on_draw)


func show_hit(angle: float, has_direction: bool) -> void:
	_hits.append({"angle": angle, "has_dir": has_direction, "time": HIT_LIFETIME})
	if _hits.size() > MAX_HITS:
		_hits.pop_front()


func _process(delta: float) -> void:
	if _hits.is_empty():
		return
	for h in _hits:
		h["time"] = float(h["time"]) - delta
	_hits = _hits.filter(func(h): return float(h["time"]) > 0.0)
	_canvas.queue_redraw()


func _on_draw() -> void:
	var view: Vector2 = _canvas.get_viewport_rect().size
	var center: Vector2 = view * 0.5
	var radius: float = minf(view.x, view.y) * 0.32
	var thickness: float = minf(view.x, view.y) * 0.09
	var flash: float = 0.0
	for h in _hits:
		var life: float = float(h["time"]) / HIT_LIFETIME  # 1 -> 0
		flash = maxf(flash, life)
		if h["has_dir"]:
			_draw_arc_glow(center, float(h["angle"]), radius, thickness, life)
	_draw_edge_flash(view, flash)


func _draw_edge_flash(view: Vector2, strength: float) -> void:
	if strength <= 0.0:
		return
	var a: float = strength * strength * 0.35
	var band: float = minf(view.x, view.y) * 0.22
	var solid := Color(0.85, 0.0, 0.0, a)
	var clear := Color(0.85, 0.0, 0.0, 0.0)
	var cols := PackedColorArray([solid, solid, clear, clear])
	# top
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(view.x, 0), Vector2(view.x, band), Vector2(0, band)]), cols)
	# bottom
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, view.y), Vector2(view.x, view.y), Vector2(view.x, view.y - band), Vector2(0, view.y - band)]), cols)
	# left
	_canvas.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(0, view.y), Vector2(band, view.y), Vector2(band, 0)]), cols)
	# right
	_canvas.draw_polygon(PackedVector2Array([Vector2(view.x, 0), Vector2(view.x, view.y), Vector2(view.x - band, view.y), Vector2(view.x - band, 0)]), cols)


## A curved red glow around the crosshair, brightest in the middle and at its
## outer edge, fading out at both ends and toward the center.
func _draw_arc_glow(center: Vector2, angle: float, radius: float, thickness: float, life: float) -> void:
	var peak: float = clampf(life * 1.4, 0.0, 1.0) * 0.85
	for i in range(ARC_SEGMENTS):
		var t0: float = float(i) / ARC_SEGMENTS
		var t1: float = float(i + 1) / ARC_SEGMENTS
		var a0: float = angle + lerpf(-ARC_HALF_WIDTH, ARC_HALF_WIDTH, t0)
		var a1: float = angle + lerpf(-ARC_HALF_WIDTH, ARC_HALF_WIDTH, t1)
		var f0: float = sin(PI * t0)
		var f1: float = sin(PI * t1)
		var d0 := Vector2(sin(a0), -cos(a0))
		var d1 := Vector2(sin(a1), -cos(a1))
		var pts := PackedVector2Array([
			center + d0 * (radius + thickness),
			center + d1 * (radius + thickness),
			center + d1 * radius,
			center + d0 * radius,
		])
		var cols := PackedColorArray([
			Color(1.0, 0.05, 0.05, peak * f0),
			Color(1.0, 0.05, 0.05, peak * f1),
			Color(1.0, 0.05, 0.05, peak * f1 * 0.15),
			Color(1.0, 0.05, 0.05, peak * f0 * 0.15),
		])
		_canvas.draw_polygon(pts, cols)
