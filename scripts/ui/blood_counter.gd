extends Control
## Zombie counter: chunky blood-red numerals with slow, animated drips.
## Call set_value(n) to change the number.

@export var font_size: int = 88
@export var blood_color: Color = Color(0.74, 0.03, 0.06, 1.0)
@export var outline_color: Color = Color(0.06, 0.02, 0.02, 1.0)

const DRIP_COUNT: int = 5
const OUTLINE_SIZE: int = 12

var value: int = 0
var _drips: Array = []
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(font_size * 2.2, font_size + 90.0)
	for i in range(DRIP_COUNT):
		_drips.append(_new_drip(true))


func set_value(v: int) -> void:
	value = v
	queue_redraw()


func _new_drip(start_partway: bool) -> Dictionary:
	var reach: float = randf_range(20.0, 62.0)
	return {
		"slot": randi(),
		"jitter": randf_range(-0.15, 0.15),
		"w": randf_range(5.0, 9.0),
		"drop": randf_range(0.0, reach) if start_partway else 0.0,
		"reach": reach,
		"rate": randf_range(5.0, 14.0),
		"wait": 0.0,
	}


func _process(delta: float) -> void:
	for i in range(_drips.size()):
		var d: Dictionary = _drips[i]
		if d["drop"] < d["reach"]:
			d["drop"] += d["rate"] * delta
		else:
			d["wait"] += delta
			if d["wait"] > 2.5:
				_drips[i] = _new_drip(false)
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var text: String = str(value)
	var fs: int = font_size
	var text_size: Vector2 = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var left: float = (size.x - text_size.x) * 0.5
	var baseline: float = _font.get_ascent(fs) + 8.0
	var pos := Vector2(left, baseline)
	var digit_w: float = text_size.x / float(text.length())
	var top: float = baseline - fs * 0.1

	# Dark outlines first so numerals and drips merge into one blob.
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, OUTLINE_SIZE, outline_color)
	for d in _drips:
		var x: float = _drip_x(d, left, digit_w, text.length())
		var w: float = float(d["w"]) + 6.0
		var drop: float = float(d["drop"])
		draw_rect(Rect2(x - w * 0.5, top, w, drop), outline_color)
		draw_circle(Vector2(x, top + drop), w * 0.5, outline_color)

	# Blood fill: drawn a few times with tiny offsets to fatten the strokes.
	for offset in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(0, -1.5), Vector2(0, 1.5), Vector2.ZERO]:
		draw_string(_font, pos + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, blood_color)
	for d in _drips:
		var x: float = _drip_x(d, left, digit_w, text.length())
		var w: float = float(d["w"])
		var drop: float = float(d["drop"])
		draw_rect(Rect2(x - w * 0.5, top, w, drop), blood_color)
		draw_circle(Vector2(x, top + drop), w * 0.5, blood_color)
		# little wet highlight on the drop
		draw_circle(Vector2(x - w * 0.15, top + drop - w * 0.1), w * 0.15, Color(1.0, 0.45, 0.45, 0.7))


## Drips hang from the bottom center of a digit so they never float in a gap.
func _drip_x(d: Dictionary, left: float, digit_w: float, digits: int) -> float:
	var slot: int = int(d["slot"]) % digits
	return left + (float(slot) + 0.5 + float(d["jitter"])) * digit_w
