extends Control
## Full-screen overlay that draws the current optic's reticle at the screen center.
## The player calls show_reticle() every frame. Size and color come from Settings.

const RETICLES_PATH: String = "res://scripts/ui/reticles.gd"
const SETTINGS_PATH: String = "res://scripts/managers/game_settings.gd"
const BASE_SIZE: float = 24.0

var _lib = null
var _kind: String = ""
var _color: Color = Color(1.0, 0.2, 0.2, 0.95)
var _size_px: float = BASE_SIZE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var script = load(RETICLES_PATH)
	if script != null:
		_lib = script.new()
	var settings_script = load(SETTINGS_PATH)
	if settings_script != null:
		var s = settings_script.new()
		_color = s.reticle_color()
		_size_px = BASE_SIZE * s.get_value("reticle_size") / 100.0
	visible = false


## kind "" = hidden. amount 0..1 fades the reticle in as you finish aiming.
func show_reticle(kind: String, amount: float) -> void:
	var changed: bool = kind != _kind
	_kind = kind
	visible = kind != "" and amount > 0.0
	modulate.a = clampf(amount, 0.0, 1.0)
	if changed:
		queue_redraw()


func _draw() -> void:
	if _lib == null or _kind == "":
		return
	_lib.draw_reticle(self, size * 0.5, _kind, _size_px, _color)
