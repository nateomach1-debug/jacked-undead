extends Control
## Full-screen overlay that draws the current optic's reticle at the screen center.
## The player calls show_reticle() every frame.

const RETICLES_PATH: String = "res://scripts/ui/reticles.gd"
const RETICLE_SIZE: float = 24.0
const RETICLE_COLOR: Color = Color(1.0, 0.2, 0.2, 0.95)

var _lib = null
var _kind: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var script = load(RETICLES_PATH)
	if script != null:
		_lib = script.new()
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
	_lib.draw_reticle(self, size * 0.5, _kind, RETICLE_SIZE, RETICLE_COLOR)
